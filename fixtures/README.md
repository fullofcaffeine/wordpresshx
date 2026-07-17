# Fixtures

Reserved for minimal compiler/emitter, ownership, interop, schema, negative-diagnostic, and target-runtime evidence. Snapshots must be paired with the lint/type/runtime checks required by the relevant claim.

`profiles/valid/` contains the two minimal SDK-012 exact-profile catalog fixtures. Their canonical content digests are checked, and the validator derives fail-closed mutations covering closed fields/enums, exact pins, continuous evidence, reviewed contract payloads, profile membership, correction ancestry, and content digests. They are schema fixtures and inventories, not generated production catalogs or runtime-support evidence.

`profile-diffs/` contains SDK-014 deterministic JSON and human-output goldens for an exact upstream-profile transition and a breaking same-upstream catalog correction. The synthetic target profile is test data, not compatibility evidence.
