# ADR-012 F004 final-acceptance review integration

## Reviewed identity

- caf-oracle request: `orq_20260810T023318Z_cdd348fe`
- consultation mode: `review`
- Oracle model: GPT-5.6 Pro
- reviewed commit: `1bb877ee69e4d2815ee5254056363a691fe0d703`
- reviewed tree: `4bbeca22538894f31a035a1ec9b5a4d00f04703f`
- prompt SHA-256: `317f1561ae2ac165342ebb1fb86d7eeb0c2dd088caea3605530036d278d4e66c`
- bundle SHA-256: `35883546b4dfdf045c38c11f2fea3ff90468d1f8d8cdca8383023afd1a63d475`
- bundle size: 523,950 bytes
- Oracle completion digest: `3d1fc76b72bdf02f61b62394e3bd47e58918075b3652e6ea51bf3dc818a24071`
- decision: `changes-required`
- confidence: `0.96`

The request used a selective content-addressed packet containing 118 exact files: the ADR-009 and ADR-012 sources, tests, validators, receipts, Bead authority, dependency identity, and all earlier ADR012-F004 review records. Requester-owned local Repomix exports and unrelated product surfaces were not uploaded.

## Local second-opinion disposition

The Oracle response is retained as advisory evidence after independent source inspection and focused runtime reproduction. It does not authorize publication or broaden any product claim.

### `ADR009-RR5-F001`: retained, blocking-high

`CanonicalWireJson.encodeChecked` accepts a public `maxDepth:Int`, but the generated JavaScript boundary can receive a non-Haxe number. `Number.NaN` makes the current lower-bound, upper-bound, and recursive depth comparisons all evaluate false.

The current Genes 1.41.4 output was generated from the reviewed source under strict TypeScript 5.9.3 and Node 22.17.0. A focused foreign-boundary probe supplied 65 nested `ArrayValue` containers and `Number.NaN` as `maxDepth`. It observed:

```text
nan-depth-index=0
RED: NaN maxDepth admitted 65 containers
```

Index zero is `JsonEncoded`, so this defeats the hard 64-container invariant. The finding is not merely a source-level possibility.

Disposition: runtime-admit the depth argument before comparisons, or remove the public caller-controlled limit in favor of the fixed 64 policy. Add `NaN`, fractional, string, boolean, infinity, 65-container, and cycle foreign vectors. Every malformed limit must return a stable rejection with no bytes or escaped exception.

### `ADR009-RR5-F002`: retained, blocking-high

The latest repair guards passive malformed object-field reads, but `snapshotArray` still observes `values.length` and `values[index]` outside a checked exception boundary. `snapshotObject` also evaluates `fields.length` before its element-level `try`.

The same generated Genes boundary received a real JavaScript array whose index-zero accessor throws. The focused probe observed:

```text
RED: accessor escaped: wire-array-getter
```

The probe exited non-zero for the intended reason. This is an input through the maintained foreign-value boundary, not modification of generated artifacts.

Disposition: make the snapshot phase exception-total at every foreign observation point, with stable modeled rejection and no encoded bytes. Keep private snapshot encoding outside a broad foreign-input catch so internal encoder failures are not mislabeled. Add throwing element and throwing length/proxy vectors; add the closest faithful generated-PHP boundary vector supported by its array representation.

### `ADR012-EVIDENCE-RR5-F001`: retained, major

No raw-string `JsonPlan` success factory exists in the reviewed source. This is an evidence-sensitivity gap rather than a current bypass.

The local validator audit confirmed that `validate-architecture.py` searches only the suffix after `final class JsonPlan`. A simulated public `OutputSinks` factory accepting `encoded:String` therefore remains outside the regex, while the compiler guard intentionally permits `JsonPlan` construction owned by `OutputSinks`. The local static probe reported:

```text
validator_suffix_detects_injected_owner_factory=False
guard_allows_output_sinks_owner=True
```

Oracle independently mutation-tested the full validator: after regenerating the expected source digest, the unsafe factory mutation still passed all 36 recorded independent mutations. The exact packet bytes were then restored and reverified.

Disposition: validate the trusted `OutputSinks` owner seam semantically. Prefer an explicit allowlist of the two public typed APIs, `restJson(JsonDocument)` and `scriptData(HtmlScriptData)`, plus a mutation that adds a raw-string-returning `JsonPlan` factory and must fail even after expected evidence hashes are regenerated.

## Findings not reopened

Source review and the Oracle challenge found no current caller-authored JSON string path to successful `PlanEncoded` state. The following prior bypass classes remain closed within the declared compiler profile:

- public `JsonPlan.success`;
- direct and private construction, including `@:privateAccess`;
- constructor and class-initializer traversal omissions;
- `Type.createInstance` and aliases;
- `Type.createEmptyInstance` and `haxe.Unserializer` reconstitution;
- forged enum identity, index, constructor name, and arity;
- passive null or malformed scalar, field, Unicode, duplicate-key, and integer payloads;
- valid-integer 64/65 container counting;
- passive post-validation mutation.

The current receipts also correctly record the Docker-backed WordPress lane as not run. That lane is not treated as proof for the generic checked-JSON boundary.

## Authority disposition

- `ADR012-F004`: remains open.
- ADR-009 checked-encoder hardening: remains pending changes.
- `wordpresshx-g4.1.1`: remains in progress.
- publication or production support: not authorized.

No product-owner decision is required. The repository should repair the stronger existing total-foreign-boundary contract rather than narrow it to passive data, because the correction is feasible and the current Bead explicitly promises stable rejection without escaping target exceptions.

## Required next proof

1. Preserve the two focused red reproductions above.
2. Repair runtime depth admission and exception-total snapshot observation at the lowest owner.
3. Add the trusted-owner raw-factory mutation to the ADR-012 semantic validator.
4. Run the exact ADR-009 Haxe, Genes/strict TypeScript/Node, PHP, foreign-boundary, and native-decoder matrix.
5. Run the ADR-012 non-WordPress lanes and keep WordPress explicitly not run if Docker remains unavailable.
6. Run the full repository, formatting, strict-Haxe, hook, Gitleaks, and local-path gates.
7. Bind a new exact commit to a fresh independent acceptance review before closing the Bead.

An initial local reproduction attempt was excluded from evidence because the compiler rejected a symlinked temporary output path before reaching the codec. The successful reproduction used a physical isolated path and exercised the generated boundary directly.

## Local repair evidence

The focused probes were red before the repair. Genes and PHP both emitted
bytes when `maxDepth` was `NaN`. Genes also let a throwing array accessor
escape.

The repair admits the foreign depth value before comparisons. It also guards
each foreign observation in the snapshot phase. The new tests cover malformed
depth values, a cycle, throwing array elements, and throwing JavaScript
lengths.

`bash scripts/contracts/test-schema-authority.sh` now passes these lanes:

- Haxe 4.3.7 interpretation;
- Genes 1.41.4 with strict TypeScript 5.9.3 and Node 22.17.0;
- generated PHP on PHP 8.4.7;
- native Node and PHP decoders;
- both foreign-value probes.

`bash scripts/output-context/test.sh` passes the architecture and React lanes.
The architecture validator now rejects the unsafe owner-factory mutation. The
WordPress lane did not run because Docker is unavailable.

These results repair the retained findings on the local branch. They do not
change the review decision for commit `1bb877e`. A new exact-commit acceptance
review is still required before the Bead can close.

## caf-oracle ledger state

caf-oracle captured the exact response. The installed client cannot process
or archive it. The ledger lacks the current model-proof version, phase, and
observed-reasoning fields.

A read-only model audit confirmed this state. No ledger bytes were edited. No
replacement request was sent. Separate active caf-oracle work owns this client
compatibility problem.

The local repair relies on the independent red reproductions above. It does
not treat the unprocessed response as automatic authority.
