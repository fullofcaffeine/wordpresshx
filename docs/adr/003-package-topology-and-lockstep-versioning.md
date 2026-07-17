# ADR-003: Package topology and lockstep versioning

- Status: accepted
- Date: 2026-07-17
- Owners/reviewers: Marcelo Serpa (product owner and ecosystem direction), Codex (package/release architecture review)
- Bead: `wordpresshx-adr-003`
- Profiles/layers: SDK distribution, Haxe authoring modules, CLI, compiler workspaces, generated consumer artifacts
- Supersedes: the separate-publication recommendation in PRD §§11.1 and 11.3
- Superseded by: none

## Context

The SDK must present one coherent Haxe-first product while its first vertical slices stabilize contracts across server APIs, Gutenberg/browser APIs, HXX, exact profiles, schemas, build macros, the WordPress compiler profile, packaging, and real WordPress evidence. The PRD originally proposed a public Haxelib for nearly every source directory, lockstep-versioned through at least `1.0`.

Those source boundaries are useful, but public package boundaries have a different cost. Multiple Haxelibs require dependency metadata, publication order, compatibility ranges, partial-upgrade diagnostics, support promises, and packed-consumer tests. They do not reduce the PHP or JavaScript shipped to WordPress: Haxe compiles imported code, and SDK source packages are development inputs rather than server runtime dependencies. No independent consumer currently needs only the profile catalog, contracts, HXX parser, build macros, or test helpers as a separately versioned product.

The repository also contains two components with different authorities:

- `compiler/reflaxe.php/` is the private, generic, independently structured PHP compiler described by ADR-004. It is co-located during `0.x`, but it is not a WordPress SDK API or a separately published SDK package.
- `genes-ts` is the browser compiler authority in the separate Genes repository. WordPressHx consumes an immutable public Genes release and must not absorb or privately republish it.

The longer-term product may join a unified family with the maintainer's other Haxe compiler and framework projects. That favors portable contracts and deterministic artifacts, but it does not justify a shared package or floating sibling dependency before two real consumers prove common semantics.

## Decision

### Monorepo and public release unit

WordPressHx remains a monorepo. Through the `1.x` release line, one SDK release has exactly one SemVer identity and two public distribution artifacts:

| Logical public artifact | Ecosystem | Responsibility | Production runtime presence |
|---|---|---|---|
| `wordpress-hx` | Haxelib | Complete Haxe authoring and compile-time SDK distribution | None as a package; generated native code may be present |
| `@wordpress-hx/cli` | npm | Project creation, orchestration, checking, inspection, packaging, adoption, and diagnostics | None |

The registry spellings are reserved logical identities until naming, licensing, and publication gates approve them. Changing a spelling before the first public release does not change this topology.

The Haxelib is both the recommended install and the complete supported Haxe surface. It is not a thin dependency aggregator over separately published component Haxelibs. The npm CLI is separate because it is a host-native executable with a different package ecosystem, not because it may choose an independent SDK version.

Publication is not authorized by this ADR. ADR-020, SDK-002, release evidence, and registry ownership must pass first.

### Source-module classification

The proposed PRD packages are accepted as source and namespace boundaries inside the `wordpress-hx` Haxelib, not as separately published packages:

| Source module | Supported exposure | Direct publication | Allowed direct dependencies |
|---|---|---:|---|
| `packages/core` | public `wordpress.hx.core.*` API | no | none |
| `packages/profiles` | public generated `wordpress.hx.profile.*` API/data | no | `core` |
| `packages/contracts` | public `wordpress.hx.contracts.*` API | no | `core` |
| `packages/hxx` | public compile-time `wordpress.hx.hxx.*` API | no | `core` |
| `packages/server` | public `wordpress.hx.server.*` API | no | `core`, `profiles`, `contracts`, `hxx` |
| `packages/gutenberg` | public `wordpress.hx.gutenberg.*` API | no | `core`, `profiles`, `contracts`, `hxx` |
| `packages/build` | documented public macro/config entry points; implementation internal | no | all preceding modules |
| `packages/testing` | public dev/test helpers | no | all preceding modules, including `build` |
| `packages/interop-php` | internal adoption implementation | no | `core`, `profiles`, `contracts` |
| `packages/interop-js` | internal adoption implementation | no | `core`, `profiles`, `contracts` |
| `packages/cli` | internal source of `@wordpress-hx/cli` | only as the CLI artifact | SDK release manifest and bundled internal tools |

Public Haxe modules may have separately documented compatibility and deprecation policy while sharing one package version. A class under an internal namespace, an `_internal` directory, `tools/`, or a compiler workspace is not a supported API merely because its source is included in an archive.

Shared JSON schemas and exact profile catalogs are versioned contracts bundled with the SDK and CLI as required. They are not standalone registry packages. Examples, fixtures, evidence receipts, Docker definitions, and generated project ZIPs are repository or consumer artifacts, not SDK packages.

### Dependency direction

The source dependency graph is acyclic and points from specialized authoring/tooling layers toward smaller contracts:

```text
core
├── profiles
├── contracts
└── hxx
    ├── server      -> core + profiles + contracts + hxx
    └── gutenberg   -> core + profiles + contracts + hxx
         └── build  -> all authoring modules
              └── testing -> all supported modules

wordpress-hx distribution -> every supported module
@wordpress-hx/cli         -> release manifest + bundled host tooling

SDK build/profile -> compiler/reflaxe.php
SDK browser build -> immutable genes-ts release
```

The tree is illustrative; the dependency list in `manifests/package-topology.json` is the machine-checked authority. In particular:

- `core`, `profiles`, `contracts`, and `hxx` must not import WordPress server, Gutenberg, build, testing, CLI, or compiler implementation modules.
- HXX owns the neutral compile-time AST, contextual-output contracts, and resolver interfaces. Server and Gutenberg own their tag/component adapters, so HXX never imports either platform layer.
- public authoring modules must not import `build`; build discovers or consumes their public metadata/contracts. This prevents a macro cycle.
- `testing` may consume supported surfaces; production modules never depend on testing.
- CLI code may orchestrate Haxe and bundled tools but is not imported by generated PHP or browser output.
- the only generic compiler direction is SDK to `compiler/reflaxe.php`; ADR-004's WordPress-independence checks remain mandatory.
- sibling projects are consumed only through immutable public packages, schemas, CLIs, or copied fixtures with provenance. Repository-relative sibling paths are forbidden release dependencies.

The application happy path remains one install surface. Developers do not select an internal module graph or author PHP/JavaScript to create a normal site. They import only the Haxe namespaces they need; the compiler and package builder determine the native dependency closure.

### Lockstep SemVer and release train

Every public SDK release follows these rules:

1. One canonical release manifest chooses version `X.Y.Z` and identifies the repository commit, exact profiles, toolchain inputs, compiler content or release pin, Genes release, schemas, artifacts, hashes, and evidence receipts.
2. Repository tag `vX.Y.Z`, Haxelib `wordpress-hx` version `X.Y.Z`, and npm `@wordpress-hx/cli` version `X.Y.Z` must agree exactly. There is no supported mixed SDK/CLI version.
3. Both public artifacts are staged and tested from clean packed artifacts for every release, even when one artifact's source did not otherwise change.
4. Tracked development metadata uses an explicit development sentinel. Release tooling injects `X.Y.Z` only into an isolated staging tree and verifies that the working tree does not acquire release-version churn.
5. The CLI-generated project lock records exact versions and content hashes for the SDK, CLI, Haxe, Genes, compiler, profiles, Node/package manager, and any other build input. Floating `haxelib dev`, mutable sibling paths, branch names, and registry ranges are contributor conveniences and fail release/doctor checks.
6. Supported public imports are SemVer-governed as one SDK surface. Breaking any supported module requires the major-version treatment appropriate to the current release policy; an internal directory name does not create a compatibility loophole.
7. Generated plugin, theme, block, and solution ZIPs record the SDK release identity that built them, but they have their own application/plugin/theme versions and are not assigned the SDK version.

Before the first release, the distribution manifest and packed-consumer gates may omit an unimplemented public namespace. It may not publish an empty placeholder package or claim that namespace is supported. Once admitted to the public Haxelib, removal follows the SDK deprecation and SemVer policy.

### Compiler version boundary

The co-located `compiler/reflaxe.php` package remains workspace-private at version `0.0.0` during its current incubation. A WordPressHx release records its exact source content hash and may stage it as an implementation input, but it does not present that content as a public `reflaxe.php` registry release or give it the SDK SemVer identity.

When ADR-004's extraction criteria are met, the compiler receives its own repository/release authority and independent SemVer. WordPressHx then consumes an immutable compiler version and hash. This is an external toolchain pin, not an exception allowing WordPressHx's two public artifacts to drift.

### Admission to independent versioning

No WordPressHx source module may become an independently versioned public package merely because a directory already exists. A post-`1.0` superseding ADR may extract one only when all of the following are demonstrated:

1. at least one real consumer uses the candidate without the rest of WordPressHx, or an independently owned release cadence solves a measured maintenance/support problem;
2. the candidate can build, test, document, pack, install, and roll back from its own clean artifact without repository-relative imports;
3. its public API and data ownership are explicit, its dependency graph is acyclic, and it imports other modules only through supported public APIs;
4. exact minimum/maximum compatibility ranges produce a finite downstream matrix that CI exercises from packed artifacts;
5. maintainers accept independent security, deprecation, support-window, registry, and incident authority;
6. the split has a consumer migration plan, preserves the `wordpress-hx` recommended-install facade, and does not weaken deterministic locks or evidence receipts.

If any criterion is absent, the module stays internal to the distribution. A shared package for the wider Haxe solution family additionally requires at least two real projects to demonstrate the same semantics; similar vocabulary alone is insufficient.

## Rationale

One Haxelib gives users one coherent install while retaining strong namespaces, source ownership, and acyclic dependencies. It matches the actual deployment model: source packages do not run in WordPress, and Haxe's reachable-code compilation determines generated output. Separate Haxelibs would therefore optimize a development-time download boundary while imposing release and support work on every change.

The npm CLI remains a separate artifact because Node package managers, executable installation, bundled host tools, and update mechanics are genuinely distinct from Haxelib. Exact lockstep preserves a simple compatibility rule: the CLI and Haxe SDK either have the same version or the project is invalid.

The decision also follows the established sibling pattern: keep an independently meaningful compiler/package boundary where a distinct target tool exists, but incubate framework helpers inside the product until real consumers justify extraction. It preserves future composition with the wider Haxe family through versioned contracts instead of pretending today that repositories or modules already evolve independently.

## Alternatives considered

### Publish every proposed PRD package in lockstep

This preserves the most granular future packaging and lets consumers download only named SDK areas. It is not selected for the first stable line because there is no runtime-footprint benefit, no independent consumer evidence, and every nominal package adds packed-artifact, publication-order, compatibility, and partial-upgrade obligations. The source directories and namespaces preserve a mechanical future extraction path without publishing unsupported boundaries.

### Independently version every package from the beginning

This maximizes release autonomy, but creates a compatibility matrix before any boundary has proved autonomous. Exact profiles, HXX adapters, build macros, server/browser APIs, and test helpers are likely to change together during vertical-slice development. It is rejected.

### Publish only the npm CLI and hide all Haxe source in it

This gives one install command but makes Haxe dependency resolution, IDE indexing, macro class paths, source licenses, and direct library use opaque to standard Haxe tooling. It is rejected. The Haxe API is a real public Haxelib distribution.

### Use only one Haxelib and no CLI artifact

This removes cross-ecosystem version coordination, but Haxelib is not a suitable home for Node-based scaffolding, watch orchestration, package-manager integration, or ordinary npm executable workflows. It is rejected; lockstep makes the real two-artifact boundary safe.

### Extract the PHP compiler now or assign it the SDK version

Immediate extraction is governed by ADR-004 and remains unnecessary without its trigger evidence. Assigning the generic compiler the WordPress SDK version would falsely make it a WordPress product component and complicate later non-WordPress use. The private content-hashed workspace boundary is retained.

### Create a shared package for the unified Haxe family now

The sibling projects share useful patterns, but their target/runtime semantics and maturity differ. A premature common package would either be too abstract to help or would couple releases through unpublished internals. Shared contracts remain candidates until at least two real consumers and independent conformance evidence exist.

## Consequences

Benefits:

- users get one Haxe dependency and one exactly matching CLI version;
- source modules can evolve atomically during the feasibility and vertical-slice phases;
- unused SDK modules do not become generated WordPress runtime dependencies;
- there is no component-package compatibility matrix through `1.x`;
- compiler and Genes authorities remain independently movable and pinnable;
- future extraction is based on observed consumers and packed-artifact evidence.

Costs and constraints:

- every public Haxe namespace shares the SDK's major-version budget;
- a consumer interested in one namespace downloads the complete SDK source archive;
- internal boundaries need repository checks because the package manager does not enforce them;
- every release must stage and verify both the Haxelib and npm CLI;
- an eventual package split needs a superseding ADR and migration rather than a metadata-only change.

This decision does not claim that either public artifact exists in a registry, that the listed namespaces are implemented, or that any generated site is production-supported. Exact-profile and runtime evidence advance only through their own gates and receipts.

## Evidence and commands

Reviewed evidence and patterns:

- PRD §§11, 21.1, 26, 27, and 29.1;
- ADR-001's independent SDK/product boundary and ADR-004's co-located generic compiler seam;
- the current `packages/core` source-only scaffold and absence of independently consumable component artifacts;
- `haxe.ruby`'s target/compiler release alignment and its practice of incubating a companion framework layer until independent extraction is justified;
- `nextjshx`'s private workspace CLI boundary;
- Genes' single public Haxelib release authority;
- the `haxe.rust` family-extraction criteria and `haxe.go` decision to defer multi-package output without concrete ownership/tooling evidence.

The accepted machine-readable map is `manifests/package-topology.json`. Repository verification checks the two public artifacts, source classification, acyclic dependency direction, lockstep policy, compiler/Genes boundaries, and publication prohibition.

Acceptance commands:

```bash
bash scripts/check-repository.sh
bash scripts/hooks/test.sh
bd lint
bd dep cycles
git diff --check
```

No package publication, registry mutation, sibling source change, or generated-runtime compatibility claim is part of this ADR.

## Migration, rollback, and supersession

There is no released package consumer, so the PRD's proposed component package names become internal module labels without a user migration. Existing source remains under `packages/`; future assembly work stages it into the single Haxelib.

If clean packed-consumer evidence shows that one archive is technically infeasible, a superseding ADR may introduce multiple lockstep Haxelibs while retaining a `wordpress-hx` recommended-install facade. If a component later satisfies every independent-version admission criterion, a post-`1.0` ADR may extract it and define exact compatibility ranges and migration. Rollback is removal of the unshipped topology lock and restoration of the PRD proposal; it must occur before public release or include a full consumer migration.

## Follow-up beads

- `wordpresshx-adr-006`: define the semantic plan and emitter contract within the accepted dependency direction.
- `wordpresshx-adr-016`: define project locks and CLI configuration around one SDK version.
- `wordpresshx-adr-021`: define release/support mechanics for the two-artifact train.
- `wordpresshx-sdk-002`: choose and implement toolchain/release metadata without authorizing publication.
- `wordpresshx-sdk-040`: scaffold the internal HXX module and neutral resolver contract.
- `wordpresshx-sdk-080`: implement the CLI/package builder against the lockstep manifest.
- `wordpresshx-sdk-094`: prove clean packed-consumer installation of the public release unit.
- `wordpresshx-sdk-111`: prove a complete Haxe-only site and native deployment from the recommended install.
