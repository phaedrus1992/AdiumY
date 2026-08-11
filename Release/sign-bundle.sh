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

# No pipeline here on purpose: `file -b x | grep -q` returns non-zero under
# `set -o pipefail`, because grep -q exits early and file dies on SIGPIPE.
is_macho() {
	local description
	description=$(file -b "$1")
	[[ "$description" == *Mach-O* ]]
}

# "Developer ID Application: Someone (C36L3X7U5T)" -> "C36L3X7U5T". Empty for
# ad-hoc signing, which has no team. The Fastfile is responsible for always
# passing a full name here rather than a bare SHA-1 or team ID, precisely so
# this can find one — see resolve_identity_override.
EXPECTED_TEAM=""
if [[ "$IDENTITY" =~ \(([A-Z0-9]{10})\)[[:space:]]*$ ]]; then
	EXPECTED_TEAM="${BASH_REMATCH[1]}"
fi

# An empty directory under Versions/ makes framework signing fail. Version
# control leaves these behind when a vendored dependency drops a directory.
echo "==> Removing empty directories"
find "$APP" -type d -empty -delete

# Loose executables first: helper tools that belong to no bundle of their own,
# such as AdiumApplescriptRunner and Sparkle's Autoupdate. Signing a bundle
# afterwards seals over them, which is the order notarization wants.
#
# A bundle's own main binary gets signed here too. That is redundant rather
# than wrong — signing the enclosing bundle replaces it.
#
# -perm -u+x, not +111: BSD find's `+mode` spelling is deprecated and silently
# matches nothing under `set -euo pipefail`, which quietly turned this whole
# pass into a no-op.
echo "==> Signing loose executables"
MAIN_EXECUTABLE="$APP/Contents/MacOS/$(basename "$APP" .app)"
while IFS= read -r -d '' bin; do
	[ "$bin" = "$MAIN_EXECUTABLE" ] && continue
	is_macho "$bin" || continue
	echo "    $bin"
	sign "$bin"
done < <(find "$APP" -type f -perm -u+x -print0)

# Then every nested code bundle, deepest first, so a child is never signed
# after the parent that seals it.
#
# -type d on the bundles: a versioned framework symlinks its contents into its
# root, and signing the same bundle twice through both paths breaks the seal.
# Nested .app matters — Sparkle ships Updater.app inside its framework, still
# carrying the Sparkle project's signature until this re-signs it.
echo "==> Signing nested bundles and libraries"
while IFS= read -r -d '' item; do
	[ "$item" = "$APP" ] && continue
	echo "    $item"
	sign "$item"
done < <(find "$APP" -depth \( \
	\( -type d \( -name '*.app' -o -name '*.framework' -o -name '*.bundle' \
	-o -name '*.mdimporter' -o -name '*.xpc' -o -name '*.appex' \) \) \
	-o \( -type f \( -name '*.dylib' -o -name '*.so' \) \) \) \
	-print0)

echo "==> Signing $APP"
if [ -n "$ENTITLEMENTS" ]; then
	sign --entitlements "$ENTITLEMENTS" "$APP"
else
	sign "$APP"
fi

echo "==> Verifying seal and nested code"
codesign --verify --strict --deep --verbose=2 "$APP"

# `codesign --verify` alone is not enough: the linker ad-hoc-signs every binary
# at link time, so an executable this script missed still verifies while being
# rejected by notarization as "not signed with a valid Developer ID
# certificate". Check who signed it, not just that something did.
echo "==> Auditing every executable"
failed=0
while IFS= read -r -d '' bin; do
	is_macho "$bin" || continue

	if ! info=$(codesign --display --verbose=2 "$bin" 2>&1); then
		echo "    UNSIGNED: $bin" >&2
		failed=1
		continue
	fi

	if [[ "$info" == *linker-signed* ]]; then
		echo "    STILL LINKER-SIGNED: $bin" >&2
		failed=1
	elif [ -n "$EXPECTED_TEAM" ] && [[ "$info" != *"TeamIdentifier=$EXPECTED_TEAM"* ]]; then
		echo "    WRONG TEAM: $bin" >&2
		failed=1
	fi
done < <(find "$APP" -type f -print0)

if [ "$failed" -ne 0 ]; then
	echo "error: bundle has executables this script did not sign; notarization will fail" >&2
	exit 1
fi

# Report signing details, but never let a grep non-match kill the release
# silently: under `set -o pipefail`, a signature that prints none of these
# tokens (or a failed --display whose error text carries none) turns grep's
# exit 1 into an unlabeled abort. Show the actual output either way.
SIGN_INFO=$(codesign --display --verbose=4 "$APP" 2>&1 || true)
if [ -z "$SIGN_INFO" ]; then
	echo "warning: codesign --display --verbose=4 produced no output for $APP" >&2
else
	SIGN_LINES=$(printf '%s\n' "$SIGN_INFO" | grep -E 'Authority|TeamIdentifier|Runtime|flags' || true)
	if [ -n "$SIGN_LINES" ]; then
		echo "$SIGN_LINES"
	else
		echo "warning: $APP signature shows none of Authority/TeamIdentifier/Runtime/flags:" >&2
		echo "$SIGN_INFO" >&2
	fi
fi
echo "==> Signed: $APP"
