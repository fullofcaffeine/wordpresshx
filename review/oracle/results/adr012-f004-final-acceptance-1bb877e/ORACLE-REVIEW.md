changes-required — confidence 0.96

The exact reviewed source has repaired the two `5e151ed` findings, and I found no surviving ordinary-Haxe route that forges successful `JsonPlan` state through direct/private construction, `Type.createInstance`, `Type.createEmptyInstance`, or `haxe.Unserializer`. However, the ADR-009 checked encoder still has two foreign-boundary holes: an unchecked runtime `maxDepth` can defeat the hard 64-container limit, and traversal of a valid native array can still let an accessor exception escape instead of returning `JsonRejected`. There is also a material mutation-sensitivity gap in the ADR-012 gate.

### Closure disposition

Subject

May close?

Reason

`ADR012-F004`

**No**

Its recorded claim is that typed JSON reaches the sink as encoded bytes **or an explicit failure** (`manifests/evidence/adr-012-output-context-safety.json:106-110`), and `OutputSinks` relies directly on `encodeChecked` at `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx:79-87`. A reachable foreign-array failure can still escape that seam.

ADR-009 checked-encoder hardening

**No**

Hard-64 enforcement is bypassable by malformed runtime `maxDepth`, and the foreign collection traversal is not total.

Bead `wordpresshx-g4.1.1`

**No**

`.beads/issues.jsonl:7` explicitly requires exact hard-64 behavior, totality over malformed public/foreign shapes, no escaping exception, and a fresh independent accepted review. Those criteria are not met.

Findings
--------

### `ADR009-RR5-F001` — malformed runtime depth limit bypasses the hard maximum

**Severity: blocking-high.**

**Observed source fact.** `CanonicalWireJson.encodeChecked` is public and accepts `maxDepth:Int`, but validates it only with numeric comparisons:

*   `packages/contracts/src/wordpress/hx/contracts/CanonicalWireJson.hx:20-26` checks `< 1` and `> 64`.
    
*   `:84-85` and `:103-104` enforce container depth only through `containerDepth > maxDepth`.
    
*   There is no runtime `Std.isOfType(maxDepth, Int)` admission check, even though the same codec deliberately performs runtime type checks on foreign `BoolValue` and `IntegerValue` payloads at `:43-46`.
    

The maintained foreign Genes probe demonstrates why static Haxe/TypeScript types are insufficient at this seam: it deliberately supplies `Number.NaN`, fractions, infinities, and other non-Haxe-`Int` values to the generated API at `packages/contracts/test-runtime/verify-wire-json-foreign.mjs:23-34`. It tests `Number.NaN` specifically for `IntegerValue` at line 30, but never varies `maxDepth`.

The ordinary Haxe boundary suites test `0`, `-1`, `1`, `64`, and `65`, but not a malformed runtime depth value: `packages/contracts/test-boundary/wordpress/hx/contracts/boundary/WireJsonBoundaryTest.hx:49-68` and `packages/contracts/test/wordpress/hx/contracts/tests/SchemaAuthorityTest.hx:277-299`.

**Independent model.** On the local JavaScript runtime:

```
NaN < 1   => false
NaN > 64  => false
65 > NaN  => false
```

PHP has the same comparison result for `NAN`. Thus a foreign Genes/JavaScript call of the shape

JavaScript

```
CanonicalWireJson.encodeChecked(nested65, Number.NaN)
```

passes both admission comparisons and makes every subsequent `containerDepth > maxDepth` test false. A 65-container value can therefore evade the accepted maximum; a cycle amplifies the same defect into unbounded recursion rather than the intended depth rejection.

**Inference.** The exact Genes output could not be generated here because Haxe/Lix are unavailable, so the call itself was not executed against generated `CanonicalWireJson.js`. The inference is high-confidence: the repository expressly exposes the generated static method to JavaScript in `verify-wire-json-foreign.mjs:8-17`, and its existing `NaN` regression relies on runtime rather than TypeScript admission. JavaScript `number` does not enforce Haxe `Int` at the call boundary.

**Smallest decisive reproducer.** Extend `verify-wire-json-foreign.mjs` to construct 65 nested `ArrayValue`s, call `encodeChecked(value, Number.NaN)`, and require `JsonRejected` with no `value` property. Also pin at least fractional/string/boolean malformed depth inputs so the boundary is type-total rather than merely patched for `NaN`.

**Smallest correction.** Before any numeric comparison, runtime-admit the parameter using the same pattern already used for foreign integer payloads, with a stable rejection such as `json-depth-limit-must-be-integer`. An even smaller authority surface would make the public checked encoder always use the fixed 64-container limit and keep any variable-depth helper non-public/test-only.

* * *

### `ADR009-RR5-F002` — valid foreign arrays can still escape target exceptions

**Severity: blocking-high.**

**Observed source fact.** The latest repair correctly guards malformed `WireField` dereferences inside `snapshotObject`:

*   `CanonicalWireJson.hx:107-132` places `fields[index]`, `current.name`, and `current.value` inside a `try/catch`.
    

But equivalent collection observations remain outside a checked boundary:

*   `snapshotArray` reads `values.length` and then `values[index]` without any `try` at `CanonicalWireJson.hx:80-96`.
    
*   `snapshotObject` still evaluates `fields.length` in the `for` header before its `try`, at `:99-108`.
    
*   `encodeChecked` itself has no outer snapshot exception boundary at `:20-30`.
    

The foreign Genes corpus at `verify-wire-json-foreign.mjs:23-56` contains passive malformed objects, wrong container types, forged enum metadata, and the three newly added malformed fields. It contains no native array with an accessor or proxy.

**Independent model.** I constructed an actual JavaScript `Array`, defined an accessor on index `0` that throws, and verified:

```
Array.isArray(array) = true
array instanceof Array = true
array.length = 1
array[0] => throws Error("wire-array-getter")
```

I also verified that a proxy over an array remains an array under both ordinary JavaScript array tests while its `length` access can throw.

That gives the minimal foreign vector:

JavaScript

```
const values = [];
Object.defineProperty(values, "0", {
  get() { throw new Error("wire-array-getter"); }
});
values.length = 1;

CanonicalWireJson.encodeChecked(WireValue.ArrayValue(values));
```

**Inference.** Genes' Haxe `Array` representation must accept native arrays—it is already the boundary shape exercised by the repository's JavaScript probes. Once `Std.isOfType(values, Array)` accepts this genuine array, source line 89 performs the throwing indexed read with no enclosing catch. The target `Error` therefore escapes instead of becoming `JsonRejected`.

This is not hostile modification of generated artifacts. It is a value supplied through the explicitly maintained foreign-input boundary. The current Bead's acceptance text says **all malformed public or foreign `WireValue` shapes** must produce a stable failure without an escaping exception.

The same root problem exists for an `ObjectValue` whose fields container is an array proxy throwing from `length`: the recent field-element catch starts too late.

**Smallest decisive closure tests.** Add a Genes native probe with (1) an actual array whose element getter throws and (2) an array proxy whose `length` getter throws, asserting modeled rejection and absence of encoded bytes. Add an analogous PHP boundary vector where the generated `Array_hx` surface permits one; JavaScript alone is sufficient to disprove the current cross-target claim.

**Smallest correction.** Make the snapshot phase itself exception-total. The least fragile design is to guard every foreign observation point—enum/payload access, container length, element/field retrieval—with stable modeled failures, with a snapshot-level catch as a final backstop. Encoding the resulting private `CanonicalJsonValue` should remain outside that broad catch so an internal encoder bug is not silently presented as malformed caller input.

* * *

### `ADR012-EVIDENCE-RR5-F001` — a raw-string sink factory can be added without a semantic gate failure

**Severity: major.**

This is an evidence-sensitivity finding, **not a bypass present in the exact source**.

**Observed current source.** The reviewed `OutputSinks` is currently good on this point. Its only successful `JsonPlan` construction is:

*   `OutputSinks.hx:81-85`: `EncodedValue(WireValue)` → `CanonicalWireJson.encodeChecked` → only `JsonEncoded(encoded)` constructs `PlanEncoded(encoded)`.
    
*   `JsonPlan` itself has sink-owned private construction and closed nullable state at `OutputSinks.hx:262-285`.
    

I found no current public raw-string success factory.

**Observed gate weakness.** `scripts/output-context/validate-architecture.py:374-380` splits the file at `"final class JsonPlan"` and checks for a raw-string public factory only in the text **after** that split. A factory added to `OutputSinks` itself is therefore outside the scan. The compiler guard also intentionally permits any `TNew(JsonPlan)` whose owning class is `OutputSinks`, at `OutputContextBoundaryGuard.hx:64-71`.

I mutation-tested this rather than inferring it. I temporarily added:

haxe

```
public static function unsafeJsonPlan(
    schemaId:String,
    encoded:String
):JsonPlan {
    return new JsonPlan(schemaId, PlanEncoded(encoded));
}
```

to `OutputSinks`.

The validator first failed only because `prototypeEvidence.sourceTreeSha256` no longer matched. I then regenerated that expected source digest—the normal consequence of intentionally changing source—and reran the validator. Result:

```
regenerated-evidence-mutated-validator-exit=0
ADR-012 output-context architecture passed:
11 contexts, 15 forbidden edges, 36 independent mutations
```

I restored the exact packet bytes afterward and reverified all 118 inventory hashes.

The existing `json_plan_success` fixture (`fixtures/output-context/test-negative/json_plan_success/Main.hx:1-6`) checks only the old `JsonPlan.success(...)` spelling. It would not exercise a newly introduced `OutputSinks.unsafeJsonPlan(...)`.

**Smallest closure test.** Make `validate-architecture.py` reject public `OutputSinks` functions that accept raw JSON/encoded `String` authority and return `JsonPlan`, or explicitly allowlist the two public plan APIs (`restJson(JsonDocument)` and `scriptData(HtmlScriptData)`). Add the above mutation as an independent mutation case; it must continue to fail even after source hashes/evidence metadata are regenerated.

This gap does not itself prove the exact commit unsafe, but after this many equivalent-bypass repairs it is important evidence that the claimed policy is not yet regression-sensitive at its trusted owner seam.

Prior bypass-class challenge
----------------------------

I rechecked the previous routes rather than only the latest patches.

Bypass / invariant

Exact-subject assessment

Would current evidence catch regression?

Public `JsonPlan.success(raw)`

**Closed in current source.** No such factory; success is only at `OutputSinks.hx:82-84`.

Old spelling yes; arbitrary new `OutputSinks` raw factory **no** — finding RR5 evidence above.

Direct/private/`@:privateAccess` construction

**Closed within admitted compiler profile.** `OutputContextBoundaryGuard.hx:64-80`.

Yes: dedicated compile negatives.

Constructor/class-initializer traversal omission

**Closed.** Classes, fields/statics, constructors and `init` are traversed at `OutputContextBoundaryGuard.hx:28-47`.

Yes: `json_plan_private_constructor` and `json_plan_private_init`.

`Type.createInstance`, including alias

**Closed.** `OutputContextBoundaryGuard.hx:83-104`.

Yes.

`haxe.Unserializer` / `Type.createEmptyInstance`

**Latest source repair is credible.** Unserializer construction/static/instance access and both Type constructors are rejected at `:66-75`, `:83-107`.

Unserializer yes. `createEmptyInstance` itself lacks a dedicated negative fixture, so removing only that rule is less directly pinned.

Forged enum index/name/arity

**Closed for reproduced passive shapes.** `CanonicalWireJson.hx:56-78` checks enum identity, index, constructor and arity before switching.

Yes: PHP/Genes native foreign probes.

Null/wrong scalar payloads, fractional/out-of-range integers

**No regression found.** `:43-48`; native probes include `NaN` and infinity.

Yes.

Malformed `WireField`

**Latest passive-field bug closed.** `:107-132`.

Yes for missing name/value/non-object field.

Foreign container observations

**Still open.** Finding `ADR009-RR5-F002`.

No active-accessor vector.

Exact 64/65 depth for valid `Int` policy

**Correct in source/tests.** Only containers increment depth at `:49-52`; ordinary 64/65 arrays/objects/mixed shapes are well covered.

Yes for valid Haxe `Int`; **no** for malformed runtime depth parameter.

Cycles

With ordinary max `64`, depth eventually rejects.

Yes. With `NaN` max depth, the stopping condition disappears.

Mutation after validation

**Good for passive values.** Encoding consumes private snapshots; mutations after `encodeChecked` do not affect bytes.

Yes at `WireJsonBoundaryTest.hx:79-90` and `SchemaAuthorityTest.hx:323-334`.

C0 controls, quotes, backslashes

**No source counterexample found.** `CanonicalWireJson.hx:194-221` covers JSON escapes and remaining C0 as `\\u00xx`.

Strong existing corpus.

Invalid Unicode

**No regression found.** `:143-175`, with target-specific UTF-16/UTF-8 validation.

Yes for high/low surrogate vectors.

Duplicate keys / canonical order

**No regression found.** Validated snapshot is scalar-sorted and duplicates rejected at `:134-140`.

Yes.

Native JSON acceptance

No contrary successful-byte case found.

Repository probes use independent native decoders; good design.

Docker/WordPress evidence inflation

**Closed.** Receipt explicitly records current WordPress lane as not run at `manifests/evidence/adr-012-output-context-safety.json:69` and `:257`.

Yes; no false current-subject WordPress claim found.

The important positive result is that I found **no current path from a caller-authored JSON `String` to successful `PlanEncoded` state** in the admitted Haxe profile. For passive, validly admitted `WireValue`s and an actual integer depth limit in `1...64`, the snapshot/encoder design also appears to produce canonical decoder-compatible JSON. Those narrower properties are not enough to satisfy the exact acceptance request because the total foreign-boundary and hard-limit claims are stronger.

Verification actually performed
-------------------------------

The archive SHA-256 is `35883546b4dfdf045c38c11f2fea3ff90468d1f8d8cdca8383023afd1a63d475`.

Packet integrity passed: `sha256sum -c SHA256SUMS` reported all five packet-level artifacts `OK`, and I reconstructed the Repomix source tree and independently checked every included file against `SOURCE_INVENTORY.tsv`: **118/118 matched byte length and SHA-256**. `MANIFEST.json:13-19` describes the packet as `selective`, revision `1bb877ee69e4d2815ee5254056363a691fe0d703`, with 118 packed files and zero omissions from that selection; `primary.git-state.json:2-4` records the same revision and no selected modifications.

The archive does **not** contain a `.git` object database. I therefore cannot independently recompute commit `1bb877e…` or tree `4bbeca22538894f31a035a1ec9b5a4d00f04703f`; the tree hash is request metadata rather than something derivable from the supplied objects.

Actual environment:

```
Haxe:   unavailable
Lix:    unavailable
Docker: unavailable
Node:   v22.16.0
PHP:    8.4.23
Python: 3.13.5
Git:    2.47.3
```

Actual commands/outcomes:

*   `python3 scripts/output-context/validate-architecture.py` — **passed**, reporting 11 contexts, 15 forbidden edges, 36 independent mutations.
    
*   Static reviewed-Haxe weak-token scan for `Dynamic`, `Any`, `Reflect`, `untyped`, and `cast` — **no matches** in `packages/contracts/src` or `fixtures/output-context/src`.
    
*   `python3 scripts/contracts/validate-schema-authority.py` — **not runnable from this selective packet**; it reaches `scripts/contracts/validate-schema-authority.py:114` and fails because `schemas/contract-schema.schema.json` is absent.
    
*   `bash scripts/contracts/test-schema-authority.sh` — **exit 1**, preflight says `ADR-009 schema authority gate requires haxelib`.
    
*   `bash scripts/output-context/test.sh` — **exit 1**, preflight says `ADR-012 output-context gate requires docker` (`scripts/output-context/test.sh:16-21` makes the Docker binary mandatory).
    
*   `bash scripts/check-repository.sh` — **exit 128**, because the reconstructed packet has no `.git`.
    
*   Custom native-decoder sanity on the checked-in `fixtures/output-context/expected/context-plan.txt` — Node 22.16.0 and PHP 8.4.23 both parsed the plan and all **34** nested modeled-success JSON byte strings (`restJson`, `scriptData`, and 32 C0 vectors). This is a sanity check of checked-in expectations, **not** execution proof for current generated source.
    
*   JavaScript/PHP `NaN` comparison model — confirmed all comparisons relevant to the depth bypass evaluate false.
    
*   JavaScript native-array model — confirmed real arrays can remain arrays while indexed access throws, and array proxies can throw from `length`.
    
*   ADR-012 unsafe-factory mutation test — after regenerating the expected source-tree digest, `validate-architecture.py` **passed the unsafe factory mutation**. The reviewed files were then restored and all 118 inventory hashes rechecked successfully.
    

The receipts record the desired exact Haxe 4.3.7 / Genes 1.41.4 / TypeScript 5.9.3 / Node 22.17.0 / PHP 8.4.7 runs at `manifests/evidence/adr-009-schema-codec-authority.json:67-95` and `manifests/evidence/adr-012-output-context-safety.json:45-72`. I treat those as historical/current-local supporting claims, not executions I independently reproduced here.

Implementation-ready stop criteria
----------------------------------

The smallest safe next repair is confined to the checked encoder and evidence guard; there is no reason to reopen the `JsonPlan` representation or broaden the architecture.

1.  Runtime-admit `maxDepth` before comparisons, or remove the caller-controlled public limit and expose only the hard fixed 64 policy. Add foreign Genes vectors for `NaN`, fractional and otherwise non-`Int` depth values; 65 containers and a cycle must still produce modeled rejection with no bytes.
    
2.  Make snapshot traversal exception-total over foreign observations. Pin at least a throwing array-element accessor and throwing container metadata/access case. An exception from input observation must become one stable `JsonRejected`; private snapshot encoding should remain deterministic and exception-free.
    
3.  Strengthen the ADR-012 authority validator so a public raw-string `OutputSinks`→`JsonPlan` success factory fails for a **semantic reason even after evidence hashes are regenerated**. The mutation I used above is the closure test.
    
4.  Rerun the exact ADR-009 target matrix and ADR-012 non-WordPress lanes, both native decoder probes, and the expanded foreign corpus. Keep the WordPress lane explicitly `not-run` if Docker remains unavailable; it is not a prerequisite for this bounded JSON decision.
    
5.  Produce a new content-addressed subject and obtain the required fresh independent acceptance. Do not close `wordpresshx-g4.1.1` merely from local greens.
    

### Unresolved owner decisions

No product-owner decision is necessary to disposition this commit. There is one possible contract choice: if active foreign arrays/accessors are intentionally _not_ part of the foreign-value guarantee, the ADR/Bead must explicitly narrow “all malformed public or foreign shapes” and “no escaping target exception” to an inert/passive-data boundary. The current text does not make that narrower claim, and the implementation can feasibly enforce the stronger one, so I would repair rather than narrow it.

Likewise, keeping configurable `maxDepth` public versus making 64 an invariant public constant is an implementation/API choice; either is acceptable only if malformed runtime arguments cannot bypass the 64-container authority.

No publication, production-support, general WordPress compatibility, compiler-readiness, or legal conclusion is authorized by this review.

CAF\_ORACLE\_COMPLETE orq\_20260810T023318Z\_cdd348fe 3d1fc76b72bdf02f61b62394e3bd47e58918075b3652e6ea51bf3dc818a24071
