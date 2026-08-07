#!/bin/bash
#
# Sign an .app bundle inside-out with a Developer ID identity, ready for
# notarization. Nested code is signed deepest-first; the outer bundle last,
# with entitlements.
#
# --deep is deliberately not used: it forces one set of options and
# entitlements onto every nested item and skips non-standard locations.
#
# Usage: sign-bundle.sh <app-bundle> <signing-identity> [entitlements-plist]

set -euo pipefail

if [ $# -lt 2 ]; then
	echo "usage: $0 <app-bundle> <signing-identity> [entitlements-plist]" >&2
	exit 64
fi

APP=$1
IDENTITY=$2
ENTITLEMENTS=${3:-}

if [ ! -d "$APP" ]; then
	echo "error: $APP is not a bundle directory" >&2
	exit 66
fi

if [ -n "$ENTITLEMENTS" ] && [ ! -f "$ENTITLEMENTS" ]; then
	echo "error: entitlements file not found: $ENTITLEMENTS" >&2
	exit 66
fi

# --timestamp and --options runtime are both required for notarization.
sign() {
	codesign --force --timestamp --options runtime --sign "$IDENTITY" "$@"
}

is_macho() {
	file -b "$1" | grep -q 'Mach-O'
}

# An empty directory under Versions/ makes framework signing fail. Version
# control leaves these behind when a vendored dependency drops a directory.
echo "==> Removing empty directories"
find "$APP" -type d -empty -delete

echo "==> Signing nested bundles and libraries"
while IFS= read -r -d '' item; do
	echo "    $item"
	sign "$item"
done < <(find "$APP" -depth \
	\( -name '*.framework' -o -name '*.bundle' -o -name '*.mdimporter' \
	-o -name '*.xpc' -o -name '*.appex' -o -name '*.dylib' -o -name '*.so' \) \
	-print0)

# Helper executables that are not bundles — AdiumApplescriptRunner and
# anything else dropped into Resources or MacOS alongside the main binary.
echo "==> Signing loose executables"
MAIN_EXECUTABLE="$APP/Contents/MacOS/$(basename "$APP" .app)"
while IFS= read -r -d '' bin; do
	[ "$bin" = "$MAIN_EXECUTABLE" ] && continue
	is_macho "$bin" || continue
	echo "    $bin"
	sign "$bin"
done < <(find "$APP/Contents/MacOS" "$APP/Contents/Resources" \
	-type f -perm +111 -print0 2>/dev/null)

echo "==> Signing $APP"
if [ -n "$ENTITLEMENTS" ]; then
	sign --entitlements "$ENTITLEMENTS" "$APP"
else
	sign "$APP"
fi

echo "==> Verifying seal and nested code"
codesign --verify --strict --deep --verbose=2 "$APP"

echo "==> Verifying every executable individually"
failed=0
while IFS= read -r -d '' bin; do
	is_macho "$bin" || continue
	if ! codesign --verify "$bin" 2>/dev/null; then
		echo "    UNSIGNED: $bin" >&2
		failed=1
	fi
done < <(find "$APP" -type f -perm +111 -print0)

if [ "$failed" -ne 0 ]; then
	echo "error: bundle contains unsigned executables; notarization will fail" >&2
	exit 1
fi

codesign --display --verbose=4 "$APP" 2>&1 | grep -E 'Authority|TeamIdentifier|Runtime|flags'
echo "==> Signed: $APP"
