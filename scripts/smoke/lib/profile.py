"""Write a throwaway Adium profile for one smoke test.

The smoke tests never touch the real Adium profile. They give the app an empty
home directory through CFFIXED_USER_HOME and write the account files into it, so
the app behaves like a fresh install with one account.

Usage:
  profile.py --home <dir> --transport jabber --uid smoke-a@localhost
             [--pref "Jabber:Connect Server=127.0.0.1"]

Prints the keychain service and account names for the account password on
stdout, one per line, as `keychain-service=<value>` and
`keychain-account=<value>`. Diagnostics go to stderr.

The app builds those two names in AdiumPasswords.m: the service is
`<serviceID>.<account name>`, and the protocol is `AdIM`. The account name is
the UID, so the UID must already be lowercase and free of spaces: the app
compacts the UID before the lookup, and this script does not.
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path

# The service the app loads the account under: "type" selects the service by
# its unique ID, and "service" is the short name the app shows and uses as the
# first part of the keychain key.
TRANSPORT_SERVICES = {
    "jabber": {"type": "libpurple-Jabber", "service": "Jabber"},
    "irc": {"type": "libpurple-IRC", "service": "IRC"},
}

# The app numbers its accounts and keeps the next free number in the same file,
# so the ID is an integer string and the profile holds only one account.
DEFAULT_OBJECT_ID = "0"

# Flag the app sets after it moves the old one-file-per-account preferences into
# AccountPrefs.plist. On a fresh profile that move runs with an empty source
# directory and overwrites the account preferences with an empty dictionary, so
# this file claims the move already happened. The key is
# LOADED_OBJECT_PREFS_KEY in AIPreferenceController.m, in the "General" group.
GENERAL_PREFERENCES = {"Loaded individual object & account prefs": True}

# A profile name the login window selects at launch. Without this file the app
# opens its login window and waits for a user to pick a profile, so the account
# never comes online on its own. The key is LOGIN_LAST_USER in AILoginController.m.
LOGIN_PREFERENCES = {"Last Login Name": "Default"}

# The profile the app opens: the only directory under Users/.
USER_NAME = "Default"

# The group file that makes the app write its debug log, which is the inside
# view of the app while a smoke test runs. The keys are KEY_DEBUG_WRITE_LOG and
# GROUP_DEBUG in ESDebugController.h, and the log lands in
# <home>/Library/Logs/AdiumY Debug/<date>.log.
DEBUG_PREFERENCES = {"Write Debug Log": True}


def user_directory(home: Path) -> Path:
    """Return the profile directory the app writes inside the throwaway home."""
    return (
        home
        / "Library"
        / "Application Support"
        / "Adium 2.0"
        / "Users"
        / USER_NAME
    )


def write_login_preferences(home: Path) -> None:
    """Write the login file, which names the profile the app opens."""
    path = home / "Library" / "Application Support" / "Adium 2.0"
    with (path / "Login Preferences.plist").open("wb") as handle:
        plistlib.dump(LOGIN_PREFERENCES, handle)


def write_accounts(
    directory: Path, service_type: str, service_name: str, uid: str, object_id: str
) -> None:
    """Write the account list the app loads at launch."""
    payload = {
        "Accounts": [
            {
                "ObjectID": object_id,
                "Service": service_name,
                "Type": service_type,
                "UID": uid,
            }
        ],
        "TopAccountID": str(int(object_id) + 1),
    }
    with (directory / "Accounts.plist").open("wb") as handle:
        plistlib.dump(payload, handle)


def write_general_preferences(directory: Path) -> None:
    """Write the general preferences the app reads at launch."""
    with (directory / "General.plist").open("wb") as handle:
        plistlib.dump(GENERAL_PREFERENCES, handle)


def write_debug_preferences(directory: Path) -> None:
    """Write the group file that makes the app write its debug log."""
    with (directory / "Debug Group.plist").open("wb") as handle:
        plistlib.dump(DEBUG_PREFERENCES, handle)


def write_account_preferences(
    directory: Path, object_id: str, preferences: dict
) -> None:
    """Write the per-account preferences, keyed by the account object ID."""
    payload = {object_id: preferences}
    with (directory / "AccountPrefs.plist").open("wb") as handle:
        plistlib.dump(payload, handle)


def parse_preference(text: str) -> tuple:
    """Split "key=value" into a key and a value.

    The value type follows the app's own account files: the exact words "true"
    and "false" become booleans, digits become an integer, and every other
    value stays text.
    """
    if "=" not in text:
        raise argparse.ArgumentTypeError(f"preference needs key=value, got {text!r}")
    key, _, raw = text.partition("=")
    if not key:
        raise argparse.ArgumentTypeError(f"preference needs a key, got {text!r}")
    if raw in ("true", "false"):
        return key, raw == "true"
    if raw.isdigit():
        return key, int(raw)
    return key, raw


def keychain_names(transport: str, uid: str) -> tuple:
    """Return the (service, account) names the app reads the password under."""
    service = TRANSPORT_SERVICES[transport]["service"]
    return f"{service}.{uid}", uid


def main(argv: list) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument(
        "--transport", required=True, choices=sorted(TRANSPORT_SERVICES)
    )
    parser.add_argument("--uid", required=True)
    parser.add_argument("--pref", action="append", default=[], type=parse_preference)
    parser.add_argument(
        "--debug-log",
        action="store_true",
        help="make the app write its debug log into the throwaway home",
    )
    arguments = parser.parse_args(argv)

    directory = user_directory(arguments.home)
    directory.mkdir(parents=True, exist_ok=True)

    preferences = {"isOnline": True}
    preferences.update(dict(arguments.pref))

    service = TRANSPORT_SERVICES[arguments.transport]
    write_accounts(
        directory,
        service["type"],
        service["service"],
        arguments.uid,
        DEFAULT_OBJECT_ID,
    )
    write_general_preferences(directory)
    write_login_preferences(arguments.home)
    write_account_preferences(directory, DEFAULT_OBJECT_ID, preferences)
    if arguments.debug_log:
        write_debug_preferences(directory)

    keychain_service, keychain_account = keychain_names(
        arguments.transport, arguments.uid
    )
    print(f"keychain-service={keychain_service}")
    print(f"keychain-account={keychain_account}")
    print(f"profile.py: wrote {directory}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
