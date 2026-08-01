# Changelog

All notable changes to the generic `reflaxe.php` package are recorded here.

The package remains an unpublished `0.0.0` workspace component. Entries under
`Unreleased` describe compiler changes without implying that a public release
has been authorized.

## Unreleased

- Added the first ordinary-Haxe Reflaxe registration and typed-AST tracer:
  `Sys.println(String)` lowers through the generic PHP IR into deterministic,
  source-mapped, executable PHP without application-authored backend IR.
- Added a typed, generated semantic capability matrix and the first stock-Haxe
  differential slice for small `Int` addition, an initialized local, equality,
  and `if/else`, with PHP warnings and errors kept visible.
- Added deterministic package-artifact construction and an isolated external
  Haxelib consumer proof.
- Added typed PHPDoc declarations, native typed properties, and the PHP
  `require`/`require_once` expression used by downstream profiles.
- Added authenticated source ranges, semantic node identities, trace anchors,
  and deterministic range-map writing.
- Established the typed PHP IR and deterministic PHP 7.4-compatible printer.
