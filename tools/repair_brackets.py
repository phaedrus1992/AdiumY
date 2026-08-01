#!/usr/bin/env python3
"""Find and repair unbalanced brackets in Objective-C source files.

Purpose
-------
Legacy codebases migrated to ARC (e.g. by an automated conversion tool) often
end up with corrupted bracket balance at statement boundaries: a stray `)` left
from a removed `autorelease)`, an extra `[` at the start of a statement whose
matching `]` was dropped, or an off-by-one on the trailing `]]]` run. These are
mechanical edits where whitespace differs from file to file, so string-based
editors keep failing to match. This tool counts brackets only (ignoring strings,
comments, and whitespace), so it is immune to the codebase's whitespace style.

Modes
-----
check FILE...   Report every region where a bracket type's running balance is
                non-zero (i.e. the line where corruption begins) and any
                statements with a suspicious leading bracket run that could be
                an ARC-migration orphan `[`. Exit 1 if anything is found.
fix FILE...     Rebalance statements whose `]`/`)` counts are off, adjusting
                only the statement's trailing bracket run, then verifying the
                result is balanced before writing. `{`/`}` are never touched;
                ambiguous or block-spanning cases are refused and reported.

Usage
-----
  tools/repair_brackets.py check Source/AIListWindowController.m
  tools/repair_brackets.py fix   Source/AIListWindowController.m
"""

import re
import sys
from pathlib import Path

TYPES = ("()", "[]", "{}")


def clean_source(src):
    """Return (cleaned, line_of_char) with strings/comments blanked.

    Every char inside a string or comment becomes a space, newlines stay as-is
    so line positions remain meaningful. `@""` literals, char literals, // and
    /* */ comments are all handled.
    """
    n = len(src)
    out = list(src)
    line_of = [0] * n
    line = 0
    i = 0
    in_block = in_line = False
    in_str = None  # '"' or "'"
    while i < n:
        line_of[i] = line
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "\n":
            line += 1
        if in_line:  # // comment
            out[i] = "\n" if c == "\n" else " "
            in_line = c != "\n"
            i += 1
            continue
        if in_block:  # /* comment */
            out[i] = "\n" if c == "\n" else " "
            if c == "*" and nxt == "/":
                in_block = False
                out[i + 1] = " "
                i += 2
                continue
            i += 1
            continue
        if in_str:  # string / char literal
            out[i] = "\n" if c == "\n" else " "
            if c == "\\":
                out[i + 1] = " "
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c == "/" and nxt == "/":
            in_line = True
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block = True
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if c in ('"', "'"):
            in_str = c
            out[i] = " "
            i += 1
            continue
        if c == "@" and nxt == '"':  # @"..." literal
            in_str = '"'
            out[i] = out[i + 1] = " "
            i += 2
            continue
        i += 1  # code char: keep as-is
    return "".join(out), line_of


def statement_boundaries(cleaned):
    """Char indexes of `;` that terminate a statement.

    A `;` is a boundary when `()` and `[]` are balanced at that point. `{}` depth
    is deliberately ignored: statements inside method bodies and blocks are just
    as much independent units. `for (...; ...; ...)` semicolons are at paren
    depth > 0 and are correctly not boundaries.
    """
    dp = db = 0
    out = []
    for i, c in enumerate(cleaned):
        if c == "(":
            dp += 1
        elif c == ")":
            dp -= 1
        elif c == "[":
            db += 1
        elif c == "]":
            db -= 1
        elif c == ";" and dp == 0 and db == 0:
            out.append(i)
    return out


def balance_regions(cleaned, kind, boundaries):
    """Maximal spans where `kind` balance is non-zero AND crosses a boundary.

    A span of non-zero running depth that never reaches a `;` is just a normal
    parenthesised subexpression (`(void)`, `[Foo alloc]`) — fine. A span that
    reaches a statement boundary with depth still non-zero is corruption: the
    statement ended unbalanced.
    """
    depth = 0
    regions = []
    start = None
    for i, c in enumerate(cleaned):
        if c == kind[0]:
            depth += 1
        elif c == kind[1]:
            depth -= 1
        if depth != 0 and start is None:
            start = i
        elif depth == 0 and start is not None:
            if any(b in range(start, i) for b in boundaries):
                regions.append((start, i, 0))
            start = None
    if start is not None:
        regions.append((start, len(cleaned), depth))
    return regions


def brace_regions(cleaned):
    """`{}` imbalance. A `{...}` block is a legitimate non-zero span, so only
    two things are corruption: depth going negative (extra `}`) and an unclosed
    `{` at EOF. Each unmatched `{` is reported at its own position (not the
    first `{` in the file).
    """
    regions = []
    depth = 0
    stack = []  # char indexes of currently-open `{`
    neg_start = None
    for i, c in enumerate(cleaned):
        if c == "{":
            stack.append(i)
            depth += 1
        elif c == "}":
            if stack:
                stack.pop()
            depth -= 1
        if depth < 0 and neg_start is None:
            neg_start = i
        elif neg_start is not None and depth >= 0:
            regions.append((neg_start, i, 0))
            neg_start = None
    if neg_start is not None:
        regions.append((neg_start, len(cleaned), depth))
    for pos in stack:  # unclosed `{` at EOF
        regions.append((pos, len(cleaned), 1))
    return regions


def orphan_signatures(cleaned):
    """Char indexes of `= [[[<Class> alloc]` — a possible ARC-migration orphan.

    The `[X autorelease]` -> `X` rewrite sometimes drops `autorelease]` but keeps
    the outer `[`, turning `= [[Class alloc] initWith…]` into `= [[[Class alloc]
    initWith…]`. The alloc signature keeps this from firing on ordinary nested
    message chains like `[[[adium preferenceController] preferenceForKey:…]`.
    This is a hint for human review, not a definitive finding.
    """
    return [m.start() for m in re.finditer(r"=\s*\[\[\[\w+\s+alloc\]", cleaned)]


def excerpt(src_lines, line_of, start, end):
    fl, ll = line_of[start], line_of[max(end - 1, start)]
    text = " ".join(l.strip() for l in src_lines[fl : ll + 1])
    text = " ".join(text.split())
    return text[:110] + ("…" if len(text) > 110 else "")


def statement_bounds(cleaned, rs):
    """(start, end_of_semicolon) of the statement containing char `rs`.

    Boundaries are `;` with `()` and `[]` balanced (see statement_boundaries).
    Returns (None, None) if unterminated.
    """
    dp = db = 0
    stmt_start = 0
    for i in range(rs - 1, -1, -1):
        c = cleaned[i]
        if c == "(":
            dp += 1
        elif c == ")":
            dp -= 1
        elif c == "[":
            db += 1
        elif c == "]":
            db -= 1
        elif c == ";" and dp == 0 and db == 0:
            stmt_start = i + 1
            break
    dp = db = 0
    stmt_end = None
    for i in range(stmt_start, len(cleaned)):
        c = cleaned[i]
        if c == "(":
            dp += 1
        elif c == ")":
            dp -= 1
        elif c == "[":
            db += 1
        elif c == "]":
            db -= 1
        elif c == ";" and dp == 0 and db == 0:
            stmt_end = i
            break
    return (stmt_start, stmt_end) if stmt_end is not None else (None, None)


def fix_statement(cleaned, stmt_start, stmt_end):
    """Return repaired text for [stmt_start, stmt_end), or None if unsafe.

    Adjusts only the trailing `]`/`)` run: surplus closers are stripped off the
    end, missing ones appended. The result is verified balanced before it is
    returned. Refuses if the statement contains a block, or if balancing fails.
    """
    body = cleaned[stmt_start : stmt_end + 1]
    if any(c in "{}" for c in body):
        return None
    extra_j = body.count("]") - body.count("[")
    extra_p = body.count(")") - body.count("(")
    if extra_j == 0 and extra_p == 0:
        return None  # nothing to fix
    # Trailing run of closers before the ';'.
    j = stmt_end - 1
    run_len = 0
    while j >= stmt_start and cleaned[j] in "])":
        run_len += 1
        j -= 1
    run = body[stmt_end - run_len : stmt_end]
    # Strip surplus closers from the run (prefer the end).
    keep = []
    strip_j, strip_p = max(0, extra_j), max(0, extra_p)
    for ch in reversed(run):
        if ch == "]" and strip_j:
            strip_j -= 1
        elif ch == ")" and strip_p:
            strip_p -= 1
        else:
            keep.append(ch)
    new_run = list(reversed(keep))
    # Append missing closers.
    new_run.extend("]" * max(0, -extra_j))
    new_run.extend(")" * max(0, -extra_p))
    candidate = body[: stmt_end - run_len] + "".join(new_run) + ";"
    if candidate.count("[") == candidate.count("]") and candidate.count("(") == candidate.count(")"):
        return candidate
    return None


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("check", "fix"):
        print(__doc__)
        sys.exit(2)
    mode, paths = sys.argv[1], sys.argv[2:]
    bad = 0
    for p in paths:
        data = Path(p).read_text(encoding="utf-8")
        cleaned, line_of = clean_source(data)
        src_lines = data.split("\n")
        boundaries = statement_boundaries(cleaned)
        problems = []
        for kind in ("()", "[]"):
            for s, e, net in balance_regions(cleaned, kind, boundaries):
                problems.append((kind, s, e, net))
        for s, e, net in brace_regions(cleaned):
            problems.append(("{}", s, e, net))
        problems.sort(key=lambda r: r[1])
        if mode == "check":
            if problems:
                for kind, s, e, net in problems:
                    print(f"{p}:{line_of[s] + 1} [{kind} net {net}] :: {excerpt(src_lines, line_of, s, e)}")
                bad = 1
            for i in orphan_signatures(cleaned):
                print(f"{p}:{line_of[i] + 1} [orphan-?] :: {excerpt(src_lines, line_of, i, i + 1)}")
                bad = 1
        else:
            changed = False
            for kind, s, e, net in sorted(problems, key=lambda r: -r[1]):
                if kind == "{}":
                    print(f"{p}:{line_of[s] + 1} unbalanced {{}} — manual fix")
                    continue
                stmt_start, stmt_end = statement_bounds(cleaned, s)
                if stmt_start is None:
                    print(f"{p}:{line_of[s] + 1} unterminated statement — manual fix")
                    continue
                fixed = fix_statement(cleaned, stmt_start, stmt_end)
                if fixed is None:
                    print(f"{p}:{line_of[s] + 1} ambiguous — manual fix")
                    continue
                if fixed != cleaned[stmt_start : stmt_end + 1]:
                    cleaned = cleaned[:stmt_start] + fixed + cleaned[stmt_end + 1 :]
                    changed = True
            if changed:
                Path(p).write_text(cleaned, encoding="utf-8")
                print(f"repaired {p}")
            else:
                print(f"no changes for {p}")
    sys.exit(bad)


if __name__ == "__main__":
    main()
