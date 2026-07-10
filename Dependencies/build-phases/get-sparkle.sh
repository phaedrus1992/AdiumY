#!/bin/bash -eu
# get-sparkle.sh — Download Sparkle XCFramework from GitHub and extract to Frameworks/
#
# Sparkle is not built from source like the other vendored dependencies.
# Instead its precompiled XCFramework (universal arm64+x86_64) is downloaded
# from the Sparkle GitHub release and extracted into Frameworks/.
#
# Uses the same binary artifact that the Swift Package Manager binary target
# would resolve — avoids SPM integration issues with Xcode 26+ pbxproj format.
#
# Usage: ./get-sparkle.sh [--clean]

set -o pipefail
ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCROOT="$(cd "$ROOTDIR/.." && pwd)"

SPARKLE_VERSION="2.9.4"
FRAMEWORK_DIR="$SRCROOT/Frameworks/Sparkle.framework"
DOWNLOAD_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [ "${1:-}" = "--clean" ]; then
    echo "Removing $FRAMEWORK_DIR"
    rm -rf "$FRAMEWORK_DIR"
fi

if [ -d "$FRAMEWORK_DIR" ]; then
    echo "Sparkle.framework already present at $FRAMEWORK_DIR"
    echo "Pass --clean to re-download."
    exit 0
fi

echo "Downloading Sparkle $SPARKLE_VERSION from $DOWNLOAD_URL"
curl -L -o "$TEMP_DIR/sparkle.zip" "$DOWNLOAD_URL" 2>&1

echo "Extracting Sparkle XCFramework"
unzip -q -d "$TEMP_DIR" "$TEMP_DIR/sparkle.zip"

echo "Installing Sparkle.framework to $FRAMEWORK_DIR"
EXTRACTED_FRAMEWORK=$(find "$TEMP_DIR" -name "Sparkle.xcframework" -type d | head -1)
if [ -z "$EXTRACTED_FRAMEWORK" ]; then
    echo "Error: Could not find Sparkle.xcframework in the downloaded archive" >&2
    exit 1
fi

cp -R "$EXTRACTED_FRAMEWORK/macos-arm64_x86_64/Sparkle.framework" "$FRAMEWORK_DIR"

echo "Sparkle.framework installed successfully ($(file "$FRAMEWORK_DIR/Sparkle" | sed 's/.*://'))"
