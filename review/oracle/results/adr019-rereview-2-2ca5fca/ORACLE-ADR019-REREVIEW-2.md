# Independent Oracle second rereview: ADR-019

Reviewer: Codex Oracle agent `/root/oracle_wordpresshx_review`  
Reviewed evidence commit: `2ca5fca6a227f853d5ecf3953e06377b62d10677`  
Implementation commit: `0f01fda14c81ee2476cdc31e41885afcf50e3fb5`  
Packet SHA-256: `bcb9b758ea86e7212852bb606185c0783f157c2ff5ae08f63b9d7d0aad3bfb13`  
Decision: **accepted**

## Integrity and verification

The packet and every hash in `packet-inputs.sha256` verify. Its completeness
receipt accurately reports 38 declared paths, 1,141 Repomix payloads, and 1,142
tracked archive files. Every declared path exists in both representations.
Their contents agree after accounting for Repomix's omission of the container
payload's final newline. In particular, `package-lock.json` exists in both and
has SHA-256
`8674393422769ae18afbd6812082b904e535c7858e5d8711c4de3d4845cd1a70`.

From the extracted tracked archive:

- the Python policy gate passed: 9 categories, 14 scenarios, and 60
  fail-closed mutations;
- an initially empty dependency directory installed exactly Ajv 8.17.1 with
  `npm ci`;
- the Node gate passed all 4 schemas, 8 current/ancestor instances, and 8
  material semantic weakening probes;
- live Beads verification passed after initialization and `bd dolt pull`.

The full repository gate also passed against the shared workspace at exact
commit `2ca5fca6a227f853d5ecf3953e06377b62d10677`. It could not run from the
archive alone because that gate intentionally verifies historical Git
ancestry, which a Git archive does not contain. The hosted run
`30229302949`, job `89865057093`, is consistent supporting evidence.

## Finding dispositions

- `ADR019-F001` — **resolved.** Lifecycle validation enforces bound ledger and
  record IDs, canonical prior-record hashes, sequence, strictly increasing
  timestamps, valid state transitions, exact subject/review bindings,
  revocation/supersession semantics, current-final authority, coherent
  deadlines, content-addressed Bead projections, and live current Bead state.
  Renewal recursively validates the full ancestor waiver, review, lifecycle,
  and removal authority.
- `ADR019-F002` — **resolved and remains closed.** The content-addressed review
  receipt binds reviewer provenance, prompt, inputs, snapshot, waiver subject,
  source/evidence, findings, decision, independence, and limitations.
  Synthetic receipts preserve simulation authority and cannot confer
  production authority. No manual-human review is required.
- `ADR019-F003` — **resolved.** Python locks the reviewed waiver schema, while
  pinned Ajv independently applies Draft 2020-12 semantics to all four closed
  schemas. The eight weakening probes are non-vacuous: each adversarial
  instance fails canonically and passes only under its corresponding weakened
  schema.
- `ADR019-F004` — **resolved and remains closed.** Repository paths reject
  traversal and any symlink component, resolve strictly beneath the root, and
  the file- and directory-symlink runtime probes pass.
- `ADR019-RF001` — **resolved.** The current lifecycle content-addresses both
  ancestor waiver and ledger. Recursive validation preserves boundary and
  simulation identity, rejects cycles, requires a distinct waiver and
  subject-bound review, and requires the prior final record to supersede to
  the exact successor. The fabricated mutation updates all surrounding file
  hashes and references, remains schema-shaped, and fails specifically on its
  altered earlier-chain hash.
- `ADR019-RF002` — **resolved.** The regenerated immutable packet contains the
  declared lockfile in both representations, and clean pinned installation and
  execution succeeded.

## New findings

None.

## Bounded conclusion

ADR-019's governance architecture is accepted within its stated prototype
scope. The nine-category strict-Haxe policy, prohibited scopes, bounded
expiry/risk, inventories, release stops, and independent Oracle model remain
coherent.

This acceptance does not establish production source/generated/final-artifact
scanners, a public unsafe API, WordPress or browser security behavior,
publication, stable support, or production support. Those claims remain
explicitly withheld and subject to their separate gates.
