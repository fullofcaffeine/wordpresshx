# Generic PHP compiler boundary

ADR-004 places the generic PHP compiler in [`compiler/reflaxe.php`](../../compiler/reflaxe.php) as a private, extraction-ready 0.x workspace package. This is an ownership decision, not a claim that the current slice is a complete PHP backend.

## Origin inventory

The first import used `wordpresshx-port` commit `7fdda0aa5ea66900819842aefeac6747421e9130`, tree `a5cc51c68ca443108b5b133612c2f389ebf31364`. The current clean source-evidence authority is reviewed merge commit `20b9c974f141375b6cf191db6f25b115812e282c`, tree `1de1d4869f8cea49ebebc9e54295057c62dee011`; the imported compiler and excluded adapter blobs are unchanged between those revisions.

| Origin surface | Classification | SDK disposition |
|---|---|---|
| `PhpCoreStmt`, `PhpCoreExpr`, `PhpCoreArrayEntry` | Generic PHP language IR | Imported, split into neutral `reflaxe.php.ir` modules |
| `emitPhpCore*`, array/call/new printers, quoting/indentation | Generic deterministic printer | Imported as `reflaxe.php.print.PhpPrinter` |
| typed-Haxe expression and statement lowering | Potentially generic, still mixed with `@:wp.*` intrinsics | Deferred to SDK-021 fixtures instead of copied wholesale |
| Reflaxe `GenericCompiler` registration and output driver | Generic direction, WPHX-specific flags/names today | Deferred until an exact Reflaxe pin and neutral driver fixture exist |
| class/function/file collection through `@:wp.*` metadata | WordPress application profile | Excluded from the generic package |
| `WphxPhpWordPressAdapters` | WordPress adapter registry and bodies | Entire file excluded |
| original paths, bootstrap policy, segment/template plans, ownership manifests | Full-port or WordPress profile behavior | Excluded |
| Core linker/replacement/distribution machinery | Full-port-only | Never a dependency of this repository |

The machine-readable [`provenance.json`](../../compiler/reflaxe.php/provenance.json) records source blobs/content hashes, transformations, exclusions, source license, and release blockers.

## Design references

For future registration, AST/lowering, printer, diagnostics, runtime, output-mode, fixture, and release decisions, consult the sibling `haxe.elixir.codex`, `haxe.ruby`, `haxe.go`, `haxe.rust`, `haxe.ocaml`, and `genes` compiler repositories. They are precedent, not dependencies or automatic copy sources. Any adapted implementation still needs a generalized rationale, exact provenance, and local regression evidence; repository-specific framework rules must not be copied into `reflaxe.php`.

SDK-027 specifically reviewed `haxe.ocaml` commit
`ef30eba09eff26c4ef09a8302f7cee84e23fc81c`. Its useful monorepo pattern is a
real package boundary, one canonical source artifact consumed by isolated
tests, and a large product in the same repository acting as a downstream
workload. WordPressHx adopts that pattern proportionately; it does not copy the
OCaml implementation, inherit its release system, or make `haxe.ocaml` a build
dependency.

## Package and extraction readiness

The package is independently movable without being prematurely moved. Its
package-owned gate constructs a deterministic source-only Haxelib ZIP twice,
requires byte-identical archives and manifests, and installs the exact archive
into a disposable local Haxelib repository. A neutral external Haxe
application then imports only the installed `reflaxe.php` API, emits readable
PHP, and executes that PHP. The negative half first proves the application
cannot resolve the library before installation, preventing a global
`haxelib dev` or checkout path from making the proof pass accidentally.

The artifact manifest records the source identity, archive identity, source
commit, dirty state, canonical timestamp, and explicit publication block. The
builder admits regular source files and package documentation only, rejects
machine-local paths and non-exact Haxelib dependencies, and includes a complete
file/hash manifest in the archive. CI requires a clean package worktree; local
development may test intentional edits but cannot call that result release
evidence.

This is deliberately not a repository split. WordPress-specific compiler work
continues in `compiler/wordpress` and SDK modules, where it can evolve at the
speed of the product. The generic package stays independently usable and owns
portable PHP/compiler behavior. The package-owned
[`EXTRACTION.md`](../../compiler/reflaxe.php/EXTRACTION.md) defines issue
routing, triggers, history/provenance transfer, immutable pins, downstream
receipts, and rollback for a later accepted ADR-004 extraction.

## First admitted slice

The initial import contains typed statements and expressions for control flow, arrays, calls, construction, properties, closures, references, casts, and common statements. SDK-021 extends that foundation with structural files, namespaces, functions, classes/interfaces/traits, properties, methods, PHP 7.4-compatible signature types, typed parameters, callable arrays, immutable relative source ranges, and deterministic rendered declaration ranges. SDK-026 adds optional native property types plus closed structured PHPDoc refinements for typed arrays and PHP 7.4-inexpressible unions. These are generalized IR facilities, not WordPress strings: validated names and types are constructed structurally, arrays are defensively copied, unions are normalized, comment injection fails closed, and documentation parameters must match the method signature. The printer retains output-compatible formatting from the proven source where practical, with general boundary improvements:

- raw PHP blocks are not part of the generic IR;
- identifiers and qualified names fail closed;
- magic constants and binary operators use allowlists;
- dollar signs are escaped when a PHP string requires double-quoted newline/tab rendering;
- caller-owned arrays cannot mutate validated declarations after construction;
- declaration ordering and stable names do not depend on traversal order.

The fixture is neutral: it compiles and prints a PHP program that sums a native array and emits JSON. It also snapshots representative closures, control flow, exceptions, arrays, names, and string escaping, plus negative injection-shaped inputs.

SDK-025 adds exact, content-authenticated source primitives without changing the
legacy one-based declaration-range view. The printer can record declaration,
member, and explicitly mapped statement spans as half-open UTF-8 byte ranges,
paired with stable semantic node IDs and optional emitter-owned line-trace
anchors. A neutral canonical writer receives its format identity from the
caller, preserving the generic package's WordPress isolation. Its multibyte
fixture proves byte/line/column agreement without a target-specific CLI.

## Public and private emission boundary

ADR-005 classifies generated PHP semantically at the file, symbol, and call-edge
level. Everything WordPress discovers or calls, every template/bootstrap file,
every intentionally exposed PHP facade, and every adapter into private logic is
`public-native` and must be emitted through structured PHP IR plus the WordPress
profile. Stock Haxe PHP cannot appear at that boundary.

Stock Haxe PHP is a provisional `0.x` implementation/migration lane only. A
private closure must be namespaced, dependency-closed within one generated
plugin/theme, unreachable by WordPress or non-Haxe PHP except through an
SDK-owned native adapter, and fully inventoried for files, symbols, helpers,
conversions, hashes, size, timing, conflicts, and source correlation. Unknown
classification or missing inventory rejects the build. Before the G8 API freeze,
runtime evidence must decide whether this lane becomes supported, migration-only,
or removed; it is not currently guaranteed after `1.0`.

The machine-readable contract is
[`php-emission-policy.json`](../../manifests/php-emission-policy.json). It keeps
all real WordPress/native ABI evidence `not-tested` until SDK-022 and Gate G1
exercise an ordinary PHP caller and a real WordPress 7.0 plugin.

SDK-022 now implements the first `compiler/wordpress` vertical slice without
changing the content-addressed generic compiler package. Typed profile values
produce an exact plugin header; generic IR produces the direct-access guard,
local autoload file, namespaced bootstrap class, and stable boot call. The
three-file `acme-books` fixture is byte-snapshotted, linted and invoked by an
ordinary PHP caller on exact PHP 7.4/8.4, then discovered and activated by real
WordPress 7.0 over both pinned database lanes. The artifact's JSON is explicitly
an internal SDK-022 evidence manifest, not the still-pending ADR-006 semantic
plan or ADR-007 ownership schema.

This advances only the bootstrap/profile slice. SDK-023 adds bounded hook,
REST, block, and export adapters; SDK-024 adds the dependency-closed private
stock-Haxe lane; and SDK-026 adds generated-PHP quality enforcement. Broader
lifecycle APIs, independent readability sign-off, HXX lowering, and production
support remain separate beads and claims.

## Generated-PHP quality transaction

SDK-026 makes correctness validation part of the Haxe-owned build transaction,
not project configuration. The CLI embeds the exact policy files, verifies the
installed tool bundle beside its executable byte-for-byte, writes the complete
in-memory emission into a private stage, and runs syntax lint, formatter
stability, WordPress Coding Standards and security sniffs, PHP 7.4
compatibility, PHPStan, duplicate-symbol, classmap, and autoload checks. A
failed check returns `WPHX3400`, redacts private paths, and never gives the
artifact owner publication authority.

Public native PHP uses WordPress 7.0 stubs and PHPStan level 6. Private
compiler-runtime PHP uses level 0 plus an authoritative declaration-matching
classmap; it is not reformatted or subjected to WordPress naming/layout rules.
Every exception is narrow, versioned, and justified in
[`toolchain.json`](../../tooling/php-quality/toolchain.json). Correctness,
compatibility, escaping/input/security, symbol, and autoload failures have no
waiver. A successful build owns a canonical `php-quality.json` whose file
hashes match the exact emission, and every emitted plugin artifact names
`wphx.plugin-php-quality` in the manifest-last ownership contract.

This is deliberately Haxe-first: ordinary projects write only their typed Haxe
declaration. They do not carry Composer, PHPCS, PHPStan, stub, or shell files.
The exact graph and standalone policy are documented in
[`tooling/php-quality`](../../tooling/php-quality/README.md).

## Planned typed-markup capability

ADR-011 makes server HXX a first-class generic compiler capability. A future `reflaxe.php` slice owns a neutral, typed PHP-markup IR for positioned elements/text, typed dynamic segments, attributes, control flow, output contexts, source correlation, and deterministic mixed PHP/HTML rendering. This replaces handwritten mixed PHP markup for Haxe-owned templates; it does not introduce a runtime parser, VDOM, component registry, template resolver, or request dispatcher.

The WordPress extension remains outside the generic package. `compiler/wordpress` plus the SDK HXX/server layer maps typed WordPress components—hierarchy/templates, loops/post fields, navigation, parts, nonces, admin/forms, blocks, media, i18n, and native helpers—onto the generic markup IR. Generic fixtures must remain neutral, and repository checks must reject WordPress symbols or profile branches in `compiler/reflaxe.php`.

```text
reflaxe.php typed markup IR/lowerer
                <- compiler/wordpress adapters
                <- SDK HXX/server abstractions
```

SDK-080 proves the pinned parser adapter. SDK-081 owns the generic markup and WordPress-extension implementation, independently gated, after SDK-052 establishes output-context security types. Browser HXX is not part of this lane; it continues through Genes.

## Evidence status

The package test passed with Haxe 4.3.7 and formatter 1.18.0. The generated namespaced file passes lint and runtime execution on exact PHP 7.4.33 and PHP 8.4.7 container images with output `{"total":14,"count":4,"error":"RuntimeException","label":"generic"}`. The fixture exercises native indexed/associative arrays, callable class-method arrays, a typed static method, a by-reference parameter and local alias, and native exception/catch behavior.

The official PHP images are pinned by multi-platform index digest, and runtime
containers execute with networking disabled. SDK-021 declaration records
preserve their legacy validated source ranges and generated lines. SDK-025 now
implements ADR-014's separate content-bound, half-open UTF-8 range maps, unique
line anchors, package source index, retention profiles, and offline PHP trace
CLI. The representative public/private failure plugin runs directly on exact
PHP 7.4/8.4 and as an activated WordPress 7.0 plugin over both database lanes;
eight development/packaged CLI traces preserve every native line and resolve
the four exact throw anchors.

The original source audit correctly found stale committed evidence rather than claiming a disposable regeneration as a clean pass. `wordpresshx-g1.1` reconciled the source-port evidence through reviewed [PR #1](https://github.com/fullofcaffeine/wordpresshx-port/pull/1) and added the missing closure receipt through [PR #2](https://github.com/fullofcaffeine/wordpresshx-port/pull/2). From a fresh detached checkout of the current authority, `npm ci --ignore-scripts`, `wphx:php:adoption-ci:check`, and `receipts:validate` pass without regeneration: 29 required checks, 28 included WPHX manifests, zero exclusions, and 493 closed tasks linked to 493 receipts.

The aggregate gate covers the five compiler areas that were directly stale in the first audit:

- core statement lowering;
- native array mutation;
- callable/closure/reference behavior;
- static and dynamic members;
- private emitter pilot, with its already-recorded exception-class gap.

The repair changed compiler/toolchain identities and their deterministic rollups only: the compiler source blob remains `b1b4a0148f3a774cbc4fd53efd6ddbddb8471c0c` with SHA-256 `f3d3b91024a9b3fc5450ef0790d0f111114397caf10d26823576dabb209da182`. Both source PRs passed all six PHP Conformance jobs, including deterministic and live-database lanes. No source-port checkout is a runtime or build input of this SDK.

The import and reconciliation outcomes are in [`SDK-020-REFLAXE-PHP-BOOTSTRAP`](../../manifests/evidence/sdk-020-reflaxe-php-bootstrap.json). The structural IR/printer and runtime-matrix evidence is in [`SDK-021-PHP-IR-PRINTER`](../../manifests/evidence/sdk-021-php-ir-printer.json). The bounded public WordPress bootstrap evidence is in [`SDK-022-WORDPRESS-PUBLIC-PHP-PROFILE`](../../manifests/evidence/sdk-022-wordpress-public-php-profile.json), exact PHP source-correlation evidence is in [`SDK-025-PHP-SOURCE-CORRELATION`](../../manifests/evidence/sdk-025-php-source-correlation.json), the staging quality gate is in [`SDK-026-GENERATED-PHP-QUALITY`](../../manifests/evidence/sdk-026-generated-php-quality.json), and the independently installed package seam is in [`SDK-027-GENERIC-PHP-COMPILER-READINESS`](../../manifests/evidence/sdk-027-generic-php-compiler-readiness.json).

## Current non-claims

The package does not yet claim:

- a Reflaxe compiler driver or arbitrary-Haxe compilation;
- complete typed-AST lowering;
- Haxe runtime/stdlib ownership;
- browser stack/source-map correlation or a production diagnostics handler;
- WordPress support beyond the bounded SDK-022 plugin bootstrap, general public
  ABI compatibility, or original-path emission;
- typed HXX/PHP-markup IR or mixed PHP/HTML lowering;
- publication eligibility.

SDK-021 establishes the structural IR/printer foundation through neutral
fixtures. SDK-025 supplies serialized PHP source correlation while preserving
the same generic boundary. SDK-022 begins the separate WordPress profile with a
native plugin bootstrap; SDK-023 and later beads own the representative public
callback surfaces and broader Gate G1 proof. SDK-034 owns browser correlation.
