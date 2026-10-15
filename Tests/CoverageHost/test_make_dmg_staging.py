#!/usr/bin/env python3
"""Behavioral test for Release/make-dmg.sh's staged text files.

The disk image carries three companions to the app bundle: Changes.txt,
License.txt, and the Finder layout. A wrong source file there does not fail
loudly — the image builds, uploads, and ships the wrong content, which is how
the 2.0.1 DMG shipped the upstream 1.x history as its changelog (#406).

The test drives the real script through the mocks/ hdiutil and SetFile, with a
stub app bundle, and inspects the finished image:

  - Changes.txt carries the repo's live changelog (CHANGELOG.md) — the 2.x
    release record — not the frozen 1.x history in ChangeLogs/;
  - License.txt carries the repo's License.txt;
  - the item name stays "Changes.txt", because both the baked .DS_Store and the
    AppleScript fallback position an item by that name.

Run from the repo root:  python3 -m unittest discover -s Tests/CoverageHost -v
Run just this file:      python3 -m unittest discover -s Tests/CoverageHost -p 'test_make_dmg_staging*' -v
"""

import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MAKE_DMG = REPO_ROOT / "Release" / "make-dmg.sh"
MOCK_BIN = pathlib.Path(__file__).resolve().parent / "mocks"
CHANGELOG = REPO_ROOT / "CHANGELOG.md"
LICENSE = REPO_ROOT / "License.txt"


def build_image(temp):
    """Run make-dmg.sh in a hermetic tree; return the mounted image path."""
    app = pathlib.Path(temp) / "AdiumY.app"
    app.mkdir()
    (app / "Contents").mkdir()
    output = pathlib.Path(temp) / "out" / "AdiumY-9.9.9.dmg"

    env = dict(os.environ)
    env["PATH"] = f"{MOCK_BIN}:{env['PATH']}"
    env["TMPDIR"] = temp

    result = subprocess.run(
        ["bash", str(MAKE_DMG), str(app), "9.9.9", str(output)],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise AssertionError(f"make-dmg.sh failed ({result.returncode}):\n{result.stderr}")

    return output


class MakeDmgStagingTest(unittest.TestCase):
    """The image's text companions come from the live repo files."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.mkdtemp(prefix="make-dmg-staging.")
        cls.image = build_image(cls.temp)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.temp, ignore_errors=True)

    def read_image_file(self, name):
        return (self.image / name).read_text(encoding="utf-8")

    def test_changes_txt_is_the_live_changelog(self):
        staged = self.read_image_file("Changes.txt")
        self.assertEqual(staged, CHANGELOG.read_text(encoding="utf-8"))

    def test_changes_txt_is_not_the_frozen_1x_history(self):
        # The first version heading of the frozen 1.x history must not appear in
        # the image. Derived rather than hardcoded so the marker follows the
        # file it is taken from.
        frozen = (REPO_ROOT / "ChangeLogs" / "Changes.txt").read_text(encoding="utf-8")
        marker = next(line for line in frozen.splitlines() if line.startswith("Version "))
        self.assertNotIn(marker, self.read_image_file("Changes.txt"))

    def test_license_txt_is_staged(self):
        self.assertEqual(self.read_image_file("License.txt"), LICENSE.read_text(encoding="utf-8"))

    def test_finder_layout_items_are_staged(self):
        # The .DS_Store and the two positioned text items must all be present;
        # a missing one means the staging or layout step regressed, and the
        # Changes.txt assertions above would be inspecting the wrong tree.
        names = {entry.name for entry in self.image.iterdir()}
        self.assertIn(".DS_Store", names)
        self.assertIn("Changes.txt", names)
        self.assertIn("License.txt", names)
        self.assertTrue((self.image / "Applications").is_symlink())


if __name__ == "__main__":
    unittest.main()
