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

# ---- Dependency Map ----
# Maps dylib basename → framework name → binary name.
# Three parallel indexed arrays (bash 3.2 compatible, no associative arrays).
# Used by build_framework to rewrite inter-framework dependency paths to @rpath.
readonly DYLIB_MAP_DYLIB=(
    "libffi.8.dylib"
    "libintl.8.dylib"
    "libglib-2.0.0.dylib"
    "libgmodule-2.0.0.dylib"
    "libgobject-2.0.0.dylib"
    "libgthread-2.0.0.dylib"
    "libgio-2.0.0.dylib"
    "libpcre2-8.0.dylib"
    "libxml2.16.dylib"
    "libgpg-error.0.dylib"
    "libgcrypt.20.dylib"
    "libotr.5.dylib"
    "libpurple.0.dylib"
)
readonly DYLIB_MAP_FRAMEWORK=(
    "libffi" "libintl" "glib" "libgmodule" "libgobject" "libgthread" "libgio"
    "libpcre2-8" "libxml2" "libgpg-error" "libgcrypt" "libotr" "libpurple"
)
readonly DYLIB_MAP_BINARY=(
    "libffi" "libintl" "glib" "libgmodule" "libgobject" "libgthread" "libgio"
    "libpcre2-8" "libxml2" "libgpg-error" "libgcrypt" "libotr" "libpurple"
)

# Look up framework name for a dylib basename.
# Usage: fw="$(_lookup_framework "libfoo.X.dylib")" || fw=""
_lookup_framework() {
    local dylib="$1" i
    for i in "${!DYLIB_MAP_DYLIB[@]}"; do
        if [ "${DYLIB_MAP_DYLIB[$i]}" = "$dylib" ]; then
            echo "${DYLIB_MAP_FRAMEWORK[$i]}"
            return 0
        fi
    done
    return 1
}

# Look up binary name for a dylib basename.
_lookup_binary() {
    local dylib="$1" i
    for i in "${!DYLIB_MAP_DYLIB[@]}"; do
        if [ "${DYLIB_MAP_DYLIB[$i]}" = "$dylib" ]; then
            echo "${DYLIB_MAP_BINARY[$i]}"
            return 0
        fi
    done
    return 1
}

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
    export LDFLAGS="-arch $arch -mmacosx-version-min=$min_ver -isysroot $sdk -Wl,-headerpad_max_install_names"
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
        [ -L "$dylib" ] && continue   # guard: skip symlinks from a prior run to avoid junk chains
        local name
        name="$(basename "$dylib")"
        # Strip trailing version number: libfoo.X.dylib -> libfoo.dylib
        local bare
        bare="$(echo "$name" | sed 's/\.[0-9]\{1,\}\.dylib$/.dylib/')"
        if [ "$bare" != "$name" ] && [ ! -f "$lib_dir/$bare" ] && [ ! -L "$lib_dir/$bare" ]; then
            ln -sf "$name" "$lib_dir/$bare"
            echo "  symlink: $bare -> $name"
        fi
    done
    echo "--- Universal binaries done ---"
}

# ---- Create a .framework bundle ----
# Creates a complete, self-contained, relocatable framework bundle.
# Usage: build_framework <name> <binary_name> <dylib_path> <header_dir> [version]
# The version defaults to "A" but phases should pass their library version
# (e.g. "1.12.2") so Info.plist carries the real version.
build_framework() {
    local name="$1"        # e.g. "glib"
    local binary_name="$2" # e.g. "glib" (the file inside framework)
    local dylib_path="$3"  # path to the universal dylib
    local header_dir="$4"  # path to headers (or empty string)
    local version="${5:-A}"

    local fw_dir="$SRCROOT/Frameworks/$name.framework"
    local ver_dir="$fw_dir/Versions/A"

    echo "--- Creating framework: $name (v$version) ---"

    # Idempotent: remove any stale bundle before building
    rm -rf "$fw_dir"
    mkdir -p "$ver_dir/Resources" "$ver_dir/Headers"

    # ---- Binary ----
    if [ -f "$dylib_path" ]; then
        cp "$dylib_path" "$ver_dir/$binary_name"
        chmod 755 "$ver_dir/$binary_name"

        # Set @rpath-based install name (relocatable, matches consumer rpaths)
        install_name_tool -id \
            "@rpath/$name.framework/Versions/A/$binary_name" \
            "$ver_dir/$binary_name"

        # ---- Rewrite inter-framework dependency links ----
        # Collect all non-system, non-@rpath dependency paths from otool -L.
        # For each one, look up the dylib basename in DYLIB_MAP: mapped deps get
        # rewritten to @rpath/<fw>.framework/Versions/<ver>/<bin>; unmapped
        # absolute paths (which should never exist for our vendored deps) fail
        # the phase loudly.
        local dep_path dylib_basename fw_lookup bin_lookup new_path has_errors
        has_errors=0

        while IFS= read -r line; do
            dep_path="$(echo "$line" | awk '{print $1}')"
            [ -z "$dep_path" ] && continue

            dylib_basename="$(basename "$dep_path")"
            fw_lookup="$(_lookup_framework "$dylib_basename")" || true

            if [ -n "$fw_lookup" ]; then
                bin_lookup="$(_lookup_binary "$dylib_basename")"
                new_path="@rpath/${fw_lookup}.framework/Versions/A/${bin_lookup}"
                if [ "$dep_path" != "$new_path" ]; then
                    install_name_tool -change "$dep_path" "$new_path" "$ver_dir/$binary_name"
                    echo "  $binary_name: $dep_path -> $new_path"
                fi
            else
                # Only fail on absolute paths (these are build-system leaks).
                # System paths, @rpath, @loader_path, and leaf names are fine.
                case "$dep_path" in
                    /*)
                        echo "  ERROR: unmapped absolute dependency $dep_path in $binary_name" >&2
                        has_errors=1
                        ;;
                esac
            fi
        done < <(
            otool -L "$ver_dir/$binary_name" 2>/dev/null | \
            grep -v ':' | grep -v '/usr/lib/' | grep -v '/System/' | \
            grep -v '@rpath' | grep -v '@executable_path'
        )

        if [ "$has_errors" -ne 0 ]; then
            return 1
        fi

        # Re-sign after install_name_tool edits (arm64 macOS kills unsigned edits)
        codesign -f -s - "$ver_dir/$binary_name"
    fi

    # ---- Headers ----
    # cp -RL dereferences symlinks so no absolute symlinks leak into bundles
    if [ -n "$header_dir" ] && [ -d "$header_dir" ]; then
        cp -RL "$header_dir/" "$ver_dir/Headers/"
    fi

    # ---- Info.plist ----
    local plist_version="$version"
    if [ "$version" = "A" ]; then
        plist_version="1.0"
    fi
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
    <string>$plist_version</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>$plist_version</string>
</dict>
</plist>
PLIST
    plutil -lint "$plist" || { echo "  ERROR: Info.plist lint failed for $name" >&2; return 1; }

    # ---- Symlinks ----
    ln -sfh "A" "$fw_dir/Versions/Current"
    ln -sfh "Versions/Current/$binary_name" "$fw_dir/$binary_name"
    ln -sfh "Versions/Current/Headers" "$fw_dir/Headers"
    ln -sfh "Versions/Current/Resources" "$fw_dir/Resources"

    echo "--- Framework $name created ---"
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