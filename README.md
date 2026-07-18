# wordpress-hx-sdk

`wordpress-hx-sdk` is a typed Haxe SDK and build toolchain for authoring ordinary WordPress plugins, themes, blocks, editor extensions, REST APIs, and related native artifacts.

It is the application/site-level alternative for teams that want a Haxe-first development experience without replacing WordPress Core. A project may begin with typed interfaces to existing WordPress, PHP, plugin, and browser code, then move only the bounded implementations it chooses into Haxe. A new site may instead use Haxe/HXX as its complete maintained code and configuration surface. Both paths emit ordinary native WordPress artifacts; handwritten PHP and JavaScript are optional interoperability tools, not required authoring layers.

Haxe inline HXX is the primary UI surface: typed components, props, children, slots, WordPress helpers, design refs, and real Haxe expressions lower at compile time to proportionate native PHP/HTML or Genes TSX. The generic PHP compiler owns reusable typed markup lowering; the WordPress profile adds native hierarchy/helper ergonomics. No HXX parser, component registry, VDOM, or template runtime ships with a site. Existing templates and raw/native code remain explicit checked escape boundaries.

Canonical source: [github.com/fullofcaffeine/wordpresshx](https://github.com/fullofcaffeine/wordpresshx).

> **Status: bootstrap / pre-feasibility.** There is no released SDK, supported compatibility profile, installable package, or production-readiness claim yet. The feasibility gates in the product requirements document decide when any narrower claim becomes valid.

Claim records use the evidence terms `inventoried`, `typed`, `generated`, `runtime-tested`, and `production-supported`; no earlier term implies a later one. Vanilla `wp70-release`, opt-in `gutenberg-forward-23.4`, and any future WordPressHx provider result remain separate fields. See [ADR-001](docs/adr/001-product-and-repository-boundary.md) for the exact qualification and correction rules.

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

The longer-term architecture should compose with the maintainer's broader Haxe compiler and framework family through portable Haxe contracts, versioned semantic-plan/artifact schemas, immutable compiler packages, and independent evidence receipts. It must not acquire floating dependencies on sibling repositories merely to simulate that future integration.

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

## Local safety hooks

Install and verify the tracked hooks in every clone or worktree:

```bash
bash scripts/hooks/install.sh
bash scripts/hooks/test.sh
```

They pin Haxe Formatter 1.18.0 and Gitleaks 8.30.0, format staged Haxe, reject machine-local paths, scan staged changes, and scan complete reachable history before push. Synchronize Beads through `bash scripts/beads/push-safe.sh` so decoded issue state and history are scanned before the separate Dolt ref is published.

## Compiler direction

- PHP: continue the custom Reflaxe PHP compiler originating in `wordpresshx-port` as an independently structured generic package under `compiler/reflaxe.php` in this monorepo during 0.x. The SDK must not import the port's Core linker, original-path replacement machinery, or internal source paths. [ADR-004](docs/adr/004-generic-php-compiler-home.md) defines the boundary and later extraction triggers.
- Browser: use the sibling genes-ts project as the compiler authority. Any required change must be generalized in an isolated upstream worktree, protected by a non-WordPress regression fixture and the relevant full upstream suite, and submitted upstream before this repository pins it.

The browser-compiler selection baseline is the immutable genes-ts `v1.33.0`
release; the active SDK-031 Gutenberg/browser fixture is locked to the later
`v1.36.3` release through a recorded generic-fix lineage. Their exact commits,
trees, package digests, toolchains, upstream CI, and clean replays are recorded
in the [browser compiler pin](docs/architecture/browser-compiler.md). These are
compiler-input and strict-fixture claims, not yet a complete WordPress browser
support claim.

SDK-032 now layers typed Haxe inline markup over that boundary for the exact
`wp70-release` React/Gutenberg profile. Its Haxe-only registration-proof page
exercises Button, Notice, hooks, state, context, DOM refs, mouse and keyboard
events, fragments, conditions, loops, and closed spreads, then verifies the
generated TSX, real React runtime, accessibility structure, visual bundle, and
source maps. Dependency extraction, translations, full browser trace evidence,
and the classic differential remain separately gated, so G2 is not yet closed.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the working agreement and [docs/](docs/) for the documentation map.

## Policies

- [Governance](GOVERNANCE.md)
- [Security](SECURITY.md)
- [Support](SUPPORT.md)
- [Contribution workflow](CONTRIBUTING.md)
- [Provisional licensing review packet](LICENSES/README.md)
- [Release status](docs/release/README.md)

No repository-wide license or public distribution grant exists. ADR-020 now has
a provenance-bound provisional GPL-2.0-or-later recommendation, generated-output
origin model, component inventory, and machine-checked publication blocker; it
remains proposed pending a named qualified reviewer, product-owner approval, and
SDK-002 artifact/notice proof. Run `python3 scripts/licenses/test-license-policy.py`
to verify that the inventory is complete and publication still exits closed.
