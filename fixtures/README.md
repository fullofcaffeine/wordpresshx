# Fixtures

Reserved for minimal compiler/emitter, ownership, interop, schema, negative-diagnostic, and target-runtime evidence. Snapshots must be paired with the lint/type/runtime checks required by the relevant claim.

`profiles/valid/` contains the two minimal SDK-012 exact-profile catalog fixtures. Their canonical content digests are checked, and the validator derives nine fail-closed mutations covering unknown fields/enums, floating or placeholder pins, skipped evidence, missing unsafe metadata, profile mismatch, correction ancestry, and digest mismatch. They are schema fixtures and inventories, not generated production catalogs or runtime-support evidence.
