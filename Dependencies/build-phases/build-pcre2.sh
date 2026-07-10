#!/bin/bash -eu
# build-pcre2.sh — Build pcre2 (8-bit, unicode) as universal framework (glib dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_PCRE2_VERSION="10.47"
BUILD_PCRE2_FILE="pcre2-${BUILD_PCRE2_VERSION}.tar.bz2"
BUILD_PCRE2_SHA256="47fe8c99461250d42f89e6e8fdaeba9da057855d06eb7fc08d9ca03fd08d7bc7"

build_pcre2() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_PCRE2_FILE" "$BUILD_PCRE2_SHA256" "pcre2-$BUILD_PCRE2_VERSION")"

    cd "$src_dir"

    # Clean artifacts from previous arch build (shared source tree)
    make clean 2>/dev/null || true

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 \
        --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_pcre2_phase() {
    echo "=== Phase: pcre2 $BUILD_PCRE2_VERSION ==="
    build_for_archs build_pcre2 "libpcre2-8.0.dylib"
    build_framework "libpcre2-8" "libpcre2-8" "$BUILD_DIR/lib/libpcre2-8.0.dylib" "" "$BUILD_PCRE2_VERSION"

    # Copy pcre2 headers to build dir so glib's meson can find pcre2.h
    if [ -d "$SANDBOX_X86_64/include" ]; then
        mkdir -p "$BUILD_DIR/include"
        cp -R "$SANDBOX_X86_64/include/"pcre2*.h "$BUILD_DIR/include/" 2>/dev/null || true
    fi
}
