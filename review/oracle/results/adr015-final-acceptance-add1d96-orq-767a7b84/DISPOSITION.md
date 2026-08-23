# ADR-015 Oracle disposition for `orq_20260823T204247Z_767a7b84`

## Integrated conclusion

Retain Oracle's `do not accept` verdict. Current `main` still contains two
critical defects and three major defect groups. These defects block closure of
`wordpresshx-g6.1`.

This review covered commit `add1d966fa18101afa7708129854eb6b671d2b7c`.
Current published `main` is
`ea0b4553e45114fbf5f567add6acee631e63a6b8`. The later commits repaired PHP
launcher portability and bound a successful hosted run. They did not change
the Haxe authority model, generator, validator, ownership probe, or evidence
refresher that caused Oracle's architectural findings.

The response is advisory evidence for the current conclusion. It cannot
authorize closure because it did not review the current revision. A new
content-addressed Oracle review must examine the final corrected revision.

No product code changed during reconciliation. This disposition records the
required work for the parent agent.

## Local baseline before reading Oracle

### Request identity and processing contract

- Request: `orq_20260823T204247Z_767a7b84`.
- Sender: `wordpresshx/wordpresshx-maintainer`.
- Consultation mode: `review`.
- Local processor: `gpt-5.6-sol` at `xhigh`.
- Stored processor contract: `gpt-5.6-sol` at a minimum of `xhigh`.
- Prompt SHA-256:
  `b7f41d00c0f51bec4ae7ecd92ff3b6e9e3ff20f80e3ee067e869ef82a2828a9a`.
- Prompt body SHA-256:
  `26760cefe5a21efbba9ac7da2e938f06d496f774701885086925f825dc496cf8`.
- Bundle SHA-256:
  `115fe9b93b8774f1dc181809e90b63c3a05e2b561e60e16e48232e55e53a92e8`.
- Response SHA-256:
  `81ac96a9c7cb3188d2cf879cef6a31382652da15a00573debb85a240b4fe696d`.
- Stage digest:
  `b06a00a405843fee9d5c8ac60e7a88008c799b924a28bb72ea8ec00be7923be0`.
- Conversation handle: `convo_56b87feae794fce4`.

The pre-dispatch, post-confirmation, and final-capture events use the same
stage digest and conversation binding. Each event records `Pro`,
`chatgpt-pro-control-v3`, and `chatgpt-exact-model-proof-v3`. The model proof
is valid in all three phases.

The prepared completion sentinel matches the response after Markdown
canonicalization. The stored Markdown escapes the underscores, and the ledger
reports `responseComplete: true`. The response has no attachments.

### Current repository and task state

- `HEAD`, local `main`, `origin/main`, and remote `main` all resolved to
  `ea0b4553e45114fbf5f567add6acee631e63a6b8`.
- The tracked worktree was clean before this disposition.
- The worktree contained three pre-existing untracked files. The two protected
  Repomix files were not opened or changed.
- Bead `wordpresshx-g6.1` remained `in_progress`. Its latest comment requires a
  new review of the final evidence revision.
- The evidence receipt remained `implemented-hosted-and-review-pending` and
  `acceptanceAuthorized: false`.
- Every current receipt subject hash matched its file.
- GitHub run `32667029622`, job `97261932874`, completed successfully for
  commit `5dadc5bfc22412cf411742bebbbe2c7ac01dd307`.

The provisional local conclusion was that the hosted portability correction
was valid, but the old review could not close the current task. The Oracle
response strengthened that conclusion by identifying unchanged architectural
defects.

## Oracle claim matrix

`Retained` means that the claim applies to current `ea0b455`. `Rejected` means
that current evidence contradicts a revision-specific claim. `Deferred` means
that the claim is real but does not decide the present gate. `Owner decision`
means that the repository owner must select the durable design.

| Oracle claim | Class | Current-revision evidence | Practical consequence |
| --- | --- | --- | --- |
| The typed Haxe path and native execution use separate proof chains. | Retained, critical | `AcmeCalendarFacade` still returns call-plan strings at `AcmeCalendar.hx:48-63`. `verify_bundle()` returns an ordinary dictionary at `test-native-provider.py:53-85`. The probe later executes facade and provider paths at `:124-190`. A current facade-swap reproduction returned `PWNED` after bundle verification. | The code can validate one facade and execute another. F005 and F007 remain open. |
| PHP and JavaScript reopen mutable paths after they hash bytes. | Retained, critical | Generated PHP uses `hash_file()` and `file_get_contents()`, then calls `require_once` on the path at `generate-fixture.py:316-337`. Generated JavaScript reads and hashes a module, then imports its path at `:359-389`. | The verified bytes are not necessarily the executed bytes. |
| Callers can remove canonical required bindings. | Retained, critical | `requiredBindings` remains a public `Array<String>` at `Adoption.hx:31-42`. Both `probe()` and `authorizes()` read that mutable array at `:151-160` and `:182-220`. A current Haxe reproduction cleared the array and printed `available-authorizes=true`. | An incomplete observation can mint and use authority. F004 remains open. |
| A downstream class can spoof the privileged `TargetProbe` path. | Retained, critical | Production source still grants `@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)` at `Adoption.hx:68-96` and `:172-180`. A current compile excluded repository test-support and supplied that exact class path. It printed `friend-spoof-authorizes=true`. | Downstream source can construct scopes, observations, and runtimes. |
| ABI extraction is hard-coded and accepts source drift. | Retained, major | The generator still omits TypeScript interface fields and PHP docblocks at `generate-fixture.py:108-208`. It keeps authoritative signatures without comparing runtime declarations at `:211-236`. Expected signatures and emitted ABI remain constants at `:614-797`. The validator repeats the constants at `validate-architecture.py:419-518` and `:664-699`. | F001-F003 remain open. Source changes can leave stale admitted types. |
| Three source-only ABI mutations pass generation. | Retained, major | Current reproductions changed only the runtime PHP parameter type, the TypeScript interface field, or the PHP docblock return. All three generations succeeded and kept the old ABI. | Current green generation does not prove source-derived ABI fidelity. |
| The Haxe badge surface narrows JavaScript `number` to `Int`. | Retained, major | `CalendarBadgeProps.count` is still `Int` at `AcmeCalendar.hx:38-45`. The contract uses `javascript-number`. | The authored Haxe surface is not generated from, or checked against, the contract. |
| The bundle and `ArtifactOwner` do not publish one complete set. | Retained, major | The bundle and ownership manifest list the same five generated files. They omit the Haxe facade, provider archive, and bundle file. `test-ownership.py:29-36` stages only manifest members. The `adoption.bundle` callback remains a no-op in pass mode at `packages/cli/test/ownership/src/sdk041/fixture/Main.hx:31-42`. | F006 and F009 remain open. Publication can pass without semantic bundle validation. |
| The local pass status is copied by an identity refresher. | Retained, major | `refresh-evidence.py:150-238` hard-codes counts and booleans, then copies receipt claims. `test.sh:23-24` runs it before the native, ownership, and Haxe observers. These files are unchanged from `add1d966`. | F010 remains open. Identity refresh can preserve a pass without observer receipts for the same content root. |
| Hosted evidence was pending and the receipt timestamp preceded the claimed proof. | Rejected as stale | Commit `c03fa00` records run `32667029622`, job `97261932874`, and `observedAt: 2026-08-23T21:18:01Z`. GitHub reports the run and job as successful. | The current receipt no longer has Oracle's pending-hosted or old-timestamp defect. This does not correct the architectural blockers. |
| F008's recorded prefix and suffix anchoring defect is closed. | Retained | Current schema patterns are anchored. `validate-architecture.py` passed 33 independent mutations. | The recorded F008 defect is closed. |
| `relativePath` accepts `../x`. | Deferred, minor | The current pattern `^[^/][^\\]*$` accepts `../x` in the contract and bundle schemas. A local regular-expression reproduction returned `True`. | This needs a bounded path-policy follow-up. It does not outweigh the critical blockers. |
| Required and optional absence remain distinct. | Retained | `CapabilityRuntime.probe()` returns separate reasons at `Adoption.hx:187-192`. | This part of the design is demonstrated. |
| The underlying ownership transaction is real. | Retained | The fixture uses the production `ArtifactOwner` and exercises transaction mechanics. The missing part is a real adoption-bundle validator and complete stage. | Preserve the production owner. Correct its ADR-015 integration. |
| Generator and validator share ABI assumptions. | Retained | Both files contain the same signature and ABI constants. | The validator cannot independently detect those semantic mistakes. |
| Committed generated bytes prove determinism, not semantics. | Retained | `test.sh:71-77` generates twice and compares output with committed bytes. | Keep the determinism check, but add independent semantic observers. |
| The cross-target Haxe transcript observes a model, not provider execution. | Retained | Haxe returns strings at `AcmeCalendar.hx:48-63`. Native provider calls occur in a separate Python probe. | The tracer bullet does not connect typed Haxe to the verified provider. |

## F001-F010 disposition

| Gap | Class | Current decision |
| --- | --- | --- |
| F001 | Retained, major | The generator inventories top-level declarations but does not parse all referenced declarations or JavaScript runtime exports. |
| F002 | Retained, major | The five admissions, four omissions, and their ABI values still depend on hard-coded generator decisions. |
| F003 | Retained, major | Current source-only mutations reproduce stale ABI output. The `Int` versus JavaScript `number` mismatch also remains. |
| F004 | Retained, critical | Both public binding mutation and exact friend-path spoofing create unauthorized capability authority. |
| F005 | Retained, critical | The PHP native facade is separate from typed Haxe and reopens mutable paths after validation. |
| F006 | Retained, major | The bundle omits public and executable bytes that affect typing and execution. It is not part of the owned publication set. |
| F007 | Retained, critical | The JavaScript native facade is separate from typed Haxe and imports a mutable path after hashing it. |
| F008 | Retained as closed for the recorded defect | Prefix and suffix anchoring is present and independently exercised. The `../x` case is a deferred minor concern. |
| F009 | Retained, major | The production transaction runs, but its adoption stage omits the bundle and uses a no-op semantic validator. |
| F010 | Retained, major with stale subclaims rejected | Current hosted identities are valid. The local pass state still lacks observer-derived, same-root receipts. |

## Parent-agent blockers

The parent agent must not close `wordpresshx-g6.1` until it resolves these
items:

1. Connect typed Haxe to a production target adapter that owns one immutable,
   verified execution handle. Prove that post-verification facade and provider
   swaps cannot change executed bytes.
2. Make canonical binding requirements immutable. Remove production friend
   grants to the test-support class path. Add mutation and exact-path spoof
   regressions.
3. Parse one source-derived ABI model for referenced TypeScript fields, PHP
   docblocks, and lower-precedence runtime declarations. Generate or check the
   Haxe surface from that model. Keep all three reproduced drift cases.
4. Define one complete publication set. Run a real `adoption.bundle` validator
   through the existing `ArtifactOwner` before publication and recovery.
5. Separate identity refresh from outcome recording. Record a local pass only
   after every observer succeeds against the same content root.
6. After all corrections and current gates pass, create a new exact-revision
   Oracle request. This older response cannot authorize closure.

## Owner decisions

Two design choices remain with the owner:

1. **Bundle and ownership direction.** Oracle recommends a content bundle that
   excludes the final ownership manifest. One final ADR-007 manifest then owns
   the bundle and all members. This avoids a direct digest cycle.
2. **Production adapter boundary.** PHP and browser adapters must own
   verification, immutable execution handles, lifecycle scopes, observations,
   and token minting. The owner must select the durable public seam.

The parent agent must stop for these decisions if implementation alternatives
change public semantics. No decision was made in this reconciliation run.

## Verification and gaps

### Commands and observers that passed

- `caf-oracle doctor --json`.
- `caf-oracle request show orq_20260823T204247Z_767a7b84 --json`.
- Prepared prompt, bundle, and response SHA-256 checks with `/usr/bin/shasum`.
- Read-only Beads preflight with `bd-toolchain check` and
  `bd --readonly info --json`.
- Read-only task inspection with `bd --readonly show wordpresshx-g6.1 --json`
  and `bd --readonly comments wordpresshx-g6.1 --json`.
- `gh run view 32667029622 --json ...`.
- `python3 scripts/adoption/validate-architecture.py`, which passed 33
  independent mutations.
- Every subject hash in
  `manifests/evidence/adr-015-interop-adoption-contract.json`.
- Direct current native-provider probes in local PHP 8.4.7 and the pinned PHP
  container. Both printed the native-facade pass result.
- Current facade-swap reproduction. It verified a bundle, replaced the facade,
  and executed `PWNED`.
- Current Haxe binding-mutation reproduction. It printed
  `available-authorizes=true`.
- Current exact friend-path spoof reproduction. It printed
  `friend-spoof-authorizes=true`.
- Current generator drift reproductions for the runtime PHP parameter,
  TypeScript interface field, and PHP docblock return.

### Gaps and failed command starts

- `bash scripts/adoption/test.sh` stopped before tests because `lix` was not on
  the shell path.
- `pnpm exec bash scripts/adoption/test.sh` also stopped because the repository
  root is not a package in this workspace.
- The full repository gate was not run in this reconciliation turn.
- Hosted run `32667029622` provides the current focused-gate observer for commit
  `5dadc5b`. It does not correct or disprove the reproduced defects.
- Oracle reviewed `add1d966`, not `ea0b455`. A new exact-current-revision review
  remains mandatory after implementation.

The bounded temporary reproduction directory was moved to Trash after the
tests. No repository product file or Beads record changed.
