# Release status and provisional process

There are no releases. All channels, version windows, licensing, support, security response, and compatibility claims remain gated by ADR-020, ADR-021, SDK-002, SDK-003, and G8.

A future canonical release must, at minimum:

1. select one exact source commit and freeze all toolchain/profile pins;
2. build from a clean checkout with no floating sibling paths;
3. run source, generated target, installed WordPress, editor/browser, security, accessibility, determinism, and performance gates required by the claimed capability set;
4. build normalized WordPress packages twice and compare unsigned bytes;
5. install and exercise the exact final package bytes in clean environments;
6. generate checksums, SBOM, licenses/notices, provenance, API/profile/claim diffs, and inventories;
7. run external consumer and supported upgrade/rollback paths;
8. publish only from the tested immutable commit and verify downloaded artifacts.

Until the release/support ADR is accepted, any experimental artifact is local research output and must not be described as stable, supported, or production-ready.
