#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
release=false
universal=false
for argument in "$@"; do
    case "$argument" in
        --release) release=true; universal=true ;;
        --universal) universal=true ;;
        *) echo "Usage: scripts/package.sh [--universal] [--release]" >&2; exit 2 ;;
    esac
done
if $release; then
    : "${TOMALES_SIGNING_IDENTITY:?Set your Developer ID Application signing identity}"
    : "${TOMALES_NOTARY_PROFILE:?Set a notarytool Keychain profile}"
    : "${TOMALES_REPOSITORY:?Set the personal GitHub owner/repository}"
    : "${TOMALES_HOMEBREW_TAP:?Set the personal Homebrew owner/tap}"
    if [[ ! "$TOMALES_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ||
          ! "$TOMALES_HOMEBREW_TAP" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ||
          "${TOMALES_REPOSITORY%%/*}" != "${TOMALES_HOMEBREW_TAP%%/*}" ]]; then
        echo "Release repository and tap must use the same personal owner/name." >&2
        exit 2
    fi
fi
if $universal; then "$task_root/scripts/build.sh" --universal
else "$task_root/scripts/build.sh"; fi
version="$(tr -d '[:space:]' < VERSION)"
app="$task_root/dist/Tomales.app"
archive="$task_root/dist/Tomales-$version.zip"
disk_image="$task_root/dist/Tomales-$version.dmg"
notarize() {
    local response="$task_root/.build/notary-response.json"
    xcrun notarytool submit "$1" --keychain-profile "$TOMALES_NOTARY_PROFILE" \
        --wait --timeout 30m --output-format json > "$response"
    python3 - "$response" <<'PY'
import json
import sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
if result.get("status") != "Accepted":
    raise SystemExit(f"Notarization failed: {result.get('status', 'unknown')}; submission {result.get('id', 'unknown')}")
print(f"Notarization accepted: {result['id']}")
PY
}
rm -f "$archive"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
if $release; then
    notarize "$archive"
    xcrun stapler staple "$app"
    rm -f "$archive"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
fi
staging="$task_root/.build/dmg"
rm -rf "$staging"
mkdir -p "$staging"
/usr/bin/ditto "$app" "$staging/Tomales.app"
ln -s /Applications "$staging/Applications"
cp LICENSE "$staging/LICENSE.txt"
/usr/bin/hdiutil create -volname Tomales -srcfolder "$staging" -format UDZO -ov "$disk_image"
if $release; then
    /usr/bin/codesign --force --timestamp --sign "$TOMALES_SIGNING_IDENTITY" "$disk_image"
    notarize "$disk_image"
    xcrun stapler staple "$disk_image"
    python3 scripts/generate-cask.py --repository "$TOMALES_REPOSITORY" --tap "$TOMALES_HOMEBREW_TAP" \
        --archive "$archive" --output "$task_root/dist/tap/Casks/tomales.rb"
fi
(
    cd dist
    /usr/bin/shasum -a 256 "Tomales-$version.zip" "Tomales-$version.dmg" > SHA256SUMS
)
echo "Packaged $archive"
echo "Packaged $disk_image"
