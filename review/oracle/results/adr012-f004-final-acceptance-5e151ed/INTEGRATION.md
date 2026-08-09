# ADR-009/ADR-012 Oracle acceptance-review integration

## Reviewed subject and identity

- Request: `orq_20260809T190746Z_2da016f8`
- Reviewed commit: `5e151ed02767378ab50f4b703fdd373fa9c0874b`
- Prompt SHA-256: `0a74b34c1dbfed6dead75129d4f6a8ec2915a264fa3cc588ecf9b768e46fcaee`
- Prompt-body SHA-256: `b7cfa3ca2b55761527d4202a97e19c83f65725b6baffbc636c3ee6bc508345de`
- Bundle SHA-256: `ecd2e77bc76eac4c8190f5cbf9ffe6b0a6a493c172c72cc608ef74c63d4736e7`
- Captured response SHA-256: `78d24a58a23101fbdc8b7509a69c8a95769a426a913bcfb32578dedd5d44db17`
- Requested model: GPT-5.6 Pro; ledger-observed model: Pro
- Bound conversation: `convo_c778dd40e136f387`
- Oracle decision: `changes-required` with confidence `0.98`

The completion marker matches the request ID and exact prompt-body digest. The
prompt, bundle, and captured response hashes were recomputed locally before
this disposition. Oracle is advisory evidence; the findings below were checked
against current `main` and reproduced before correction.

## Local disposition

### Prior RR3 sub-findings — retained as closed

The response correctly confirms that the prior direct/private constructor,
class-initializer, `Type.createInstance`, PHP enum discriminator, and evidence
drift reproductions are repaired. The new findings do not invalidate those
specific corrections. Current evidence continues to visit fields, statics,
constructors, and class initialization; verify enum identity, index, name, and
arity; and state that the current WordPress Docker lane did not run.

### ADR012-F004-RR4-F001 — retained, reproduced, and repaired locally

The Oracle found that standard `haxe.Unserializer` can allocate a `JsonPlan`
without calling its private constructor. This bypass did not use `TNew` for
`JsonPlan`, `Type.createInstance`, or a forbidden weak-type token in application
source.

Red evidence on reviewed commit `5e151ed`:

- A new application fixture serialized a legitimate plan, changed the encoded
  payload from `null` to `false`, unserialized it as `JsonPlan`, and completed
  successfully under Haxe interpretation with exit 0.

Correction:

- The typed compiler-profile guard now rejects `haxe.Unserializer` static and
  instance access and direct construction.
- It also rejects `Type.createEmptyInstance`, closing the standard
  constructorless allocation primitive at the same compiler-owned seam.
- `json_plan_unserializer` is an all-target compile-negative fixture. It now
  fails with the intended compiler diagnostic under Haxe interpretation,
  Genes, and stock-Haxe PHP.

The retained scope remains an admitted compiler profile. Arbitrary untrusted
macros are still outside the claim; this correction does not claim runtime
object opacity against code that is allowed to rewrite typed output after the
guard.

### ADR009-RR4-F001 — retained, reproduced, and repaired locally

The Oracle found that a valid generated PHP `Array_hx` containing a malformed
field element reached `snapshotObject`, where direct `current.name` access
escaped as `ErrorException` instead of producing `JsonRejected`.

Red evidence on reviewed commit `5e151ed`:

- `WireValue::ObjectValue(Array_hx::wrap([new stdClass()]))` exited 255 on PHP
  8.4.7 with `Undefined property: stdClass::$name`.

Correction:

- Field payload access is now inside the checked snapshot boundary.
- Null/missing names and values produce a stable `invalid-field` rejection.
- Target exceptions while reading a malformed field become the same rejection;
  no bytes escape.
- Native PHP and Genes probes now cover a field without `name`, a field without
  `value`, and a non-object element inside a valid object container. The
  maintained foreign malformed corpus grows from 19 to 22 semantic cases.

## Other recommendations

- **Retained:** checked-in transcript expectations and native `JSON.parse` / PHP
  `json_decode(..., JSON_THROW_ON_ERROR)` remain independent decoder oracles.
- **Retained:** source-marker counts are bookkeeping and are not treated as the
  proof of the construction boundary. The behavioral compile-negative fixture
  is the owner.
- **Retained:** no fresh WordPress Docker run is required for this bounded JSON
  decision. The current-subject WordPress claim remains explicitly unrun.
- **Deferred by existing authority:** a fresh independent accepted review of
  the post-correction commit is still required before closing
  `wordpresshx-g4.1.1` or returning ADR-009/ADR-012 F004 to bounded accepted
  status. This response reviewed the pre-correction commit and cannot accept
  the later repair. No additional Oracle request was dispatched during this
  reconciliation.

No finding requires a product-owner decision. No broader SDK, WordPress
runtime, publication, production-support, or general compiler claim is granted.

## Verification actually run

- Red `json_plan_unserializer` Haxe interpretation on `5e151ed`: exit 0.
- Red malformed-field native PHP probe on `5e151ed`: exit 255 with escaping
  `ErrorException`.
- `python3 scripts/contracts/validate-schema-authority.py`: passed.
- `python3 scripts/output-context/validate-architecture.py`: passed.
- `bash scripts/contracts/test-schema-authority.sh`: passed Haxe 4.3.7,
  Genes 1.41.4 with strict TypeScript 5.9.3/Node 22.17.0, stock-Haxe PHP 8.4.7,
  both native foreign probes, and both native decoders.
- `bash scripts/output-context/test.sh`: all non-Docker lanes passed, including
  33 compile-negative fixtures and React; the WordPress lane stopped only
  because the local Docker daemon is unavailable.

The issue remains open pending the already-required fresh acceptance review of
the corrected commit.
