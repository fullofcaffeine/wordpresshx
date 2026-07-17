# wordpress-hx-sdk

`wordpress-hx-sdk` is a typed Haxe SDK and build toolchain for authoring ordinary WordPress plugins, themes, blocks, editor extensions, REST APIs, and related native artifacts.

> **Status: bootstrap / pre-feasibility.** There is no released SDK, supported compatibility profile, installable package, or production-readiness claim yet. The feasibility gates in the product requirements document decide when any narrower claim becomes valid.

The intended build flow is:

```text
Haxe declarations and source
          |
          v
validated semantic build plan
          |
          +--> native PHP and templates
          +--> strict TS/TSX/JS and assets
          +--> WordPress metadata and packages
          |
          v
unmodified vanilla WordPress and Gutenberg
```

The product is not a WordPress fork, a replacement runtime, a generic CMS abstraction, or a proprietary site builder. The SDK and the separate full `wordpress-hx` port may share released generic compiler packages and public contracts, but neither project may import the other's unpublished implementation internals or merge its compatibility claims.

## Product authority

The canonical planning source is [wordpress-hx-sdk-product-requirements.md](wordpress-hx-sdk-product-requirements.md). It defines the exact-profile MVP, architecture, feasibility gates, risk register, evidence contract, and bounded 90-day sequence.

Work is tracked in the repository's beads database:

```bash
bd prime
bd ready
bd show wordpresshx-sdk-000
```

The imported roadmap uses stable IDs matching the PRD (`SDK-000` through `SDK-111`), explicit ADR beads (`ADR-001` through `ADR-022`), and gate epics (`G0` through `G8`).

## Bootstrap check

The only repository-wide executable check at this stage validates the policy/layout skeleton and rejects direct dependencies on full-port internals:

```bash
bash scripts/check-repository.sh
bd lint
bd dep cycles
```

Compiler, profile, PHP, browser, WordPress, and package checks will be added by their dependency-gated beads; this bootstrap does not pretend those toolchains already exist.

## Compiler direction

- PHP: continue the custom Reflaxe PHP compiler originating in `wordpresshx-port`, while extracting and pinning it as a reusable generic compiler package. The SDK must not import the port's Core linker, original-path replacement machinery, or internal source paths.
- Browser: use the sibling genes-ts project as the compiler authority. Any required change must be generalized in an isolated upstream worktree, protected by a non-WordPress regression fixture and the relevant full upstream suite, and submitted upstream before this repository pins it.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the working agreement and [docs/](docs/) for the documentation map.

## Policies

- [Governance](GOVERNANCE.md)
- [Security](SECURITY.md)
- [Support](SUPPORT.md)
- [Contribution workflow](CONTRIBUTING.md)
- [Licensing status](LICENSES/README.md)
- [Release status](docs/release/README.md)

No license or public distribution grant has been selected yet. Public package or release publication remains blocked on the dedicated licensing review.
