#!/bin/bash -eu
# build-lmx.sh — Build LMX as universal framework (reverse XML parser)
# Shell function, sourced by build-universal-deps.sh

BUILD_LMX_VERSION="1.0"
BUILD_LMX_FILE="LMX-1.0.tbz"
BUILD_LMX_SHA256="91adf3fa39b89d8716ed73cae51830c67bc98102e148d4b66bab1b62f99e5355"

build_lmx() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_LMX_FILE" "$BUILD_LMX_SHA256" "LMX-1.0")"

    mkdir -p "$SANDBOX/lib"
    mkdir -p "$SANDBOX/include/lmx"

    clang -dynamiclib -fno-objc-arc \
        -arch "$ARCH" -mmacosx-version-min="$SDK_VER" -isysroot "$SDK_DIR" \
        -O2 -include Foundation/Foundation.h -framework Foundation \
        -install_name @rpath/LMX.framework/Versions/A/LMX \
        -o "$SANDBOX/lib/libLMX.dylib" \
        "$src_dir/LMXParser.m" \
        "$src_dir/LMXMutableDataAdditions.m" \
        "$src_dir/LMXMutableStringAdditions.m"

    # Copy public headers for staging
    cp "$src_dir/LMXParser.h" "$SANDBOX/include/lmx/"
    cp "$src_dir/LMXMutableDataAdditions.h" "$SANDBOX/include/lmx/"
    cp "$src_dir/LMXMutableStringAdditions.h" "$SANDBOX/include/lmx/"
}

build_lmx_phase() {
    echo "=== Phase: LMX $BUILD_LMX_VERSION ==="
    build_for_archs build_lmx "libLMX.dylib"

    # Stage headers from sandbox
    mkdir -p "$BUILD_DIR/staging/lmx"
    cp -R "$SANDBOX_X86_64/include/lmx"/ "$BUILD_DIR/staging/lmx/" 2>/dev/null || true
    build_framework "LMX" "LMX" "$BUILD_DIR/lib/libLMX.dylib" \
        "$BUILD_DIR/staging/lmx" "$BUILD_LMX_VERSION"
}
