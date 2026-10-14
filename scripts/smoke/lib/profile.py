"""Write a throwaway Adium profile for one smoke test.

The smoke tests never touch the real Adium profile. They give the app an empty
home directory through CFFIXED_USER_HOME and write the account files into it, so
the app behaves like a fresh install with one account.

Usage:
  profile.py --home <dir> --transport jabber --uid smoke-a@localhost
             [--pref "Jabber:Connect Server=127.0.0.1"] [--object-id <id>]

Prints the account object ID on stdout. Diagnostics go to stderr.
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path

# The service ID pairs the account file with the transport the test exercises.
# "type" selects the service when the app loads the account (it matches the
# service's unique ID). "service" is the short name the app shows and uses in
# the keychain key, so the two differ.
TRANSPORT_SERVICES = {
    "jabber": {"type": "libpurple-Jabber", "service": "Jabber"},
    "irc": {"type": "libpurple-IRC", "service": "IRC"},
    "simple": {"type": "libpurple-simple", "service": "SIMPLE"},
    "bonjour": {"type": "libpurple-bonjour", "service": "Bonjour"},
}

# Accounts that name their keychain item after their object ID instead of the
# UID. The IRC service does this, because a nick can change or be taken.
TRANSPORTS_USING_OBJECT_ID = {"irc"}

# The app numbers its accounts and keeps the next free number in the same file,
# so the ID is an integer string and the profile holds only one account.
DEFAULT_OBJECT_ID = "0"


def user_directory(home: Path) -> Path:
    """Return the profile directory the app writes inside the throwaway home."""
    return home / "Library" / "Application Support" / "Adium 2.0" / "Users" / "Default"


def write_accounts(
    directory: Path, service_type: str, service_name: str, uid: str, object_id: str
) -> None:
    """Write the account list the app loads at launch.

    The app selects the service by the unique ID in "Type". "Service" holds the
    short name, which is also the key of the account password in the keychain.
    """
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
    directory: Path, object_id: str, preferences: dict[str, object]
) -> None:
    """Write the per-account preferences, keyed by account object ID."""
    payload = {object_id: preferences}
    with (directory / "AccountPrefs.plist").open("wb") as handle:
        plistlib.dump(payload, handle)


def parse_preference(text: str) -> tuple[str, object]:
    """Split "key=value" into a key and a typed value."""
    if "=" not in text:
        raise argparse.ArgumentTypeError(f"preference needs key=value, got {text!r}")
    key, _, raw = text.partition("=")
    if not key:
        raise argparse.ArgumentTypeError(f"preference needs a key, got {text!r}")
    if raw in ("true", "false"):
        return key, raw == "true"
    return key, raw


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument(
        "--transport", required=True, choices=sorted(TRANSPORT_SERVICES)
    )
    parser.add_argument("--uid", required=True)
    parser.add_argument("--object-id", default=DEFAULT_OBJECT_ID)
    parser.add_argument("--pref", action="append", default=[], type=parse_preference)
    arguments = parser.parse_args(argv)

    directory = user_directory(arguments.home)
    directory.mkdir(parents=True, exist_ok=True)

    preferences: dict[str, object] = {"isOnline": True}
    preferences.update(dict(arguments.pref))

    service = TRANSPORT_SERVICES[arguments.transport]
    write_accounts(
        directory,
        service["type"],
        service["service"],
        arguments.uid,
        arguments.object_id,
    )
    write_account_preferences(directory, arguments.object_id, preferences)

    account_name = (
        f"{service['service']}.{arguments.object_id}"
        if arguments.transport in TRANSPORTS_USING_OBJECT_ID
        else arguments.uid
    )
    print(f"object-id={arguments.object_id}")
    print(f"keychain-service={service['service']}.{account_name}")
    print(f"keychain-account={account_name}")
    print(f"profile.py: wrote {directory}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
