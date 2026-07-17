# Schemas

Reserved for versioned project, profile, semantic-plan, generated-ownership, adoption, and evidence schemas after their ADRs are accepted. A schema must define migration/correction behavior and may not turn inventory into a support claim.

[`profile.schema.json`](profile.schema.json) is the closed SDK-012 exact-profile catalog schema. Schema version, catalog revision, upstream identities, and content digest are independent fields. All object shapes reject unknown fields; API classifications, evidence states, administrative results, provenance, exact pins, continuous evidence stages, reviewed diffable contracts, and additive corrections are validated by `scripts/profiles/validate-profile-schema.py`. A reviewed contract is legal only at `typed` evidence or later. Signature authority excludes heuristic inference, metadata facts contain canonical JSON, and contract receipts must be indexed.

[`profile-diff.schema.json`](profile-diff.schema.json) is the closed SDK-014 report schema. It separates upstream-profile changes from direct SDK catalog corrections, records exact endpoints and before/after values, carries conservative impact and migration actions, and fixes policy fields to exact-catalog advisory output with no inferred range or source rewrite.
