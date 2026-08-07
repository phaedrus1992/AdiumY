#!/bin/bash
#
# Build the distributable disk image: stage the signed app alongside an
# /Applications symlink, apply the Finder window layout, and compress.
#
# Replaces the pre-fork make-diskimage.sh, which depended on an i386-only
# mkalias, an x86_64-only AdiumApplescriptRunner, and /Developer/Tools.
#
# Usage: make-dmg.sh <app-bundle> <version> <output-dmg>

set -euo pipefail

if [ $# -ne 3 ]; then
	echo "usage: $0 <app-bundle> <version> <output-dmg>" >&2
	exit 64
fi

APP=$1
VERSION=$2
OUTPUT=$3

RELEASE_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_DIR=$(dirname "$RELEASE_DIR")
VOLUME_NAME="AdiumY $VERSION"
STAGE=$(mktemp -d)
TEMP_DMG=$(mktemp -u).dmg

if [ ! -d "$APP" ]; then
	echo "error: $APP is not a bundle directory" >&2
	exit 66
fi

cleanup() {
	if [ -n "${DEV_NAME:-}" ] && [ -e "$DEV_NAME" ]; then
		hdiutil detach "$DEV_NAME" -quiet -force || true
	fi
	rm -rf "$STAGE" "$TEMP_DMG"
}
trap cleanup EXIT

echo "==> Staging $VOLUME_NAME"
# ditto, not cp: preserves extended attributes and the code signature.
ditto "$APP" "$STAGE/$(basename "$APP")"
ditto "$SRC_DIR/ChangeLogs/Changes.txt" "$STAGE/Changes.txt"
ditto "$SRC_DIR/License.txt" "$STAGE/License.txt"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
ditto "$RELEASE_DIR/Artwork/dmgBackground.png" "$STAGE/.background/dmgBackground.png"

echo "==> Creating read-write image"
hdiutil create -srcfolder "$STAGE" -volname "$VOLUME_NAME" \
	-fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG" -quiet

DEV_NAME=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" |
	grep -E '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_DIR="/Volumes/$VOLUME_NAME"

# Driving Finder needs a GUI login session, which a CI runner does not have.
# A pre-baked .DS_Store is the headless path: it encodes the same icon
# positions and window size, and just gets copied in.
DS_STORE="$RELEASE_DIR/Artwork/dmg-DS_Store"
if [ -f "$DS_STORE" ]; then
	echo "==> Applying pre-baked Finder layout"
	ditto "$DS_STORE" "$MOUNT_DIR/.DS_Store"
	apply_finder_layout=false
else
	echo "==> Applying Finder layout via AppleScript"
	apply_finder_layout=true
fi

# Background image is 600x400; the window is sized to match it exactly.
if [ "$apply_finder_layout" = true ]; then
	osascript <<APPLESCRIPT || echo "warning: Finder layout failed (no GUI session?); DMG will use default icon positions" >&2
tell application "Finder"
	tell disk "$VOLUME_NAME"
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set the bounds of container window to {200, 120, 800, 520}
		set theViewOptions to the icon view options of container window
		set arrangement of theViewOptions to not arranged
		set icon size of theViewOptions to 96
		set background picture of theViewOptions to file ".background:dmgBackground.png"
		set position of item "$(basename "$APP")" of container window to {150, 200}
		set position of item "Applications" of container window to {450, 200}
		set position of item "Changes.txt" of container window to {150, 330}
		set position of item "License.txt" of container window to {450, 330}
		close
		open
		update without registering applications
		delay 2
	end tell
end tell
APPLESCRIPT
fi

chmod -Rf go-w "$MOUNT_DIR" || true

# Mounting read-write leaves these behind; they have no business in a release.
rm -rf "$MOUNT_DIR/.fseventsd" "$MOUNT_DIR/.Trashes" "$MOUNT_DIR/.TemporaryItems"
sync

hdiutil detach "$DEV_NAME" -quiet
DEV_NAME=""

echo "==> Compressing"
rm -f "$OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"
hdiutil convert "$TEMP_DMG" -format UDBZ -o "$OUTPUT" -quiet

echo "==> Built: $OUTPUT"
