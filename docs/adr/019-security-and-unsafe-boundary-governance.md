# ADR-019: Security and unsafe-boundary governance

- Status: proposed; independent Oracle review required
- Date: 2026-07-26
- Owners/reviewers: Marcelo Serpa (product owner and accountable security/release owner), Codex (policy and executable-fixture implementation), independent security Oracle (acceptance pending)
- Bead: `wordpresshx-adr-019`
- Profiles/layers: maintained Haxe, generated PHP/JavaScript/TypeScript, profile/adoption contracts, compiler target segments, artifact manifests, security evidence, and release gates
- Supersedes: informal waiver descriptions in the PRD and earlier ADRs
- Superseded by: none

## Context

WordPressHx deliberately removes routine weak and raw boundaries. Maintained
Haxe must use concrete types; generated public PHP and TypeScript must preserve
precise contracts; HXX must lower through context-specific terminals; provider
adoption must be precise or omitted. That default is stronger than recording
unsafe code after the fact.

Some native or compiler APIs can nevertheless be genuinely open. A provider may
publish an opaque callback payload, a compiler may need one narrowly isolated
target segment, or an experimental upstream API may have no stable public
contract. Hiding such cases behind a broad type or an untracked generated
fragment would make the SDK appear safer than it is. Merely attaching the word
“waiver” is also insufficient: a stale waiver can outlive its source, move into
a public API, disappear from a final artifact, or be renewed indefinitely.

The PRD therefore requires every durable unsafe use to carry an ID, reason,
boundary, owner, expiry, evidence, and removal gate; CI must inventory weak Haxe,
raw PHP/JavaScript, TypeScript openness, private APIs, unchecked external
contracts, unsafe profile entries, and generated raw target segments. ADR-008
already says an `unsafe` classification never becomes supported while it
remains unsafe. ADR-012 withholds a raw-output constructor until this governance
exists. ADR-021 requires an unsafe inventory before release and separately
blocks stable publication today.

This ADR decides the governance and prototype validation model. It does not
publish an unsafe Haxe API, implement the production source/generated scanners,
or authorize a stable release.

## Decision

### Safety remains the default; a waiver is not a type

The default disposition of every detected or declared unsafe boundary is
`blocked`. A waiver is a temporary, visible exception to one exact boundary. It
does not:

- turn a raw or opaque value into a safe output-context value;
- establish validation, sanitization, authorization, escaping, or support;
- allow weak Haxe in a public API, application source, recommended example, or
  routine HXX expression;
- authorize an unknown category, detector, source, scope, or artifact;
- override a critical/high vulnerability stop;
- transfer evidence to another profile, provider, package, target, source hash,
  generated artifact, or SDK release.

The strict repository Haxe rule remains controlling. `Dynamic`, `Any`, `cast`,
`Reflect`, and `untyped` are prohibited. Only when an external/compiler API
makes a typed implementation genuinely impossible after typed alternatives are
exhausted may a minimal generated-interop-internal boundary be considered. It
still requires the inline invariant required by `AGENTS.md`, an opaque typed
facade or decoder, this ADR's inventory and waiver, and compiler/runtime
evidence. A waiver cannot make that exception routine.

### Closed boundary categories

The policy has nine categories:

| Category | Ordinary treatment | Stable-package treatment |
|---|---|---|
| `haxe-weak-type` | Block; only a minimal generated interop internal may be reviewed | Current waiver, immediate typed facade/decoder, independent security review, and no public/example/application exposure |
| `php-raw-segment` | Block; only a compiler/generated private adapter may be reviewed | Current waiver, exact source/generated mapping, independent review |
| `javascript-raw-segment` | Same as PHP raw segments | Same as PHP raw segments |
| `generated-raw-target` | Block unless the semantic emitter declares and maps the segment | Current waiver, artifact mapping, independent review |
| `typescript-any` | Block; compiler loss is a Genes defect, not an SDK workaround | Only exact upstream openness narrowed immediately inside generated interop, with current waiver and independent review |
| `typescript-unknown` | Inventory at a real foreign boundary and require decoder evidence | May ship without a waiver only when it remains at the boundary and is decoded before domain use |
| `private-upstream-api` | Experimental opt-in or generated private adapter only | Never stable while private |
| `profile-unsafe-entry` | Experimental opt-in only | Never stable while classified unsafe |
| `unchecked-external-contract` | Block or experimental/generated interop with exact adoption provenance | Never stable while unchecked |

Unknown categories and detectors fail closed. Adding a new native-emission kind
or detector requires a policy change and review; it cannot silently fall into a
generic raw bucket.

### Exact waiver record

[`unsafe-boundary-waiver.schema.json`](../../schemas/unsafe-boundary-waiver.schema.json)
is the closed waiver record. Every waiver binds:

- `WPHX-UNSAFE-NNNN` and one stable `UB-*` boundary ID;
- one closed category, reason, accountable owner, and independently recorded
  approval;
- exact creation, review, expiry, and removal deadline instants in UTC;
- risk severity, threat, and mitigation;
- repository-relative source path, full-file SHA-256, and line range;
- package/layer, exact profiles, and target scope;
- at least one content-addressed evidence file;
- one removal Bead and a testable success condition.

The reviewer differs from the owner. A content-addressed independent Oracle
agent acting in the relevant security/compiler expert role is an allowed
reviewer; this policy never forces a manual human review gate. The accountable
owner remains a named human or maintainer role because an automated reviewer
cannot own release response or removal work.

An initial waiver lasts at most 90 days. Its removal deadline cannot exceed its
expiry. “Before 1.0,” “next release,” and other relative dates are invalid. A
renewal is a new waiver ID, source binding, evidence packet, review, expiry, and
removal decision; prior approval is not inherited.

### Lifecycle is evaluated, not asserted

A waiver is active only when all of these are true at the gate's recorded UTC
instant:

1. its independent approval is valid;
2. evaluation precedes expiry;
3. category and scope match the detected boundary;
4. the exact source and evidence hashes match;
5. its removal Bead is open or in progress;
6. risk remains below high;
7. every required artifact mapping and decoder/facade proof exists.

Expired, revoked, source-drifted, and scope-drifted waivers fail every build,
not only release builds. Supersession is additive: historical records and
receipts remain immutable, while the new record names its own identity.

### One reconciled inventory, three observations

Compiler/macro declarations and independent detectors produce findings. They
must reconcile one-to-one into a closed source inventory. A finding without a
record is `WPX1901`; a record without a current finding is `WPX1902`. Duplicate
IDs or locations, unknown categories/detectors, and missing fields also block.
A reviewed false positive remains visible as a reviewed inventory record rather
than becoming an invisible scanner suppression.

The build retains three related but non-interchangeable observations:

1. source inventory: authored/compiler boundary and exact source binding;
2. generated inventory: exact emitted segments/declarations and source boundary
   IDs;
3. final-artifact inventory: only boundaries actually shipped, with artifact,
   source, evidence, and current waiver digests.

Every generated boundary maps back to a source boundary ID. Every final plugin,
theme, block, browser package, or SDK archive carries the relevant boundary and
waiver identities in its build manifest. Source-clean does not imply
artifact-clean, and a stale source record cannot justify bytes that no longer
map to it.

Inventories group by package, category, owner, and release-blocker state. They
are evidence inputs, not documentation-only reports.

### Gate behavior and diagnostics

Development/build gates reconcile detectors and inventory and reject missing,
expired, revoked, drifted, out-of-scope, or prohibited records. Package gates
also reconcile source/generated inventories, require a complete final-artifact
inventory, authenticate waiver/evidence digests, and reject high/critical risk.

A stable-release gate additionally requires:

- the category to permit a bounded current waiver;
- a reviewed inventory diff;
- current independent security review for each category that requires it;
- no critical/high known vulnerability in shipped supported scope;
- a current independent external security review for authentication,
  authorization, SQL, HTML, JavaScript, update, or install generators;
- ADR-021's unsafe-inventory release requirement to pass.

The stable gate does not override ADR-020 licensing blockers, ADR-021 operational
blockers, G8 evidence, or capability-ledger status.

Stable diagnostic ownership is:

| Code | Meaning |
|---|---|
| `WPX1901` | detected boundary missing from inventory |
| `WPX1902` | stale inventory record without a detection |
| `WPX1903` | required waiver missing |
| `WPX1904` | waiver expired, revoked, superseded, or otherwise non-current |
| `WPX1905` | source/evidence digest drift |
| `WPX1906` | scope/category mismatch |
| `WPX1907` | boundary appears in a prohibited scope |
| `WPX1908` | owner self-approved |
| `WPX1909` | invalid, relative, reversed, or overlong expiry/removal dates |
| `WPX1910` | generated/final artifact mapping missing |
| `WPX1911` | risk/category release stop |
| `WPX1912` | decoder or independent review evidence missing |

### Review triggers

Review is required when a boundary is added, removed, or changed; its category
or scope changes; a compiler adds an emission kind; generated inventory changes;
a provider/profile changes; a boundary reaches a public/example surface; a
security-sensitive generator changes; source/evidence/artifact digests drift; a
waiver is within fourteen days of expiry; or a waiver is renewed, revoked, or
superseded.

Architecture acceptance and later waiver review use immutable,
content-addressed Oracle packets. There is no mandatory manual-human review
step. A 1.0 security review is still external to the implementation context and
must inspect the exact release candidate and final artifact inventory.

## Rationale

Exact source binding prevents a broad approval from following changed code.
Short absolute expiry and additive renewal prevent “temporary” exceptions from
becoming permanent. Reconciliation catches both missing findings and stale
records. Separate source, generated, and final inventories acknowledge that
compiler transformations can introduce or remove unsafe constructs. Category
and scope rules stop a valid private adapter waiver from migrating into normal
author code.

An independent Oracle review meets the need for a second security perspective
without imposing a human availability bottleneck. Keeping the accountable owner
separate preserves operational responsibility.

## Alternatives considered

### Allow any unsafe construct when it has an annotation

This is rejected. An annotation without detector reconciliation, source
identity, expiry evaluation, artifact propagation, and scope rules is easy to
copy or forget and can make unsafe code look approved.

### Keep only a repository-wide token allowlist

A token allowlist is simple, but it cannot express target AST nodes, generated
segments, private APIs, exact providers, artifact propagation, ownership,
expiry, or removal. Token scans remain one detector, not authority.

### Permit permanent waivers

Permanent records reduce churn, but eliminate the removal pressure required by
the PRD and conceal changing source/risk. This ADR limits initial lifetime to 90
days and makes renewal additive.

### Let a waiver authorize public weak types or raw HXX

This would undermine the SDK's main safety proposition and turn an exception
mechanism into an alternate API. Such scopes remain prohibited even with a
current waiver.

### Scan only source or only final artifacts

Source-only scanning misses compiler-introduced target bytes; artifact-only
scanning loses author intent, source positions, and removal ownership. The
three-observation model is selected.

### Require a manual human security reviewer

Manual expert review can be useful but cannot be a mandatory availability gate
for this project. A separate content-addressed Oracle agent with the relevant
expert role can provide reproducible independent review. A named human remains
accountable for product/release decisions and remediation.

## Consequences

Positive consequences:

- every unsafe boundary is explicit, temporary, source-bound, and searchable;
- strict Haxe and output-context rules cannot be bypassed by adding a waiver;
- stale approvals and stale inventory fail early;
- generated and packaged bytes remain attributable to their source boundary;
- release decisions can consume one closed inventory without implying safety or
  support;
- automated independent review can gate security architecture and waivers.

Costs and constraints:

- narrow unavoidable boundaries require evidence, an owner, a removal Bead, and
  periodic re-review;
- unrelated edits to a source-bound file invalidate its waiver by design;
- source and artifact scanners must agree on stable IDs;
- provider/profile upgrades can invalidate otherwise unchanged waivers;
- the project may withhold experimental integrations when no precise contract
  or review capacity exists.

## Evidence and commands

Machine authority:

- [`unsafe-boundary-policy.json`](../../manifests/unsafe-boundary-policy.json)
- [`unsafe-boundary-waiver.schema.json`](../../schemas/unsafe-boundary-waiver.schema.json)
- [`scenarios.json`](../../fixtures/unsafe-boundary/scenarios.json)
- [`test-unsafe-boundary-policy.py`](../../scripts/security/test-unsafe-boundary-policy.py)

The simulation covers a current narrow waiver, missing/stale inventory, expiry,
source and scope drift, a prohibited public Haxe type, self-approval, missing
waiver, missing generated mapping, high/critical risk, missing independent
review, decoded TypeScript `unknown`, and overlong expiry. The policy validator
also applies independent fail-closed mutations to the authority, categories,
lifecycle, inventory, gates, diagnostics, and claims.

Focused public workflow
[`30224851347`](https://github.com/fullofcaffeine/wordpresshx/actions/runs/30224851347),
job `89853259064`, passed the exact policy, schema, scenarios, and mutation
validator at commit `1d1296a9078a6e4834fb2d1f5900e568aa74c4f8`.

Acceptance commands:

```bash
python3 scripts/security/test-unsafe-boundary-policy.py
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

These checks prove a bounded governance model. They do not scan every production
source/artifact, publish an unsafe constructor, execute WordPress security
behavior, complete the release security corpus, or authorize stable support.
Independent Oracle acceptance remains required.

## Migration, rollback, and supersession

Existing classification `WAIVER-001` fixture metadata is architecture evidence,
not an ADR-019 production waiver, and must migrate to the closed schema before
it can authorize anything. Prose-only or release-relative expiry records are
invalid. Production scanners introduced by SDK-052/SDK-093 must emit the
boundary IDs and inventories defined here without weakening the current
repository Haxe prohibition.

Rollback removes the unpublished prototype policy, schema, fixture, validator,
and receipt together. Once a release contains waiver identities, history and
artifacts remain immutable; withdrawal is additive and a replacement release
must carry corrected inventories. A superseding ADR is required to add a
category, lengthen the waiver lifetime, change scope/release eligibility, relax
reconciliation, alter reviewer independence, or permit a prohibited surface.

## Follow-up beads

- `wordpresshx-sdk-052`: implement typed security/output boundaries and the
  production declaration/inventory interface; keep the unsafe raw API withheld
  until its exact implementation evidence exists.
- `wordpresshx-sdk-093`: implement source/generated/final scanners, malicious
  corpora, dependency/container scans, inventory diffs, and release blocking.
- `wordpresshx-adr-020` / `wordpresshx-sdk-plan.2`: resolve independent
  licensing findings before publication.
- `wordpresshx-adr-021`: consume the exact final unsafe inventory in release
  rehearsal and support decisions.
- `wordpresshx-sdk-plan.4`: validate all future immutable review prompt paths
  against the archived packet inventory.
