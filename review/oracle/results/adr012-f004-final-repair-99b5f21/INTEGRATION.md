# ADR-009/ADR-012 Oracle review integration

## Reviewed subject

- Request: `orq_20260809T014239Z_9ab978af`
- Reviewed commit: `99b5f21f2e36bef907650cd7c2b1d30d61dadfbd`
- Reviewed tree: `209a3f4cc53626c0ceb1de6bd5520e5cb3409538`
- Oracle decision: `changes-required`
- Oracle confidence: `0.97`
- Captured response SHA-256: `16feda7779a0ec6bf83f81b12a2b64b52da06a8133ab12eb93c7316902493cfd`

The Oracle response is advisory evidence. Each material claim below was checked
against current source and reproduced before implementation.

## Local disposition

### ADR012-F004-RR3-F001 — retained and repaired

The review correctly found that `OutputContextBoundaryGuard` scanned ordinary
instance and static fields but not `ClassType.constructor` or `ClassType.init`.
It also correctly found that checking only `TNew` left reflective construction
available.

Red evidence on the reviewed implementation:

- A direct `@:privateAccess new JsonPlan(...)` inside an instance constructor
  compiled with exit 0.
- The same construction inside `static function __init__()` compiled with exit
  0.
- `Type.createInstance(JsonPlan, ...)` compiled with exit 0.

Correction:

- The post-typing guard now visits fields, statics, the class constructor, and
  the class initialization expression.
- The admitted output-context profile rejects `Type.createInstance` itself,
  including taking an alias to it. This is an explicit profile restriction and
  avoids claiming that a later runtime alias can be reconstructed reliably.
- Five all-target construction negatives now cover the ordinary private
  constructor, direct private-access construction, instance-constructor
  placement, class-initializer placement, direct reflection, and reflection
  aliasing as the relevant grouped boundary cases.

Green evidence: the new fixtures fail with the intended compiler-owned
diagnostic under Haxe interpretation, Genes, and stock-Haxe PHP as part of
`scripts/output-context/test.sh`.

### ADR009-RR3-F001 — retained and repaired

The review correctly found that the checked encoder accepted PHP
`new WireValue('Unknown', 0, array())` as `NullValue` because it trusted the
valid numeric index without checking the runtime constructor identity.

Red evidence: the focused native PHP probe exited 255 with
`valid-index-unknown-tag emitted bytes`.

Correction:

- `encodeChecked` now verifies the enum identity, constructor index,
  constructor name, and declared parameter count before switching on the typed
  value.
- Any exception while inspecting a malformed foreign envelope becomes the
  stable `invalid-wire-value` rejection with no bytes.
- Payload-domain checks remain the second layer and reject missing or malformed
  values using the stable payload-specific reason where the target runtime
  preserves a declared slot.
- Native PHP cases now cover a valid index with an unknown tag, mismatched
  tag/index, extra parameters on the null constructor, and missing parameters.
- Native Genes cases now cover an unknown enum identity and a missing Bool
  payload. The maintained foreign corpus grows from 13 to 19 cases.

Green evidence: `scripts/contracts/test-schema-authority.sh` passes Haxe 4.3.7
interpretation, Genes 1.41.4 with strict TypeScript 5.9.3 and Node 22.17.0, and
stock-Haxe PHP 8.4.7. Both native probes pass, and all nine successful encoded
vectors decode through native JavaScript and PHP decoders.

### ADR012-EVIDENCE-RR3-F001 — retained and repaired

The review correctly found that the active ADR-012 receipt called the current
WordPress lane passed/runtime-tested even though Docker was unavailable for the
reviewed subject.

Correction:

- The active verification result now says
  `not-run-current-subject-docker-unavailable`.
- The broader claim now says
  `historical-runtime-tested-current-subject-not-run`.
- Historical immutable WordPress run identities remain recorded separately and
  are not presented as execution of the current subject.

The missing Docker run does not block the bounded JSON-plan correction. It does
remain required before restoring a current WordPress-runtime claim.

## Verification and remaining authority

- `bash scripts/contracts/test-schema-authority.sh`: passed.
- `bash scripts/output-context/test.sh`: every non-Docker lane passed; stopped
  only because the Docker daemon was unavailable before WordPress 7.0/MariaDB.
- `python3 scripts/contracts/validate-schema-authority.py`: passed.
- `python3 scripts/output-context/validate-architecture.py`: passed.
- Strict Haxe weak-token scan for the touched contract/output-context surfaces:
  zero findings.

The reviewed request is now fully reconciled, but it reviewed the pre-correction
commit. `wordpresshx-g4.1.1`, ADR-009 checked JSON, and ADR-012 F004 therefore
remain pending until a fresh independent review accepts the corrected commit.
No WordPress runtime, production SDK, publication, or general compiler claim is
broadened by this integration.
