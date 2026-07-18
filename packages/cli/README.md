# WordPressHx CLI

`@wordpress-hx/cli` is the version-matched host executable for WordPressHx.
The SDK-025 slice implements offline PHP stack correlation. Its application
logic is Haxe and Genes emits the Node ESM executable; there is no handwritten
JavaScript implementation and no dependency on a sibling Genes checkout.

The package is internal and publication remains blocked. Its exact build closure
is recorded in [`dependency-lock.json`](dependency-lock.json): Haxe 4.3.7,
Lix package 15.12.4 (reported CLI 15.12.2),
Genes 1.36.3 at commit
`c59ecb361fd91418584487c2138bae8d3d3a3961`, hxnodejs 10.0.0, and Node
22.17.0. The test harness authenticates and invokes the Haxe shim adjacent to
the active Lix executable, so scoped libraries do not depend on whichever
system Haxe happens to appear first on `PATH`. SDK-025 required no Genes source
change or pull request.

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

`trace browser` is intentionally unavailable in this slice. SDK-034 owns its
Source Map v3 stack parser, composed/two-stage lookup, and deliberate
development/minified runtime evidence.

## Development and packaging

Development builds may keep an index, external map, and allowlisted local source
copy. A production install ZIP contains readable PHP only. The separately
generated debug companion contains the exact map and index but no PHP or Haxe
source, and is content-bound to the production PHP. Operators provide source
roots locally when investigating a failure.

Run the complete deterministic compile, locked Node/PHP runtime, output snapshot,
package replay, path-privacy, and tamper suite from the repository root:

```bash
bash packages/cli/scripts/test.sh
```

The bounded implementation and non-claims are recorded by
`SDK-025-PHP-SOURCE-CORRELATION` in
[`manifests/evidence`](../../manifests/evidence/sdk-025-php-source-correlation.json).
