# Release Appcast with Sparkle 2

Sparkle 2 ships CLI tools that handle appcast XML generation and EdDSA signing.
These replace the old `AppcastReplaceItem.py` (Python 2, md5Sum-based, removed).

## Prerequisites

Run `Dependencies/build-phases/get-sparkle.sh` to fetch both the Sparkle.framework
and the CLI tools. The tools land in `Dependencies/build/sparkle-tools/`:

- `generate_appcast` — maintains the whole appcast file across releases
- `generate_keys` — creates an Ed25519 keypair (one-time setup)
- `sign_update` — signs an update archive with the private key

## One-time: Generate signing key

```bash
Dependencies/build/sparkle-tools/generate_keys
```

This stores the private key in your login Keychain and prints the base64-encoded
public key. Copy the public key into `Resources/Info.plist` under `SUPublicEDKey`.

## Per release: Generate appcast

```bash
Dependencies/build/sparkle-tools/generate_appcast /path/to/release-archives/
```

Point `generate_appcast` at a directory containing the `.dmg` (or `.zip`/`.tar.xz`)
release archives. It writes/updates `appcast.xml` in that directory with correct
`sparkle:edSignature`, `length`, `sparkle:version`, and `pubDate` for every
archive — no per-item scripting needed.

## Verification

```bash
Dependencies/build/sparkle-tools/sign_update /path/to/archive.dmg
```

Prints the `sparkle:edSignature` for the file. Compare it against what
`generate_appcast` wrote in the appcast `<enclosure>`.
