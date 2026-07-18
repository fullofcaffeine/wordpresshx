# Source-correlation contract fixtures

These files exercise the accepted ADR-014 schemas without claiming compiler or
runtime completion. The fixture contains one content-bound PHP range map, one
standard Source Map v3 browser chain already composed to Haxe, and one explicit
JavaScript-to-TypeScript-to-Haxe two-stage chain.

`source-index.valid.json` is a debug-companion index. Runtime files are marked as
production artifacts, while maps, generated TypeScript, and source content are
separate debug-companion files. This fixture deliberately exercises the
`allowlisted-debug-only` source-content branch with public test content. Real
debug packages default to omitting source content; including it requires an
explicit allowlist plus release secret, license, and path scans.

Run `python3 scripts/source-correlation/validate-contracts.py` to validate the
closed schemas, exact bytes and hashes, UTF-8 coordinates, layer continuity,
retention policy, and fail-closed negative mutations.
