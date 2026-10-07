#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
"$task_root/scripts/build.sh"
destination="$HOME/Applications/Tomales.app"
mkdir -p "$HOME/Applications"
if [[ -e "$destination" ]]; then
    identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$identifier" != "app.tomales.menubar" ]]; then
        echo "An unrelated Tomales.app already exists at $destination" >&2
        exit 1
    fi
fi
staging="$(mktemp -d "$HOME/Applications/.tomales-install.XXXXXX")"
cleanup() {
    if [[ -e "$staging/Previous.app" && ! -e "$destination" ]]; then
        echo "Previous app preserved at $staging/Previous.app" >&2
    else
        rm -rf "$staging"
    fi
}
trap cleanup EXIT
/usr/bin/ditto "$task_root/dist/Tomales.app" "$staging/Tomales.app"
if /usr/bin/pgrep -x Tomales >/dev/null; then
    /usr/bin/osascript -e 'tell application id "app.tomales.menubar" to quit'
    for attempt in {1..30}; do
        if ! /usr/bin/pgrep -x Tomales >/dev/null; then break; fi
        /bin/sleep 0.1
    done
    if /usr/bin/pgrep -x Tomales >/dev/null; then
        echo "Quit Tomales before installing." >&2
        exit 1
    fi
fi
if [[ -e "$destination" ]]; then mv "$destination" "$staging/Previous.app"; fi
if ! mv "$staging/Tomales.app" "$destination"; then
    if [[ -e "$staging/Previous.app" ]]; then mv "$staging/Previous.app" "$destination"; fi
    exit 1
fi
/usr/bin/open "$destination"
echo "Installed $destination"
