#!/bin/bash
# relink-sandbox-refs.sh — Post-link fixup for the AdiumY app bundle.
#
# The app and AdiumLibpurple link the vendored dylibs directly from
# Dependencies/build/lib (legacy upstream layout). Those dylibs carry per-arch
# staging paths (Dependencies/sandbox-*/lib/*.dylib) as their install names,
# which are dead after the universal-deps build merges them into frameworks.
# This phase, run last in the app target, before Xcode's final codesign:
#   1. Backfills any framework any bundle binary references that the Copy
#      Frameworks phase omits (self-heals a stale copy list).
#   2. Rewrites every Dependencies/sandbox-*/lib/*.dylib reference in the app
#      binary and in every bundled framework binary to its @rpath/<fw>.framework
#      equivalent.
#   3. Re-signs (ad-hoc) every binary it copies or edits; Xcode's final codesign
#      then seals the whole bundle.
# Fails loudly if any sandbox reference has no framework mapping.
#
# Mapping: keep in sync with Dependencies/build-common.sh DYLIB_MAP.

set -euo pipefail

# --- Environment (Xcode Run Script phase) -------------------------------------
[ -n "${TARGET_BUILD_DIR:-}" ] || { echo "relink: TARGET_BUILD_DIR not set (not a build phase?)" >&2; exit 1; }
[ -n "${WRAPPER_NAME:-}" ] || { echo "relink: WRAPPER_NAME not set" >&2; exit 1; }
[ -n "${EXECUTABLE_NAME:-}" ] || { echo "relink: EXECUTABLE_NAME not set" >&2; exit 1; }

APP_DIR="$TARGET_BUILD_DIR/$WRAPPER_NAME"
FW_DIR="$APP_DIR/Contents/Frameworks"
APP_BIN="$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
SRC_FRAMEWORKS="${SRCROOT:-.}/Frameworks"
PROD_FRAMEWORKS="${BUILT_PRODUCTS_DIR:-.}"

[ -d "$FW_DIR" ] || { echo "relink: no Frameworks dir in $APP_DIR" >&2; exit 1; }

# --- Map a sandbox dylib basename to its @rpath framework install name ---------
sandbox_to_rpath() {
    case "$1" in
        libglib-2.0.0.dylib)    echo "@rpath/glib.framework/Versions/A/glib" ;;
        libgmodule-2.0.0.dylib) echo "@rpath/libgmodule.framework/Versions/A/libgmodule" ;;
        libgobject-2.0.0.dylib) echo "@rpath/libgobject.framework/Versions/A/libgobject" ;;
        libgthread-2.0.0.dylib) echo "@rpath/libgthread.framework/Versions/A/libgthread" ;;
        libotr.5.dylib)         echo "@rpath/libotr.framework/Versions/A/libotr" ;;
        libintl.8.dylib)        echo "@rpath/libintl.framework/Versions/A/libintl" ;;
        libffi.8.dylib)         echo "@rpath/libffi.framework/Versions/A/libffi" ;;
        libgcrypt.20.dylib)     echo "@rpath/libgcrypt.framework/Versions/A/libgcrypt" ;;
        libgpg-error.0.dylib)   echo "@executable_path/../Frameworks/libgpg-error.framework/Versions/A/libgpg-error" ;;
        libfribidi.0.dylib)     echo "@rpath/FriBidi.framework/Versions/A/FriBidi" ;;
        *)                      echo "" ;;
    esac
}

# Every Mach-O framework binary in the bundle (versioned layout).
bundle_bins() {
    find "$FW_DIR" -path '*/Versions/*/*' -type f 2>/dev/null | while read -r f; do
        case "$f" in
            *Headers*|*.plist|*CodeResources*|*Resources/*) continue ;;
        esac
        if file "$f" 2>/dev/null | grep -q 'Mach-O'; then echo "$f"; fi
    done
}

# --- Every Mach-O binary that can reference an embedded framework --------------
all_bins() {
    { echo "$APP_BIN"; bundle_bins; }
}

# --- Embedded-framework refs of one binary (@rpath / @executable_path) ----------
# System framework refs (e.g. /System/Library/Frameworks/...) resolve from the
# OS and must not be backfilled, hence the leading ^@ filter.
embedded_fw_refs() {
    local line
    otool -L "$1" | awk 'NR>1 {print $1}' \
        | grep -E '^@(rpath|executable_path)/.*\.framework' \
        | sed -E 's#\.framework/.*#.framework#' \
        | sort -u | while IFS= read -r line; do basename "$line"; done || true
}

# --- Backfill any framework any bundle binary references but the Copy phase ---
# omits. Must run AFTER the sandbox refs are rewritten to @rpath form, or the
# grep below sees only absolute sandbox paths and copies nothing. Runs to a
# fixpoint: a backfilled framework (e.g. glib) may itself reference another
# omitted one (libpcre2-8), so a full pass with nothing copied signals done.
backfill_frameworks() {
    local fw bin changed=1
    while [ "$changed" -eq 1 ]; do
        changed=0
        while IFS= read -r bin; do
            for fw in $(embedded_fw_refs "$bin"); do
                if [ -d "$FW_DIR/$fw" ]; then continue; fi
                echo "relink: backfilling $fw"
                if [ -d "$SRC_FRAMEWORKS/$fw" ]; then
                    ditto "$SRC_FRAMEWORKS/$fw" "$FW_DIR/$fw"
                elif [ -d "$PROD_FRAMEWORKS/$fw" ]; then
                    ditto "$PROD_FRAMEWORKS/$fw" "$FW_DIR/$fw"
                else
                    echo "relink: $fw referenced by $bin but not found in $SRC_FRAMEWORKS or $PROD_FRAMEWORKS" >&2
                    exit 1
                fi
                codesign -f -s - "$FW_DIR/$fw"
                changed=1
            done
        done < <(all_bins)
    done
}

# --- Rewrite one binary's sandbox refs; re-sign if anything changed -------------
rewrite_bin() {
    local bin="$1" old new base any=0
    for old in $(otool -L "$bin" | awk 'NR>1 {print $1}' | grep "/Dependencies/sandbox-" || true); do
        base=$(basename "$old")
        new=$(sandbox_to_rpath "$base")
        if [ -z "$new" ]; then
            echo "relink: no framework mapping for $old (referenced by $bin)" >&2
            exit 1
        fi
        echo "relink: $bin: $old -> $new"
        install_name_tool -change "$old" "$new" "$bin"
        any=1
    done
    if [ "$any" -eq 1 ]; then
        codesign -f -s - "$bin"
    fi
}

# --- Refresh any embedded framework the Copy phase omits but never updates ---
# backfill_frameworks only fills gaps, so a framework embedded on a first build
# (e.g. AIUtilities) stays stale forever once its product changes. Overwrite any
# embedded framework whose build-product copy is newer before rewriting refs.
refresh_frameworks() {
    local fw bin src srcbin dstbin name
    while IFS= read -r bin; do
        for fw in $(embedded_fw_refs "$bin"); do
            [ -n "$fw" ] || continue
            [ -d "$FW_DIR/$fw" ] || continue
            if [ -d "$PROD_FRAMEWORKS/$fw" ]; then
                src="$PROD_FRAMEWORKS/$fw"
            elif [ -d "$SRC_FRAMEWORKS/$fw" ]; then
                src="$SRC_FRAMEWORKS/$fw"
            else
                continue
            fi
            # Compare the canonical binary (Versions/A/<name>), not the framework
            # dir: writing a file inside a dir doesn't bump the dir mtime, so a
            # rebuilt product would never refresh the embedded copy.
            name=$(basename "$fw" .framework)
            if [ -f "$src/Versions/A/$name" ]; then
                srcbin="$src/Versions/A/$name"
                dstbin="$FW_DIR/$fw/Versions/A/$name"
            else
                srcbin="$src/$name"
                dstbin="$FW_DIR/$fw/$name"
            fi
            if [ -f "$srcbin" ] && { [ ! -f "$dstbin" ] || [ "$srcbin" -nt "$dstbin" ]; }; then
                echo "relink: refreshing $fw"
                rm -rf "${FW_DIR:?}/${fw:?}"
                ditto "$src" "$FW_DIR/$fw"
                codesign -f -s - "$FW_DIR/$fw"
            fi
        done
    done < <(all_bins)
}

# --- Run ------------------------------------------------------------------------
# Order matters: refresh stale embedded frameworks, rewrite sandbox refs to
# @rpath, then backfill so the rewrite is visible to the backfill scan.
refresh_frameworks
rewrite_bin "$APP_BIN"
while IFS= read -r bin; do
    rewrite_bin "$bin"
done < <(bundle_bins)
backfill_frameworks

# --- Verify: no sandbox references may remain ------------------------------------
remaining=0
if otool -L "$APP_BIN" | grep -q "Dependencies/sandbox-"; then remaining=1; fi
while IFS= read -r bin; do
    if otool -L "$bin" | grep -q "Dependencies/sandbox-"; then remaining=1; fi
done < <(bundle_bins)

if [ "$remaining" -eq 1 ]; then
    echo "relink: sandbox references remain after rewrite — refusing to continue" >&2
    exit 1
fi
echo "relink: ok — no sandbox references remain in $APP_BIN or bundled frameworks"
