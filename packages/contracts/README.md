# Typed contracts

This package is the executable ADR-009 architecture slice for data shared by
Haxe domain code, native PHP, Genes browser output, WordPress REST routes, and
Gutenberg metadata. It establishes a single typed semantic schema before any
target projection. It is not yet the supported SDK-054 authoring API or a raw
JSON parser.

The boundary is deliberately closed:

1. A target adapter parses foreign bytes into `WireValue`, the JSON-compatible
   sum type. Missing fields are represented by `Presence`; explicit JSON null
   is represented by `NullableValue`.
2. A `SchemaDocument` retains defaults as a recursively immutable
   `FrozenWireValue`, binds its rule set, and rejects invalid bounds, duplicate
   identities, cycles, nested nullability/refinement, conflicting rule roles,
   invalid defaults, and incomplete adjacent migration chains. Each runtime or
   schema projection receives a fresh mutable wire copy.
3. `RefinedNode` attaches exact validators or explicit sanitizer descriptors to
   any value position. `ContractValidator` applies the schema and rules before
   a domain codec reads the value.
4. A `ContractCodec<T>` maps only a validated value into `T` and maps `T` back
   to the wire algebra. Impossible post-validation branches are internal
   defects, not user-input diagnostics.
5. Target projectors consume the same canonical schema IR. A projector that
   cannot preserve a constraint must fail rather than silently widen it.

Validation and sanitization are separate. Validators decide whether input is
admissible and participate in cross-target parity. Sanitizer references record
an explicit transform, including documented native WordPress relations, but
decoding never mutates input implicitly. Authorization and output-context
escaping are separate contracts owned by later ADRs.

The fixture uses the builder classes directly so the IR and runtime behavior
can be reviewed now. That verbosity is not the intended application surface.
SDK-054 will derive the schema, structural codec, REST projection, and browser
client from concise Haxe declarations; hand-written code remains limited to
domain construction and named rules that cannot be derived safely.

Run the complete local proof from the repository root:

```bash
bash scripts/contracts/test-schema-authority.sh
```

The gate validates the closed serialized schema, rejects an independent
mutation corpus, checks formatter, strict null safety, and weak-type policy,
proves four deliberate compile failures, validates development encoder output,
runs strict TypeScript over Genes output, and compares one canonical transcript
byte-for-byte across Haxe interpretation, Genes/Node 22.17.0, and PHP 8.4.7. It
includes missing/null, immutable and named-rule-checked defaults, cyclic-default
rejection, projection-copy isolation, path-independent named rules, signed-int32
overflow rejection, Unicode-scalar lengths and key ordering, decomposed-string
preservation, refined roots/items/union payloads, tagged unions, JSON Pointer
escaping, exact rules, unknown fields, duplicate fields, and structural/domain
failures. The public `contract-schema` workflow job runs the same complete gate.

Contract canonical bytes preserve strings and are stored in the installed
content-addressed schema registry. Only their restricted-ASCII identity,
version, and SHA-256 reference enter ADR-006's separately NFC-normalized
semantic plan, so plan canonicalization cannot mutate contract payload bytes.

Production foreign-byte parsers, macro derivation, PHP/Genes emitters,
WordPress REST registration, block-attribute projection, migration execution,
PHP 7.4 evidence, and packed-consumer support remain follow-up work.
