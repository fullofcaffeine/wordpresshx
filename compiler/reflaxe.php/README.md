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
- a real Reflaxe registration/driver tracer that lowers an ordinary Haxe
  `static main` containing `Sys.println(String)` through that IR, without
  application-authored backend IR;
- required Haxe `Int` parameters/returns and source-owned static calls lowered
  to PHP native `int` signatures and deterministic cross-module calls; and
- exact Haxe `String` locals, String-only concatenation without implicit
  coercion, value equality, and UTF-8 literal/`Sys.println` byte preservation;
- required non-null `String` parameters/returns and source-owned static String
  calls lowered to native PHP `string` signatures when every Haxe argument is
  itself an admitted non-null String expression;
- Haxe source-character positions converted to authenticated UTF-8 byte ranges,
  so non-ASCII source before or inside a mapped statement remains traceable; and
- deterministic collision-safe PHP files and exact maps per owned Haxe type,
  plus a separate dependency-ordered `bootstrap.php`, a content-addressed
  artifact-graph manifest, and staged generated-file ownership; and
- the explicit `php74-modern-v1` target profile, which selects PHP 7.4 as its
  floor, `strict_types=1`, and native `int` signatures without a floating
  "latest PHP" mode; and
- a neutral generated-PHP lint/runtime fixture that runs on exact PHP 7.4.33 and 8.4.7 containers.

This is not yet a complete arbitrary-Haxe PHP backend. The first driver path is
an architecture tracer, not a compatibility claim: typed-AST lowering breadth,
the Haxe runtime/stdlib strategy, official Haxe-suite qualification, WordPress
package index/trace policy, and public release remain separate gated work.

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
source-correlation fixture, and runs `php -l` plus native PHP execution. It also
compiles the ordinary-Haxe tracer twice, compares the emitted PHP and exact map,
checks the PHP against a manually reviewed golden, verifies source spans with an
independent reader, and proves unsupported typed AST fails without partial
output.

The tracer's intentionally tiny application source is
[`test/compiler-tracer/src/tracer/Main.hx`](test/compiler-tracer/src/tracer/Main.hx).
It imports neither compiler internals nor PHP IR. Additions to this lowering
surface must start with a concrete behavior scenario and retain both the
focused deterministic regression and the real Haxe → PHP → native-PHP path.

The next incremental behavior owner is:

```bash
bash compiler/reflaxe.php/scripts/test-semantic-matrix.sh
```

It derives [`semantic-capabilities.json`](semantic-capabilities.json) from the
typed `PhpSemanticCapabilities` registry, fails on stale or overbroad states,
and currently admits small `Int` literals/addition, initialized locals, `Int`
equality, `if/else`, required `Int` parameters/returns, and source-owned static
application calls, explicit `Int` assignment, `Int <=`, and pre-test `while`
plus fixed `Array<Int>` literals and compiler-proven constant in-bounds reads
beyond the original tracer. It also admits exact UTF-8 String literals,
initialized String locals, concatenation only when both operands are already
Strings, String value equality, printing, required non-null String
parameters/returns, and source-owned static String calls. Because ordinary Haxe
without strict null safety permits `null` where `String` is expected, the
compiler explicitly rejects a null String argument instead of generating a PHP
call with different behavior. Calls from handwritten weakly typed PHP are a
separate adapter/ABI concern and are not covered by this source-owned call
claim.
Its two-module fixture runs under stock Haxe and generated PHP; their stdout
must be byte-identical, and any PHP warning, error, or fatal fails the lane.
Optional/default and non-`Int`/non-`String` signatures, foreign static calls, compound
assignment, `do-while`, dynamic array indices, out-of-bounds reads, and implicit
String coercion, null String arguments, and foreign String calls fail without
partial output. Arbitrary array access stays
rejected because native PHP would emit an undefined-key warning where stock
Haxe returns `null`; String length/indexing/normalization also remain unclaimed
until an owned runtime can preserve Haxe semantics. Unsupported and unverified
runtime/stdlib features remain named and owned in the matrix.

The current driver emits one file per owned Haxe type. Path segments are
length-prefixed, so distinct module/type identities cannot collapse through a
separator or case-normalization shortcut. A source-derived dependency plan
orders the generated bootstrap independently of Reflaxe callback order. Cyclic
owned dependencies currently fail closed; namespaces, a general autoloader,
additional PHP profiles, and broader Haxe module/runtime semantics remain
future capabilities rather than implied support.

Generated publication uses `.reflaxe.php-owned-files.v1`: only files whose
previous content and length still match the ledger may be updated or removed,
unowned collisions and locally modified generated files fail before
publication, artifacts are staged and verified, and the ownership ledger is
published last. The focused owner exercises stale removal, collision and edit
rejection, same-process rollback, and preservation of unrelated files:

```bash
bash compiler/reflaxe.php/scripts/test-generated-output-owner.sh
```

The downstream WordPress compiler independently packages the authenticated
module graph into a deterministic plugin-shaped artifact. That one-way proof
does not add WordPress concepts to this package or broaden the compiler's Haxe
semantic claims.

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
