#!/bin/bash -eu
# build-gpg-error.sh — Build libgpg-error as universal framework (libgcrypt dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_GPGERROR_VERSION="1.61"
BUILD_GPGERROR_FILE="libgpg-error-${BUILD_GPGERROR_VERSION}.tar.bz2"
BUILD_GPGERROR_SHA256="7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93"

build_gpg_error() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_GPGERROR_FILE" "$BUILD_GPGERROR_SHA256" "libgpg-error-$BUILD_GPGERROR_VERSION")"

    cd "$src_dir"

    # Clean artifacts from previous arch build (shared source tree)
    make clean 2>/dev/null || true

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --disable-doc --disable-tests \
        --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_gpg_error_phase() {
    echo "=== Phase: libgpg-error $BUILD_GPGERROR_VERSION ==="
    skip_cached "gpg-error" "$BUILD_GPGERROR_SHA256" && return 0
    build_for_archs build_gpg_error "libgpg-error.0.dylib"

    # Stage gpg-error headers so framework provides them for the Adium target
    mkdir -p "$BUILD_DIR/staging/gpg-error"
    cp "$SANDBOX_X86_64/include/"gpg-error*.h "$BUILD_DIR/staging/gpg-error/" 2>/dev/null || true
    build_framework "libgpg-error" "libgpg-error" "$BUILD_DIR/lib/libgpg-error.0.dylib" \
        "$BUILD_DIR/staging/gpg-error" "$BUILD_GPGERROR_VERSION"
    write_cache "gpg-error" "$BUILD_GPGERROR_SHA256"
}
