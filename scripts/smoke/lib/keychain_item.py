"""Store and remove the throwaway account password the smoke tests use.

The app reads an account password through the Keychain Services API in
AIKeychain.m. That API matches an item by server, account, and protocol, where
the protocol for every Adium account is the four-character code "AdIM".

The ``security`` command writes a legacy item, and the app cannot find it: the
protocol attribute of that item does not match a modern query. The app then
asks the user for the password, and the account never connects. This script
writes the item through the same API the app reads it with, so the run needs no
prompt.

The item is stored with no access object, so it takes the default access, which
names no application. A constructed access list cannot serve here. The entries
that SecAccessCreate makes with no application force the app to ask the user to
confirm each read, and an entry that names the app does not help, because a
locally built app carries no stable code requirement. An unanswered dialog
blocks the app until the run times out. The password here is a throwaway for a
test account on localhost, and the item is removed when the run ends.

Usage:
  keychain_item.py add --server <name> --account <name> --password <text>
  keychain_item.py remove --server <name> --account <name>

Exit 0 when the item is stored or removed. A missing item on removal is not an
error. Diagnostics go to stderr.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import sys

# The protocol attribute of every account password. AdiumPasswords.m passes
# FOUR_CHAR_CODE('AdIM'), and AIKeychain.m writes it as this four-character
# string.
PROTOCOL = "AdIM"

# Keychain Services status codes used here.
ERR_SEC_SUCCESS = 0
ERR_SEC_ITEM_NOT_FOUND = -25300

# The Core Foundation string encoding for UTF-8.
K_CF_STRING_ENCODING_UTF8 = 0x08000100


class KeychainError(Exception):
    """Raised when a Keychain Services call fails."""


class _Frameworks:
    """The Core Foundation and Security entry points this script calls."""

    def __init__(self) -> None:
        self.core_foundation = ctypes.cdll.LoadLibrary(
            ctypes.util.find_library("CoreFoundation")
        )
        self.security = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Security"))

        self.core_foundation.CFStringCreateWithCString.restype = ctypes.c_void_p
        self.core_foundation.CFStringCreateWithCString.argtypes = [
            ctypes.c_void_p,
            ctypes.c_char_p,
            ctypes.c_uint32,
        ]
        self.core_foundation.CFDataCreate.restype = ctypes.c_void_p
        self.core_foundation.CFDataCreate.argtypes = [
            ctypes.c_void_p,
            ctypes.c_char_p,
            ctypes.c_long,
        ]
        self.core_foundation.CFDictionaryCreate.restype = ctypes.c_void_p
        self.core_foundation.CFDictionaryCreate.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_void_p),
            ctypes.POINTER(ctypes.c_void_p),
            ctypes.c_long,
            ctypes.c_void_p,
            ctypes.c_void_p,
        ]
        self.core_foundation.CFRelease.argtypes = [ctypes.c_void_p]

        self.security.SecItemAdd.restype = ctypes.c_int32
        self.security.SecItemAdd.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
        self.security.SecItemDelete.restype = ctypes.c_int32
        self.security.SecItemDelete.argtypes = [ctypes.c_void_p]

        # The dictionaries are built for one call and released by this script,
        # so they need no key or value callbacks. A callback structure passed
        # by address from ctypes would be a copy of a pointer, not the
        # structure, and the dictionary would be malformed.
        self._type_key_callbacks = None
        self._type_value_callbacks = None

    def constant(self, name: str) -> int:
        """Return the address of an exported Keychain Services constant."""
        return ctypes.c_void_p.in_dll(self.security, name).value

    def string(self, text: str) -> int:
        """Create a Core Foundation string."""
        value = self.core_foundation.CFStringCreateWithCString(
            None, text.encode("utf-8"), K_CF_STRING_ENCODING_UTF8
        )
        if not value:
            raise KeychainError(f"cannot create the string {text!r}")
        return value

    def data(self, payload: bytes) -> int:
        """Create a Core Foundation data object."""
        value = self.core_foundation.CFDataCreate(None, payload, len(payload))
        if not value:
            raise KeychainError("cannot create the password data")
        return value

    def dictionary(self, pairs: list) -> int:
        """Create a Core Foundation dictionary from (key, value) address pairs."""
        count = len(pairs)
        keys = (ctypes.c_void_p * count)(*[key for key, _ in pairs])
        values = (ctypes.c_void_p * count)(*[value for _, value in pairs])
        handle = self.core_foundation.CFDictionaryCreate(
            None,
            keys,
            values,
            count,
            self._type_key_callbacks,
            self._type_value_callbacks,
        )
        if not handle:
            raise KeychainError("cannot create the query dictionary")
        return handle

    def release(self, handle: int) -> None:
        """Release a Core Foundation object."""
        if handle:
            self.core_foundation.CFRelease(handle)


def _query(frameworks: _Frameworks, server: str, account: str) -> int:
    """Return the dictionary that names one account password item."""
    return frameworks.dictionary(
        [
            (frameworks.constant("kSecClass"), frameworks.constant("kSecClassInternetPassword")),
            (frameworks.constant("kSecAttrServer"), frameworks.string(server)),
            (frameworks.constant("kSecAttrAccount"), frameworks.string(account)),
            (frameworks.constant("kSecAttrProtocol"), frameworks.string(PROTOCOL)),
        ]
    )


def add_item(server: str, account: str, password: str) -> None:
    """Store the password for one account, replacing any existing item."""
    frameworks = _Frameworks()
    query = _query(frameworks, server, account)
    # The old item goes first: SecItemUpdate does not change the access list,
    # so only a fresh item carries the default access.
    status = frameworks.security.SecItemDelete(query)
    if status not in (ERR_SEC_SUCCESS, ERR_SEC_ITEM_NOT_FOUND):
        frameworks.release(query)
        raise KeychainError(
            f"an item for {server} exists and this script cannot remove it "
            f"(status {status}). Remove it with: security delete-internet-password "
            f"-s {server!r} -a {account!r}"
        )

    # No access object goes into the attributes. The default access names no
    # application, so the app reads the password without a question; the module
    # docstring gives the reason.
    attributes = frameworks.dictionary(
        [
            (
                frameworks.constant("kSecClass"),
                frameworks.constant("kSecClassInternetPassword"),
            ),
            (frameworks.constant("kSecAttrServer"), frameworks.string(server)),
            (frameworks.constant("kSecAttrAccount"), frameworks.string(account)),
            (frameworks.constant("kSecAttrProtocol"), frameworks.string(PROTOCOL)),
            (
                frameworks.constant("kSecValueData"),
                frameworks.data(password.encode("utf-8")),
            ),
        ]
    )
    try:
        status = frameworks.security.SecItemAdd(attributes, None)
        if status != ERR_SEC_SUCCESS:
            raise KeychainError(
                f"SecItemAdd for {server} failed with status {status}. "
                "Unlock the login keychain and run the step again."
            )
    finally:
        frameworks.release(query)
        frameworks.release(attributes)


def remove_item(server: str, account: str) -> None:
    """Remove the password for one account. A missing item is not an error."""
    frameworks = _Frameworks()
    query = _query(frameworks, server, account)
    try:
        status = frameworks.security.SecItemDelete(query)
        if status not in (ERR_SEC_SUCCESS, ERR_SEC_ITEM_NOT_FOUND):
            raise KeychainError(
                f"SecItemDelete for {server} failed with status {status}. "
                f"Remove the item with: keychain_item.py remove "
                f"--server {server!r} --account {account!r}"
            )
    finally:
        frameworks.release(query)


def main(argv: list) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("add", "remove"):
        subparser = commands.add_parser(name)
        subparser.add_argument("--server", required=True)
        subparser.add_argument("--account", required=True)
        if name == "add":
            subparser.add_argument("--password", required=True)
    arguments = parser.parse_args(argv)

    try:
        if arguments.command == "add":
            add_item(arguments.server, arguments.account, arguments.password)
        else:
            remove_item(arguments.server, arguments.account)
    except KeychainError as error:
        print(f"keychain_item.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
