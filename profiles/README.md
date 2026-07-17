# Compatibility profiles

Reserved for exact, checksummed WordPress/Gutenberg profile manifests and generated catalogs.

[ADR-002](../docs/adr/002-exact-compatibility-profiles.md) accepts `wp70-release` and `gutenberg-forward-23.4` as separate peer identities. [`decision-lock.json`](decision-lock.json) freezes their architecture inputs, catalog revision names, single-profile artifact rule, and future range criteria. The lock is an architecture input, not the profile schema or a support receipt.

No profile is supported yet. SDK-010 and SDK-011 must independently materialize and verify the exact upstream commits and artifact hashes; SDK-012/013 own the versioned schema and generated catalogs. Until those gates pass, the decision lock remains `not-tested` and the profiles must remain separately generated, tested, packaged, and claimed.
