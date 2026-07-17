# reflaxe.php

Private 0.x workspace package for the generic PHP compiler being continued from the Reflaxe-backed WPHX PHP work.

The current admitted surface is deliberately bounded:

- typed PHP file, namespace, function, class, interface, trait, property, method, statement, and expression IR;
- PHP 7.4-compatible signature types, parameters, by-reference boundaries, native arrays, callable arrays, and closures;
- validated relative file/source paths, identifiers, qualified names, magic constants, and binary operators;
- deterministic declaration ordering and declaration-level generated/source line correlation;
- a neutral generated-PHP lint/runtime fixture that runs on exact PHP 7.4.33 and 8.4.7 containers.

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

Run the exact PHP floor/current matrix after the package test has generated its fixture:

```bash
bash compiler/reflaxe.php/scripts/test-php-matrix.sh
```

The matrix uses immutable official PHP container index digests and disables container networking during lint/runtime execution. The rendered declaration ranges are the structural input for SDK-025; this package does not yet serialize the final `*.haxe-map.json` format or provide a trace CLI.

## Origin and release status

[`provenance.json`](provenance.json) records the exact `wordpresshx-port` source commit, tree, blobs, hashes, transformations, and exclusions. The imported source is GPL-2.0-or-later. Final SDK/compiler/generated-output licensing remains blocked on ADR-020; this package is version `0.0.0` and must not be published yet. Its Haxelib `url` identifies the canonical SDK monorepo established by SDK-004; that repository URL does not authorize package publication, and the source provenance URLs remain exact and independent of the destination.

Package ownership and extraction triggers are defined by [ADR-004](../../docs/adr/004-generic-php-compiler-home.md).
