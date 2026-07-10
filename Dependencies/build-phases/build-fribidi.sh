#!/bin/bash -eu
# build-fribidi.sh — Build GNU FriBidi as universal framework (bidirectional text)
# Shell function, sourced by build-universal-deps.sh

BUILD_FRIBIDI_VERSION="1.0.16"
BUILD_FRIBIDI_FILE="fribidi-${BUILD_FRIBIDI_VERSION}.tar.xz"
BUILD_FRIBIDI_SHA256="1b1cde5b235d40479e91be2f0e88a309e3214c8ab470ec8a2744d82a5a9ea05c"

build_fribidi() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_FRIBIDI_FILE" "$BUILD_FRIBIDI_SHA256" "fribidi-$BUILD_FRIBIDI_VERSION")"

    cd "$src_dir"

    # Clean artifacts from previous arch build (shared source tree)
    make clean 2>/dev/null || true

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_fribidi_phase() {
    echo "=== Phase: FriBidi $BUILD_FRIBIDI_VERSION ==="
    build_for_archs build_fribidi "libfribidi.0.dylib"

    # Stage headers from sandbox so framework doesn't reference ephemeral paths
    mkdir -p "$BUILD_DIR/staging/fribidi"
    cp -R "$SANDBOX_X86_64/include/fribidi"/ "$BUILD_DIR/staging/fribidi/" 2>/dev/null || true
    build_framework "FriBidi" "FriBidi" "$BUILD_DIR/lib/libfribidi.0.dylib" \
        "$BUILD_DIR/staging/fribidi" "$BUILD_FRIBIDI_VERSION"
}
