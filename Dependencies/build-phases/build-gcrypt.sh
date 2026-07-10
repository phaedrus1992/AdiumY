#!/bin/bash -eu
# build-gcrypt.sh — Build libgcrypt as universal framework (libotr dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_GCRYPT_VERSION="1.12.2"
BUILD_GCRYPT_FILE="libgcrypt-${BUILD_GCRYPT_VERSION}.tar.bz2"
BUILD_GCRYPT_SHA256="7ce33c2492221a0436f96a8500215e9f3e3dcb5fd26a757cd415e7a843babd5e"

build_gcrypt() {
    # Ensure gpg-error is built in this sandbox first (needed for --only=gcrypt)
    build_gpg_error

    local src_dir
    src_dir="$(vendored_extract "$BUILD_GCRYPT_FILE" "$BUILD_GCRYPT_SHA256" "libgcrypt-$BUILD_GCRYPT_VERSION")"

    cd "$src_dir"

    # Clean artifacts from previous arch build (shared source tree)
    make clean 2>/dev/null || true

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --disable-doc \
        --with-libgpg-error-prefix="$SANDBOX" \
        --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_gcrypt_phase() {
    echo "=== Phase: libgcrypt $BUILD_GCRYPT_VERSION ==="
    skip_cached "gcrypt" "$BUILD_GCRYPT_SHA256" && return 0
    build_for_archs build_gcrypt "libgcrypt.20.dylib"

    # Stage gcrypt headers so framework provides them for the Adium target
    mkdir -p "$BUILD_DIR/staging/gcrypt"
    cp "$SANDBOX_X86_64/include/"gcrypt*.h "$BUILD_DIR/staging/gcrypt/" 2>/dev/null || true
    build_framework "libgcrypt" "libgcrypt" "$BUILD_DIR/lib/libgcrypt.20.dylib" \
        "$BUILD_DIR/staging/gcrypt" "$BUILD_GCRYPT_VERSION"
    write_cache "gcrypt" "$BUILD_GCRYPT_SHA256"
}
