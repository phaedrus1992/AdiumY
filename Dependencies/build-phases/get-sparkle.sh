#!/bin/bash
# get-sparkle.sh — Download the Sparkle framework and CLI tools from GitHub.
#
# Sparkle is not built from source like the other vendored dependencies.
# Instead its precompiled XCFramework (universal arm64+x86_64) is downloaded
# from the Sparkle GitHub release and extracted into Frameworks/.
#
# The appcast lane also needs the CLI tools (generate_appcast, generate_keys,
# sign_update). They come from a second artifact and land in
# Dependencies/build/sparkle-tools/. The tools install on every run, because the
# framework can be present while the tools are missing (#361).
#
# Uses the same binary artifact that the Swift Package Manager binary target
# would resolve — avoids SPM integration issues with Xcode 26+ pbxproj format.
#
# Usage: ./get-sparkle.sh [--clean]

set -euo pipefail
ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Dependencies/build-phases
SRCROOT="$(cd "$ROOTDIR/../.." && pwd)"               # project root (two up from build-phases)

# renovate: datasource=github-releases depName=sparkle-project/Sparkle
SPARKLE_VERSION="2.9.4"
# SHA-256 of the two artifacts for this version, computed from the 2.9.4 GitHub
# release (download, then `shasum -a 256`). Both land inside the notarized
# release, so a pinned checksum is what keeps the download honest. Re-pin both
# when bumping SPARKLE_VERSION: a renovate PR that bumps the version without
# updating these checksums fails the build instead of shipping an unverified
# artifact.
SPARKLE_FRAMEWORK_SHA256="cb6fdbdc8884f15d62a616e79face92b08322410fd2d425edc6596ccbf4ba3b0"  # Sparkle-for-Swift-Package-Manager.zip
SPARKLE_CLI_SHA256="ce89daf967db1e1893ed3ebd67575ed82d3902563e3191ca92aaec9164fbdef9"  # Sparkle-2.9.4.tar.xz
FRAMEWORK_DIR="$SRCROOT/Frameworks/Sparkle.framework"
CLI_DIR="$SRCROOT/Dependencies/build/sparkle-tools"
FRAMEWORK_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip"
CLI_TARBALL_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [ "${1:-}" = "--clean" ]; then
    echo "Removing $FRAMEWORK_DIR and $CLI_DIR"
    rm -rf "$FRAMEWORK_DIR" "$CLI_DIR"
fi

install_framework() {
    echo "Downloading Sparkle $SPARKLE_VERSION from $FRAMEWORK_URL"
    curl -fL -o "$TEMP_DIR/sparkle.zip" "$FRAMEWORK_URL"
    echo "$SPARKLE_FRAMEWORK_SHA256  $TEMP_DIR/sparkle.zip" | shasum -a 256 -c -

    echo "Extracting Sparkle XCFramework"
    unzip -q -d "$TEMP_DIR" "$TEMP_DIR/sparkle.zip"

    local extracted
    extracted="$(find "$TEMP_DIR" -name "Sparkle.xcframework" -type d -print -quit)"
    if [ -z "$extracted" ]; then
        echo "Error: Could not find Sparkle.xcframework in the downloaded archive" >&2
        exit 1
    fi

    echo "Installing Sparkle.framework to $FRAMEWORK_DIR"
    cp -R "$extracted/macos-arm64_x86_64/Sparkle.framework" "$FRAMEWORK_DIR"
    echo "Sparkle.framework installed successfully ($(file "$FRAMEWORK_DIR/Sparkle" | sed 's/.*://'))"
}

install_cli_tools() {
    echo "Downloading Sparkle $SPARKLE_VERSION CLI tools (generate_appcast, generate_keys, sign_update)"
    mkdir -p "$CLI_DIR"
    curl -f#L -o "$TEMP_DIR/sparkle.tar.xz" "$CLI_TARBALL_URL"
    echo "$SPARKLE_CLI_SHA256  $TEMP_DIR/sparkle.tar.xz" | shasum -a 256 -c -
    tar -xJf "$TEMP_DIR/sparkle.tar.xz" -C "$TEMP_DIR"

    local bin_dir
    bin_dir="$(find "$TEMP_DIR" -path "*/bin" -type d -print -quit)"
    if [ -z "$bin_dir" ]; then
        echo "Error: Could not find bin/ directory in the Sparkle distribution archive" >&2
        exit 1
    fi

    cp "$bin_dir/generate_appcast" "$bin_dir/generate_keys" "$bin_dir/sign_update" "$CLI_DIR/"
    echo "Sparkle CLI tools installed to $CLI_DIR"
}

if [ -d "$FRAMEWORK_DIR" ]; then
    echo "Sparkle.framework already present at $FRAMEWORK_DIR"
    echo "Pass --clean to re-download."
else
    install_framework
fi

# The appcast lane signs releases with these tools. Install them on every run,
# because a restored framework does not imply the tools are present (#361).
if [ -x "$CLI_DIR/generate_appcast" ] && [ -x "$CLI_DIR/generate_keys" ] && [ -x "$CLI_DIR/sign_update" ]; then
    echo "Sparkle CLI tools already present at $CLI_DIR"
else
    install_cli_tools
fi
