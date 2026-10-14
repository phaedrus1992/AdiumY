"""Scripted IRC peer for the IRC smoke test.

The peer connects to a local server with a valid nickname, sends one message,
and then waits for a reply that carries an expected token. The token makes a
stale message from an earlier run useless.

The peer speaks the IRC protocol over a plain socket, so the test needs no IRC
library.

Usage:
  irc_peer.py --server 127.0.0.1 --port <port> --nick smoke-b
              --send <text> --send-to <target> --expect <text>
              [--join <channel>] [--require-nick <nick>] [--timeout 30]

Exit 0 after the expected reply arrives. Print the reply line on stdout.
Every diagnostic goes to stderr.
"""

from __future__ import annotations

import argparse
import socket
import sys
import time


class IrcPeer:
    """A small IRC client: connect, send one message, wait for one reply."""

    def __init__(self, arguments: argparse.Namespace) -> None:
        self.arguments = arguments
        self.socket = socket.create_connection(
            (arguments.server, arguments.port), timeout=arguments.timeout
        )
        self.buffer = b""
        self.stream = self.socket.makefile("rb")

    def send(self, line: str) -> None:
        self.socket.sendall(f"{line}\r\n".encode())

    def read_line(self) -> str | None:
        """Read one IRC line. Return None at end of stream."""
        raw = self.stream.readline()
        if not raw:
            return None
        line = raw.decode("utf-8", "replace").rstrip("\r\n")
        print(f"peer: <- {line}", file=sys.stderr)
        return line

    def read_until(self, predicate, deadline: float) -> str | None:
        """Return the first line the predicate accepts, or None at the deadline."""
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            self.socket.settimeout(max(0.5, min(remaining, 5.0)))
            try:
                line = self.read_line()
            except TimeoutError:
                continue
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

        IRC server drops a message addressed to a nickname that is not
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
    target, _, text = rest.partition(" :")
    sender = prefix.lstrip(":").split("!")[0]
    return sender, target, text


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
        peer.read_until(
            lambda line: " 366 " in line or " 353 " in line, time.monotonic() + 5
        )

    is_channel = arguments.send_to.startswith(("#", "&"))
    if not is_channel and not peer.wait_for_nick(arguments.send_to, deadline):
        return 1

    peer.send(f"PRIVMSG {arguments.send_to} :{arguments.send}")
    print(f"peer: sent {arguments.send!r} to {arguments.send_to}", file=sys.stderr)

    if arguments.require_nick:
        seen = peer.read_until(
            lambda line: f":{arguments.require_nick}!" in line and " JOIN " in line,
            deadline,
        )
        if seen is None:
            print(
                f"peer: {arguments.require_nick} did not join {arguments.join}",
                file=sys.stderr,
            )
            return 1
        print(f"peer: saw {arguments.require_nick} join", file=sys.stderr)

    def is_expected(line: str) -> bool:
        message = parse_privmsg(line)
        return message is not None and arguments.expect in message[2]

    reply = peer.read_until(is_expected, deadline)
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
    parser.add_argument("--send", required=True)
    parser.add_argument("--send-to", required=True)
    parser.add_argument("--expect", required=True)
    parser.add_argument("--join", default="")
    parser.add_argument("--require-nick", default="")
    parser.add_argument("--timeout", type=float, default=30.0)
    arguments = parser.parse_args(argv)

    try:
        return run(arguments)
    except OSError as error:
        print(f"peer: connection stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
