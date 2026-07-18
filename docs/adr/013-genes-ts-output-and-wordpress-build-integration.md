# ADR-013: Genes TypeScript output and WordPress build integration

- Status: accepted
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product and architecture owner); Codex (source, evidence, and implementation review)
- Bead: wordpresshx-adr-013
- Profiles/layers: wp70-release; Genes compiler boundary; SDK browser profile; WordPress browser build

## Context

WordPressHx needs one browser path that remains Haxe-authored while producing
ordinary artifacts that WordPress and JavaScript developers can inspect, type
check, bundle, and import. Gate G2 requires a real Gutenberg component with
props, events, a hook, a ref or context boundary, package imports, styles,
translations, a retained public ESM export, final dependency metadata, browser
evidence, and a representative classic Genes comparison.

The generic compiler boundary is already fixed. Genes v1.33.0 is pinned at
commit 7999b7cff09f78ebb8e09c3db6e221beb141b67b and passed its complete release
gate under SDK-030. The mutable sibling checkout at ../genes is design
authority and the place to reduce generic defects, but it is not a consumer
build input. Its newer or dirty HEAD cannot silently change this SDK.

Genes offers two real output paths:

- strict split ESM TypeScript/TSX source under the genes.ts define; and
- direct split ESM JavaScript, optionally paired with declarations, when that
  define is absent.

They share a bounded tested Haxe corpus, but they are not textually identical
and are not yet a universal interchangeable-output promise. Haxe DCE also
cannot see callers that exist only in authored JavaScript, TypeScript, or a
bundler entry. Public ESM surfaces therefore need an explicit retained graph.

WordPress adds a different responsibility. Source modules import packages such
as @wordpress/components and @wordpress/i18n, while the final classic script
usually executes against registered WordPress globals and declares handles
such as wp-components and wp-i18n. React automatic JSX output introduces the
react/jsx-runtime request and the react-jsx-runtime handle. Those mappings,
bundle decisions, final version hashes, and asset PHP files belong to normal
WordPress build tooling and the selected compatibility profile, not to Genes.

The exact wp70-release source requires Node at least 20.10.0 and npm at least
10.2.3. Its embedded Gutenberg commit uses TypeScript 5.9.3 and declares
@wordpress/scripts 31.5.0 plus dependency-extraction plugin 6.40.0. The repo
already contains an exact Node 22.17.0 image. Probing that digest reported npm
10.9.2. Genes v1.33.0 was locally release-tested on Node 20.19.3 and has
upstream Node 20 and 22 lanes; those compiler-maintainer inputs must not be
confused with the generated-project package manager.

This ADR selects the architecture. It does not claim that the WordPress
fixture, package install, bundle, runtime, or production support has passed.
SDK-031 through SDK-035 own those proofs.

## Decision

### Strict TS/TSX is the primary lane

The primary WordPress browser lane emits readable split ESM TypeScript source:

- .ts for modules without emitted JSX and .tsx for markup-bearing modules;
- genes.ts, genes.ts.no_extension, genes.library, and js-es=6;
- extensionless relative imports because the WordPress application is
  bundler-first;
- Haxe inline HXX lowered by Genes to TSX;
- the automatic React JSX runtime, producing the normal
  react/jsx-runtime request; and
- no authored wp global access in source modules.

The minimum strict typecheck contract is:

~~~json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "strictNullChecks": true,
    "exactOptionalPropertyTypes": true,
    "noUncheckedIndexedAccess": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": false,
    "jsx": "react-jsx",
    "noEmit": true
  }
}
~~~

The exact project compiler is TypeScript 5.9.3. It is selected because the
wp70-release embedded Gutenberg source uses that version, while Genes v1.33.0
has generated-output evidence on TypeScript 5.5.4, 6.0.2, and 7.0.2. Selection
between proven surrounding compiler lanes is not itself compatibility proof;
SDK-031 must run the exact 5.9.3 WordPress corpus and stop if it exposes an
unsupported construct.

A passing typecheck is necessary but insufficient. SDK-031 must also run
negative consumers, a lexical weak-type inventory, and a TypeScript semantic
export audit. Normal user and public export surfaces have an empty unexplained
any/unknown delta. Deliberate foreign boundaries need stable waiver IDs,
owners, reasons, source provenance, and containment evidence.

### Classic Genes is a bounded differential lane

Selected source also emits classic split ESM JavaScript with adjacent
declarations:

- omit genes.ts;
- enable dts, genes.library, genes.no_extension,
  genes.react.inline_markup, and js-es=6;
- type check the declarations from an external strict consumer with
  skipLibCheck disabled; and
- compare observable runtime behavior and public contracts, not generated
  formatting.

Classic output is not the default production lane and not an automatic
emergency switch for every project. It is a compiler-pressure and regression
lane for an explicit corpus. If source uses a target-specific construct, the
fixture must either supply a typed target adapter with independently tested
semantics or narrow the shared corpus visibly. An unexplained behavior
difference blocks the affected G2 claim.

### Project and compiler toolchains are separate locks

Generated WordPress projects use:

- Haxe 4.3.7;
- Genes v1.33.0 at the exact commit, tree, and release artifact in SDK-030;
- Node 22.17.0 from the checksum-locked image
  docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0;
- npm 10.9.2;
- package-lock.json lockfile version 3 and npm ci; and
- TypeScript 5.9.3.

Generated direct npm dependencies are exact, not ranges. The lockfile owns the
complete transitive graph. Global installs, haxelib dev, mutable siblings, and
an uncommitted node_modules tree are contributor conveniences only and fail a
release build.

Genes upstream continues to use its own verified Yarn 1.22.22 release graph
and TypeScript matrix. The SDK does not rewrite that upstream project to npm,
and consumer scaffolds do not inherit Yarn merely because the compiler used it
for its release gate.

Node 20.19.3 remains accurate SDK-030 provenance, but it is not the selected
new-project runtime. Node 22.17.0 satisfies the WordPress floor, sits in the
Genes-supported Node 22 lane, and is already content-addressed by this
repository. SDK-031 must turn its current version probe into an actual strict
build/runtime receipt.

### Public exports use a declared retained graph

The versioned browser entry/export semantic plan is the source of truth for
externally callable ESM. Each entry records at least:

- stable export ID;
- Haxe source identity and source span;
- generated module and export name;
- type identity;
- retention rule; and
- exact profile capability references.

The SDK projects declared public facade roots to Genes library roots:

- @:genes.library on the selected facade class;
- genes.library in both TS and classic profiles;
- a macro include of only the declared public namespace so otherwise
  unreferenced roots are typed; and
- dts in classic output.

This retains the transitive public runtime/type graph while leaving private
unreachable implementation eligible for DCE. Disabling DCE globally and
scattering unmanifested keep metadata are prohibited. A narrow internal
initialization or side-effect root may use a compiler-required retention
mechanism only when it appears in the semantic plan with a reason and source
position.

Development may use a conservative DCE setting for debugging, but it consumes
the identical export and side-effect plan. Production uses full DCE. The
generated-source inventory, semantic TypeScript surface, production bundle,
ordinary JavaScript import/call, and classic declaration consumer must agree
on the declared public ABI.

### Normal ESM imports cross the WordPress boundary

Haxe/Genes source uses normal exact-profile-approved ESM requests. It does not
emit wp.components or other global spellings as its normal authoring form.
Initial admitted mappings are:

| Source request | WordPress handle | Package capability | Handle capability |
| --- | --- | --- | --- |
| @wordpress/blocks | wp-blocks | gutenberg.package.@wordpress/blocks | wordpress.script-handle.wp-blocks |
| @wordpress/components | wp-components | gutenberg.package.@wordpress/components | wordpress.script-handle.wp-components |
| @wordpress/data | wp-data | gutenberg.package.@wordpress/data | wordpress.script-handle.wp-data |
| @wordpress/element | wp-element | gutenberg.package.@wordpress/element | wordpress.script-handle.wp-element |
| @wordpress/i18n | wp-i18n | gutenberg.package.@wordpress/i18n | wordpress.script-handle.wp-i18n |

The exact dependency-extraction source also maps react, react-dom, and
react/jsx-runtime to react, react-dom, and react-jsx-runtime. WordPress 7.0
source contains those runtime handles. They must be promoted into the typed
profile/catalog before the G2 component uses them; the source observation in
this ADR is not a substitute for that admission.

Binding-free side-effect imports remain first-class dependency-plan edges and
must survive both compiler modes and bundling. Development and production
start from identical semantic imports. Minification cannot change the
external dependency set.

The wp global form exists only through generated, typed, exact-profile legacy
mappings for a declared non-module boundary. It is not an escape from package
resolution or a reason to weaken source types.

### WordPress tooling owns bundling and dependency extraction

The default MVP adapter is exact @wordpress/scripts 31.5.0. Its production
command is wp-scripts build and its development command is wp-scripts start.
The selected embedded Gutenberg source pairs it with
@wordpress/dependency-extraction-webpack-plugin 6.40.0.

The SDK begins with the normal default configuration. It may add entry
discovery and deterministic output paths, but it does not replace or duplicate
the dependency-extraction plugin. A custom plugin instance is allowed only if
a supported requirement cannot be expressed by the default and the default
instance is removed exactly once; the resulting mapping still needs profile
and parity evidence.

For MVP, classic WordPress scripts are the default registration form. The
WordPress Script Modules API remains an explicit later capability because the
selected dependency tool describes module support as experimental and its
externalization rules differ. A post-MVP equivalent bundler requires an
adapter contract and independent parity evidence; command similarity is not
enough.

### Final artifacts, not source guesses, own dependency metadata

The official dependency-extraction output is authoritative only after the
SDK validates it. For every entry, SDK-033 compares:

1. the generated ESM import plan;
2. the build tool externalized-dependencies report;
3. the final development or production bundle;
4. the final asset PHP file;
5. the selected profile package-to-handle catalog; and
6. the native register/enqueue/translation plan.

The final asset PHP file is never hand-authored or patched after bundling. Its
dependency list and version come from the final bundle tool output. A clean
replay must reproduce the bundle/metadata relationship. Development and
production must report the same external handle set for the same semantic
entry; content versions may differ when bundle bytes differ.

Translation metadata attaches to the final registered handle. Source maps and
content hashes are generated in the same artifact transaction. Target-language
post-processing that changes behavior or imports after dependency extraction
is prohibited.

## Rationale

Strict TS/TSX keeps the generated browser surface reviewable and lets the
selected WordPress/React declarations validate package components, event
handlers, refs, children, and hooks after Haxe has validated the source
expressions. Choosing the embedded Gutenberg TypeScript version minimizes a
profile split, while the existing Genes matrix supplies evidence on both sides
of that exact pin.

Classic output remains valuable because it exercises a distinct compiler path
and executable artifact without making weak TypeScript an acceptable fallback.
The differential is deliberately semantic and bounded, matching the actual
upstream evidence.

The Genes library profile solves the DCE problem at the correct layer. It
captures the public graph before DCE and keeps runtime values and public types
together. A declared SDK export plan adds WordPress-facing stable IDs,
capability references, and source correlation without adding WordPress logic
to the compiler.

Normal package imports preserve familiar React/WordPress development and let
the official dependency tool make its intended bundled-versus-external
decision. Validating its final output is safer than predicting handles from
source alone, while the exact profile prevents the build tool from silently
admitting a symbol the target WordPress installation does not provide.

## Alternatives considered

### Make classic Genes JavaScript the primary lane

Classic JS has the more mature direct runtime path and avoids a TypeScript
compile step. It gives up the readable strict TSX product surface and weakens
the second type boundary against exact Gutenberg declarations. It remains the
selected differential, not the primary lane.

### Emit only TypeScript and omit the differential

This is simpler, but it removes a valuable independent compiler/runtime signal
and an already proven Genes capability. It would allow a mode-specific
lowering regression to hide behind one toolchain. Rejected for the
representative G2 corpus.

### Promise universal same-source switching

Genes evidence explicitly bounds dual output to tested corpora. React package
shapes, mutable bindings, source maps, and target helpers can differ. A broad
promise would outrun evidence, so the differential stays explicit and
fixture-scoped.

### Track the sibling Genes checkout or newest tag

The sibling currently contains newer releases and user-owned changes. Using it
would make builds path-dependent and bypass SDK-030. The immutable v1.33.0
release remains selected until a fresh full upstream and SDK receipt admits an
upgrade.

### Use Node 20.19.3 as the project runtime

It exactly matches the local Genes release gate and satisfies WordPress 7.0's
minimum. It conflates compiler verification with the generated project and
does not use the repository's already selected Node 22 image. Node 22.17.0 is
chosen, with SDK-031 responsible for exact integration proof.

### Use the Genes TypeScript floor or newest lane as the project compiler

TypeScript 5.5.4 is directly verified as the legacy floor, while 7.0.2 is the
current Genes output lane. Neither is the exact compiler selected by embedded
Gutenberg. TypeScript 5.9.3 minimizes the WordPress profile mismatch and must
earn its own SDK fixture evidence.

### Rewrite imports to wp globals in Genes

This would couple the generic compiler to WordPress names, bypass normal ESM
typing, and duplicate dependency-extraction behavior. It is prohibited.
Typed legacy globals remain an SDK/profile adapter only.

### Generate asset PHP from the source import graph

Source imports cannot prove what bundling, tree shaking, externals, or
minification left in the final entry. A precomputed asset file can drift from
runtime bytes. Source planning remains an audit input; final build output owns
the emitted asset file.

### Disable DCE or add keep everywhere

Both approaches conceal ownership and inflate runtime output. The reusable
library root plus a versioned export/side-effect manifest retains only the
external contract.

### Adopt another bundler now

Vite, esbuild, or a custom Next-oriented build can be attractive, but G2 needs
native WordPress dependency and asset parity first. @wordpress/scripts is the
MVP default; a later adapter must prove equivalent externalization, hashes,
translations, source maps, and runtime behavior.

## Consequences

Benefits:

- the happy path stays entirely Haxe-authored while emitting ordinary
  TS/TSX, JavaScript, declarations, bundles, and asset PHP;
- React and Gutenberg props/events/hooks/refs receive exact strict TypeScript
  validation instead of Dynamic;
- compiler and WordPress package knowledge remain cleanly separated;
- public ESM survives production DCE through an explicit graph;
- official WordPress externalization and handle behavior remain authoritative;
- classic output supplies an independent bounded runtime signal; and
- future equivalent bundlers have a concrete parity contract.

Costs and constraints:

- two compiler profiles and their declarations/runtime transcripts must be
  maintained for the selected corpus;
- generated projects carry an exact Node/npm/TypeScript/package lock;
- the profile catalog needs React runtime handle admission before G2 exits;
- SDK-031 must prove TypeScript 5.9.3 despite the upstream Genes matrix using
  neighboring generated-output versions;
- SDK-033 must inspect final build artifacts instead of trusting source or
  plugin success alone; and
- script-module output and alternate bundlers remain outside MVP until they
  earn separate evidence.

This decision advances architecture only. browserSdkCompatibility and
productionSupport remain not-tested, and publication remains unauthorized.

## Evidence and commands

Machine-readable authority:

- manifests/browser-build-architecture.json;
- manifests/upstream.lock.json;
- manifests/toolchain.lock.json;
- manifests/evidence/sdk-030-genes-ts-v1.33.0.json;
- profiles/wp70-release/source.lock.json; and
- generated/wp70-release/catalog-v1/catalog.json.

Immutable source review:

- Genes v1.33.0 package manifest, toolchain matrix, output modes, interop, and
  React HXX contract;
- embedded Gutenberg commit
  a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd root package manifest;
- its packages/scripts/package.json at version 31.5.0;
- dependency-extraction package and mapping implementation at version 6.40.0;
  and
- WordPress 7.0 script-loader package inventory.

Decision checks:

~~~sh
docker run --rm \
  docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0 \
  sh -c 'node --version && npm --version && corepack --version'
python3 -m json.tool manifests/browser-build-architecture.json
bash scripts/check-repository.sh
bash scripts/hooks/test.sh
bd lint
bd dep cycles
git diff --check
~~~

The exact image probe returned Node v22.17.0, npm 10.9.2, and Corepack 0.33.0.
Corepack is observed provenance, not the selected project package manager.

No Genes modification or PR is required by this decision. If SDK-031 or
SDK-032 exposes a generic defect, the existing isolated-worktree,
generic-fixture, complete-regression, upstream-PR, and fresh-pin policy applies.

## Migration, rollback, and supersession

There is no released browser ABI to migrate. New browser scaffolds start with
this profile. Existing experiments using classic JS may remain differential
fixtures or migrate by adding the strict TS/TSX lane and declared export plan;
they are not silently relabeled primary.

Rollback of generated artifacts means rebuilding from the previous immutable
project lock and Genes SDK receipt. It does not mean pointing at an older
sibling checkout. The recorded Genes v1.32.0 rollback also requires a fresh SDK
receipt.

A superseding ADR is required to change the primary compiler mode, project
Node/npm/TypeScript tuple, default WordPress build adapter, public retention
model, or final-artifact authority. A minor package update within the same
architecture still needs exact locks and the affected SDK evidence.

If exact TypeScript 5.9.3 cannot sustain strict generated output, SDK-031 stops
and this ADR is revisited; it must not normalize weak types. If official
dependency extraction cannot match the exact profile and final bundle,
SDK-033 blocks release and may narrow supported imports. If public exports
cannot survive bounded retention, the public browser ABI is narrowed before
disabling DCE.

## Follow-up beads

- wordpresshx-sdk-031: implement the exact strict profile, weak-type audit,
  export plan, library roots, DCE, and ordinary JS consumer.
- wordpresshx-sdk-032: implement the typed React/Gutenberg HXX component,
  props, events, hooks, refs, styles, and package externs.
- wordpresshx-sdk-033: run normal WordPress builds and prove import,
  externalization, final asset PHP, enqueue, version, and translation parity.
- wordpresshx-sdk-034: prove source maps through generated TSX and the final
  bundle.
- wordpresshx-sdk-035: establish the representative classic Genes semantic
  differential.
- wordpresshx-sdk-113: consume the versioned public browser/NextJsHx adapter
  contract without a floating sibling dependency.
