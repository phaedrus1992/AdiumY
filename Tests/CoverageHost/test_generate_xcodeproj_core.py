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
  - #324: the CoverageHost stub's AIEventHandlerGroupType (and its
          EVENT_HANDLER_GROUP_COUNT) must stay in lockstep with the real header;
          the live-file test is the CI enforcement.
"""

import json
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
import unittest.mock

sys.path.insert(0, os.path.dirname(__file__))

from generate_xcodeproj_core import (
    build_compile_entries,
    compile_command,
    discover_unit_test_sources,
    event_handler_group_count_drift,
    expand_build_path,
    extract_event_handler_group_count,
    sources_for_target,
    validate_source_paths,
    write_compile_commands_atomic,
    xcrun_query,
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

    def test_empty_entry_skipped(self):
        # Pre-review P1: an empty/whitespace entry once normalized to the
        # project dir itself and was emitted as a search-path flag.
        self.assertIsNone(expand_build_path("", "/proj"))
        self.assertIsNone(expand_build_path("   ", "/proj"))
        self.assertIsNone(expand_build_path('""', "/proj"))

    def test_unmatched_quote_skipped(self):
        # Pre-review P2: a lone quote was kept as a literal in the resolved
        # path, producing a flag clangd can't resolve.
        self.assertIsNone(expand_build_path('"unterminated', "/proj"))
        self.assertIsNone(expand_build_path('a"b', "/proj"))
        self.assertIsNone(expand_build_path('$(SRCROOT)/"x', "/proj"))


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

    def test_missing_target_returns_empty(self):
        self.assertEqual(sources_for_target("NOPE", self._objects(), "/proj"), [])

    def test_target_without_build_phases_returns_empty(self):
        objs = self._objects()
        objs["T2"] = {"isa": "PBXNativeTarget"}
        self.assertEqual(sources_for_target("T2", objs, "/proj"), [])

    def test_includes_objcpp_model_ref(self):
        # Pre-review P2: a wired ObjC++ TU (sourcecode.cpp.objcpp) was silently
        # dropped by the objc-only type filter.
        objs = self._objects()
        objs["R3"] = {"lastKnownFileType": "sourcecode.cpp.objcpp", "path": "a.mm",
                      "sourceTree": "<group>"}
        got = sources_for_target("T", objs, "/proj")
        self.assertEqual(
            got,
            [os.path.normpath("/proj/Sub/b.m"), os.path.normpath("/proj/a.m"),
             os.path.normpath("/proj/a.mm")],
        )

    def test_empty_path_ref_skipped(self):
        objs = self._objects()
        objs["R1"] = {"lastKnownFileType": "sourcecode.c.objc", "path": "",
                      "sourceTree": "<group>"}
        got = sources_for_target("T", objs, "/proj")
        self.assertEqual(got, [os.path.normpath("/proj/Sub/b.m")])


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

    def test_roundtrips_varied_flag_domain(self):
        # Pre-review P1: the shlex round-trip was pinned with one fixed flag
        # list. Flags are a wide domain (spaces, quotes, $, =, empty values) —
        # every token must survive shlex.join → shlex.split.
        source = "/abs/a.m"
        cases = [
            ["-fobjc-arc"],
            ["-I", "/dir with spaces/sub"],
            ["-D", 'FOO="bar baz"'],
            ["-D", "X=$SHELL"],
            ["-D", "A=1", "-D", "B=2"],
            ["-isysroot", "/path with quote's"],
            ["-I", ""],
            ["-Wl,-rpath,/a b/c"],
            ["-include", "/prefix.h", "-I", "/a b/c", "-D", "K=v with spaces"],
            ["-std=c++17", "-Wno-everything"],
        ]
        for flags in cases:
            with self.subTest(flags=flags):
                self.assertEqual(
                    shlex.split(compile_command("/usr/bin/clang", flags, source)),
                    self._tokens(source, flags),
                )

    def test_language_flag_follows_lowercased_mm_suffix(self):
        # `.MM` is ObjC++; any other spelling (multi-dot, no dot, bare "mm")
        # is plain ObjC.
        self.assertIn("-x objective-c++", compile_command("clang", [], "/x.MM"))
        self.assertNotIn("objective-c++", compile_command("clang", [], "/x.mm.txt"))
        self.assertNotIn("objective-c++", compile_command("clang", [], "no-ext"))
        self.assertNotIn("objective-c++", compile_command("clang", [], "mm"))

    def test_compiler_path_with_spaces_roundtrips(self):
        compiler = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
        flags = ["-fobjc-arc"]
        source = "/abs/a.m"
        self.assertEqual(
            shlex.split(compile_command(compiler, flags, source)),
            [compiler] + ["-x", "objective-c"] + flags + ["-c", source, "-o", "/dev/null"],
        )


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
            self.assertEqual([n for n in os.listdir(d) if n.endswith(".tmp")], [])

    def test_replace_failure_leaves_no_tmp_and_raises(self):
        # Pre-review P1: an interrupted write (here, a directory parked where
        # the database goes, so os.replace fails) must not leave a stray .tmp
        # behind and must abort naming the path.
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "compile_commands.json")
            os.mkdir(out)
            with self.assertRaises(SystemExit):
                write_compile_commands_atomic([{"a": 1}], out)
            self.assertEqual([n for n in os.listdir(d) if n.endswith(".tmp")], [])

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
            "R8": {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.c.objc",
                   "path": "built-elsewhere.m", "sourceTree": "BUILT_PRODUCTS_DIR"},
        }

    def test_reports_only_missing_source_files(self):
        with tempfile.TemporaryDirectory() as d:
            missing = validate_source_paths(self._objects(d), d)
            self.assertEqual(
                missing,
                sorted([os.path.normpath(os.path.join(d, "missing.h")),
                        os.path.normpath(os.path.join(d, "missing.m"))]),
            )

    def test_non_group_source_tree_refs_skipped(self):
        # Pre-review P2: a sourcecode ref rooted elsewhere (BUILT_PRODUCTS_DIR,
        # SOURCE_ROOT) resolves outside project_dir — checking it here would be
        # a wrong "missing source" abort. The validator must skip it like the
        # source resolver does.
        with tempfile.TemporaryDirectory() as d:
            objs = self._objects(d)
            objs["R9"] = {"isa": "PBXFileReference",
                          "lastKnownFileType": "sourcecode.c.objc",
                          "path": "definitely-missing.m",
                          "sourceTree": "SOURCE_ROOT"}
            self.assertNotIn(
                os.path.normpath(os.path.join(d, "definitely-missing.m")),
                validate_source_paths(objs, d),
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


class XcrunQueryTest(unittest.TestCase):
    """#298: SDK queries fail with an actionable SystemExit, not a traceback."""

    def _patched_run(self, side_effect=None, stdout=""):
        return unittest.mock.patch(
            "generate_xcodeproj_core.subprocess.run",
            return_value=unittest.mock.Mock(stdout=stdout),
            side_effect=side_effect,
        )

    def test_success_strips_and_builds_argv(self):
        sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
        with self._patched_run(stdout="  %s\n" % sdk_path) as mock_run:
            self.assertEqual(xcrun_query(["--show-sdk-path"], "macosx"), sdk_path)
        mock_run.assert_called_once_with(
            ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
            text=True,
            capture_output=True,
            check=True,
        )

    def test_called_process_error_raises_system_exit_with_query_and_hint(self):
        err = subprocess.CalledProcessError(
            1,
            ["xcrun", "--sdk", "macosx", "--find", "clang"],
            stderr='xcrun: error: SDK "macosx" cannot be located\n',
        )
        with self._patched_run(side_effect=err):
            with self.assertRaises(SystemExit) as cm:
                xcrun_query(["--find", "clang"], "macosx")
        msg = str(cm.exception)
        self.assertIn("macosx", msg)
        self.assertIn("xcrun --sdk macosx --find clang", msg)
        self.assertIn('xcrun: error: SDK "macosx" cannot be located', msg)
        self.assertIn(
            "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer", msg
        )

    def test_missing_xcrun_binary_raises_system_exit(self):
        # OSError (xcrun itself absent) is the same failure surface as a
        # non-zero exit: the hint, not a FileNotFoundError traceback.
        with self._patched_run(side_effect=FileNotFoundError("xcrun")):
            with self.assertRaises(SystemExit):
                xcrun_query(["--show-sdk-platform-path"], "macosx")

    def test_empty_stdout_raises_system_exit(self):
        # A query that "succeeds" but returns nothing must not silently yield
        # an empty SDK path — same actionable hint as a hard failure.
        with self._patched_run(stdout="  \n"):
            with self.assertRaises(SystemExit) as cm:
                xcrun_query(["--show-sdk-path"], "macosx")
        self.assertIn("returned no output", str(cm.exception))


class EventHandlerGroupCountDriftTest(unittest.TestCase):
    """#324: the CoverageHost stub's AIEventHandlerGroupType must track the real
    header. The live-file test below runs in CI on every push/PR (the generator
    itself only runs on `make xcodeproj`), so a stale stub count fails CI, not
    just a local regeneration."""

    @classmethod
    def setUpClass(cls):
        # Tests/CoverageHost → up two levels is the repo root.
        cls.test_dir = os.path.dirname(os.path.abspath(__file__))
        cls.repo_root = os.path.dirname(os.path.dirname(cls.test_dir))

    def _header(self, text):
        fd, path = tempfile.mkstemp(suffix=".h")
        with os.fdopen(fd, "w") as f:
            f.write(text)
        self.addCleanup(os.unlink, path)
        return path

    def test_live_headers_in_lockstep(self):
        # The enforcement test: the committed stub and the real header must both
        # exist and agree today, or CI fails and the register-guard coverage is
        # provably stale.
        real = os.path.join(self.repo_root, "Frameworks", "Adium", "Source",
                            "AIContactAlertsControllerProtocol.h")
        stub = os.path.join(self.test_dir, "AdiumY", "AIContactAlertsControllerProtocol.h")
        self.assertTrue(os.path.isfile(real), f"real header missing: {real}")
        self.assertTrue(os.path.isfile(stub), f"stub header missing: {stub}")
        self.assertEqual(
            event_handler_group_count_drift(real, stub),
            [],
            "CoverageHost stub EVENT_HANDLER_GROUP_COUNT drifted from the real "
            "header — update Tests/CoverageHost/AdiumY/AIContactAlertsControllerProtocol.h",
        )

    def test_matching_counts_return_empty(self):
        text = "#define EVENT_HANDLER_GROUP_COUNT 5\n"
        self.assertEqual(
            event_handler_group_count_drift(self._header(text), self._header(text)),
            [],
        )

    def test_mismatched_counts_return_error(self):
        real = self._header("#define EVENT_HANDLER_GROUP_COUNT 6\n")
        stub = self._header("#define EVENT_HANDLER_GROUP_COUNT 5\n")
        errors = event_handler_group_count_drift(real, stub)
        self.assertEqual(len(errors), 1)
        self.assertIn("real header = 6", errors[0])
        self.assertIn("CoverageHost stub = 5", errors[0])

    def test_missing_define_raises_value_error(self):
        with self.assertRaises(ValueError):
            extract_event_handler_group_count(self._header("enum X { A, B };\n"))

    def test_missing_define_reported_as_drift_not_crash(self):
        # A header that lost the define is a broken binding; drift must report
        # it as an error rather than propagate a traceback through the generator.
        stub = self._header("enum AIEventHandlerGroupType { A, B };\n")
        errors = event_handler_group_count_drift(self._header("#define EVENT_HANDLER_GROUP_COUNT 5\n"), stub)
        self.assertEqual(len(errors), 1)
        self.assertIn("EVENT_HANDLER_GROUP_COUNT", errors[0])


if __name__ == "__main__":
    unittest.main()
