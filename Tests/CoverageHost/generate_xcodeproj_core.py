#!/usr/bin/env python3
"""Pure helpers for generate-xcodeproj.py — importable without running the
generator's module-level side effects, so they're testable via `unittest`.

Everything here is deterministic over its arguments: no module globals, no
subprocess, no filesystem writes. generate-xcodeproj.py wires these against
its in-memory project model and the SDK; the tests exercise them with
synthetic inputs.
"""

import glob
import json
import os
import shlex


def expand_build_path(entry, project_dir):
    """Expand a build-setting path entry to absolute, or None if not a real path.

    Handles `$(inherited)` (skip), optional surrounding quotes, and
    `$(SRCROOT)`-relative entries (the harness's HEADER_SEARCH_PATHS style).
    Quotes are stripped before whitespace so a padded quoted entry
    (e.g. `"  $(SRCROOT)/x  "`) still normalizes; any other unresolved `$(...)`
    build variable (e.g. `$(FRAMEWORK_SEARCH_PATHS)`) is skipped rather than
    emitted as a literal path.
    """
    if not isinstance(entry, str):
        print(f"WARNING: skipping non-string build path entry {entry!r}")
        return None
    p = entry
    if len(p) >= 2 and p[0] == '"' and p[-1] == '"':
        p = p[1:-1]
    p = p.strip()
    if p == "$(inherited)":
        return None
    p = p.replace("$(SRCROOT)", project_dir)
    if "$(" in p:
        # Unresolved build variable (e.g. $(FRAMEWORK_SEARCH_PATHS)) this
        # generator can't expand — skip rather than emit a literal path, but
        # warn so a typo'd entry doesn't silently vanish from clangd's flags.
        print(f"WARNING: skipping unresolved build variable {entry!r} (cannot expand to a path)")
        return None
    if not os.path.isabs(p):
        p = os.path.join(project_dir, p)
    return os.path.normpath(p)


def _resolve_source_ref(path, source_tree, project_dir):
    """Resolve a PBXFileReference path to an absolute path, or None to skip.

    The model's source refs are `sourceTree: <group>` with paths relative to
    the project dir. Guard the two drift classes that would silently hand
    clangd a wrong or absent entry: a non-`<group>` sourceTree (product refs,
    SOURCE_ROOT), and a `$(...)` build variable the generator can't expand.
    """
    if source_tree not in (None, "<group>"):
        print(f"WARNING: skipping source ref {path!r} (sourceTree {source_tree!r})")
        return None
    p = path.replace("$(SRCROOT)", project_dir)
    if "$(" in p:
        print(f"WARNING: skipping source ref {path!r} (unresolved build variable)")
        return None
    if not os.path.isabs(p):
        p = os.path.join(project_dir, p)
    return os.path.normpath(p)


def sources_for_target(target_id, objects, project_dir):
    """Absolute paths of the ObjC translation units in a target's sources phase.

    Walks the target's PBXSourcesBuildPhases and their PBXFileReferences,
    resolving each ObjC TU against `project_dir` (see `_resolve_source_ref`).
    Deterministic: returns unique, sorted, absolute paths — never a relative or
    build-variable path.
    """
    files = []
    for phase_id in objects[target_id]["buildPhases"]:
        phase = objects[phase_id]
        if phase.get("isa") != "PBXSourcesBuildPhase":
            continue
        for build_file_id in phase.get("files", []):
            ref_id = objects[build_file_id].get("fileRef")
            if not ref_id:
                continue
            ref = objects.get(ref_id, {})
            if ref.get("lastKnownFileType") != "sourcecode.c.objc":
                continue
            path = ref.get("path", "")
            if not path:
                continue
            resolved = _resolve_source_ref(path, ref.get("sourceTree"), project_dir)
            if resolved is not None:
                files.append(resolved)
    return sorted(set(files))


def discover_unit_test_sources(repo_root):
    """Recursively discover UnitTests TUs (*.m, *.mm) for the clangd DB.

    The pbxproj must name every file explicitly, so a new test file that lands
    in UnitTests/ without touching the generator would silently get no clangd
    entry. Recursive so a `UnitTests/Sub/*.m` can't drop out of the database;
    `.mm` is included because ObjC++ TUs need `-x objective-c++`, which
    `compile_command` applies per-source. Returns absolute, normalized, sorted
    paths.
    """
    tests_dir = os.path.join(repo_root, "UnitTests")
    if not os.path.isdir(tests_dir):
        return []
    return sorted(
        os.path.normpath(p)
        for p in (glob.glob(os.path.join(tests_dir, "**", "*.m"), recursive=True) +
                  glob.glob(os.path.join(tests_dir, "**", "*.mm"), recursive=True))
    )


def compile_command(compiler, flags, source):
    """Serialise one compile_commands.json command as a shell token stream.

    clangd re-parses `command` with shlex; a malformed stream silently stops
    indexing the TU with no error surface. The language flag is added
    per-source — `.mm` TUs must parse as objective-c++, not objective-c.
    `flags` is the shared, language-agnostic flag list; its order is preserved
    so the emitted command keeps the pre-refactor shape.
    """
    lang = "objective-c++" if source.lower().endswith(".mm") else "objective-c"
    return shlex.join([compiler] + ["-x", lang] + list(flags) +
                      ["-c", source, "-o", "/dev/null"])


def build_compile_entries(compiler, flags, sources, directory):
    """Deterministic [{directory, command, file}] — one entry per source.

    Bijective: every source yields exactly one entry, in `sources` order. Same
    inputs always render to the same bytes (json.dump with indent + trailing
    newline), so regenerating the database is a no-op diff.
    """
    return [
        {"directory": directory,
         "command": compile_command(compiler, flags, source),
         "file": source}
        for source in sources
    ]


def write_compile_commands_atomic(entries, out_path):
    """Write compile_commands.json atomically (temp file + os.replace).

    A plain open("w") truncates the previous database before json.dump writes;
    an interrupt mid-write (disk-full OSError, Ctrl-C, SIGKILL) would leave
    truncated JSON behind and clangd silently fall back to standalone mode.
    os.replace is atomic on POSIX — the old database survives until the new one
    is complete.
    """
    tmp = out_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(entries, f, indent=2)
        f.write("\n")
    os.replace(tmp, out_path)


def validate_source_paths(objects, project_dir):
    """Source paths referenced by the project model that don't exist on disk.

    Every PBXFileReference for a committed source file — `sourcecode.*` (ObjC/
    C/C++ sources + headers) and `text.plist.*` (Info.plist) types, the class
    of hardcoded path this guards — must exist relative to `project_dir`.
    Framework refs (`wrapper.*`) are excluded: they're linked, not compiled,
    and system frameworks (`sourceTree: <absolute>`, e.g. XCTest) legitimately
    live outside the repo. Returns the missing absolute paths, sorted; the
    caller aborts naming them instead of letting xcodebuild fail opaquely.
    """
    missing = []
    for ref in objects.values():
        if ref.get("isa") != "PBXFileReference":
            continue
        ftype = ref.get("lastKnownFileType") or ""
        if not (ftype.startswith("sourcecode.") or ftype.startswith("text.plist.")):
            continue
        path = ref.get("path")
        if not path:
            continue
        p = path.replace("$(SRCROOT)", project_dir)
        if "$(" in p:
            continue
        abs_path = os.path.normpath(os.path.join(project_dir, p))
        if not os.path.exists(abs_path):
            missing.append(abs_path)
    return sorted(missing)
