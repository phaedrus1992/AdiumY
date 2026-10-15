"""Store and remove the throwaway account password the smoke tests use.

The app reads an account password through the Keychain Services API in
AIKeychain.m. That API matches an item by server, account, and protocol, where
the protocol for every Adium account is the four-character code "AdIM".

The ``security`` command writes a legacy item, and the app cannot find it: the
protocol attribute of that item does not match a modern query. The app then
asks the user for the password, and the account never connects. This script
writes the item through the same API the app reads it with, so the run needs no
prompt.

The item takes an access list that answers no question to any application,
which the ``security -A`` command also makes. Naming the app in the list cannot
work: the app is a local build whose code changes on every rebuild, so macOS
cannot match it and asks the user to confirm the first read of every new item.
The password here is a throwaway for a test account on localhost, and the item
is removed when the run ends. Only items that this script writes are removed:
an item from the older ``security`` recipe does not match this query and stays
in the login keychain.

The login keychain must be unlocked: while the screen is asleep macOS refuses
the read with errSecInDarkWake, and the account never connects.

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

# The prompt selector that asks no question. See SecACLSetContents.
NO_PROMPT = 0


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
        self.core_foundation.CFArrayCreate.restype = ctypes.c_void_p
        self.core_foundation.CFArrayCreate.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_void_p),
            ctypes.c_long,
            ctypes.c_void_p,
        ]
        self.core_foundation.CFArrayGetCount.restype = ctypes.c_long
        self.core_foundation.CFArrayGetCount.argtypes = [ctypes.c_void_p]
        self.core_foundation.CFArrayGetValueAtIndex.restype = ctypes.c_void_p
        self.core_foundation.CFArrayGetValueAtIndex.argtypes = [
            ctypes.c_void_p,
            ctypes.c_long,
        ]
        self.core_foundation.CFRelease.argtypes = [ctypes.c_void_p]

        self.security.SecItemAdd.restype = ctypes.c_int32
        self.security.SecItemAdd.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
        self.security.SecItemDelete.restype = ctypes.c_int32
        self.security.SecItemDelete.argtypes = [ctypes.c_void_p]
        self.security.SecAccessCreate.restype = ctypes.c_int32
        self.security.SecAccessCreate.argtypes = [
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_void_p),
        ]
        self.security.SecAccessCopyACLList.restype = ctypes.c_int32
        self.security.SecAccessCopyACLList.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_void_p),
        ]
        self.security.SecACLSetContents.restype = ctypes.c_int32
        self.security.SecACLSetContents.argtypes = [
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_uint32,
        ]

    def constant(self, name: str) -> int:
        """Return the address of an exported Keychain Services constant."""
        return ctypes.c_void_p.in_dll(self.security, name).value

    def core_foundation_constant(self, name: str) -> int:
        """Return the address of an exported Core Foundation constant."""
        return ctypes.c_void_p.in_dll(self.core_foundation, name).value

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

    def access_for_any_application(self) -> int:
        """Create an access list that answers no question to any application.

        SecAccessCreate makes the entries; every one of them then takes an
        empty application list, which means every application, and the prompt
        selector that asks nothing. The app reads the item without a question,
        and this script can replace it on the next run.
        """
        empty = self.core_foundation.CFArrayCreate(None, None, 0, None)
        if not empty:
            raise KeychainError("cannot create the empty application list")
        access = ctypes.c_void_p()
        try:
            status = self.security.SecAccessCreate(
                self.string("smoke test item"), empty, ctypes.byref(access)
            )
        finally:
            self.release(empty)
        if status != ERR_SEC_SUCCESS or not access.value:
            raise KeychainError(f"SecAccessCreate failed with status {status}")

        acl_list = ctypes.c_void_p()
        status = self.security.SecAccessCopyACLList(access, ctypes.byref(acl_list))
        if status != ERR_SEC_SUCCESS or not acl_list.value:
            self.release(access)
            raise KeychainError(f"SecAccessCopyACLList failed with status {status}")
        try:
            count = self.core_foundation.CFArrayGetCount(acl_list)
            for index in range(count):
                acl = self.core_foundation.CFArrayGetValueAtIndex(acl_list, index)
                status = self.security.SecACLSetContents(
                    acl, None, self.string("smoke test item"), NO_PROMPT
                )
                if status != ERR_SEC_SUCCESS:
                    self.release(access)
                    raise KeychainError(
                        f"SecACLSetContents failed with status {status}"
                    )
        finally:
            self.release(acl_list)
        return access.value

    def dictionary(self, pairs: list) -> int:
        """Create a Core Foundation dictionary from (key, value) address pairs."""
        count = len(pairs)
        keys = (ctypes.c_void_p * count)(*[key for key, _ in pairs])
        values = (ctypes.c_void_p * count)(*[value for _, value in pairs])
        # The dictionary lives for one call: no key or value callbacks. A
        # callback structure passed by address from ctypes would be a copy of
        # a pointer, not the structure, and the dictionary would be malformed.
        handle = self.core_foundation.CFDictionaryCreate(None, keys, values, count, None, None)
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
    # so only a fresh item carries the new one.
    status = frameworks.security.SecItemDelete(query)
    if status not in (ERR_SEC_SUCCESS, ERR_SEC_ITEM_NOT_FOUND):
        frameworks.release(query)
        raise KeychainError(
            f"cannot remove items for {server}, if any (status {status}). Unlock "
            f"the login keychain and run the step again, or delete the item in "
            f"Keychain Access (search for {server!r})."
        )

    # The access list answers no question to any application; the module
    # docstring gives the reason. The item never syncs, and it is readable
    # only on this device while the keychain is unlocked.
    access = frameworks.access_for_any_application()
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
                frameworks.constant("kSecAttrAccessible"),
                frameworks.constant("kSecAttrAccessibleWhenUnlockedThisDeviceOnly"),
            ),
            (
                frameworks.constant("kSecAttrSynchronizable"),
                frameworks.core_foundation_constant("kCFBooleanFalse"),
            ),
            (
                frameworks.constant("kSecValueData"),
                frameworks.data(password.encode("utf-8")),
            ),
            (frameworks.constant("kSecAttrAccess"), access),
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
        frameworks.release(access)


def remove_item(server: str, account: str) -> None:
    """Remove the password for one account. A missing item is not an error."""
    frameworks = _Frameworks()
    query = _query(frameworks, server, account)
    try:
        status = frameworks.security.SecItemDelete(query)
        if status not in (ERR_SEC_SUCCESS, ERR_SEC_ITEM_NOT_FOUND):
            raise KeychainError(
                f"SecItemDelete for {server} failed with status {status}. Unlock "
                f"the login keychain and run the step again, or delete the item "
                f"in Keychain Access (search for {server!r})."
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
