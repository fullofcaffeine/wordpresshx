# ADR-008: Profile generation and API classification

- Status: accepted
- Date: 2026-07-17
- Owners/reviewers: Marcelo Serpa (product owner and PRD authority), Codex (architecture and evidence-model review)
- Bead: `wordpresshx-adr-008`
- Profiles/layers: exact profile catalogs, capability ledgers, generated namespaces, documentation, diagnostics, and release claims
- Supersedes: none; refines ADR-001 evidence vocabulary and ADR-002 profile isolation
- Superseded by: none

## Context

An exact upstream source tree can prove that a symbol, package, hook, handle, or metadata key exists. It cannot by itself prove that the SDK representation is correct, that generators emit a valid artifact, that the artifact behaves correctly in WordPress, or that maintainers promise production support. Treating inventory as support would turn catalog breadth into an unearned compatibility claim.

The SDK also needs visibly different API surfaces. A stable public wrapper, an opt-in Gutenberg experiment, an implementation-private declaration, a reviewed unsafe escape, and a deprecated compatibility entry have different import, generation, documentation, release, and migration rules. Those classifications describe exposure policy, not evidence maturity. An experimental entry may have excellent runtime evidence and remain experimental; a public candidate may still be only inventoried and therefore unpublishable.

Evidence authority is question-specific. Official release bytes are stronger than a monorepo workspace listing for what actually shipped, while an exact real-runtime fixture is stronger than source inference for behavior. A curated contract can resolve an ambiguous Haxe representation but cannot manufacture runtime support. The schema and generator must preserve these distinctions before public packages depend on them.

SDK-010 and SDK-011 provide exact source/release authorities. This ADR decides how later schemas and generators classify entries and advance evidence. It does not implement the profile schema, generate catalogs, or make a runtime/support claim; SDK-012, SDK-013, and the real WordPress/browser gates own those results.

## Decision

### Separate classification and evidence axes

Every capability entry has one API classification and one attained evidence status. Neither axis implies the other.

The closed classification vocabulary is:

| Classification | Meaning | Exposure rule |
|---|---|---|
| `public` | Intended stable, SemVer-governed SDK surface | May be published in the stable namespace only at `runtime-tested` or later; `production-supported` still requires the complete support contract |
| `experimental` | Opt-in unstable surface without compatibility promise | Requires an explicit experimental namespace/define and at least `typed` evidence; never becomes production-supported without reclassification and migration review |
| `private` | Generator or implementation detail | Recorded for provenance but absent from consumer package graphs and generated public artifacts |
| `unsafe` | Narrow escape surface that bypasses a normal safety contract | Requires explicit import/define, a waiver, security review, manifest inventory, and removal owner; never production-supported while classified unsafe |
| `deprecated` | Previously public compatibility surface scheduled for migration/removal | Retains its public name during the promised window, emits deprecation metadata/diagnostics, and requires `since`, replacement or no-replacement reason, earliest removal, and evidence continuity |

`public` is the canonical machine value for the stable public surface. Documentation may say “stable public,” but a second `stable` enum alias is forbidden because aliases would create divergent serialized catalogs. Classifications are mutually exclusive. Deprecating a released public API changes its classification without moving the callable name during the compatibility window; the separate deprecated inventory and generated diagnostic make the boundary visible.

Classification never increases evidence. A `public` entry at `inventoried` is an intent/review record, not an importable wrapper. An `experimental` entry at `runtime-tested` is still experimental. Reclassification requires a catalog change, review receipt, release note, and migration analysis; moving `experimental`, `private`, or `unsafe` to `public` additionally requires the public publication floor.

### Ordered evidence maturity

The exact ordered evidence states are:

1. `inventoried`: found in exact upstream input with content-addressed provenance; no type or behavior claim.
2. `typed`: reviewed Haxe/contract representation exists for the exact profile and capability; no emitted/runtime claim.
3. `generated`: the exact artifact was emitted and passed applicable schema, type, static, and deterministic checks; no runtime claim.
4. `runtime-tested`: the exact artifact passed named real-runtime evidence for the recorded profile, provider, toolchain, and environment.
5. `production-supported`: the exact finite capability is inside a published support window and its complete production-readiness contract has passed with no blocking result.

`generated` is the canonical ledger value; user-facing prose may say “emitted,” but `emitted` is not a second serialized status. Promotion is contiguous and additive. Each transition records its own receipt, exact keys, input/output digests, time, and reviewer. One automation run may produce several receipts, but it may not collapse or infer missing stages.

The aggregate attained status is the highest continuous proven prefix, never the highest isolated green check. A runtime fixture without a reviewed type contract does not make an entry `runtime-tested`; it is retained as unattached evidence until the missing stages are established. Evidence does not inherit across profile, catalog digest, capability, artifact digest, provider, toolchain, environment, or support window.

Administrative results remain orthogonal: `not-tested`, `failed`, `not-applicable`, `unsupported`, and `withdrawn`. Each requires a reason and affected keys. A failure or withdrawal blocks promotion and the effective public claim, but it never erases attained history or rewrites an old receipt. Blank fields are not interpreted as passing or supported.

### Evidence sources and precedence

There is no universal “source wins” order. Precedence is evaluated for the question being answered:

| Question | Precedence, strongest first | Maximum result without other evidence |
|---|---|---|
| Shipped availability/bytes | exact official distribution or package artifact; exact package export/asset metadata; exact source workspace; versioned official documentation; heuristic scan | `inventoried` |
| Signature/shape | provider-owned versioned stubs/export maps/schema; unambiguous exact source declarations; curated reviewed contract citing exact inputs; versioned documentation/PHPDoc; heuristic inference | `typed` only after review |
| Runtime behavior | exact final SDK artifact on the exact real provider/runtime; focused upstream executable fixture on exact released bytes; upstream tests/source reasoning; documentation | `runtime-tested` only for the first class and recorded scope |
| Production support | completed production-readiness ledger plus published maintainer support window; runtime evidence; all other inputs | `production-supported` only for the complete first class |

Actual exact runtime behavior overrides documentation or source assumptions about behavior. Exact released bytes override a workspace package listing for shipped availability. Provider-owned versioned stubs, schemas, or export maps override heuristic signature inference unless real behavior contradicts them. A curated override must cite the conflict, reviewers, chosen representation, affected profiles, and test plan; it cannot override a real-runtime failure into a pass.

When equal-authority sources conflict, generation fails closed and emits a review item. Lower-confidence data may enrich diagnostics but cannot raise evidence state beyond its authority. Ambiguous unions, magic/dynamic members, conditional symbols, private exports, and inferred callback shapes are precise-or-omitted: they enter the review report rather than becoming broad `Dynamic` or stable public wrappers.

### Capability ledger identity

Every ledger row is keyed by at least:

- exact `profileId`, `catalogRevision`, and catalog content digest;
- stable capability ID and provider identity;
- exact upstream commit/artifact digests and entry provenance;
- API classification and attained evidence status;
- generator/toolchain identity where generated output exists;
- exact artifact digest for generated and later stages;
- environment, provider, and receipt IDs for runtime and support stages;
- administrative results, correction ancestry, and classification-specific metadata.

The selected profile is availability authority at compile time. A compile-time capability token is immutable, serializable build data derived from one exact catalog. A runtime capability result is request-scoped proof produced by native checks against the current provider. It is not serializable authority, does not modify profile selection, and cannot admit an unavailable import, package export, handle, metadata key, or signature.

The machine-readable architecture lock is [`profiles/classification-decision-lock.json`](../../profiles/classification-decision-lock.json). SDK-012 must translate this vocabulary and its closed-field rules into the versioned schema and Haxe types without weakening it.

### Publication and dependency rules

Stable packages may consume only `public` and still-within-window `deprecated` entries at or above the public publication floor. Experimental packages require explicit opt-in and cannot be dependencies of stable packages. Private entries never appear in consumer graphs. Unsafe entries require explicit source-level acknowledgement and are inventoried in every final artifact manifest.

Generated docs, discovery, diagnostics, manifests, and release notes display classification and evidence status separately. A search hit must say `inventoried` when that is all the evidence available. “Supported,” “stable,” or “production-ready” is prohibited unless the exact keyed row is `production-supported` and its support window is current.

### Corrections and versioning

Published catalog bytes, receipts, tags, and release artifacts are immutable. A correction is additive:

1. preserve the erroneous catalog digest and receipts;
2. mark the affected effective claim `failed`, `unsupported`, or `withdrawn` with a reason;
3. open the ADR-001 claim-correction workflow when public wording or shipped metadata overstates evidence;
4. publish a replacement SDK/catalog artifact with a new content digest and `correctionOf` link;
5. record consumer-contract and schema-interpretation impact, SemVer classification, migration guidance, and affected artifacts;
6. rerun every invalidated downstream evidence stage instead of copying the old attained status.

Upstream identity, profile identity, catalog schema/revision, SDK version, and catalog content digest are independent. A new upstream baseline creates a new exact profile or explicitly admitted identity. A breaking change to catalog schema interpretation increments `catalogRevision`. A data/signature/classification correction under the same schema still produces a new SDK/replacement artifact and digest; if it changes a consumer contract, release notes and SemVer treat it as breaking even when upstream bytes did not change.

No mutable `latest` catalog is evidence authority. Caches and manifests key the exact digest. Rollback selects an earlier immutable SDK/catalog/artifact tuple and restores only the claims proven for that tuple.

## Rationale

Two independent axes prevent a useful classification from becoming a support shortcut. Contiguous evidence stages make missing proof visible, while question-specific precedence respects that source, distributions, types, runtime behavior, and maintainer promises answer different questions. Publication floors let the project inventory broadly and experiment deliberately without shipping an untested stable facade.

Additive correction preserves auditability. Separating schema revision from upstream and content identity allows generator/schema evolution and evidence repairs without pretending upstream changed. Request-scoped runtime tokens support optional native integrations without contaminating deterministic compile-time profile selection.

## Alternatives considered

### One `supported: true|false` flag

This is easy to display and query. It is rejected because it collapses type quality, emitted artifact checks, runtime behavior, production operations, experimental policy, and time-bounded support into one unauditable assertion.

### Derive evidence from API classification

Calling every public entry supported and every experimental entry untested would simplify catalogs. It is rejected because classification is SDK exposure intent, while evidence is observed proof. Either axis can change independently.

### Treat generated source inventory as semantic authority

Static extraction is deterministic and broad, but it cannot prove conditional availability, packaged exports, runtime callback behavior, or compatibility. It is limited to `inventoried` until reviewed contracts and later gates add evidence.

### Use one global evidence-source ranking

A single total order looks objective but produces wrong answers: distribution bytes outrank workspace source for shipped availability, while real runtime outranks both for behavior and provider stubs may outrank heuristic source inference for signatures. Question-specific precedence is selected.

### Allow maturity stages to skip when a later test passes

A real integration test can accidentally exercise a capability before its type or provenance record is complete. Treating that as full maturity hides gaps and makes later reproduction impossible. The test is retained, but aggregate status advances only through a continuous receipt chain.

### Serialize successful runtime detection as a capability token

This could avoid repeated native checks. It is rejected as authority because plugin activation, versions, multisite/blog context, request state, and registered packages can change. Caching may exist only inside the documented native validity scope and cannot cross requests/builds as profile evidence.

### Mutate the current catalog after a correction

Silent repair keeps filenames simple but invalidates old manifests, caches, receipts, and user reports. Immutable replacement artifacts with correction ancestry are required.

## Consequences

Positive consequences:

- inventories can be broad without becoming public support claims;
- stable, experimental, private, unsafe, and deprecated surfaces have enforceable dependency rules;
- every promotion identifies exactly which proof is missing or invalid;
- contradictory evidence produces review work instead of permissive types;
- generated docs and release notes can consume one finite ledger without inventing wording;
- corrections, rollbacks, and profile diffs remain content-addressed and auditable.

Costs and constraints:

- generators and schemas carry more provenance, receipt, correction, and classification metadata;
- capability promotion requires real receipts at each stage rather than a single green build;
- runtime evidence is deliberately narrow and may need repetition across profiles/providers/environments;
- deprecated compatibility windows and unsafe waivers create explicit maintenance work;
- public wrappers are withheld until real behavior evidence exists, reducing early stable API breadth.

Acceptance of this ADR changes no capability status. Existing SDK-010/011 profile inventories remain `inventoried`; runtime and production claims remain `not-tested`, and all forward support remains experimental.

## Evidence and commands

Reviewed sources:

- [PRD §9 profile architecture and enforcement](../../wordpress-hx-sdk-product-requirements.md#9-compatibility-baselines-and-version-profiles);
- [PRD §17 precise-or-omitted interop](../../wordpress-hx-sdk-product-requirements.md#17-interop-and-adoption-contracts);
- [PRD §22.22 evidence ledger](../../wordpress-hx-sdk-product-requirements.md#2222-evidence-ledger);
- [PRD §22.23 production-readiness evidence contract](../../wordpress-hx-sdk-product-requirements.md#2223-exact-production-readiness-evidence-contract);
- [PRD §24.2 profile/version correction policy](../../wordpress-hx-sdk-product-requirements.md#242-version-policy);
- [ADR-001 claim vocabulary/correction policy](001-product-and-repository-boundary.md);
- [ADR-002 exact profile isolation](002-exact-compatibility-profiles.md);
- SDK-010 and SDK-011 immutable source/release locks and receipts.

Acceptance checks:

```bash
python3 scripts/profiles/check-classification-decision.py
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

The decision-lock test exercises contiguous promotion, exact receipt keys, surface publication floors, deprecated/unsafe requirements, administrative withdrawal, non-serializable runtime evidence, and additive correction. These are architecture fixtures, not generated catalog or real WordPress runtime results.

## Migration, rollback, and supersession

No released profile schema or catalog consumer exists. SDK-012 must use the canonical enum values and reject unknown fields/statuses. Prototypes with `supported` booleans, `stable` aliases, inferred stage skipping, or serializable runtime authority must migrate before they can become evidence.

Rollback selects a prior immutable SDK version, profile/catalog digest, artifact digest, and matching evidence ledger. It does not copy a later status onto earlier bytes. A superseding ADR is required to change ordered vocabulary, relax publication floors, admit a new classification, allow stage skipping, or make runtime evidence durable build authority.

## Follow-up beads

- `wordpresshx-sdk-012`: implement the closed profile/evidence schema, Haxe types, compile-time availability token, request-scoped runtime capability result, and negative fixtures.
- `wordpresshx-sdk-013`: generate deterministic precise-or-omitted catalogs and review reports from exact inputs.
- `wordpresshx-sdk-014`: diff classifications, contracts, evidence, corrections, and migration impact.
- `wordpresshx-adr-009`: apply this evidence model to canonical schema/codec authority.
- `wordpresshx-adr-010`: apply it to built-in, custom, and dynamic hook contracts.
- `wordpresshx-adr-020` and `wordpresshx-sdk-002`: decide licensing/provenance requirements before catalog/package publication.
- `wordpresshx-adr-021`: define support windows, deprecation windows, and production maintenance commitments.
