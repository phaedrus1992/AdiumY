#!/bin/bash -eu
# build-libpurple.sh — Build vanilla upstream libpurple (from Pidgin) as universal
# framework with static prpls: jabber, irc, simple.
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBPURPLE_VERSION="2.14.14"
BUILD_LIBPURPLE_FILE="pidgin-${BUILD_LIBPURPLE_VERSION}.tar.bz2"
BUILD_LIBPURPLE_SHA256="0ffc9994def10260f98a55cd132deefa8dc4a9835451cc0e982747bd458e2356"

build_libpurple() {
    # Source already extracted in build_libpurple_phase(); LIBPURPLE_SRC is set there.
    # build_for_archs runs build functions in a subshell, so vars set inside don't
    # propagate — the extract MUST happen in the caller scope.
    cd "$LIBPURPLE_SRC"

    # Clean artifacts from the previous arch build. Both arch builds share
    # the same extracted source tree; without this, make (with
    # --disable-dependency-tracking) sees .o files as up-to-date and skips
    # recompilation for the second arch, producing wrong-arch binaries.
    make clean 2>/dev/null || true

    export PKG_CONFIG_PATH="$SANDBOX/lib/pkgconfig:$BUILD_DIR/lib/pkgconfig"
    export LIBXML_CFLAGS="-I$BUILD_DIR/include/libxml2"
    export LIBXML_LIBS="-L$BUILD_DIR/lib -lxml2"

    ./configure --prefix="$SANDBOX" \
        --disable-dependency-tracking \
        --disable-static --enable-shared \
        --disable-gtkui --disable-consoleui \
        --disable-perl --disable-tcl \
        --with-static-prpls=jabber,irc,simple \
        --disable-plugins \
        --disable-avahi --disable-dbus \
        --enable-gnutls=no --enable-nss=no \
        --disable-cyrus-sasl \
        --disable-vv --disable-gstreamer --disable-farstream \
        --disable-meanwhile \
        --disable-idn --disable-nls --disable-doxygen \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_libpurple_phase() {
    echo "=== Phase: libpurple $BUILD_LIBPURPLE_VERSION ==="
    skip_cached "libpurple" "$BUILD_LIBPURPLE_SHA256" && return 0

    # Extract here (outer scope) so LIBPURPLE_SRC survives build_for_archs's subshell.
    local src_dir
    src_dir="$(vendored_extract "$BUILD_LIBPURPLE_FILE" "$BUILD_LIBPURPLE_SHA256" "pidgin-$BUILD_LIBPURPLE_VERSION")"
    LIBPURPLE_SRC="$src_dir"

    build_for_archs build_libpurple "libpurple.0.dylib"

    # Stage headers from sandbox so framework doesn't reference ephemeral paths
    mkdir -p "$BUILD_DIR/staging/libpurple"
    cp -R "$SANDBOX_X86_64/include/libpurple"/ "$BUILD_DIR/staging/libpurple/" 2>/dev/null || true
    build_framework "libpurple" "libpurple" "$BUILD_DIR/lib/libpurple.0.dylib" \
        "$BUILD_DIR/staging/libpurple" "$BUILD_LIBPURPLE_VERSION"

    # Purple Service imports internal + prpl headers not installed by `make install`.
    # Copy them from the source tree (same set the old fork's build shipped, minus
    # dead protocols).
    local src="${LIBPURPLE_SRC}/libpurple"
    local hdr="$SRCROOT/Frameworks/libpurple.framework/Versions/A/Headers"
    cp "$src/internal.h" "$src/cmds.h" "$hdr/"
    cp "$src/protocols/jabber/auth.h" "$src/protocols/jabber/bosh.h" \
       "$src/protocols/jabber/buddy.h" "$src/protocols/jabber/caps.h" \
       "$src/protocols/jabber/chat.h" \
       "$src/protocols/jabber/jutil.h" "$src/protocols/jabber/presence.h" \
       "$src/protocols/jabber/si.h" "$src/protocols/jabber/jabber.h" \
       "$src/protocols/jabber/iq.h" "$src/protocols/jabber/namespaces.h" \
       "$hdr/"
    cp "$src/protocols/irc/irc.h" "$hdr/"
    write_cache "libpurple" "$BUILD_LIBPURPLE_SHA256"
}
