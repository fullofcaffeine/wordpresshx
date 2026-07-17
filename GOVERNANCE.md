# Governance

This document is the bootstrap governance skeleton for `wordpress-hx-sdk`. It describes how decisions are made before a formal maintainer and support contract is accepted. It does not create an SLA, security-response promise, or release entitlement.

## Authorities

Authority is deliberately separated by concern:

1. The product requirements document defines recommended scope, architecture, gates, evidence, and backlog.
2. Accepted ADRs govern durable architecture and policy decisions. An open ADR bead is not an accepted decision.
3. Beads is the task and dependency authority for this repository.
4. Exact vanilla WordPress and embedded Gutenberg source, distribution bytes, and executable behavior govern compatibility claims for a selected profile.
5. Generic compiler repositories govern target-language/compiler semantics. This SDK consumes immutable releases or commits rather than carrying hidden local patches.
6. The full `wordpress-hx` port governs only its own implementation ownership and parity claims.

When these sources disagree, work stops at the affected boundary until the responsible ADR or evidence bead resolves the conflict. An issue inventory or generated scaffold never overrides real upstream behavior.

## Decision process

Durable decisions follow this sequence:

1. Create or use the relevant decision bead before implementation breadth.
2. Record context, exact scope/profile, alternatives, rationale, consequences, migration/rollback implications, and evidence.
3. Link dependent implementation and verification beads.
4. Obtain review from the owners of every affected layer. Security, licensing, and public-support decisions require qualified review appropriate to those subjects.
5. Mark an ADR accepted only when its acceptance criteria and blocking evidence are satisfied.
6. Supersede decisions explicitly; do not silently rewrite historical rationale.

During bootstrap, repository write access identifies who may merge, but it does not by itself establish a long-term support commitment. ADR-021 and SDK-003 must define named release, rollback, security, and compatibility ownership before a stable release.

## Change review

Every proposed change should make these points reviewable:

- bead and gate scope;
- exact profile and upstream authority;
- responsible layer (generic compiler, SDK profile/build/API, application example, or full port);
- generated/public artifacts affected;
- unsafe and compatibility impact;
- static, native-runtime, browser, package, and downstream evidence required;
- stop or rollback condition.

A generic compiler defect is fixed and regression-tested in its compiler repository. A WordPress-specific rule belongs in this SDK's profile or application API. Full-port original-path linking and Core replacement never belong here.

## Releases and claims

There are currently no releases and no supported versions. A release candidate may not claim generic "WordPress support" or "production readiness." Future claims must name an SDK version, exact profile, finite capability set, toolchain matrix, and evidence ledger.

The final immutable WordPress package bytes—not a developer checkout—are the organizing artifact for release evidence. Vanilla results and any future WordPressHx provider receipt remain separate fields.

See [SUPPORT.md](SUPPORT.md), [SECURITY.md](SECURITY.md), and [docs/release/README.md](docs/release/README.md) for the current deliberately limited policies.
