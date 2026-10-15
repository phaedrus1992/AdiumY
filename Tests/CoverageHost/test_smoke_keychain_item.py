#!/usr/bin/env python3
"""Unit tests for scripts/smoke/lib/keychain_item.py.

The app reads an account password through a query of four attributes: the
internet-password class, the server, the account, and the "AdIM" protocol. The
script builds that query through ctypes, where a wrong constant or a missing
argument surfaces inside the app as a password prompt, not as an error here.
These tests read the built dictionary back and pin the four attributes.

Run from the repo root:  python3 -m unittest discover -s Tests/CoverageHost -v
"""

import ctypes
import importlib.util
import os
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KEYCHAIN_PATH = os.path.join(REPO_ROOT, "scripts", "smoke", "lib", "keychain_item.py")

try:
    from hypothesis import given, settings, strategies as st

    HAS_HYPOTHESIS = True
except ImportError:
    HAS_HYPOTHESIS = False


def load_keychain_item():
    """Load scripts/smoke/lib/keychain_item.py, which no package imports."""
    spec = importlib.util.spec_from_file_location("smoke_keychain_item", KEYCHAIN_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


keychain_item = load_keychain_item()


def build_query(server, account):
    """Return the frameworks and the built query dictionary for a pair of names."""
    frameworks = keychain_item._Frameworks()
    query = keychain_item._query(frameworks, server, account)
    cf = frameworks.core_foundation
    cf.CFDictionaryGetValue.restype = ctypes.c_void_p
    cf.CFDictionaryGetValue.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    cf.CFEqual.restype = ctypes.c_ubyte
    cf.CFEqual.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    return frameworks, query


def attribute(frameworks, query, key):
    """Return the value stored under one attribute key."""
    return frameworks.core_foundation.CFDictionaryGetValue(
        query, frameworks.constant(key)
    )


class QueryShapeTest(unittest.TestCase):
    """The query must carry the four attributes the app matches on."""

    def test_query_carries_the_four_attributes(self):
        frameworks, query = build_query("Jabber.smoke-a@localhost", "smoke-a@localhost")
        equal = frameworks.core_foundation.CFEqual

        self.assertTrue(
            equal(attribute(frameworks, query, "kSecClass"),
                  frameworks.constant("kSecClassInternetPassword"))
        )
        self.assertTrue(
            equal(attribute(frameworks, query, "kSecAttrServer"),
                  frameworks.string("Jabber.smoke-a@localhost"))
        )
        self.assertTrue(
            equal(attribute(frameworks, query, "kSecAttrAccount"),
                  frameworks.string("smoke-a@localhost"))
        )
        self.assertTrue(
            equal(attribute(frameworks, query, "kSecAttrProtocol"),
                  frameworks.string(keychain_item.PROTOCOL))
        )


if HAS_HYPOTHESIS:
    # The @given decorators are evaluated at class-body time, so this section
    # must be hidden when hypothesis is absent (CI installs a pinned one).

    class QueryRoundTripProperty(unittest.TestCase):
        """Any server and account text round-trips into the query."""

        @given(
            server=st.text(alphabet=st.characters(blacklist_characters="\x00"), min_size=1),
            account=st.text(alphabet=st.characters(blacklist_characters="\x00"), min_size=1),
        )
        @settings(max_examples=50, deadline=None)
        def test_server_and_account_round_trip(self, server, account):
            frameworks, query = build_query(server, account)
            equal = frameworks.core_foundation.CFEqual

            self.assertTrue(
                equal(attribute(frameworks, query, "kSecAttrServer"), frameworks.string(server))
            )
            self.assertTrue(
                equal(attribute(frameworks, query, "kSecAttrAccount"), frameworks.string(account))
            )
            self.assertTrue(
                equal(attribute(frameworks, query, "kSecClass"),
                      frameworks.constant("kSecClassInternetPassword"))
            )


if __name__ == "__main__":
    unittest.main()
