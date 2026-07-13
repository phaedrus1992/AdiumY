# Design: Build FriBidi and LMX in the dependency build

- **Issue:** [#56 — FriBidi and LMX prebuilt frameworks lack arm64 slices](../../../../issues/56)
- **Status:** Approved
- **Scope:** `Dependencies/build-universal-deps.sh`, `Dependencies/build-common.sh`,
  `Dependencies/build-phases/`, `Dependencies/vendor/`, `Frameworks/Adium/Source/`,
  `Adium.xcodeproj/project.pbxproj`, `.gitignore`, two consumer `#import` lines

## 1. Problem

`Frameworks/FriBidi.framework` and `Frameworks/LMX.framework` are git-tracked
prebuilt binaries with `x86_64 + i386` slices and no arm64. They are the only
external dependencies not produced by `Dependencies/build-universal-deps.sh`
(#55), and they block a universal (x86_64 + arm64) link of the Adium app.

## 2. Findings that shape the design

### 2.1 FriBidi.framework is not vanilla fribidi

The shipped framework is GNU FriBidi **0.19.1** (Unicode 5.1, circa 2008) plus
an Adium-specific Objective-C category compiled in:
`NSString-FBAdditions` (Ofri Wolfus, 2006), which provides
`-[NSString baseWritingDirection]`. The category's `.m` source is **not in
this repo** — only the header ships inside the framework.

That category is the *only* FriBidi API Adium uses. The complete consumer list:

- `Frameworks/Adium/Source/AIHTMLDecoder.m` — `#import <FriBidi/NSString-FBAdditions.h>`
- `Frameworks/Adium/Source/AIMessageEntryTextView.m` — same import

There are zero direct `fribidi_*` C calls anywhere in the tree. A plain
fribidi build phase alone would therefore produce a framework no consumer can
use; the category must be recreated somewhere.

### 2.2 FriBidi.framework is never linked — bidi detection is likely broken

No target links FriBidi.framework — not in this fork and not at
`mark-final-upstream`. It appears only in the app target's **Copy Frameworks**
phase (`project.pbxproj:1088`) and as a file reference. No xcconfig adds
`-framework FriBidi` either. Since Objective-C category methods resolve at
runtime, and nothing loads the framework, `-baseWritingDirection` most likely
raises `unrecognized selector` (or resolves against something else entirely)
at runtime. This design makes the linkage explicit and fixes that as a side
effect.

### 2.3 LMX is tiny Objective-C, not an autotools/meson lib

LMX is Peter Hosey's reverse ("last-in-first-out") XML parser,
<https://boredzo.org/lmx/>. Facts verified against the upstream tarball
`LMX-1.0.tbz`:

- BSD-style license (`LICENSE.txt`, © 2005–2007 Peter Hosey).
- Three implementation files: `LMXParser.m`, `LMXMutableDataAdditions.m`,
  `LMXMutableStringAdditions.m` (plus matching headers). Manual
  retain/release (pre-ARC).
- The tarball's `LMXParser.h` is identical to the shipped framework's header
  modulo whitespace — drop-in API compatibility is confirmed.
- SHA256: `91adf3fa39b89d8716ed73cae51830c67bc98102e148d4b66bab1b62f99e5355`.
- The upstream Subversion repo (`https://github.com/phaedrus1992/adiumy/liblmx`) is long dead;
  the tarball is the canonical source artifact.

Sole consumer: `Source/DCMessageContextDisplayPlugin.m` (Adium app target),
which links and copies LMX.framework via existing pbxproj phases.

## 3. Design

### 3.1 FriBidi build phase

- Vendor `fribidi-1.0.16.tar.xz` (latest upstream release) into
  `Dependencies/vendor/` via `vendor-fetch.sh`.
  SHA256: `1b1cde5b235d40479e91be2f0e88a309e3214c8ab470ec8a2744d82a5a9ea05c`
  (verified against the official GitHub release asset).
- New `Dependencies/build-phases/build-fribidi.sh` following the libotr
  pattern: `vendored_extract`, then per-arch via `build_for_archs`:
  `./configure --prefix="$SANDBOX" --disable-static --enable-shared
  --disable-dependency-tracking --host="$HOST_TRIPLE"`, `make`, `make install`.
  fribidi 1.0.x has no library dependencies, so the phase is order-independent;
  append it after libpurple in `build-universal-deps.sh`.
- `build_framework "FriBidi" "FriBidi" <universal libfribidi dylib>
  <staged headers> "1.0.16"` — keeping the existing framework name means the
  pbxproj file reference and Copy Frameworks entry need no changes.
- Register in the `DYLIB_MAP_*` arrays in `build-common.sh`:
  dylib `libfribidi.0.dylib` → framework `FriBidi` → binary `FriBidi`.
  This puts FriBidi under the existing verification gate (universal-arch
  check, sandbox-path leak check, symlink check) and the @rpath rewrite
  machinery automatically.

### 3.2 NSString-FBAdditions category, recreated as source

- New files `Frameworks/Adium/Source/NSString-FBAdditions.{h,m}` (~40 lines).
  The header keeps the existing interface verbatim:
  `- (NSWritingDirection)baseWritingDirection;`
- Implementation: convert the receiver to UTF-32 (`FriBidiChar` buffer via
  `-getBytes:...encoding:NSUTF32LittleEndianStringEncoding` or equivalent),
  call `fribidi_get_bidi_types()` then `fribidi_get_par_direction()`, and map:
  - `FRIBIDI_PAR_RTL` / `FRIBIDI_PAR_WRTL` → `NSWritingDirectionRightToLeft`
  - `FRIBIDI_PAR_LTR` / `FRIBIDI_PAR_WLTR` → `NSWritingDirectionLeftToRight`
  - `FRIBIDI_PAR_ON` (and empty string) → `NSWritingDirectionNatural`
- Xcode project changes (Adium.Framework target):
  - add the new `.h`/`.m` to the target,
  - add FriBidi.framework to the target's **Frameworks (link)** phase — the
    link that has always been missing (§2.2).
- Consumers change one line each:
  `#import <FriBidi/NSString-FBAdditions.h>` →
  `#import "NSString-FBAdditions.h"` in `AIHTMLDecoder.m` and
  `AIMessageEntryTextView.m`.

### 3.3 LMX build phase

- Vendor `LMX-1.0.tbz` from <https://boredzo.org/lmx/LMX-1.0.tbz> into
  `Dependencies/vendor/` (SHA256 in §2.3).
- New `Dependencies/build-phases/build-lmx.sh`. No configure/make — per arch,
  a single compile+link over the three `.m` files:

  ```
  clang -dynamiclib -fno-objc-arc \
      -arch $arch -mmacosx-version-min=$min_ver -isysroot $sdk \
      -framework Foundation \
      -install_name @rpath/LMX.framework/Versions/A/LMX \
      -o "$SANDBOX/lib/libLMX.dylib" \
      LMXParser.m LMXMutableDataAdditions.m LMXMutableStringAdditions.m
  ```

  reusing the same arch/SDK/min-version values `build-common.sh` exports for
  every other phase (implementation may route through `build_for_archs` for
  consistency, with the phase function doing the clang invocation). Because
  the install name is set at compile time, no rewrite step is needed.
- `lipo -create` the two dylibs, then
  `build_framework "LMX" "LMX" <universal dylib> <the 3 public headers> "1.0"`.
- Register `libLMX.dylib` → `LMX` → `LMX` in `DYLIB_MAP_*` for the
  verification gate.
- `-fno-objc-arc` because LMX 1.0 is manual retain/release, matching the rest
  of the (non-ARC) Adium codebase.
- The consumer keeps `#import <LMX/LMXParser.h>`; the app target's existing
  link and Copy Frameworks phases are unchanged.

### 3.4 Repo hygiene

- `git rm -r --cached Frameworks/FriBidi.framework Frameworks/LMX.framework`
  (~270 KB of stale i386-era binaries out of git).
- Add both paths to the existing "Vendored dependency frameworks" block in
  `.gitignore`, matching the other regenerated frameworks.

## 4. Testing

- **Category unit test** (existing UnitTests arrangement): RTL input → RTL,
  LTR input → LTR, empty string → Natural, neutral-only (digits/punctuation)
  → Natural, mixed string resolved by first strong character.
- **LMX smoke test**: reverse-parse a small XML snippet and assert element
  and character callbacks arrive in reverse document order. The parser is
  non-trivial state-machine logic; one behavioral test guards the
  from-source rebuild.
- **Structural verification**: both frameworks pass the existing gate in
  `build-universal-deps.sh` (universal archs, no absolute/sandbox dependency
  paths, correct symlink topology).

## 5. Out of scope

- Sparkle.framework arm64 — resolved by the Sparkle 2.x upgrade (#7).
- `Frameworks/Growl.framework` zero-byte placeholder.
- Any fribidi capability beyond what `-baseWritingDirection` needs (no
  shaping, reordering, or char-set APIs are exposed to consumers).
