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

The current compiler surface is still an admitted typed-IR/printer slice. It
does not yet have a production Reflaxe driver, arbitrary typed-Haxe AST
lowering, a complete runtime/stdlib strategy, or an official Haxe-suite result.

[`manifests/reflaxe-php-qualification.json`](../../manifests/reflaxe-php-qualification.json)
locks the exact upstream Haxe source from which future qualification starts. It
records the candidate `unitstd`, issue, and hxcpp-issue source sets by their
sorted path/blob identities, plus the top-level cases registered by
`TestMain.hx`. Candidate presence is never a passing test result.

The active inventory can only be produced after the real compiler driver
exists. It must observe preprocessing, macro registration, target defines, and
capability selection. Every case then needs one of four explicit dispositions:

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

The real ordinary-Haxe tracer is tracked by `wordpresshx-reflaxe-php.2`; the
active official-suite execution is tracked by `wordpresshx-reflaxe-php.4`; and
eventual standalone packaging/extraction is tracked by
`wordpresshx-reflaxe-php.5`.
