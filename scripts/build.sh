#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
architecture="${TOMALES_ARCHITECTURE:-native}"
if [[ "${1:-}" == "--universal" ]]; then architecture=universal; fi
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--universal" ) ]]; then
    echo "Usage: scripts/build.sh [--universal]" >&2
    exit 2
fi
version="$(tr -d '[:space:]' < VERSION)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Invalid VERSION" >&2; exit 2; fi
tap="${TOMALES_HOMEBREW_TAP:-}"
homebrew_kind="${TOMALES_HOMEBREW_KIND:-cask}"
if [[ -n "$tap" && ! "$tap" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "TOMALES_HOMEBREW_TAP must be owner/tap" >&2; exit 2
fi
if [[ "$homebrew_kind" != formula && "$homebrew_kind" != cask ]]; then
    echo "TOMALES_HOMEBREW_KIND must be formula or cask" >&2; exit 2
fi
mkdir -p .build/module-cache dist
export CLANG_MODULE_CACHE_PATH="$task_root/.build/module-cache"
build=(xcrun swift build -c release --disable-sandbox
    -debug-info-format none --disable-index-store
    --cache-path "$task_root/.build/cache" --config-path "$task_root/.build/config"
    --security-path "$task_root/.build/security"
    -Xswiftc -module-cache-path -Xswiftc "$CLANG_MODULE_CACHE_PATH")
case "$architecture" in
    native) ;;
    universal) build+=(--arch arm64 --arch x86_64) ;;
    arm64|x86_64) build+=(--arch "$architecture") ;;
    *) echo "Unsupported architecture: $architecture" >&2; exit 2 ;;
esac
"${build[@]}"
binary_directory="$("${build[@]}" --show-bin-path)"
app="$task_root/dist/Tomales.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_directory/Tomales" "$app/Contents/MacOS/Tomales"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
if [[ -n "$tap" ]]; then
    /usr/libexec/PlistBuddy -c "Add :TomalesHomebrewTap string $tap" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :TomalesHomebrewKind string $homebrew_kind" "$app/Contents/Info.plist"
fi
iconset="$task_root/.build/AppIcon.iconset"
if [[ ! -f "$task_root/.build/AppIcon.icns" || Tools/GenerateIcon.swift -nt "$task_root/.build/AppIcon.icns" ]]; then
    xcrun swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" Tools/GenerateIcon.swift "$iconset"
    /usr/bin/iconutil -c icns "$iconset" -o "$task_root/.build/AppIcon.icns"
fi
cp "$task_root/.build/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$iconset/icon_128x128@2x.png" "$app/Contents/Resources/TomalesIcon.png"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
if [[ -n "${TOMALES_SIGNING_IDENTITY:-}" ]]; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$TOMALES_SIGNING_IDENTITY" "$app"
else
    /usr/bin/codesign --force --sign - "$app"
fi
echo "Built $app"
