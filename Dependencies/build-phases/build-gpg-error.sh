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
    build_for_archs build_gpg_error "libgpg-error.0.dylib"
    build_framework "libgpg-error" "libgpg-error" "$BUILD_DIR/lib/libgpg-error.0.dylib" ""
}
