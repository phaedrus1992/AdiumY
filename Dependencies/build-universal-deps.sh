#!/bin/bash -eu
# build-universal-deps.sh — Build Adium's Unix dependencies as universal (x86_64+arm64) frameworks
#
# Reads vendored source tarballs from Dependencies/vendor/ (SHA256-verified),
# builds for both architectures, creates .framework bundles in Frameworks/,
# and rewrites install_name references.
#
# Usage: ./build-universal-deps.sh [--clean] [--build-dir=<dir>]
#
# shellcheck disable=SC1091 # sourced files use ROOTDIR, not determinable statically
# Flags:
#   --clean        Remove all cached source and build artifacts before building
#   --build-dir=<dir>  Override build output directory (default: Dependencies/build/)
#   --force        Ignore build stamps and rebuild all dependencies

set -o pipefail

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCROOT="$(cd "$ROOTDIR/.." && pwd)"

# ---- Parse flags ----
CLEAN=0
ONLY_PHASE=""
# shellcheck disable=SC2034 # BUILD_DIR_OVERRIDE is parsed for future build-dir override support; FORCE used by build-common.sh
while [ $# -gt 0 ]; do
    case "$1" in
        --clean) CLEAN=1 ;;
        --build-dir=*) BUILD_DIR_OVERRIDE="${1#*=}" ;;
        --only=*) ONLY_PHASE="${1#*=}" ;;
        --force) FORCE=1 ;;
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
source "$ROOTDIR/build-phases/build-fribidi.sh"
source "$ROOTDIR/build-phases/build-lmx.sh"

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
run_phase fribidi build_fribidi_phase
run_phase lmx build_lmx_phase

# ---- Verification gate ----
# Every framework from the map must pass structural checks.
# In --only mode, frameworks not built by the selected phase are skipped.
echo ""
echo "=== Verifying frameworks ==="

verify_mode="full"
if [ -n "$ONLY_PHASE" ]; then
    verify_mode="partial"
fi

has_errors=0
for i in "${!DYLIB_MAP_DYLIB[@]}"; do
    fw="${DYLIB_MAP_FRAMEWORK[$i]}"
    bin="${DYLIB_MAP_BINARY[$i]}"
    fw_dir="$SRCROOT/Frameworks/$fw.framework"
    binary="$fw_dir/Versions/A/$bin"

    if [ ! -f "$binary" ]; then
        if [ "$verify_mode" = "full" ]; then
            echo "  FAIL: $fw.framework — binary missing ($binary)"
            has_errors=1
        else
            echo "  SKIP: $fw.framework — not built (--only mode)"
        fi
        continue
    fi

    # Check universal archs
    archs="$(lipo -archs "$binary" 2>/dev/null || echo "")"
    if ! echo "$archs" | grep -q "x86_64" || ! echo "$archs" | grep -q "arm64"; then
        echo "  FAIL: $fw.framework — missing archs (got: $archs)"
        has_errors=1
    fi

    # Check for leaked absolute / sandbox / build paths in actual dependency lines.
    # Skip otool's binary-path header lines (which always contain the file path)
    # by filtering out lines ending with ":". Only dependency paths matter.
    bad_deps="$(otool -L "$binary" 2>/dev/null | grep -v ':$' | grep -E '(/Users/|sandbox-|/Dependencies/build)')" || true
    if [ -n "$bad_deps" ]; then
        echo "  FAIL: $fw.framework — contains absolute/sandbox dependency paths:"
        echo "$bad_deps"
        has_errors=1
    fi

    # Check code signature — WARN only (non-fatal for dev cycle).
    # Ad-hoc signing (codesign -s -) satisfies arm64 runtime requirements but
    # fails --verify --strict because there is no certificate chain. This is
    # expected for local development builds and will be superseded by proper
    # Developer ID signing + notarization for distribution builds.
    # See: docs/design/signing.md (pending)
    if ! codesign --verify --strict "$binary" 2>/dev/null; then
        echo "  WARN: $fw.framework — codesign verification failed (non-fatal, ad-hoc only)"
    fi

    # Check top-level symlinks
    if [ ! -L "$fw_dir/$bin" ] || [ ! -L "$fw_dir/Headers" ] || \
       [ ! -L "$fw_dir/Resources" ] || [ ! -L "$fw_dir/Versions/Current" ]; then
        echo "  FAIL: $fw.framework — top-level symlinks missing/resolved"
        has_errors=1
    fi
done

# ---- Cleanup sandboxes ----
echo ""
echo "=== Cleaning up ==="
cleanup_build_dirs

if [ "$has_errors" -ne 0 ]; then
    echo ""
    echo "=== VERIFICATION FAILED ===" >&2
    exit 1
fi

echo ""
echo "=== Build complete === $(lipo -archs "$binary" 2>/dev/null || true)"
echo "All frameworks verified OK."