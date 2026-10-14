"""Scripted IRC peer for the IRC smoke test.

The peer connects to a local server with a valid nickname, and then runs one
step of the test:

- with ``--send`` and ``--expect``, it sends a message and waits for a reply
  that carries the expected token (both directions in one run);
- with ``--join`` and ``--require-nick``, it joins a channel and waits until
  the client under test is in it.

The message text carries a token, so a stale message from an earlier run
cannot pass a check. The peer speaks the IRC protocol over a plain socket, so
the test needs no IRC library.

Usage:
  irc_peer.py --server 127.0.0.1 --port <port> --nick smoke-b
              [--send <text> --send-to <target> --expect <text>]
              [--join <channel>] [--require-nick <nick>] [--timeout 30]

Exit 0 when the step succeeds. Print the received line on stdout.
Every diagnostic goes to stderr.
"""

from __future__ import annotations

import argparse
import select
import socket
import sys
import time


class IrcPeer:
    """A small IRC client: connect, run one exchange, report the result."""

    def __init__(self, arguments: argparse.Namespace) -> None:
        self.arguments = arguments
        self.socket = socket.create_connection(
            (arguments.server, arguments.port), timeout=arguments.timeout
        )
        # The socket stays blocking, and every wait goes through select().
        # A timeout that fires inside a buffered read leaves the stream in an
        # error state, after which every read raises "cannot read from timed
        # out object" and the peer cannot recover.
        #
        # The lines are buffered here rather than by a file object: a buffered
        # reader keeps data that select() cannot see, so a wait on the socket
        # would miss the lines already read into the buffer.
        self.socket.settimeout(None)
        self.buffer = b""

    def send(self, line: str) -> None:
        self.socket.sendall(f"{line}\r\n".encode())

    def read_line(self) -> str | None:
        """Read one IRC line. Return None at end of stream."""
        while b"\n" not in self.buffer:
            chunk = self.socket.recv(65535)
            if not chunk:
                return None
            self.buffer += chunk
        raw, _, self.buffer = self.buffer.partition(b"\n")
        line = raw.decode("utf-8", "replace").rstrip("\r\n")
        print(f"peer: <- {line}", file=sys.stderr)
        return line

    def wait_for_input(self, deadline: float) -> bool:
        """Wait until a line is ready, or the deadline passes."""
        if b"\n" in self.buffer:
            return True
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            ready, _, _ = select.select([self.socket], [], [], min(remaining, 0.5))
            if ready:
                return True

    def read_until(self, predicate, deadline: float) -> str | None:
        """Return the first line the predicate accepts, or None at the deadline."""
        while self.wait_for_input(deadline):
            line = self.read_line()
            if line is None:
                return None
            if line.startswith("PING "):
                self.send("PONG " + line.split(" ", 1)[1])
                continue
            if predicate(line):
                return line
        return None

    def wait_for_nick(self, nick: str, deadline: float) -> bool:
        """Wait until the server reports that a nickname is connected.

        An IRC server drops a message addressed to a nickname that is not
        connected, so the peer asks the server with ISON before it sends.
        """
        while time.monotonic() < deadline:
            self.send(f"ISON {nick}")
            line = self.read_until(lambda text: " 303 " in text, time.monotonic() + 3)
            # The reply lists the online nicknames after the target. The server
            # writes the colon only when the list has more than one entry.
            online = (
                [token.lstrip(":").lower() for token in line.split()[3:]]
                if line
                else []
            )
            if nick.lower() in online:
                print(f"peer: {nick} is connected", file=sys.stderr)
                return True
        print(f"peer: {nick} did not connect within the time limit", file=sys.stderr)
        return False

    def wait_for_join(self, nick: str, channel: str, deadline: float) -> bool:
        """Wait until the nickname joins the channel."""
        seen = self.read_until(
            lambda line: f":{nick}!" in line and " JOIN " in line, deadline
        )
        if seen is None:
            print(f"peer: {nick} did not join {channel}", file=sys.stderr)
            return False
        print(f"peer: saw {nick} join {channel}", file=sys.stderr)
        return True

    def join(self, channel: str) -> None:
        self.send(f"JOIN {channel}")
        print(f"peer: joined {channel}", file=sys.stderr)

    def close(self) -> None:
        try:
            self.send("QUIT :smoke test done")
            self.socket.close()
        except OSError:
            pass


def parse_privmsg(line: str) -> tuple[str, str, str] | None:
    """Return (sender, target, text) for a PRIVMSG line, else None."""
    if " PRIVMSG " not in line:
        return None
    prefix, _, rest = line.partition(" ")
    # rest is "PRIVMSG <target> :<text>". The command word sits in front of the
    # target, so split the parameters before the trailing text is removed.
    parameters, _, text = rest.partition(" :")
    fields = parameters.split()
    if len(fields) < 2 or fields[0] != "PRIVMSG":
        return None
    sender = prefix.lstrip(":").split("!")[0]
    return sender, fields[1], text


def expected_message(line: str, expect: str, expect_from: str) -> bool:
    """True when the line is the expected message from the expected sender."""
    message = parse_privmsg(line)
    if message is None:
        return False
    sender, _, text = message
    if expect_from and sender.lower() != expect_from.lower():
        return False
    return expect in text


def run(arguments: argparse.Namespace) -> int:
    deadline = time.monotonic() + arguments.timeout
    peer = IrcPeer(arguments)

    peer.send(f"NICK {arguments.nick}")
    peer.send(f"USER {arguments.nick} 0 * :{arguments.nick}")

    welcome = peer.read_until(lambda line: " 001 " in line, deadline)
    if welcome is None:
        print("peer: no welcome (001) from the server", file=sys.stderr)
        return 1

    if arguments.join:
        peer.join(arguments.join)
        peer.read_until(lambda line: " 366 " in line, time.monotonic() + 5)

    if arguments.require_nick and not peer.wait_for_join(
        arguments.require_nick, arguments.join, deadline
    ):
        return 1

    if arguments.send:
        is_channel = arguments.send_to.startswith(("#", "&"))
        if not is_channel and not peer.wait_for_nick(arguments.send_to, deadline):
            return 1
        peer.send(f"PRIVMSG {arguments.send_to} :{arguments.send}")
        print(f"peer: sent {arguments.send!r} to {arguments.send_to}", file=sys.stderr)

    if not arguments.expect:
        peer.close()
        return 0

    reply = peer.read_until(
        lambda line: expected_message(line, arguments.expect, arguments.expect_from),
        deadline,
    )
    if reply is None:
        print(
            f"peer: no reply with {arguments.expect!r} within {arguments.timeout}s",
            file=sys.stderr,
        )
        return 1

    print(reply)
    peer.close()
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--server", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--nick", required=True)
    parser.add_argument("--send", default="")
    parser.add_argument("--send-to", default="")
    parser.add_argument("--expect", default="")
    parser.add_argument("--expect-from", default="")
    parser.add_argument("--join", default="")
    parser.add_argument("--require-nick", default="")
    parser.add_argument("--timeout", type=float, default=30.0)
    arguments = parser.parse_args(argv)

    if arguments.send and not arguments.send_to:
        parser.error("--send needs --send-to")
    if arguments.expect and not arguments.send:
        parser.error("--expect needs --send")
    if arguments.send and not arguments.expect_from:
        # A reply to our message comes from the account we sent it to.
        arguments.expect_from = arguments.send_to

    try:
        return run(arguments)
    except OSError as error:
        print(f"peer: connection stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
