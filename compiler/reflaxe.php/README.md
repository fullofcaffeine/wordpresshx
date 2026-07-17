# reflaxe.php

Private 0.x workspace package for the generic PHP compiler being continued from the Reflaxe-backed WPHX PHP work.

The current admitted surface is deliberately small:

- typed PHP statement and expression IR;
- deterministic PHP printing;
- validated identifiers, qualified names, magic constants, and binary operators;
- a neutral generated-PHP lint/runtime fixture.

This is not yet a complete arbitrary-Haxe PHP backend. The Reflaxe driver, typed-AST lowering breadth, Haxe runtime/stdlib strategy, source maps, and public release remain separate gated work.

## Boundary

This package must remain independent of WordPress and the SDK application packages. It may not contain WordPress paths, hooks, handles, plugin classes, `@:wp.*` metadata, or imports from `compiler/wordpress` or `packages`.

The future WordPress profile consumes this package. The generic package never consumes the profile.

## Test

From the repository root:

```bash
bash compiler/reflaxe.php/scripts/test.sh
```

The test compiles the Haxe test harness with Haxe 4.3.7, checks deterministic snapshots and rejected unsafe names/operators, writes an ignored PHP fixture, runs `php -l`, and executes the fixture.

## Origin and release status

[`provenance.json`](provenance.json) records the exact `wordpresshx-port` source commit, tree, blobs, hashes, transformations, and exclusions. The imported source is GPL-2.0-or-later. Final SDK/compiler/generated-output licensing remains blocked on ADR-020; this package is version `0.0.0` and must not be published yet. Its Haxelib `url` is intentionally empty until SDK-004 records a maintainer-authorized canonical repository; source provenance URLs remain exact and independent of that destination.

Package ownership and extraction triggers are defined by [ADR-004](../../docs/adr/004-generic-php-compiler-home.md).
