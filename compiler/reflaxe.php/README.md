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
- typed `Bool` literals/locals, logical negation, direct conditions, required
  non-null parameters/returns, and source-owned static calls lowered to native
  PHP `bool`, plus lazy `&&`/`||` with explicit typed grouping so PHP preserves
  Haxe precedence and short-circuit evaluation without admitting truthiness;
- one non-inherited source-owned class shape with a private constructor-set
  `String` field, required `String` constructor and instance method, a typed
  object local, native construction, field read, and instance call;
- required unary `String -> String` closures with read-only lexical `String`
  captures lowered to typed static PHP closures, explicit by-value `use`
  clauses, direct invocation, and independently mapped closure bodies;
- one immediate `throw new haxe.Exception(String)` guarded by one exact
  `catch (error:haxe.Exception)`, lowered to native `RuntimeException`, with
  typed `error.message` access lowered to `getMessage()`;
- Haxe source-character positions converted to authenticated UTF-8 byte ranges,
  so non-ASCII source before or inside a mapped statement remains traceable; and
- deterministic collision-safe PHP files and exact maps per owned Haxe type,
  plus a separate dependency-ordered `bootstrap.php`, a content-addressed
  artifact-graph manifest, and staged generated-file ownership; and
- the explicit `php74-modern-v1` target profile, which selects PHP 7.4 as its
  floor, `strict_types=1`, and native `int` signatures without a floating
  "latest PHP" mode; and
- a neutral generated-PHP lint/runtime fixture that runs on exact PHP 7.4.33 and 8.4.7 containers; and
- one narrow typed native-function boundary: a public static method on an
  `extern` class may use `@:phpGlobalFunction("name")`, and an ordinary Haxe
  statement call with admitted `String` arguments lowers to a validated,
  root-qualified PHP global call. The function name cannot contain PHP syntax.

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

The first native interop owner is separate from the semantic matrix:

```bash
bash compiler/reflaxe.php/scripts/test-native-global.sh
```

Its application calls a typed `printf` extern and never imports compiler
internals or backend IR. A manually authored PHP golden and stdout expectation
are checked with the native PHP parser/runtime. Missing annotations and invalid
function names fail at the Haxe source boundary without partial output. This is
not arbitrary PHP injection or broad native interop: only static extern calls
with admitted String arguments are currently accepted.

The next incremental behavior owner is:

```bash
bash compiler/reflaxe.php/scripts/test-semantic-matrix.sh
```

It derives [`semantic-capabilities.json`](semantic-capabilities.json) from the
typed `PhpSemanticCapabilities` registry, fails on stale or overbroad states,
and admits small `Int` literals, addition, subtraction, initialized locals,
equality, and `if/else`. Exact `Int` conditions also admit `<`, `<=`, `>`, and
`>=`. It admits required `Int` parameters and returns. It also admits
source-owned static calls, explicit assignment, and pre-test `while`. The array
subset includes fixed `Array<Int>` literals and
exact length. It includes direct result-discarded push and non-empty pop.
It also includes compiler-proven constant in-bounds reads and writes.
The matrix admits exact UTF-8 String literals,
initialized String locals, concatenation only when both operands are already
Strings, String value equality, printing, required non-null String
parameters/returns, and source-owned static String calls. Because ordinary Haxe
without strict null safety permits `null` where `String` is expected, the
compiler explicitly rejects a null String argument instead of generating a PHP
call with different behavior. Calls from handwritten weakly typed PHP are a
separate adapter/ABI concern and are not covered by this source-owned call
claim.
The numeric subset preserves Haxe grouping and operator precedence. It keeps
`9 - (4 - 2)` grouped in the generated PHP. It also distinguishes
`2 + 3 * 4` from `(2 + 3) * 4`. This first multiplication path accepts only
compiler-proven, 32-bit-safe constant expressions. The same proof admits unary
negation, including nested and grouped constant expressions. Runtime-dependent
and Float multiplication or negation fail before output. Integer-minimum
negation overflow, division, modulo, coercion, and general numeric behavior
remain unproved.
The ordering slice lowers native PHP comparisons only after both operands have
exact Haxe `Int` type and pass the existing `Int` expression validator. A
stock-Haxe-valid Float ordering fixture fails before output. Mixed numeric,
String, null, object, coercion, spaceship, NaN, and general comparison behavior
remain unproved.
The first explicit nullable slice is narrower: `Null<String>` locals may be
initialized from `null` or an admitted String, passed to a source-owned required
`Null<String>` parameter, and compared with `null` using `==` or `!=`. The
compiler emits PHP 7.4-compatible `?string` signatures, native `null`, and
strict `===`/`!==` checks. `Null<Int>`, `Null<Bool>`, nullable objects or arrays,
mutation, optional/default parameters, dereference/flow narrowing, foreign
callers, and general null/runtime behavior remain rejected or unclaimed. The
same bounded slice admits a unary source-owned `Null<String> -> Null<String>`
function and call, emitting `?string` for both parameter and return type; it
does not generalize nullable returns to other types or expression shapes.
The same fail-closed rule applies to the admitted Boolean slice: exact Bool
literals, locals, logical negation, direct conditions, required non-null
parameters/returns, source-owned calls, and lazily evaluated `&&`/`||` lower to
native PHP `bool`. Bool binary expressions use a typed parenthesized PHP IR node
so mixed `(a || b) && c` grouping is retained rather than delegated to target
precedence. A stock-Haxe-valid null Bool argument and foreign Bool calls are
rejected before emission. PHP truthy coercion, bitwise Bool operations, Bool
equality/mutation, and weak-PHP callers remain separate capabilities.
The same fixture now includes a third source-owned class. It proves a narrow
modern object path: Haxe `new Greeter(...)` becomes a dedicated PHP class with a
private typed property, `__construct`, and native instance call. The field must
be private, `String`-typed, and constructor-only; mutable fields, inheritance,
interfaces, overrides, accessors, nullable objects, and general object/runtime
semantics still fail closed or remain unclaimed.
The callback slice additionally proves one required unary `String -> String`
function value with read-only `String` captures. It lowers to a native static
PHP closure with `string` parameter/return types and by-value captures, then is
invoked directly from Haxe. Multiple/optional parameters, non-String or mutable
captures, nested closures, `this`, closure escape/return, recursion, variadics,
foreign callables, and general function values remain rejected or unclaimed.
The exception slice proves only one immediate Haxe `Exception` throw and one
matching catch in the same method, including a typed caught-message read.
Multiple or nested try blocks, arbitrary thrown values, other exception types,
finally, rethrow, exception inheritance, foreign exceptions, and broad
exception/runtime behavior remain rejected or unclaimed. Haxe lexical local
names must also remain unique within an admitted method because PHP catch and
ordinary locals share function scope; a stock-Haxe-valid collision fails before
publication instead of silently changing behavior.
Its three-module fixture runs under stock Haxe and generated PHP; their stdout
must be byte-identical, and any PHP warning, error, or fatal fails the lane.
Optional/default and signature types outside the admitted `Int`/`Bool`/`String` subset, foreign static calls, compound
assignment, `do-while`, dynamic array indices, out-of-bounds reads, and implicit
String coercion, null String/Bool arguments, foreign String/Bool calls, mutable
instance fields, inherited instance layouts, unsupported closure shapes, and
mutable captured Strings fail without
partial output. Arbitrary array access stays rejected because native PHP would
emit an undefined-key warning where stock Haxe returns `null`. Array `.length`
uses native PHP `count` only for a proven compiler-owned `Array<Int>` local.
A direct `values.push(value)` statement lowers to `$values[] = value` for that
proven local. The compiler updates its exact length proof before later reads.
The direct statement `values[1] = value` lowers to a native PHP indexed write
only when the compiler proves that index. A direct result-discarded
`values.pop()` lowers to native `array_pop($values)` only when the compiler
proves that the owned array is not empty. The compiler reduces its exact length
before it checks later reads. Push or pop return values, empty pop, and mutation
in branches or loops remain rejected. Other receivers, aliases, dynamic or
out-of-bounds writes, and iteration also remain rejected. The first owned
runtime slice now lowers non-null `String.length` to an on-demand,
typed-IR-authored PHP helper that counts Unicode scalar values, so
`"A🚀".length` is `2` rather than PHP's `strlen` byte count of `5`. It requires
no `mbstring`, rejects malformed UTF-8 explicitly, and is emitted, mapped,
owned, and dependency-ordered only when used. String indexing, substring,
normalization, grapheme behavior, nullable receivers, and the broader Haxe
runtime remain unclaimed. Unsupported and unverified runtime/stdlib features
remain named and owned in the matrix.

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
installs the exact archive into a disposable Haxelib repository, and first
proves that the package cannot resolve before installation. The gate packages
each exact installed dependency as a local seed. It installs those seeds with
dependency fetching disabled. Thus, a package test does not depend on the
Haxelib network after the workflow installs its exact toolchain.

The gate then compiles a neutral external Haxe application. The application
emits ordinary PHP through the installed typed IR and printer. The gate checks
and runs that PHP. Neither the consumer nor its generated output resolves the
WordPress profile, SDK packages, this checkout, a sibling checkout, or
`haxelib dev`.

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
