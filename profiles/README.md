# Compatibility profiles

Reserved for exact, checksummed WordPress/Gutenberg profile manifests and generated catalogs.

[ADR-002](../docs/adr/002-exact-compatibility-profiles.md) accepts `wp70-release` and `gutenberg-forward-23.4` as separate peer identities. [`decision-lock.json`](decision-lock.json) freezes their architecture inputs, catalog revision names, single-profile artifact rule, and future range criteria. The lock is an architecture input, not the profile schema or a support receipt.

[ADR-008](../docs/adr/008-profile-generation-and-api-classification.md) separately defines how generated entries are classified and how evidence advances. [`classification-decision-lock.json`](classification-decision-lock.json) freezes the closed public/experimental/private/unsafe/deprecated vocabulary, contiguous evidence states, question-scoped source precedence, compile-time versus runtime capability authority, and additive correction rules. SDK-012 still owns the actual closed profile schema and Haxe types; this architecture lock is not a generated catalog.

No profile is supported yet. SDK-010 and SDK-011 must independently materialize and verify the exact upstream commits and artifact hashes; SDK-012/013 own the versioned schema and generated catalogs. Until those gates pass, the decision lock remains `not-tested` and the profiles must remain separately generated, tested, packaged, and claimed.

SDK-010 has now locked and independently materialized the [`wp70-release` source authority](wp70-release/README.md). SDK-011 has separately locked the [`gutenberg-forward-23.4` source authority](gutenberg-forward-23.4/README.md), including compile-admission and final-artifact leak fixtures. Those gates advance only the exact source/release identities and capability inventories to `inventoried`; they do not advance any API or runtime-support claim. WordPress 7.0 compatibility for the forward profile remains forbidden.
