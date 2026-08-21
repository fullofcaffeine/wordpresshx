# Changelog

All notable changes to the generic `reflaxe.php` package are recorded here.

The package remains an unpublished `0.0.0` workspace component. Entries under
`Unreleased` describe compiler changes without implying that a public release
has been authorized.

## Unreleased

- Added signed 32-bit wrap behavior for runtime `Int` addition and
  subtraction. The exact PHP profile now requires 64-bit PHP integers.
- Added signed 32-bit wrap behavior for runtime `Int` multiplication. Safe
  constant products still use readable native PHP multiplication.
- Added signed 32-bit wrap behavior for runtime unary `Int` negation. Safe
  constant negation still uses readable native PHP.
- Added runtime `Int` remainder when the divisor is a compiler-proven nonzero
  constant. Runtime and zero divisors remain rejected.
- Added truncating runtime `Int` division when the divisor is a compiler-proven
  nonzero constant. The compiler-owned helper preserves signed 32-bit overflow.
- Added strict equality and inequality for already typed `Bool` values. Null
  and mixed-type comparisons remain rejected.
- Added strict inequality for already typed `Int` values and source-owned
  `Int` predicates. Float and mixed-type comparisons remain rejected.
- Added strict inequality for already typed non-null `String` values and
  source-owned `String` predicates. Null and coercive comparisons remain
  rejected.
- Replaced the temporary monolithic compiler output with collision-safe
  per-type PHP artifacts and exact maps, a source-derived dependency-ordered
  bootstrap, the explicit `php74-modern-v1` policy, a content-addressed graph,
  and staged hash ownership that preserves unowned files and fails on drift.
- Added fixed `Array<Int>` literals and compiler-proven constant in-bounds
  reads; dynamic and out-of-bounds access remains rejected until an owned Haxe-
  compatible array runtime exists.
- Added the first ordinary-Haxe Reflaxe registration and typed-AST tracer:
  `Sys.println(String)` lowers through the generic PHP IR into deterministic,
  source-mapped, executable PHP without application-authored backend IR.
- Added a typed, generated semantic capability matrix and the first stock-Haxe
  differential slice for small `Int` addition, an initialized local, equality,
  and `if/else`, with PHP warnings and errors kept visible.
- Added required `Int` parameters and returns plus source-owned cross-module
  static calls, emitted as readable native PHP `int` signatures with focused
  optional/default, non-`Int`, and foreign-call rejection cases.
- Added explicit `Int` assignment, `Int <=`, and pre-test `while` lowering with
  stock-Haxe/native-PHP parity; compound assignment and `do-while` remain
  source-positioned failures.
- Added deterministic package-artifact construction and an isolated external
  Haxelib consumer proof.
- Added typed PHPDoc declarations, native typed properties, and the PHP
  `require`/`require_once` expression used by downstream profiles.
- Added authenticated source ranges, semantic node identities, trace anchors,
  and deterministic range-map writing.
- Established the typed PHP IR and deterministic PHP 7.4-compatible printer.
