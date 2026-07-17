# Release status and process

ADR-021 is accepted and defines channels, exact matrices, a default stable term of 180 consecutive days, deprecations, security/backport boundaries, owners, and immutable rollback. There are still no releases or supported versions.

**Publication decision: blocked.** Licensing/output review, G8 production evidence, a final-package consumer matrix, enabled/tested private vulnerability reporting, a named backup release/security owner, and a production release/rollback rehearsal remain open. Passing a simulated SDK-003 rehearsal does not remove those blockers.

A future canonical release must, at minimum:

1. select one exact source commit and freeze all toolchain/profile pins;
2. build from a clean checkout with no floating sibling paths;
3. run source, generated target, installed WordPress, editor/browser, security, accessibility, determinism, and performance gates required by the claimed capability set;
4. build normalized WordPress packages twice and compare unsigned bytes;
5. install and exercise the exact final package bytes in clean environments;
6. generate checksums, SBOM, licenses/notices, provenance, API/profile/claim diffs, and inventories;
7. run external consumer and supported upgrade/rollback paths;
8. publish only from the tested immutable commit and verify downloaded artifacts.

All `0.x` artifacts are development/nightly/preview and unsupported. Stable starts no earlier than `1.0.0` and only for the exact manifest-listed scope. See [release checklist](release-checklist.md), [rollback checklist](rollback-checklist.md), [ADR-021](../adr/021-release-and-support-policy.md), and `manifests/release-support-policy.json`.
