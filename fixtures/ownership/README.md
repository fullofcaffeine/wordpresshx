# Generated artifact ownership fixtures

This directory supplies the canonical ADR-007 contract vectors and the real
SDK-041 Haxe artifact-owner corpus.

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

The aggregate gate first runs the independent Python ADR oracle. It then compiles
the production Haxe owner twice through immutable Genes, compares both generated
trees, and runs the result on exact Node 22.17.0 with networking disabled. The
production corpus creates isolated project roots and exercises success, caught
failure, thirteen abrupt interruptions across build/clean/adopt phases, exact
rollback/finalization, idempotent rebuild, complete staging, strict JSON,
link/path/collision/edit failures, and malformed or tampered recovery state.
Refreshing canonical fixtures remains an explicit review action:

```bash
python3 scripts/ownership/test-contract.py --write-fixtures
```

The artifact-owner library is implemented and SDK-043 exercises it through
`wphx build` and `wphx clean`. The evidence does not claim
power-loss, Windows/network-filesystem, hostile concurrent mutation,
WordPress/Next.js runtime compatibility, or production support.
