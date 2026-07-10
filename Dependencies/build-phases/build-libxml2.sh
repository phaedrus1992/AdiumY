#!/bin/bash -eu
# build-libxml2.sh — Build libxml2 as universal framework (libpurple XMPP dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBXML2_VERSION="2.15.3"
BUILD_LIBXML2_FILE="libxml2-${BUILD_LIBXML2_VERSION}.tar.xz"
BUILD_LIBXML2_SHA256="78262a6e7ac170d6528ebfe2efccdf220191a5af6a6cd61ea4a9a9a5042c7a07"

build_libxml2() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_LIBXML2_FILE" "$BUILD_LIBXML2_SHA256" "libxml2-$BUILD_LIBXML2_VERSION")"

    cd "$src_dir"

    # Clean artifacts from previous arch build (shared source tree)
    make clean 2>/dev/null || true

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --without-python --without-lzma --without-icu \
        --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_libxml2_phase() {
    echo "=== Phase: libxml2 $BUILD_LIBXML2_VERSION ==="
    skip_cached "libxml2" "$BUILD_LIBXML2_SHA256" && return 0
    # Dylib name libxml2.16.dylib: libtool -version-info is CURRENT:MICRO:AGE with
    # CURRENT=major+minor=17, AGE=minor-compat=1, so suffix = CURRENT-AGE = 16
    # (verified in the 2.15.3 configure.ac).
    build_for_archs build_libxml2 "libxml2.16.dylib"

    # Stage headers from sandbox so framework doesn't reference ephemeral paths
    mkdir -p "$BUILD_DIR/staging/libxml2"
    cp -R "$SANDBOX_X86_64/include/libxml2"/ "$BUILD_DIR/staging/libxml2/" 2>/dev/null || true
    build_framework "libxml2" "libxml2" "$BUILD_DIR/lib/libxml2.16.dylib" \
        "$BUILD_DIR/staging/libxml2" "$BUILD_LIBXML2_VERSION"

    # Copy .pc file for downstream (libpurple) and fix prefix
    mkdir -p "$BUILD_DIR/lib/pkgconfig"
    cp "$SANDBOX_X86_64/lib/pkgconfig/libxml-2.0.pc" "$BUILD_DIR/lib/pkgconfig/"
    sed -i '' "s|$SANDBOX_X86_64|$BUILD_DIR|g" "$BUILD_DIR/lib/pkgconfig/libxml-2.0.pc"
    mkdir -p "$BUILD_DIR/include"
    cp -R "$SANDBOX_X86_64/include/libxml2" "$BUILD_DIR/include/"
    write_cache "libxml2" "$BUILD_LIBXML2_SHA256"
}
