# Governance

This document implements the current repository governance contract for `wordpress-hx-sdk`. ADR-021 defines the finite future release/support policy; no current version is released or supported, and this document creates no SLA or release entitlement.

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

Repository write access identifies who may land code, but it does not by itself establish a long-term support commitment. Stable release ownership requires tested credentials, a private security channel, a named backup, an immutable release/rollback rehearsal, and explicit acceptance of the release-specific term.

## Current accountability

| Responsibility | Accountable owner | Current readiness |
|---|---|---|
| Product scope and final claim matrix | Marcelo Serpa | Development decisions; stable approval requires an exact release manifest |
| Release publication and downloaded-byte verification | Marcelo Serpa | Blocked until protected-credential rehearsal |
| Rollback, revocation, and claim correction | Marcelo Serpa | Blocked until final-artifact rehearsal |
| Compatibility profiles and backport scope | Marcelo Serpa | Development evidence only; no supported line |
| Private security intake and coordination | Marcelo Serpa, provisional | Blocked because private vulnerability reporting is disabled |
| Backup release/security recovery | unassigned | Stable-release blocker |

Automated agents can execute approved checks and workflows but are not accountable owners. They cannot accept a support term, security disclosure, claim matrix, registry publication, or destructive rollback.

The unassigned backup role is an explicit stable-release blocker, not implicit coverage by the primary owner or an automated agent.

## Direct-to-main and review

Direct-to-main is the normal flow for authorized maintainers doing routine work in this repository. The maintainer must first claim a Bead, keep the change within its authority, run the tracked hooks and proportionate layer gates, commit intentionally, and push only a green commit. A pull request is a coordination tool for external contributions, difficult cross-repository work, or review that materially benefits from a branch; it is not mandatory ceremony for routine local changes.

Changes to Genes follow the stricter upstream policy: use an isolated Genes worktree, reduce the issue to a generalized non-WordPress fixture, run the full relevant upstream regression suite, and only then open a PR. Licensing, security disclosure, and release publication still require their named qualified review or workflow even when the code change lands directly.

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

There are currently no releases and no supported versions. A release candidate may not claim generic "WordPress support" or "production readiness." Future claims must name an SDK version, exact profile, finite capability set, toolchain matrix, evidence ledger, support start/end, and accountable owners.

All `0.x` work is development/nightly/preview and unsupported. ADR-021 permits stable only at `1.0.0` or later after G8, licensing authorization, exact production evidence, tested private security intake, primary/backup access, and release/rollback rehearsal. A stable minor defaults to a non-shortenable 180-day term recorded in its exact release manifest.

The final immutable WordPress package bytes—not a developer checkout—are the organizing artifact for release evidence. Vanilla results and any future WordPressHx provider receipt remain separate fields.

See [SUPPORT.md](SUPPORT.md), [SECURITY.md](SECURITY.md), and [docs/release/README.md](docs/release/README.md) for the current deliberately limited policies.
