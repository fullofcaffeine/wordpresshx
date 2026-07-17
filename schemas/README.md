# Schemas

Reserved for versioned project, profile, semantic-plan, generated-ownership, adoption, and evidence schemas after their ADRs are accepted. A schema must define migration/correction behavior and may not turn inventory into a support claim.

[`profile.schema.json`](profile.schema.json) is the closed SDK-012 exact-profile catalog schema. Schema version, catalog revision, upstream identities, and content digest are independent fields. All object shapes reject unknown fields; API classifications, evidence states, administrative results, provenance, exact pins, continuous evidence stages, and additive corrections are validated by `scripts/profiles/validate-profile-schema.py`.
