# Generated artifact ownership fixtures

This directory is the executable ADR-007 filesystem contract, not the production
SDK-041 artifact owner.

`valid/current.generated-files.json` owns the initial plugin and stale support
files. `valid/next.generated-files.json` replaces the plugin, removes the stale
file, and adds `theme.json`. `valid/prepared.journal.json` binds those exact old
and new states to one prepared replace/remove/create transaction. All three are
canonical JSON with content/self digests.

`artifacts/` contains the exact regular-file bytes. The `.txt` suffix keeps PHP
fixture bytes non-executable in this repository; the manifest records their real
live output names and hashes.

Run:

```bash
bash scripts/ownership/test.sh
```

The harness creates isolated temporary project roots and exercises success,
caught failure, abrupt interruption, recovery, clean, relinquishment, idempotent
rebuild, link/path/collision/edit failures, and malformed state. Refreshing
canonical fixtures is an explicit review action:

```bash
python3 scripts/ownership/test-contract.py --write-fixtures
```

Fixture success does not claim a production CLI implementation, power-loss or
Windows support, WordPress/Next.js runtime compatibility, or production support.
