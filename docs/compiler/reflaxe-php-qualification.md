# Reflaxe.PHP qualification contract

WordPressHx is developing the generic PHP compiler in this monorepo first. A
standalone repository is a low-priority extraction outcome, not a prerequisite
for useful compiler or WordPress work. The dependency direction remains:

```text
compiler/reflaxe.php <- compiler/wordpress <- WordPressHx SDK
```

The generic package must not import WordPress concepts. The downstream profile
may use the generic compiler.

## What is qualified today

The compiler now has a real Reflaxe registration and a deliberately bounded
ordinary-Haxe path. Three Haxe modules lower through the generic PHP IR. The
compiler writes one mapped PHP file per type and a dependency-ordered
bootstrap. Native PHP then runs those files. The checked semantic matrix covers
small `Int` control flow and calls. It also covers fixed proven `Array<Int>`
reads and length. The String subset covers exact UTF-8 concatenation, equality,
inequality, `<`, `<=`, and `>` ordering, and printing. It includes required non-null
String parameters and returns for source-owned static calls and predicates.
String `<`, `<=`, and `>` ordering uses `strcmp`, not direct PHP comparison. This
preserves lexical ordering for numeric-looking Strings and multi-byte UTF-8
values. String `>=` remains unqualified. Exact non-null
`String.length` lowers through an on-demand compiler-owned PHP runtime helper
with Unicode-scalar semantics and no `mbstring` dependency. The helper's
artifact, dependency edge, ownership record, and source map are part of the
same clean-room vertical; malformed UTF-8 is rejected explicitly. This does not
qualify nullable receivers, indexing, substring, normalization, grapheme
behavior, other String operations, or a general Haxe runtime. Exact array
length lowers to PHP `count` only for a proven compiler-owned `Array<Int>`
local. Other arrays and general collection behavior remain unqualified. The matrix also covers exact
Bool literals/locals, logical negation, direct conditions, required non-null
Bool parameters/returns, source-owned static Bool calls, and lazy `&&`/`||`
with typed parenthesized grouping, without PHP truthiness. Null arguments are
rejected before emission because ordinary non-null-safe Haxe and strict PHP do
not otherwise agree at that boundary. One explicit nullable subset admits only
`Null<String>` locals initialized from `null` or an admitted String, required
source-owned `Null<String>` parameters and calls, and `== null` / `!= null`
checks. It lowers to PHP 7.4-compatible `?string`, native `null`, and strict
identity checks. Other nullable types, mutation, optional/default parameters,
foreign callers, dereference/flow narrowing, and general null semantics remain
unqualified. A unary source-owned `Null<String> -> Null<String>` identity and
call additionally prove PHP `?string` return typing and nullable-return local
initialization; multiple parameters, other nullable return domains, and broader
nullable expressions remain unqualified. The admitted object subset adds one
non-inherited class with a private typed
`String` field, constructor-only initialization, a required `String`
constructor and instance method, native construction, and an instance call.
The admitted callback subset adds a required unary `String -> String` closure,
read-only lexical `String` capture by value, direct invocation, native PHP
`string` signature types, and exact mapping for both the closure declaration
and its body. The admitted exception subset adds one immediate
`throw new haxe.Exception(String)` with one exact `haxe.Exception` catch and a
typed caught-message read, lowered to `RuntimeException` and `getMessage()`.
Mutable fields, inheritance, interfaces, overrides, accessors, nullable object
values, mutable/non-String captures, nested or escaping closures, multiple or
nested try blocks, other thrown/caught types, finally, rethrow, and broad
object/function/exception semantics are not qualified. This establishes a useful compiler path;
it does not imply arbitrary typed-Haxe lowering, a complete
runtime/standard-library strategy, an external weak-PHP ABI claim, or an
official Haxe-suite result.

[`manifests/reflaxe-php-qualification.json`](../../manifests/reflaxe-php-qualification.json)
locks the exact upstream Haxe source from which future qualification starts. It
records the candidate `unitstd`, issue, and hxcpp-issue source sets by their
sorted path/blob identities, plus the top-level cases registered by
`TestMain.hx`. Candidate presence is never a passing test result.

The tracer is not the active official-suite inventory producer. That inventory
must be added as a source-derived compiler facility that observes
preprocessing, macro registration, target defines, and capability selection.
Every case then needs one of four explicit dispositions:

- active and applicable;
- adapted with an exact patch and rationale;
- unsupported with an owner and follow-up;
- target-inapplicable with a semantic rationale.

An inactive branch, dummy assertion, omitted file, or unowned skip cannot count
as a pass.

## Independent evidence

The compiler scorecard accepts the pinned Haxe expectations and language
semantics, manually reviewed minimal PHP expectations, and native PHP parser and
runtime observations as independent oracles. Generated output cannot generate
its own expectation.

WordPress activation, packaging, Gutenberg, browser, and migration evidence
remain separate scorecards. They cannot advance an official Haxe compiler
claim, and compiler conformance cannot advance their claims.

## Commands

Run the closed local contract and its mutation corpus:

```bash
python3 scripts/compiler-qualification/qualification.py validate
python3 scripts/compiler-qualification/qualification.py self-test
```

When an exact Haxe checkout containing the pinned commit is available, verify
that the checked-in contract regenerates byte-for-byte from upstream source:

```bash
python3 scripts/compiler-qualification/qualification.py validate --upstream ../haxe
```

Regeneration is an explicit maintenance action:

```bash
python3 scripts/compiler-qualification/qualification.py generate --upstream ../haxe
```

The ordinary-Haxe tracer is implemented under `wordpresshx-reflaxe-php.2`; the
active official-suite execution is tracked by `wordpresshx-reflaxe-php.4`; and
eventual standalone packaging/extraction remains low priority under
`wordpresshx-reflaxe-php.5`.
