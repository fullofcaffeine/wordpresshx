# Architecture decision records

Required decisions are tracked as `wordpresshx-adr-001` through `wordpresshx-adr-022`. An open bead describes a decision to make; it is not an accepted ADR.

When a decision is accepted, create a numbered immutable record in this directory using this structure:

```markdown
# ADR-NNN: Title

- Status: proposed | accepted | superseded
- Date: YYYY-MM-DD
- Owners/reviewers: ...
- Bead: wordpresshx-adr-NNN
- Profiles/layers: ...

## Context

## Decision

## Rationale

## Alternatives considered

## Consequences

## Evidence and commands

## Migration, rollback, and supersession

## Follow-up beads
```

Decisions involving licensing, security, public support, or compatibility claims require appropriate qualified review. Prototypes and comments are supporting evidence, not acceptance by themselves.

## Accepted records

- [ADR-001: Product and repository boundary](001-product-and-repository-boundary.md)
- [ADR-002: Exact compatibility profiles](002-exact-compatibility-profiles.md)
- [ADR-003: Package topology and lockstep versioning](003-package-topology-and-lockstep-versioning.md)
- [ADR-004: Generic PHP compiler home and extraction boundary](004-generic-php-compiler-home.md)
- [ADR-005: Public versus private PHP emission](005-public-versus-private-php-emission.md)
- [ADR-006: Semantic plan and emitter contract](006-semantic-plan-and-emitter-contract.md)
- [ADR-008: Profile generation and API classification](008-profile-generation-and-api-classification.md)
- [ADR-011: HXX parser and lowering architecture](011-hxx-parser-and-lowering-architecture.md)
- [ADR-013: Genes TypeScript output and WordPress build integration](013-genes-ts-output-and-wordpress-build-integration.md)
- [ADR-014: Source maps and PHP trace correlation](014-source-maps-and-php-trace-correlation.md)
- [ADR-021: Release and support policy](021-release-and-support-policy.md)

## Proposed records

- [ADR-020: Licensing and generated output](020-licensing-and-generated-output.md) — qualified review and owner approval pending; no license grant or publication authorization.
