#!/usr/bin/env python3
"""Unit tests for generate_xcodeproj_core.py — the pure helpers behind
Tests/CoverageHost/generate-xcodeproj.py.

Run from the repo root:  python3 -m unittest discover -s Tests/CoverageHost -v
or from Tests/CoverageHost:  python3 -m unittest -v test_generate_xcodeproj_core

Covers the generator hardening deferred from PR #292 review (issues #294, #295,
#296) and #194:
  - #294: command serialization round-trips through shlex; byte-deterministic
          output; _expand_build_path idempotence + no-exception; _sources_for_target
          absolute/ObjC/sorted; bijection between sources and entries.
  - #295: sourceTree / $(...) path-resolution drift guards; recursive UnitTests
          discovery including .mm (per-file -x objective-c++).
  - #296: atomic compile_commands.json write (temp file + os.replace).
  - #194: referenced source paths must exist before the project is emitted.
"""

import json
import os
import shlex
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))

from generate_xcodeproj_core import (
    build_compile_entries,
    compile_command,
    discover_unit_test_sources,
    expand_build_path,
    sources_for_target,
    validate_source_paths,
    write_compile_commands_atomic,
)


class ExpandBuildPathTest(unittest.TestCase):
    def test_plain_relative_joined_to_project_dir(self):
        self.assertEqual(
            expand_build_path("dir/sub", "/proj"),
            os.path.normpath("/proj/dir/sub"),
        )

    def test_absolute_stays_absolute(self):
        self.assertEqual(
            expand_build_path("/abs/x", "/proj"),
            os.path.normpath("/abs/x"),
        )

    def test_surrounding_quotes_stripped(self):
        self.assertEqual(
            expand_build_path('"dir/sub"', "/proj"),
            os.path.normpath("/proj/dir/sub"),
        )

    def test_padded_quoted_entry_normalized(self):
        # Pre-review P2: quote/whitespace ordering was once non-idempotent.
        self.assertEqual(
            expand_build_path('"  $(SRCROOT)/x  "', "/proj"),
            os.path.normpath("/proj/x"),
        )

    def test_srcroot_expanded(self):
        self.assertEqual(
            expand_build_path("$(SRCROOT)/Frameworks", "/proj"),
            os.path.normpath("/proj/Frameworks"),
        )

    def test_inherited_skipped(self):
        self.assertIsNone(expand_build_path("$(inherited)", "/proj"))

    def test_unresolved_build_var_skipped(self):
        self.assertIsNone(expand_build_path("$(FRAMEWORK_SEARCH_PATHS)", "/proj"))

    def test_non_string_entries_skipped(self):
        self.assertIsNone(expand_build_path(123, "/proj"))
        self.assertIsNone(expand_build_path(None, "/proj"))

    def test_idempotent(self):
        for entry in [
            "dir/sub", "/abs/x", '"dir/sub"', '"  $(SRCROOT)/x  "',
            "$(SRCROOT)/Frameworks", "$(inherited)", "$(FRAMEWORK_SEARCH_PATHS)",
            " ", "", "a b c", 'a"b',
        ]:
            first = expand_build_path(entry, "/proj")
            self.assertEqual(
                expand_build_path(first, "/proj") if first else first,
                first,
                f"expand_build_path not idempotent for {entry!r}",
            )

    def test_no_exception_on_arbitrary_strings(self):
        for entry in ["", " ", "\t", "$(", "()", '"unterminated', "\\", "a\nb",
                      "$(A)$(B)", '$(SRCROOT)/"x']:
            expand_build_path(entry, "/proj")  # must not raise


class SourcesForTargetTest(unittest.TestCase):
    def _objects(self):
        # Minimal flat model: one sources phase with ObjC files, a header, a
        # product ref, and a ref carrying an unresolved build variable.
        objs = {
            "T": {"buildPhases": ["P1"], "isa": "PBXNativeTarget"},
            "P1": {"isa": "PBXSourcesBuildPhase", "files": ["BF1", "BF2", "BF3", "BF4", "BF5"]},
            "BF1": {"fileRef": "R1"},  # a.m
            "BF2": {"fileRef": "R2"},  # b.m
            "BF3": {"fileRef": "R3"},  # header — not an ObjC TU
            "BF4": {"fileRef": "R4"},  # product ref — skipped by sourceTree
            "BF5": {"fileRef": "R5"},  # unresolved build-variable path — skipped
            "R1": {"lastKnownFileType": "sourcecode.c.objc", "path": "a.m", "sourceTree": "<group>"},
            "R2": {"lastKnownFileType": "sourcecode.c.objc", "path": "Sub/b.m", "sourceTree": "<group>"},
            "R3": {"lastKnownFileType": "sourcecode.c.h", "path": "a.h", "sourceTree": "<group>"},
            "R4": {"lastKnownFileType": "wrapper.framework", "path": "X.app", "sourceTree": "BUILT_PRODUCTS_DIR"},
            "R5": {"lastKnownFileType": "sourcecode.c.objc", "path": "$(PRODUCT_NAME)/Sub/c.m", "sourceTree": "<group>"},
        }
        return objs

    def test_returns_absolute_sorted_objc_only(self):
        got = sources_for_target("T", self._objects(), "/proj")
        self.assertEqual(
            got,
            [os.path.normpath("/proj/Sub/b.m"), os.path.normpath("/proj/a.m")],
        )
        for p in got:
            self.assertTrue(os.path.isabs(p))

    def test_skips_non_group_source_tree(self):
        objs = self._objects()
        objs["R2"] = {"lastKnownFileType": "sourcecode.c.objc", "path": "b.m",
                      "sourceTree": "BUILT_PRODUCTS_DIR"}
        got = sources_for_target("T", objs, "/proj")
        self.assertEqual(got, [os.path.normpath("/proj/a.m")])

    def test_skips_unresolved_build_variable(self):
        objs = self._objects()
        objs["R1"] = {"lastKnownFileType": "sourcecode.c.objc", "path": "$(SOURCE_ROOT)/a.m",
                      "sourceTree": "<group>"}
        got = sources_for_target("T", objs, "/proj")
        self.assertEqual(got, [os.path.normpath("/proj/Sub/b.m")])

    def test_srcroot_expands_to_project_dir(self):
        objs = self._objects()
        objs["R1"] = {"lastKnownFileType": "sourcecode.c.objc", "path": "$(SRCROOT)/a.m",
                      "sourceTree": "<group>"}
        got = sources_for_target("T", objs, "/proj")
        self.assertIn(os.path.normpath("/proj/a.m"), got)
        self.assertNotIn(os.path.normpath("/proj/proj/a.m"), got)

    def test_deterministic(self):
        objs = self._objects()
        self.assertEqual(
            sources_for_target("T", objs, "/proj"),
            sources_for_target("T", objs, "/proj"),
        )


class DiscoverUnitTestSourcesTest(unittest.TestCase):
    def test_recursive_glob_includes_mm(self):
        with tempfile.TemporaryDirectory() as repo:
            os.makedirs(os.path.join(repo, "UnitTests", "Sub"))
            open(os.path.join(repo, "UnitTests", "a.m"), "w").close()
            open(os.path.join(repo, "UnitTests", "Sub", "b.m"), "w").close()
            open(os.path.join(repo, "UnitTests", "Sub", "c.mm"), "w").close()
            open(os.path.join(repo, "UnitTests", "d.txt"), "w").close()  # not a TU
            got = discover_unit_test_sources(repo)
            self.assertEqual(
                got,
                sorted(os.path.normpath(p) for p in [
                    os.path.join(repo, "UnitTests", "Sub", "b.m"),
                    os.path.join(repo, "UnitTests", "Sub", "c.mm"),
                    os.path.join(repo, "UnitTests", "a.m"),
                ]),
            )

    def test_missing_dir_is_empty(self):
        with tempfile.TemporaryDirectory() as repo:
            self.assertEqual(discover_unit_test_sources(repo), [])


class CompileCommandTest(unittest.TestCase):
    def _tokens(self, source, flags=()):
        compiler = "/usr/bin/clang"
        return [compiler] + ["-x", "objective-c++" if source.lower().endswith(".mm")
                             else "objective-c"] + list(flags) + \
            ["-c", source, "-o", "/dev/null"]

    def test_roundtrips_through_shlex(self):
        source = "/abs/a.m"
        flags = ["-fobjc-arc", "-I", "/dir with spaces/sub", "-D", 'FOO="bar baz"']
        self.assertEqual(
            shlex.split(compile_command("/usr/bin/clang", flags, source)),
            self._tokens(source, flags),
        )

    def test_objc_uses_objective_c(self):
        cmd = compile_command("clang", [], "/abs/a.m")
        self.assertIn("-x objective-c", cmd)
        self.assertNotIn("objective-c++", cmd)

    def test_objcpp_uses_objective_cpp(self):
        cmd = compile_command("clang", [], "/abs/a.mm")
        self.assertIn("-x objective-c++", cmd)

    def test_deterministic(self):
        args = ("clang", ["-I", "/x"], "/abs/a.m")
        self.assertEqual(compile_command(*args), compile_command(*args))


class BuildCompileEntriesTest(unittest.TestCase):
    def test_bijection_sources_to_entries(self):
        sources = ["/a.m", "/b.mm", "/c.m"]
        entries = build_compile_entries("clang", ["-fobjc-arc"], sources, "/repo")
        self.assertEqual(len(entries), len(sources))
        for entry, src in zip(entries, sources):
            self.assertEqual(entry["file"], src)
            self.assertEqual(entry["directory"], "/repo")
            self.assertEqual(shlex.split(entry["command"])[0], "clang")

    def test_byte_deterministic_render(self):
        sources = ["/a.m", "/b.mm"]
        entries = build_compile_entries("clang", ["-fobjc-arc"], sources, "/repo")

        def render():
            return json.dumps(entries, indent=2) + "\n"

        self.assertEqual(render(), render())

    def test_preserves_source_order(self):
        sources = ["/z.m", "/a.m"]
        entries = build_compile_entries("clang", [], sources, "/repo")
        self.assertEqual([e["file"] for e in entries], sources)


class WriteCompileCommandsAtomicTest(unittest.TestCase):
    def test_writes_valid_json_with_newline(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "compile_commands.json")
            entries = [{"directory": "/repo", "command": "clang -c /a.m", "file": "/a.m"}]
            write_compile_commands_atomic(entries, out)
            with open(out) as f:
                content = f.read()
            self.assertTrue(content.endswith("\n"))
            self.assertEqual(json.loads(content), entries)

    def test_no_tmp_leftover(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "compile_commands.json")
            write_compile_commands_atomic([], out)
            self.assertTrue(os.path.exists(out))
            self.assertFalse(os.path.exists(out + ".tmp"))

    def test_overwrites_existing(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "compile_commands.json")
            with open(out, "w") as f:
                f.write("STALE")
            write_compile_commands_atomic([{"a": 1}], out)
            with open(out) as f:
                self.assertEqual(json.load(f), [{"a": 1}])

    def test_byte_identical_across_writes(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "compile_commands.json")
            entries = [{"directory": "/repo", "command": "clang -c /a.m", "file": "/a.m"}]
            write_compile_commands_atomic(entries, out)
            with open(out, "rb") as f:
                first = f.read()
            write_compile_commands_atomic(entries, out)
            with open(out, "rb") as f:
                self.assertEqual(f.read(), first)


class ValidateSourcePathsTest(unittest.TestCase):
    def _objects(self, tmpdir, real_a=True):
        a_path = os.path.join(tmpdir, "a.m")
        if real_a:
            open(a_path, "w").close()
        return {
            "R1": {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.c.objc",
                   "path": "a.m", "sourceTree": "<group>"},
            "R2": {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.c.objc",
                   "path": "missing.m", "sourceTree": "<group>"},
            "R3": {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.c.h",
                   "path": "missing.h", "sourceTree": "<group>"},
            "R4": {"isa": "PBXFileReference", "lastKnownFileType": "wrapper.framework",
                   "path": "XCTest.framework", "sourceTree": "<absolute>"},
            "R5": {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.c.objc",
                   "path": "$(SOURCE_ROOT)/x.m", "sourceTree": "<group>"},
            "R6": {"isa": "PBXFileReference", "path": "nofiletype.txt", "sourceTree": "<group>"},
            "R7": {"isa": "PBXBuildFile", "path": "not-a-ref.m", "sourceTree": "<group>"},
        }

    def test_reports_only_missing_source_files(self):
        with tempfile.TemporaryDirectory() as d:
            missing = validate_source_paths(self._objects(d), d)
            self.assertEqual(
                missing,
                sorted([os.path.normpath(os.path.join(d, "missing.h")),
                        os.path.normpath(os.path.join(d, "missing.m"))]),
            )

    def test_clean_model_returns_empty(self):
        with tempfile.TemporaryDirectory() as d:
            objs = self._objects(d)
            for ref in objs.values():
                if ref.get("path"):
                    ref_path = os.path.normpath(os.path.join(d, ref["path"]))
                    if not os.path.exists(ref_path):
                        os.makedirs(os.path.dirname(ref_path), exist_ok=True)
                        open(ref_path, "w").close()
            self.assertEqual(validate_source_paths(objs, d), [])


if __name__ == "__main__":
    unittest.main()
