#!/usr/bin/env python3
r"""Property-based + targeted tests for the analyze-gate finding-extraction
pipeline (issue #346).

Drives the REAL pipeline — scripts/analyze-extract.sh — via subprocess, not a
reimplementation, so the tests stay honest about what the gate actually parses.
The pipeline reshapes an `xcodebuild analyze` log line

    <abs-path>:<line>:<col>: warning: <message> [<checker>]

into a tab-separated tuple

    <checker>\t<path>\t<message>

(stripping the repo-root prefix, dropping line/col). This suite guards two
documented failure modes:

  FM1 — bracketed prose swallowed into the checker field. A message ending in
        prose like "[Note]" (no real checker) used to be captured by the greedy
        \[([A-Za-z][A-Za-z0-9._]*)\]$ as if it were a checker name, emitting a
        bogus tuple that never matches the baseline entry (false "new"
        finding). Fixed by requiring the checker suffix to be a DOTTED
        identifier (deadcode.DeadStores) — prose never carries a dot.
  FM2 — path mis-split on ":N:N: warning:"-like text. A message that quotes a
        "path:line:col: warning:" snippet dragged the reshape's greedy path
        group across the boundary, corrupting the path. Fixed by matching the
        path as [^:]+ — a colon can never appear in a macOS filename, so the
        first colon in the line is always the line-number boundary.

Round-trip property (Hypothesis): a batch of well-formed generated lines
round-trips to exactly their tuples — checker == dotted bracket suffix,
path == the path part (relative under the project dir), message == the text
between "warning: " and " [checker]". Messages are generated adversarially
(bracketed prose, colon snippets, quotes, dots) so the property would catch a
re-broken FM1/FM2.

Invariants on generated messages: no newline (a log line is one physical line)
and no tab (the tuple is tab-separated; clang doesn't emit tabs in analyzer
messages). Both are documented here rather than handled in the pipeline.

The FM1/FM2 targeted tests below are plain unittest (no Hypothesis) — they pin
the exact corrupted inputs from the issue, so a regression is a clear,
human-readable failure without decoding a shrink.

Run from the repo root:  python3 -m unittest discover -s Tests/CoverageHost -v
"""

import os
import string
import subprocess
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXTRACT_SCRIPT = os.path.join(REPO_ROOT, "scripts", "analyze-extract.sh")

try:
    from hypothesis import HealthCheck, given, settings, strategies as st
    HAS_HYPOTHESIS = True
except ImportError:
    HAS_HYPOTHESIS = False


def extract(project_dir, log_text):
    """Run the real extraction pipeline; return (stdout, returncode)."""
    proc = subprocess.run(
        [EXTRACT_SCRIPT, project_dir],
        input=log_text,
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.stdout, proc.returncode


class FindingExtractionTargetedRegression(unittest.TestCase):
    """Pin the exact corrupted inputs from issue #346 — plain unittest so a
    regression is a clear, human-readable failure (no Hypothesis shrinking to
    decode)."""

    def test_prose_bracket_without_checker_is_not_extracted(self):
        # FM1: a message ending in bracketed prose ("[Note]") with no real
        # checker. The old greedy \[(\w+)\]$ captured "[Note]" as the checker,
        # emitting "Note\t<path>\texpression result is unused" — a bogus tuple
        # that never matches the baseline entry.
        with tempfile.TemporaryDirectory() as td:
            line = "{}/File.m:1:2: warning: expression result is unused [Note]\n".format(td)
            stdout, rc = extract(td, line)
            self.assertEqual(rc, 0)
            self.assertEqual(stdout, "")

    def test_prose_bracket_inside_message_keeps_real_checker(self):
        # FM1b: bracketed prose INSIDE the message, before the real checker,
        # must stay in the message — the dotted-checker requirement must not
        # over-filter real findings.
        with tempfile.TemporaryDirectory() as td:
            rel = "Frameworks/Adium/Source/File.m"
            line = "{}/{rel}:123:9: warning: value stored [Note] is never read [deadcode.DeadStores]\n".format(td, rel=rel)
            stdout, rc = extract(td, line)
            self.assertEqual(rc, 0)
            self.assertEqual(stdout, "deadcode.DeadStores\t{}\tvalue stored [Note] is never read\n".format(rel))

    def test_message_quoting_another_warning_does_not_mis_split_path(self):
        # FM2: a message that quotes "path:line:col: warning:" text. The old
        # greedy (.+) path group jumped to the LAST ":N:N: warning:", dragging
        # "File.m:123:9: warning: see /tmp/foo.c" into the path field and
        # truncating the message to "example".
        with tempfile.TemporaryDirectory() as td:
            rel = "Frameworks/Adium/Source/File.m"
            msg = "see /tmp/foo.c:5:2: warning: example"
            line = "{}/{rel}:123:9: warning: {msg} [core.NullDereference]\n".format(td, rel=rel, msg=msg)
            stdout, rc = extract(td, line)
            self.assertEqual(rc, 0)
            self.assertEqual(stdout, "core.NullDereference\t{}\t{}\n".format(rel, msg))

    def test_real_baseline_findings_extract_unchanged(self):
        # A representative sample of the 57 baselined findings (all dotted
        # checkers) must extract to exactly their baseline entries — guards the
        # dotted-checker requirement against over-filtering real output.
        rows = [
            ("core.FixedAddressDereference", "Source/ESDebugController.m",
             "Dereference of a fixed address"),
            ("core.NullDereference", "Plugins/Bonjour/libezv/Simple HTTP Server/AsyncSocket.m",
             "Access to field 'sin6_port' results in a dereference of a null pointer (loaded from variable 'pSockAddr6')"),
            ("core.UndefinedBinaryOperatorResult", "Source/AIListLayoutWindowController.m",
             "The left operand of '!=' is a garbage value"),
            ("deadcode.DeadStores", "Dependencies/MMTabBarView/MMTabBarView/MMTabBarView/MMTabBarController.m",
             "Value stored to 'totalOccupiedWidth' is never read"),
        ]
        with tempfile.TemporaryDirectory() as td:
            lines = "\n".join("{}/{}:1:1: warning: {} [{}]".format(td, p, m, c)
                              for c, p, m in rows) + "\n"
            stdout, rc = extract(td, lines)
            self.assertEqual(rc, 0)
            # Order-independent (sort -u collation) — same multiset as above.
            expected = ["{}\t{}\t{}".format(c, p, m) for c, p, m in rows]
            self.assertEqual(sorted(stdout.splitlines()), sorted(expected))

    def test_non_finding_lines_are_ignored(self):
        with tempfile.TemporaryDirectory() as td:
            lines = "\n".join([
                "Analyzing Frameworks/Adium/Source/File.m",          # progress line
                "{}:1:2: warning: unused variable 'x' [-Wunused-variable]".format(td),  # -W flag, not a checker
                "{}:1:2: error: unknown type name 'gboolean'".format(td),               # error, not a warning
                "** ANALYZE SUCCEEDED **",                           # completion marker
            ]) + "\n"
            stdout, rc = extract(td, lines)
            self.assertEqual(rc, 0)
            self.assertEqual(stdout, "")

    def test_empty_log_is_empty_findings(self):
        with tempfile.TemporaryDirectory() as td:
            stdout, rc = extract(td, "")
            self.assertEqual(rc, 0)
            self.assertEqual(stdout, "")

    def test_project_dir_with_regex_metacharacters(self):
        # The project dir is interpolated into a sed PATTERN — regex metachars
        # in it must not corrupt the prefix strip (e.g. a repo path "my[repo]").
        with tempfile.TemporaryDirectory() as td:
            proj = os.path.join(td, "proj[1]+x")
            os.makedirs(proj)
            line = "{}/Source/File.m:1:1: warning: msg [deadcode.DeadStores]\n".format(proj)
            stdout, rc = extract(proj, line)
            self.assertEqual(rc, 0)
            self.assertEqual(stdout, "deadcode.DeadStores\tSource/File.m\tmsg\n")


if HAS_HYPOTHESIS:
    # Real checker names from scripts/analyze-baseline.txt plus generated
    # dotted names — the pipeline must accept the whole dotted checker space.
    _REAL_CHECKERS = [
        "core.FixedAddressDereference",
        "core.NullDereference",
        "core.UndefinedBinaryOperatorResult",
        "core.CallAndMessage",
        "core.NonNullParamChecker",
        "deadcode.DeadStores",
        "nullability.NullPassedToNonnull",
        "nullability.NullReturnedFromNonnull",
        "osx.cocoa.RetainCount",
        "osx.cocoa.UnusedIvars",
        "osx.ObjCProperty",
        "unix.Malloc",
    ]

    # Adversarial message fragments: bracketed prose, ":N:N: warning:"-style
    # snippets, quotes, dots, colons — the inputs that used to corrupt the
    # split. All free of newline (a log line is one physical line) and tab
    # (the tuple is tab-separated).
    _MESSAGE_FRAGMENTS = [
        "Value stored to 'x' is never read",
        "Potential leak of an object allocated on line 12",
        "1st function call argument is an uninitialized value",
        "[Note]",
        "[sic]",
        "[deprecated]",
        "value stored [Note] is never read",
        "see /tmp/foo.c:5:2: warning: example",
        "reached via /build/a.m:3:4: warning: here",
        "'quoted [text]' with dotted.prose: right here",
        "requires [foo.bar] framework",
        "assignment to 'unsigned char *' from 'char *'",
    ]

    _path_component = st.text(
        alphabet=string.ascii_letters + string.digits + "_-",
        min_size=1, max_size=12,
    ).filter(lambda s: s not in (".", ".."))
    _path_tail = st.lists(_path_component, min_size=1, max_size=3).map("/".join)

    @st.composite
    def _dotted_checker(draw):
        if draw(st.booleans()):
            return draw(st.sampled_from(_REAL_CHECKERS))
        domain = draw(st.text(alphabet=string.ascii_lowercase, min_size=1, max_size=10))
        name = draw(st.text(alphabet=string.ascii_lowercase, min_size=1, max_size=10))
        return "{}.{}".format(domain, name.capitalize())

    @st.composite
    def _message(draw):
        count = draw(st.integers(min_value=1, max_value=5))
        return " ".join(draw(st.sampled_from(_MESSAGE_FRAGMENTS)) for _ in range(count))

    @st.composite
    def _finding(draw):
        in_project = draw(st.booleans())
        path_tail = draw(_path_tail)
        line = draw(st.integers(min_value=1, max_value=9999))
        col = draw(st.integers(min_value=1, max_value=9999))
        message = draw(_message())
        checker = draw(_dotted_checker())
        return in_project, path_tail, line, col, message, checker


if HAS_HYPOTHESIS:
    # The @given/@settings decorators below are evaluated at class-body time,
    # so the whole class must be hidden when hypothesis is absent (not just
    # @skipUnless'd — a NameError would otherwise break the entire discover
    # run). CI installs a pinned hypothesis (see .github/workflows/ci.yml);
    # the targeted regression tests above still run without it.
    class FindingExtractionRoundTrip(unittest.TestCase):
        """Hypothesis round-trip property: any batch of well-formed generated
        lines extracts to exactly their checker\tpath\tmessage tuples."""

        @given(findings=st.lists(_finding(), min_size=1, max_size=8))
        @settings(max_examples=150, deadline=None, suppress_health_check=[HealthCheck.too_slow])
        def test_round_trip_extracts_exact_tuples(self, findings):
            with tempfile.TemporaryDirectory() as td:
                lines = []
                expected = []
                for in_project, path_tail, line, col, message, checker in findings:
                    if in_project:
                        abs_path = os.path.join(td, path_tail)
                        out_path = path_tail
                    else:
                        # A system-header path outside the repo: the prefix
                        # strip leaves it absolute, and it must survive reshape
                        # unchanged.
                        abs_path = os.path.join("/usr/include", path_tail)
                        out_path = abs_path
                    lines.append("{}:{}:{}: warning: {} [{}]".format(abs_path, line, col, message, checker))
                    expected.append("{}\t{}\t{}".format(checker, out_path, message))
                stdout, rc = extract(td, "\n".join(lines) + "\n")
                self.assertEqual(rc, 0)
                # Compare as sets, not exact order: the pipeline's `sort -u`
                # uses locale-aware BSD sort (a tab collates after "/", where
                # Python puts 0x09 first), and the gate consumes tuples as a SET
                # (grep -vxF), so order is not a contract. Identical findings
                # collapse to one tuple under sort -u — hence the separate dedup
                # assertion below.
                actual_lines = stdout.splitlines()
                self.assertEqual(set(actual_lines), set(expected))
                self.assertEqual(len(actual_lines), len(set(actual_lines)))


if __name__ == "__main__":
    unittest.main()
