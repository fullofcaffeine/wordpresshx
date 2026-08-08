changes-required — confidence: high

Bounded decision
----------------

Commit `552c7affabe16af9a1976cf6393ed34f4ba31a2b` correctly repairs the container-depth definition and the original validate-before-sort/snapshot defects. It also removes the ordinary `JsonPlan.success` factory and rejects an unannotated direct constructor call.

It does **not**, however, close the complete checked-JSON boundary:

1.  `EncodingFailure("")` creates a plan with both `encoded == ""` and `failureReason == ""`; the native consumers treat that shape as success and attempt to parse empty JSON.
    
2.  Haxe’s `@:access` and `@:privateAccess` language features can override the private `JsonPlan` constructor. The supplied negatives test only ordinary access.
    
3.  `encodeChecked` still accepts malformed null `BoolValue`/`IntegerValue` payloads without validation; notably, a null integer can become successful JSON `null`.
    
4.  The decisive malformed-value corpus does not pass through the Genes/strict-TypeScript lane.
    

These are source-level blockers independent of receipt status.

Subject binding
---------------

**Observed:** The packet binds the primary repository to revision `552c7affabe16af9a1976cf6393ed34f4ba31a2b`, detached with no selected dirty status, and declares 556 selected/packed files with none omitted: `MANIFEST.json:3-19`; `primary.git-state.json:2-4`.

**Executed:** `sha256sum -c SHA256SUMS` passed for all five packet members. I independently checked every `SOURCE_INVENTORY.tsv` entry against the reconstructed source: **556/556 byte lengths and SHA-256 hashes matched**, including 459 Haxe files.

**Limitation:** The selective packet contains no `.git` directory or Git mode inventory. I therefore could not independently recompute tree `4e27f5e61cce0b7aff947c44c334eee39477e43b`; that tree binding remains an authoritative packet assertion rather than an independently reproduced Git-tree result.

Prior-finding dispositions
--------------------------

Prior finding

Disposition

Basis

`ADR012-F004-RR-F001`

**Not closed; partially repaired**

The ordinary public factory is gone and the unannotated constructor is private, but the empty-failure sentinel and Haxe access-control metadata leave equivalent false-success/raw-construction paths. `OutputSinks.hx:79-87,258-268`; `scripts/output-context/test.sh:282-285`.

`ADR009-RR-F001`

**Closed**

The implementation now consistently counts JSON containers: root scalar starts at zero, each array/object increments once, maximum 64 is enforced, and invalid configurations reject before traversal. `CanonicalWireJson.hx:9,20-29,46-49,53-59,72-78`; `WireJsonBoundaryTest.hx:50-69`.

`ADR009-RR-F002`

**Not closed; substantial repair present**

Null references, string validity, validate-before-sort, duplicate detection, and snapshot isolation are repaired, but malformed scalar payloads and invalid runtime enum shapes are not modeled, and the malformed corpus omits the Genes/strict-TypeScript lane. `CanonicalWireJson.hx:33-50,79-104,141-155`; `WireJsonBoundaryTest.hx:24-48`; `test-schema-authority.sh:152-184`.

New material findings
---------------------

### `ADR012-F004-RR2-F001` — empty failure reason creates a false-success plan

**Severity:** `blocking-high`  
**Confidence:** high

**Observed fact**

Application codecs publicly return either `EncodedValue(WireValue)` or `EncodingFailure(reason:String)`: `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx:86-95`.

The sink handles those variants as follows:

*   checked success → `new JsonPlan(schemaId, encoded, "")`;
    
*   checked rejection → `new JsonPlan(schemaId, "", reason)`;
    
*   codec failure → `new JsonPlan(schemaId, "", reason)`.
    

There is no requirement that the failure reason be non-empty: `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx:79-87`. The plan contains only three strings and has no closed success/failure discriminator: `OutputSinks.hx:258-268`.

The fixture tests only `EncodingFailure("invalid-domain-id")`, never an empty failure reason: `fixtures/output-context/test/Main.hx:35-50,109-112`.

The browser interprets an empty failure reason as success and later executes `JSON.parse(plan.scriptData.encoded)`: `fixtures/output-context/runtime/browser.mjs:36-52,106-111`. PHP calls `json_decode(..., JSON_THROW_ON_ERROR)` before its later failure-field assertions: `fixtures/output-context/runtime/wordpress-probe.php:102-103,124-130`.

This contradicts the ADR requirement that encoding failure cannot silently become an empty response or fragment: `docs/adr/012-output-context-safety.md:135-143`.

**Executed reproduction**

Using the available native runtimes:

```
JSON.parse("")
→ SyntaxError: Unexpected end of JSON input
exit 2

json_decode("", true, 512, JSON_THROW_ON_ERROR)
→ JsonException: Syntax error
exit 2
```

**Inference**

A valid application codec can return `EncodingFailure("")`. The sink then creates:

```
encoded = ""
failureReason = ""
```

That shape is indistinguishable from success under the current sentinel convention and reaches a native decoder exception. No malformed raw JSON string is needed.

**Consequence**

The plan result is not a total modeled success/failure value. Application-controlled input can still produce an uncaught target exception and a false-success surface.

**Required correction**

Replace the paired-string sentinel with a closed plan result, such as distinct success and rejection variants. A rejection must always carry zero bytes and must not rely on a non-empty string to prove that it is a rejection. Native consumers must branch on the explicit variant before accessing bytes.

At minimum, reject or normalize empty/null failure reasons before plan creation, but that alone is weaker than an explicit discriminator.

**Smallest decisive closure test**

Add a codec returning `EncodingFailure("")`, plus a non-strict null-reason case where representable. On Haxe interp, Genes/strict TypeScript/Node, and stock-Haxe PHP, assert:

*   the result is explicitly rejected;
    
*   encoded bytes are absent;
    
*   a stable non-empty diagnostic is present;
    
*   neither native JSON decoder is invoked.
    

* * *

### `ADR012-F004-RR2-F002` — Haxe access metadata defeats sink-owned construction

**Severity:** `blocking-high`  
**Confidence:** high

**Observed fact**

`JsonPlan` is application-nameable and has a private constructor guarded only by `@:allow(OutputSinks)`: `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx:258-268`.

The supplied negatives test only:

*   removed `JsonPlan.success`: `fixtures/output-context/test-negative/json_plan_success/Main.hx:1-6`;
    
*   an ordinary direct constructor call: `fixtures/output-context/test-negative/json_plan_constructor/Main.hx:1-6`.
    

Those are run across interp, Genes, and PHP at `scripts/output-context/test.sh:172-229,282-285`.

The source gate searches for `Dynamic`, `Any`, `Reflect`, `untyped`, and `cast`, but not access-control metadata: `scripts/output-context/test.sh:81-89`. The architecture validator checks source spelling for a private constructor and absence of a raw-string public factory, but does not inspect typed construction sites or access metadata: `scripts/output-context/validate-architecture.py:372-390`.

The repository already uses `@:access` elsewhere, so no repository-wide rule currently excludes it: `packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/EditAttributesRuntime.hx:5-9`.

Haxe officially defines `@:access` as forcing access to private fields and says it “effectively subverts” visibility. `@:privateAccess` permits private access to anything for the annotated expression. Haxe macros can generate or modify access metadata. [![](https://www.google.com/s2/favicons?domain=https://haxe.org&sz=128)Haxe - The Cross-platform Toolkit+1](https://haxe.org/manual/lf-access-control.html)

**Not executed**

I could not compile the adversarial fixture because Haxe, Haxelib, and Lix were unavailable in this environment.

**Inference**

Application code can use the language-supported equivalent of:

haxe

```
@:privateAccess
new JsonPlan("forged.v1", '{"caller":"authored"}', "");
```

or place `@:access(...)` on the accessing method. This restores the prior raw-success bypass while using none of the prohibited weak-type constructs.

A text search for direct metadata is insufficient because application macros can synthesize it.

**Consequence**

The claim that successful plan construction is unforgeable through application Haxe code is false. `private` plus `@:allow` is ordinary API encapsulation, not a provenance or security capability boundary in Haxe.

**Required correction**

Choose and enforce one of these bounded positions:

*   Establish a trusted compilation boundary and run a final typed-AST gate that rejects every `JsonPlan` construction outside `OutputSinks`, regardless of `@:access`, `@:privateAccess`, or macro generation. Application-provided macros must be excluded from that trusted boundary or inspected after expansion.
    
*   Move the provenance-sensitive operation behind a boundary application Haxe cannot override.
    
*   Narrow the ADR claim from language-enforced unforgeability to an audited repository convention.
    

**Smallest decisive closure test**

Across interp, Genes, and PHP, add negatives for:

1.  ordinary constructor access;
    
2.  expression-level `@:privateAccess`;
    
3.  method/class-level `@:access`;
    
4.  macro-generated private construction.
    

The decisive gate must reject the resulting typed construction site, not merely search source text or rely on the ordinary private-access diagnostic.

* * *

### `ADR009-RR2-F001` — malformed scalar payloads remain successfully encodable

**Severity:** `blocking-high`  
**Confidence:** high for the missing validation and null-integer consequence; medium-high for other malformed target representations

**Observed fact**

The public algebra carries basic scalar payloads:

*   `BoolValue(value:Bool)`;
    
*   `IntegerValue(value:Int)`.
    

See `packages/contracts/src/wordpress/hx/contracts/WireValue.hx:3-10`.

The snapshot traversal validates null roots, strings, arrays, fields, names, and values, but directly accepts boolean and integer payloads without runtime validation:

```
BoolValue(value)    → CanonicalBool(value)
IntegerValue(value) → CanonicalInteger(value)
```

See `CanonicalWireJson.hx:33-50`.

Encoding then uses a truth test for booleans and `Std.string(value)` for integers: `CanonicalWireJson.hx:141-155`. There is also no explicit signed-int32 range validation, despite the ADR’s signed-32-bit contract: `docs/adr/009-schema-and-codec-authority.md:74-89`.

The deliberately non-strict malformed corpus includes null string/container/field cases but omits `BoolValue(null)` and `IntegerValue(null)`: `packages/contracts/test-boundary/wordpress/hx/contracts/boundary/WireJsonBoundaryTest.hx:12-34`. The compile-negative fixture has the same omission: `packages/contracts/test-negative/malformed_wire_value/wordpress/hx/contracts/negative/MalformedWireValueMain.hx:7-20`.

The snapshot’s enum switch also has no modeled fallback or exception containment for an invalid runtime constructor/tag: `CanonicalWireJson.hx:33-50`.

Haxe’s dynamic targets, including JavaScript and PHP, allow null values for basic types outside null-safe code. Haxe 4.3.7 specifies that `Std.string(null)` returns `"null"`. [![](https://www.google.com/s2/favicons?domain=https://haxe.org&sz=128)Haxe - The Cross-platform Toolkit+1](https://haxe.org/manual/types-nullability.html?utm_source=chatgpt.com)

**Inference**

On the decisive JavaScript/PHP boundaries, malformed `IntegerValue(null)` reaches `CanonicalInteger(null)` and then emits successful JSON `null`, rather than `JsonRejected`. It is therefore not merely an exception risk: malformed integer state can be silently rebranded as valid bytes with different semantics.

`BoolValue(null)`, out-of-range foreign integer payloads, wrong runtime scalar payloads, and invalid enum tags likewise lack explicit modeled handling; their exact target manifestations were not executed here.

**Consequence**

`encodeChecked` is not total over all malformed values admitted by its public runtime surface, and a `JsonEncoded` result does not necessarily preserve the selected `WireValue` constructor’s semantics.

This makes the current ADR statement that the encoder returns stable rejection variants “for every malformed public shape” too broad: `docs/adr/009-schema-and-codec-authority.md:483-492`.

**Required correction**

Before constructing the private snapshot:

*   reject null boolean and integer payloads;
    
*   validate the runtime scalar kind where foreign callers can bypass Haxe typing;
    
*   enforce the signed-int32 range;
    
*   convert invalid runtime enum/tag/container representations into modeled rejection;
    
*   contain any target exception before bytes are created.
    

If those checks cannot be implemented without a prohibited weakly typed Haxe escape, raw foreign values must first pass through a target-owned validated adapter, and `encodeChecked` must not be exposed directly to unvalidated foreign representations.

**Smallest decisive closure test**

Inject, through a genuinely foreign/non-strict boundary:

*   null boolean and integer payloads;
    
*   wrong runtime boolean/integer payload types;
    
*   integers immediately outside signed-int32 range;
    
*   non-finite numeric payloads where representable;
    
*   invalid enum tag/shape;
    
*   wrong array/object payload kind.
    

Every target must return a stable rejection with zero bytes and no uncaught exception.

* * *

### `ADR009-RR2-F002` — decisive malformed corpus silently omits Genes/strict TypeScript

**Severity:** `major`  
**Confidence:** high

**Observed fact**

The ordinary schema corpus runs through:

*   Haxe interp;
    
*   Genes → strict TypeScript → Node;
    
*   stock-Haxe PHP.
    

See `scripts/contracts/test-schema-authority.sh:97-150`.

The deliberately non-strict malformed boundary corpus instead runs through:

*   Haxe interp;
    
*   ordinary stock-Haxe JavaScript plus Node;
    
*   stock-Haxe PHP.
    

It does **not** use `genes-ts` or invoke strict TypeScript compilation: `scripts/contracts/test-schema-authority.sh:152-184`.

That differs from the prior review’s explicit closure requirement that the same malformed corpus run on interp, Genes/strict TypeScript/Node, and PHP: `review/oracle/results/adr012-f004-rereview-0e01ab5/ORACLE-REREVIEW.md:189-202`.

The accepted boundary helpers assert only the `JsonEncoded` variant and discard the bytes: `WireJsonBoundaryTest.hx:150-157`; `SchemaAuthorityTest.hx:391-396`. The expected boundary transcript records only labels such as `depth-64-empty-array=encoded`: `fixtures/schema-codec/expected/wire-json-boundary.txt:15-37`.

The Python validator hashes and counts that boundary transcript but does not independently parse or validate accepted boundary bytes: `scripts/contracts/validate-schema-authority.py:99-130`.

**Consequence**

A Genes-specific code-generation or strict-TypeScript discrepancy in malformed handling can pass the gate. The current boundary proof establishes selected variants and reasons, but not decoder-compatible bytes for its accepted depth/object vectors.

**Required correction and smallest closure test**

Run one identical semantic corpus across all three required target lanes. Where strict TypeScript prevents constructing malformed values in generated Haxe code, use a small target-native foreign-call harness to inject them into the compiled public boundary.

For accepted depth-1/depth-64, Unicode, C0, and unsorted-object vectors, compare explicit hand-authored bytes or independently derived invariants and parse those bytes with the target-native decoder.

* * *

### `ADR009-RR2-F003` — public `JsonEncoded(String)` remains a forgeable success wrapper

**Severity:** `major`  
**Confidence:** high

**Observed fact**

`WireJsonEncoding` remains a public enum whose success constructor directly accepts a string:

haxe

```
JsonEncoded(value:String);
```

Its documentation says a success is safe to hand to a native decoder: `packages/contracts/src/wordpress/hx/contracts/WireJsonEncoding.hx:3-11`.

The prior rereview explicitly warned that `JsonEncoded(String)` must not be treated as an unforgeable capability because application code can construct the enum variant: `review/oracle/results/adr012-f004-rereview-0e01ab5/ORACLE-REREVIEW.md:82-92`.

**Assessment**

The current `OutputSinks` path does not accept a caller-provided `WireJsonEncoding`; it calls `encodeChecked` and immediately pattern-matches its return. Therefore this wrapper does not independently bypass the current `JsonPlan` sink.

However, its public documentation is false as a general type invariant: application code can construct `JsonEncoded("not JSON")`.

**Required correction**

Either make the result opaque/internal, or narrow its contract to “a `JsonEncoded` value returned directly by `CanonicalWireJson.encodeChecked`.” No trusted sink or native consumer may accept an independently supplied variant as proof of validation.

**Smallest decisive closure test**

Audit every consumer of `WireJsonEncoding` and establish that each obtains the value from a direct checked call within the same trusted operation. Add a compile/API negative if the intended design is actual opacity.

Repairs that are sound
----------------------

The following parts of the subject correction are supported:

*   **Exact depth semantics:** `MAX_CONTAINER_DEPTH` is 64; root traversal starts at depth zero; arrays and objects increment on entry; 64 containers pass and 65 reject; invalid configured limits reject without bytes. `CanonicalWireJson.hx:9,20-29,46-49,53-59,72-78`; `WireJsonBoundaryTest.hx:50-69`.
    
*   **Validate before ordering:** object names pass `snapshotString` before being inserted and sorted. `CanonicalWireJson.hx:79-104`.
    
*   **Snapshot isolation:** arrays, fields, and values are copied into private snapshot types, and encoding consumes only those types. `CanonicalWireJson.hx:60-69,79-104,141-155,189-205`; mutation assertion at `WireJsonBoundaryTest.hx:80-91`.
    
*   **C0 encoding:** quote, backslash, named controls, and all remaining C0 bytes are escaped. `CanonicalWireJson.hx:158-185`.
    
*   **No weak Haxe escape in the bounded implementation:** my source scan found no `Dynamic`, `Any`, `Reflect`, `untyped`, or `cast` occurrence in the selected contract/output implementation and test surfaces.
    
*   **Ordinary raw-success factory removed:** the normal public sink route invokes `encodeChecked`, and the former `JsonPlan.success` member no longer exists. `OutputSinks.hx:57-87`; `json_plan_success/Main.hx:1-6`.
    

Native-decoder and oracle assessment
------------------------------------

I independently parsed the supplied `fixtures/output-context/expected/context-plan.txt` with Node 22.16.0 and PHP 8.4.23:

```
node-native-json=passed c0=32 rejections-zero-bytes=3
php-native-json=passed c0=32 rejections-zero-bytes=3
```

All 32 C0 strings round-tripped, no raw C0 byte remained in encoded JSON, and the three existing modeled rejections carried zero bytes. These decoder results are independent of the Haxe encoder, but I could not regenerate the plan from the subject source locally.

The expected plan is therefore useful decoder evidence rather than a reproduced cross-target build. The boundary transcript is less independent: accepted cases record only `encoded`, not the actual bytes.

The exact hosted output-context run `30517289414` is green at commit `552c7af`. The exact aggregate repository run `30517289423` is red, although its repository, contract-schema, WordPress-runtime, and security jobs succeeded; the Haxe job failed during installation of the generated-PHP quality toolchain. It must not be described as an all-green aggregate. [![](https://www.google.com/s2/favicons?domain=https://github.com&sz=128)GitHub+6![](https://www.google.com/s2/favicons?domain=https://github.com&sz=128)GitHub+6![](https://www.google.com/s2/favicons?domain=https://github.com&sz=128)GitHub+6](https://github.com/fullofcaffeine/wordpresshx/actions/runs/30517289414)

The integration prose overstates the evidence when it says the repair validates “every public shape” and that the non-strict corpus proves modeled rejection: `review/oracle/results/adr012-f004-rereview-0e01ab5/INTEGRATION.md:23-29`. The receipts themselves correctly remain pending and keep acceptance/publication false: `integration.json:38-44`.

Commands actually run
---------------------

Environment:

```
Debian GNU/Linux 13 (trixie), Linux 6.18.35 x86_64
Node 22.16.0
npm 10.9.2
PHP 8.4.23
Python 3.13.5
Git 2.47.3
TypeScript 5.8.3
Haxe unavailable
Haxelib unavailable
Lix unavailable
Docker unavailable
```

Executed successfully:

```
sha256sum -c SHA256SUMS
```

Custom inventory verification:

```
inventory-files=556 haxe-files=459 mismatches=0
```

Source scans covered all selected Haxe files for JSON success wrappers, constructors/factories, access metadata, weak-type constructs, and unchecked raw-string paths.

Native probes:

```
Node/PHP parsing of fixtures/output-context/expected/context-plan.txt
Node/PHP C0 round-trip checks
Node JSON.parse("") failure probe
PHP json_decode("", ..., JSON_THROW_ON_ERROR) failure probe
```

Attempted but not completed:

```
python3 scripts/contracts/validate-schema-authority.py
python3 scripts/output-context/validate-architecture.py
```

Both stopped because the selective packet does not contain `packages/gutenberg/dependency-lock.json`.

```
bash scripts/contracts/test-schema-authority.sh
```

Stopped immediately because `haxelib` is unavailable.

```
bash scripts/output-context/test.sh
```

Stopped immediately because `docker` is unavailable.

`scripts/check-repository.sh` was not present in the reconstructed selective packet. `git diff --check` was not run because the packet contains no `.git` directory or index.

Closure authority
-----------------

*   **Bead `wordpresshx-g4.1.1`: may not close.**
    
*   **`ADR009-RR-F001` depth correction: may close as a bounded subfinding.**
    
*   **ADR-009 checked-encoder hardening as a whole: may not return to its prior bounded accepted state.**
    
*   **`ADR012-F004-RR-F001` and ADR-012 F004: may not return to their prior bounded accepted state.**
    
*   **ADR-012 as a whole remains open to the extent its status depends on F004.**
    

This decision grants **no publication, licensing, legal, or general production-support authority**.

CAF\_ORACLE\_COMPLETE orq\_20260808T182309Z\_38b28701 0c94ac93bc7ec83356f841aa9590fe0b82a97c2f3c1c352ad69486b8f9fe45b4
