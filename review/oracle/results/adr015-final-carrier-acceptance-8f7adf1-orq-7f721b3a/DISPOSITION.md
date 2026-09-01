# ADR-015 final carrier acceptance disposition

## Request and decision

- Request: `orq_20260831T203709Z_7f721b3a`
- Owner: `wordpresshx/wordpresshx-maintainer`
- Consultation: review with GPT-5.6 Pro
- Requesting model and reasoning: `gpt-5.6-sol` at `xhigh`
- Reconciliation model and floor: `gpt-5.6-sol` at `xhigh`
- Captured stage SHA-256: `b5c85d18b89c7669b371b009efbe241908e719770c3c2b0237083a190f052814`
- Response completion SHA-256: `b56db229da84863f4bf4886ea33e2f1ab16d193e3f21c73d9c0202c3748bdc24`
- Response state: complete, with no attachments
- Oracle verdict for the reviewed revision: `changes required`
- Integrated decision: retain both F001 findings. Confirm F002 through F010 as closed. Keep ADR-015 proposed and `wordpresshx-g6.1` open.

## Local baseline before response access

The baseline was recorded before the response text was opened.

- `HEAD` and `origin/main`: `8f7adf178c47ac34e7af74c3fa3b80c1b64633f0`
- Executable parent: `fd42f0bbfd9f7af0e5ad95ede7539a1e0ca5f8d5`
- Tracked worktree and index: clean
- ADR status: `proposed`
- Receipt status: `implemented-hosted-and-review-pending`
- Content root: `c58bae146b1fd7cf9c694ea76732d8feece47fa6e1c0657d005cdeddcfc9a2b7`
- Evidence subject: `3a2d1d4c56c9956761537ddf3b14bcdca97bef5ad4a1d204e28853f6e01b16cb`
- Hosted gate identity: `630301ab4bfd2f75798165af4b4fa0a398dba3b4df8acc1a7208457fe6b00745`
- Bead `wordpresshx-g6.1`: `in_progress`
- Bead `wordpresshx-adr-015`: `blocked`
- Pinned Beads client: `bd 1.1.0 (c3e600c94)`; read-only schema 1 opened successfully
- Provisional rule: accept only if no critical or major finding reproduces.

The protected repomix XML and ZIP remained unread and unchanged.

## Claim matrix

| Claim | Oracle result | Independent disposition | Evidence and action |
| --- | --- | --- | --- |
| F001a: result getter escapes cleanup | Major, open | Retained and reproduced | The committed facade inspected `value.then` after its final restoration check. The new proxy-getter case reached the real typed Haxe Promise chain, printed the normal success line, and exited 0. Result inspection now occurs inside the restoration `try/finally`. The regression requires the shared mutation error, no success line, and no malicious callback sentinel. |
| F001b: provider can replace the runtime observer | Major evidence defect, open | Retained and reproduced | The frozen observer value was assigned to a writable global property. A provider replaced it and the Haxe tracer still printed its normal success line. The probe now uses captured intrinsics and a non-writable, non-configurable property. It also checks the exact lexical object and descriptor after provider initialization. |
| F002: precise JavaScript typing | Closed | Confirmed closed | Generated Haxe keeps JavaScript numbers as `Float` and object results as the nominal opaque type. The strict scan and compile corpus contain no weak fallback. |
| F003: independent static JavaScript observer | Closed | Confirmed closed | The observer uses pinned TypeScript syntax and does not import the Python ABI model or execute provider code. The runtime observer defect is confined to F001b. |
| F004: caller authority construction | Closed | Confirmed closed | Ten negative Haxe fixtures reject token, scope, observation, friend-path, hostile-define, and access-metadata forgery on the applicable targets. |
| F005: exact provider and bundle bytes | Closed | Confirmed closed | Each native facade verifies the bundle and exact provider bytes before execution. JavaScript imports the captured module bytes and does not reopen the provider path. |
| F006: finite bundle and ownership | Closed | Confirmed closed | The bundle requires unique roles and paths. The generated ownership manifest owns the bundle, all members, and both anchors. |
| F007: target executable identity | Closed | Confirmed closed | PHP, JavaScript, and generated-Haxe closure identities remain bound to the current content root and evidence subject. |
| F008: schemas and mutation coverage | Closed | Confirmed closed | Ajv 2020-12 schema adversaries and 84 independently re-digested mutations passed in both focused runs. |
| F009: captured-stage publication | Closed | Confirmed closed | `ArtifactOwner` captures the manifest and stage once. Validators read copy-only snapshots, and publication uses those captured buffers without reopening caller paths. |
| F010: evidence freshness and runtime identity | Closed | Confirmed closed | The evidence subject includes both workflows, repository gate, fixture, scripts, schemas, and locks. The gate requires locked CPython 3.14.5 before project Python runs. |
| Historical hosted identities | Correct | Confirmed | GitHub records the focused job and all 13 repository jobs as successful on `fd42f0b`. Three companion workflows also succeeded. These runs predate the two new adversaries and do not close them. |
| Removing the private payload | Optional alternative | Not required | The targeted repair keeps the generated opaque-object behavior. All provider-controlled validation is now inside the restoration envelope. No owner decision is required for this fix. |

## Integrated conclusion

The Oracle verdict is correct for reviewed commit `8f7adf1`. Both major F001
defects reproduced. No critical defect reproduced, and F002 through F010 remain
closed.

Only the retained defects were repaired. The generated facade now checks the
provider result inside the shared-intrinsic restoration envelope. The runtime
probe now gives its observer an immutable binding and checks its identity after
provider initialization. Two exact adversaries preserve these behaviors
through the real Haxe-to-JavaScript path.

The documented boundary is now explicit. Same-realm proof covers provider
import, synchronous calls, and result inspection. It does not claim containment
of arbitrary work scheduled after a call returns. Such a provider needs a
separate realm or process before production trust admission.

The repaired subject is not yet accepted. Current hosted proof and another
fresh exact-revision review are still required. ADR-015 stays proposed, and
`wordpresshx-g6.1` stays in progress.

## Verification and gaps

Verified against the reviewed checkout and the retained repair:

- both exact F001 regressions failed before their repairs with exit 0 and the
  normal typed-Haxe success line;
- the focused local gate passed with all five observer groups;
- the forced-container PHP gate passed with all five observer groups;
- current content root:
  `67c2214877c2f0d693287a2c2758160c824ade6674c47b30deacc9c6f11b8d11`;
- current evidence subject:
  `12416a5147c01203023ea93222ece17d5d1730e03eae1a43df450a227ff7c60b`;
- current gate identity:
  `b8fa2369434c40761e80819634568a78e94ddc746465a6aef29968838b5aab4b`;
- historical hosted run `33434912827`, job `99628864070`, passed on
  `fd42f0b`;
- historical repository run `33434913127` passed all 13 jobs on that commit;
  and
- Windows `33434912820`, output-context `33434912903`, and unsafe-boundary
  `33434912775` also passed on that commit.

Remaining gates:

- run the complete repository gate for the repaired subject;
- commit and push the repair to `main`;
- obtain current hosted focused and repository proof;
- seal those hosted identities into the receipt; and
- obtain fresh exact-revision Oracle acceptance before ADR or Bead closure.
