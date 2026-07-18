# Fixtures

Reserved for minimal compiler/emitter, ownership, interop, schema, negative-diagnostic, and target-runtime evidence. Snapshots must be paired with the lint/type/runtime checks required by the relevant claim.

`profiles/valid/` contains the two minimal SDK-012 exact-profile catalog fixtures. Their canonical content digests are checked, and the validator derives fail-closed mutations covering closed fields/enums, exact pins, continuous evidence, reviewed contract payloads, profile membership, correction ancestry, and content digests. They are schema fixtures and inventories, not generated production catalogs or runtime-support evidence.

`profile-diffs/` contains SDK-014 deterministic JSON and human-output goldens for an exact upstream-profile transition and a breaking same-upstream catalog correction. The synthetic target profile is test data, not compatibility evidence.

`release-governance/` contains SDK-003 deterministic issue, disabled-private-security, blocked-release, and immutable-rollback policy rehearsals. Every package identity is synthetic, and the passing golden does not authorize a release or satisfy the production rehearsal blocker.

`licenses/` contains the exact ADR-020 blocked-publication diagnostic. Its test
also mutates review, publication, inventory, conflict, ordering, and output-origin
state to prove the provisional gate fails closed. Passing means the repository
truthfully records no license grant; it does not authorize publication.

`source-correlation/` contains the ADR-014 schema-only PHP range-map and browser
Source Map v3 chain fixtures. Its validator authenticates exact bytes, hashes,
UTF-8 coordinates, source roots, map-layer continuity, retention, and
fail-closed mutations. It is not PHP/browser runtime or trace-CLI evidence.

`semantic-plan/` contains the ADR-006 canonical plan and staged-emission
contract fixtures. The validator binds exact node schemas, profile
capabilities, UTF-8 source spans, projection coverage, and expected artifact
bytes, then exercises canonicalization and fail-closed mutations. It is not the
SDK-040 macro collector or a production PHP emitter.

`ownership/` contains the ADR-007 canonical current/next manifests, prepared
journal, and exact artifact bytes. Its reference-only harness exercises real
temporary filesystem publication, rollback, crash recovery, clean, adoption,
links, collisions, edits, and malformed state. It is not SDK-041 production
code or a runtime/platform support claim.

`project-cli/` contains the ADR-016 synthetic Haxe-only consumer, generated
bootstrap/lock, deterministic effective-input graph, bounded dry-run events,
and development-loop JSONL transcript. Its contract harness exercises input
discovery, environment separation, last-good retention, reload ordering, and
owned shutdown. It is not the SDK-043 CLI, SDK-044 watcher/process supervisor,
or WordPress/Next.js runtime evidence.
