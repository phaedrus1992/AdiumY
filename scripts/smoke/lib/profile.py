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


def user_directory(home: Path) -> Path:
    """Return the profile directory the app writes inside the throwaway home."""
    return home / "Library" / "Application Support" / "Adium 2.0" / "Users" / "Default"


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


def write_account_preferences(
    directory: Path, object_id: str, preferences: dict
) -> None:
    """Write the per-account preferences, keyed by the account object ID."""
    payload = {object_id: preferences}
    with (directory / "AccountPrefs.plist").open("wb") as handle:
        plistlib.dump(payload, handle)


def parse_preference(text: str) -> tuple:
    """Split "key=value" into a key and a value.

    Only the exact words "true" and "false" become booleans. Every other value
    stays text, which is what an account preference expects.
    """
    if "=" not in text:
        raise argparse.ArgumentTypeError(f"preference needs key=value, got {text!r}")
    key, _, raw = text.partition("=")
    if not key:
        raise argparse.ArgumentTypeError(f"preference needs a key, got {text!r}")
    if raw in ("true", "false"):
        return key, raw == "true"
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
    write_account_preferences(directory, DEFAULT_OBJECT_ID, preferences)

    keychain_service, keychain_account = keychain_names(
        arguments.transport, arguments.uid
    )
    print(f"keychain-service={keychain_service}")
    print(f"keychain-account={keychain_account}")
    print(f"profile.py: wrote {directory}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
