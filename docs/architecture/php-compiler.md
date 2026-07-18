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

## First admitted slice

The initial import contains typed statements and expressions for control flow, arrays, calls, construction, properties, closures, references, casts, and common statements. SDK-021 extends that foundation with structural files, namespaces, functions, classes/interfaces/traits, properties, methods, PHP 7.4-compatible signature types, typed parameters, callable arrays, immutable relative source ranges, and deterministic rendered declaration ranges. The printer retains output-compatible formatting from the proven source where practical, with general boundary improvements:

- raw PHP blocks are not part of the generic IR;
- identifiers and qualified names fail closed;
- magic constants and binary operators use allowlists;
- dollar signs are escaped when a PHP string requires double-quoted newline/tab rendering;
- caller-owned arrays cannot mutate validated declarations after construction;
- declaration ordering and stable names do not depend on traversal order.

The fixture is neutral: it compiles and prints a PHP program that sums a native array and emits JSON. It also snapshots representative closures, control flow, exceptions, arrays, names, and string escaping, plus negative injection-shaped inputs.

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

The official PHP images are pinned by multi-platform index digest, and runtime containers execute with networking disabled. Declaration records preserve validated repository-relative Haxe ranges and exact generated start/end lines. SDK-025 owns serialization, content binding, nested expression/statement mappings, and the offline trace CLI; SDK-021 does not overstate these declaration records as a completed PHP source-map system.

The original source audit correctly found stale committed evidence rather than claiming a disposable regeneration as a clean pass. `wordpresshx-g1.1` reconciled the source-port evidence through reviewed [PR #1](https://github.com/fullofcaffeine/wordpresshx-port/pull/1) and added the missing closure receipt through [PR #2](https://github.com/fullofcaffeine/wordpresshx-port/pull/2). From a fresh detached checkout of the current authority, `npm ci --ignore-scripts`, `wphx:php:adoption-ci:check`, and `receipts:validate` pass without regeneration: 29 required checks, 28 included WPHX manifests, zero exclusions, and 493 closed tasks linked to 493 receipts.

The aggregate gate covers the five compiler areas that were directly stale in the first audit:

- core statement lowering;
- native array mutation;
- callable/closure/reference behavior;
- static and dynamic members;
- private emitter pilot, with its already-recorded exception-class gap.

The repair changed compiler/toolchain identities and their deterministic rollups only: the compiler source blob remains `b1b4a0148f3a774cbc4fd53efd6ddbddb8471c0c` with SHA-256 `f3d3b91024a9b3fc5450ef0790d0f111114397caf10d26823576dabb209da182`. Both source PRs passed all six PHP Conformance jobs, including deterministic and live-database lanes. No source-port checkout is a runtime or build input of this SDK.

The import and reconciliation outcomes are in [`SDK-020-REFLAXE-PHP-BOOTSTRAP`](../../manifests/evidence/sdk-020-reflaxe-php-bootstrap.json). The current IR/printer and runtime-matrix evidence is in [`SDK-021-PHP-IR-PRINTER`](../../manifests/evidence/sdk-021-php-ir-printer.json).

## Current non-claims

The package does not yet claim:

- a Reflaxe compiler driver or arbitrary-Haxe compilation;
- complete typed-AST lowering;
- Haxe runtime/stdlib ownership;
- serialized source maps, trace CLI, or production diagnostics;
- WordPress support, public ABI compatibility, or original-path emission;
- typed HXX/PHP-markup IR or mixed PHP/HTML lowering;
- publication eligibility.

SDK-021 establishes the structural IR/printer foundation through neutral fixtures. SDK-025 owns serialized source correlation, and the WordPress profile begins separately under SDK-022 after the public/private emission decision.
