#!/bin/bash -eu
# build-libotr.sh — Build libotr as universal framework (OTR encryption)
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBOTR_VERSION="4.1.1"
BUILD_LIBOTR_FILE="libotr-${BUILD_LIBOTR_VERSION}.tar.gz"
BUILD_LIBOTR_SHA256="8b3b182424251067a952fb4e6c7b95a21e644fbb27fbd5f8af2b2ed87ca419f5"

build_libotr() {
    # Ensure gcrypt (and gpg-error) are built in this sandbox first
    build_gcrypt

    local src_dir
    src_dir="$(vendored_extract "$BUILD_LIBOTR_FILE" "$BUILD_LIBOTR_SHA256" "libotr-$BUILD_LIBOTR_VERSION")"

    cd "$src_dir"

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --with-libgcrypt-prefix="$SANDBOX" \
        --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_libotr_phase() {
    echo "=== Phase: libotr $BUILD_LIBOTR_VERSION ==="
    build_for_archs build_libotr "libotr.5.dylib"
    build_framework "libotr" "libotr" "$BUILD_DIR/lib/libotr.5.dylib" \
        "$SANDBOX_X86_64/include/libotr"
}
