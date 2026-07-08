#!/bin/bash -eu
# build-universal-deps.sh — Build Adium's Unix dependencies as universal (x86_64+arm64) frameworks
#
# Downloads source tarballs (SHA256-verified), builds for both architectures,
# creates .framework bundles in Frameworks/, and rewrites install_name references.
#
# Usage: ./build-universal-deps.sh [--clean] [--build-dir=<dir>]
#
# Flags:
#   --clean        Remove all cached source and build artifacts before building
#   --build-dir=<dir>  Override build output directory (default: Dependencies/build/)

set -o pipefail

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCROOT="$(cd "$ROOTDIR/.." && pwd)"

# ---- Parse flags ----
CLEAN=0
ONLY_PHASE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --clean) CLEAN=1 ;;
        --build-dir=*) BUILD_DIR_OVERRIDE="${1#*=}" ;;
        --only=*) ONLY_PHASE="${1#*=}" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# ---- Source infrastructure ----
source "$ROOTDIR/build-common.sh"

# ---- Source build phases ----
source "$ROOTDIR/build-phases/build-libffi.sh"
source "$ROOTDIR/build-phases/build-gettext.sh"
source "$ROOTDIR/build-phases/build-pcre2.sh"
source "$ROOTDIR/build-phases/build-glib.sh"
source "$ROOTDIR/build-phases/build-libxml2.sh"
source "$ROOTDIR/build-phases/build-gpg-error.sh"
source "$ROOTDIR/build-phases/build-gcrypt.sh"
source "$ROOTDIR/build-phases/build-libotr.sh"
source "$ROOTDIR/build-phases/build-libpurple.sh"

# More phases will be added here as they're implemented

# ---- Cleanup ----
if [ "$CLEAN" -eq 1 ]; then
    echo "=== Cleaning build artifacts ==="
    rm -rf "$ROOTDIR/.cache" "$ROOTDIR/build" "$ROOTDIR/sandbox-x86_64" "$ROOTDIR/sandbox-arm64"
    echo "Done."
    exit 0
fi

# ---- Build ----
echo "=== Build Universal Dependencies ==="
echo "Build dir: $BUILD_DIR"
echo "Source cache: $ROOTDIR/.cache"
echo ""

run_phase() {
    local name="$1" fn="$2"
    if [ -z "$ONLY_PHASE" ] || [ "$ONLY_PHASE" = "$name" ]; then
        "$fn"
    fi
}

# Phase order matters: libffi -> gettext -> glib -> ... (each depends on the previous)
run_phase libffi build_libffi_phase
run_phase gettext build_gettext_phase
run_phase pcre2 build_pcre2_phase
run_phase glib build_glib_phase
run_phase libxml2 build_libxml2_phase
run_phase gpg-error build_gpg_error_phase
run_phase gcrypt build_gcrypt_phase
run_phase libotr build_libotr_phase
run_phase libpurple build_libpurple_phase

# ---- Rewrite dependency links ----
echo ""
echo "=== Rewriting framework dependency links ==="
rewrite_dependency_links "$SRCROOT/Frameworks"

# ---- Cleanup sandboxes ----
echo ""
echo "=== Cleaning up ==="
cleanup_build_dirs

echo ""
echo "=== Build complete ==="
echo "Frameworks in: $SRCROOT/Frameworks/"
echo ""
echo "Frameworks built:"
for fw in "$SRCROOT/Frameworks"/*.framework; do
    name="$(basename "$fw" .framework)"
    binary=""
    if [ -f "$fw/Versions/A/$name" ]; then
        binary="$fw/Versions/A/$name"
    elif [ -f "$fw/Versions/A/lib$name" ]; then
        binary="$fw/Versions/A/lib$name"
    fi
    if [ -n "$binary" ] && [ -f "$binary" ]; then
        archs="$(lipo -info "$binary" 2>/dev/null | grep -o 'are:.*' | cut -d' ' -f2- || echo 'unknown')"
        echo "  $name.framework ($archs)"
    else
        echo "  $name.framework (no binary)"
    fi
done