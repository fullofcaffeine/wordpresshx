# Semantic-plan contract fixtures

These fixtures exercise the accepted ADR-006 envelope, content-addressed node
schemas, canonicalization rules, source spans, and staged emitter-result
traceability. They are architecture-contract evidence, not an SDK-040 macro
collector or a claim that the sample PHP was emitted by the production
WordPress profile.

`valid/minimal-plugin.json` is a canonical plan built from
`src/SemanticPlanFixture.hx`. `valid/minimal-plugin.emission.json` describes the
expected staged PHP bytes and proves complete projection-to-artifact/source
coverage. `scripts/semantic-plan/test-contract.py` also constructs fail-closed
mutations in memory; invalid plans are not retained as parallel authorities.
