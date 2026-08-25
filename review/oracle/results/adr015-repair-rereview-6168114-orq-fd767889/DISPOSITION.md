# ADR-015 repair re-review disposition

- Request: `orq_20260825T182401Z_fd767889`
- Reviewed commit: `6168114233007c1d585e4e6318ff5386e6f51fe5`
- Oracle verdict: `changes required`
- Local disposition: retain the verdict; keep ADR-015 proposed and
  `wordpresshx-g6.1` in progress.

## Local baseline

The reviewed revision is on `origin/main`. Its focused ADR-015 gate passed with
local PHP 8.4.7 and with the pinned no-network PHP container. The complete
repository gate, pre-commit gate, and pre-push gate passed. Hosted workflow run
`32883312308`, job `97917772321`, passed on the exact reviewed commit.

The response was captured complete with no attachments. Caf-oracle recorded
valid GPT-5.6 Pro model proof. Reconciliation used the recorded owner
`wordpresshx/wordpresshx-maintainer`, model `gpt-5.6-sol`, and xhigh reasoning.

## Claim matrix

| Finding | Disposition | Local conclusion |
|---|---|---|
| F001: JavaScript formals | Retained, major | Destructuring, rest, and defaults now fail, but the ASCII identifier regex still admits reserved or strict-mode-invalid names and duplicate parameters. |
| F003: independent validation | Retained, major | `validate-architecture.py` still imports the producer ABI model and generator helpers, so it cannot independently expose a shared source-shape blind spot. |
| F004: product authority mint | Retained, critical | `FixtureTargetAdapter` remains in the product module behind caller-selectable `-D adoption_contract_test`. A consumer controlling defines can compile the non-native mint path. |
| F005: complete runtime bundle verification | Closed | Both exact generated anchors embed the fixed five-member root and verify every declared record and physical member before provider observation. The topology is acyclic. |
| F007: target executable closure | Closed | PHP binds exact plugin bytes. JavaScript binds the canonical module-plus-package-metadata closure. Tokens no longer overclaim the distribution ZIP. |
| F009: production StageValidator | Retained, critical | The validator derives expected truth from candidate bytes and accepts anchors when their source merely contains the candidate digest. A replacement anchor plus recomputed manifest can pass. |
| F010: evidence freshness | Retained, major | Freshness identities omit authoritative provider inputs, generated member bytes, runtime anchors, and the generated ownership manifest. Prior pass rows can survive changes to omitted subjects. |

## Integrated conclusion

Commit `6168114` is a meaningful partial repair and should remain published.
It resolves the two owner decisions from the parent review with coherent,
non-recursive semantics. It does not earn ADR acceptance because publication
authority can still be forged and a caller-controlled compile define still
exposes a test mint path.

The next revision must remove all fixture minting from product source; supply
the real StageValidator with a non-candidate expected-stage plan covering every
published byte and exact safety semantic; close JavaScript module formal
grammar with an independent parser/observer; and bind local, container, and
hosted evidence to a non-recursive digest of every authoritative input,
generated output, validator, gate, workflow, and toolchain lock.

## Verification and gaps

Verified:

- exact local and container ADR-015 gates passed;
- complete repository, commit, and push gates passed;
- exact hosted adoption workflow passed;
- generated PHP and JavaScript anchors and target closures matched their
  supplied inputs;
- the follow-up attempt was retired without dispatch after its parent-page
  digest failed closed; the fresh request dispatched and captured normally.

Remaining gaps:

- no hostile-define product compile negative exists on interpreter, PHP, and
  JavaScript targets;
- no expected-stage plan independent of staged/caller bytes authenticates the
  external anchors and generated Haxe facade;
- no independent ECMAScript-module source observer exists;
- evidence freshness does not cover authoritative inputs and all physical
  generated outputs;
- repository wording still contains isolated statements implying the bundle
  itself binds facades or the ownership manifest.

Therefore ADR-015 remains `proposed`, the current receipt remains bounded
evidence rather than acceptance, and `wordpresshx-g6.1` remains `in_progress`.
