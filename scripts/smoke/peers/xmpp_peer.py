"""Scripted XMPP peer for the Jabber smoke test.

The peer connects to a local server as a second account, sends one message to
the account under test, and then waits for a reply. The message text carries a
token, so a stale message from an earlier run cannot pass the check.

Usage:
  xmpp_peer.py --jid smoke-b@localhost --password <pw> --server 127.0.0.1
               [--port 5222] --peer smoke-a@localhost
               --send <text> --expect <text> [--timeout 30]

Exit 0 after the expected reply arrives. Print the reply text on stdout.
Every diagnostic goes to stderr.
"""

from __future__ import annotations

import argparse
import asyncio
import sys

import slixmpp


class Peer(slixmpp.ClientXMPP):
    """A client that sends one message and waits for a reply."""

    def __init__(self, arguments: argparse.Namespace) -> None:
        super().__init__(arguments.jid, arguments.password)
        self.arguments = arguments
        self.reply: asyncio.Future[str] = asyncio.get_event_loop().create_future()

        self.register_plugin("xep_0030")  # service discovery, needed by the server
        # The test server disables TLS, so the client must accept a plaintext
        # password. slixmpp refuses that unless the mechanism is enabled here.
        self.plugin["feature_mechanisms"].unencrypted_plain = True
        self.add_event_handler("session_start", self.on_session_start)
        self.add_event_handler("message", self.on_message)

    async def on_session_start(self, _event: object) -> None:
        self.send_presence()
        await self.get_roster()
        self.send_message(
            mto=self.arguments.peer, mbody=self.arguments.send, mtype="chat"
        )
        print(
            f"peer: sent {self.arguments.send!r} to {self.arguments.peer}",
            file=sys.stderr,
        )

    def on_message(self, message: object) -> None:
        if message["type"] not in ("chat", "normal"):
            return
        body = message["body"]
        print(f"peer: received {body!r} from {message['from']}", file=sys.stderr)
        if self.arguments.expect in body and not self.reply.done():
            self.reply.set_result(body)


async def run(arguments: argparse.Namespace) -> int:
    peer = Peer(arguments)
    # The test server disables TLS, so the handshake never needs a context.
    # The connect still gets a deadline: a server that accepts the socket and
    # then stalls must not hold the run open.
    try:
        await asyncio.wait_for(
            peer.connect(arguments.server, arguments.port), timeout=arguments.timeout
        )
    except TimeoutError:
        print(
            f"peer: the server did not answer the handshake within {arguments.timeout}s",
            file=sys.stderr,
        )
        return 1

    try:
        reply = await asyncio.wait_for(peer.reply, timeout=arguments.timeout)
    except TimeoutError:
        print(
            f"peer: no reply with {arguments.expect!r} within {arguments.timeout}s",
            file=sys.stderr,
        )
        return 1

    print(reply)
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--jid", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--server", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5222)
    parser.add_argument("--peer", required=True)
    parser.add_argument("--send", required=True)
    parser.add_argument("--expect", required=True)
    parser.add_argument("--timeout", type=float, default=30.0)
    arguments = parser.parse_args(argv)

    try:
        return asyncio.run(run(arguments))
    except (KeyboardInterrupt, slixmpp.exceptions.XMPPError) as error:
        print(f"peer: connection stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
