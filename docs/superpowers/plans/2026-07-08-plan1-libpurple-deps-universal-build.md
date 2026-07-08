# Plan 1: Vendored Dependencies + Upstream libpurple 2.14.14 Universal Build

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Adium's forked/prebuilt libpurple and dependency binaries with a fully in-tree, no-download universal (arm64 + x86_64) build of vanilla upstream Pidgin libpurple 2.14.14 and its complete dependency chain.

**Architecture:** Extend the existing `Dependencies/build-universal-deps.sh` phase pipeline (per-arch autotools/meson builds into sandboxes → lipo merge → `.framework` packaging → install_name rewriting). Sources become checked-in, SHA256-pinned tarballs under `Dependencies/vendor/` — the build itself never touches the network. libpurple is built with static prpls (jabber, irc, simple), the same shape the old fork shipped.

**Tech Stack:** bash, autotools, meson/ninja (glib), lipo/install_name_tool, GitHub Actions CI.

**Spec:** `docs/superpowers/specs/2026-07-08-libpurple-upgrade-arc-design.md`

## Spec deviations (decided during planning — flag to user at review)

1. **Tarballs for all deps, no submodules.** The spec preferred submodules. The existing pipeline already consumes tarballs; release tarballs ship pregenerated `configure` (no autoreconf bootstrap), and Pidgin's canonical repo is Mercurial anyway. Uniform tarballs = one mechanism. ~55 MB committed once.
2. **cyrus-sasl dropped.** The old build linked macOS's system `libsasl2` (that's why no libsasl framework exists in `Frameworks/`). Vanilla jabber's built-in mechanisms (PLAIN, DIGEST-MD5, SCRAM-SHA-1) cover living XMPP servers; cyrus only adds GSSAPI/Kerberos SSO. Re-enable later if someone needs SSO.
3. **libidn dropped.** Pidgin 2.x's IDN support is optional (`--disable-idn`, verified in the vanilla 2.14.14 configure); the old Adium build disabled it too. Non-ASCII XMPP domains lose stringprep normalization — same behavior Adium has always shipped.
4. **pcre2 + libffi added.** The spec didn't list them, but glib requires both. The current glib phase silently downloads pcre2 via meson fallback (a build-time network fetch — exactly what this plan eliminates) and picks up Homebrew's libffi (non-relocatable, breaks the shipped app). Both become proper vendored phases.
5. **libpurple built with `--disable-nls`** (purple's own message catalog skipped; Adium ships its own localizations). Add back later by building gettext-tools' msgfmt if untranslated purple error strings bother anyone.

## Global Constraints

- Architectures: `arm64` + `x86_64`, merged with `lipo`; every produced binary must report both via `lipo -archs`.
- `MACOSX_DEPLOYMENT_TARGET` / `-mmacosx-version-min`: `11.0` (matches existing scripts).
- **No network access during build.** All sources read from `Dependencies/vendor/`. Downloads happen only via the developer-run `Dependencies/vendor-fetch.sh`.
- Build tools allowed from Homebrew (CI + dev): `meson`, `ninja`, `pkg-config`, `intltool`. Nothing else new.
- No ARC changes in this plan — everything stays MRR. That is Plan 4.
- No Xcode project changes in this plan (wiring Purple Service to the new headers is Plan 2). Deliverable is the built frameworks in `Frameworks/`.
- Versions (all latest upstream, researched 2026-07-08) and SHA256s:

| Package | Version | Vendored file | SHA256 |
|---|---|---|---|
| gettext | 1.0 | `gettext-1.0.tar.xz` | `71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7` |
| libffi | 3.6.0 | `libffi-3.6.0.tar.gz` | `31ff1fe32deaebfbb388727f32677bb254bf2a41382c51464c0b1837c9ee9828` |
| pcre2 | 10.47 | `pcre2-10.47.tar.bz2` | `47fe8c99461250d42f89e6e8fdaeba9da057855d06eb7fc08d9ca03fd08d7bc7` |
| glib | 2.88.2 | `glib-2.88.2.tar.xz` | `cf3f215a640c8a4257f14317586b8f1fdd25a10a93cb4bdda147c0f9ad88e74f` |
| libxml2 | 2.15.3 | `libxml2-2.15.3.tar.xz` | `78262a6e7ac170d6528ebfe2efccdf220191a5af6a6cd61ea4a9a9a5042c7a07` |
| libgpg-error | 1.61 | `libgpg-error-1.61.tar.bz2` | `7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93` |
| libgcrypt | 1.12.2 | `libgcrypt-1.12.2.tar.bz2` | `7ce33c2492221a0436f96a8500215e9f3e3dcb5fd26a757cd415e7a843babd5e` |
| libotr | 4.1.1 | `libotr-4.1.1.tar.gz` | `8b3b182424251067a952fb4e6c7b95a21e644fbb27fbd5f8af2b2ed87ca419f5` |
| pidgin (libpurple) | 2.14.14 | `pidgin-2.14.14.tar.bz2` | `0ffc9994def10260f98a55cd132deefa8dc4a9835451cc0e982747bd458e2356` |

  Canonical URLs: gettext `https://ftp.gnu.org/gnu/gettext/`, libffi `https://github.com/libffi/libffi/releases/download/v3.6.0/`, pcre2 `https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/`, glib `https://download.gnome.org/sources/glib/2.88/`, libxml2 `https://download.gnome.org/sources/libxml2/2.15/`, gpg-error/gcrypt `https://gnupg.org/ftp/gcrypt/{libgpg-error,libgcrypt}/`, libotr `https://otr.cypherpunks.ca/`, pidgin `https://downloads.sourceforge.net/pidgin/`.

- Phase order in `build-universal-deps.sh` (each later phase may consume earlier ones from the per-arch `$SANDBOX` and the lipo-merged `$BUILD_DIR`):
  `libffi → gettext → pcre2 → glib → libxml2 → libgpg-error → libgcrypt → libotr → libpurple`
- Existing helpers you build on (in `Dependencies/build-common.sh`): `set_build_env` (exports `CC`, `CFLAGS` with `-arch`, `$HOST_TRIPLE`, `$SANDBOX`, `$ARCH`), `build_for_archs <fn> <"dylibs">` (runs `<fn>` once per arch, lipo-merges the named dylibs from the sandboxes into `$BUILD_DIR/lib/`), `build_framework <name> <binary> <dylib> <headers>` (packages `Frameworks/<name>.framework`), `rewrite_dependency_links <dir>` (install_name surgery).
- Work on a feature branch off the current work (e.g. `feat/vendored-deps-libpurple`); never commit to `main`.

---

### Task 1: Vendoring infrastructure + gettext 1.0

**Files:**
- Create: `Dependencies/vendor-fetch.sh`
- Create: `Dependencies/vendor/` (holds `gettext-1.0.tar.xz` after this task)
- Modify: `Dependencies/build-common.sh` (add `vendored_extract`, keep-but-gut `download_*`)
- Modify: `Dependencies/build-phases/build-gettext.sh`
- Modify: `Dependencies/build-universal-deps.sh` (add `--only=<phase>` flag)

**Interfaces:**
- Produces: `vendored_extract <filename> <sha256> <expected_dirname>` → echoes extracted source dir path; errors if `Dependencies/vendor/<filename>` is missing or hash-mismatched. Handles `.tar.gz`, `.tgz`, `.tar.xz`, `.tar.bz2`. All later tasks call this instead of `download_and_extract`.
- Produces: `./build-universal-deps.sh --only=gettext` runs a single named phase (later tasks use `--only=<their phase>` for fast iteration).

- [ ] **Step 1: Create `Dependencies/vendor-fetch.sh`** (developer-run, one-time-per-dep; the build never calls it):

```bash
#!/bin/bash -eu
# vendor-fetch.sh — download a source tarball into Dependencies/vendor/ and
# verify/print its SHA256. Developer tool only; the build itself never downloads.
# Usage: vendor-fetch.sh <url> <expected-sha256>

url="$1"
expected="$2"
vendor_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor"
mkdir -p "$vendor_dir"
file="$vendor_dir/$(basename "$url")"

curl -fSL --proto '=https' --retry 3 -o "$file" "$url"
actual="$(shasum -a 256 "$file" | awk '{print $1}')"
if [ "$actual" != "$expected" ]; then
    echo "ERROR: SHA256 mismatch for $(basename "$file")" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    rm -f "$file"
    exit 1
fi
echo "OK: $actual  $(basename "$file")"
```

Run `chmod +x Dependencies/vendor-fetch.sh`.

- [ ] **Step 2: Add `vendored_extract` to `Dependencies/build-common.sh`** and delete `download_source` and `download_and_extract` (replace, don't deprecate — no other callers will remain after Task 4; grep to confirm at the end of Task 4, not here, since build-glib.sh still uses `download_and_extract` until then. For this task, add the new function alongside):

```bash
# ---- Extract a vendored source tarball ----
# Usage: vendored_extract <filename> <sha256> <expected_dirname>
# Reads Dependencies/vendor/<filename>; the build never downloads.
# Returns: path to extracted source directory
vendored_extract() {
    local filename="$1"
    local sha256="$2"
    local expected_dirname="$3"
    local tarball="$ROOTDIR/vendor/$filename"
    local extract_dir="$ROOTDIR/.cache/src"

    if [ ! -f "$tarball" ]; then
        echo "  ERROR: missing vendored source $tarball" >&2
        echo "  Fetch it once with: Dependencies/vendor-fetch.sh <url> $sha256" >&2
        return 1
    fi

    local actual
    actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"
    if [ "$actual" != "$sha256" ]; then
        echo "  ERROR: SHA256 mismatch for $filename: expected $sha256, got $actual" >&2
        return 1
    fi

    mkdir -p "$extract_dir"
    rm -rf "$extract_dir/$expected_dirname"
    echo "  Extracting $filename..." >&2
    case "$filename" in
        *.tar.gz|*.tgz) tar -xzf "$tarball" -C "$extract_dir" ;;
        *.tar.xz)       tar -xJf "$tarball" -C "$extract_dir" ;;
        *.tar.bz2)      tar -xjf "$tarball" -C "$extract_dir" ;;
        *)              echo "  ERROR: unknown archive format: $filename" >&2; return 1 ;;
    esac

    local src_path="$extract_dir/$expected_dirname"
    if [ ! -d "$src_path" ]; then
        echo "  ERROR: expected source dir $src_path not found" >&2
        ls "$extract_dir" >&2
        return 1
    fi
    echo "$src_path"
}
```

- [ ] **Step 3: Add `--only=<phase>` to `Dependencies/build-universal-deps.sh`.** In the flag-parsing section add `--only=*) ONLY_PHASE="${arg#--only=}" ;;` (default `ONLY_PHASE=""`), and wrap the phase invocations:

```bash
run_phase() {
    local name="$1" fn="$2"
    if [ -z "$ONLY_PHASE" ] || [ "$ONLY_PHASE" = "$name" ]; then
        "$fn"
    fi
}

run_phase gettext build_gettext_phase
run_phase glib build_glib_phase
run_phase json-glib build_json_glib_phase
```

(Keep the existing comment about phase order. `--only` reuses sandboxes from prior runs, so it's for iteration; full runs remain the acceptance gate.)

- [ ] **Step 4: Vendor gettext 1.0:**

```bash
Dependencies/vendor-fetch.sh \
  https://ftp.gnu.org/gnu/gettext/gettext-1.0.tar.xz \
  71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7
```

Expected output: `OK: 71132a…add7  gettext-1.0.tar.xz`

- [ ] **Step 5: Update `build-phases/build-gettext.sh`** — replace the version/URL/SHA header and the fetch call; configure flags unchanged:

```bash
BUILD_GETTEXT_VERSION="1.0"
BUILD_GETTEXT_FILE="gettext-${BUILD_GETTEXT_VERSION}.tar.xz"
BUILD_GETTEXT_SHA256="71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7"
```

and in `build_gettext()`:

```bash
    src_dir="$(vendored_extract "$BUILD_GETTEXT_FILE" "$BUILD_GETTEXT_SHA256" "gettext-$BUILD_GETTEXT_VERSION")"
```

If gettext 1.0's configure rejects any of the existing `--disable-*` flags, autoconf ignores unknown `--disable/--without` flags with a warning — leave them; only remove a flag if configure hard-errors on it.

- [ ] **Step 6: Run the phase:**

```bash
bash Dependencies/build-universal-deps.sh --only=gettext
lipo -archs Frameworks/libintl.framework/Versions/A/libintl
```

Expected: build completes with no `curl`/download output; lipo prints `x86_64 arm64`. (~5 min.)

- [ ] **Step 7: Commit** (tarball included — vendored sources are tracked):

```bash
git add Dependencies/vendor-fetch.sh Dependencies/vendor/gettext-1.0.tar.xz \
        Dependencies/build-common.sh Dependencies/build-phases/build-gettext.sh \
        Dependencies/build-universal-deps.sh
git commit -m "Vendor sources in-tree; gettext 1.0 builds without network"
```

---

### Task 2: libffi 3.6.0 phase

**Files:**
- Create: `Dependencies/build-phases/build-libffi.sh`
- Create: `Dependencies/vendor/libffi-3.6.0.tar.gz`
- Modify: `Dependencies/build-universal-deps.sh` (source + run the phase first)

**Interfaces:**
- Consumes: `vendored_extract`, `build_for_archs`, `build_framework` (Task 1 / build-common.sh).
- Produces: per-arch `$SANDBOX/lib/libffi.8.dylib` + `$SANDBOX/lib/pkgconfig/libffi.pc`; universal `$BUILD_DIR/lib/libffi.8.dylib`; `Frameworks/libffi.framework`. glib (Task 4) finds it via `$SANDBOX/lib/pkgconfig`.

- [ ] **Step 1: Vendor the tarball:**

```bash
Dependencies/vendor-fetch.sh \
  https://github.com/libffi/libffi/releases/download/v3.6.0/libffi-3.6.0.tar.gz \
  31ff1fe32deaebfbb388727f32677bb254bf2a41382c51464c0b1837c9ee9828
```

- [ ] **Step 2: Create `Dependencies/build-phases/build-libffi.sh`:**

```bash
#!/bin/bash -eu
# build-libffi.sh — Build libffi as universal framework (glib dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBFFI_VERSION="3.6.0"
BUILD_LIBFFI_FILE="libffi-${BUILD_LIBFFI_VERSION}.tar.gz"
BUILD_LIBFFI_SHA256="31ff1fe32deaebfbb388727f32677bb254bf2a41382c51464c0b1837c9ee9828"

build_libffi() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_LIBFFI_FILE" "$BUILD_LIBFFI_SHA256" "libffi-$BUILD_LIBFFI_VERSION")"

    cd "$src_dir"

    ./configure --prefix="$SANDBOX" \
        --disable-static --enable-shared \
        --disable-docs --disable-dependency-tracking \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_libffi_phase() {
    echo "=== Phase: libffi $BUILD_LIBFFI_VERSION ==="
    build_for_archs build_libffi "libffi.8.dylib"
    # No headers in the framework: ffitarget.h is arch-specific and only
    # glib's build consumes it (from the per-arch sandbox).
    build_framework "libffi" "libffi" "$BUILD_DIR/lib/libffi.8.dylib" ""
}
```

- [ ] **Step 3: Wire into `build-universal-deps.sh`** — add `source "$ROOTDIR/build-phases/build-libffi.sh"` with the other sources and `run_phase libffi build_libffi_phase` as the FIRST phase (before gettext).

- [ ] **Step 4: Run and verify:**

```bash
bash Dependencies/build-universal-deps.sh --only=libffi
lipo -archs Frameworks/libffi.framework/Versions/A/libffi
ls Dependencies/sandbox-*/lib/pkgconfig/libffi.pc
```

Expected: `x86_64 arm64`; both sandbox `.pc` files exist. (~2 min.)

- [ ] **Step 5: Commit:**

```bash
git add Dependencies/vendor/libffi-3.6.0.tar.gz Dependencies/build-phases/build-libffi.sh \
        Dependencies/build-universal-deps.sh
git commit -m "Build libffi 3.6.0 universal from vendored source"
```

---

### Task 3: pcre2 10.47 phase

**Files:**
- Create: `Dependencies/build-phases/build-pcre2.sh`
- Create: `Dependencies/vendor/pcre2-10.47.tar.bz2`
- Modify: `Dependencies/build-universal-deps.sh`

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces: per-arch `$SANDBOX/lib/libpcre2-8.0.dylib` + `libpcre2-8.pc`; universal `$BUILD_DIR/lib/libpcre2-8.0.dylib`; `Frameworks/libpcre2-8.framework`. glib (Task 4) consumes via pkg-config, replacing its meson download fallback.

- [ ] **Step 1: Vendor:**

```bash
Dependencies/vendor-fetch.sh \
  https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.bz2 \
  47fe8c99461250d42f89e6e8fdaeba9da057855d06eb7fc08d9ca03fd08d7bc7
```

- [ ] **Step 2: Create `Dependencies/build-phases/build-pcre2.sh`:**

```bash
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
    build_framework "libpcre2-8" "libpcre2-8" "$BUILD_DIR/lib/libpcre2-8.0.dylib" ""
}
```

- [ ] **Step 3: Wire in** — source the file; `run_phase pcre2 build_pcre2_phase` between gettext and glib.

- [ ] **Step 4: Run and verify:**

```bash
bash Dependencies/build-universal-deps.sh --only=pcre2
lipo -archs Frameworks/libpcre2-8.framework/Versions/A/libpcre2-8
```

Expected: `x86_64 arm64`. (~3 min.)

- [ ] **Step 5: Commit:**

```bash
git add Dependencies/vendor/pcre2-10.47.tar.bz2 Dependencies/build-phases/build-pcre2.sh \
        Dependencies/build-universal-deps.sh
git commit -m "Build pcre2 10.47 universal from vendored source"
```

---

### Task 4: glib 2.88.2 — vendored, no meson fallback, in-tree libffi/pcre2

**Files:**
- Create: `Dependencies/vendor/glib-2.88.2.tar.xz`
- Modify: `Dependencies/build-phases/build-glib.sh`
- Modify: `Dependencies/build-common.sh` (delete `download_source`/`download_and_extract` — last caller gone)

**Interfaces:**
- Consumes: libffi + pcre2 from `$SANDBOX/lib/pkgconfig` (Tasks 2–3); libintl from `$BUILD_DIR` (Task 1).
- Produces: same as today — glib/gmodule/gobject/gthread/gio frameworks, headers + fixed-up `.pc` files in `$BUILD_DIR` for downstream phases (libxml2 doesn't need them, libpurple does).

- [ ] **Step 1: Vendor:**

```bash
Dependencies/vendor-fetch.sh \
  https://download.gnome.org/sources/glib/2.88/glib-2.88.2.tar.xz \
  cf3f215a640c8a4257f14317586b8f1fdd25a10a93cb4bdda147c0f9ad88e74f
```

(SHA cross-checked against GNOME's published `glib-2.88.2.sha256sum`.)

- [ ] **Step 2: Update `build-phases/build-glib.sh`:**
  - Header:
    ```bash
    BUILD_GLIB_VERSION="2.88.2"
    BUILD_GLIB_FILE="glib-${BUILD_GLIB_VERSION}.tar.xz"
    BUILD_GLIB_SHA256="cf3f215a640c8a4257f14317586b8f1fdd25a10a93cb4bdda147c0f9ad88e74f"
    ```
  - Fetch: `src_dir="$(vendored_extract "$BUILD_GLIB_FILE" "$BUILD_GLIB_SHA256" "glib-$BUILD_GLIB_VERSION")"`
  - pkg-config: make the per-arch sandbox findable first:
    ```bash
    export PKG_CONFIG_PATH="$SANDBOX/lib/pkgconfig:$BUILD_DIR/lib/pkgconfig"
    ```
  - Meson args: remove `--force-fallback-for=pcre2`; add `--wrap-mode=nofallback` and `-Dintrospection=disabled`; delete the `sed … meson_options.txt` introspection hack (2.88 has the real option).
  - Everything else (framework packaging, header copying) unchanged.
  - If meson errors on a stale option name (2.82→2.88 drift, e.g. `-Dnls` or `-Ddtrace` type changes), fix per the error message: the intent is docs/tests/selinux/xattr/libelf/dtrace/systemtap all off, posix threads forced.

- [ ] **Step 3: Delete `download_source` and `download_and_extract` from `build-common.sh`,** then confirm nothing references them:

```bash
rg -n 'download_and_extract|download_source' Dependencies/ --glob '!vendor/**'
```

Expected: no matches.

- [ ] **Step 4: Run and verify (this is the slow one, ~15 min):**

```bash
bash Dependencies/build-universal-deps.sh --only=glib
for f in glib libgmodule libgobject libgthread libgio; do
  lipo -archs "Frameworks/$f.framework/Versions/A/$f"
done
otool -L Frameworks/glib.framework/Versions/A/glib | grep -E 'homebrew|Cellar|/usr/local' || echo CLEAN
```

Expected: five lines of `x86_64 arm64`; `CLEAN` (no Homebrew leakage — this is the bug the libffi phase fixes).

- [ ] **Step 5: Commit:**

```bash
git add Dependencies/vendor/glib-2.88.2.tar.xz Dependencies/build-phases/build-glib.sh \
        Dependencies/build-common.sh
git commit -m "Build glib 2.88.2 from vendored source with in-tree libffi/pcre2"
```

---

### Task 5: Drop json-glib

**Files:**
- Delete: `Dependencies/build-phases/build-json-glib.sh`, `Frameworks/libjson-glib.framework/`, root symlink `libjson-glib-1.0.dylib`
- Modify: `Dependencies/build-universal-deps.sh`, `Dependencies/build-common.sh` (FW_MAP entry)

json-glib existed for the fork's dead-service prpls (Facebook/Twitter-era). Vanilla libpurple 2.14 with jabber/irc/simple does not use it.

- [ ] **Step 1: Verify nothing living needs it:**

```bash
rg -l 'json-glib|json_object|JsonNode' Source Plugins Frameworks/Adium Frameworks/AIUtilities
```

Expected: no matches, or matches only inside dead-service code slated for deletion in Plan 2 (check each hit's service). **If a hit is in living code, STOP — keep json-glib and record why in the commit message instead of deleting.**

- [ ] **Step 2: Delete** `build-phases/build-json-glib.sh`, the `source` line and `run_phase json-glib …` line in `build-universal-deps.sh`, the `libjson-glib` case in `rewrite_dependency_links`'s FW_MAP, `git rm -r Frameworks/libjson-glib.framework`, and `git rm libjson-glib-1.0.dylib` (root symlink).

- [ ] **Step 3: Full pipeline still green:**

```bash
bash Dependencies/build-universal-deps.sh
```

Expected: all phases (libffi, gettext, pcre2, glib) complete. (~20 min.)

- [ ] **Step 4: Commit:**

```bash
git add -A Dependencies Frameworks libjson-glib-1.0.dylib
git commit -m "Drop json-glib: only served dead-protocol prpls"
```

---

### Task 6: libxml2 2.15.3 phase

**Files:**
- Create: `Dependencies/build-phases/build-libxml2.sh`
- Create: `Dependencies/vendor/libxml2-2.15.3.tar.xz`
- Modify: `Dependencies/build-universal-deps.sh`, `build-common.sh` (FW_MAP: add `libxml2`)

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces: per-arch `$SANDBOX/lib/libxml2*.dylib` + `libxml-2.0.pc`; universal dylib in `$BUILD_DIR/lib`; `Frameworks/libxml2.framework` with headers; libpurple (Task 9) consumes via `LIBXML_CFLAGS`/`LIBXML_LIBS`.

- [ ] **Step 1: Vendor:**

```bash
Dependencies/vendor-fetch.sh \
  https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz \
  78262a6e7ac170d6528ebfe2efccdf220191a5af6a6cd61ea4a9a9a5042c7a07
```

(SHA cross-checked against GNOME's published `libxml2-2.15.3.sha256sum`.)

- [ ] **Step 2: Create `Dependencies/build-phases/build-libxml2.sh`:**

```bash
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
    # Dylib name libxml2.16.dylib: libtool -version-info is CURRENT:MICRO:AGE with
    # CURRENT=major+minor=17, AGE=minor-compat=1, so suffix = CURRENT-AGE = 16
    # (verified in the 2.15.3 configure.ac).
    build_for_archs build_libxml2 "libxml2.16.dylib"
    build_framework "libxml2" "libxml2" "$BUILD_DIR/lib/libxml2.16.dylib" "$SANDBOX_X86_64/include/libxml2"

    # Copy .pc file for downstream (libpurple) and fix prefix
    mkdir -p "$BUILD_DIR/lib/pkgconfig"
    cp "$SANDBOX_X86_64/lib/pkgconfig/libxml-2.0.pc" "$BUILD_DIR/lib/pkgconfig/"
    sed -i '' "s|$SANDBOX_X86_64|$BUILD_DIR|g" "$BUILD_DIR/lib/pkgconfig/libxml-2.0.pc"
    mkdir -p "$BUILD_DIR/include"
    cp -R "$SANDBOX_X86_64/include/libxml2" "$BUILD_DIR/include/"
}
```

- [ ] **Step 3: Wire in** after glib: `run_phase libxml2 build_libxml2_phase`. Add `libxml2) FW_MAP["libxml2"]=1 ;;` to `rewrite_dependency_links`.

- [ ] **Step 4: Run and verify:**

```bash
bash Dependencies/build-universal-deps.sh --only=libxml2
lipo -archs Frameworks/libxml2.framework/Versions/A/libxml2
ls Frameworks/libxml2.framework/Headers/libxml/parser.h
```

Expected: `x86_64 arm64`; header exists. (~4 min.)

- [ ] **Step 5: Commit:**

```bash
git add Dependencies/vendor/libxml2-2.15.3.tar.xz Dependencies/build-phases/build-libxml2.sh \
        Dependencies/build-universal-deps.sh Dependencies/build-common.sh
git commit -m "Build libxml2 2.15.3 universal from vendored source"
```

---

### Task 7: libgpg-error 1.61 + libgcrypt 1.12.2 phases

**Files:**
- Create: `Dependencies/build-phases/build-gpg-error.sh`, `Dependencies/build-phases/build-gcrypt.sh`
- Create: `Dependencies/vendor/libgpg-error-1.61.tar.bz2`, `Dependencies/vendor/libgcrypt-1.12.2.tar.bz2`
- Modify: `Dependencies/build-universal-deps.sh`, `build-common.sh` (FW_MAP: `libgpg-error`)

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces: `Frameworks/libgpg-error.framework`, `Frameworks/libgcrypt.framework` (replacing the checked-in prebuilt libgcrypt); per-arch `$SANDBOX/bin/gpg-error-config`, `$SANDBOX/bin/libgcrypt-config` consumed by libotr (Task 8).

- [ ] **Step 1: Vendor both** (SHAs from GnuPG's signed `swdb.lst`):

```bash
Dependencies/vendor-fetch.sh \
  https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.bz2 \
  7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93
Dependencies/vendor-fetch.sh \
  https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.12.2.tar.bz2 \
  7ce33c2492221a0436f96a8500215e9f3e3dcb5fd26a757cd415e7a843babd5e
```

- [ ] **Step 2: Create `Dependencies/build-phases/build-gpg-error.sh`:**

```bash
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
```

- [ ] **Step 3: Create `Dependencies/build-phases/build-gcrypt.sh`:**

```bash
#!/bin/bash -eu
# build-gcrypt.sh — Build libgcrypt as universal framework (libotr dependency)
# Shell function, sourced by build-universal-deps.sh

BUILD_GCRYPT_VERSION="1.12.2"
BUILD_GCRYPT_FILE="libgcrypt-${BUILD_GCRYPT_VERSION}.tar.bz2"
BUILD_GCRYPT_SHA256="7ce33c2492221a0436f96a8500215e9f3e3dcb5fd26a757cd415e7a843babd5e"

build_gcrypt() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_GCRYPT_FILE" "$BUILD_GCRYPT_SHA256" "libgcrypt-$BUILD_GCRYPT_VERSION")"

    cd "$src_dir"

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
    build_for_archs build_gcrypt "libgcrypt.20.dylib"
    build_framework "libgcrypt" "libgcrypt" "$BUILD_DIR/lib/libgcrypt.20.dylib" ""
}
```

If the cross-arch slice fails in libgcrypt's assembly (building the x86_64 slice on an arm64 host or vice versa), add `--disable-asm` to configure — correctness over speed; note it with a `ponytail:` comment naming the upgrade path (per-arch asm re-enable).

- [ ] **Step 4: Wire in** after libxml2: `run_phase gpg-error build_gpg_error_phase`, then `run_phase gcrypt build_gcrypt_phase`. Add `libgpg-error) FW_MAP["libgpg-error"]=1 ;;` to FW_MAP (libgcrypt already mapped). Replace the checked-in prebuilt: `git rm -r Frameworks/libgcrypt.framework` happens implicitly — the phase overwrites it in place; verify `git status` shows the binary changed, and that's expected.

- [ ] **Step 5: Run and verify:**

```bash
bash Dependencies/build-universal-deps.sh --only=gpg-error
bash Dependencies/build-universal-deps.sh --only=gcrypt
lipo -archs Frameworks/libgpg-error.framework/Versions/A/libgpg-error
lipo -archs Frameworks/libgcrypt.framework/Versions/A/libgcrypt
```

Expected: both `x86_64 arm64`. (~8 min.) If the actual dylib versioned name differs (e.g. `libgcrypt.20.dylib` vs newer soname), fix the name in the phase from `ls Dependencies/sandbox-x86_64/lib/`.

- [ ] **Step 6: Commit:**

```bash
git add Dependencies/vendor/libgpg-error-1.61.tar.bz2 Dependencies/vendor/libgcrypt-1.12.2.tar.bz2 \
        Dependencies/build-phases/build-gpg-error.sh Dependencies/build-phases/build-gcrypt.sh \
        Dependencies/build-universal-deps.sh Dependencies/build-common.sh Frameworks/libgcrypt.framework
git commit -m "Build libgpg-error 1.61 and libgcrypt 1.12.2 universal"
```

---

### Task 8: libotr 4.1.1 phase

**Files:**
- Create: `Dependencies/build-phases/build-libotr.sh`
- Create: `Dependencies/vendor/libotr-4.1.1.tar.gz`
- Modify: `Dependencies/build-universal-deps.sh`

**Interfaces:**
- Consumes: libgcrypt from `$SANDBOX` (Task 7).
- Produces: `Frameworks/libotr.framework` with headers (replacing the prebuilt one; Adium's OTR plugin includes `<libotr/proto.h>` etc. from it).

- [ ] **Step 1: Vendor:**

```bash
Dependencies/vendor-fetch.sh \
  https://otr.cypherpunks.ca/libotr-4.1.1.tar.gz \
  8b3b182424251067a952fb4e6c7b95a21e644fbb27fbd5f8af2b2ed87ca419f5
```

- [ ] **Step 2: Create `Dependencies/build-phases/build-libotr.sh`:**

```bash
#!/bin/bash -eu
# build-libotr.sh — Build libotr as universal framework (OTR encryption)
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBOTR_VERSION="4.1.1"
BUILD_LIBOTR_FILE="libotr-${BUILD_LIBOTR_VERSION}.tar.gz"
BUILD_LIBOTR_SHA256="8b3b182424251067a952fb4e6c7b95a21e644fbb27fbd5f8af2b2ed87ca419f5"

build_libotr() {
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
```

- [ ] **Step 3: Wire in** after gcrypt: `run_phase libotr build_libotr_phase`.

- [ ] **Step 4: Run and verify:**

```bash
bash Dependencies/build-universal-deps.sh --only=libotr
lipo -archs Frameworks/libotr.framework/Versions/A/libotr
ls Frameworks/libotr.framework/Headers/proto.h
otool -L Frameworks/libotr.framework/Versions/A/libotr
```

Expected: `x86_64 arm64`; `proto.h` exists; deps reference only sandbox/build paths (rewritten at pipeline end) and system libs. (~3 min.)

- [ ] **Step 5: Commit:**

```bash
git add Dependencies/vendor/libotr-4.1.1.tar.gz Dependencies/build-phases/build-libotr.sh \
        Dependencies/build-universal-deps.sh Frameworks/libotr.framework
git commit -m "Build libotr 4.1.1 universal from vendored source"
```

---

### Task 9: libpurple 2.14.14 (vanilla upstream, static prpls)

**Files:**
- Create: `Dependencies/build-phases/build-libpurple.sh`
- Create: `Dependencies/vendor/pidgin-2.14.14.tar.bz2`
- Modify: `Dependencies/build-universal-deps.sh`

**Interfaces:**
- Consumes: glib (`$BUILD_DIR` pc/headers/dylibs, Task 4), libxml2 (`$BUILD_DIR`, Task 6), libintl (Task 1).
- Produces: `Frameworks/libpurple.framework` — universal `libpurple.0.dylib`; `Headers/` = public libpurple headers **plus** the internal headers Purple Service imports (`internal.h`, `cmds.h`, `jabber/*.h` subset, `irc/irc.h`). Plan 2 compiles Purple Service against exactly these headers.

Configure flags derive from the fork's historical build (`Dependencies/phases/build_purple.sh`) minus dead options: no cyrus-sasl, no meanwhile/json-glib env, prpls reduced to `jabber,irc,simple`, `--disable-nls` added. Every flag below exists in vanilla 2.14.14's `./configure --help`, and the dylib name `libpurple.0.dylib` follows from its libtool `-version-info 14:14:14` (suffix = CURRENT−AGE = 0) — both verified against the extracted tarball in `~/git/reference/pidgin-2.14.14`.

- [ ] **Step 1: Vendor:**

```bash
Dependencies/vendor-fetch.sh \
  https://downloads.sourceforge.net/pidgin/pidgin-2.14.14.tar.bz2 \
  0ffc9994def10260f98a55cd132deefa8dc4a9835451cc0e982747bd458e2356
```

- [ ] **Step 2: Create `Dependencies/build-phases/build-libpurple.sh`:**

```bash
#!/bin/bash -eu
# build-libpurple.sh — Build vanilla upstream libpurple (from Pidgin) as universal
# framework with static prpls: jabber, irc, simple.
# Shell function, sourced by build-universal-deps.sh

BUILD_LIBPURPLE_VERSION="2.14.14"
BUILD_LIBPURPLE_FILE="pidgin-${BUILD_LIBPURPLE_VERSION}.tar.bz2"
BUILD_LIBPURPLE_SHA256="0ffc9994def10260f98a55cd132deefa8dc4a9835451cc0e982747bd458e2356"

build_libpurple() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_LIBPURPLE_FILE" "$BUILD_LIBPURPLE_SHA256" "pidgin-$BUILD_LIBPURPLE_VERSION")"

    cd "$src_dir"

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
    build_for_archs build_libpurple "libpurple.0.dylib"

    build_framework "libpurple" "libpurple" "$BUILD_DIR/lib/libpurple.0.dylib" \
        "$SANDBOX_X86_64/include/libpurple"

    # Purple Service imports internal + prpl headers not installed by `make install`.
    # Copy them from the source tree (same set the old fork's build shipped, minus
    # dead protocols).
    local src="$ROOTDIR/.cache/src/pidgin-$BUILD_LIBPURPLE_VERSION/libpurple"
    local hdr="$SRCROOT/Frameworks/libpurple.framework/Versions/A/Headers"
    cp "$src/internal.h" "$src/cmds.h" "$hdr/"
    cp "$src/protocols/jabber/auth.h" "$src/protocols/jabber/bosh.h" \
       "$src/protocols/jabber/buddy.h" "$src/protocols/jabber/caps.h" \
       "$src/protocols/jabber/jutil.h" "$src/protocols/jabber/presence.h" \
       "$src/protocols/jabber/si.h" "$src/protocols/jabber/jabber.h" \
       "$src/protocols/jabber/iq.h" "$src/protocols/jabber/namespaces.h" \
       "$hdr/"
    cp "$src/protocols/irc/irc.h" "$hdr/"
}
```

- [ ] **Step 3: Wire in** as the LAST phase: `run_phase libpurple build_libpurple_phase`. (`libpurple` is already in FW_MAP.)

- [ ] **Step 4: Run:**

```bash
bash Dependencies/build-universal-deps.sh --only=libpurple 2>&1 | tee /tmp/purple-build.log | tail -40
```

Expected: configure summary shows `Static protocols: jabber irc simple`, SSL disabled (Adium supplies its own SSL ops — Plan 3), then a clean make. (~10 min.)

**Known-likely fixups (apply minimally, keep a patch if source edits are needed):**
- `configure` may demand `intltool-update` even with `--disable-nls` → `brew install intltool` (already in Global Constraints tooling).
- Modern clang may promote old-C warnings to errors → prefer `CFLAGS="$CFLAGS -Wno-error=..."` appended inside `build_libpurple` over patching source. 2.14.14 already fixed the gcc-14 incompatible-pointer batch upstream.
- If source patching is unavoidable, put patches in `Dependencies/patches/libpurple-*.diff`, apply with `patch -p1` in `build_libpurple` right after extraction, and document each patch's upstream-ability in its header comment.

- [ ] **Step 5: Verify the artifact:**

```bash
BIN=Frameworks/libpurple.framework/Versions/A/libpurple
lipo -archs "$BIN"                                   # → x86_64 arm64
nm -gU "$BIN" | grep -c ' _purple_core_init'         # → 1
nm -gU "$BIN" | grep -c ' _jabber'                   # → nonzero (static prpl linked)
nm "$BIN" | grep -ci 'irc_'                          # → nonzero
ls Frameworks/libpurple.framework/Headers/{purple.h,jabber.h,irc.h,internal.h}
```

- [ ] **Step 6: Full pipeline from scratch (acceptance):**

```bash
rm -rf Dependencies/.cache/src Dependencies/sandbox-* Dependencies/build
bash Dependencies/build-universal-deps.sh
otool -L Frameworks/libpurple.framework/Versions/A/libpurple
```

Expected: every phase green with zero network access; libpurple's deps all `@executable_path/../Frameworks/...` (after `rewrite_dependency_links`) or `/usr/lib`/`/System`. (~35 min.)

- [ ] **Step 7: Commit:**

```bash
git add Dependencies/vendor/pidgin-2.14.14.tar.bz2 Dependencies/build-phases/build-libpurple.sh \
        Dependencies/build-universal-deps.sh Frameworks/libpurple.framework
git commit -m "Build vanilla libpurple 2.14.14 universal with static jabber/irc/simple"
```

---

### Task 10: Legacy build-system and dead-binary cleanup

**Files (all deletions):**
- `Dependencies/phases/` (old fork build system — fully superseded by `build-phases/`)
- `Dependencies/Makefile`, `Dependencies/config.log`, `Dependencies/config.status`, `Dependencies/libtool`, `Dependencies/meanwhile.pc`, `Dependencies/meanwhile.spec` (meanwhile autotools droppings)
- `Dependencies/patches/Meanwhile-*.diff`, `Dependencies/patches/glib-*.diff` (patches for versions no longer built)
- `Dependencies/framework_maker/`, `Dependencies/rtool/`, `Dependencies/build.sh`, `Dependencies/samples/`, `Dependencies/libpurple-full.h`, `Dependencies/Libpurple-Info.plist`, `Dependencies/Libotr-Info.plist`
- `Frameworks/libmeanwhile.framework/` (dead Sametime protocol)
- Root symlinks into Homebrew Cellar: `libglib-2.0.dylib`, `libgmodule-2.0.dylib`, `libgobject-2.0.dylib`, `libgthread-2.0.dylib`, `libintl.8.dylib`, `libjson-glib-1.0.dylib` (if not already removed in Task 5), `libotr.5.dylib`
- Modify: `Dependencies/build-common.sh` (drop `libmeanwhile` from FW_MAP)

- [ ] **Step 1: Confirm nothing references what's being deleted** (project files count only if the reference is in a target we still build):

```bash
rg -l 'meanwhile|framework_maker|rtool|libpurple-full' \
   --glob '!Dependencies/phases/**' --glob '!Dependencies/patches/**' \
   Source Plugins Frameworks/Adium Frameworks/AIUtilities Adium.xcodeproj Dependencies
```

Investigate each hit: references inside `Adium.xcodeproj/project.pbxproj` to `libmeanwhile.framework` will exist (the Purple Service target links it) — those Xcode-side removals belong to Plan 2's dead-service cleanup; deleting the framework now is still correct because CI does not build that target yet. Any hit in living, currently-built code: STOP and reassess.

- [ ] **Step 2: Delete** everything in the Files list via `git rm -r` (use `trash` for any untracked leftovers). Remove the `libmeanwhile` FW_MAP line in `build-common.sh`.

- [ ] **Step 3: Full pipeline still green:**

```bash
bash Dependencies/build-universal-deps.sh --only=libpurple
```

Expected: unchanged success — deletions touched nothing the new pipeline uses. (~10 min.)

- [ ] **Step 4: Commit:**

```bash
git add -A
git commit -m "Delete fork-era build system, meanwhile, and Homebrew symlinks"
```

---

### Task 11: CI — full vendored universal build with arch assertions

**Files:**
- Modify: `.github/workflows/*.yml` (the existing build workflow)

**Interfaces:**
- Consumes: the complete pipeline (Tasks 1–10).
- Produces: CI gate every later plan builds on.

- [ ] **Step 1: Update the deps step** in the workflow:
  - Ensure tools: `brew install meson ninja pkg-config intltool || true` (some preinstalled on runners).
  - Replace the current "Build universal dependencies (glib, gettext, json-glib)" step name/body with the full run:

```yaml
      - name: Build universal dependencies (vendored, no network)
        run: bash Dependencies/build-universal-deps.sh 2>&1 | tail -40

      - name: Assert universal architectures
        run: |
          set -e
          for fw in libintl libffi libpcre2-8 glib libgmodule libgobject \
                    libgthread libgio libxml2 libgpg-error libgcrypt libotr libpurple; do
            bin="Frameworks/$fw.framework/Versions/A/$fw"
            archs="$(lipo -archs "$bin")"
            echo "$fw: $archs"
            [ "$archs" = "x86_64 arm64" ] || [ "$archs" = "arm64 x86_64" ] || { echo "FAIL: $fw"; exit 1; }
          done
          nm -gU Frameworks/libpurple.framework/Versions/A/libpurple | grep -q ' _purple_core_init'
```

  - Update the stale comment about json-glib/meanwhile.

- [ ] **Step 2: Lint the workflow:**

```bash
actionlint .github/workflows/*.yml && zizmor .github/workflows/*.yml
```

Expected: no errors (pre-existing findings unrelated to this change may stand — fix only what this change introduces… actually per house rules: if zizmor flags something pre-existing, file a GitHub issue for it rather than ignoring).

- [ ] **Step 3: Commit, push, watch CI:**

```bash
git add .github/workflows
git commit -m "CI: build full vendored dependency chain, assert universal binaries"
git push -u origin HEAD
gh pr checks --watch || gh run watch
```

Expected: green. CI runtime will grow (~30–40 min deps build); if it exceeds limits, add a cache step keyed on `hashFiles('Dependencies/vendor/*', 'Dependencies/build-phases/*')` for `Dependencies/build` + `Frameworks/*.framework` — but only if actually needed.

---

## Verification (plan-level acceptance)

1. Fresh clone + `git submodule update --init` + `bash Dependencies/build-universal-deps.sh` succeeds **with networking disabled** (e.g. `networksetup -setairportpower airport off` or run once and confirm zero `curl` invocations in the log).
2. All 13 frameworks report `x86_64 arm64`.
3. `otool -L` on every framework binary shows only `@executable_path`, `/usr/lib`, or `/System` references.
4. `nm` confirms `purple_core_init` + jabber/irc/simple symbols in libpurple.
5. CI green.

## Out of scope (later plans)

- Plan 2: compile Purple Service against `Frameworks/libpurple.framework/Headers` (fork-delta audit), delete dead-service classes, remove `libmeanwhile`/json-glib references from `Adium.xcodeproj`.
- Plan 3: Network.framework SSL-ops plugin replacing `ssl-cdsa.c`.
- Plan 4: ARC conversion.
