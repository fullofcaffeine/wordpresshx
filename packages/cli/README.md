# WordPressHx CLI

`@wordpress-hx/cli` is the version-matched host executable for WordPressHx.
SDK-043 adds the production Haxe command foundation at `wphx`; SDK-025's
private `wphx-sdk` trace launcher remains as a compatibility alias for its
authenticated historical evidence. Both applications are authored in Haxe and
Genes emits their Node ESM executables. There is no handwritten JavaScript
implementation and no dependency on a sibling Genes checkout.

The final project command is compiled from `wordpresshx.cli.WphxMain` with
`profiles/wphx.hxml`; the frozen trace-only entry remains compiled from
`wordpresshx.cli.Main` with `profiles/classic.hxml`. No released user depends
on the prototype spelling.

The package is internal and publication remains blocked. Its exact build closure
is recorded in [`dependency-lock.json`](dependency-lock.json): Haxe 4.3.7,
Lix package 15.12.4 (reported CLI 15.12.2),
Genes 1.36.3 at commit
`c59ecb361fd91418584487c2138bae8d3d3a3961`, hxnodejs 10.0.0, and Node
22.17.0. The SDK-034 browser evidence closure additionally pins esbuild 0.27.2,
playwright-core 1.58.2, and the Playwright image's exact platform children:
browser 145.0.7632.6 on Linux AMD64 and 145.0.7632.0 on Linux ARM64. Both
platforms produce byte-identical deliberate-failure stacks and source
correlations. The test harness authenticates and invokes the Haxe shim adjacent to
the active Lix executable, so scoped libraries do not depend on whichever
system Haxe happens to appear first on `PATH`. SDK-025 required no Genes source
change or pull request.

## Generated artifact ownership

SDK-041 adds the production Haxe implementation of
`wordpress-hx.ownership-transaction.v1` under
`wordpresshx.cli.ownership`. Emitters hand it a canonical next manifest and a
complete caller stage. The owner reruns the exact manifest validator callbacks,
rehashes every binary file, copies the complete tree below a private
same-filesystem transaction root, creates an exclusive lock and durable
self-digested journal, moves exact old bytes to backups, and publishes the new
manifest last as the commit marker.

`clean` removes only current manifest entries whose bytes still match.
`adoptGenerated` keeps exact live bytes while transactionally relinquishing the
named entries. Recovery either finalizes a complete committed generation or
walks operations backward and restores exact prior hashes; unexpected live,
backup, lock, journal, or manifest bytes stop recovery without a force path.

This is the safety primitive used by `wphx build` and `wphx clean`, and the
future `wphx dev` last-known-good loop. SDK-044 still owns the long-running
watcher, compiler server, services, readiness, reload, and shutdown engine.

## Project commands

Run commands from a directory at or below a generated `wordpress-hx.json`, or
pass `--project <path>`. The CLI discovers and strictly validates the project,
its self-digested exact lock, profile, package graph, HXML inputs, source and
asset discovery roots, public build environment, and ownership state before it
invokes a tool or writes an artifact.

```bash
wphx build
wphx build --dry-run --json
wphx check
wphx inspect project
wphx inspect inputs --json
wphx inspect build --json
wphx inspect provenance .wphx/generated/effective-inputs.json --json
wphx doctor
wphx clean
```

`build` types the configured Haxe entry directly with the exact locked
toolchain, validates the complete staged generation, and commits it through the
manifest-last artifact owner. `check`, `doctor`, every `inspect` topic, and
`build --dry-run` are read-only. `clean` removes only current manifest entries
whose exact bytes still match and retains every unowned file.

The SDK-042/043 slice emits three CLI-owned artifacts: the effective-input
metadata, a canonical reproducibility report, and a deterministic unsigned ZIP
that contains the report plus its declared payload. The archive is deliberately
bounded build evidence, not yet a deployable site package: PHP, browser, asset,
and target-package stages report `stage-skipped` until their registered
producers land. A skipped producer is never represented as a site build.
`wphx dev` is a stable parsed command but currently exits with `WPHX4000`
without modifying the project, because SDK-044 must supply and prove the real
long-running engine.

Use `--json` for canonical JSONL lifecycle events and closed diagnostics. Human
errors include a stable `WPHXnnnn` code, failing stage, safe project-relative
path when one is available, and an actionable remediation. Runtime secrets are
neither read into the effective graph nor serialized into diagnostics.

## PHP trace command

Capture the native PHP exception as normal, then correlate it against the exact
source index from the same build:

```bash
wphx-sdk trace php failure.stack \
  --index debug-companion/source-index.json \
  --source-root project=/absolute/path/to/checkout \
  --format text
```

Use `--format json` for canonical machine-readable output. `--source-root`
resolves a declared logical root ID to local content; it is repeatable for
separate project or dependency roots. The index, map, generated PHP, and any
resolved source are authenticated before lookup. Paths in correlation metadata
stay normalized and project-relative. The CLI does not use the network, mutate
the stack or artifacts, search by basename, or guess a nearby mapping.

Native stack lines are always retained. A PHP line maps only when it has one
unique emitter-owned trace anchor. Missing coverage is reported honestly as
`native-unmapped`, `unmapped-no-anchor`, or `unmapped-no-layer` rather than being
promoted to an exact Haxe location.

Exit codes are stable:

- `0`: the valid trace was processed, including valid unmapped frames;
- `2`: usage or stack-input error;
- `3`: schema or integrity failure; and
- `4`: ambiguous correlation contract.

## Browser trace command

Correlate a captured Chromium stack against the source index from the same
browser build:

```bash
wphx-sdk trace browser browser.stack \
  --index debug-companion/source-index.json \
  --source-root project=/absolute/path/to/checkout \
  --source-root genes=/absolute/path/to/genes/source \
  --format text
```

The closed regular Source Map v3 reader validates Base64 VLQ segments and every
generated, intermediate, map, and resolved source hash before lookup. A proven
composed entry reports `mapped-composed`; an authenticated JS-to-TS/TSX-to-Haxe
chain reports `mapped-two-stage`. Unknown files, missing columns, and valid
unmapped segments retain their exact native frame without basename, suffix, or
nearest-line guessing. URL origins are transport details; the complete decoded
pathname is the file identity.

SDK-034 admits the exact Genes 1.36.3/esbuild 0.27.2 fixture entry in
development, minified production, and two-stage modes. G2.4 separately projects
the same strict lookup contract through the exact SDK-033
`@wordpress/scripts` 31.5.0 entry in development and minified production. Its
real Chromium frames resolve through one authenticated composed layer to the
same Haxe token while preserving native frames and honest unmapped results.
This remains a bounded entry-and-mode claim; future entries and NextJsHx
adapters must be proven independently.

## Development and packaging

Development builds may keep an index, external map, and allowlisted local source
copy. A production install ZIP contains readable PHP or runtime JavaScript only,
according to the target package. A separately generated debug companion contains
the exact maps/index and generated TypeScript needed for correlation but no Haxe
source; it is content-bound to the production runtime. Operators provide source
roots locally when investigating a failure.

Run the complete deterministic compile, locked Node/PHP runtime, output snapshot,
package replay, path-privacy, and tamper suite from the repository root:

```bash
bash scripts/determinism/test-production.sh
bash scripts/project-cli/test-production.sh
bash packages/cli/scripts/test.sh
bash packages/cli/scripts/test-browser-source-correlation.sh
```

The project-command corpus compiles the `wphx` entry twice and compares the
generated trees, types the real Haxe fixture, and exercises the command through
exact Node 22.17.0 with networking disabled. It covers discovery, effective
input parity, public-environment invalidation, secret exclusion, no-write
commands, publication/replay/clean/provenance, tamper and ownership failures,
invalid locks/configuration/package graphs, links and special files, Haxe
failure, and the honest SDK-044 handoff.

The SDK-042 determinism gate copies the same accepted project into two fresh,
unrelated roots at different depths, varies source modes and modification
times, builds with the locked offline Node runtime, and compares every owned
file, mode, manifest byte, report, and ZIP byte. It independently parses the
ZIP policy and proves actionable failures for corrupted bytes, mode drift, and
missing artifacts before exercising the safe additive output-root migration
from the SDK-043 generation.

The bounded implementation and non-claims are recorded by
[`SDK-043-PROJECT-CLI`](../../manifests/evidence/sdk-043-project-cli.json),
[`SDK-042-DETERMINISTIC-BUILD`](../../manifests/evidence/sdk-042-deterministic-build.json),
[`SDK-025-PHP-SOURCE-CORRELATION`](../../manifests/evidence/sdk-025-php-source-correlation.json)
and
[`SDK-034-BROWSER-SOURCE-CORRELATION`](../../manifests/evidence/sdk-034-browser-source-correlation.json).
The official WordPress adapter proof is recorded by
[`G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION`](../../manifests/evidence/g2.4-wordpress-scripts-source-correlation.json).
