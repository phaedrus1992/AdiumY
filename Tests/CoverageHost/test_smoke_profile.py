#!/usr/bin/env python3
"""Unit tests for scripts/smoke/lib/profile.py.

That script writes the throwaway profile the transport smoke tests give the
app. A wrong value there does not fail loudly: the app loads the account with
defaults and the test fails later for a reason that names nothing. These tests
pin the parts the app depends on:

  - the account file selects the service by "Type" and names the account by an
    integer string, with "TopAccountID" one above it (AdiumAccounts.m reads
    both);
  - the preference file is keyed by that same number, because the app looks the
    preferences up by the account's numeric ID;
  - the keychain names match what AdiumPasswords.m builds, with a protocol of
    `AdIM`;
  - the debug-log option writes the group file that turns on the app's own log,
    and writes it only when the option is given.

Run from the repo root:  python3 -m unittest discover -s Tests/CoverageHost -v
Run just this file:      python3 -m unittest discover -s Tests/CoverageHost -p 'test_smoke_profile*' -v
"""

import importlib.util
import os
import pathlib
import plistlib
import re
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROFILE_PATH = os.path.join(REPO_ROOT, "scripts", "smoke", "lib", "profile.py")

try:
    from hypothesis import given, settings, strategies as st

    HAS_HYPOTHESIS = True
except ImportError:
    HAS_HYPOTHESIS = False


def load_profile():
    """Load scripts/smoke/lib/profile.py, which no package imports."""
    spec = importlib.util.spec_from_file_location("smoke_profile", PROFILE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


profile = load_profile()


def write_profile(directory, object_id):
    """Write every profile file the way the smoke tests do."""
    service = profile.TRANSPORT_SERVICES["jabber"]
    profile.write_accounts(
        directory, service["type"], service["service"], "smoke-a@localhost", object_id
    )
    profile.write_general_preferences(directory)
    profile.write_account_preferences(directory, object_id, {"isOnline": True})


class AccountFileTest(unittest.TestCase):
    """The account file must carry the keys the app reads."""

    def test_account_file_names_the_service_and_the_account(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = _as_path(temp)
            write_profile(directory, profile.DEFAULT_OBJECT_ID)

            payload = plistlib.loads((directory / "Accounts.plist").read_bytes())
            self.assertEqual(len(payload["Accounts"]), 1)
            account = payload["Accounts"][0]
            self.assertEqual(account["Type"], "libpurple-Jabber")
            self.assertEqual(account["Service"], "Jabber")
            self.assertEqual(account["UID"], "smoke-a@localhost")
            self.assertIsInstance(account["ObjectID"], str)
            self.assertEqual(payload["TopAccountID"], "1")

    def test_preference_file_is_keyed_by_the_account_id(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = _as_path(temp)
            write_profile(directory, profile.DEFAULT_OBJECT_ID)

            accounts = plistlib.loads((directory / "Accounts.plist").read_bytes())
            preferences = plistlib.loads((directory / "AccountPrefs.plist").read_bytes())
            self.assertEqual(
                list(preferences), [accounts["Accounts"][0]["ObjectID"]]
            )
            self.assertTrue(preferences[profile.DEFAULT_OBJECT_ID]["isOnline"])

    def test_default_object_id_is_an_integer_string(self):
        # A UUID in this field loads, but the app then keys the preferences by
        # the number the UUID converts to, and the profile stops matching.
        self.assertEqual(profile.DEFAULT_OBJECT_ID, str(int(profile.DEFAULT_OBJECT_ID)))

    def test_general_file_stops_the_first_run_preference_migration(self):
        # A fresh profile makes the app move the old per-account preference
        # files into AccountPrefs.plist. The source directory is empty here, so
        # the move writes an empty file and the run loses its own preferences.
        with tempfile.TemporaryDirectory() as temp:
            directory = _as_path(temp)
            profile.write_general_preferences(directory)

            general = plistlib.loads((directory / "General.plist").read_bytes())
            self.assertTrue(general["Loaded individual object & account prefs"])


class PreferenceTest(unittest.TestCase):
    """The "key=value" parser feeds values straight into the plist."""

    def test_boolean_words_become_booleans(self):
        self.assertEqual(profile.parse_preference("isOnline=true"), ("isOnline", True))
        self.assertEqual(
            profile.parse_preference("isOnline=false"), ("isOnline", False)
        )

    def test_digits_become_an_integer(self):
        # The app reads "Connect Port" as a number, and writes its own port
        # back as one. A string here still parses, but it is not what the app
        # stores, so the test would not match a real profile.
        self.assertEqual(profile.parse_preference("Connect Port=5222"), ("Connect Port", 5222))

    def test_non_ascii_digits_stay_text(self):
        # str.isdigit() accepts superscripts and other scripts' numerals, but a
        # preference value must be ASCII digits to become an integer.
        self.assertEqual(profile.parse_preference("k=²"), ("k", "²"))
        self.assertEqual(profile.parse_preference("k=١٢٣"), ("k", "١٢٣"))

    def test_every_other_value_stays_text(self):
        self.assertEqual(
            profile.parse_preference("Connect Host=127.0.0.1"),
            ("Connect Host", "127.0.0.1"),
        )
        self.assertEqual(profile.parse_preference("IRC:Use SSL=True"), ("IRC:Use SSL", "True"))
        self.assertEqual(profile.parse_preference("k="), ("k", ""))
        self.assertEqual(profile.parse_preference("k=a=b"), ("k", "a=b"))
        self.assertEqual(profile.parse_preference("k= v "), ("k", " v "))
        self.assertEqual(profile.parse_preference("k=-1"), ("k", "-1"))
        self.assertEqual(profile.parse_preference("k=1.5"), ("k", "1.5"))

    def test_missing_separator_or_key_is_an_error(self):
        with self.assertRaises(Exception):
            profile.parse_preference("no-separator")
        with self.assertRaises(Exception):
            profile.parse_preference("=value")


class KeychainNameTest(unittest.TestCase):
    """The names must match what AdiumPasswords.m looks up."""

    def test_jabber_names_the_item_after_the_address(self):
        self.assertEqual(
            profile.keychain_names("jabber", "smoke-a@localhost"),
            ("Jabber.smoke-a@localhost", "smoke-a@localhost"),
        )

    def test_irc_names_the_item_after_the_nickname(self):
        self.assertEqual(
            profile.keychain_names("irc", "smoke-a"), ("IRC.smoke-a", "smoke-a")
        )

    def test_every_transport_is_covered(self):
        for transport, service in profile.TRANSPORT_SERVICES.items():
            keychain_service, account = profile.keychain_names(transport, "smoke-a")
            self.assertEqual(keychain_service, f"{service['service']}.smoke-a")
            self.assertEqual(account, "smoke-a")


class DebugLogTest(unittest.TestCase):
    """The --debug-log option controls the group file the app reads.

    That file turns on the app's own debug log, which is the inside view of the
    app while a run goes wrong.
    """

    def test_debug_log_option_writes_the_group_file(self):
        with tempfile.TemporaryDirectory() as temp:
            home = _as_path(temp)
            profile.main(
                [
                    "--home",
                    temp,
                    "--transport",
                    "jabber",
                    "--uid",
                    "smoke-a@localhost",
                    "--debug-log",
                ]
            )

            directory = profile.user_directory(home)
            payload = plistlib.loads((directory / "Debug Group.plist").read_bytes())
            self.assertEqual(payload, {"Write Debug Log": True})

    def test_a_run_without_the_option_leaves_no_group_file(self):
        with tempfile.TemporaryDirectory() as temp:
            home = _as_path(temp)
            profile.main(
                ["--home", temp, "--transport", "jabber", "--uid", "smoke-a@localhost"]
            )

            directory = profile.user_directory(home)
            self.assertFalse((directory / "Debug Group.plist").exists())


def _as_path(text):
    """Return a Path for a directory name from tempfile."""
    return pathlib.Path(text)


if HAS_HYPOTHESIS:
    # The @given decorators are evaluated at class-body time, so this section
    # must be hidden when hypothesis is absent (CI installs a pinned one).

    class AccountNumberProperty(unittest.TestCase):
        """Any account number round-trips, and the next number follows it."""

        @given(number=st.integers(min_value=0, max_value=10**6))
        @settings(max_examples=100, deadline=None)
        def test_number_round_trips_into_both_files(self, number):
            with tempfile.TemporaryDirectory() as temp:
                directory = _as_path(temp)
                write_profile(directory, str(number))

                payload = plistlib.loads((directory / "Accounts.plist").read_bytes())
                preferences = plistlib.loads(
                    (directory / "AccountPrefs.plist").read_bytes()
                )
                self.assertEqual(payload["Accounts"][0]["ObjectID"], str(number))
                self.assertEqual(payload["TopAccountID"], str(number + 1))
                self.assertEqual(list(preferences), [str(number)])

    class PreferenceValueProperty(unittest.TestCase):
        """Only an exact boolean word or an ASCII digit run changes a value's type."""

        @given(value=st.text())
        @settings(max_examples=200, deadline=None)
        def test_value_types_follow_the_documented_rule(self, value):
            key, parsed = profile.parse_preference("k=" + value)
            self.assertEqual(key, "k")
            if value in ("true", "false"):
                self.assertIsInstance(parsed, bool)
            elif re.fullmatch("[0-9]+", value):
                self.assertIsInstance(parsed, int)
            else:
                self.assertEqual(parsed, value)


if __name__ == "__main__":
    unittest.main()
