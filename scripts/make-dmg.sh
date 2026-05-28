#!/usr/bin/env bash
#
# make-dmg.sh — package a (notarized) Boopa.app into a drag-to-Applications .dmg.
#
#   scripts/make-dmg.sh /path/to/Boopa.app [output.dmg]
#
# Produces a compressed disk image whose window shows Boopa.app next to an
# Applications shortcut, so users just double-click and drag to install.
#
# The app should already be Developer ID signed, notarized, and stapled. The
# stapled ticket is preserved inside the bundle. For public distribution you may
# also want to notarize the .dmg itself:
#   xcrun notarytool submit Boopa-<ver>.dmg --key … --key-id … --issuer … --wait
#   xcrun stapler staple Boopa-<ver>.dmg

set -euo pipefail

APP="${1:?usage: make-dmg.sh /path/to/Boopa.app [output.dmg]}"
[ -d "$APP" ] || { echo "Not found: $APP" >&2; exit 1; }

VOL="Boopa"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 1.0)"
OUT="${2:-$(cd "$(dirname "$APP")" && pwd)/Boopa-$VERSION.dmg}"

TMPDMG="$(mktemp -u).dmg"
STAGING="$(mktemp -d)"
MNT="/Volumes/$VOL"

cleanup() {
  hdiutil detach "$MNT" -quiet 2>/dev/null || true
  rm -rf "$STAGING" "$TMPDMG"
}
trap cleanup EXIT

# Stage app + Applications shortcut.
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Writable image, sized to content + slack.
hdiutil detach "$MNT" -quiet 2>/dev/null || true
hdiutil create -volname "$VOL" -srcfolder "$STAGING" -fs HFS+ \
  -format UDRW -ov "$TMPDMG" >/dev/null
hdiutil attach "$TMPDMG" -mountpoint "$MNT" -nobrowse -noautoopen >/dev/null

# Arrange the window (best effort — needs Automation permission for Finder).
osascript <<APPLESCRIPT 2>/dev/null || echo "note: Finder layout skipped (grant Automation access to arrange icons)"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 720, 470}
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 128
    set position of item "Boopa.app" of container window to {150, 180}
    set position of item "Applications" of container window to {390, 180}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true

rm -f "$OUT"
hdiutil convert "$TMPDMG" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
echo "Created: $OUT"
