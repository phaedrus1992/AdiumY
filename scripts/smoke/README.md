# Transport smoke tests

Each script in this directory proves one transport end to end, with no public
server, no real account, and no credentials of your own.
The test starts a local server, gives the app a throwaway profile, and checks a
message in both directions against a scripted peer.

The work belongs to the plan in [issue #133](https://github.com/phaedrus1992/AdiumY/issues/133).

## What a test proves

1. The app accepts the account and connects to the server.
   The proof is the session in the server's own log; the account's status is
   not enough, because it reads "available" before the connection is made.
2. A message from another client arrives in the app, and the app writes it to
   its chat log.
3. A message sent from the app reaches the other client.

A run that only avoids a crash is a failure.
Every assertion fails loudly with the observed state and the fix, and the
failure carries the last server log lines, the chat log directory, or the peer
log, whichever the step was waiting on.

## Requirements

- macOS, with Docker running and `uv` installed.
- The app, built: `make adium` (the tests read `build/Release-Debug/AdiumY.app`).
- **The Automation permission for AdiumY.** The test drives the app through its
  AppleScript interface, which macOS gates behind a per-application permission.
  Grant it once:

  1. Open System Settings > Privacy & Security > Automation.
  2. Find the terminal that runs the test (for example Ghostty or Terminal).
  3. Turn on the switch for AdiumY.

  If no AdiumY row appears under the terminal, run this command once, then look
  again:

  ```bash
  osascript -e 'tell application "AdiumY" to get version'
  ```

  macOS refuses an Apple event with error `-1743` when the permission is off.
  Each test checks the permission first and prints these steps if it is missing.

The Docker server runs as a container named `adiumy-smoke-<transport>` and is
removed on exit. Its image is pinned by digest, so a run always tests the same
server.

The run refuses to start while another AdiumY is running.
Apple events reach the app by name, not by process, so a test started next to
your own session would drive that session instead of the throwaway one.
Quit AdiumY first.

The test never reads or writes the real Adium profile, and it removes its own
keychain item on exit. A leftover is printed as a warning with the command that
removes it.

## Run

```bash
scripts/smoke/jabber.sh      # Jabber/XMPP over a local Prosody server
scripts/smoke/irc.sh         # IRC over a local Ergo server
```

SIMPLE/SIP is not here yet.
A SIP server in a container on macOS cannot deliver a request back to a client
on the host, and Docker publishes only the mapped port.
See [issue #136](https://github.com/phaedrus1992/AdiumY/issues/136).

Set `SMOKE_KEEP=1` to keep the work directory (`.tmp/smoke-<transport>.*`) for
inspection after a failure.
It holds the server log, the app's standard output, the peer log, and the
throwaway profile with its chat logs.

## Files

| Path | Purpose |
|------|---------|
| `lib/smoke.sh` | Shared steps: profile write, keychain, app launch, AppleScript, assertions, teardown. |
| `lib/profile.py` | Writes `Accounts.plist` and `AccountPrefs.plist` for the throwaway home. |
| `peers/xmpp_peer.py` | Scripted XMPP peer: sends one message, then waits for the reply. |
| `peers/irc_peer.py` | Scripted IRC peer: connects with a nickname, sends one message, waits for the reply. |
| `jabber.sh` | Jabber/XMPP test: Prosody in Docker. |
| `irc.sh` | IRC test: Ergo in Docker. |

## Notes for the next transport

- Docker can mount a file only from the home directory tree, because Docker
  Desktop and colima share the home directory with their virtual machine.
  The work directory therefore stays under the repository's `.tmp/`.
- Account IDs in `Accounts.plist` are integer strings (`"0"`), and the
  `AccountPrefs.plist` key is the same string.
  An account with a UUID in place of a number does load, but its preferences
  are then written under the wrong key.
- The app starts with every account offline.
  Only an explicit "go online" connects it; no preference makes it connect at
  launch.
- The account password lives in an internet-password keychain item.
  `lib/profile.py` prints the exact service and account names for the item.
  The service name comes from the service's `serviceID` (`Jabber`, `IRC`), not
  from the unique ID in `Accounts.plist`.
