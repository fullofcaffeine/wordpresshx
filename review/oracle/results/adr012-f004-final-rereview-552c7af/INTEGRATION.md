# ADR-012 F004 final rereview integration

## Bound response

The `caf-oracle` ledger captured a GPT-5.6 Pro critical review for request
`orq_20260808T182309Z_38b28701`.

- reviewed commit: `552c7affabe16af9a1976cf6393ed34f4ba31a2b`
- reviewed tree: `4e27f5e61cce0b7aff947c44c334eee39477e43b`
- prompt SHA-256: `607943e56c0aff103b067f2d8fc61de5833c8ea64fe6ba92ccd0027798746381`
- prompt-body/completion SHA-256: `0c94ac93bc7ec83356f841aa9590fe0b82a97c2f3c1c352ad69486b8f9fe45b4`
- bundle SHA-256: `2e29e2c35f00f6fc4f000c1c2584de5c6d44fbd367b0cfc76d3c04a5b19e7b3b`
- captured response SHA-256: `9798c182dcf796e8006654259a88cdd48aea7a7fd968c29bf91cf8f03d796562`
- conversation handle: `convo_9f46ba5a55f61816`
- requested/observed model: `GPT-5.6 Pro` / `Pro`
- decision: `changes-required`, high confidence

The ledger records confirmed dispatch, the matching conversation, and the exact
completion sentinel. The response is preserved verbatim in
[`ORACLE-REREVIEW.md`](ORACLE-REREVIEW.md). Oracle is advisory evidence; the
local disposition below is based on independent reproduction against current
source.

## Current-subject check

Current `main` was `eb9a5b5ea75b4282b9f26c3e800bd1eb4dbec175`, tree
`685d73859ed11200bce675e56563f0bbadddd6c1`, during reconciliation. Git reports
no changes since the reviewed commit in the JSON encoder, output codec/sink,
boundary fixtures, or focused gate scripts named by the findings. The material
source defects therefore remain present on current `main`.

## Local reproduction

A disposable strictly typed Haxe fixture exercised the public APIs without
`Dynamic`, `Any`, `cast`, `Reflect`, or `untyped`. Haxe interp, stock Haxe
JavaScript/Node, stock Haxe PHP, and Genes 1.38.0 followed by strict TypeScript
all produced the same observations:

```text
private-access-plan={"forged":true}:
empty-failure-plan=:
integer-null=encoded:null
bool-null=encoded:false
```

The first line was created with expression-level `@:privateAccess` and the
private `JsonPlan` constructor. The second came through an ordinary
`OutputCodec` returning `EncodingFailure("")`. The last two came from
`CanonicalWireJson.encodeChecked(IntegerValue(null))` and
`CanonicalWireJson.encodeChecked(BoolValue(null))`. Native Node `JSON.parse("")`
and PHP `json_decode("", ..., JSON_THROW_ON_ERROR)` both rejected the empty
bytes.

The unchanged ADR-009 focused gate nevertheless passed across Haxe interp,
Genes/strict TypeScript/Node 22.17.0, and PHP 8.4.7. This confirms a test-
sensitivity gap: its non-strict malformed corpus still uses stock Haxe
JavaScript instead of Genes and omits these cases. The ADR-012 focused gate
passed architecture, formatting, and React stages, then stopped because the
local Docker daemon was unavailable; no WordPress/Docker result is claimed for
this reconciliation.

## Finding dispositions

### `ADR012-F004-RR2-F001` — retained, blocking-high

`EncodingFailure("")` produces `encoded == ""` and `failureReason == ""`.
Native consumers use the empty reason as the success sentinel and can invoke a
decoder on empty bytes. This is independently reproduced on every available
target lane.

Correction: replace paired-string sentinel state with a closed plan result.
Rejection must be structurally distinct, carry no encoded bytes, and have a
stable diagnostic even when the application supplies an empty or null reason.
Native consumers must branch on the result variant before accessing bytes.

### `ADR012-F004-RR2-F002` — retained, blocking-high claim/enforcement gap

`@:privateAccess` successfully constructs a forged `JsonPlan` on interp,
Genes/strict TypeScript, stock JavaScript, and PHP. Haxe visibility is ordinary
API encapsulation, not an unforgeable capability against application metadata
or macros.

The Oracle's observation is retained, but its alternatives require a bounded
architecture choice. Either inspect the post-expansion typed construction graph
and reject every plan construction outside the sink, or explicitly narrow the
claim and govern access-control metadata as an unsafe boundary. A source-text
ban alone is insufficient because macros can synthesize metadata or calls.

### `ADR009-RR2-F001` — retained, blocking-high

Null integer and boolean payloads are accepted and silently change semantics to
JSON `null` and `false` on all reproduced targets. The current snapshot switch
does not validate those scalar payloads.

Correction: reject malformed scalar payloads before snapshot construction,
enforce the signed-int32 contract at target-owned foreign adapters, and contain
all failure before bytes exist. Wrong runtime scalar kinds, out-of-range values,
and invalid enum/tag shapes remain required adversarial tests; this local
reconciliation independently reproduced the null cases only and does not
mislabel the other cases as executed facts.

### `ADR009-RR2-F002` — retained, major

The decisive boundary corpus runs interp, stock Haxe JavaScript, and PHP, while
the ordinary strict corpus uses Genes. The Genes omission is visible in
`scripts/contracts/test-schema-authority.sh`. The disposable strict Genes
reproduction demonstrates that the current defects survive that target too,
but it does not replace a maintained identical cross-target corpus.

Correction: execute one semantic boundary corpus through interp,
Genes/strict-TypeScript/Node, and PHP, with target-native injection where strict
typing intentionally prevents malformed Haxe construction. Accepted cases must
assert independently reviewed bytes and native decoding, not only the success
variant label.

### `ADR009-RR2-F003` — retained, major API-contract issue

`WireJsonEncoding.JsonEncoded(String)` is publicly constructible while its
documentation describes every success value as decoder-safe. It does not
currently bypass `OutputSinks`, because that sink consumes only the immediate
result of `encodeChecked`; it is therefore not independently classified as a
current sink blocker.

Correction: make the result opaque/internal or narrow the contract to values
returned directly by `encodeChecked`, then audit every consumer so no native
boundary accepts a caller-constructed variant as proof.

## Retained closures and limitations

The Oracle's closure of `ADR009-RR-F001` is accepted: container nesting now has
one shape-independent hard maximum of 64. Validate-before-sort, immutable
snapshot encoding, C0 escaping, and removal of the ordinary public
`JsonPlan.success` factory also remain sound.

The packet's selective source inventory prevented Oracle from rerunning two
Python validators that require the Gutenberg dependency lock. Local execution
of the complete ADR-009 gate filled that gap and passed. Oracle could not run
Haxe or Docker; local Haxe/Genes/PHP reproductions establish the retained source
defects, while Docker-dependent WordPress proof remains unexecuted here.

## Authority disposition and next sequence

- `wordpresshx-g4.1.1` remains `in_progress` and may not close.
- ADR-009 checked-encoder hardening may not return to its prior bounded accepted
  state, except that the depth subfinding is closed.
- ADR-012 F004 remains open; no other retained ADR-012 finding is reopened
  without a concrete regression.
- No publication, licensing, legal, or general production-support authority is
  granted.

The remediation sequence is: introduce an explicit plan-result algebra; close
empty/null failure handling; validate scalar/foreign shapes; decide and enforce
the post-expansion construction/unsafe-metadata boundary; run one identical
Genes/interp/PHP corpus with native decoder assertions; repair the public
`WireJsonEncoding` contract; then obtain the independent acceptance required by
the existing Bead before closure. This reconciliation does not dispatch another
Oracle request.
