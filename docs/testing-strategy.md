# Behavior-first testing strategy

WordPressHx has several products in one repository. A generated PHP fixture, a
real WordPress installation, a Gutenberg browser flow, and a deterministic ZIP
can all be green while proving different things. This strategy makes those
differences explicit so a failure is easier to diagnose and a narrow success
cannot be reported as broader compatibility.

The checked authority is
[`manifests/testing-strategy.json`](../manifests/testing-strategy.json). Validate
it with:

```bash
python3 scripts/testing/strategy.py validate
python3 scripts/testing/strategy.py self-test
```

The design is an incremental adoption of the verified
`consolidated-testing` `2026-07-31-v3` reference. The reference informs this
repository; it is not a runtime, build, release, or floating sibling dependency.
Existing test runners and hosted workflows remain authoritative for what they
actually execute.

## The practical workflow

For a meaningful bug fix or behavior change:

1. Describe a concrete scenario: starting conditions, action or compilation
   path, observable result, edge or error behavior, owning product surface, and
   protected claim.
2. Choose the smallest test that can still observe the defect. Demonstrate that
   it is red for the expected reason before the implementation changes.
3. State where the expected result comes from. A specification, manually
   reviewed minimum, pinned upstream implementation, invariant, or real native
   consumer can be an oracle. The production code under test cannot generate
   its own expectation.
4. Make the focused owner green and refactor.
5. Run one narrow real path across the important generated-language or
   framework boundary. This path is the tracer bullet.
6. Run the broader scorecard owners affected by the change. Retain a compact
   system or browser regression when it protects a real public behavior.
7. For compiler representation, runtime, ABI, package publication, security,
   migration, or claim changes, perform a review pass distinct from the
   implementation. Record findings and dispositions.

A separate red commit is optional. The Bead or durable implementation note must
retain the pre-fix command and concise intended failure. When scaffolding has no
natural red state, use a controlled mutation or document why sensitivity has to
be proven another way.

## Independent product surfaces

These five scorecards are intentionally separate. Their full fields, owners,
profiles, oracles, last clean proofs, skips, and residual risks live in the
machine-checked manifest.

Owner membership is reciprocal: an owner that declares a surface must appear
in that scorecard, and no scorecard may borrow an owner that declares a
different surface. Each clean proof names its exact workflow, job, run, commit,
and covered owners. An owner without matching proof is listed explicitly under
`unprovenOwners`; today the complete scaffolded plugin install owner remains
unproven for the WordPress/package/migration scorecards rather than borrowing
the narrower example or compiler jobs.

| Surface | Current evidence | Current limit |
| --- | --- | --- |
| `compiler-adapter` | Typed generic PHP IR/printer fixtures, an ordinary-Haxe → custom Reflaxe driver → mapped PHP → native PHP tracer, a typed semantic matrix with a stock-Haxe/PHP numeric-control-flow differential, clean package consumer, WordPress emitter fixtures, and bounded contract/output adapters | The real driver path admits only the matrix’s exact records; runtime/stdlib breadth and official Haxe target qualification remain unproved |
| `wordpress-runtime-abi` | Exact PHP lanes plus clean WordPress 7.0/MySQL/MariaDB activation, hook, filter, REST, block, reflection, reference, and error observations | No general WordPress compatibility, version range, theme, full-site, or production claim |
| `package-install` | Deterministic internal compiler/plugin packages, ownership replay, and two generated showcase plugins installed on WordPress | No public SDK package, theme/full-site package, upgrade/uninstall matrix, notices, or release proof |
| `gutenberg-browser` | Strict Genes output, real Gutenberg editor and data registry, compact Chromium flows, accessibility, focus, and fatal-error checks | No general Gutenberg, Interactivity API, browser matrix, or production claim |
| `migration-downstream` | Profile/generated-output mutations, static-block migration, and bounded adoption/downstream fixtures | No production adoption generator, real provider portfolio, or broad downstream compatibility |

Official Haxe target qualification applies only to the actual compiler-facing
surface. WordPress, package, or browser success cannot substitute for a custom
Haxe-to-PHP compiler result. Conversely, a future regular-Haxe compiler result
will not prove WordPress ABI, installation, or Gutenberg behavior.

## Test layers and the double lock

The lowest faithful layer means the cheapest layer that still contains the
failure being protected:

- Static checks own formatting, strict types, closed schemas, manifests,
  freshness, workflow policy, security, and release blockers. They sit outside
  any focused/integration/E2E ratio.
- Focused owners diagnose parsers, macros, validation, lowering, emitters,
  diagnostics, codecs, source mapping, and deterministic contracts.
- Vertical owners compile authored Haxe, generate native output, run the target
  check/build, cross the package or framework boundary, and observe the real
  runtime.
- System and browser owners exist only when installation, process behavior,
  WordPress, Gutenberg, or the browser is the lowest faithful observer.

When a WordPress or browser test exposes a compiler/generator defect, preserve
the real-boundary proof and add a focused deterministic owner where one exists.
The focused test answers “which rule broke?” while the vertical test answers
“does generated output cross the real boundary?” A user-visible E2E remains
only when it protects a distinct user promise.

The first ordinary-Haxe PHP tracer follows this rule directly. Its manually
reviewed PHP/stdout minimum and independent range-map reader diagnose lowering
and correlation, while native `php -l` and execution retain the real boundary.
Its owner remains explicitly unproven by hosted evidence until a clean workflow
runs the exact command; local green evidence does not borrow an older typed-IR
or WordPress proof.

The incremental runtime owner extends that path without changing the claim
model. `semantic-capabilities.json` is regenerated from a typed compiler-owned
registry and currently lists 15 admitted, 6 explicitly unsupported, and 7
unverified capabilities across 13 categories. Its differential fixture checks
small `Int` addition, an initialized local, equality, `if/else`, required `Int`
parameters/returns, and a source-owned cross-module static call under both stock
Haxe 4.3.7 and exact PHP 8.4.7. Empty PHP stderr is part of the contract, so
warnings and fatals cannot be retried or normalized away. Optional/default and
non-`Int` signatures plus foreign calls are compile-negative owners and publish
no partial PHP.

Mocks are useful when the mocked component is not the claim. A mock that removes
WordPress bootstrap, PHP reference semantics, package installation, Gutenberg
state, or browser behavior cannot prove that boundary.

## Representative behavior-first workflow

The ADR-009/ADR-012 JSON repair is the first durable example because it was a
real regression, not a code change invented to demonstrate process.

### Scenario and red state

- Preconditions: a non-strict or foreign caller can provide a typed `WireValue`
  to the final JSON sink, including malformed shapes and exact nesting limits.
- Action: the codec returns a value, the checked encoder validates and snapshots
  it, and `OutputSinks` creates the terminal plan.
- Required result: every modeled success must decode under PHP
  `JSON_THROW_ON_ERROR` and JavaScript `JSON.parse`.
- Edge result: public raw-success construction, 65 nested containers, invalid
  Unicode, null/malformed values, duplicates, cycles, and unsupported domains
  reject without bytes or an escaping exception.
- Protected claim: within this bounded prototype, successful JSON bytes have
  one sink-owned construction path and are accepted by both native decoders.

At reviewed commit `0e01ab5e18fe023e43f2d45e1052bdccef658f05`,
`JsonPlan.success(schemaId, encoded)` was public. The negative fixture did not
exist in that historical tree, so the controlled sensitivity replay copies the
current fixture unchanged over the historical source and compiles it with the
same classpath. That subject exits zero; the current tree exits one with
`JsonPlan has no field success`. Run the exact proof with:

```bash
bash scripts/testing/reproduce-json-plan-red.sh
```

The imported-fixture, historical source, current source, script, command,
outputs, and independent-review hashes are retained in
[`testing-strategy-json-red-proof.json`](../manifests/evidence/testing-strategy-json-red-proof.json).
The earlier
[`ORACLE-REREVIEW.md`](../review/oracle/results/adr012-f004-rereview-0e01ab5/ORACLE-REREVIEW.md)
is the independent finding and negative-test design; it is not represented as
if it had executed the later overlay.

A full checkout validates that historical source and tree before accepting the
receipt. A deliberately shallow CI checkout retains the exact receipt identity
without claiming it replayed unavailable history; a complete checkout missing
the subject fails closed.

### Oracle and tracer bullet

The expectation is independent of the checked encoder. Manually authored
boundary vectors are decoded by PHP and JavaScript's native JSON parsers; React
and WordPress consume the resulting plan at their native sinks. The tracer is:

```text
Haxe TodoCard codec
  -> WireValue
  -> CanonicalWireJson.encodeChecked
  -> private JsonPlan
  -> generated native plan
  -> PHP, JavaScript, WordPress, and React observers
```

The focused owner is the contracts boundary corpus plus compile-negative
fixtures. `bash scripts/output-context/test.sh` retains the real cross-target
boundary. The repair is implemented and hosted gates pass, but
`wordpresshx-g4.1.1` remains open until a fresh content-addressed independent
rereview accepts the corrected commit. This workflow does not authorize
publication or broaden the prototype claim.

## Feedback rings

The rings describe who owns evidence and when it should run. They do not create
a second test implementation or imply that the current topology is already
optimized.

| Ring | Current owner | Initial observed state |
| --- | --- | --- |
| R0 focused/editor | The active semantic owner selected from the manifest | Contract architecture first/repeat sample: 0.10s/0.04s |
| R1 local smoke | A representative surface tracer, normally the focused owner followed by its real vertical | WordPress PHP emitter/native caller first/repeat: 3.07s/2.49s |
| R2 required pull request | All current required workflow jobs plus the repository bootstrap | Local repository policy first/repeat: 86.82s/71.35s; hosted topology currently runs every workflow |
| R3 affected extended | Exact WordPress, browser, package, adoption, and platform owners selected by risk | Not yet separated from R2; individual workflows are manually dispatchable |
| R4 main full | Every current-primary hosted workflow on each `main` push | Clean baseline critical path: 905s; Haxe 904s and WordPress runtime 709s |
| R5 release | Clean final artifact, consumer install, and every claimed exact matrix | Withheld; the release-policy command proves publication remains blocked, not that a release works |

These are single samples, not p50/p95 measurements or budgets. The local full
output-context run reached its Haxe/Genes/React proof, then was stopped after
the local Docker daemon did not enter the WordPress lane. The clean hosted
Output-context workflow completed in 98s and is the complete-system baseline
for that environment.

After the strategy change and its shallow-history portability correction, the
same local R0/R1/R2 first/repeat commands measured 0.07s/0.05s,
2.66s/2.50s, and 107.51s/79.23s. The spread is retained as observation rather
than presented as an optimization result.

They are also deliberately called first invocation and immediate repeat—not
“cold” and “warm.” The repository did not have a controlled pre-change
cache/artifact reset protocol, and inventing one after the measurement would
not make the historical sample cold. `wordpresshx-sdk-plan.3.6` owns controlled
cold/warm, p50/p95, and cache/artifact-separated observation. No CI topology is
changed while that evidence is absent.

The current R2/R4 topology is evidence-heavy but safe: no affected selector can
skip a job. Optimization begins with attribution and observation, not removal.

## Affected-test selection

The selector maps paths to semantic owners and product surfaces, then expands
declared reverse dependencies. It always selects the strategy contract and
repository sentinel. Unknown, unsafe, selector, workflow, release, or
cross-cutting changes select the entire mapped portfolio.

Explain a known change:

```bash
python3 scripts/testing/strategy.py select \
  --changed compiler/reflaxe.php/src/reflaxe/php/Printer.hx
```

Explain a real branch diff:

```bash
python3 scripts/testing/strategy.py select --base origin/main --json
```

Selection is observation-only. It cannot authorize skipping any current pull
request or main job. Promotion requires recorded selected/omitted decisions,
full-backstop comparisons, zero unresolved selector misses for an accepted
observation window, a required aggregator, and owner review. Until then, all
current workflows remain the backstop.

## Executable examples

Examples are QA assets only at the tier they execute:

- Tier A, flagship application: compile/generate, strict target checks, package
  resolution, production build, process boot, runtime smoke, and compact
  distinctive E2E.
- Tier B, capability showcase: compile/build/run and one distinctive
  system/browser assertion when runtime behavior is advertised.
- Tier C, compile-only snippet: compile/typecheck only; never runtime evidence.

The editor sidebar and Todo data-store lab are Tier B capability showcases.
Their full commands install generated plugins into exact WordPress 7.0 and run
distinctive browser flows. The `--skip-wordpress` variants are faster build
owners and cannot replace the advertised runtime proof. Todo Studio remains a
planned Tier A flagship; the in-memory data-store lab cannot borrow that claim.

## Oracles, snapshots, and generated artifacts

Every new or materially changed expectation names its authority in the Bead,
fixture manifest, or evidence receipt. Strong sources include:

- pinned public WordPress, PHP, Gutenberg, Haxe, or package behavior;
- a manually authored minimal expectation reviewed for meaning;
- a pinned differential implementation;
- an invariant such as byte-identical clean replay or round trip;
- a previously accepted content-addressed artifact; or
- a real independent consumer.

Do not update a snapshot only because generation changed. First classify the
semantic difference, identify the independent oracle, and run the strict target
or real runtime owner. Expected WordPress globals, includes, references, and
public ABI shapes must come from pinned upstream/public behavior or independent
native fixtures, not from the generated output being checked.

## Failures, retries, and quarantine

Deterministic compiler, target check, PHP warning/fatal, WordPress error, test
assertion, and browser console/page/request failure exits nonzero on its first
attempt. Automatic retries may not turn it green. A diagnostic retry is allowed
only for a plausibly infrastructural or nondeterministic failure and must retain
the original attempt.

There are no strategy-recognized quarantines today. A future quarantine needs a
stable test ID, owner, Bead, reason, first/last failure evidence, expiry,
nonblocking execution lane, and nonpassing claim contribution. A quarantine is
never a compatibility pass.

Recent workflow success/failure counts are development history, not a flake
rate: the repository does not yet classify failures by cause. Selector misses,
unique failure yield, diagnosis time, E2E-to-focused conversion, retry state,
and comparable cold/warm p50/p95 samples remain follow-up telemetry.

## Claims and remaining work

This strategy justifies evidence attribution, Tier B example classification,
and fail-safe advisory selection. It does not broaden any compiler, WordPress,
package, browser, migration, release, or production-support claim.

Deferred work remains in the owning Beads:

- `wordpresshx-sdk-plan.3`: the shortest complete Haxe-only WordPress product
  vertical and future Tier A flagship evidence;
- `wordpresshx-g4.1.1`: fresh independent acceptance of the JSON boundary
  repair;
- `wordpresshx-g6.1` and `wordpresshx-sdk-072`: production adoption and
  downstream contracts;
- `wordpresshx-sdk-plan.2`: final artifact licensing, notices, and publication
  authority; and
- `wordpresshx-sdk-plan.3.6`: selector observation, causal failure
  classification, comparable p50/p95 timings, diagnosis time, and any future
  promotion decision.
