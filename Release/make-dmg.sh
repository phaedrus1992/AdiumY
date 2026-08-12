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

if [ ! -d "$APP" ]; then
	echo "error: $APP is not a bundle directory" >&2
	exit 66
fi

RELEASE_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_DIR=$(dirname "$RELEASE_DIR")
VOLUME_NAME="AdiumY $VERSION"
# The Finder layout below is fed through an unquoted heredoc, so these values
# reach the AppleScript source text verbatim. A version carrying a `"` (or a
# manual VERSION= override with a backtick) would otherwise break out of the
# string literal and become AppleScript of its own. Newlines collapse to a
# space so a hostile/multi-line value cannot even split the `tell disk` line.
apple_escape() {
	# shellcheck disable=SC2016  # single-quoted sed program: backslash + backtick are literal, must NOT expand
	printf '%s' "$1" | tr '\n' ' ' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/`/\\`/g'
}
ESCAPED_VOLUME_NAME=$(apple_escape "$VOLUME_NAME")
ESCAPED_APP_LEAF=$(apple_escape "$(basename "$APP")")
STAGE=$(mktemp -d)
# A directory + fixed leaf name, not `mktemp -u`: `-u` prints a name it never
# reserves, so nothing stops another process claiming it before this script
# creates the actual image there.
DMG_WORKDIR=$(mktemp -d)
TEMP_DMG="$DMG_WORKDIR/image.dmg"

cleanup() {
	if [ -n "${DEV_NAME:-}" ] && [ -e "$DEV_NAME" ]; then
		hdiutil detach "$DEV_NAME" -quiet -force || true
	fi
	rm -rf "$STAGE" "$DMG_WORKDIR"
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

# -plist + python3 rather than `hdiutil attach | grep | sed 1q | awk`: that
# pipeline reintroduces the exact SIGPIPE-under-pipefail hazard sign-bundle.sh
# documents elsewhere in this repo (sed quits reading after the first match,
# which can signal the still-writing upstream stage), and it guessed
# MOUNT_DIR from VOLUME_NAME rather than reading it — wrong the moment a
# volume of that name is already mounted (e.g. left over from an interrupted
# run), silently operating on someone else's disk image for the rest of the
# script. plutil/python3 both fully drain their stdin, so nothing here exits
# early and there is nothing to SIGPIPE.
ATTACH_INFO=$(hdiutil attach -readwrite -noverify -noautoopen -plist "$TEMP_DMG" |
	plutil -convert json -o - - |
	python3 -c '
import json, sys
for e in json.load(sys.stdin)["system-entities"]:
    if "mount-point" in e:
        print(e["dev-entry"])
        print(e["mount-point"])
        break
')
DEV_NAME=$(printf '%s\n' "$ATTACH_INFO" | sed -n '1p')
MOUNT_DIR=$(printf '%s\n' "$ATTACH_INFO" | sed -n '2p')
[ -n "$MOUNT_DIR" ] || {
	echo "error: hdiutil attach did not report a mountable partition" >&2
	exit 1
}

# Driving Finder needs a GUI login session, which a CI runner does not have.
# A pre-baked .DS_Store is the headless path: it encodes the same icon
# positions and window size, and just gets copied in.
#
# A DMG whose layout never landed is degraded but not corrupt — icons sit at
# default positions — and that used to be invisible: the build finished and
# the artifact looked identical to a correct one. Track it for the end-of-run
# summary, and let DMG_REQUIRE_FINDER_LAYOUT=1 make a missing layout fatal for
# release builds that must ship it.
layout_applied=true
DS_STORE="$RELEASE_DIR/Artwork/dmg-DS_Store"
if [ -f "$DS_STORE" ]; then
	echo "==> Applying pre-baked Finder layout"
	ditto "$DS_STORE" "$MOUNT_DIR/.DS_Store" || true
	if [ ! -f "$MOUNT_DIR/.DS_Store" ]; then
		# ditto failed or produced nothing — same degraded state as a failed
		# AppleScript pass, tracked for the end-of-run summary.
		layout_applied=false
	fi
	apply_finder_layout=false
else
	echo "==> Applying Finder layout via AppleScript"
	apply_finder_layout=true
fi

# Background image is 600x400; the window is sized to match it exactly.
if [ "$apply_finder_layout" = true ]; then
	OSASCRIPT_ERR="$DMG_WORKDIR/osascript.err"
	osascript_failed=""
	osascript 2>"$OSASCRIPT_ERR" <<APPLESCRIPT || osascript_failed=1
tell application "Finder"
	tell disk "$ESCAPED_VOLUME_NAME"
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set the bounds of container window to {200, 120, 800, 520}
		set theViewOptions to the icon view options of container window
		set arrangement of theViewOptions to not arranged
		set icon size of theViewOptions to 96
		set background picture of theViewOptions to file ".background:dmgBackground.png"
		set position of item "$ESCAPED_APP_LEAF" of container window to {150, 200}
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
	if [ -n "$osascript_failed" ]; then
		# The DMG still builds (degraded layout); the single end-of-run warning
		# and the DMG_REQUIRE_FINDER_LAYOUT=1 gate below cover the policy. Here
		# only osascript's own reason is surfaced.
		if [ -f "$OSASCRIPT_ERR" ]; then
			echo "  osascript: $(cat "$OSASCRIPT_ERR")" >&2
		else
			echo "  osascript: (no stderr captured — writing $OSASCRIPT_ERR failed)" >&2
		fi
		layout_applied=false
	fi
fi

# A volume icon is the modern replacement for the HFS+ resource-fork `Icon\r`
# files git cannot store: `.VolumeIcon.icns` on the volume root plus the
# SetFile custom-icon attribute is what Finder renders on the mounted disk.
# Purely cosmetic — a missing icon or SetFile degrades to a warning, never a
# failed release.
VOLUME_ICON="$RELEASE_DIR/Artwork/VolumeIcon.icns"
if [ -f "$VOLUME_ICON" ]; then
	echo "==> Applying volume icon"
	if ! ditto "$VOLUME_ICON" "$MOUNT_DIR/.VolumeIcon.icns"; then
		echo "  warning: could not copy $VOLUME_ICON — using the default volume icon" >&2
	elif ! SetFile -a C "$MOUNT_DIR"; then
		echo "  warning: SetFile -a C failed — using the default volume icon" >&2
	fi
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

if [ "$layout_applied" != true ]; then
	echo "warning: DMG built without Finder layout — icons use default positions (set DMG_REQUIRE_FINDER_LAYOUT=1 to make this fatal)" >&2
	if [ "${DMG_REQUIRE_FINDER_LAYOUT:-}" = "1" ]; then
		echo "error: DMG_REQUIRE_FINDER_LAYOUT=1 — Finder layout failure is fatal" >&2
		exit 1
	fi
fi
echo "==> Built: $OUTPUT"
