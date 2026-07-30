changes-required — high confidence

# WordPressHx ADR-012 F004 regression-repair rereview

**Reviewer:** GPT-5.6 Pro, independent source/evidence review  
**Reviewed repository:** `fullofcaffeine/wordpresshx`  
**Reviewed commit:** `0e01ab5e18fe023e43f2d45e1052bdccef658f05`  
**Reviewed tree:** `a18c63f427d5030e19e0923a7408fe239abd7e4b`  
**Primary finding:** `ADR012-F004`  
**Remediation Bead:** `wordpresshx-g4.1.1`  
**Related bounded authority:** ADR-009 `CanonicalWireJson.encodeChecked`  
**Reviewed at:** `2026-07-30T04:10:42Z`

## Bounded decision

The repair closes the original `TodoCardCodec` raw-JSON return arm: an `OutputCodec<T>` success now carries `WireValue`, and the normal `OutputSinks` path calls `CanonicalWireJson.encodeChecked` before constructing its plan. The new canonical string encoder also correctly escapes all C0 controls, quote, and backslash in the inspected source.

That is not sufficient to accept the boundary. A public `JsonPlan.success(schemaId:String, encoded:String)` factory still lets application code manufacture a modeled success from arbitrary caller-authored bytes without passing through either `OutputCodec`, `Output.jsonDocument`, `OutputSinks.jsonPlan`, or `CanonicalWireJson.encodeChecked`. In addition, the checked encoder does not implement a stable 64-container nesting bound and is not total over values that can reach it from non-null-safe application code. These are decisive source-level defects; unavailable Haxe/Docker lanes do not prevent a bounded `changes-required` decision.

**ADR012-F004 disposition: remains open.** The exact codec-specific defect is structurally repaired, but an equivalent public plan-level raw-success bypass preserves the false success invariant.

**ADR-009 checked-encoder hardening disposition: changes required.** The base ADR-009 architecture is not reopened beyond this narrow checked-encoding surface, but that surface may not return from pending rereview to accepted.

**ADR-012 disposition: may not return from pending rereview to accepted.** No publication, release, legal, or production-support authority is granted.

## Packet integrity and exact identity

Observed:

- `sha256sum -c SHA256SUMS` passed for all four declared packet deliverables.
- The tar archive's embedded Git commit is exactly `0e01ab5e18fe023e43f2d45e1052bdccef658f05`.
- Reconstructing the archive as a Git index produced tree `a18c63f427d5030e19e0923a7408fe239abd7e4b`.
- Reconstructing the parent tree and applying `changes.patch` produced the same subject tree.
- The parent tree was `3f5945022eb5102bef399a7810bbe55404f7ac1a`.
- `git apply --check --whitespace=error-all changes.patch` passed.
- The patch changes 21 tracked files and adds `WireJsonEncoding.hx`.

Declared packet hashes:

- `ORACLE_PROMPT.md`: `9c9c83ea85370cce8f6768397c913d9a3d73c7948661fd4697610098ad498dbe`
- `wordpresshx-source-0e01ab5.tar.gz`: `a9e0ea38ea43f0e625a38b9304b671c25aecc7981c9e74f24ec048f16b1123d2`
- `wordpresshx-repomix.xml`: `1b5eea8dd5f4d9f270183f86238af5bed2ed81f157c0f0992482c81202602632`
- `changes.patch`: `f48352df438552a8f217574d603cd88e9b9a3db215ba12c9a284f20822fb6907`

The uploaded packet archive itself hashes to `32e9585589e35bc4f9fc8e407794eac0fc7bd4a3788d651ed7956abae33a4143`.

## Finding ADR012-F004-RR-F001 — public raw-success construction bypasses the checked sink

**Classification:** blocking-high  
**Confidence:** high  
**Disposition:** keep `ADR012-F004` open; keep `wordpresshx-g4.1.1` in progress

### Exact evidence

- `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx:86-95` changes codec success to `EncodedValue(value:WireValue)`. This part of the repair is correct.
- `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx:79-87` routes that normal codec result through `CanonicalWireJson.encodeChecked`.
- `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx:258-276` exposes public type `JsonPlan` and public factory `JsonPlan.success(schemaId:String, encoded:String)`.
- `fixtures/output-context/test/Main.hx:20` imports `wordpress.hx.output.prototype.OutputSinks.JsonPlan`, demonstrating that code outside the `OutputSinks` class can name the type.
- `packages/contracts/src/wordpress/hx/contracts/CanonicalWireJson.hx:9-11` also leaves an unchecked public `encode(value:WireValue):String` entry point.
- `scripts/output-context/test.sh:149-221` contains no compile-negative case preventing application code from calling `JsonPlan.success`.
- The independent static boundary scan found `public_raw_success_factory=true` and `negative_fixture_blocks_json_plan_success=false`.

A caller can bypass the claimed sole conversion boundary with the equivalent of:

```haxe
import wordpress.hx.output.prototype.OutputSinks.JsonPlan;

final forged = JsonPlan.success(
  "forged.v1",
  "{\"title\":\"caller-authored bytes\"}"
);
```

The second argument can be malformed JSON, invalid Unicode in a target string, duplicate-key JSON, a raw C0 byte, or bytes with any other property the checked encoder was intended to exclude. The resulting object has a non-empty `encoded` value and an empty `failureReason`, so it is indistinguishable at the plan surface from the sink-created success.

### Consequence

The repository claim that the final sink is the sole conversion to successful JSON bytes is false as an enforced architecture invariant. The README statement that application codecs cannot brand caller-authored strings as valid JSON is also not enforced. Native consumers trust `failureReason == ""` and immediately call `JSON.parse` or `json_decode(..., JSON_THROW_ON_ERROR)`; a forged plan recreates the original false-success condition without involving a codec.

This factory existed before the repair. That does not make it acceptable: the requested rereview explicitly required checking that no public/app surface could forge successful JSON bytes. It means the repair closes one path while leaving the invariant open through an equivalent path.

### Required correction

- Remove public `JsonPlan.success` and `JsonPlan.failure` factories.
- Make successful plan construction private to `OutputSinks`, for example through a private constructor plus narrowly scoped `@:allow(wordpress.hx.output.prototype.OutputSinks)` authority.
- Expose only read-only plan observations to consumers; do not expose any public constructor/factory that accepts an already encoded `String` and creates success.
- Reassess whether public unchecked `CanonicalWireJson.encode` belongs on the application-visible API. If retained for internal/schema projection use, give it explicitly unsafe/internal authority and ensure no public success wrapper accepts its result.
- Do not treat `WireJsonEncoding.JsonEncoded(String)` as an unforgeable capability; Haxe enum constructors are public. Only a private sink-owned construction path can carry the invariant.

### Smallest decisive closure test

Add a compile-negative fixture outside the prototype package that imports `OutputSinks.JsonPlan` and attempts both `JsonPlan.success("x", raw)` and direct construction. The fixture must fail on Haxe interpretation, Genes/strict TypeScript generation, and stock-Haxe PHP compilation with an accessibility diagnostic. Add a static gate asserting that no public function accepting `encoded:String` or raw JSON bytes can construct a successful `JsonPlan`.

## Finding ADR009-RR-F001 — the advertised depth-64 limit is leaf-dependent and admits 65 nested containers

**Classification:** blocking-medium  
**Confidence:** high  
**Disposition:** keep `wordpresshx-g4.1.1` in progress; create or link a focused ADR-009 child blocker if the correction is split

### Exact evidence

- `packages/contracts/src/wordpress/hx/contracts/CanonicalWireJson.hx:17-24` defaults `maxDepth` to 64 and starts validation at depth 0.
- `CanonicalWireJson.hx:27-30` rejects only when `depth > maxDepth`.
- `CanonicalWireJson.hx:43-51` and `54-74` increment depth only when visiting a child.
- `fixtures/output-context/test/Main.hx:52-66` creates nested singleton arrays.
- `fixtures/output-context/test/Main.hx:129` tests only depth 66.
- `fixtures/output-context/runtime/browser.mjs:49-52` and `runtime/wordpress-probe.php:116-123` merely assert that this one clearly over-limit fixture fails.
- The ADR-012 receipt records `"depthFailure": "explicit-at-64"`, but no exact 64/65 boundary vector exists.

A line-for-line independent model of the source algorithm produced:

```text
64-empty-arrays=true
65-empty-arrays=true
66-empty-arrays=false
64-arrays-plus-scalar=true
65-arrays-plus-scalar=false
64-empty-objects=true
65-empty-objects=true
66-empty-objects=false
```

Thus the same 65-container nesting is accepted when the innermost container is empty but rejected when that innermost container has a scalar child. The bound is measuring visited value-node distance, not JSON container nesting, and its result depends on leaf occupancy.

As an adjacent runtime observation, local PHP 8.4.16 `json_decode` with a configured depth of 64 rejected 64 nested arrays regardless of whether the innermost array was empty or contained `null`. The repository probes use decoder depth 512, so that observation is not itself the acceptance basis; it demonstrates why the checked encoder must define its own depth measure precisely instead of assuming target semantics.

### Consequence

The claimed hard limit “values exceeding depth 64” is neither precisely defined nor implemented as a stable nesting limit. A cyclic value still eventually reaches the guard under the default, but the exact boundary and resource bound are one level looser for empty containers. The current test at 66 cannot detect the off-by-one/leaf-shape behavior.

### Required correction

Define the limit explicitly as JSON **container nesting**, independent of whether the deepest container is empty. One valid formulation is:

- scalar root: container depth 0;
- root array/object: container depth 1;
- each nested array/object adds one;
- reject a container whose depth would exceed `maxDepth`;
- scalar children do not add a container level.

Implement that definition consistently for arrays and objects. Preserve non-positive configuration rejection. Prefer validating and producing a private immutable snapshot or encoded result in one traversal so the same measured tree is later encoded.

### Smallest decisive closure test

For both arrays and objects, and on Haxe interp, Genes/Node, and stock-Haxe PHP:

- `maxDepth=1`: scalar and one root container pass; a nested container fails;
- `maxDepth=64`: 64 nested empty containers pass; 65 fail;
- repeat with a scalar in the deepest container;
- repeat with mixed array/object nesting;
- `maxDepth=0` and negative values reject without bytes;
- cyclic array and cyclic object reject without stack overflow or exception escaping the modeled result.

The test must assert both result variant and the absence of encoded bytes on rejection.

## Finding ADR009-RR-F002 — `encodeChecked` is not total over publicly constructible `WireValue` shapes

**Classification:** blocking-high  
**Confidence:** high for the exposed gap; medium-high for exact target exception forms because the compiled Haxe lanes were unavailable  
**Disposition:** keep `wordpresshx-g4.1.1` in progress and link a focused ADR-009 hardening blocker

### Exact evidence

- `packages/contracts/src/wordpress/hx/contracts/WireValue.hx:4-10` exposes constructors carrying `String`, `Array<WireValue>`, and `Array<WireField>` reference payloads.
- `WireValue.hx:13-16` exposes field records carrying `name:String` and `value:WireValue`.
- `CanonicalWireJson.hx:21-40`, `43-45`, `54-59`, and `80-104` dereference these values without runtime null/malformed-shape checks.
- `scripts/output-context/test.sh:91-98`, `100-114`, and `129-135` enables strict null safety only for `wordpress.hx.output.prototype`; it does not enable it for the root-package application codec in `test/Main.hx` or for `wordpress.hx.contracts` in this output gate.
- Even the separate ADR-009 gate's strict package setting is compile-time, not a runtime validation barrier against values originating in non-null-safe or foreign code.
- `CanonicalWireJson.hx:54-60` sorts object fields by `UnicodeScalarOrder.compare` before validating field-name Unicode.
- `CanonicalWireJson.hx:127-139` performs a second sort/traversal after preflight and retains a throwing duplicate-field path.
- The independent source audit found `encoder_has_explicit_null_guard=false`, `output_gate_null_safety_prototype_only=true`, and `object_sorts_before_name_validation=true`.

Public/app code can construct shapes such as a null `WireValue`, `StringValue(null)`, `ArrayValue(null)`, `ArrayValue([null])`, `ObjectValue(null)`, or a field with null name/value when compiled outside a strict null-safe package or received through an unsafe/foreign boundary. `encodeChecked` has no modeled rejection for these shapes. It can fail while switching, reading `.length`, copying/sorting, or converting a string instead of returning `JsonRejected`.

Malformed object-key text has a separate ordering problem: the Unicode scalar comparator sees the key before `validateString`. On targets where malformed UTF-8 or an unpaired surrogate makes iteration fail, preflight can escape through a target-specific exception instead of the promised `JsonRejected("...invalid-unicode")`. The exact exception form was not executed here, so that part is explicitly an inference from control flow and target string APIs, not a claimed observed crash.

### Consequence

The checked encoder is not a total function from all values reachable through its public type surface to `JsonEncoded | JsonRejected`. A malicious or merely non-strict application codec can crash the final sink instead of producing the explicit failure/no-bytes outcome claimed by the packet. Sorting unvalidated keys also leaves target divergence exactly where the hardening is supposed to normalize target behavior.

### Required correction

- Extend the output-context gate's strict null-safety scope to the application fixture and contracts package, but do not rely on compile-time null safety alone.
- Add explicit runtime guards for null enum values, null string/container payloads, null array elements, null field records, null field names, and null field values.
- Validate every field name before invoking `UnicodeScalarOrder.compare`.
- Snapshot validated arrays/objects into a private immutable representation and encode that snapshot, or validate and encode in a single traversal. Avoid a second traversal that can retain exception-only invariant checks.
- Convert all malformed public-input conditions into stable `JsonRejected` reasons with no bytes.

### Smallest decisive closure test

Add an application-package codec corpus covering:

- null root `WireValue`;
- `StringValue(null)`;
- null array/object payload;
- null array element;
- null field record, null field name, and null field value;
- lone high surrogate, lone low surrogate, and malformed UTF-8 as both values and object keys where representable;
- duplicate keys adjacent and non-adjacent before sorting;
- mutation of source arrays after plan creation and, where a target permits it, during checked encoding.

Each case must either fail compilation under a deliberately global strict-null gate or return `JsonRejected` with zero bytes. No uncaught exception is an acceptable result. Run the same corpus on Haxe interp, Genes/strict TypeScript/Node 22.17.0, and stock-Haxe PHP 8.4.7.

## What the repair did establish

The following conclusions held under source inspection or the independent probes actually available:

- Codec success changed from caller-authored bytes to `EncodedValue(WireValue)` (`Output.hx:86-95`).
- The normal `restJson`/`scriptData` sink route calls `encodeChecked` (`OutputSinks.hx:57-63`, `79-87`).
- `encodeString` escapes quote, backslash, all named JSON controls, and every remaining C0 code point (`CanonicalWireJson.hx:141-169`).
- The checked path explicitly rejects non-positive configured depth (`CanonicalWireJson.hx:17-20`).
- Validated object input is copied and canonically sorted; exact duplicate keys are detected during preflight (`CanonicalWireJson.hx:54-74`).
- String values are checked for UTF-16 surrogate pairing on UTF-16 targets and UTF-8 validity otherwise (`CanonicalWireJson.hx:76-104`).
- The expected plan's 32 C0 entries all decoded correctly under the available Node 22.16.0 `JSON.parse` and PHP 8.4.16 `json_decode(..., JSON_THROW_ON_ERROR)` probes. No successful encoded string contained a raw C0 byte.
- The expected plan's unsupported-domain, depth, and invalid-Unicode result objects contain no encoded bytes.
- A native Node probe round-tripped quote, backslash, and non-BMP text. Node can represent lone high and low surrogate target strings; actual compiled checked-encoder rejection was not rerun.
- A native PHP probe confirmed that raw malformed UTF-8 is rejected by `json_decode(..., JSON_THROW_ON_ERROR)`.
- No `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` token was introduced in the relevant Haxe prototype/contracts/test surfaces. The only additions-only textual hit was documentation inside `.beads/issues.jsonl`, not Haxe code.
- The ADR-009 and ADR-012 receipts remain marked pending rereview and explicitly set publication authorization to false.
- The remediation Bead is still `in_progress`, which is the correct state for this decision.

## Independent execution and validator results

### Passed or produced decisive observations

- Packet `sha256sum -c` — passed.
- Tar embedded commit extraction — exact commit matched.
- Reconstructed source tree — exact tree matched.
- Parent-plus-patch reconstruction — exact subject tree matched.
- Patch whitespace/application check — passed.
- `python3 scripts/output-context/validate-architecture.py` — passed: 11 contexts, 15 forbidden edges, 36 independent mutations.
- `python3 scripts/contracts/validate-schema-authority.py` — passed: 17 vectors, 27 Haxe invariants, 18 independent mutations.
- Independent Node expected-plan decoder probe — passed on Node v22.16.0.
- Independent PHP expected-plan decoder probe — passed on PHP 8.4.16.
- Independent source-equivalent depth model — reproduced the 65-empty-container acceptance.
- Independent source boundary audit — reproduced the public success factory, unchecked encoder, null-guard absence, narrow null-safety scope, and sort-before-validation order.
- Local PHP nesting probe — recorded target depth behavior; it is supporting evidence only because the exact pinned PHP version was unavailable.

### Attempted but not executable in this environment

- `bash scripts/output-context/test.sh` — stopped because Docker is unavailable.
- `bash scripts/contracts/test-schema-authority.sh` — stopped because `haxelib` is unavailable.
- `bash scripts/check-repository.sh` — reached a historical-ancestry assertion that cannot be satisfied by the synthetic archive Git index; this is an environment/provenance limitation, not a subject defect.
- Haxe 4.3.7 interpretation — unavailable.
- Genes 1.38.0 plus strict TypeScript 5.9.3 and Node 22.17.0 — unavailable.
- Stock-Haxe PHP generation and execution on PHP 8.4.7 — unavailable.
- React 18.3.1 SSR — the internal npm mirror did not contain the package.
- WordPress 7.0/MariaDB runtime — Docker is unavailable.

The implementer's receipts for those lanes were inspected but were not counted as independent execution proof.

## Commands actually run

Principal commands, with outcomes, were:

```text
unzip -q /mnt/data/wordpresshx-adr012-f004-rereview-0e01ab5.zip -d /mnt/data/wordpresshx-adr012-f004-rereview-0e01ab5
(cd packet && sha256sum -c SHA256SUMS)
gzip -dc wordpresshx-source-0e01ab5.tar.gz | git get-tar-commit-id
git write-tree                         # reconstructed archive index
git apply --check --whitespace=error-all changes.patch
python3 scripts/output-context/validate-architecture.py
python3 scripts/contracts/validate-schema-authority.py
bash scripts/output-context/test.sh    # environment stop: docker unavailable
bash scripts/contracts/test-schema-authority.sh  # environment stop: haxelib unavailable
bash scripts/check-repository.sh       # synthetic-history ancestry limitation
node probes/native-json-probe.mjs fixtures/output-context/expected/context-plan.txt
php probes/native-json-probe.php fixtures/output-context/expected/context-plan.txt
python3 probes/depth-model.py
php probes/php-depth-semantics.php
python3 probes/source-boundary-audit.py
rg/grep source and patch scans for forbidden weak-type tokens, encoder call sites, success constructors, and negative fixtures
npm install react@18.3.1 react-dom@18.3.1  # internal-registry 404
```

## Environment and limitations

Available environment:

- Node `v22.16.0` rather than the pinned `v22.17.0`;
- npm `10.9.2`;
- PHP `8.4.16` rather than the pinned `8.4.7`, with JSON but without `mbstring`;
- Python `3.13.5`;
- no Haxe, haxelib, Lix, or Docker;
- no pinned Gutenberg TypeScript/React installation.

Accordingly, byte identity across Haxe interp, Genes/TypeScript/Node, and generated PHP; actual high/low-surrogate handling in every compiled target; React SSR; and WordPress 7.0 consumption remain unexecuted in this review. Those limitations reduce confidence in unexecuted parity claims but do not weaken the three source-level blockers above.

## Required Bead and authority disposition

- `wordpresshx-g4.1.1`: remain `in_progress`; do not close.
- Add the public `JsonPlan.success` compile-negative requirement directly to this Bead because it is an equivalent F004 bypass.
- Add exact empty/non-empty 64/65 depth vectors and malformed/null `WireValue` totality vectors to this Bead or a linked priority-0 ADR-009 child blocker. The parent Bead cannot close until the linked blocker is accepted.
- ADR012-F004: **remains open**.
- ADR-009 checked-encoder hardening: **pending changes-required**.
- ADR-009 may return to accepted within this bounded prototype scope: **no**.
- ADR-012 may return to accepted within this bounded prototype scope: **no**.
- Publication authorized: **no**.

## Final bounded conclusion

The implementation materially improves the original codec path and appears to fix the specific C0 escaping bug on the expected transcript. It does not yet enforce the claimed success invariant as an architecture boundary. Public raw-success construction, unstable depth semantics, and non-total handling of publicly reachable malformed `WireValue` shapes require correction and decisive cross-target tests before ADR-009/ADR-012 can be accepted again.
