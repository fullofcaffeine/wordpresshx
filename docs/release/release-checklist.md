# Canonical release checklist

This is an executable review contract, not authorization to publish. The release
owner is Marcelo Serpa; stable remains blocked until a named backup has exercised
recovery access and every item below has immutable evidence.

## Candidate and authority

- [ ] One clean immutable commit is selected; Git and Beads are pushed and clean.
- [ ] `wordpress-hx` and `@wordpress-hx/cli` use one exact version.
- [ ] ADR-020/SDK-002 authorize every artifact class and notices are complete.
- [ ] The exact profile/catalog, upstream distributions, compilers, toolchains,
      PHP/Node/browser/database/OS matrix, and provider are frozen.
- [ ] The capability/claim ledger contains only attained evidence and every
      advertised stable capability is `production-supported`.
- [ ] Start/end UTC instants and accountable primary/backup owners are recorded;
      the default stable term is 180 days and cannot later be shortened.

## Build and evidence

- [ ] Canonical CI is green on the candidate commit.
- [ ] Clean external consumer projects install packed Haxelib/npm artifacts.
- [ ] Generated PHP/TS/metadata/static/runtime/browser/package gates pass for the
      claimed matrix.
- [ ] Final plugin/theme/site ZIPs are built twice with normalized identical
      unsigned bytes and then installed/exercised from those exact bytes.
- [ ] API/profile/claim/unsafe/`any`/`unknown` diffs and migration notes are
      reviewed.
- [ ] SBOM, license inventory, notices, provenance, checksums, source maps, and
      release manifest bind every final artifact hash.
- [ ] Upgrade from the supported predecessor and rollback to the last known-good
      immutable identity pass, including state/migration rules.

## Security and publication

- [ ] GitHub private vulnerability reporting and backup access are tested without
      placing sensitive material in public records.
- [ ] Active stable dependencies/advisories have been reviewed within 30 days.
- [ ] Protected workflow credentials publish from the tested commit; no local
      dirty checkout assembles release bytes.
- [ ] Downloaded registry/source/ZIP artifacts match the approved hashes.
- [ ] Support/status pages list exact versions, matrices, term, owners, known
      gaps, rollback version, and private reporting instructions.

Any unchecked item keeps the candidate preview or blocked. An automated agent may
collect evidence but cannot check owner/capacity/publication approval on behalf of
the named humans.
