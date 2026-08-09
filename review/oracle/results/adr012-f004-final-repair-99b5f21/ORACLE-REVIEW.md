Decision: `changes-required`
============================

**Confidence: 0.97 (high).**

Commit `99b5f21f2e36bef907650cd7c2b1d30d61dadfbd` fixes most of the retained defects and correctly repairs the Genes 1.41.4 evidence identity, but the bounded invariant is still not established. I found **two blocking boundary defects** and one major evidence-record inconsistency:

1.  `OutputContextBoundaryGuard` does not inspect class constructors or class `__init__` expressions, and it only recognizes `TNew`. The supplied `@:privateAccess` negative therefore proves one syntactic location, not the claimed construction boundary.
    
2.  `CanonicalWireJson.encodeChecked` range-checks `Type.enumIndex(value)` but does not validate that a foreign `WireValue` has a coherent constructor identity/discriminator. The foreign tests cover index `99`, but not a forged **valid** index such as PHP `new WireValue('Unknown', 0, array())`. That leaves the required foreign-shape totality/semantic-integrity claim open and is likely an actual acceptance bypass.
    
3.  The ADR-012 evidence receipt still says the WordPress lane `"passed"` / `"runtime-tested"` even though the exact-subject evidence explicitly says Docker stopped the lane and no current WordPress result is claimed.
    

The missing current WordPress run is **not itself a blocker to the bounded JSON-plan invariant**. The stale receipt claim about that run is an evidence problem.

Retained findings
-----------------

Finding

Disposition

Current evidence

`ADR012-F004-RR2-F001`

**closed**

`OutputSinks.hx:79-92` maps `EncodingFailure("")` only to `PlanRejected("codec-rejected-without-reason")`; `JsonPlan.fold` has disjoint encoded/rejected handling at `273-278`. `test-regression/EmptyFailureMain.hx:15-28` explicitly fails if the empty failure emits bytes or changes reason.

`ADR012-F004-RR2-F002`

**open**

The exact supplied `@:privateAccess` fixture is caught (`test-negative/json_plan_private_access/Main.hx:3-6`, `scripts/output-context/test.sh:290-295`), but the guard only visits `classType.fields` and `classType.statics` at `OutputContextBoundaryGuard.hx:26-35`. It omits the separate constructor and `__init__` expressions.

`ADR009-RR2-F001`

**closed**

`CanonicalWireJson.hx:33-47` explicitly rejects null/non-Bool `BoolValue` and null/non-Int/out-of-range `IntegerValue`. The Haxe boundary corpus covers nulls at `WireJsonBoundaryTest.hx:21-24`; Genes/PHP foreign probes additionally exercise wrong scalar types, fractional integers, bounds, NaN, and Infinity.

`ADR009-RR2-F002`

**closed**

The maintained boundary corpus runs on interp, Genes, and PHP at `scripts/contracts/test-schema-authority.sh:151-197`; generated Genes and PHP additionally receive the target-native foreign probes at `198-212`. Genes is no longer omitted.

`ADR009-RR2-F003`

**closed**

`WireJsonEncoding.hx:3-12` now says only a `JsonEncoded` returned directly by `encodeChecked` carries the decoder-safety claim and explicitly says the public constructor is merely a transport shape. `OutputSinks.hx:81-84` consumes only the immediate encoder result. I found no selected production consumer treating independently created `JsonEncoded` as authority.

**Earlier depth closure remains sound.** `encodeChecked` begins at container depth zero; arrays and objects increment before the hard-limit check (`CanonicalWireJson.hx:20-30,57-82`). `WireJsonBoundaryTest.hx:49-68` distinguishes depth 64 from 65 across empty/scalar arrays, objects, and mixed structures and checks invalid configured limits. The fixed expected transcript records those exact results at `wire-json-boundary.txt:17-38`. Cycles are also bounded by the same limit at `WireJsonBoundaryTest.hx:70-77`.

Blocking finding 1 — construction guard is not a complete guard
---------------------------------------------------------------

**`ADR012-F004-RR3-F001` — blocking, confidence 0.99**

### Observed source fact

`OutputContextBoundaryGuard.validateModules` does this:

*   visits `classType.fields.get()` — `OutputContextBoundaryGuard.hx:31`
    
*   visits `classType.statics.get()` — line 32
    
*   searches those expressions for `TNew(JsonPlan, ...)` — lines `48-59`
    

It never visits `classType.constructor` or `classType.init`.

That distinction is not speculative. In Haxe 4.3.7's macro model, `ClassType.fields`, `statics`, `constructor`, and `init` are distinct properties; the constructor and `__init__` expression are not part of the two arrays the guard scans. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/haxe/macro/Type.hx)

Therefore moving the maintained `@:privateAccess new JsonPlan(...)` pattern from `static main()` into an ordinary class constructor puts the `TNew` outside the guard traversal.

The closed state does improve the design: `JsonPlan.state` is private and the state algebra itself is private (`OutputSinks.hx:262-285`). But it does not compensate for an incomplete compiler-profile guard. An admitted application can obtain a legitimate plan, privately inspect its non-null state, and construct another `JsonPlan` from that inferred state inside an unvisited constructor. The copied successful bytes still came from the checked encoder, but **the successful plan was constructed outside `OutputSinks`**, directly contradicting the required construction invariant.

### The guard is also expression-shape incomplete

Even in expressions it does inspect, it recognizes only `TNew`. Haxe 4.3.7's standard `Type.createInstance` invokes a class constructor reflectively and is a call expression, not `TNew`; both the JavaScript and PHP standard implementations expose this mechanism. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/js/_std/Type.hx)

I found no selected profile rule banning `Type.createInstance`; the forbidden-token gate in `scripts/contracts/test-schema-authority.sh:86-95` bans textual `Dynamic`, `Any`, `Reflect`, `untyped`, and `cast`, not `Type`. I am not making this a separate finding because the constructor traversal hole alone decisively falsifies the claim, but a repair that merely adds `classType.constructor` would still leave the broader “all construction paths” wording too strong.

The architecture validator is insensitive to this defect: `validate-architecture.py:389-401` checks only that `Context.onAfterTyping(validateModules)` and the diagnostic string exist. It does not inspect traversal completeness.

Blocking finding 2 — foreign enum-shape validation is incomplete
----------------------------------------------------------------

**`ADR009-RR3-F001` — blocking, confidence 0.91**

### Observed source fact

At `CanonicalWireJson.hx:33-54`, after the null check, the only envelope validation is:

*   `Type.enumIndex(value)` at line 37;
    
*   reject indices outside `0...5` at `38-40`;
    
*   then switch on the typed enum.
    

There is no check of runtime enum identity, constructor name/tag, index/tag consistency, or parameter cardinality before that switch.

The target-native tests expose exactly why this matters:

*   Genes tests the fake value `{_hx_index: 99, __enum__: "wordpress.hx.contracts.WireValue"}` at `verify-wire-json-foreign.mjs:35-39`.
    
*   PHP tests `new WireValue('Unknown', 99, array())` at `verify-wire-json-foreign.php:40`.
    

They therefore prove that an **out-of-range** fake index is rejected. They do not test malformed values whose forged index is **within 0–5**.

For Haxe 4.3.7 JavaScript, `Type.enumIndex` directly returns `_hx_index`. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/js/_std/Type.hx) For stock PHP it directly returns the enum object's `index`, and Haxe's PHP generator emits typed enum-index expressions as `->index`. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/php/_std/Type.hx)

That makes this PHP value the decisive missing red vector:

`new WireValue('Unknown', 0, array())`

Its index passes `CanonicalWireJson.hx:38`. Nothing in the checked encoder verifies that `"Unknown"` is actually `NullValue`.

I did **not** execute that vector against the exact generated PHP/Genes artifacts, so I distinguish the final runtime consequence as inference rather than observation. However, the public PHP representation used by the maintained probe makes the malformed shape demonstrably reachable, and the checked source has no discriminator-consistency validation. Given Haxe's index-based enum lowering, acceptance as the index-0 constructor is the likely behavior. Either way, the repository has not established the required invariant that every reachable malformed foreign `WireValue` returns a stable rejection rather than bytes or an exception.

This is materially different from the now-closed null-Bool/null-Integer issue.

Test sensitivity and oracle quality
-----------------------------------

The positive evidence is substantially stronger than in the previous revisions. The recorded schema gate compares fixed transcripts byte-for-byte across Haxe interp, Genes/strict TypeScript/Node, and PHP (`test-schema-authority.sh:146-149`), and does the same for the focused malformed/depth boundary transcript at `194-197`. Native Node and PHP then parse every encoded boundary vector using `JSON.parse` and `json_decode(..., JSON_THROW_ON_ERROR)` (`verify-wire-json-transcript.mjs:7-17`; `.php:14-28`). The fixed boundary transcript contains nine actual encoded byte strings rather than result tags alone. The output-context plan likewise contains exact C0 escaping for all 32 control characters and explicit no-byte failure states.

The foreign probes are also genuinely independent target-side perturbations rather than a second Haxe implementation. Their weakness is **coverage of the runtime enum envelope**: 12 malformed payload/category values plus one index-99 fake is not enough to establish totality over a public runtime representation whose tag/index can disagree.

The construction negatives are similarly useful but too location-specific. `json_plan_private_access` has only a static `main()` expression, so it cannot detect that the guard omits constructors or `__init__`. The static architecture validator likewise only verifies the guard's presence.

### Commands recorded as run by the supplied evidence

The evidence file at lines `12-46` records:

*   `bash scripts/contracts/test-schema-authority.sh` — exit 0.
    
*   `bash scripts/output-context/test.sh` — exit 1 after all non-Docker portions and React passed; Docker daemon unavailable.
    
*   `bash scripts/check-repository.sh` — exit 0.
    
*   the commit hook sequence — passed.
    
*   the push hook sequence — passed and pushed `99b5f21` to `main`.
    

I did **not** rerun those repository gates.

What I did execute independently on the packet was `sha256sum -c SHA256SUMS` and a reconstruction/check of all 52 selected source files against the byte counts and SHA-256 values in `SOURCE_INVENTORY.tsv`; all matched. Haxe, Lix, and Docker are absent in this review environment. The available Node is 22.16.0 and PHP is 8.4.23, not the recorded exact Node 22.17.0/PHP 8.4.7 combination, so I did not substitute them as exact-subject execution evidence.

One packet limitation: `scripts/contracts/test-schema-authority.sh:146` references `fixtures/schema-codec/expected/cross-target.txt`, but that file is not among the 52 selected packet files. I therefore cannot independently inspect that particular fixed oracle's contents. The more directly relevant `wire-json-boundary.txt` and `context-plan.txt` are present. I treat the missing ordinary transcript as an **evidence limit**, not an additional finding.

Genes 1.41.4 binding
--------------------

This repair is **closed and honest for the current proof lanes**.

`packages/gutenberg/haxe_libraries/genes-ts.hxml:1-5` binds:

*   version `1.41.4`;
    
*   commit `98a51bdb7a5a1e31002b9ba47855d41905ea48ef`;
    
*   both the cache source path and `-D genes-ts=1.41.4`.
    

`packages/gutenberg/dependency-lock.json:25-36` names the same release and commit.

Both relevant scripts now execute their Genes compilation from `packages/gutenberg` and use `-lib genes-ts`: schema gate at `test-schema-authority.sh:73-78,105-130,157-181`, output-context gate at `test.sh:71-74,105-130,197-215`.

`packages/cli/dependency-lock.json:3-9` still legitimately describes a separate classic Genes 1.38.0 profile; I found no current proof-lane path returning to that lock.

`adr-012-output-context-safety.json:114` still contains the historical statement that the “second correction” used 1.38.0. Because it is nested under `secondCorrectionClaims`, I do not treat it as the current proof identity. The current top-level receipt fields at `40` and `51` say 1.41.4.

New evidence finding
--------------------

**`ADR012-EVIDENCE-RR3-F001` — major, confidence 0.99**

The exact-subject evidence says at `wordpresshx-adr012-f004-final-repair-evidence.txt:23-29` that `scripts/output-context/test.sh` stopped because Docker was off and:

> no WordPress 7.0/MariaDB result is claimed for this commit.

But the active receipt says:

*   `"wordpressTextAttributeTextareaUrlKsesJsonBlockRestAndAdmin": "passed"` at `manifests/evidence/adr-012-output-context-safety.json:69`;
    
*   `"wordpressNativeEscaping": "runtime-tested"` at line `223`.
    

Those are not safely qualified as historical exact-commit results. They overstate the execution evidence of `99b5f21`.

**The correction is to change the receipt, not to require Docker for this bounded rereview.** Mark the exact-subject WordPress runtime lane `not-run`/`pending` (or explicitly bind the old result to its historical commit). A fresh WordPress run remains necessary before restoring any current WordPress-runtime claim.

Smallest safe correction
------------------------

For the construction blocker, make the post-typing validation actually cover the complete admitted construction surface. At minimum, visit `classType.constructor` and `classType.init` in addition to `fields` and `statics`, and add all-target negative fixtures with the existing `@:privateAccess` construction placed inside an instance constructor and `__init__`. Because the stated invariant is stronger than “reject source `new`,” either also reject reflective `Type.createInstance` construction of `JsonPlan` at the typed-AST (typed abstract syntax tree) boundary or explicitly exclude and enforce that API in the admitted profile.

The decisive construction red/green case should not merely pass `null`; it should obtain a valid encoded `JsonPlan`, privately retrieve its non-null state through inference, and attempt to construct a second successful plan outside `OutputSinks`. Red today; after repair, all interp/Genes/PHP compilations must fail with the sink-boundary diagnostic.

For checked-encoder totality, validate the runtime `WireValue` constructor identity consistently before trusting the constructor index, or otherwise redesign the public foreign representation so malformed tag/index combinations cannot enter `encodeChecked`. Add native Genes/PHP cases for at least valid-index/wrong-tag, missing/non-numeric/fractional index where target-reachable, wrong parameter count, and each valid index paired with an incompatible tag. Every case must produce `JsonRejected`, a stable reason, no bytes, and no target exception. The concrete PHP red vector should include `new WireValue('Unknown', 0, array())`.

Finally, repair the ADR-012 receipt's WordPress execution claims. No current Docker run is required to turn the **JSON-plan** red vectors green.

Authority disposition
---------------------

`wordpresshx-g4.1.1` **cannot close** on `99b5f21`.

ADR-012 F004 **cannot return to bounded accepted status** because the construction authority guard remains incomplete.

The already accepted ADR-009 **depth** result remains closed, and the specific null-scalar/Genes-corpus/public-`JsonEncoded` retained findings are closed. But the broader ADR-009 checked-JSON boundary **cannot return to bounded accepted status** until the valid-index malformed foreign-enum case is deterministically rejected across the admitted target representations.

No broader WordPress-runtime, SDK readiness, production support, publication, or general compiler-readiness claim is authorized. The missing exact-subject Docker run remains pending specifically for WordPress runtime authority; it is not why this JSON-plan review is `changes-required`.

JSON

```
{
  "decision": "changes-required",
  "confidence": 0.97,
  "prior_findings": {
    "ADR012-F004-RR2-F001": "closed",
    "ADR012-F004-RR2-F002": "open",
    "ADR009-RR2-F001": "closed",
    "ADR009-RR2-F002": "closed",
    "ADR009-RR2-F003": "closed",
    "earlier_depth_closure": "sound"
  },
  "new_findings": [
    {
      "id": "ADR012-F004-RR3-F001",
      "severity": "blocking",
      "confidence": 0.99,
      "summary": "The typed construction guard scans fields/statics and TNew only; class constructors, class init, and other construction forms are not comprehensively guarded."
    },
    {
      "id": "ADR009-RR3-F001",
      "severity": "blocking",
      "confidence": 0.91,
      "summary": "encodeChecked range-checks the runtime enum index without proving constructor/discriminator consistency; foreign valid-index malformed WireValue shapes are neither checked nor tested."
    },
    {
      "id": "ADR012-EVIDENCE-RR3-F001",
      "severity": "major",
      "confidence": 0.99,
      "summary": "The ADR-012 receipt claims WordPress passed/runtime-tested although the exact-subject run stopped before Docker and explicitly claims no current WordPress result."
    }
  ],
  "evidence_limits": {
    "repository_gates_rerun_by_oracle": false,
    "packet_integrity_verified": true,
    "selected_source_inventory_verified": "52/52",
    "haxe_lix_docker_available_to_oracle": false,
    "recorded_schema_gate": "passed",
    "recorded_output_context_gate": "non-Docker portions passed; Docker/WordPress not run",
    "genes_proof_identity": "1.41.4 @ 98a51bdb7a5a1e31002b9ba47855d41905ea48ef",
    "genes_identity_correction": "closed",
    "missing_from_selective_packet": [
      "fixtures/schema-codec/expected/cross-target.txt"
    ]
  },
  "authority_disposition": {
    "wordpresshx-g4.1.1": "remain-open",
    "ADR012-F004": "changes-required",
    "ADR009-checked-json": "changes-required",
    "ADR009-depth": "accepted-closure-remains-sound",
    "wordpress-runtime-exact-subject": "pending",
    "broader_claims_authorized": false
  }
}
```

CAF\_ORACLE\_COMPLETE orq\_20260809T014239Z\_9ab978af 896fb02d6b0e9b97da08bd30aaa93fe4c4b770ceb5cf8461ad0535645b897ef7
