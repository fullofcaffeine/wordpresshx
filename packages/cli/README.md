# WordPressHx CLI

`@wordpress-hx/cli` is the version-matched host executable for WordPressHx.
SDK-025 implements offline PHP stack correlation and SDK-034 adds authenticated
browser Source Map v3 correlation. Its application logic is Haxe and Genes
emits the Node ESM executable; there is no handwritten JavaScript implementation
and no dependency on a sibling Genes checkout.

ADR-016 selects `wphx` as the generated-project binary and `wphx dev` as the
one-command development loop. This package is still a private trace-only
prototype whose checked launcher is named `wphx-sdk`; SDK-043 must add and
migrate the final command without invalidating the existing correlation
evidence, and SDK-044 must prove real watch/process behavior. No released user
depends on the prototype spelling.

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

This is the safety primitive for the `wphx dev` last-known-good loop. SDK-043
still needs to expose it through the final `wphx build`, `clean`, and
`adopt-generated` commands, and SDK-044 still owns watching and services.

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
bash packages/cli/scripts/test.sh
bash packages/cli/scripts/test-browser-source-correlation.sh
```

The bounded implementation and non-claims are recorded by
[`SDK-025-PHP-SOURCE-CORRELATION`](../../manifests/evidence/sdk-025-php-source-correlation.json)
and
[`SDK-034-BROWSER-SOURCE-CORRELATION`](../../manifests/evidence/sdk-034-browser-source-correlation.json).
The official WordPress adapter proof is recorded by
[`G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION`](../../manifests/evidence/g2.4-wordpress-scripts-source-correlation.json).
