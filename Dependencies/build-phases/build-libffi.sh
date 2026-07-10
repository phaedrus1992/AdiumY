#!/bin/bash -eu
# build-libffi.sh — Build libffi as universal framework (glib dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBFFI_VERSION="3.6.0"
BUILD_LIBFFI_FILE="libffi-${BUILD_LIBFFI_VERSION}.tar.gz"
BUILD_LIBFFI_SHA256="31ff1fe32deaebfbb388727f32677bb254bf2a41382c51464c0b1837c9ee9828"

build_libffi() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_LIBFFI_FILE" "$BUILD_LIBFFI_SHA256" "libffi-$BUILD_LIBFFI_VERSION")"

    cd "$src_dir"

    # Clean artifacts from previous arch build (shared source tree)
    make clean 2>/dev/null || true

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --disable-docs --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_libffi_phase() {
    echo "=== Phase: libffi $BUILD_LIBFFI_VERSION ==="
    skip_cached "libffi" "$BUILD_LIBFFI_SHA256" && return 0
    build_for_archs build_libffi "libffi.8.dylib"
    # No headers in the framework: ffitarget.h is arch-specific and only
    # glib's build consumes it (from the per-arch sandbox).
    build_framework "libffi" "libffi" "$BUILD_DIR/lib/libffi.8.dylib" "" "$BUILD_LIBFFI_VERSION"
    write_cache "libffi" "$BUILD_LIBFFI_SHA256"
}
