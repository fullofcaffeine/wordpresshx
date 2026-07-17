# Exact-profile diff fixtures

SDK-014 derives two complete exact-profile pairs in a temporary directory from
the checked-in SDK-012 `wp70-release` schema fixture. The input construction is
executable in `scripts/profiles/test-profile-diff.py`; it does not mutate or
publish a profile catalog.

The `upstream` pair changes the exact profile/upstream identity and exercises a
package export addition, a PHP API removal, and reviewed signature,
classification, script-handle, block-metadata, and dependency changes. The
`correction` pair preserves the exact upstream inputs, links directly to the
prior catalog digest through additive correction ancestry, and records a
breaking corrected signature plus an explicit migration.

`expected/` contains byte-for-byte JSON and human output for both comparisons.
The JSON goldens validate against `schemas/profile-diff.schema.json`, including
their canonical report digests. The suite also rejects unrecorded same-upstream
drift, a correction mixed with changed upstream authority, an undeclared
range-support field, and non-canonical embedded change JSON.

These are contract fixtures, not WordPress 7.1 evidence. Their target hashes and
identities are deterministic synthetic values and cannot support a compatibility
claim.
