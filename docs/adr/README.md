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
- [ADR-004: Generic PHP compiler home and extraction boundary](004-generic-php-compiler-home.md)
