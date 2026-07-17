# Locks and evidence manifests

This directory contains immutable toolchain/upstream locks, evidence receipts, and future release manifests. No placeholder hash may be interpreted as a pin; exact identities are added by the corresponding gate bead.

- `upstream.lock.json` records resolved cross-project inputs. Its `partial` status means only the listed entries are pinned; omitted upstreams remain unresolved rather than receiving guessed or floating values.
- `evidence/` contains the command, environment, hosted-CI, limitation, and artifact evidence behind a lock entry.

The first resolved input is genes-ts `v1.33.0`, recorded by `wordpresshx-sdk-030`. Global SDK/WordPress/PHP compiler locks remain separate gated work.
