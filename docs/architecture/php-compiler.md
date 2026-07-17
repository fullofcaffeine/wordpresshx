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

The initial package contains typed statements and expressions for control flow, arrays, calls, construction, properties, closures, references, casts, and common statements. The printer retains output-compatible formatting from the proven source where practical, with four general boundary improvements:

- raw PHP blocks are not part of the generic IR;
- identifiers and qualified names fail closed;
- magic constants and binary operators use allowlists;
- dollar signs are escaped when a PHP string requires double-quoted newline/tab rendering.

The fixture is neutral: it compiles and prints a PHP program that sums a native array and emits JSON. It also snapshots representative closures, control flow, exceptions, arrays, names, and string escaping, plus negative injection-shaped inputs.

## Evidence status

The package test passed with Haxe 4.3.7 and formatter 1.18.0. The generated program passed PHP 8.4.7 lint and runtime execution with output `{"total":6,"label":"generic"}`.

PHP 7.4 is `not-tested`, not passed. The installed Homebrew PHP 7.4.33 binary cannot start because its `libaspell.15.dylib` dependency is absent; the containerized PHP 7.4 matrix remains a scoped SDK-021 requirement rather than part of this provenance-only reconciliation.

The original source audit correctly found stale committed evidence rather than claiming a disposable regeneration as a clean pass. `wordpresshx-g1.1` reconciled the source-port evidence through reviewed [PR #1](https://github.com/fullofcaffeine/wordpresshx-port/pull/1) and added the missing closure receipt through [PR #2](https://github.com/fullofcaffeine/wordpresshx-port/pull/2). From a fresh detached checkout of the current authority, `npm ci --ignore-scripts`, `wphx:php:adoption-ci:check`, and `receipts:validate` pass without regeneration: 29 required checks, 28 included WPHX manifests, zero exclusions, and 493 closed tasks linked to 493 receipts.

The aggregate gate covers the five compiler areas that were directly stale in the first audit:

- core statement lowering;
- native array mutation;
- callable/closure/reference behavior;
- static and dynamic members;
- private emitter pilot, with its already-recorded exception-class gap.

The repair changed compiler/toolchain identities and their deterministic rollups only: the compiler source blob remains `b1b4a0148f3a774cbc4fd53efd6ddbddb8471c0c` with SHA-256 `f3d3b91024a9b3fc5450ef0790d0f111114397caf10d26823576dabb209da182`. Both source PRs passed all six PHP Conformance jobs, including deterministic and live-database lanes. No source-port checkout is a runtime or build input of this SDK.

The exact outcomes and package content digest are in [`SDK-020-REFLAXE-PHP-BOOTSTRAP`](../../manifests/evidence/sdk-020-reflaxe-php-bootstrap.json).

## Current non-claims

The package does not yet claim:

- a Reflaxe compiler driver or arbitrary-Haxe compilation;
- complete typed-AST lowering;
- Haxe runtime/stdlib ownership;
- source maps or production diagnostics;
- PHP 7.4 evidence;
- WordPress support, public ABI compatibility, or original-path emission;
- publication eligibility.

SDK-021 grows the generic IR/driver only through neutral fixtures. The WordPress profile begins separately under SDK-022 after the public/private emission decision.
