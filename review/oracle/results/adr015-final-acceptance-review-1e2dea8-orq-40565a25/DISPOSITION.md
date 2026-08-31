# ADR-015 final acceptance review disposition

## Request and decision

- Request: `orq_20260831T043455Z_40565a25`
- Owner: `wordpresshx/wordpresshx-maintainer`
- Consultation: review, GPT-5.6 Pro, requested by `gpt-5.6-sol` at `xhigh`
- Reconciliation: `gpt-5.6-sol` at the `xhigh` floor
- Prepared packet SHA-256: `ca6a4eaea2f0dd5959483b172c41e3457c56be623066535c2712fd5f8846b0da`
- Captured stage SHA-256: `73096cd301d3ff1cf0816feedd1ec0463658b2448d328cb73458cfcb8a8bc8d6`
- Captured response file SHA-256: `094ccae907a538ec6717355d4b05c4c7c336148fa1975e89c8248e205dd2605a`
- Response completion digest: `00e2e862446c86741fac318e1fbf8a1790f3ee90c8ed2e56de80639d67f1590d`
- Response state: complete, with no response attachments
- Oracle verdict at the reviewed revision: `changes required`
- Integrated decision: retain F001 and F010. Keep ADR-015 proposed and `wordpresshx-g6.1` open until the repaired revision has current hosted proof and fresh independent acceptance.

## Local baseline before reading the response

The baseline was recorded before response text was opened.

- `HEAD` and `origin/main`: `1e2dea8f1e560d4b50035b217afdf783b08daa88`
- Tracked worktree and index: clean
- ADR status: `proposed-pending-fresh-review`
- Receipt status: `implemented-hosted-and-review-pending`
- Acceptance and publication: false
- Content root: `c2a0a55dd274ead37af78c2ea2d53a43cdc7868c9fb80949e9cc246e2c57088a`
- Evidence subject: `816fe7d99206d51b953f4fac7ee4b44aff115a3168c7363f4ab82c5b85307779`
- Bead `wordpresshx-g6.1`: `in_progress`
- Pinned Beads client: `bd 1.1.0 (c3e600c94)`, read-only schema open succeeded
- Provisional rule: accept and close only if no critical or major finding reproduces against this checkout.

## Claim matrix

| Finding | Oracle result | Independent disposition | Evidence and action |
| --- | --- | --- | --- |
| F001 JavaScript declaration and result boundary | Retained, major | Retained and reproduced | A frozen provider object changed its `then` getter from `undefined` inside the facade to a function after return. The generator now returns a facade-owned frozen, null-prototype carrier with no keys or inheritance. A test-only typed Haxe observer verifies it after the real adapter crossing, including a stateful/context-sensitive provider adversary. |
| F002 precise number/object typing | Closed | Closed | Generated Haxe still maps number to `Float` and preserves the object result as an opaque exact extern. The focused gate found no forbidden weak type. |
| F003 independent observer | Closed | Closed | The TypeScript AST observer remains separate from Python producer parsing and provider execution. The focused gate reran its declaration adversaries. |
| F004 caller-selectable ownership mint | Closed | Closed | Exact Haxe 4.3.7 hostile-define, `@:access`, construction, observation, scope, and friend-path negatives all failed as intended. No new mint path reproduced. |
| F005 complete runtime bundle verification | Closed | Closed | Native facade proof rechecked exact bundle members, anchors, provider bytes, versions, symbols, absence, swap, and failure paths. |
| F006 publication and ownership graph | Closed | Closed | The production owner again passed publish, no-op, update, removal, rollback, and provider-untouched cases after rejecting stale semantics before effects. |
| F007 target executable identity | Closed | Closed | Current target-local PHP and JavaScript closure identities remained exact through native execution. |
| F008 schema anchoring and path grammar | Closed | Closed | Ajv 2020-12 schema and anchored path adversaries passed. |
| F009 stage time-of-check/time-of-use | Closed | Closed | The ownership proof again published the validated captured snapshot and rejected candidate-derived semantic drift before transaction effects. |
| F010 evidence freshness and runtime identity | Retained, major | Retained and reproduced | Mutating `.github/workflows/repository.yml` or `scripts/check-repository.sh` left the old digest unchanged. Both are now direct evidence subjects. Tests cover Python setup order/version, removal of refresh or validation, and interpreter drift. |

## Integrated conclusion

The response correctly rejected acceptance at `1e2dea8`. Both retained majors reproduced, so neither was treated as advisory. No critical finding reproduced, and the response's closures for F002 through F009 agree with the inspected code and the complete focused proof.

Only the retained fixes were implemented. F001 now prevents a provider-owned object, getter, proxy surface, or prototype from crossing into Haxe. F010 now makes either owning repository path change the evidence digest. The direct path inventory was chosen instead of a new wrapper because it gives one freshness rule with no additional execution layer.

After repair, the current local state is:

- Content root: `8119ccf035373fa74e79280a9229e49735eee5a413f4829ae92ac29b98b8cf65`
- Evidence subject: `410a548eff6a5595ac3f88000963bbdbf916dfe8c33f0a2f46fb3a4d58915edd`
- Hosted gate identity: `d1a981276e17f0f895dbff48bf17957f0e22e2c37cfa31437bdffeacd70a5207`
- Local observation: passed under CPython 3.14.5
- Forced-container observation: passed under CPython 3.14.5 with pinned PHP 8.4.7
- Hosted current-main observation: pending
- Fresh independent acceptance of these repaired bytes: pending

Therefore this disposition does not accept ADR-015 and does not authorize closing `wordpresshx-g6.1`. Those actions require the two pending items above.

## Verification and gaps

Reproduced before repair:

- Stateful F001 result: `{"object":true,"frozen":true,"thenAfterFacadeReturn":"function"}`.
- F010 result: both omitted-path mutations reported `digestUnchanged: True` against evidence subject `816fe7d9...`.

Passed after repair:

- `python3 scripts/adoption/test-evidence.py`
- deterministic generator comparison against the checked-in fixture
- `python3 scripts/adoption/refresh-evidence.py`
- `python3 scripts/adoption/validate-architecture.py`
- `bash scripts/adoption/test.sh` with a recorded local observer set
- `WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP=1 bash scripts/adoption/test.sh` with a recorded container observer set
- `bash scripts/check-repository.sh`

The response's suggested explicit post-capture manifest/add/remove cases and regular-expression lexer adversary are minor defense-in-depth ideas, not reproduced acceptance blockers. They are not retained in this repair.

This remains a bounded synthetic architecture fixture. It does not prove a real provider, WordPress runtime, PHP 7.4, isolated reflection, package consumer, production SDK-070/SDK-073 behavior, SDK-117 trust admission, publication, or production support.
