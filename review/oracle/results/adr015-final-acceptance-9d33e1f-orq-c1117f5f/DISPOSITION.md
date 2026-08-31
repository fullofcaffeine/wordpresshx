# ADR-015 exact-revision acceptance review disposition

## Request and decision

- Request: `orq_20260831T061750Z_c1117f5f`
- Owner: `wordpresshx/wordpresshx-maintainer`
- Consultation: review, GPT-5.6 Pro, requested by `gpt-5.6-sol` at `xhigh`
- Reconciliation: `gpt-5.6-sol` at the `xhigh` floor
- Prepared packet SHA-256: `27d2d39f86ce9761c30073d64ed82e86c87d50c64a271c739ef2ba12f0d55176`
- Captured stage SHA-256: `bb46196073928ba631c1cb5cbb61e4467acbf69947d699ba2ff3f563d440dc16`
- Response completion digest: `00d1279bb35086c3faea8f1f2bf4c344d9e7fabf5cf6c7154dd19d0148577f0c`
- Response state: complete, with no response attachments
- Oracle verdict at the reviewed revision: `changes required`
- Integrated decision: retain F001 only. Keep ADR-015 proposed and `wordpresshx-g6.1` open until the repaired revision has current hosted proof and fresh independent acceptance.

## Local baseline before reading the response

The baseline was recorded before response text was opened.

- `HEAD` and `origin/main`: `9d33e1ff967ba6b3681b15e23bdbd976bd9861e8`
- Tracked worktree and index: clean
- ADR status: `proposed-pending-fresh-review`
- Receipt status: `implemented-hosted-and-review-pending`
- Acceptance and publication: false
- Content root: `8119ccf035373fa74e79280a9229e49735eee5a413f4829ae92ac29b98b8cf65`
- Evidence subject: `410a548eff6a5595ac3f88000963bbdbf916dfe8c33f0a2f46fb3a4d58915edd`
- Hosted gate identity: `d1a981276e17f0f895dbff48bf17957f0e22e2c37cfa31437bdffeacd70a5207`
- Bead `wordpresshx-g6.1`: `in_progress`
- Bead `wordpresshx-adr-015`: `blocked`
- Pinned Beads client: `bd 1.1.0 (c3e600c94)`, read-only schema open succeeded
- Provisional rule: accept and close only if no critical or major finding reproduces against this checkout.

## Claim matrix

| Finding | Oracle result | Independent disposition | Evidence and action |
| --- | --- | --- | --- |
| F001 JavaScript carrier and handle provenance | Retained, major | Retained and reproduced | An exact provider replaced `Object.create` after provider execution. Its proxy passed the old frozen/null-prototype/zero-key and single-`then` observer, then exposed a callable `then`. A separate inherited-`then` provider interposed on the asynchronous return chain. The generated facade now captures construction, freezing, deletion, descriptor inspection, and bound `WeakMap.set` intrinsics before provider execution. It returns frozen null-prototype carrier and handle records, restores and rejects shared `Object.prototype.then` mutation, and uses a captured multi-read observer. Both exact providers are executable regressions through the real typed Haxe crossing. |
| F002 precise number/object typing | Closed | Closed | Generated Haxe still maps JavaScript number to `Float` and preserves the result as the exact opaque generated object. The strict scan and compile corpus found no weak fallback. |
| F003 independent JavaScript observation | Closed | Closed | The pinned TypeScript parser remains independent of the Python producer and provider execution. The focused gate reran its source/runtime adversaries. |
| F004 Haxe authority construction | Closed | Closed | Hostile define, `@:access`, direct construction, observation, scope, and legacy friend-path negatives all failed under Haxe 4.3.7. The JavaScript handle defect did not expose Haxe authority construction. |
| F005 exact provider and bundle bytes | Closed | Closed | Native facade tests rechecked captured bundle members, anchors, exact package/module and plugin bytes, versions, symbols, absence, swap, and failure paths. |
| F006 finite ownership graph | Closed | Closed | The production owner rejected stale semantics before effects and passed publish, no-op, update, removal, rollback, and provider-untouched cases. |
| F007 target executable identity | Closed | Closed | The PHP plugin and JavaScript package/module closures remained the exact target identities exercised by the native tests. |
| F008 schemas and mutation coverage | Closed | Closed | Ajv 2020-12 closed-schema/path adversaries and the 84 independent semantic mutations passed. |
| F009 captured-stage publication | Closed | Closed | Publication continued to use the validated copied snapshot; post-capture caller mutation could not change published bytes. |
| F010 executable freshness | Closed | Closed | `scripts/adoption/test-evidence.py` proved both repository-owning paths are direct evidence subjects and exercised Python setup order/version, refresh/validation removal, interpreter drift, and owning-path mutations. No receipt cycle or omitted executable subject reproduced. |

## Integrated conclusion

The response correctly rejected acceptance at `9d33e1f`. F001 reproduced in both forms, so it was not treated as advisory. No critical finding reproduced. F002 through F010 agree with the current code and the complete focused proof.

Only F001 was changed. The repair protects the public boundary without adding a provider sandbox or changing the provider-runtime ownership model. Captured intrinsics construct the carrier and handle before any provider-controlled lookup can substitute them. A provider that leaves an inherited `then` mutation is restored and rejected before the async handle crosses. The observer captures its structural functions before provider execution and performs repeated `then` reads as regression evidence; provenance comes from the captured native constructor, not from the finite reads.

After repair, the current local state is:

- Content root: `c58bae146b1fd7cf9c694ea76732d8feece47fa6e1c0657d005cdeddcfc9a2b7`
- Evidence subject: `3a2d1d4c56c9956761537ddf3b14bcdca97bef5ad4a1d204e28853f6e01b16cb`
- Hosted gate identity: `630301ab4bfd2f75798165af4b4fa0a398dba3b4df8acc1a7208457fe6b00745`
- Local observation: passed under CPython 3.14.5, Haxe 4.3.7, Node 22.17.0, and PHP 8.4.7
- Forced-container observation: passed with pinned PHP 8.4.7
- Complete repository bootstrap: passed
- Hosted current-main observation: pending
- Fresh independent acceptance of these repaired bytes: pending

This disposition therefore does not accept ADR-015 and does not authorize closing `wordpresshx-g6.1`. Those actions require the two pending items above.

## Verification and gaps

Reproduced before repair:

- The exact carrier-substitution provider made the real Haxe observer fail with `Haxe observer received a mutable or thenable JavaScript carrier` after the second `then` read.
- The exact inherited-`then` provider produced `provider-owned-handle-proxy-crossed` through the old asynchronous handle path.

Passed after repair:

- exact focused native Haxe/PHP/JavaScript crossing under Node 22.17.0 and PHP 8.4.7
- deterministic generator comparison against the checked-in fixture
- `python3 scripts/adoption/test-evidence.py`
- `python3 scripts/adoption/refresh-evidence.py`
- `python3 scripts/adoption/validate-architecture.py`
- `bash scripts/adoption/test.sh` with a durably recorded local observer set
- `WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP=1 bash scripts/adoption/test.sh` with a durably recorded container observer set
- `bash scripts/check-repository.sh`

This remains a bounded synthetic architecture fixture. It does not prove a real provider, WordPress runtime, PHP 7.4, isolated reflection, package consumer, production SDK-070/SDK-073 behavior, SDK-117 trust admission, publication, or production support.
