# ADR-009: Schema and codec authority

- Status: accepted
- Date: 2026-07-19
- Owners/reviewers: Marcelo Serpa (product owner and PRD authority), Codex (architecture and executable-fixture implementation), independent Codex review (two correction rounds; final review found no blockers)
- Bead: `wordpresshx-adr-009`
- Profiles/layers: shared contracts, PHP compiler/profile, Genes browser output, WordPress REST, Gutenberg block attributes, schema migrations
- Supersedes: none; makes PRD §§5.1, 13.5, 14.5, 15.3, and 29.1 concrete on top of ADR-006
- Superseded by: none

## Context

A Haxe declaration may be consumed as a domain type, native PHP data, a strict
browser value, a WordPress REST argument/response schema, or Gutenberg block
attributes. If each target owns a second schema, requiredness, nullability,
defaults, enum cases, validation, sanitization, and migration behavior can drift
while every artifact still looks individually plausible.

The shared contract must remain narrow. WordPress REST schemas and Gutenberg
attribute schemas are related projections, not identical standards. PHP arrays
and JavaScript objects have different foreign-boundary behavior. WordPress
sanitizers may be intentionally lossy and have no exact browser equivalent.
The Haxe type system also does not make parsed JSON trustworthy by itself.

ADR-006 already selects one typed semantic plan before target emission and
forbids floating-point values in its canonical build contract. This ADR defines
the typed value/schema node consumed by contract-bearing semantic-plan nodes.
It does not turn REST, block metadata, or target-native schemas into competing
authorities, and it does not create a runtime schema service.

The application-facing syntax should eventually be considerably denser than
the executable builder fixture in this decision. Macro derivation can remove
repetition only after the semantic meaning is fixed; otherwise convenient
syntax merely hides drift.

## Decision

### One semantic schema IR

`wordpress-hx.contract-schema.v1`, represented in Haxe by
`SchemaDocument`, is the canonical semantic authority. Its closed serialized
contract is [`contract-schema.schema.json`](../../schemas/contract-schema.schema.json).
Target-native PHP arrays, TypeScript interfaces, REST argument arrays,
`block.json`, generated documentation, and test vectors are projections. They
never become input authority for a Haxe-owned contract.

The initial executable authoring form is the typed builder in
[`packages/contracts`](../../packages/contracts/README.md). The intended public
form is a concise macro-derived contract over closed Haxe typedefs, classes,
enums, abstracts, and explicit field metadata. Both forms must lower to the
same `SchemaDocument` before emission. A macro is derivation convenience; its
macro AST and compiler internals are not a second schema.

A production declaration binds:

- a stable schema ID and positive monotonically increasing version;
- the closed value schema;
- a `ContractCodec<T>` for domain construction and encoding;
- exact versioned validation rules;
- separately classified sanitization descriptors;
- missing-field defaults where declared; and
- explicit adjacent migration references.

The collector writes the canonical schema bytes to the installed
content-addressed schema registry. Its ADR-006 semantic node carries only the
restricted-ASCII schema ID, signed-int32 version, and lowercase hexadecimal
SHA-256 reference. Raw schema bytes and contract payload strings are never
embedded in the NFC-normalized semantic-plan envelope. Emitters resolve and
authenticate the exact installed bytes before consuming them. This keeps
ADR-006's `wordpress-hx.canonical-json.v1` plan identity distinct from
`wordpress-hx.contract-canonical-json.v1`; hand-written parallel PHP, browser,
REST, or block schemas for an owned contract remain forbidden.

### Closed wire algebra and numeric policy

Foreign values are converted immediately into the closed `WireValue` algebra:
null, boolean, signed 32-bit integer, string, array, or object. Schema nodes add
closed string enums, nullable values, and tagged unions. Objects reject unknown
and duplicate fields in v1. Tagged unions are closed objects with distinct
named discriminator and payload fields; cases are stable string tags with a
case-specific payload schema.

Floating-point JSON is not admitted. Money uses bounded integer minor units;
larger integers and decimals use explicit versioned domain strings until a
cross-target numeric contract proves more. A projector cannot silently change
an integer to a float or a domain decimal to a target-native number. Every
serialized integer-bearing schema position—wire defaults, bounds, lengths,
versions, revisions, and migration endpoints—enforces the same signed-int32
ceiling and floor.

String length constraints count Unicode scalar values, not PHP bytes or
JavaScript UTF-16 code units. Contract payload strings are preserved rather
than silently normalized. Stable schema/rule IDs and field names use restricted
ASCII forms. A domain needing Unicode normalization declares a named exact rule
and vectors for it.

The canonical schema serialization uses compact UTF-8 JSON from the closed wire
algebra. Object keys sort lexicographically by Unicode scalar value on every
target; it contains no floats or duplicate keys. Schema field and rule arrays
retain authored semantic order. Contract strings—including decomposed Unicode—
are preserved. Their exact canonical bytes are digested before the ASCII
schema reference enters the separately NFC-normalized ADR-006 plan. Payload
byte equivalence is required only when the contract declares it; otherwise PHP
and Genes outputs must decode to the same semantic value and issue.

### Missing, explicit null, and defaults

Target null conventions are not semantic authority. The shared Haxe model uses:

```text
Presence.Missing
Presence.Present(NullableValue.ExplicitNull)
Presence.Present(NullableValue.NonNull(value))
```

Required/optional and nullable/non-nullable are independent decisions. A
required nullable field must be present and may contain null. An optional
non-nullable field may be absent but rejects a present null.

A default is legal only on an optional field. `FieldDefaults.whenMissing`
recursively converts authored `WireValue` into a closed, recursively immutable
`FrozenWireValue`, so neither mutating the caller's source arrays nor mutating a
later projected copy can change accepted schema bytes. Cyclic array or object
graphs fail with `ContractError` during freezing. `SchemaDocument` binds the
declaration's rule implementation and rejects a default that fails either its
shape or a named validator before the schema becomes authoritative. Runtime
materialization and schema projection each thaw a fresh copy. Explicit null
never triggers a default. Target projections must preserve this behavior;
in particular, a Gutenberg or REST default may be emitted only when the native
system applies it at the same boundary. Otherwise a generated adapter applies
the default explicitly or the projection fails.

### Decode and encode authority

The decode path is ordered:

1. A target-owned foreign parser adapter accepts raw bytes or native values and
   immediately constructs `WireValue`.
2. An operation adapter applies only the explicitly selected sanitization
   policy.
3. `ContractValidator` rejects wrong kinds, invalid ranges/lengths, unknown or
   duplicate fields, missing required fields, invalid enum/union tags, and
   unavailable or failing exact rules.
4. Missing-field defaults are materialized and validated.
5. The domain codec constructs `T` only from the normalized validated value.

The domain codec may pattern-match again to satisfy the Haxe typer, but it does
not duplicate user-input validation. An impossible branch after successful
schema validation is an SDK defect, not a user-input error.

Encoding performs the inverse domain-to-wire mapping and then validates in
development/test builds. Generated production encoders may omit a redundant
validation walk only when derivation proves the domain representation cannot
violate the schema and differential fixtures cover the optimized path.

No runtime reflection table or generic object mapper is required. Foreign
parsing adapters are target-specific and remain the only unavoidable open
boundary. If an external API cannot be represented without a weak operation,
the repository's strict Haxe rule applies: isolate the smallest expression,
convert immediately, and document the invariant inline. No such operation is
present in this ADR's repository-owned Haxe prototype.

Strict package-scoped Haxe null safety is part of every interpreter, Genes,
PHP, and compile-negative command. Raw target `null` cannot inhabit
`WireValue`, `SchemaNode`, or another contract reference in repository-owned
code; `NullValue`, `NullableValue`, and `Presence` remain the explicit forms.

### Validation and sanitization are different

Validators decide admissibility. Every validator has a stable `RuleId`, a
positive revision, and `exact` parity. The same accepted/rejected vectors must
run in PHP and Genes output. A missing rule implementation fails with
`WPHX5206`; no target may skip an unknown validator.

`ContractRuleSet.evaluate(rule, value)` deliberately receives no diagnostic
path. Rule admissibility therefore cannot differ between declaration-time
default checking and runtime validation merely because the value occupies a
different location. `SchemaDocument` retains the exact rule-set instance used
to admit the declaration, and ordinary document validation cannot substitute a
different registry. JSON Pointer paths are diagnostic context owned solely by
`ContractValidator`.

`RefinedNode` attaches validators and sanitizer descriptors to any value node,
not just object fields. Scalar roots, array items, object values, nullable
values, and tagged-union payloads therefore retain one reusable rule model
without changing their wire shape. Directly nested refinements are rejected so
the canonical location and rule order stay unambiguous.

Sanitizers transform values and may be lossy. They use the same stable identity
and revision mechanism but may be either:

- `exact`, when PHP and browser implementations have the same specified
  behavior; or
- `documented-native-relation`, when a pinned WordPress native sanitizer owns
  PHP behavior and the relationship is tested against the exact profile.

Sanitizers never run implicitly inside the base contract decoder. A route,
option, meta field, block boundary, or form contract chooses an explicit typed
operation policy and applies its ordered sanitizer list before validation. A
validator rule cannot use `documented-native-relation`, and one rule revision
cannot be both validator and sanitizer on the same field. Security-sensitive
invalid input defaults to rejection rather than silent repair.

Validation, sanitization, authorization, nonce verification, and output-context
escaping remain separate. ADR-012 and ADR-019 define the trust/output graph and
unsafe governance; this ADR creates no `Safe<T>` shortcut.

### Canonical diagnostics

V1 decoding is deterministic fail-first. A rejection contains one stable issue
with code, RFC-6901 JSON Pointer path, expected token, and actual token:

| Code | Meaning |
|---|---|
| `WPHX5201` | wire kind mismatch |
| `WPHX5202` | missing required field |
| `WPHX5203` | unknown field |
| `WPHX5204` | duplicate field |
| `WPHX5205` | built-in constraint or named-rule rejection |
| `WPHX5206` | required rule implementation unavailable |

Container kind is checked first. Object duplicate and unknown names are checked
in lexicographic Unicode-scalar order, then declared fields in schema order.
Arrays use ascending index and validators use declared order. This fixes
PHP/Genes error parity even where PHP's UTF-8 byte comparison and JavaScript's
UTF-16 comparison disagree, and avoids target-dependent map iteration. A
future aggregated-error mode needs a new diagnostic contract; it cannot
silently change v1 ordering.

### Versioning and migrations

Any semantic change increments the schema version, including requiredness,
nullability, a default, a field/tag name, a constraint, or rule membership. A
behavior change in a named rule also increments that rule's revision. An
additive optional field can be compatibility-preserving for selected readers,
but it still creates a new schema version and a generated compatibility report.

V1 records a complete ordered chain of adjacent pure migrations from version 1
to the current version. A migration has from/to versions, a stable rule ID, and
revision. Migration execution is explicit:

1. validate bytes with the immutable old schema and codec;
2. run one named adjacent pure migration;
3. validate the result with the next schema;
4. repeat while recording before/after schema identities and content digests.

Emitters and decoders do not migrate implicitly. Gutenberg block deprecations,
saved markup, REST clients, and plugin storage each choose and expose their
upgrade boundary. Retiring an old schema follows ADR-021 support windows; it is
not achieved by deleting migration evidence.

### PHP, Genes, REST, and Gutenberg projections

The generic contract/value/schema modules contain no WordPress symbol and are
usable by a PHP-only Haxe consumer. WordPress behavior lives above that layer.
Production projection rules are:

- **PHP:** the generic PHP compiler emits readable native scalar/array codecs
  and rule calls. The WordPress profile emits small native adapters and uses
  exact WordPress functions only where the schema names a compatible relation.
- **Genes:** the pinned Genes compiler emits strict TypeScript/JavaScript types,
  codecs, and clients. Browser code consumes ordinary objects; it does not ship
  a second schema service or copy the PHP implementation.
- **REST:** representable built-in constraints become native
  `register_rest_route` argument schema entries. Named validators/sanitizers
  become explicit callbacks. Permissions, status/error mappings, and nonce
  policy belong to the route contract and cannot be inferred from a data schema.
- **Gutenberg attributes:** representable field types, source shapes, and
  missing-field defaults become profile-correct `block.json` attributes.
  Saved serialization, deprecations, bindings, and migrations remain explicit
  block contracts. Unsupported unions, null semantics, sources, or defaults
  fail rather than widen to an open object.

Every projection records schema ID, version, and canonical digest. A target
that cannot express a semantic constraint must add a generated adapter with
the same vectors or reject the projection. “Close enough” REST or block
metadata is not allowed.

This rule also applies to Gutenberg patterns, template parts, and reusable site
content where attributes cross editor/server boundaries. It enables the
cohesive SDK-121 authoring surface; it does not itself implement patterns,
blocks, REST routes, or complete sites.

## Rationale

A small closed algebra gives every target the same questions to answer and
makes unsupported semantics visible. Explicit presence/null/default types stop
PHP and JavaScript conventions from deciding domain behavior. Versioned rules
separate a reusable schema from application-specific checks without reducing
those checks to function-name strings with unknown behavior.

Keeping sanitization distinct prevents a native WordPress convenience from
being misrepresented as exact cross-target validation. Making target schemas
projections lets WordPress remain native: REST and Gutenberg use their normal
registration shapes, but those shapes cannot drift from the Haxe declaration.

The builder prototype is intentionally lower-level than the eventual public
API. It proves the semantics before SDK-054 introduces derivation. Haxe-first
ergonomics remain the goal: ordinary application authors should declare a type
and exceptional rules once, not hand-write the builder, PHP callbacks,
TypeScript codec, REST array, and `block.json` independently.

Read-only sibling review informed bounded patterns only:

- Genes demonstrates containing and immediately narrowing a JavaScript foreign
  boundary; its weak implementation machinery is not copied into this Haxe
  source.
- `haxe.ruby` demonstrates one golden JSON corpus across compiler/runtime
  targets; its broad JSON test types, reflection, and floats are not adopted.
- `haxe.elixir.codex` demonstrates compile-time framework field inspection; its
  source-file heuristics and predefined fallbacks are rejected as authority.
- `haxe.ocaml` demonstrates typed, ordered, versioned inspection reports.
- `tink_json` demonstrates useful macro-derived reader/writer ergonomics and
  optional-field handling; its null sentinels and weak macro escape mechanisms
  are not copied.

Exact commits, paths, Git blobs, file hashes, selected patterns, and
`copiedBytes: false` are recorded in
[`schema-codec-architecture.json`](../../manifests/schema-codec-architecture.json).
No sibling checkout is a build or runtime dependency.

## Alternatives considered

### Treat Haxe types alone as the schema

This is concise and preserves domain typing. It is rejected as the complete
authority because requiredness, explicit null, wire names, defaults, numeric
bounds, sanitization relations, migrations, and target projection capability
are not all recoverable safely from a bare Haxe type. Macro derivation still
starts from Haxe types, but must produce the explicit semantic IR.

### Make WordPress REST schema or `block.json` canonical

This appears maximally native and reduces one emitter. It is rejected because
the two WordPress schemas have different expressive subsets and neither owns
PHP/browser domain codecs. Making either canonical would force unrelated
boundaries to inherit its omissions.

### Maintain independent PHP and TypeScript codecs

This lets each language use its best libraries and may produce smaller code.
It is rejected for owned contracts because cross-language changes become a
review convention rather than a compiler-checked dependency. Target-specific
implementations remain legal only behind one named schema/rule and shared
vectors.

### Use target-native arbitrary JSON values throughout shared Haxe code

Genes and stock Haxe can expose native JSON conveniently. It is rejected for
the semantic core because an open value plus assertions would spread the
foreign boundary and weaken exhaustiveness. Native objects remain at the
actual target edge and are converted immediately into the closed algebra.

### Adopt `tink_json` directly as the public contract authority

Its derivation and reader/writer design are mature and useful references. It is
limited rather than adopted because the SDK also needs stable cross-target
schema nodes, WordPress/Gutenberg projection negotiation, explicit missing vs
null, rule parity, and the repository's stricter weak-type policy. Future macro
work may use compatible parser/compiler techniques without exposing a second
authority or copying prohibited boundary mechanisms.

### Sanitize every input automatically

This is convenient for forms and resembles common WordPress practice. It is
rejected because lossy repair can hide invalid or hostile input and rarely has
an exact browser equivalent. Sanitization must be selected at the operation
boundary and remain visibly different from validation.

### Permit open objects for forward compatibility

Ignoring new fields helps old readers survive additive changes. It is rejected
as the v1 default because typos and profile drift become valid input. A future
version may add a typed extension-map node with explicit ownership and
round-trip semantics; it cannot turn ordinary objects open silently.

### Infer migrations from schema diffs

Automatic rename/default/coercion could reduce upgrade code. It is rejected for
saved block content, REST clients, and persisted data because plausible diffs
do not prove domain meaning. Diffs may generate a reviewed migration skeleton,
but the accepted migration remains named, pure, versioned, and tested.

## Consequences

Benefits:

- one Haxe declaration can drive PHP, Genes, REST, and block artifacts without
  making a target schema authoritative;
- missing, null, defaults, enums, tagged unions, and errors have stable
  cross-target meanings;
- exact validators and native-related sanitizers cannot be confused;
- unsupported target projections fail before emitting plausible widened code;
- Gutenberg attributes/pattern data and complete-site contracts can reuse the
  same typed boundary as REST and server code;
- the generic core remains usable without WordPress and extractable later.

Costs and constraints:

- the SDK must maintain schema/rule versions and a cross-target vector corpus;
- target projection capability matrices are necessary because REST and block
  schemas are not isomorphic;
- v1 deliberately excludes floats, open objects, implicit migrations, and
  aggregate diagnostics;
- macro derivation, parser adapters, sanitization execution, and production
  emitters remain substantial follow-up implementation;
- named rule registries must be complete on every target before a contract is
  considered supported.

This decision does not prove production macro derivation, the custom PHP
compiler emitter, a production Genes client, PHP 7.4 compatibility, native
WordPress REST behavior, Gutenberg serialization, packed consumers, or stable
support. Those claims remain `not-tested` in the evidence receipt.

## Evidence and commands

Machine authority and executable fixture:

- [`schema-codec-architecture.json`](../../manifests/schema-codec-architecture.json)
- [`contract-schema.schema.json`](../../schemas/contract-schema.schema.json)
- [`typed contract package`](../../packages/contracts/README.md)
- [`cross-target transcript`](../../fixtures/schema-codec/expected/cross-target.txt)
- [`independent validator`](../../scripts/contracts/validate-schema-authority.py)
- [`cross-target gate`](../../scripts/contracts/test-schema-authority.sh)

The fixture contains 27 Haxe schema/validator invariants, 17 cross-target
behavior vectors, 18 independent serialized-schema mutations, and four
deliberate Haxe compile failures. The independent validator now asserts each
vector's meaning rather than checking canonical syntax alone. It proves missing
versus explicit null, recursively immutable defaults, caller/projection copy
isolation, cyclic array/object rejection, declaration-time named-default
rejection with the retained path-independent rule set, signed-int32 serialization bounds, Unicode-scalar lengths
and ordering, decomposed-string preservation, closed/duplicate fields, rules
on roots/array items/union payloads, enum and tagged-union behavior,
exact/unavailable rules, development encode validation, strict null safety,
JSON Pointer escaping, stable errors, and byte-identical output through Haxe
interpretation, Genes 1.36.3 plus strict TypeScript 5.9.3 on Node 22.17.0, and
stock Haxe PHP on PHP 8.4.7.

The `contract-schema` job in the public repository workflow runs that complete
shell gate with the exact Haxe, Node, TypeScript, Genes, and pinned PHP container
toolchain. Its first hosted run remains pending until these bytes reach `main`;
the architecture manifest does not claim hosted success beforehand.

Acceptance commands:

```bash
bash scripts/contracts/test-schema-authority.sh
bash scripts/check-repository.sh
bash scripts/hooks/test.sh
bash scripts/lint/hx-format-guard.sh
bd lint
bd dep cycles
git diff --check
```

The hxnodejs dependency currently emits upstream Haxe deprecation warnings in
the Genes proof. The repository-owned Haxe source remains formatter-stable and
contains none of the strict-rule weak constructs. The warning does not alter
the generated transcript and is not promoted to a clean-warning support claim.

## Fresh review record

An independent Codex reviewer reran the complete gate and then challenged the
authority rather than accepting its green output. The initial review found ten
gaps: ADR-006 normalization ambiguity, target-native Unicode ordering,
mutable-default aliasing, unenforced serialized int32 limits, absent hosted gate
coverage, named-rule-invalid defaults, field-only rules, an unvalidated encoder,
missing strict null safety, and shallow independent vector checks. The
implementation and this decision were revised for all ten. The first re-review
then found three deeper problems: frozen defaults still exposed mutable nested
wire arrays, named-rule behavior could depend on a diagnostic path and the
document discarded its admitting rule set, and cyclic typed defaults exhausted
the runtime stack. Defaults now use a recursively immutable representation with
fresh-copy projection, rules are path-independent and retained by the document,
and cycles fail closed. The final fresh review reran the complete Haxe,
Genes/strict-TypeScript/Node, and PHP gate, inspected the current bytes, checked
all four compile-negative fixtures, and found no remaining blocker.

## Migration, rollback, and supersession

No released consumer depends on this schema. Before SDK-054 lands, rollback is
removal of the unshipped prototype and reopening ADR-009. Once a generated
contract ships, a breaking IR replacement requires a superseding ADR, old/new
schema readers, explicit migration fixtures, emitter negotiation, and an
ADR-021 support window.

If exact PHP/Genes validators cannot remain equivalent, narrow or split the
rule and schema rather than relabel target-specific behavior as exact. If a
WordPress REST or Gutenberg projection cannot preserve a contract, keep the
typed Haxe/PHP contract usable and mark that projection unsupported. Do not
widen the shared schema to rescue one target.

## Follow-up beads

- `wordpresshx-adr-012`: define output-context trust and native escaping after
  data validation.
- `wordpresshx-adr-019`: govern genuinely unavoidable unsafe boundaries and
  waiver expiry.
- `wordpresshx-sdk-052`: implement typed security boundary values and explicit
  validation/sanitization policies.
- `wordpresshx-sdk-054`: implement ergonomic macro derivation, parser adapters,
  PHP/Genes codecs, one exact REST route, and non-Haxe caller evidence.
- `wordpresshx-sdk-063`: project canonical attributes/defaults/migrations into
  native Gutenberg block contracts and real parser validation.
- `wordpresshx-sdk-121`: build the cohesive typed Gutenberg authoring surface,
  including patterns and reusable editor/server contracts, above exact native
  semantics.
