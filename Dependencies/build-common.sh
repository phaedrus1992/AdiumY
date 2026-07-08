#!/bin/bash -eu
# build-common.sh — Shared utilities for universal dependency builds
# Sourced by build-universal-deps.sh

set -o pipefail

# ---- Configuration ----
# Resolve ROOTDIR to the Dependencies/ directory
# BASH_SOURCE works when sourced from a script, $0 when run directly
THIS_SRC="${BASH_SOURCE[0]:-$0}"
ROOTDIR="$(cd "$(dirname "$THIS_SRC")" 2>/dev/null && pwd)"
# Verify: if we found build-common.sh, we're good
if [ ! -f "$ROOTDIR/build-common.sh" ]; then
    # Try as if sourced from repo root
    ROOTDIR="$(cd "$(dirname "$THIS_SRC")/Dependencies" 2>/dev/null && pwd)"
fi
if [ ! -f "$ROOTDIR/build-common.sh" ]; then
    echo "ERROR: Cannot find build-common.sh. ROOTDIR=$ROOTDIR" >&2
    exit 1
fi
SRCROOT="$(cd "$ROOTDIR/.." && pwd)"
BUILD_DIR="$ROOTDIR/build"
SANDBOX_X86_64="$ROOTDIR/sandbox-x86_64"
SANDBOX_ARM64="$ROOTDIR/sandbox-arm64"
SDK_DIR="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VER="11.0"
NUM_JOBS="$(sysctl -n hw.activecpu 2>/dev/null || echo 4)"

# ---- Architecture triples ----
HOST_X86_64="x86_64-apple-darwin"
HOST_ARM64="aarch64-apple-darwin"

# ---- Cleanup ----
cleanup_build_dirs() {
    rm -rf "$SANDBOX_X86_64" "$SANDBOX_ARM64"
}

# ---- Per-arch build environment ----
set_build_env() {
    local arch="$1"
    local sdk="$SDK_DIR"
    local min_ver="$SDK_VER"

    export CC="clang"
    export CXX="clang++"
    export CFLAGS="-arch $arch -mmacosx-version-min=$min_ver -isysroot $sdk -O2"
    export CXXFLAGS="-arch $arch -mmacosx-version-min=$min_ver -isysroot $sdk -O2"
    export LDFLAGS="-arch $arch -mmacosx-version-min=$min_ver -isysroot $sdk"
    export OBJCFLAGS="-arch $arch -mmacosx-version-min=$min_ver -isysroot $sdk"

    export ARCH="$arch"
    if [ "$arch" = "x86_64" ]; then
        export HOST_TRIPLE="$HOST_X86_64"
        export SANDBOX="$SANDBOX_X86_64"
    else
        export HOST_TRIPLE="$HOST_ARM64"
        export SANDBOX="$SANDBOX_ARM64"
    fi

    # Meson places LDFLAGS before dependency -l flags but cross-file c_link_args
    # after them. Add -L paths here so meson (and autotools) can find libraries
    # in build- and sandbox-dir lib/ when a dependency like intl provides only
    # a bare -lintl flag without a search path.
    export LDFLAGS="$LDFLAGS -L$BUILD_DIR/lib -L$SANDBOX/lib"

    export PKG_CONFIG_PATH="$BUILD_DIR/lib/pkgconfig"
    export PATH="$BUILD_DIR/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}

# ---- Build a dependency for both architectures ----
# Usage: build_for_archs <build_function_name> <"dylib1 dylib2 ...">
# The build function is called twice: once per arch (with set_build_env already called)
build_for_archs() {
    local build_fn="$1"
    local dylibs="$2"
    local lib_dir="$BUILD_DIR/lib"

    mkdir -p "$lib_dir"

    for arch in x86_64 arm64; do
        echo "--- Building for $arch ---"
        set_build_env "$arch"
        rm -rf "$SANDBOX"
        mkdir -p "$SANDBOX"
        (cd "$SANDBOX" && "$build_fn") || { echo "  ERROR: $build_fn failed for $arch" >&2; return 1; }
        echo "--- $arch build complete ---"
    done

    echo "--- Creating universal binaries ---"
    for dylib in $dylibs; do
        local x86_dylib="$SANDBOX_X86_64/lib/$dylib"
        local arm_dylib="$SANDBOX_ARM64/lib/$dylib"
        local output="$lib_dir/$dylib"

        if [ -f "$x86_dylib" ] && [ -f "$arm_dylib" ]; then
            echo "  lipo: $dylib"
            lipo -create -arch x86_64 "$x86_dylib" -arch arm64 "$arm_dylib" -output "$output"
        elif [ -f "$x86_dylib" ]; then
            echo "  (single arch) $dylib"
            cp "$x86_dylib" "$output"
        else
            echo "  WARNING: $dylib not found in either sandbox" >&2
        fi
    done
    # Create .dylib symlinks (linker looks for libfoo.dylib, not libfoo.0.0.dylib)
    for dylib in "$lib_dir"/*.dylib; do
        [ -f "$dylib" ] || continue
        local name="$(basename "$dylib")"
        # Strip trailing version number: libfoo.X.dylib -> libfoo.dylib
        local bare="$(echo "$name" | sed 's/\.[0-9]\{1,\}\.dylib$/.dylib/')"
        if [ "$bare" != "$name" ] && [ ! -f "$lib_dir/$bare" ] && [ ! -L "$lib_dir/$bare" ]; then
            ln -sf "$name" "$lib_dir/$bare"
            echo "  symlink: $bare -> $name"
        fi
    done
    echo "--- Universal binaries done ---"
}

# ---- Create a .framework bundle ----
# Usage: build_framework <name> <binary_name> <dylib_path> <header_dir> [version]
build_framework() {
    local name="$1"        # e.g. "glib"
    local binary_name="$2" # e.g. "glib" (the file inside framework)
    local dylib_path="$3"  # path to the universal dylib
    local header_dir="$4"  # path to headers (or empty)
    local version="${5:-A}"

    local fw_dir="$SRCROOT/Frameworks/$name.framework"
    local ver_dir="$fw_dir/Versions/$version"

    echo "--- Creating framework: $name ---"

    mkdir -p "$ver_dir/Resources"
    mkdir -p "$ver_dir/Headers"

    # Copy binary
    if [ -f "$dylib_path" ]; then
        cp "$dylib_path" "$ver_dir/$binary_name"
        chmod 755 "$ver_dir/$binary_name"

        # Set install name
        install_name_tool -id \
            "@executable_path/../Frameworks/$name.framework/Versions/$version/$binary_name" \
            "$ver_dir/$binary_name" 2>/dev/null || true
    fi

    # Copy headers
    if [ -n "$header_dir" ] && [ -d "$header_dir" ]; then
        cp -R "$header_dir/" "$ver_dir/Headers/"
    fi

    # Create Info.plist
    local plist="$ver_dir/Resources/Info.plist"
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>$binary_name</string>
    <key>CFBundleIdentifier</key>
    <string>im.adium.$name</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$name</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
</dict>
</plist>
PLIST

    # Create symlinks
    ln -sfh "$version" "$fw_dir/Versions/Current"
    ln -sfh "Versions/Current/$binary_name" "$fw_dir/$binary_name"
    ln -sfh "Versions/Current/Headers" "$fw_dir/Headers"
    ln -sfh "Versions/Current/Resources" "$fw_dir/Resources"

    echo "--- Framework $name created ---"
}

# ---- Rewrite inter-framework dependency links ----
# Scans all framework binaries and rewrites SANDBOX/BUILD_DIR paths to
# @executable_path/../Frameworks/<dep>.framework/Versions/A/<dep>
# NOTE: macOS ships bash 3.2 (no declare -A), so this uses indexed arrays.
rewrite_dependency_links() {
    local frameworks_dir="$1"

    echo "--- Rewriting dependency links ---"

    # Collect framework names (indexed array, bash 3.2 compatible).
    # Substring match in the lookup loop handles dylib aliases natively
    # (e.g. "glib" matches "libglib-2.0"), no explicit alias map needed.
    local fw_names=()
    local fw fw_name
    for fw in "$frameworks_dir"/*.framework; do
        fw_name="$(basename "$fw" .framework)"
        fw_names+=("$fw_name")
    done

    for fw in "$frameworks_dir"/*.framework; do
        local name
        name="$(basename "$fw" .framework)"
        local binary="$fw/Versions/A/$name"

        if [ ! -f "$binary" ]; then
            continue
        fi

        # Get all dependency paths
        otool -L "$binary" 2>/dev/null | grep -v ':' | grep -v '/usr/lib/' | \
            grep -v '/System/' | grep -v '@executable_path' | \
            while read -r line; do
            local dep_path
            dep_path="$(echo "$line" | awk '{print $1}')"
            if [ -z "$dep_path" ]; then continue; fi

            # Check if this path matches a known framework
            local fw_name
            for fw_name in "${fw_names[@]}"; do
                if echo "$dep_path" | grep -q "$fw_name"; then
                    local new_path="@executable_path/../Frameworks/$fw_name.framework/Versions/A/$fw_name"
                    if [ "$dep_path" != "$new_path" ]; then
                        install_name_tool -change "$dep_path" "$new_path" "$binary" 2>/dev/null || true
                        echo "  $binary: $dep_path -> $new_path"
                    fi
                    break
                fi
            done
        done
    done

    echo "--- Dependency rewriting done ---"
}

# ---- Extract a vendored source tarball ----
# Usage: vendored_extract <filename> <sha256> <expected_dirname>
# Reads Dependencies/vendor/<filename>; the build never downloads.
# Returns: path to extracted source directory
vendored_extract() {
    local filename="$1"
    local sha256="$2"
    local expected_dirname="$3"
    local tarball="$ROOTDIR/vendor/$filename"
    local extract_dir="$ROOTDIR/.cache/src"

    if [ ! -f "$tarball" ]; then
        echo "  ERROR: missing vendored source $tarball" >&2
        echo "  Fetch it once with: Dependencies/vendor-fetch.sh <url> $sha256" >&2
        return 1
    fi

    local actual
    actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"
    if [ "$actual" != "$sha256" ]; then
        echo "  ERROR: SHA256 mismatch for $filename: expected $sha256, got $actual" >&2
        return 1
    fi

    mkdir -p "$extract_dir"
    rm -rf "$extract_dir/$expected_dirname"
    echo "  Extracting $filename..." >&2
    case "$filename" in
        *.tar.gz|*.tgz) tar -xzf "$tarball" -C "$extract_dir" ;;
        *.tar.xz)       tar -xJf "$tarball" -C "$extract_dir" ;;
        *.tar.bz2)      tar -xjf "$tarball" -C "$extract_dir" ;;
        *)              echo "  ERROR: unknown archive format: $filename" >&2; return 1 ;;
    esac

    local src_path="$extract_dir/$expected_dirname"
    if [ ! -d "$src_path" ]; then
        echo "  ERROR: expected source dir $src_path not found" >&2
        ls "$extract_dir" >&2
        return 1
    fi
    echo "$src_path"
}