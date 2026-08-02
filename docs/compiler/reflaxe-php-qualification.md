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
ordinary-Haxe path. Two Haxe modules lower through the generic PHP IR into one
mapped PHP file per type plus a dependency-ordered bootstrap, then execute under
native PHP. The checked semantic matrix currently covers small `Int` control
flow and calls, fixed proven `Array<Int>` reads, and exact UTF-8 String
concatenation/equality/printing plus required non-null String
parameters/returns and source-owned static String calls. Null arguments are
rejected before emission because ordinary non-null-safe Haxe and strict PHP do
not otherwise agree at that boundary. This establishes a useful compiler path;
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
