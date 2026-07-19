# reflaxe.php

Private 0.x workspace package for the generic PHP compiler being continued from the Reflaxe-backed WPHX PHP work.

The current admitted surface is deliberately bounded:

- typed PHP file, namespace, function, class, interface, trait, property, method, statement, and expression IR;
- PHP 7.4-compatible signature types, parameters, by-reference boundaries, native arrays, callable arrays, and closures;
- validated relative file/source paths, identifiers, qualified names, magic constants, and binary operators;
- deterministic declaration ordering plus authenticated declaration, member,
  and statement-level generated/source byte correlation;
- content-bound logical source files, semantic node IDs, explicit line-trace
  anchors, and a deterministic caller-named range-map writer; and
- a neutral generated-PHP lint/runtime fixture that runs on exact PHP 7.4.33 and 8.4.7 containers.

This is not yet a complete arbitrary-Haxe PHP backend. The Reflaxe driver,
typed-AST lowering breadth, Haxe runtime/stdlib strategy, WordPress package
index/trace policy, and public release remain separate gated work.

## Boundary

This package must remain independent of WordPress and the SDK application packages. It may not contain WordPress paths, hooks, handles, plugin classes, `@:wp.*` metadata, or imports from `compiler/wordpress` or `packages`.

The future WordPress profile consumes this package. The generic package never consumes the profile.

## Test

From the repository root:

```bash
bash compiler/reflaxe.php/scripts/test.sh
```

The test compiles the Haxe test harness with Haxe 4.3.7, checks deterministic
snapshots and rejected unsafe names/operators, emits a neutral multibyte
source-correlation fixture, writes ignored PHP/map artifacts, runs `php -l`, and
executes both fixtures.

Prove the release-shaped package seam independently:

```bash
bash compiler/reflaxe.php/scripts/test-package.sh
```

That gate builds the source-only package twice and requires byte-identical ZIPs,
installs the exact archive into a disposable Haxelib repository, first proves
that the package cannot resolve before installation, and then compiles a neutral
external Haxe application. The application emits ordinary PHP through the
installed typed IR/printer and the gate lints and executes that PHP. Neither the
consumer nor its generated output resolves the WordPress profile, SDK packages,
this checkout, a sibling checkout, or `haxelib dev`.

The generated `build/package-artifact/artifact-manifest.json` binds the archive
to its source-tree hash, archive hash, Git commit, dirty state, fixed timestamp,
and publication status. CI adds `--require-clean`; ordinary local development
may exercise intentional uncommitted changes without turning them into release
evidence.

Run the exact PHP floor/current matrix after the package test has generated its fixture:

```bash
bash compiler/reflaxe.php/scripts/test-php-matrix.sh
```

The matrix uses immutable official PHP container index digests and disables
container networking during lint/runtime execution. The generic writer accepts
the map identity from its caller, so the neutral package does not own the public
WordPressHx `*.haxe-map.json` format, package source index, or CLI. Those remain
one-way consumers in `compiler/wordpress` and `packages/cli`.

## Origin and release status

[`provenance.json`](provenance.json) records the exact `wordpresshx-port` source commit, tree, blobs, hashes, transformations, and exclusions. The imported source is GPL-2.0-or-later. Final SDK/compiler/generated-output licensing remains blocked on ADR-020; this package is version `0.0.0` and must not be published yet. Its Haxelib `url` identifies the canonical SDK monorepo established by SDK-004; that repository URL does not authorize package publication, and the source provenance URLs remain exact and independent of the destination.

Package ownership and extraction triggers are defined by [ADR-004](../../docs/adr/004-generic-php-compiler-home.md).
The package-owned [extraction procedure](EXTRACTION.md) defines defect routing,
the maintained standalone seam, immutable downstream pins, and the steps that
apply only after an ADR-004 trigger is accepted.
