# ADR-006: Semantic plan and emitter contract

- Status: accepted
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product owner and PRD authority), Codex (architecture and contract-fixture review)
- Bead: `wordpresshx-adr-006`
- Profiles/layers: SDK build macros, exact-profile contracts, PHP/Genes/HXX/metadata emitters, staged artifacts, source correlation
- Supersedes: none; makes PRD §16.2 normative and refines ADR-003's build-layer boundary
- Superseded by: none

## Context

One Haxe declaration may drive native PHP, strict TS/TSX or JavaScript, block and
theme metadata, CSS/tokens, translations, source indexes, and package files. If
each macro or target writes files directly, those projections can disagree while
every individual generator still appears locally correct. Direct writes also
make deterministic ordering, fail-closed ownership, rollback, and useful source
correlation substantially harder.

The build needs one typed, inspectable handoff between authoring declarations and
target emitters. That handoff cannot become a provider-neutral CMS model or a
runtime application kernel: WordPress concepts remain WordPress concepts, HXX
remains compile-time input, Genes remains the JavaScript compiler authority, and
the native PHP compiler remains generic below the WordPress profile.

The plan must also grow. Hooks, REST schemas, blocks, theme hierarchy, server
markup, browser exports, design tokens, and provider contracts will not all be
implemented at once. A single open `Dynamic` payload would make that growth easy
but would merely move cross-target drift into an unvalidated JSON boundary. A
closed envelope plus exact content-addressed node schemas gives each capability
an explicit version and owner without requiring a new plan envelope for every
new node kind.

ADR-007 owns live-file publication and recovery. ADR-009 owns canonical data
schema/codec derivation. This ADR defines the contract both depend on; it does
not implement the SDK-040 macro collector, the ownership transaction, or a
production emitter.

## Decision

### One immutable plan before target emission

SDK build macros collect typed declarations, validate exact-profile
capabilities, normalize stable identities and dependencies, and produce one
`wordpress-hx.semantic-plan.v1` document. Macros do not write final target
files. The plan is a build artifact only and ships in no WordPress runtime
package.

The envelope binds:

- the exact SDK collector and toolchain identity;
- the exact profile ID, catalog revision, and catalog content digest;
- the project identity/version and effective source-tree digest;
- an exact content-addressed registry of node payload schemas;
- normalized semantic nodes, dependencies, profile requirements, source spans,
  and requested emitter projections; and
- a digest over the complete normalized plan with only the `planDigest` field
  omitted.

The accepted envelope is [`semantic-plan.schema.json`](../../schemas/semantic-plan.schema.json).
The direct `payload` object is the single deliberately delegated shape in that
schema. It is not untyped: every node names a registered schema ID, version,
kind, SHA-256, and allowed emitter set, and the collector must validate the
payload against those exact installed bytes. Unknown schemas, hash mismatches,
unknown fields in a closed node schema, or an emitter not registered for that
schema fail before emission.

The first two node schemas are intentionally small contract fixtures for a
WordPress module and hook. They establish the registry mechanism; they do not
claim SDK-040 feature breadth. Later work adds REST, block, theme, HXX, asset,
translation, package, and provider node schemas only with their owning bead and
evidence.

### Stable identity and graph rules

Node IDs are lowercase human-readable identities built from node kind, module,
and declared semantic key. Public declarations should accept an explicit stable
key where a native WordPress name is not already stable. Source paths, line
numbers, traversal order, timestamps, temporary names, and generated paths are
never part of node identity.

Dependencies and projections use separate stable IDs. Node and projection IDs
are globally unique within a plan. Dependencies must name existing nodes and
form an acyclic graph. Duplicate IDs, profile conflicts, missing dependencies,
cycles, and unresolved capabilities fail before any emitter runs. A semantic
rename is an explicit delete/add or a versioned migration; line movement cannot
silently rename an owned artifact.

### Canonical JSON v1

`wordpress-hx.canonical-json.v1` is UTF-8 without a byte-order mark. Strings and
keys normalize to NFC. Schema field names are closed ASCII names; object keys
sort lexicographically, JSON carries no insignificant whitespace, and the file
ends with exactly one LF. Duplicate JSON keys and non-finite values fail.

Floating-point JSON is forbidden in the plan contract because Haxe, PHP, and
JavaScript printers do not provide one independently proven cross-runtime
canonical decimal representation. Domains needing decimals use bounded integer
units or a validated domain string such as money minor units, CSS lengths, or a
versioned decimal contract.

Arrays have schema-defined semantics. Sets are deduplicated and sorted by their
declared stable key before encoding. Semantic sequences preserve authored order
and must carry explicit order when a producer otherwise observes an unordered
container. The generic JSON encoder never sorts an arbitrary array.

`planDigest` is SHA-256 over the normalized compact JSON document with that one
field omitted and without the terminal LF. The on-disk document includes the
digest and one LF. The same rules apply to `resultDigest` in an emitter result.

### Content-bound source locations

Every semantic node has one primary source span and may have sorted related
spans. Paths are normalized project-relative POSIX paths. Absolute paths,
backslashes, empty/dot/traversal segments, and local checkout roots are
forbidden.

Spans bind the exact source SHA-256 and use half-open UTF-8 byte offsets,
one-based lines, and zero-based UTF-8 byte columns. This matches the accepted
ADR-014 PHP range-map coordinate model. Emitters adapt those coordinates to a
target source-map convention; they do not reinterpret the semantic source
span. A span whose bytes, lines, columns, or source digest disagree fails.

### Projection and emitter boundary

A projection is a stable request for one registered emitter and artifact kind.
It is routing metadata, not target text embedded in the semantic payload.
WordPress-specific projections are owned by the SDK WordPress profile; generic
PHP IR lowering remains WordPress-independent. Browser projections invoke the
immutable Genes contract rather than copying or modifying Genes inside this
repository.

An emitter receives a validated immutable projection of the plan and an
orchestrator-owned staging sink. It may read only inputs declared and digested
by the plan/build lock. It must not mutate the plan, patch another emitter's
text, resolve schemas over the network, write the live output tree, update the
ownership manifest, read undeclared environment state, or publish a partial
result.

It returns `wordpress-hx.semantic-emission.v1`, validated by
[`semantic-emission.schema.json`](../../schemas/semantic-emission.schema.json).
The result binds the plan digest, exact emitter identity, requested and emitted
projection IDs, complete staged artifact paths/kinds/content hashes/sizes,
owner and source node IDs, content-bound source spans, required validators, and
stable diagnostics. Requested and emitted projection sets must be equal. Every
projection owner must reach at least one artifact. The result describes bytes
in the isolated staging transaction; ADR-007 alone decides whether those bytes
may replace live files.

### Extensions

Extensions are build-time only. An admitted extension has a namespaced
extension ID, node schema ID and version, exact schema SHA-256, exact package or
source lock, compatible emitter registration, and declared removal/migration
path. The build uses installed locked schema bytes; network schema resolution
is forbidden. Unknown extensions and schemas fail rather than being ignored.

An observational tool may preserve an opaque node only when its contract says
it is non-validating and non-emitting. A validator, emitter, semantic diff, or
ownership tool cannot claim success over an unknown node. Extensions never
create a runtime plugin registry, a generic compiler WordPress branch, or an
implicit escape from exact-profile capability checks.

### Versioning and consumers

Changing envelope fields, canonicalization, digest material, identity rules, or
source-coordinate semantics requires a new semantic-plan major identity. A
breaking payload change creates a new node-schema version; the old version
remains readable for its migration window. Adding a node kind is compatible
with the v1 envelope only after its exact schema, emitter coverage, and consumer
negotiation are admitted.

Migrations are explicit pure transformations that preserve the original bytes,
produce separately validated new bytes, and record old/new digests and the
migration implementation. Emitters never migrate input implicitly. The plan is
not a supported external API until a later decision names external consumers,
compatibility windows, and packed-consumer evidence; repository tools may use
it internally now.

## Rationale

The contract creates one reviewable boundary where cross-target consistency can
be proven. A hook, block attribute, theme token, HXX tree, or content contract
has one semantic identity and exact source provenance before PHP, Genes, or
metadata-specific rules begin. Target behavior remains explicit because each
node schema and projection retains its WordPress or browser meaning instead of
renaming everything into a universal application model.

Content-addressed node schemas allow gradual expansion without an open payload
or a monolithic schema release for every feature. Complete staged results keep
emitters deterministic and composable while leaving collision, rollback, and
publication authority in one transaction layer. Human-readable stable IDs and
content-bound spans make generated artifacts inspectable and debuggable without
turning source positions into ownership identities.

The decision takes only architectural patterns from the sibling compiler
repositories: closed typed planner vocabulary before serialization, separation
of framework IR from printers, explicit generated-file descriptors, and
transactional buffering of output plus source maps. No sibling source or
fixture bytes are copied and no sibling checkout becomes a build dependency.

## Alternatives considered

### Let each macro write its own target files

This is initially simple and lets each feature own its complete output. It is
rejected because ordering, profile validation, source correlation, collision
checks, cross-target schema parity, and rollback would be duplicated across
macros. Partial generation could become visible before another target fails.

### Use Haxe typed objects only and serialize no stable plan

Keeping the handoff in memory avoids schema/version work. It is rejected as the
only contract because deterministic replay, semantic diffing, source/provenance
inspection, CLI diagnostics, and independent emitter fixtures need a stable
byte representation. Implementations should still use typed Haxe wrappers and
serialize only at the boundary.

### Use one giant closed schema for every future node

This maximizes central validation but couples hooks, REST, blocks, themes, HXX,
assets, translations, and packaging to one schema revision and one owner. It is
limited to the closed envelope. Content-addressed node schemas keep payloads
closed while letting bounded capabilities evolve under their actual owners.

### Allow arbitrary JSON payloads or `Dynamic`

This makes extensions frictionless and avoids schema registration. It is
rejected because it recreates the cross-language drift the plan exists to
prevent. The envelope's open JSON object is permitted only as a delegated
location that must pass an exact closed node schema before any consumer sees
it.

### Make emitters filesystem plugins that write their own outputs

This resembles familiar compiler plugin systems and can support third parties.
It is rejected for the supported path because live writes and undeclared reads
break atomic ownership. Build-time extensions may emit only through the locked
projection/staging/result contract.

### Put target-native AST/text directly in the shared plan

This could make emitters trivial. It is rejected because PHP, TSX, metadata,
and CSS concerns would contaminate the shared authority and encourage textual
patching. Target AST/IR belongs after projection: generic PHP IR in
`reflaxe.php`, WordPress PHP profile plans in the SDK, and Genes intent/output
in the browser lane.

### Defer the plan until examples exist

The landing, blog, and commerce examples would surface useful requirements,
but implementing them first would make application-specific adapters the
accidental shared contract. The bounded module/hook fixture is enough to decide
the envelope; later site work expands node schemas through real vertical
evidence.

## Consequences

Benefits:

- PHP, Genes, metadata, HXX, token, and package emitters consume one validated
  declaration graph;
- exact-profile capabilities and source spans are checked once before target
  work begins;
- clean replay, semantic diff, provenance, staged ownership, and parallel
  emission have a stable byte boundary;
- new capabilities can add a closed content-addressed node schema without
  weakening older payloads;
- a future NextJsHx renderer can consume explicit browser/content projections
  without changing WordPress-native runtime authority.

Costs and constraints:

- collectors must build typed nodes and schema-specific payloads rather than
  writing convenient target snippets;
- canonicalization and registry validation add build work and fixtures;
- stable IDs become a maintained application/public contract;
- adding a node kind requires schema, emitter, migration, diagnostic, and
  coverage decisions;
- decimal values need domain contracts instead of raw JSON floats;
- external semantic-plan tooling is deliberately unsupported until separately
  admitted.

This ADR does not prove a macro collector, a production emitter, WordPress or
Next.js runtime compatibility, artifact publication safety, or production
support.

## Evidence and commands

Machine authority:

- [`semantic-plan-architecture.json`](../../manifests/semantic-plan-architecture.json)
- [`semantic-plan.schema.json`](../../schemas/semantic-plan.schema.json)
- [`semantic-emission.schema.json`](../../schemas/semantic-emission.schema.json)
- [`semantic-plan fixtures`](../../fixtures/semantic-plan/README.md)

The fixture proves two closed content-addressed node schemas, two stable
projections, one content-bound staged artifact, canonical replay under set
permutations, Unicode normalization, sequence preservation, duplicate/float
rejection, exact source coordinates, exact-profile capability binding, and 21
fail-closed mutations. The expected PHP is a contract byte fixture, not a claim
that SDK-040 or the production WordPress emitter generated it.

Read-only architecture references are pinned in the machine manifest at exact
commits, paths, Git blobs, and SHA-256 values for `haxe.rust`, `haxe.ruby`,
`haxe.go`, and Genes. `copiedBytes` is false for every reference.

Acceptance commands:

```bash
bash scripts/semantic-plan/test.sh
bash scripts/check-repository.sh
bash scripts/hooks/test.sh
bash scripts/lint/hx-format-guard.sh
bd lint
bd dep cycles
git diff --check
```

No registry publication, sibling source change, external network schema lookup,
live generated-file write, or runtime compatibility claim is part of this
decision.

## Migration, rollback, and supersession

There is no released plan consumer. Before SDK-040 lands, rollback is removal of
this unshipped contract and reopening ADR-006. Once a collector or emitter
depends on v1, any incompatible replacement needs a superseding ADR, a pure
old-to-new migration with immutable before/after fixtures, consumer negotiation,
and a deprecation window.

If the delegated node-schema registry cannot provide deterministic validation
or safe extension negotiation, a superseding ADR may choose a closed monolithic
schema. It must migrate every retained node and cannot silently treat unknown
payloads as valid.

## Follow-up beads

- `wordpresshx-adr-007`: use staged emission results as the only input to
  fail-closed ownership publication and recovery.
- `wordpresshx-adr-009`: define canonical schema/codec authority on top of
  content-addressed semantic nodes.
- `wordpresshx-sdk-040`: implement typed macro collection, normalization,
  validation, plan replay, and semantic diagnostics.
- `wordpresshx-sdk-041`: implement the transaction and generated-file manifest;
  emitters never bypass it.
- `wordpresshx-sdk-052`: define typed output-context nodes and unsafe-boundary
  policy before server HXX lowering.
- `wordpresshx-sdk-081`: project typed server HXX into native PHP markup IR.
- `wordpresshx-sdk-113`: reuse content/block/token nodes across native WordPress
  and the pinned public NextJsHx/Genes adapter.
