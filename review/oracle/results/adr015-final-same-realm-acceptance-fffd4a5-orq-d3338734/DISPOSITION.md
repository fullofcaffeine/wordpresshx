# ADR-015 final same-realm acceptance disposition

## Local baseline

- Request: `orq_20260901T035046Z_d3338734`
- Owner: `wordpresshx/wordpresshx-maintainer`
- Consultation: review with GPT-5.6 Pro
- Requesting and processing model: `gpt-5.6-sol`
- Requesting and processing reasoning: `xhigh`
- Prompt SHA-256: `53502487c54843b0f6809ef471109363585602250ee75d8c3e08d7063de7fd99`
- Bundle SHA-256: `231e8af5beeb5c87fb3dc549ae891fb5b69a7945e8a2e54f5101b5354f7292f2`
- Captured stage SHA-256: `1aea1aea9c1b5e39c6a15c62165abe6de6b05c44e7e32df6a038a749e7c57e91`
- Response completion SHA-256: `909919920afd9b39858b4ee80bd2db07e552d8f1a4090b2c1e0162e4a6d88de2`
- Response state: complete, exact Pro proof valid, and no attachments
- Oracle verdict for the reviewed revision: `changes required`
- Integrated decision: retain and repair F001c. Confirm F001a, F001b, and F002 through F010 as closed. Keep ADR-015 proposed and `wordpresshx-g6.1` open.

The baseline was recorded before the response text was opened.

- `HEAD` and `origin/main`: `fffd4a5dbc7af0f994f3a91f329f7558d6c4e711`
- Executable parent: `35c138a0d0c89cc7c9512a1c74a3299bbb84d914`
- Tracked worktree and index: clean
- ADR status: `proposed-pending-fresh-review`
- Receipt status: `implemented-hosted-and-review-pending`
- Content root: `67c2214877c2f0d693287a2c2758160c824ade6674c47b30deacc9c6f11b8d11`
- Evidence subject: `12416a5147c01203023ea93222ece17d5d1730e03eae1a43df450a227ff7c60b`
- Hosted gate identity: `b8fa2369434c40761e80819634568a78e94ddc746465a6aef29968838b5aab4b`
- Bead `wordpresshx-g6.1`: `in_progress`
- Bead `wordpresshx-adr-015`: `blocked`
- Pinned Beads client: `bd 1.1.0 (c3e600c94)`; schema 1 opened read-only without skew.
- Provisional rule: accept only if no critical or major finding reproduces.

The two protected Repomix files remained unread and unchanged.

## Oracle claim matrix

| Claim | Classification | Independent evidence and consequence |
| --- | --- | --- |
| F001c: a callable export named `then` can substitute the dynamic-import result and defer a shared mutation until required-symbol inspection | Retained and reproduced | The real typed Haxe tracer exited 0 with `haxe-js-native\|immediate-string\|opaque-object-observed`. Its provider sentinel recorded normal provider execution, and its separate callback sentinel recorded `post-import inherited then called`. This is inside the documented synchronous import boundary. |
| Precise-or-omitted generation admitted this host-active export as an omitted value | Retained | The reviewed ABI model treated every declared `exported-value` as `dynamic-property`, and it had no rule for `then`. V1 now rejects this exact runtime export before generation with a stable diagnostic. |
| The independent JavaScript observer did not cover exported values | Retained for F001c | The reviewed observer intentionally filtered `exported-value` bindings from its function comparison. It now independently enumerates exported names and rejects `then`. |
| Required provider-symbol reads happened after the import restoration check | Retained | The reviewed facade read `CalendarBadge` and `formatCalendarLabel` after `finally`. Both reads now occur inside the same restoration boundary as dynamic import. |
| F001a: provider result inspection can escape cleanup | Confirmed closed | Provider call, shape checks, and `value.then` access remain inside one restoration boundary. The preserved result-getter adversary fails before crossing. |
| F001b: a provider can replace the independent observer | Confirmed closed | The observer is published through captured `defineProperty` as non-writable and non-configurable. Its exact lexical object and descriptor are checked before success. The replacement adversary remains fail-closed. |
| Module initialization lets provider code run before intrinsic capture | Rejected | Launcher and facade captures occur before the provider import in the actual module graph. F001c did not bypass those captures. |
| F002: precise JavaScript typing | Confirmed closed | Generated Haxe keeps precise scalars and the nominal opaque object. The strict scan and compile corpus introduced no weak fallback. |
| F003: independent JavaScript observation | Confirmed closed after repair | The TypeScript-AST observer remains independent of the Python model and now also rejects the host-active export name. |
| F004: caller authority construction | Confirmed closed | The negative Haxe corpus still rejects scope, observation, token, friend-path, hostile-define, and access-metadata forgery. |
| F005: exact provider and bundle bytes | Confirmed closed | Facades verify exact staged provider and bundle bytes before execution. F001c used accepted bytes rather than a path-reopen race. |
| F006: finite bundle and ownership | Confirmed closed | Bundle roles and paths remain unique, and the ownership manifest covers the bundle, members, and both anchors. |
| F007: target executable identity | Confirmed closed | Regeneration refreshed the provider, facade, Haxe, content-root, and executable-closure identities together. |
| F008: schemas and mutation coverage | Confirmed closed | Ajv 2020-12 adversaries and 84 independently re-digested mutations passed. F001c has a separate runtime and source-policy regression. |
| F009: captured-stage publication | Confirmed closed | The publication transaction remains unchanged and uses one captured staged set. |
| F010: freshness and runtime identity | Confirmed closed | The repair changed the evidence subject and invalidated current hosted proof automatically. Both current local observer modes bind the new subject. |
| Reject `then` or add a generated wrapper module | Retain the rejection policy; reject the wrapper alternative for v1 | Rejecting one host-active export is smaller, explicit, independently observable, and fail-closed. A wrapper adds another module and identity boundary without a current compatibility requirement. |
| Descriptor revalidation occurs after the carrier enters a Haxe-typed variable | Retained as a wording detail only | Repository documentation does not claim the opposite. The observer binding is immutable before provider execution, so this timing does not reopen F001b. |
| The supplied ZIP was not mounted in Oracle's runtime | No local gap | Caf-oracle prepared and bound the exact bundle digest. Oracle's environment limitation does not weaken the independently reproduced F001c result. |

## Integrated conclusion

Oracle's `changes required` verdict is correct for `fffd4a5`. F001c reproduced
through the real Haxe-to-JavaScript Promise chain. It was not a timer or an
independent provider task. The provider's callable `then` export substituted
the import result, and a later required-symbol read installed inherited
thenability after cleanup.

Only the retained defect was repaired. Required-symbol inspection now stays
inside import restoration. The Python ABI boundary and independent TypeScript
observer both reject the host-active export name `then`. The real runtime
adversary preserves the full import-substitution route and requires failure
before the inherited callback or normal Haxe success line.

F001a, F001b, and F002 through F010 remain closed. No critical finding
reproduced. The new repair has complete local and forced-container proof, but
its hosted receipt is correctly pending. The current Oracle response is not an
acceptance. The requester forbids another Oracle dispatch, so ADR-015 remains
proposed and `wordpresshx-g6.1` remains in progress.

No exact continuation target exists in the ledger. Return to this originating
thread uses visible conversation context only; semantic continuation remains
unverified and no continuation outcome can be recorded.

## Verification and unresolved gaps

Actually run against the current checkout:

- pre-repair real typed-Haxe reproducer: exited 0 with the normal success line;
- pre-repair callback sentinel: `post-import inherited then called`;
- repaired direct native-provider tracer: passed;
- `bash scripts/adoption/test.sh`: passed with all observer groups;
- `WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP=1 bash scripts/adoption/test.sh`:
  passed with all observer groups;
- `python3 scripts/adoption/validate-architecture.py`: passed;
- `bash scripts/check-repository.sh`: passed; and
- Python compilation, Node syntax, whitespace, deterministic regeneration, and
  evidence freshness checks: passed.

Current repaired identities:

- content root: `e79ec1f96203cb17d3ee5bac16117ec1edc44c7563b0a394b075e0868970a66c`;
- evidence subject: `0192d382517e33c0a3410fbf9e7141fe59e45bf6d78a24ada8312b3b29561f87`;
- gate identity: `c6f669a0761e93cf7efd65a3cacdf70554a113dd8f1288aa5018147db669493c`;
- local observation: passed; and
- forced-container observation: passed.

Remaining gaps:

- commit and push the retained repair to `main`;
- obtain and seal current hosted focused and repository proof; and
- obtain an accepted independent exact-revision decision before closing
  ADR-015 or `wordpresshx-g6.1`. No new Oracle request may be dispatched under
  the requester's current instruction.
