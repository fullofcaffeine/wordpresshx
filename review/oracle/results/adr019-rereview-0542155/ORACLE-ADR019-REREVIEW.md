# Independent Oracle rereview: ADR-019

Reviewer: Codex Oracle agent `/root/oracle_wordpresshx_review`  
Reviewed commit: `05421557763d61b3bd87996714508227da619db2`  
Packet: `2cedd63d13f5c22699cae4adae98ca884fcb2fba9b307e6028b399581dcd6a49`  
Decision: **changes-required**

## Integrity and execution

The supplied archive hash and all three internal top-level hashes match. The
Repomix snapshot hash is
`544562b2744c05c6306f01b3d616d4343c1cb242ce46d2f666aa426bfbea57ef`.
I read the prompt and every declared path actually present in that snapshot.
The path inventory is not complete: 29 of 30 declared files have a `<file>`
payload; `scripts/security/unsafe-boundary-schema/package-lock.json` is absent.

The extracted Python gate passed with 9 categories, 14 scenarios, and 59
fail-closed mutations. Its two runtime symlink probes reject both a file
symlink and a directory-component symlink. The exact `npm ci`/Ajv test could
not be reproduced from the immutable packet because its declared lockfile is
missing. Live Beads verification was not run because the packet review does not
contain the repository's Beads database/tooling; the pinned hosted result is
supporting evidence only.

## Prior finding dispositions

- `ADR019-F001` — **partially resolved; remains open.** The correction adds
  content-addressed removal status, live `bd show` comparison after `bd dolt
  pull`, coherent deadlines, and additive current-ledger records. However,
  renewal validation authenticates a prior ledger's bytes and checks only its
  waiver ID, current record ID, final `superseded` state, and successor. It
  does not validate the prior ledger schema, contiguous hash chain, subject and
  review bindings, timestamps, or removal-status authority. A fabricated prior
  ledger can therefore authorize a renewal.
- `ADR019-F002` — **resolved.** The waiver now binds a closed,
  content-addressed receipt covering identity/provider/model/role, prompt,
  inputs, snapshot digest, waiver subject, sources/evidence, findings,
  decision, independence declaration, and limitations. Synthetic receipts are
  explicitly simulation-only and cannot authorize production. No manual-human
  gate is required.
- `ADR019-F003` — **correction appears sound but is not independently
  reproducible from this packet.** Python locks the exact reviewed waiver
  schema digest and tests nested weakenings; `validate.mjs` independently
  compiles all four Draft 2020-12 schemas and demonstrates seven non-vacuous
  waiver-schema weakening probes. The missing lockfile prevents verification
  that the claimed pinned Ajv 8.17.1 dependency graph is the reviewed one.
- `ADR019-F004` — **resolved.** Every repository path traverses components
  without symlinks, resolves strictly, and must remain below the repository
  root. Both required runtime escape probes pass.

## New findings

### ADR019-RF001 — High — renewal ancestry is only shallowly authenticated

`validate_lifecycle` reads the content-addressed prior ledger but validates
only a handful of fields from its final record. It must validate the complete
prior ledger under the closed lifecycle schema and the same semantic
hash-chain, review-binding, timestamp, and removal-authority rules (or bind a
separately verified immutable acceptance receipt that proves those checks).
Add a negative fixture with a schema-valid-looking final supersession record
and a broken/fabricated earlier chain.

### ADR019-RF002 — Medium — immutable review packet omits a declared input

The evidence manifest claims lockfile hash
`8674393422769ae18afbd6812082b904e535c7858e5d8711c4de3d4845cd1a70`,
but the archive contains no lockfile payload. Regenerate the immutable packet,
verify that all declared paths have payloads before delivery, and rerun
`npm ci` plus `npm test` from that packet.

## Bounded conclusion

The nine-category strict-Haxe policy, prohibited scopes, bounded expiry/risk
rules, inventories, release stops, and no-manual-human-review decision remain
coherent. This review does not claim production scanners, a public unsafe API,
WordPress/browser behavior, publication, stable support, or production
support. Acceptance is withheld solely for the renewal-authority defect and
the incomplete immutable evidence packet.
