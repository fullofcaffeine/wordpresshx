Decision: `changes-required`
============================

**Confidence: 0.98.**

The exact corrected commit `5e151ed02767378ab50f4b703fdd373fa9c0874b` fixes all three concrete RR3 reproductions, but it does **not** establish the bounded invariants. I found two new blocking vectors:

1.  `JsonPlan` can still be reconstituted outside `OutputSinks` through standard Haxe serialization/unserialization without any `TNew(JsonPlan)`, `Type.createInstance`, or forbidden weak-type token in application source.
    
2.  PHP foreign `ObjectValue` payloads can reach `snapshotObject` with a valid enum envelope and valid Haxe `Array`, but a malformed field element can throw during `current.name`/`current.value` access instead of returning `JsonRejected`.
    

I verified the packet itself independently: `MANIFEST.json:14` binds the exact requested revision, `primary.git-state.json:2-4` has that revision with no selected modifications, and all **66/66** included files recomputed to their `SOURCE_INVENTORY.tsv` SHA-256 values.

Prior RR3 findings
------------------

### `ADR012-F004-RR3-F001` — **open overall; its previously demonstrated sub-vectors are fixed**

The correction does exactly what the prior review requested for the known forms. `OutputContextBoundaryGuard.hx:31-42` now visits instance fields, statics, `ClassType.constructor`, and `ClassType.init`. `:64-70` rejects `TNew(JsonPlan)` outside `OutputSinks`; `:71-80` rejects any typed access to `Type.createInstance`, so aliasing the function does not evade the check.

The all-target negative fixtures correspond to those cases at:

*   `test-negative/json_plan_private_access/Main.hx:5`
    
*   `test-negative/json_plan_private_constructor/Main.hx:4-5`
    
*   `test-negative/json_plan_private_init/Main.hx:4-5`
    
*   `test-negative/json_plan_reflective_constructor/Main.hx:5`
    
*   `test-negative/json_plan_reflective_alias/Main.hx:5-6`
    

and `scripts/output-context/test.sh:290-303` requires all five reflective/private variants to fail on interp, Genes, and PHP.

That closes the **specific RR3 reproductions**, but not the authority invariant, because an equivalent construction mechanism remains.

### `ADR009-RR3-F001` — **closed as the original discriminator finding**

`CanonicalWireJson.hx:56-78` now verifies, before the typed switch:

*   actual enum identity with `Type.getEnum`;
    
*   numeric constructor index;
    
*   constructor name;
    
*   declared parameter count.
    

The exact old PHP red case is now pinned at `packages/contracts/test-runtime/verify-wire-json-foreign.php:41`:

`new WireValue('Unknown', 0, array())`

and adjacent index/name/arity mismatches are covered at `:40-44`.

This is semantically appropriate for PHP: Haxe 4.3.7's PHP representation exposes enum identity from the runtime class and keeps `tag`, `index`, and `params` as the enum representation. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/php/_std/Type.hx) On the JavaScript side, constructor identity is `__enum__`, the discriminator is `_hx_index`, and the constructor name/parameter list are derived from enum metadata, so inventing an independent “tag” property would indeed be testing a property that target semantics ignore. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/js/_std/Type.hx)

I therefore consider **the retained RR3 discriminator bug closed**. The broader ADR-009 boundary is nevertheless still blocked by the separate payload-totality finding below.

### `ADR012-EVIDENCE-RR3-F001` — **closed**

The active receipt no longer upgrades historical WordPress execution into current-subject proof:

*   `manifests/evidence/adr-012-output-context-safety.json:69` says `not-run-current-subject-docker-unavailable`.
    
*   `:236` says `historical-runtime-tested-current-subject-not-run`.
    
*   historical hosted runs are explicitly bound to older commits at `:206-222`.
    
*   ADR text at `docs/adr/012-output-context-safety.md:463-471` likewise says the current lane was not executed.
    

That is the correct bounded disposition. No fresh Docker run is needed for this JSON-plan decision.

* * *

New blocking finding: `ADR012-F004-RR4-F001`
--------------------------------------------

**Severity: blocking.**

### Standard `haxe.Unserializer` bypasses the construction guard

`JsonPlan` has a private constructor and closed state at `OutputSinks.hx:262-285`, but this security property is being enforced by compiler-profile policy rather than runtime object opacity.

The guard only treats two construction mechanisms specially:

*   `TNew(JsonPlan)` — `OutputContextBoundaryGuard.hx:64-70`
    
*   `Type.createInstance` — `:71-80`
    

Haxe 4.3.7 provides another standard construction path. `haxe.Unserializer` explicitly documents that classes are created without calling their constructors, and its implementation calls `Type.createEmptyInstance` then populates fields through `Reflect.setField`. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/haxe/Unserializer.hx) Both JavaScript and PHP implement `Type.createEmptyInstance` as real constructorless allocation. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/js/_std/Type.hx)

`haxe.Serializer` serializes ordinary Haxe classes by enumerating their fields through reflection. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/haxe/Serializer.hx) This is especially concrete on PHP because Haxe 4.3.7's generator maps ordinary Haxe field visibility to `public` unless explicitly marked `@:protected`; Haxe `private` by itself is not emitted as PHP-private storage. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/src/generators/genphp7.ml)

The current application-source token check at `scripts/output-context/test.sh:83-92` does not prevent this. An application can spell only `haxe.Serializer` and `haxe.Unserializer`; the `Dynamic`/`Reflect` operations occur inside the standard library, outside the directories being grepped.

A decisive negative fixture is therefore conceptually:

haxe

```
final seed =
	OutputSinks.restJson(Output.jsonDocument(new NullCodec(), 0));

final serialized = haxe.Serializer.run(seed);

// "null" is the legitimately checked PlanEncoded payload.
// Rewrite the serialized object graph to another successful payload.
final modified =
	StringTools.replace(serialized, "y4:null", "y5:false");

final forged:JsonPlan = haxe.Unserializer.run(modified);

forged.fold(
	bytes -> {
		if (bytes != "false")
			throw new haxe.Exception("unexpected payload");
	},
	reason -> throw new haxe.Exception("forgery rejected: " + reason)
);
```

There is no source `new JsonPlan`, no `Type.createInstance`, and no application spelling of `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped`.

**Observed source fact:** the current guard has no rule for `Type.createEmptyInstance`, `haxe.Unserializer`, or an equivalent reconstitution API.

**Runtime inference:** Haxe 4.3.7's authoritative standard-library implementation is expressly designed to perform exactly this constructorless allocation/field restoration. I could not execute the exact Haxe/Genes/PHP toolchain from the packet environment, so the fixture itself remains to be run; the upstream implementation makes this a high-confidence red vector, not speculation. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub+1](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/haxe/Unserializer.hx)

**Smallest decisive closure test:** add this as an output-context negative fixture and require all admitted compiler targets to reject it. The durable repair should at least exclude `Type.createEmptyInstance` and `haxe.Unserializer` at the same compiler-profile seam that currently excludes `Type.createInstance`; merely adding another source grep would leave the authority split between two mechanisms.

* * *

New blocking finding: `ADR009-RR4-F001`
---------------------------------------

**Severity: blocking.**

### PHP malformed `WireField` elements are not total

The new envelope validation is good, but it protects only the `WireValue` envelope. Once a valid `ObjectValue` reaches `snapshotObject`, the implementation does this:

*   validates that `fields` itself is an `Array` — `CanonicalWireJson.hx:99-104`;
    
*   checks only `current == null` — `:107-111`;
    
*   directly evaluates `current.name` — `:112`;
    
*   later directly evaluates `current.value` — `:118`.
    

The current native PHP corpus only tests `ObjectValue(new stdClass())` at `verify-wire-json-foreign.php:39`, which fails the **outer array** test. It never supplies a legitimate Haxe array containing a malformed foreign field element.

For a Haxe anonymous-structure field access, Haxe 4.3.7's PHP generator emits a direct PHP `->field` access. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)GitHub](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/src/generators/genphp7.ml) Haxe's PHP boot code installs an error handler that converts ordinary PHP warnings to `ErrorException`. [![](https://www.google.com/s2/favicons?domain=https://raw.githubusercontent.com&sz=128)raw.githubusercontent.com](https://raw.githubusercontent.com/HaxeFoundation/haxe/4.3.7/std/php/Boot.hx) Therefore a Haxe `Array` containing `new stdClass()` can pass `Std.isOfType(fields, Array)` and then encounter an undefined-property warning on `current.name`, outside the `try` in `hasValidWireEnvelope`.

I also reproduced the relevant PHP mechanism locally on PHP 8.4.23: reading a missing `stdClass` property under the same warning-to-`ErrorException` handler shape throws. That is corroboration only; the packet claims PHP 8.4.7, which I did not independently execute.

**Smallest decisive closure test:** extend `verify-wire-json-foreign.php` with a generated Haxe `Array` whose first element is, at minimum:

1.  `new stdClass()` with no `name`;
    
2.  an object with valid `name` but no `value`;
    
3.  a non-object element.
    

Every one must yield a stable `JsonRejected` and no escaping exception. The Genes native probe should carry corresponding plain malformed field elements where target-reachable.

This is not the old tag/index bug; it is a new payload-totality hole.

* * *

Test sensitivity and oracle independence
----------------------------------------

There is meaningful independent evidence in the existing suite. `scripts/contracts/test-schema-authority.sh:194-197` compares all three boundary transcripts against a checked-in expected transcript, then `:198-212` feeds successful output to native decoders. The JavaScript verifier calls actual `JSON.parse` at `verify-wire-json-transcript.mjs:14`; PHP calls `json_decode(..., JSON_THROW_ON_ERROR)` at `verify-wire-json-transcript.php:21`. Those are appropriate independent decoder authorities, not counters calculated by `CanonicalWireJson` itself.

The immutable-snapshot test is also behaviorally meaningful at `WireJsonBoundaryTest.hx:79-90`, and the 64-container tests use checked-in exact output/rejection expectations at `:49-68`.

The weak areas are precisely where the new findings live. The construction suite enumerates five known syntax forms, rather than testing the broader capability to reconstitute successful state. Meanwhile `validate-architecture.py:374-425` mostly checks source markers and expected counts; a `typedConstructionGuardCount` of five is bookkeeping, not proof that no sixth construction mechanism exists. Likewise, the foreign native tests have hard-coded behavioral expectations, which is good, but their shape corpus stops before malformed elements inside a valid object container.

The packet itself contains no raw execution artifacts (`MANIFEST.json:22` has `"evidence": []`). I therefore treated the receipts' “passed” fields as recorded claims rather than independent proof. That does **not** create a separate evidence finding here because the active receipts are appropriately pending rereview and the WordPress lane is accurately marked unrun.

Required invariants
-------------------

1.  **Application code cannot construct successful `JsonPlan` outside `OutputSinks`: FAIL.** Standard Haxe unserialization is an unexcluded equivalent construction path.
    
2.  **All reachable foreign `WireValue` shapes reject without escaping exceptions: FAIL.** PHP malformed field elements inside a valid `ObjectValue` container are not guarded.
    
3.  **Every successful checked string is accepted by both native decoders: supported by the current test design.** I found no contrary vector in the nine shared successful cases.
    
4.  **64-container depth, empty-failure, null scalars, immutable snapshot, key validation, and `JsonEncoded` documentation: no regression found.** `WireJsonEncoding.hx:3-8` still correctly says public `JsonEncoded` construction itself conveys no authority.
    
5.  **Evidence accurately distinguishes current and historical execution: PASS.**
    
6.  **Repository Haxe source avoids the forbidden weak tokens: PASS as written, but insufficient to save invariant 1.** The unserialization vector does not need those tokens in application source.
    

Authority disposition
---------------------

`wordpresshx-g4.1.1` **must remain open**.

ADR-012 F004 **cannot return to bounded accepted status** because successful-plan construction authority is still bypassable.

The original `ADR009-RR3-F001` discriminator finding is closed, but **ADR-009 checked JSON cannot return to bounded accepted status** because foreign PHP object payload totality remains incomplete.

`ADR012-EVIDENCE-RR3-F001` is closed; the absent current WordPress Docker run is correctly represented and is **not** a reason for this `changes-required` decision.

No broader SDK, WordPress runtime, production compiler, publication, or support authority is granted or evaluated here.

CAF\_ORACLE\_COMPLETE orq\_20260809T190746Z\_2da016f8 b7cfa3ca2b55761527d4202a97e19c83f65725b6baffbc636c3ee6bc508345de
