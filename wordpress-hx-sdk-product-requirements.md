# 1. Title, status, authorship assumptions, and date
## `wordpress-hx-sdk` — Product Requirements Document and Architecture Charter

| Field | Value |
|---|---|
| **Status** | Draft 0.1 — architecture review candidate; implementation has not begun |
| **Product name** | `wordpress-hx-sdk` (provisional; naming ADR required before first public package) |
| **Date** | 2026-07-16 |
| **Prepared by** | Architecture and principal product engineering, using the supplied read-only repository snapshots |
| **Decision owners assumed** | Project maintainer(s) for product scope; compiler maintainers for generic target work; WordPress/Gutenberg upstreams remain runtime authorities |
| **Audience** | SDK maintainers, compiler maintainers, WordPress/Gutenberg contributors, Haxe developers, plugin/theme authors, security and release reviewers |
| **Normative language** | **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are requirements terms. “MVP” means the bounded first production-candidate scope, not the entire inventory in this document. |

> **Decision summary:** Create `wordpress-hx-sdk` as a separate open-source monorepo and product. Target one exact vanilla WordPress baseline first: `wp70-release`. Treat `gutenberg-forward-23.4` as an opt-in, separately generated capability profile. Use Haxe as the source of truth, but emit ordinary WordPress PHP, TypeScript/TSX/JavaScript, metadata, templates, and packages. Use a small typed native-PHP artifact emitter for public WordPress files and stock Haxe PHP only behind private implementation boundaries. Use genes-ts for strict browser output. Do not create a parallel WordPress runtime, a proprietary site builder, or a universal CMS abstraction.

---

## Table of contents

1. [Title, status, authorship assumptions, and date](#1-title-status-authorship-assumptions-and-date)
2. [Executive recommendation](#2-executive-recommendation)
3. [Product definition and terminology](#3-product-definition-and-terminology)
4. [Problem statement](#4-problem-statement)
5. [Product thesis and differentiation](#5-product-thesis-and-differentiation)
6. [Relationship to the full `wordpress-hx` port](#6-relationship-to-the-full-wordpress-hx-port)
7. [Users and detailed user journeys](#7-users-and-detailed-user-journeys)
8. [Goals, measurable outcomes, and explicit non-goals](#8-goals-measurable-outcomes-and-explicit-non-goals)
9. [Compatibility baselines and version profiles](#9-compatibility-baselines-and-version-profiles)
10. [Scope matrix](#10-scope-matrix-mvp-post-mvp-experimental-and-out-of-scope)
11. [Proposed repository and package topology](#11-proposed-repository-and-package-topology)
12. [Dependency-direction rules](#12-dependency-direction-rules)
13. [Detailed WordPress SDK capability model](#13-detailed-wordpress-sdk-capability-model)
14. [Detailed Gutenberg SDK capability model](#14-detailed-gutenberg-sdk-capability-model)
15. [Haxe-first solution/site composition model](#15-haxe-first-solutionsite-composition-model)
16. [Compiler, macros, target emission, and runtime architecture](#16-compiler-macros-target-emission-and-runtime-architecture)
17. [Typed boundary and escape-hatch policy](#17-typed-boundary-and-escape-hatch-policy)
18. [HXX/template architecture](#18-hxxtemplate-architecture)
19. [Generated artifact ownership and regeneration policy](#19-generated-artifact-ownership-and-regeneration-policy)
20. [Interoperability and gradual-adoption strategy](#20-interoperability-and-gradual-adoption-strategy)
21. [Developer experience and tooling](#21-developer-experience-and-tooling)
22. [Testing and evidence architecture](#22-testing-and-evidence-architecture)
23. [Security, accessibility, performance, i18n, and operational requirements](#23-security-accessibility-performance-i18n-and-operational-requirements)
24. [Distribution, packaging, versioning, and release policy](#24-distribution-packaging-versioning-and-release-policy)
25. [Documentation and example strategy](#25-documentation-and-example-strategy)
26. [Milestones and feasibility gates](#26-milestones-with-named-feasibility-gates-and-acceptance-criteria)
27. [Initial issue and epic backlog](#27-initial-issueepic-backlog-with-dependencies)
28. [Risk register](#28-risk-register-with-mitigations-and-stop-conditions)
29. [Required ADRs and unresolved questions](#29-required-adrs-and-unresolved-questions)
30. [Alternatives considered](#30-alternatives-considered)
31. [Recommended first 90-day bounded plan](#31-recommended-first-90-day-bounded-plan)
32. [Appendix: inspected evidence](#32-appendix-inspected-repositories-commits-dirty-state-and-authority)

---

# 2. Executive recommendation

## 2.1 Recommended architecture

Build `wordpress-hx-sdk` as a **separate, independently useful SDK repository** with five architectural layers:

1. **Typed WordPress and Gutenberg contracts.** Version-profiled Haxe externs, branded identifiers, schemas, enums, structural types, and macro-validated declarations model public native APIs without replacing them.
2. **Application authoring APIs.** Thin, target-shaped APIs for hooks, content types, REST endpoints, blocks, editor extensions, stores, templates, security boundaries, and packaging. These APIs remove stringly typed mistakes while preserving recognizable WordPress/Gutenberg concepts.
3. **Build-time semantic plan.** Haxe macros collect declarations into a target-neutral-enough semantic plan: plugin/module descriptors, hook registrations, schemas, block metadata, template ASTs, exported facades, asset dependencies, and profile requirements. This plan is not a runtime framework.
4. **Native artifact emitters.** A WordPress PHP artifact emitter, genes-ts, metadata generators, HXX lowerers, and normal WordPress build tools produce ordinary PHP, TSX/TS/JS, `block.json`, `theme.json`, CSS, asset metadata, translation metadata, source maps, Composer/npm metadata, and ZIP packages.
5. **Evidence and ownership tooling.** A fail-closed manifest records every generated path and checksum. Real WordPress, PHP, browser, editor, package, and deterministic-build gates decide support claims.

```text
Haxe source + typed project declarations
                 │
                 ▼
      macro-validated semantic plan
        │            │             │
        │            │             ├── metadata emitters
        │            │                 block.json / theme.json / POT / manifests
        │            │
        │            └── genes-ts ──► TS / TSX / JS ──► @wordpress/scripts
        │
        └── WordPress PHP profile ──► native PHP/bootstrap/templates
                                      │
                                      ▼
                         normal plugin/theme/block ZIPs
                                      │
                                      ▼
                    unmodified WordPress + Gutenberg runtime
```

There is **no SDK runtime equivalent of WordPress, Gutenberg, React, a template engine, a router, or a data layer**. Generated code calls those native runtimes.

## 2.2 Hard decisions

| Decision | Recommendation | Why |
|---|---|---|
| Repository | Separate SDK monorepo | Independent product authority, releases, maturity claims, and compatibility tests; no coupling to full-port internals |
| Initial WordPress support | One exact `wp70-release` baseline | Broad ranges would be marketing without evidence; exact pins make generated API catalogs and behavior tests reviewable |
| Forward Gutenberg | Separate opt-in `gutenberg-forward-23.4` profile | Prevents accidental forward API leakage into WordPress 7.0 artifacts |
| Server output | Native public PHP emitter plus bounded stock Haxe PHP for private classes | Stock Haxe PHP is useful but does not naturally express every public WordPress file/ABI shape |
| Browser output | genes-ts strict TS/TSX as primary development lane; classic Genes JS as differential/fallback lane | Preserves readable typed output and uses the existing compiler pressure loop without WordPress-specific hacks |
| HXX | Compile-time lowering only | Typed authoring without a parallel runtime template system |
| Application composition | Thin workspace/build layer | Enables complete solutions while avoiding a proprietary CMS/site-builder runtime |
| Package versioning | Separately publishable packages, lockstep SemVer through at least `1.0` | Avoids premature dependency-version combinatorics while preserving future package independence |
| Generated output | Manifest-owned and fail-closed | Prevents overwriting user code and makes regeneration, cleanup, and upgrades auditable |
| Public API classification | Stable, experimental, private, unsafe, and deprecated are separate surfaces | WordPress/Gutenberg API maturity is not uniform and must not be flattened into one typed namespace |

## 2.3 The hardest tradeoffs

### Native shape versus compiler convenience

The SDK will fail if generated PHP looks like an opaque foreign runtime bolted onto WordPress. Plugin root files, callbacks, render boundaries, template files, class names, stack frames, asset handles, and metadata must look normal to a WordPress developer. This requires more compiler and emitter work than compiling every class through stock Haxe PHP. That cost is justified at public boundaries; it is not justified for every private helper on day one.

### Strong typing versus semantic camouflage

Haxe should eliminate invalid hook callback arity, malformed block attributes, unsafe output contexts, mismatched REST clients, misspelled capabilities, and untracked asset handles. It should **not** hide the facts that WordPress hooks are ordered mutable callbacks, REST permission callbacks execute at runtime, block serialization is an upstream contract, React hooks have lifecycle rules, or `WP_Query` has WordPress-specific behavior. The SDK should make those concepts safer, not rename them into a generic framework.

### Exact compatibility versus attractive breadth

The requested capability inventory is much larger than a responsible MVP. The MVP must prove a vertical product path—plugin bootstrap, hooks, a content type, a REST contract/client, one static block, one dynamic block, one editor extension, typed interop, packaging, and real WordPress tests. WP-CLI, list tables, full theme authoring, exhaustive Gutenberg packages, broad version ranges, and advanced Interactivity API behavior belong after those gates.

### Shared contracts versus false isomorphism

Shared models, enums, validation rules, and JSON codecs are valuable across PHP and browser targets. Sharing React components, database code, WordPress global state, or arbitrary service logic across targets is usually not. The SDK must support target-specific implementations around a deliberately small shared domain contract.

## 2.4 Recommendation on custom PHP compiler work

Create or extract a reusable, non-WordPress-specific Reflaxe PHP compiler core—provisionally `reflaxe.php-native`—that owns typed-AST lowering, PHP IR, printing, native arrays/callables/references, names, source correlation, and deterministic file output. Both `wordpress-hx-sdk` and the full port may pin releases of that compiler.

The SDK should own a **WordPress application profile** that adds plugin headers, bootstrap files, native registration calls, render adapters, template segments, WordPress coding style, and artifact manifests. The full port should separately own Core original-path replacement, distribution linking, whole-Core file inventories, and port-specific adapter registries.

For MVP, do not wait for a complete arbitrary-Haxe PHP target. Build the smallest reusable public-PHP artifact lane needed for the vertical sample while using stock Haxe PHP for bounded private implementation classes. The gate is output quality and runtime behavior, not compiler ideology.

## 2.5 MVP definition in one sentence

A developer can author, typecheck, build, inspect, install, test, and package a Haxe-owned WordPress 7.0 plugin containing typed hooks, a custom post type, a typed REST endpoint and generated browser client, a static block, a dynamic block, and an editor sidebar; the resulting ZIP contains only normal WordPress/PHP/JS artifacts, passes strict generated-code gates, and activates and behaves correctly in a real vanilla WordPress 7.0 installation.

---

# 3. Product definition and terminology

## 3.1 Product definition

`wordpress-hx-sdk` is a typed Haxe SDK and build toolchain for authoring WordPress plugins, mu-plugins, themes, blocks, editor extensions, REST APIs, admin surfaces, browser behavior, and complete solutions that execute on the **native WordPress and Gutenberg runtimes**.

It consists of:

- Haxe type libraries and externs;
- macro-based declarations and compile-time validators;
- typed HXX markup support;
- public PHP and browser compiler profiles;
- generators and adoption tools;
- deterministic native artifact production;
- integration and end-to-end test harnesses;
- package and release tooling;
- compatibility-profile metadata and diagnostics.

It is not a WordPress fork, a Gutenberg fork, a PHP framework, a JavaScript framework, a runtime template engine, a new block runtime, a new CMS, or a universal CMS portability layer.

## 3.2 Terminology

| Term | Definition |
|---|---|
| **SDK-authored** | Logic or metadata whose authoritative maintained source is Haxe or a typed SDK project declaration |
| **Native artifact** | A generated file in a format ordinary WordPress/PHP/JavaScript tooling already understands, such as PHP, TSX, JS, JSON, CSS, or a ZIP package |
| **Public WordPress boundary** | A symbol, file, callback, template, metadata file, script handle, global function/class, REST route, block registration, or package export visible to WordPress, Gutenberg, PHP, JavaScript, or another plugin/theme |
| **Private implementation PHP** | Namespaced generated PHP that is called only through SDK-owned public adapters and is not itself promised as a hand-authored WordPress API surface |
| **Profile** | An exact capability and compatibility contract tied to pinned WordPress/Gutenberg source and artifact baselines |
| **Capability token** | A typed proof that a compile-time profile or runtime environment provides an API or feature |
| **Contract** | A typed, versioned description of a boundary: schema, hook signature, PHP symbol, JS export, REST endpoint, block attributes, template locals, or generated callable ABI |
| **Adoption contract** | Generated or reviewed extern/facade metadata for existing PHP, JavaScript, TypeScript, plugin, or theme code |
| **Solution workspace** | A build-time project containing one or more normal plugins, themes, blocks, shared contracts, and deployment packages; it is not a runtime container |
| **HXX** | JSX-like Haxe markup parsed and validated at compile time, then lowered to PHP/HTML or TSX/JSX/native React calls |
| **Unsafe boundary** | A narrow, explicitly declared use of dynamic values, raw target syntax, private APIs, unvalidated data, or opaque external behavior |
| **Provider** | The runtime implementation of public WordPress/Gutenberg contracts: vanilla WordPress for the primary SDK claim; a future WordPressHx distribution for secondary compatibility evidence |
| **Production-ready** | The exact documented scope has passed the evidence contract in section 22.23; it does not mean every WordPress/Gutenberg API or version is supported |

## 3.3 Sources of truth

The product has multiple authorities, and they must not be conflated:

- Haxe source is authoritative for SDK-authored logic.
- `wordpress-hx-sdk` declarations and schemas are authoritative for generated SDK artifacts.
- Vanilla WordPress 7.0 source, distribution artifacts, and executable behavior are authoritative for `wp70-release` compatibility.
- The forward Gutenberg 23.4 source baseline is authoritative only for the `gutenberg-forward-23.4` profile.
- PHP, React, npm, Composer, browser, and WordPress build-tool behavior remain externally owned.
- The full `wordpress-hx` port is authoritative only for its own implementation and distribution claims, never for vanilla SDK behavior.

---

# 4. Problem statement

WordPress development has a large, capable ecosystem but exposes many important contracts through strings, heterogeneous arrays, loosely documented callback shapes, runtime-only errors, manually synchronized PHP/JavaScript schemas, and version-sensitive package exports. Gutenberg improves JavaScript modularity and typing, but a substantial extension still crosses PHP, JSON metadata, React, data stores, REST, asset manifests, translations, block serialization, and WordPress lifecycle APIs.

The resulting failure modes are familiar:

- a hook callback accepts the wrong number or type of arguments;
- `accepted_args` disagrees with the callback;
- a capability, nonce action, post type, taxonomy, screen ID, script handle, or REST route is misspelled;
- PHP validation and the TypeScript client disagree;
- a block attribute default or serialization shape changes without a deprecation/migration path;
- saved markup no longer validates;
- an editor package API exists in a Gutenberg plugin version but not in the embedded WordPress baseline;
- user-controlled content is escaped for the wrong output context—or not escaped at all;
- generated files are edited and later silently overwritten;
- a TypeScript declaration migrator emits plausible but incorrect Haxe;
- a plugin integrates with an existing PHP package through `Dynamic` and loses type safety immediately;
- build artifacts are difficult to inspect or debug because names and stack traces no longer resemble WordPress code;
- a project claims “WordPress support” without an exact tested version/profile.

PHP 8 and TypeScript can address many of these problems when used rigorously. The thesis is not that Haxe is inherently safer than well-engineered PHP/TypeScript. The thesis is that one typed Haxe source graph can make **cross-boundary consistency** materially better by generating and validating both server and browser artifacts from shared types, schemas, identifiers, enums, and macros—while still producing normal WordPress code.

The product problem is therefore not “wrap every WordPress function.” It is:

> Provide a native-looking, incrementally adoptable, strongly typed authoring system for the WordPress/Gutenberg boundaries where compile-time knowledge can prevent real cross-language and stringly typed defects, without obscuring the upstream runtime semantics or requiring a replacement runtime.

---

# 5. Product thesis and differentiation

## 5.1 What Haxe can materially improve

Haxe is most valuable where one declaration can safely drive multiple native artifacts or where its type system can close a WordPress boundary that is normally open-ended.

### Shared schemas and codecs

A Haxe schema can generate:

- Haxe server and browser types;
- strict JSON encoders/decoders;
- WordPress REST argument schemas;
- sanitization and validation functions;
- PHP response serialization;
- generated TypeScript interfaces through genes-ts;
- browser clients;
- block attribute metadata;
- negative compile-time diagnostics and runtime contract tests.

The gain is not fewer files; it is fewer independently drifting authorities.

### Branded identifiers instead of arbitrary strings

Post types, taxonomies, meta keys, options, capabilities, nonce actions, REST namespaces/routes, screen IDs, asset handles, translation keys, block names, store names, SlotFill names, template references, and hook references should be typed values generated from declarations. This prevents accidental interchange while leaving their native string representation visible in generated artifacts.

### Hook signatures and callback arity

Built-in hook catalogs and generated third-party hook contracts can encode callback argument types and return types. The compiler can infer `accepted_args`, reject an action callback used as a filter, and surface the exact native hook name in diagnostics.

### Algebraic data types at integration boundaries

Haxe enums can represent domain states and error cases more safely than nullable arrays or magic strings. At public boundaries they must lower to documented native scalar/object/array shapes, with explicit codecs and compatibility tests.

### Typed HXX and output contexts

HXX can validate component/tag props, required template locals, event handlers, children/slot contracts, and escaping contexts before emitting normal PHP/HTML or TSX. It should make unsafe HTML visibly exceptional.

### Compile-time profile enforcement

Conditional compilation and generated capability inventories can prevent a Gutenberg 23.4-only API from entering a `wp70-release` build. Runtime version checks alone are too late for package imports, asset handles, and incompatible signatures.

### Deterministic generated references

Macros and adoption tools can generate externs, facades, route references, store APIs, typed selectors/actions, and symbol catalogs from reliable source metadata. The output remains reviewable and regenerable.

### Safer refactoring across PHP and browser code

Renaming a shared DTO field, block attribute, capability reference, or REST endpoint should break compilation at every affected boundary rather than fail later in WordPress or the browser.

## 5.2 What the SDK must not abstract away

The following abstractions are rejected unless future evidence overturns this decision:

- a generic `Cms`, `ContentRepository`, or provider-neutral hook API designed before a second runtime provider exists;
- an ORM that pretends `WP_Query`, metadata tables, taxonomy relationships, and `$wpdb` behave like a conventional relational model;
- a runtime VDOM or server template engine;
- a generic event bus that hides WordPress hook ordering, priorities, mutable filter values, and accepted argument counts;
- a block framework that hides `block.json`, edit/save/render boundaries, serialization, deprecations, supports, or upstream validation;
- a React wrapper that changes hook lifecycles or prevents ordinary Gutenberg component use;
- a replacement data store abstraction over `@wordpress/data`;
- automatic monkey-patching of Gutenberg internals;
- a universal “safe” wrapper that converts every unknown PHP/JS value to `Dynamic` or `unknown`;
- generated PHP that requires developers to learn an opaque Haxe runtime before they can debug a WordPress callback.

## 5.3 Where native knowledge remains required

SDK users still need to understand:

- WordPress request/bootstrap and plugin lifecycle;
- hooks, capabilities, nonces, sanitization, validation, and escaping;
- PHP deployment, fatal errors, Composer/autoloading, and server compatibility;
- Gutenberg block lifecycle, serialization, editor state, React, and accessibility;
- JavaScript modules, bundling, browser debugging, and npm dependencies;
- database and caching behavior where their product depends on it;
- the difference between WordPress Core APIs, Gutenberg plugin APIs, experimental/private APIs, and third-party plugin contracts.

The SDK should shorten the distance from that knowledge to a correct implementation. It cannot make the knowledge unnecessary.

## 5.4 Differentiation from a typed PHP/TypeScript project

A disciplined PHP/TypeScript codebase remains a credible alternative and will often be simpler. `wordpress-hx-sdk` earns its complexity only when at least one of these is true:

- shared server/browser contracts are material;
- macros can validate or generate a large class of WordPress metadata and references;
- Haxe enums/abstracts/structural types improve the domain model;
- the team already has Haxe expertise or shared Haxe code;
- strict generated TS/TSX is a useful review surface;
- a complete solution benefits from one typed refactor graph across plugin, block, admin, REST, and browser layers.

The SDK documentation must say so plainly. A one-file PHP plugin with no browser boundary probably should remain PHP.

---

# 6. Relationship to the full `wordpress-hx` port

## 6.1 Product boundary

The full `wordpress-hx` project is attempting to replace WordPress and Gutenberg runtime implementation with Haxe-authored implementations while preserving compatibility. `wordpress-hx-sdk` instead authors extensions and solutions that consume the existing runtime.

| Concern | `wordpress-hx-sdk` | Full `wordpress-hx` port |
|---|---|---|
| Primary runtime | Unmodified vanilla WordPress/Gutenberg | Generated WordPressHx distribution |
| Primary product claim | Typed extension/solution authoring | Haxe ownership and compatibility of WordPress/Gutenberg runtime implementation |
| WordPress source authority | External runtime/API oracle | Replacement implementation oracle and parity target |
| Original Core path replacement | Out of scope | Core responsibility |
| Core distribution linker | Out of scope | Core responsibility |
| Plugin/theme/block packaging | Core responsibility | Useful as compatibility consumer, not ownership proof |
| SDK contract dependency | Owns and releases SDK | May pin released SDK versions |
| Port internals dependency | Forbidden | May depend on its own internals |
| Success evidence | Same extension works on vanilla baseline | Distribution behavior and ownership parity; later, same extension also works there |

## 6.2 Allowed sharing

The projects may share or jointly pressure:

- generic Reflaxe PHP compiler packages;
- genes-ts and ts2hx;
- HXX parser/AST concepts;
- public WordPress/Gutenberg contract inventories;
- schema formats;
- source-map formats;
- generated-artifact manifest schemas if generalized;
- exact compatibility fixtures and sample plugin ZIPs;
- release pins and cross-project receipts.

Sharing must happen through released packages, immutable commits, versioned schemas, or copied evidence fixtures with provenance—not by importing unpublished port-internal modules.

## 6.3 Forbidden coupling

The SDK MUST NOT:

- import the full port’s Core linker or original-path replacement machinery;
- rely on port-only classes, bootstrap behavior, global state, or generated distribution layout;
- use port ownership manifests as proof of SDK API correctness;
- claim a WordPress/Gutenberg API is supported merely because the full port has a scaffold or bridge;
- use the port’s task database as SDK task authority;
- block a vanilla WordPress release on the future availability of the port distribution.

The full port MUST NOT:

- count an SDK wrapper, extern, plugin, block, or generated artifact as Haxe ownership of the corresponding WordPress/Gutenberg runtime implementation;
- silently vendor an unreleased SDK checkout;
- force SDK API design around port-only implementation details.

## 6.4 Cross-project compatibility protocol

1. The SDK publishes an immutable release and a compatibility fixture package containing source, generated artifact manifest, and final plugin/theme ZIP hashes.
2. Vanilla WordPress execution is the blocking SDK compatibility gate.
3. The full port pins that exact SDK release and exact fixture artifact.
4. The full port runs the unchanged artifact against its generated distribution.
5. Results are recorded separately:
   - `sdk-vanilla-compatible`: SDK claim;
   - `port-extension-compatible`: full-port claim.
6. Failures are triaged to the owner of the violated contract. No project changes the other’s claim language without a receipt.

```text
public WP/Gutenberg contracts  ◄──────────────┐
          ▲                                   │
          │                                   │
wordpress-hx-sdk release ──► extension ZIP    │
          ▲                    │              │
          │                    ├─► vanilla WP ┘  (SDK gate)
          │                    │
          └── pinned by full port ─► WordPressHx distro (port gate)

No dependency arrow points from the SDK to port implementation internals.
```

## 6.5 Claim-language rule

Every dashboard, README, release note, and milestone must classify progress as one of:

- SDK contract coverage;
- SDK generated-artifact coverage;
- SDK vanilla runtime evidence;
- full-port implementation ownership;
- full-port parity evidence;
- cross-provider extension compatibility.

“WordPress Haxe support increased” is too ambiguous to be accepted in project status reporting.

---

# 7. Users and detailed user journeys

## 7.1 Primary users

### Existing WordPress plugin maintainer

Has a PHP plugin and perhaps a small JavaScript build. Wants to introduce strict types around one error-prone domain or REST/browser boundary without rewriting the plugin or changing deployment conventions.

**Journey:** install SDK tooling, generate an adoption contract for selected PHP symbols, create one Haxe module, compile it to a namespaced private implementation plus a stable PHP facade, call it from existing PHP, run existing PHPUnit/integration tests, inspect generated output, then expand only when the boundary proves useful.

### Gutenberg block developer

Already uses `@wordpress/scripts`, React, `block.json`, and TypeScript. Wants Haxe ADTs, shared contracts, macros, and stronger block metadata validation without losing normal package imports or editor tooling.

**Journey:** scaffold a block module inside the existing npm project, select `wp70-release`, author typed attributes/edit/save, generate strict TSX and `block.json`, bundle through normal WordPress scripts, run editor Playwright tests, and keep the rest of the project in TypeScript.

### Haxe-first product team

Wants to build a substantial WordPress product with shared domain logic, REST contracts, admin UI, blocks, and browser code while deploying normal plugins/themes.

**Journey:** scaffold a solution workspace, declare shared models and schemas, create plugin and block modules, generate native packages, run local WordPress, use watch mode, package signed/reproducible ZIPs, and maintain upgrade routines. The team still debugs PHP and browser output when failures cross those boundaries.

### Agency or theme developer

Builds client-specific themes and site functionality. Values typed templates, design tokens, content schemas, and repeatable packaging, but must interoperate with ordinary plugins and hosting.

**Journey:** start with a typed theme module and bounded HXX templates, generate normal PHP templates and `theme.json`, use existing WordPress template hierarchy, add a companion plugin for content types and REST behavior, and deploy as ordinary theme/plugin ZIPs.

### Plugin ecosystem integrator

Needs typed access to WooCommerce-like or organization-specific PHP/JS APIs. Cannot trust generated guesses.

**Journey:** run a read-only adoption generator against Composer stubs, PHP signatures, PHPDoc, TypeScript declarations, or package exports; review omissions and warnings; commit the contract source; call the generated facade; and maintain exact plugin/package version constraints.

### SDK/compiler contributor

Maintains type catalogs, macros, emitters, profiles, and fixtures. Needs clear separation between generic compiler defects, reusable WordPress profile behavior, and full-port-only machinery.

**Journey:** reduce a failure to the smallest layer, add a generic genes-ts/Reflaxe fixture if appropriate, update profile metadata, run generated-output and real-WordPress tests, and publish exact cross-package pins.

## 7.2 Detailed product journeys

### Journey A: first typed island in a legacy plugin

1. `wphx-sdk adopt php --composer composer.lock --symbols Acme\Pricing\*` inspects metadata without executing plugin code.
2. The tool generates a precise-or-omitted adoption contract and a review report.
3. The developer writes a pure Haxe pricing module using generated DTOs.
4. `wphx-sdk build --profile wp70-release` emits private PHP and a stable public facade.
5. Existing PHP calls the facade using ordinary namespaced PHP.
6. The plugin’s existing tests run unchanged; an SDK integration test verifies input/output codecs and stack trace mapping.
7. The generated ownership manifest prevents future regeneration from overwriting a manually adopted file.

**Exit condition:** the island can be removed by deleting its facade call and generated artifacts; no WordPress runtime replacement is involved.

### Journey B: new static and dynamic block collection

1. Scaffold a collection using the exact embedded Gutenberg package profile.
2. Define typed block names, attributes, supports, examples, deprecations, variations, and styles.
3. Author React editor UI with typed HXX and native Gutenberg components.
4. Static blocks generate `save` TSX and serialization fixtures.
5. Dynamic blocks generate a PHP render adapter and optional frontend Interactivity entrypoint only when declared.
6. The build emits one `block.json` per block, dependencies, `*.asset.php`, translation metadata, source maps, and production bundles.
7. Playwright inserts, edits, saves, reloads, transforms, and validates blocks in a real editor.

**Exit condition:** the built directory can be copied into an ordinary plugin and registered by native WordPress APIs.

### Journey C: typed REST contract shared by server and browser

1. Define request, path, query, response, and error schemas in Haxe.
2. Bind the endpoint to a native WordPress route and explicit permission policy.
3. Generate PHP registration/validation/serialization and a browser client using `@wordpress/api-fetch` or a configured native fetch adapter.
4. Compile-time checks reject a browser call with missing path parameters or the wrong response decoder.
5. Real WordPress tests verify permissions, nonce behavior where applicable, schema exposure, status codes, error shapes, and JSON bytes.

**Exit condition:** generated server and client artifacts are independently inspectable and can interoperate with a non-Haxe caller.

### Journey D: Haxe-first theme with ordinary template hierarchy

1. Declare theme metadata, supports, design tokens, template references, and typed locals.
2. HXX lowers bounded Haxe-owned templates to ordinary PHP/HTML files at expected theme paths.
3. Existing PHP templates remain external and may be referenced through typed `Template.external` contracts.
4. WordPress selects templates using its native hierarchy; there is no SDK runtime dispatcher.
5. Visual, accessibility, and template-hierarchy tests execute in a real site.

**Exit condition:** deactivating the SDK tooling has no effect on the deployed theme because Haxe is a build-time dependency only.

### Journey E: complete solution workspace

1. A root `wordpress-hx.json` lists normal deployable units: one mu-plugin, one plugin, one theme, and several block entries.
2. Shared contracts compile to PHP and browser artifacts; runtime-specific implementations remain in target-specific source sets.
3. Environment profiles configure endpoints, debug flags, and build behavior without embedding secrets.
4. Versioned plugin upgrade routines run through normal activation/update hooks.
5. The build emits independent plugin/theme ZIPs, a deployment manifest, and checksums.
6. Local tooling provisions a vanilla WordPress test site, but production deployment remains hosting/provider-specific.

**Exit condition:** each deployable unit remains recognizable and independently installable; the workspace is an orchestrator, not a proprietary application server.

---

# 8. Goals, measurable outcomes, and explicit non-goals

## 8.1 Product goals

1. **Native deployment:** SDK projects deploy as ordinary WordPress plugins, mu-plugins, themes, block packages, and static assets with no replacement WordPress runtime.
2. **Cross-boundary type safety:** shared schemas and typed references prevent drift among Haxe, PHP, REST, JSON, TS/TSX, `block.json`, and browser clients.
3. **Incremental adoption:** an existing PHP/JS project can add one Haxe-owned island without surrendering ownership of surrounding files.
4. **Native-looking output:** generated public files are readable, stable enough for code review, debuggable, and compatible with normal WordPress tooling.
5. **Exact compatibility claims:** builds identify the exact WordPress/Gutenberg profile used and reject unsupported API access.
6. **Fail-closed generation:** the tool never silently overwrites or deletes unowned or modified files.
7. **Strict unsafe-boundary accounting:** every `Dynamic`, `untyped`, raw target fragment, `any`, `unknown`, private API, or unchecked external contract is visible and reviewable.
8. **Real runtime evidence:** production claims require installed WordPress, editor, browser, PHP, packaging, and update tests—not only snapshots or mocks.
9. **Clean dependency direction:** generic compiler defects are fixed generically; the SDK is independent of full-port implementation internals.
10. **Substantial product capability:** the architecture supports complete solutions without turning into a replacement CMS or proprietary site builder.

## 8.2 MVP measurable outcomes

The MVP release candidate is acceptable only if all of the following are true:

| Outcome | Measure |
|---|---|
| Exact profile | Every artifact manifest records `wp70-release`, WordPress commit `26b68024931348d267b70e2a29910e1320d0094f`, and embedded Gutenberg commit `a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd` |
| Vertical sample | One reference plugin includes hooks, activation/upgrade, custom post type/meta, REST endpoint/client, static block, dynamic block, editor sidebar, i18n, and typed PHP/JS interop |
| Native install | Final ZIP installs and activates in a clean real WordPress 7.0 site without Haxe, Node, or Composer installed on the server |
| Strict Haxe | No unexplained `Dynamic`, `untyped`, broad `cast`, or raw target syntax in maintained SDK/sample Haxe source |
| Generated PHP | `php -l`, WordPress Coding Standards, and the selected PHP static-analysis baseline pass with no unwaived errors |
| Generated TS/TSX | `tsc --strict` passes; no unexplained emitted `any` or `unknown`; package imports resolve only from the selected profile |
| Block behavior | Static markup roundtrips without validation errors; dynamic rendering matches server oracle; editor insert/edit/save/reload tests pass |
| REST behavior | Server schema, permission checks, generated client, and non-Haxe caller fixtures agree on request/response/error shapes |
| Ownership safety | 100% of generated paths appear in the manifest with content hashes; collision, edit, stale-file, interruption, and clean tests fail closed |
| Determinism | Two clean builds from the same source/toolchain produce byte-identical artifacts and package hashes, excluding explicitly signed envelopes |
| Source correlation | Representative PHP and JS failures map to the originating Haxe file and line with documented CLI/browser workflows |
| Packaging | Plugin ZIP, source package, SBOM, checksums, license inventory, and provenance are generated and install-tested |
| Accessibility | Editor extension and frontend example pass automated checks plus documented keyboard/focus assertions |
| Claim separation | Release notes contain separate SDK/vanilla, forward-profile, and full-port compatibility status fields |

## 8.3 Provisional performance budgets

These are starting budgets, not claims of achieved performance. Missing a budget requires measurement, an ADR, and explicit release wording; it must not be silently waived.

- Clean build for the reference plugin: **≤45 seconds** on the pinned CI runner after dependencies are cached.
- Warm incremental server-only rebuild: **≤5 seconds**.
- Warm incremental browser rebuild: **≤8 seconds** without HMR; HMR is not an MVP requirement.
- Static-block production JavaScript: **≤20% gzip overhead** versus the maintained equivalent TypeScript/TSX oracle implementing the same behavior.
- Server-only starter plugin generated PHP/runtime: **≤400 KiB uncompressed**, excluding third-party Composer dependencies and translation catalogs.
- Hook callback overhead: median increase **≤0.5 ms or 10%, whichever is larger**, against a hand-written PHP oracle in the representative benchmark.
- No additional frontend network request is permitted solely to bootstrap an SDK runtime.

These values should be revised after the first feasibility spikes, but the revision must remain numeric.

## 8.4 Non-goals

The following are explicitly outside the MVP and, unless an ADR changes scope, outside the product:

- porting or replacing WordPress Core or Gutenberg runtime implementation;
- supporting “all maintained WordPress versions” at launch;
- abstracting over non-WordPress CMS providers;
- creating a runtime dependency injection container, application server, ORM, router, or template engine;
- automatically translating arbitrary PHP, JavaScript, or TypeScript into production-quality Haxe;
- guaranteeing compatibility with every third-party plugin, theme, block, or hosting provider;
- hiding generated output or telling users never to inspect PHP/JS;
- supporting private/experimental Gutenberg APIs as if they were stable;
- minifying or obfuscating generated PHP by default;
- generating database transactions where the database/runtime does not provide a reliable contract;
- hot-reloading PHP or editor state through a proprietary protocol;
- shipping a visual site builder;
- using SDK scaffolding as evidence that the full port owns corresponding WordPress/Gutenberg code;
- making a Haxe-only deployment environment mandatory.

---

# 9. Compatibility baselines and version profiles

## 9.1 Baseline decision

The MVP MUST support **one exact WordPress baseline first**, not a broad range. The baseline is:

### `wp70-release`

- WordPress source commit: `26b68024931348d267b70e2a29910e1320d0094f`
- WordPress release identity in supplied evidence: `7.0.0` / `7.0-src`
- Embedded Gutenberg source commit: `a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd`
- Distribution claim: `wordpress-7.0-compatible`
- Recorded WordPress minimums: PHP `7.4`, MySQL `5.5.5`
- Forward Gutenberg source inventory: forbidden

### `gutenberg-forward-23.4`

- Gutenberg commit: `98a796c8780c480ef7bcfe03c42302d9564d785c`
- Tag/package baseline: `v23.4.0`
- Distribution claim: none
- WordPress 7.0 compatibility claim: forbidden
- Purpose: opt-in forward API experiments and future compatibility development

A build cannot name both profiles as one undifferentiated compatibility target.

## 9.2 Profile architecture

Each profile is an immutable generated package containing:

- exact upstream commits and artifact hashes;
- PHP function/class/constant signatures used by the SDK;
- hook names and callback signature evidence;
- WordPress feature/version capability flags;
- Gutenberg workspace/package versions and public export inventories;
- stable/experimental/private/deprecated classifications;
- script handle and dependency mapping;
- block metadata schema version and supported keys;
- browser global mappings where required;
- source and artifact provenance;
- compatibility test fixture references.

Proposed Haxe selection:

```hxml
-lib wordpress-hx-sdk
-D wordpress_hx_profile=wp70-release
```

or:

```bash
wphx-sdk build --profile wp70-release
```

The CLI writes the selected profile into every build manifest and refuses an implicit default in CI. Local scaffolds may initially default to `wp70-release`, but the generated project must persist the selection.

## 9.3 Compile-time enforcement

Profile enforcement occurs before target emission:

- Profile-specific externs and typed refs are generated into separate modules.
- Every API declaration records its minimum profile capability.
- Macros accumulate required capabilities from hooks, package imports, metadata keys, blocks, and emitted files.
- A build fails with a source-located diagnostic when a requirement is absent.
- Forward-only imports do not exist in the `wp70-release` package graph; they are not merely runtime guarded.
- Generated asset metadata may reference only handles and dependencies present in the selected profile or explicitly declared third-party contracts.

Representative diagnostic:

```text
WPX1204: @wordpress/content-types is not available in profile wp70-release.
Required by src/acme/editor/ContentPanel.hx:18.
Available in gutenberg-forward-23.4 only.
Build a separate forward artifact or remove the dependency; runtime detection cannot make this package import compatible.
```

## 9.4 Runtime capability detection

Runtime checks are appropriate only when one compiled artifact intentionally interacts with an optional feature whose ABI is compatible with the selected profile, for example a third-party plugin or optional WordPress function.

```haxe
switch OptionalPlugins.inventoryApi() {
  case Available(api): api.reserve(item, quantity);
  case Missing: Notices.warn(Messages.InventoryPluginRequired);
}
```

The generated PHP may use `function_exists`, `class_exists`, `defined`, `method_exists`, plugin-version checks, or registered-script/package checks. The result is a typed capability token. Direct unchecked calls after a boolean check are discouraged because the relationship is easy to lose during refactoring.

Runtime detection MUST NOT be used to smuggle a forward-only package import, incompatible block metadata key, or different TypeScript signature into a `wp70-release` artifact.

## 9.5 Multi-profile projects

A source workspace MAY produce separate artifacts from shared code:

```text
build/wp70-release/acme-plugin.zip
build/gutenberg-forward-23.4/acme-plugin.zip
```

Profile-specific code uses target/profile source sets or conditional compilation. The package filenames, plugin headers, manifests, and support documentation must make the distinction visible. A single ZIP claiming both profiles requires the full test matrix for both and must contain only their common API surface plus valid runtime-guarded optional behavior.

## 9.6 Broader WordPress ranges

A future support range such as WordPress `7.0–7.2` requires:

1. an exact profile for every release used to establish the range;
2. generated API/export diffs;
3. real install/editor/browser tests on every claimed endpoint version and justified intermediate sampling;
4. explicit policy for deprecations and removed APIs;
5. proof that generated artifacts do not depend on the newest profile accidentally;
6. a release-support and security-maintenance commitment.

Until then, wording must be “tested against exact WordPress 7.0 baseline,” not “WordPress 7+.”

## 9.7 PHP, database, Node, and browser compatibility

The MVP profile records rather than assumes its toolchain matrix:

- Haxe: exact pinned compiler, initially `4.3.7` based on the supplied references.
- PHP syntax floor: `7.4`, because that is the recorded WordPress 7.0 minimum; generated code must be linted and executed on that floor before the claim is made.
- Primary PHP lanes: `7.4`, one representative `8.1/8.2` lane, `8.4`, and optionally `8.5` once pinned images and WordPress behavior pass.
- Database: real MySQL and MariaDB lanes for database-dependent tests; no generic transaction claim.
- Node/npm: exact lockfile and CI version; initially align with the proven compiler/tooling environment, then document the WordPress scripts requirement separately.
- Browser: exact Chromium blocking lane for MVP plus production-readiness Firefox and WebKit/Safari-like lanes for user-facing behavior.

The fact that the supplied oracle passed PHP `8.4.7`, MySQL `8.4.10`, and Chromium `149.0.7827.115` is evidence for that environment only, not the full proposed matrix.

---

# 10. Scope matrix: MVP, post-MVP, experimental, and out of scope

Legend: **MVP** is required for the first production-candidate vertical path; **Post-MVP** is intended product scope after the vertical foundation; **Experimental** may ship behind explicit unstable namespaces/flags without compatibility promises; **Out** is rejected or delegated.

| Area | MVP | Post-MVP | Experimental | Out |
|---|---|---|---|---|
| Profiles | Exact `wp70-release`; profile diagnostics | Additional exact WordPress releases and compatibility ranges | `gutenberg-forward-23.4` | Silent mixed baselines |
| Plugin lifecycle | Plugin/mu-plugin bootstrap, activation, deactivation, uninstall, versioned upgrade routine | Multisite-specific lifecycle helpers, update-channel tooling | Network activation orchestration prototypes | Replacement bootstrap runtime |
| Hooks | Typed built-in catalog subset, custom generated contracts, priority/arity validation | Broad catalog generation, third-party hook packages | Dynamic hook-pattern contracts with constrained interpolation | Generic event bus hiding WordPress semantics |
| Content | Custom post type, metadata, basic taxonomy registration | Users, roles, capabilities, settings, options, richer taxonomy/content schemas | Typed field-framework adapters | Proprietary content model runtime |
| REST | Typed endpoints, permissions, schemas, generated browser client | Batch endpoints, pagination helpers, richer OpenAPI export | Generated clients for other Haxe targets | Replacement router/server |
| Data access | Typed IDs and bounded post/meta queries used by reference plugin | Wider `WP_Query`, `$wpdb`, cache, transaction capability detection | Query macro experiments | ORM pretending WordPress is relationally uniform |
| Admin | Menu/page registration and one typed HXX page/sidebar example | Settings screens, forms, notices, list tables, AJAX, media | DataViews/admin-ui profile experiments | Proprietary admin application shell |
| CLI/cron | Basic upgrade task invoked through plugin lifecycle | WP-CLI commands, cron/scheduled events | Long-running/background orchestration helpers | New job runtime |
| Themes | External template references; one bounded HXX template proof | Haxe-first theme, template hierarchy, parts, patterns, `theme.json`, design tokens | Block-theme generation experiments | Runtime theme engine |
| Blocks | Static and dynamic blocks, attributes, deprecations, serialization, InnerBlocks, basic supports | Variations, styles, transforms, bindings, patterns, richer supports | Forward-only block APIs | Reimplementation of block editor/runtime |
| Editor extensions | One plugin/sidebar/SlotFill, native components/hooks | Commands, formats, notices, preferences, filters, panels | Private/experimental components behind unsafe profile | Monkey-patching internals |
| Data stores | Typed custom store plus selected native selectors/actions | Resolvers, controls, entity records, subscriptions, generated store adoption | Complex inference from JS source | Replacement state manager |
| Interactivity API | Capability inventory and no false support claim | Typed directives, stores/actions, SSR/hydration examples | Forward-profile behavior while APIs evolve | Parallel frontend runtime |
| Interop | PHP extern/adoption generator subset; JS/TS imports; public Haxe exports | Composer package catalogs, richer PHPDoc/stub shapes, dts adoption | ts2hx-assisted migration with loss reports | Arbitrary lossless source translation claim |
| HXX | Compile-time typed React HXX and one bounded PHP/HTML template path | Theme/admin component library and typed partials | Advanced mixed segment syntax | Runtime template engine |
| Solution workspace | One project can coordinate plugin + blocks + shared contracts | Multiple plugins/themes, env profiles, deploy manifests, update workflows | Provider-specific deploy adapters | Proprietary site builder/CMS |
| Tooling | Scaffold, build, watch, check, inspect, clean, package, doctor | Upgrade assistant, compatibility diff, API browser | HMR where normal tooling permits | Mandatory cloud service |
| Testing | Unit, generated snapshots, real WP/PHPUnit, Playwright, packaging | Visual matrix, multisite, broader browser/DB/version matrices | Differential fuzzing | Mocks as substitute for installed WP |

## 10.1 MVP cut line

The MVP does **not** mean “typed coverage for every item in the capability inventory.” It means the architecture has proven the riskiest representative boundaries:

- public PHP bootstrap and callbacks;
- strict TSX package integration;
- shared REST/schema generation;
- block metadata and serialization;
- a server-rendered block;
- editor extension and data-store interaction;
- PHP and JS interoperability;
- fail-closed artifact ownership;
- real vanilla WordPress installation and packaging.

A capability may be useful and still remain out of the MVP if it does not strengthen one of those proof points.


---

# 11. Proposed repository and package topology

## 11.1 Monorepo recommendation

Use a monorepo because the first stable product contract spans Haxe APIs, profile data, macros, a PHP profile, genes-ts integration, CLI behavior, ownership manifests, examples, and real WordPress tests. Splitting these before the cross-package contracts stabilize would create release and compatibility work without producing user value.

Packages should be **separately publishable but lockstep-versioned** through at least `1.0`. A release train publishes the same SDK version for every public package that changed or is required by the distribution manifest. Independent SemVer is a post-`1.0` decision contingent on evidence that packages can evolve independently without matrix explosion.

## 11.2 Proposed repository tree

```text
wordpress-hx-sdk/
├── AGENTS.md
├── README.md
├── LICENSES/
├── SECURITY.md
├── SUPPORT.md
├── GOVERNANCE.md
├── CHANGELOG.md
├── haxelib.json                  # umbrella/dev package only; not the sole release artifact
├── package.json
├── lix.scope.json
├── yarn.lock or package-lock.json
├── wordpress-hx.repo.json       # repository build/release configuration
├── docs/
│   ├── product/
│   │   └── product-requirements.md
│   ├── adr/
│   ├── architecture/
│   ├── guides/
│   ├── reference/
│   ├── compatibility/
│   ├── security/
│   └── generated/               # generated API docs, never hand edited
├── packages/
│   ├── core/                    # wordpress-hx-core (Haxelib)
│   │   ├── src/wordpress/hx/core/
│   │   └── haxelib.json
│   ├── profiles/                # generated exact profile catalogs
│   │   ├── src/wordpress/hx/profile/wp70/
│   │   ├── src/wordpress/hx/profile/gutenbergForward234/
│   │   └── data/*.json
│   ├── contracts/               # schemas, codecs, shared model generation
│   ├── server/                  # hooks, lifecycle, content, REST, admin, i18n
│   ├── gutenberg/               # blocks, editor, data, React/package externs
│   ├── hxx/                     # compile-time markup parser adapters/lowerers
│   ├── build/                   # macros, semantic plan, emitters, manifests
│   ├── testing/                 # Haxe/PHP/WP/browser test helpers
│   ├── interop-php/             # PHP metadata readers and extern/facade model
│   ├── interop-js/              # package/type adoption and export retention helpers
│   └── cli/                     # @wordpress-hx/cli npm package and binary
├── compiler/
│   └── wordpress-php-profile/   # WordPress-specific profile over external generic PHP core
├── profiles/
│   ├── wp70-release/
│   │   ├── profile.json
│   │   ├── php-api.json
│   │   ├── hooks.json
│   │   ├── gutenberg-packages.json
│   │   ├── script-handles.json
│   │   └── checksums.json
│   └── gutenberg-forward-23.4/
├── schemas/
│   ├── project.schema.json
│   ├── generated-files.schema.json
│   ├── profile.schema.json
│   ├── adoption-contract.schema.json
│   └── evidence.schema.json
├── tools/
│   ├── profile-generator/
│   ├── php-adopter/
│   ├── ts-adopter/
│   ├── artifact-owner/
│   ├── package-builder/
│   └── source-map-tools/
├── examples/
│   ├── 01-existing-plugin-island/
│   ├── 02-haxe-plugin/
│   ├── 03-existing-gutenberg-block/
│   ├── 04-block-collection/
│   ├── 05-haxe-theme/
│   ├── 06-complete-solution/
│   └── compatibility-fixture/
├── fixtures/
│   ├── php-emission/
│   ├── hooks/
│   ├── rest/
│   ├── blocks/
│   ├── hxx/
│   ├── interop/
│   ├── ownership/
│   └── negative/
├── test/
│   ├── unit/
│   ├── compiler/
│   ├── generated-php/
│   ├── generated-ts/
│   ├── wordpress-phpunit/
│   ├── wordpress-e2e/
│   ├── playwright/
│   ├── accessibility/
│   ├── visual/
│   ├── packaging/
│   └── downstream/
├── docker/
│   ├── wordpress/
│   ├── php/
│   ├── mysql/
│   └── mariadb/
├── manifests/
│   ├── toolchain.lock.json
│   ├── upstream.lock.json
│   ├── release/
│   └── evidence/
└── .github/workflows/
```

## 11.3 Public package responsibilities

| Package | Responsibility | Runtime presence |
|---|---|---|
| `wordpress-hx-core` | Branded identifiers, result/error types, capability tokens, profile selection, shared annotations, diagnostics primitives | Compile time and generated value shapes only |
| `wordpress-hx-profiles` | Exact generated API/package/hook catalogs and classification metadata | Compile time only |
| `wordpress-hx-contracts` | Typed schemas, validation, sanitization descriptors, JSON codecs, client/server contract generation | Generated PHP/JS codec code as needed; no independent service runtime |
| `wordpress-hx-server` | WordPress PHP externs and thin APIs for hooks, lifecycle, REST, content, security, admin, i18n, assets | Calls native WordPress APIs through generated PHP |
| `wordpress-hx-gutenberg` | Blocks, React/Gutenberg components, data stores, editor extensions, Interactivity contracts, package imports | Calls native Gutenberg/React/WordPress packages |
| `wordpress-hx-hxx` | Parser integration, typed tag/component resolution, server/browser markup ASTs, output-context checking | Compile time only; generated PHP/HTML or TSX remains |
| `wordpress-hx-build` | Macro collection, semantic plan, emitters, dependency extraction integration, artifact manifests, source correlation | Build time only |
| `wordpress-hx-testing` | Fixtures, typed test helpers, WordPress install harness adapters, generated contract assertions | Dev/test only |
| `@wordpress-hx/cli` | Scaffolding, build orchestration, watch, check, inspect, package, adoption, doctor, compatibility diagnostics | Dev/build only |

`wordpress-hx-interop-php` and `wordpress-hx-interop-js` may begin as internal modules of `build`/`cli`. Promote them to public packages only when third-party consumers need their contract formats independently.

## 11.4 External compiler dependencies

```text
reflaxe.php-native (generic, separate project)
          ▲
          │ pinned public compiler API
compiler/wordpress-php-profile
          ▲
          │
wordpress-hx-build ─────────► wordpress-hx-server

reflaxe + Haxe 4.3.7
          ▲
          └── genes-ts ─────► wordpress-hx-gutenberg / browser output

`tink_hxx` concepts/parser AST
          ▲
          └── wordpress-hx-hxx adapters and WordPress-specific typed tags
```

The SDK must not fork generic compiler logic into WordPress namespaces merely to move faster. A short-lived prototype may live under `fixtures/` or an explicitly temporary compiler experiment, but release code must depend on a versioned generic compiler surface.

## 11.5 User project topology

A complete solution should use normal deployable units rather than one giant generated plugin:

```text
acme-site/
├── wordpress-hx.json
├── haxe_libraries/
├── src/
│   ├── shared/                  # DTOs, enums, validation, pure domain logic
│   ├── server/                  # WordPress/PHP-specific logic
│   └── browser/                 # Gutenberg/browser-specific logic
├── modules/
│   ├── acme-core-plugin/
│   │   ├── plugin.hx
│   │   └── resources/
│   ├── acme-mu-bootstrap/
│   ├── acme-theme/
│   └── blocks/
│       ├── card/
│       └── product-grid/
├── tests/
└── build/                       # generated, manifest-owned
    ├── dev/
    ├── packages/
    └── _GeneratedFiles.json
```

Each module declares its native WordPress identity and output package. Cross-module dependencies are explicit and acyclic. A theme may depend on a public contract from a companion plugin, but the generated theme cannot silently load plugin implementation files.

## 11.6 Naming policy

Use native names at boundaries and Haxe-friendly names internally:

- Haxe package root: `wordpress.hx.*` until naming ADR resolves final namespace.
- Generated PHP vendor namespace: project-controlled, e.g. `Acme\Books\Generated`.
- Public PHP facades use stable declared names, never compiler-mangled names.
- WordPress slugs and handles use lowercase kebab/snake conventions as required by upstream APIs.
- Generated JS packages use normal ESM exports and project-controlled package names.
- Avoid `Hx` suffixes on every public symbol. The artifact should communicate product/domain purpose, not compiler implementation.

---

# 12. Dependency-direction rules

## 12.1 Layering

```text
pure shared domain
      │
      ├──► contracts/schema primitives
      │
      ├──► server WordPress APIs ──► public WordPress PHP contracts
      │
      └──► browser Gutenberg APIs ─► public Gutenberg/React packages

build/macros inspect all authoring layers but are never imported at runtime.
profiles feed compile-time validation but never import application code.
```

### Allowed dependencies

- `core` → Haxe standard library only.
- `profiles` → `core` data types and generated immutable data.
- `contracts` → `core`; no WordPress/Gutenberg runtime dependency for pure schemas.
- `server` → `core`, `profiles`, `contracts`, native PHP/WordPress externs.
- `gutenberg` → `core`, `profiles`, `contracts`, genes-ts-compatible JS/React externs.
- `hxx` → `core`, typed markup parser dependencies, optional server/browser tag packages.
- `build` → all authoring packages for compile-time inspection; external generic compiler APIs.
- `testing` → public packages plus test harnesses.
- `cli` → schemas, build tools, package manager interfaces; it must invoke compilers as pinned tools rather than importing project source through undocumented paths.

### Forbidden dependencies

- Shared domain code → WordPress PHP globals, React, DOM, or editor packages.
- SDK packages → full-port implementation internals.
- Generic compiler package → WordPress-specific hook names, plugin classes, or block semantics.
- WordPress profile → application-specific symbols.
- Generated runtime code → SDK CLI/build packages.
- Server code → browser-only modules or vice versa, except shared contracts.
- Stable package → experimental/private API package without an explicit unstable dependency and release classification.

## 12.2 Generic compiler issue routing

A failure belongs in genes-ts, Haxe PHP, Reflaxe, or another generic compiler project when it can be described without mentioning WordPress semantics. Examples:

- incorrect TS union or generic emission;
- bad TSX component prop typing;
- ESM live-binding or side-effect import behavior;
- PHP native array mutation semantics;
- PHP closure/callable lowering;
- by-reference parameter printing;
- source-map line attribution;
- deterministic file ordering;
- generic HXX parser diagnostics.

The SDK issue should contain a minimized upstream fixture reference and remain blocked on an exact compiler release. It must not add `if wordpress` branches to a generic compiler.

## 12.3 SDK compiler/profile responsibility

The SDK owns behavior that is reusable for ordinary WordPress extensions:

- plugin and theme headers;
- WordPress bootstrap and direct-file guards;
- hook registration and callback adapters;
- REST/block registration;
- WordPress native identifiers and capability catalogs;
- `block.json`, `theme.json`, asset, translation, and script-handle metadata;
- PHP/HTML template file shape;
- WordPress coding-standard formatting;
- project/package layout;
- profile-specific API availability.

## 12.4 Full-port-only responsibility

The full port exclusively owns:

- replacing WordPress Core files at original distribution paths;
- preserving Core include/load order and top-level side effects across the whole distribution;
- Core-wide public ABI inventories and linker segments;
- conditional declaration and caller-scope parity for existing Core files;
- ownership progression from upstream bridge to Haxe implementation;
- final WordPress distribution assembly and parity claims.

The SDK may learn from these mechanisms but must not import them as a hidden runtime dependency.

## 12.5 Exact pins and receipts

Every cross-project dependency must record:

- package/repository identity;
- immutable version or commit;
- expected tree/package hash;
- compatibility profile;
- artifact manifest schema version;
- test receipt IDs;
- known dirty-state observations, excluded from the pin;
- upgrade owner and rollback version.

Floating sibling checkouts are forbidden in release builds.

---

# 13. Detailed WordPress SDK capability model

## 13.1 Design model

The server SDK should expose three layers, all visibly native-shaped:

1. **Generated extern layer:** close representations of WordPress functions/classes/constants and selected native PHP facilities.
2. **Typed contract layer:** branded IDs, callback signatures, schemas, safe output types, result/error wrappers, and capability tokens.
3. **Authoring layer:** concise registration builders and macros that generate normal WordPress calls and metadata.

Users may drop from the authoring layer to externs without leaving the typed system. Raw PHP is the last layer, not the first escape route.

## 13.2 Hooks and filters

### Requirements

- Built-in hook references MUST encode action versus filter, ordered argument types, return type, and maximum documented arguments.
- `accepted_args` SHOULD be inferred from the callback type; an explicit smaller value is allowed only through a typed truncation helper.
- Priority MUST be a branded integer with common constants (`Earliest`, `Default`, `Late`) and no false claim that priorities are a closed enum.
- Hook removal MUST use a stable callback identity; anonymous callbacks that cannot be removed should be explicitly marked `PermanentListener`.
- Dynamic hook names MUST use typed pattern constructors generated from source evidence, not arbitrary concatenation.
- Third-party/custom hooks MUST be declared through a versioned adoption contract or typed project declaration.
- The generated PHP MUST use ordinary `add_action`, `add_filter`, `remove_action`, and `remove_filter` calls.

### Proposed API shape

```haxe
WpActions.Init.listen(PluginBoot.register, Priority.Default);
WpFilters.TheContent.map(ContentFilters.addReadingTime, Priority.Late);
AcmeHooks.InvoicePaid.listen(Billing.onInvoicePaid);
```

The compiler rejects a `Void` action callback used for a filter requiring a returned content value and rejects an inferred arity greater than the hook contract.

### Scope

- MVP: representative built-in catalog, custom declarative hooks, priority/arity/removal behavior.
- Post-MVP: broad generated catalog and dynamic hook patterns.
- Experimental: inference from third-party source where reliable documentation is incomplete.

## 13.3 Plugin and mu-plugin bootstrapping

A typed `PluginManifest` or `MuPluginManifest` declares:

- plugin name, slug, version, description, author URI, license, text domain;
- required WordPress/PHP versions;
- network-only status;
- bootstrap class/function;
- activation, deactivation, uninstall, and upgrade handlers;
- assets, blocks, REST modules, CLI modules, and dependencies;
- profile and generated namespace.

The public PHP emitter generates the root plugin file with exact header comments, an `ABSPATH` guard, deterministic autoload inclusion, and a stable boot call. Plugin headers are not smuggled through raw PHP strings in application code.

Mu-plugins generate the expected root file and optional subdirectory loader. The SDK must document mu-plugin activation differences rather than pretending normal activation hooks execute.

## 13.4 Activation, deactivation, uninstall, and upgrades

- Lifecycle callbacks are typed and registered through native APIs.
- Activation code MUST be idempotent or explicitly guarded.
- Network activation receives a typed context and must be tested separately.
- Uninstall behavior MUST be declared as one of `PreserveData`, `DeleteOwnedData`, or a custom reviewed policy.
- Versioned upgrade routines use a monotonic plugin schema version stored in a declared option; they are not a general migration framework.
- Upgrade steps MUST be individually retryable or transactionally bounded where the database supports it.
- The generated plugin MUST fail activation with an actionable admin error when PHP/WordPress/profile requirements are unmet.

## 13.5 REST routes, schemas, permissions, and clients

A REST endpoint contract contains:

- HTTP method;
- typed namespace and route pattern;
- path, query, body, and header schemas;
- permission policy/callback;
- success response schema and status;
- typed error variants and status mapping;
- cache and nonce expectations where applicable;
- browser client exposure policy.

Generation produces:

- native `register_rest_route` calls;
- WordPress argument schema arrays;
- sanitization and validation callbacks;
- request decoding into a typed value;
- response encoding to native `WP_REST_Response`/`WP_Error` shapes;
- strict browser client functions and codecs;
- contract tests and optional documentation output.

Permission callbacks are never optional by default. A public endpoint requires an explicit `Public` policy and security-review annotation. `__return_true` must not appear merely because the developer omitted a decision.

## 13.6 WP-CLI

Post-MVP support should expose typed command classes with:

- command/name references;
- positional and associative argument schemas;
- synopsis/help generation;
- exit/error handling;
- progress and output adapters;
- profile/runtime availability detection.

Generated code registers through ordinary `WP_CLI::add_command`. The SDK must not emulate WP-CLI when it is absent.

## 13.7 Cron and scheduled events

Post-MVP support should provide:

- typed schedule names and recurrence descriptors;
- event payload schemas;
- idempotent scheduling helpers;
- unscheduling on deactivation where declared;
- duplicate-event diagnostics;
- real cron execution tests plus direct callback tests.

The API must preserve the limitations of WP-Cron. It must not market at-least-once, exact timing, distributed locks, or durable background processing unless an external provider contract supplies those semantics.

## 13.8 Post types, taxonomies, metadata, options, and settings

### Content type declarations

Typed declarations generate native registration arrays and references:

- `PostTypeRef<TRecord>`;
- `TaxonomyRef<TTerm>`;
- `MetaKey<TValue, TObject>`;
- support and capability mappings;
- REST exposure and schema;
- labels driven by typed message keys;
- rewrite/query settings without hiding their native meaning.

MVP includes one custom post type, selected post meta, and a taxonomy path sufficient to test registration, persistence, REST, and editor behavior.

### Options and settings

- `OptionKey<T>` couples storage key, schema, default, autoload policy, and sanitization.
- Settings registration binds capability, section, field, schema, and render component.
- Reads distinguish missing value, stored false/zero/empty, and decode failure.
- Network/site options use different branded types.
- Arbitrary serialized object storage is discouraged; versioned codecs are required.

### Users, roles, and capabilities

- Built-in capabilities are profile-generated refs.
- Custom capabilities are declared once and used by role setup, permission checks, REST policies, and UI visibility.
- Capability checks return typed authorization evidence only for the current request/user context; tokens must not be serializable or cached across requests.
- Role mutation is upgrade/lifecycle behavior, not a module-load side effect.

## 13.9 Nonces, sanitization, validation, escaping, and output safety

The SDK must distinguish these operations rather than use a generic “safe” type:

```text
Untrusted<T>
   ├── validate ──► Validated<T>
   ├── sanitize ──► Sanitized<T>       (possibly lossy)
   └── reject

Plain text ──► EscapedText
URL        ──► EscapedUrl
attribute  ──► EscapedAttribute
HTML       ──► KsesSafeHtml / TrustedHtml
JS data    ──► JsonEncoded<T>
```

Requirements:

- Nonce actions and fields are branded and paired.
- Verification and capability checks are separate; a valid nonce is not authorization.
- Output-context types are not interchangeable.
- `TrustedHtml` construction is restricted to audited constructors or generated known-safe templates.
- Schema declarations choose validation and sanitization deliberately; silently sanitizing invalid security-sensitive input is discouraged.
- Generated target code uses native WordPress escaping/sanitization functions where their semantics match the contract.
- HXX performs context-aware lowering and rejects unsafe interpolation.

## 13.10 `WP_Query`, database access, and transactions

### `WP_Query`

Provide typed query argument builders for high-value closed subsets:

- post type/status/author/IDs;
- pagination and ordering;
- tax/meta/date query ASTs;
- selected fields and result wrappers;
- cache/count flags;
- typed result IDs or post records.

The builder must emit ordinary WordPress argument arrays and preserve documented edge cases. An escape hatch exposes the native argument object with a warning, not a generic query DSL pretending full coverage.

### `$wpdb`

Post-MVP support should include:

- typed table refs and prefix handling;
- prepared placeholders coupled to argument types;
- result-row decoders;
- write helpers with explicit formats;
- `WP_Error`/false/result distinctions;
- no raw interpolation in SQL helpers;
- explicit raw SQL boundary with review metadata.

### Transactions

WordPress has no universal transaction abstraction. The SDK may expose a capability-gated helper only when the active database/engine and code path support it. The default API must not imply that surrounding WordPress code participates in the transaction.

## 13.11 Admin menus, screens, forms, notices, list tables, and AJAX

### MVP

- typed menu/page/screen IDs;
- capability-gated page registration;
- one HXX-authored admin page or panel;
- typed form schema, nonce, validation, and escaped rendering;
- admin notice API with message keys and dismissibility contract.

### Post-MVP

- settings sections/fields;
- list table column/row/action types;
- bulk actions and pagination;
- AJAX actions with separate authenticated/unauthenticated contracts;
- media modal integrations;
- Screen Options and contextual help where stable.

Generated pages must participate in normal WordPress admin hooks and screen lifecycle. The SDK should not mount a proprietary SPA shell unless the project explicitly authors one with normal WordPress assets and accessibility behavior.

## 13.12 Media, uploads, HTTP, mail, feeds, shortcodes, widgets, and template hooks

These are valid post-MVP domains with target-shaped APIs:

| Domain | Typed value | Important preserved semantics |
|---|---|---|
| Media/uploads | `AttachmentId`, upload result/error, MIME policy | WordPress upload checks, metadata generation, filesystem errors |
| HTTP | request/response schemas, headers, timeout, error union | `wp_remote_*`, transport behavior, `WP_Error`, redirects |
| Mail | recipient/address types, headers, attachments | `wp_mail` behavior and server mail configuration remain authoritative |
| Feeds | feed hook/format refs, escaped output | output buffering/content types and feed lifecycle |
| Shortcodes | attribute schema and returned safe HTML | global shortcode registry and parsing quirks |
| Widgets | typed settings schema and render/form/update contracts | native widget lifecycle; block widgets where relevant |
| Template hooks | typed hook refs and output context | theme/plugin load order and native template hierarchy |

None should be included merely to increase API count. Each needs one real integration fixture and an explicit failure model.

## 13.13 Theme setup, templates, parts, patterns, `theme.json`, and design tokens

Post-MVP theme support includes:

- typed theme manifest and headers;
- `after_setup_theme` declarations;
- supports, image sizes, menus, sidebars, styles/scripts;
- template and template-part refs tied to actual generated/external files;
- block patterns and categories;
- typed `theme.json` schema bound to the selected profile;
- generated design token access for Haxe/TSX/CSS/PHP templates;
- native template hierarchy tests.

The SDK may generate PHP templates and block-theme HTML templates. It must not insert a runtime template resolver ahead of WordPress.

## 13.14 Internationalization

- Message IDs are declared as typed keys with default text, context, plural form, placeholders, translator comments, and text domain.
- Placeholders are schema-checked; missing or extra substitutions fail compilation.
- Emitters produce literal native gettext calls that WordPress extraction tooling can recognize, or a deterministic extraction surrogate with byte-linked provenance.
- Browser bundles use normal `@wordpress/i18n` calls and `wp_set_script_translations` metadata.
- Dynamic message IDs are rejected except at an explicit external translation boundary.
- Generated POT, Jed JSON, and PHP translation metadata are native artifacts recorded in the manifest.

## 13.15 PHP plugin interoperability

Adoption input precedence should be:

1. authoritative PHP stubs/signature metadata shipped by the provider;
2. native PHP reflection executed in an isolated, explicitly approved environment only when loading code is safe and deterministic;
3. Composer package metadata and source signatures;
4. PHPDoc with a known parser and confidence rules;
5. curated handwritten contract.

The default generator MUST NOT execute application/plugin code. It is precise-or-omitted:

- supported signatures generate typed externs/facades;
- ambiguous unions, magic methods, dynamic properties, callbacks, references, or conditional symbols generate review diagnostics;
- unsupported symbols are omitted, not typed as broad `Dynamic`;
- generated contracts include provider package/version constraints and source hashes;
- optional plugin availability is represented through a capability token;
- interop tests call the real provider when licensing and CI permit.

---

# 14. Detailed Gutenberg SDK capability model

## 14.1 Design model

The Gutenberg SDK should expose native package concepts directly. `BlockType`, `BlockEditProps`, `BlockSaveProps`, `registerBlockType`, `useSelect`, `useDispatch`, `PluginDocumentSettingPanel`, `InnerBlocks`, `RichText`, and related concepts should be recognizable in Haxe and generated TSX.

The authoring layer adds value through:

- typed block metadata and attribute schemas;
- profile-filtered package exports;
- typed HXX/React props and events;
- generated server/client contracts;
- serialization/deprecation fixtures;
- asset/dependency/translation generation;
- safe extension classification.

## 14.2 Static blocks from scratch

A static block declaration includes:

- typed block name and API version;
- title/category/icon/keywords/message keys;
- attribute schema and defaults;
- supports and context contracts;
- parent/ancestor/allowed child constraints;
- edit and save components;
- examples;
- deprecations and migrations;
- variations/styles/transforms where supported;
- assets and translation domain.

The build emits:

- `block.json`;
- strict TSX/TS or JS modules;
- editor/style CSS as declared;
- dependencies and `*.asset.php`;
- translation metadata;
- serialization snapshots and block-parser roundtrip fixtures.

Saved markup is a public compatibility contract. A Haxe refactor that changes markup must add a deprecation/migration or intentionally declare a breaking block change.

## 14.3 Dynamic/server-rendered blocks

A dynamic block separates:

- editor preview/edit component;
- typed attributes and context;
- optional saved fallback markup;
- server render function;
- frontend view/interactivity entrypoint;
- cache behavior and data dependencies.

The PHP profile emits a native render callback registered through `register_block_type`. It decodes attributes, obtains native block/context values, calls Haxe-owned implementation code, and returns an explicitly safe HTML type. The public adapter remains a small readable PHP function or static method.

Dynamic rendering MUST be tested against direct WordPress rendering, REST/editor preview where used, frontend output, escaping, and cache/context behavior.

## 14.4 `block.json` generation

`block.json` is generated from a typed schema tied to the selected profile. Requirements:

- unknown keys fail compilation unless an experimental profile explicitly defines them;
- required fields and allowed value enums are checked;
- attribute schemas are derived from or checked against Haxe types;
- asset paths must resolve to manifest-owned files;
- script/module/view handles and file references are profile-aware;
- server and client registration metadata must match;
- key order and formatting are deterministic;
- the generated file remains valid input to normal WordPress block tooling.

Hand-editing generated `block.json` is forbidden. Existing hand-owned files can be adopted as external contracts or converted through a generator that produces a reviewed Haxe declaration before ownership changes.

## 14.5 Attributes, defaults, deprecations, migrations, serialization, and validation

- Every attribute has an explicit codec and source shape.
- Defaults are typechecked and serializable.
- Missing versus `null` versus absent must be represented deliberately.
- Deprecated versions are ordered, immutable compatibility records.
- Migration functions are pure and covered by fixtures.
- `isEligible`/equivalent logic is typed and tested when used.
- Static blocks maintain normalized and byte-sensitive serialization fixtures where upstream behavior requires it.
- The SDK invokes native Gutenberg parsing/validation in real tests; a Haxe-only serializer is not sufficient evidence.
- Attribute schemas shared with PHP use one canonical declaration and target-specific codecs.

## 14.6 Edit/save/render boundaries

Types must make boundary differences visible:

```text
EditProps<A>    includes live attributes, setters, client ID, selection/editor context
SaveProps<A>    includes serializable attributes and save-time block props only
RenderContext<A> includes decoded attributes, WP_Block/context, request/user data as declared
```

An edit-only value cannot leak into saved markup. Server-only services cannot be imported into browser code. `save` must remain deterministic and side-effect free according to Gutenberg expectations.

## 14.7 InnerBlocks and nested contracts

Provide typed wrappers for:

- allowed block refs;
- template tuples and default attributes;
- template locking;
- parent/ancestor relationships;
- child block context;
- controlled versus uncontrolled inner block APIs;
- `useInnerBlocksProps` and save counterparts.

The SDK should validate declared child block names against the selected profile/project graph and generate editor tests for insertion constraints. It must not invent a separate tree model.

## 14.8 Variations, styles, transforms, bindings, patterns, categories, and supports

| Capability | Requirement | Priority |
|---|---|---|
| Supports | Typed profile-specific schema; generated metadata; edit/save behavior fixtures | MVP subset |
| Styles | Typed name/label/default; native registration or metadata | Post-MVP early |
| Variations | Typed attributes/scope/isActive; version/profile checks | Post-MVP |
| Transforms | Typed source/target block contracts; attribute migration; no unsafe casts | Post-MVP |
| Bindings | Profile-specific source/argument types; server/client consistency | Post-MVP/experimental depending upstream maturity |
| Patterns | Typed names/categories/content refs; generated PHP/JSON registration | Post-MVP |
| Categories | Native category registration and message keys | Post-MVP |
| Deprecations | Immutable typed compatibility records | MVP |

A feature being present in `gutenberg-forward-23.4` does not make it available to `wp70-release`. Generated catalogs decide availability.

## 14.9 Editor filters and modification of existing blocks

The SDK should support public filter mechanisms with typed contracts for known hooks. Safe modification means:

- the filter is public/stable in the selected profile;
- the callback input/output shape is known;
- the modification preserves upstream registration and behavior except for the declared change;
- unregister/re-register sequences are avoided unless upstream requires them;
- dependency/load ordering is explicit;
- editor tests include the unmodified baseline and extension behavior.

Private state mutation, package-internal imports, prototype changes, and DOM scraping are unsafe monkey-patching and require an experimental/unsafe module plus a removal condition. They are not part of production support.

## 14.10 Editor plugins, sidebars, panels, commands, notices, preferences, and SlotFill

### MVP

- native editor plugin registration;
- one document or block sidebar/panel using public SlotFill/component APIs;
- typed plugin name, icon, render component, capability/data requirements;
- focus/keyboard/accessibility tests;
- clean unregister behavior for development/tests.

### Post-MVP

- commands and command palettes;
- notices;
- preferences and persistence;
- plugin areas and additional SlotFills;
- publish/pre-publish panels;
- editor settings filters;
- DataViews/admin UI where profile-stable.

The API should import normal `@wordpress/plugins`, `@wordpress/edit-post` or successor packages, `@wordpress/components`, and related modules. It must not recreate SlotFill.

## 14.11 Rich-text formats

Post-MVP support should type:

- format name/title/tag/class/attributes;
- edit component props;
- apply/remove/toggle helpers;
- keyboard shortcuts;
- active object/selection behavior;
- serialization fixtures;
- unregister and compatibility behavior.

The SDK must preserve `@wordpress/rich-text` semantics and test paste, selection, undo/redo, keyboard, and saved markup.

## 14.12 Data stores, selectors, actions, resolvers, controls, subscriptions, and entity records

### Native store consumption

Profile-generated store contracts expose selected stable selectors/actions with typed arguments and return values. `useSelect` and `useDispatch` wrappers preserve React dependency semantics rather than hiding them.

### Custom stores

A typed store declaration includes:

- branded store key;
- state schema;
- reducer/action variants;
- selectors;
- actions;
- optional resolvers/controls;
- registry dependencies;
- persistence policy if any.

The build emits normal `createReduxStore`/`register` or the profile-correct APIs. Public TS modules remain usable from non-Haxe JavaScript.

### Entity records

Entity record typing is valuable but inherently open-ended. The SDK should generate record types from registered content/meta schemas and preserve loading/error/resolution states. It must not pretend every plugin-added field is statically known without an adoption contract.

### Priority

- MVP: one custom store, selected native selectors/actions, `useSelect`/`useDispatch` typing.
- Post-MVP: resolvers, controls, subscriptions, entity records, registry plugins.
- Experimental: automated inference from implementation source.

## 14.13 React components, hooks, refs, context, events, and accessibility

- genes-ts output must use normal React imports or WordPress element package mappings required by the profile.
- HXX component resolution must validate props, required children, refs, event types, and generic component parameters.
- Hook wrappers must preserve Rules of Hooks and dependency array semantics; the SDK must not implement its own hook runtime.
- Native components from `@wordpress/components`, block editor, editor, and related packages should be profile-generated or curated with exact versions.
- Refs and DOM event types must not degrade to `Dynamic`/`any` globally.
- Accessibility props and labels should use typed message keys, but compile-time typing cannot replace runtime accessibility tests.
- Source maps must map browser errors through bundling to Haxe source where tooling allows.

## 14.14 Interactivity API

The Interactivity API deserves a dedicated package only after a bounded end-to-end gate. Intended support includes:

- typed store namespace;
- state/context schemas;
- action and callback signatures;
- directive names and value grammar;
- server-rendered directive attributes;
- generated frontend module registration;
- hydration/state serialization codecs;
- derived state and async action behavior where profile-supported;
- navigation/router integration only through public APIs.

MVP should inventory and classify the surface but not claim full support. Post-MVP production support requires server render, hydration, navigation, concurrency, accessibility, and no-JS fallback tests on the exact profile.

## 14.15 Package imports, globals, dependencies, handles, and asset metadata

The browser build supports both source imports and WordPress externalization:

- Haxe imports map to exact profile-approved `@wordpress/*` exports.
- genes-ts emits strict ESM TS/TSX.
- normal WordPress dependency-extraction/build tooling decides bundled versus external packages according to project policy.
- generated `*.asset.php` contains dependency handles and version hashes matching the final bundle.
- `wp.*` globals are supported only through generated typed mappings for legacy/non-module contexts.
- script/module handles are branded and checked against registration/enqueue declarations.
- localization and script translations use native APIs.
- side-effect imports and package initialization are preserved and tested.
- development and production outputs share the same semantic imports; minification must not change dependency metadata.

## 14.16 genes-ts requirements

For SDK release use, genes-ts must provide:

- split ESM TypeScript/TSX output;
- strict typechecking;
- stable public export retention;
- React/TSX component and hook behavior for the used corpus;
- deterministic output transaction behavior;
- source maps;
- side-effect import correctness;
- package shape tests;
- classic Genes JS differential output for selected fixtures;
- exact pinned release/commit and full upstream CI receipt.

A WordPress-specific failure must first be reduced to a generic fixture. The SDK may add package externs and profile metadata; it may not patch TS lowering with WordPress symbol names.

## 14.17 ts2hx-assisted adoption

`ts2hx` is an optional adoption assistant, not the preferred authoring path and not a lossless migration claim.

- Strict mode is transactional and fails on unsupported constructs.
- Assisted mode records every semantic loss, inserted boundary, omitted declaration, and manual review item.
- Generated Haxe goes into an adoption-review directory and is not automatically marked authoritative.
- Type declaration adoption is preferred over implementation-source translation.
- Runtime parity tests are required before migrated implementation becomes owned source.
- Unsupported top-level execution, module cycles, dynamic prototypes, mutable live bindings, complex TSX, or package declaration shapes are surfaced, not replaced with `Dynamic`.

## 14.18 Stable, experimental, private, deprecated, and unsafe APIs

Public Haxe namespaces and documentation must encode classification:

```text
wordpress.gutenberg.*                 stable/public for selected profile
wordpress.gutenberg.experimental.*    explicitly unstable; opt-in define
wordpress.gutenberg.deprecated.*      supported only for migration windows
wordpress.gutenberg.privateApi.*      not published by default
wordpress.gutenberg.unsafe.*          explicit waiver and runtime guards
```

A private API becoming public creates a new stable wrapper; the private wrapper is not silently reclassified. Generated docs show upstream source/package/version and SDK evidence status.

---

# 15. Haxe-first solution/site composition model

## 15.1 Recommendation

Include a solution-composition layer, but keep it a **build-time workspace model over normal WordPress deployables**. It should answer “which plugins, themes, blocks, contracts, and packages belong to this solution?” It should not answer “how does WordPress route every request through our proprietary application kernel?”

## 15.2 Project manifest

A root `wordpress-hx.json` should declare:

- project identity and SDK version;
- selected compatibility profile(s);
- deployable modules and output paths;
- Haxe source sets (`shared`, `server`, `browser`);
- WordPress/PHP/Node requirements;
- plugin/theme dependencies;
- environment profile names and non-secret configuration keys;
- generated namespace policy;
- build modes and asset tool integration;
- artifact ownership root;
- test site configuration;
- package and update metadata.

The JSON is schema-validated and may be generated or edited as project configuration. Application behavior remains in Haxe.

## 15.3 Shared server/browser models

Shared code is limited to target-independent types and behavior:

- DTOs and enums;
- validation rules with equivalent target implementations;
- JSON codecs;
- identifiers and domain calculations;
- deterministic formatting where locale/runtime behavior is specified;
- API error contracts.

Forbidden shared dependencies include PHP globals, `WP_Post`, DOM nodes, React elements, editor stores, browser storage, database handles, and request-global authorization tokens.

Every shared codec must run the same vector corpus on PHP and JS. Byte equivalence is required where the contract says so; semantic equivalence is documented otherwise.

## 15.4 Generated plugin/theme packaging

The workspace emits independent packages:

```text
build/packages/acme-core-1.2.0.zip
build/packages/acme-blocks-1.2.0.zip
build/packages/acme-theme-1.2.0.zip
build/deployment.json
build/checksums.txt
```

A deployment manifest may express ordering and compatibility, but WordPress still installs/activates normal plugins and themes. A workspace-level “bundle ZIP” may be generated for CI or hosting automation only if it contains ordinary packages and does not require a custom runtime installer.

## 15.5 Environment and configuration profiles

Support compile/build/runtime configuration without embedding secrets:

- compile-time feature/profile choices;
- public environment values safe for browser output;
- server runtime constants/options read through typed adapters;
- local/test WordPress URLs and database settings;
- production optimization flags.

Secrets remain in hosting environment variables, WordPress configuration, or secret management. The build fails if a declared secret is referenced from browser/shared code.

## 15.6 Database migrations and upgrade routines

Call them **plugin upgrade routines**, not a general migration system. They should:

- have a declared plugin data version;
- run through native activation/update/admin hooks;
- be ordered and idempotent;
- record completion only after success;
- support resumable batches for large content changes;
- expose rollback guidance but not promise automatic rollback where WordPress operations are irreversible;
- coordinate custom tables, options, roles, and content registrations;
- run against real databases in tests.

Custom-table schema builders may be added later but must preserve `dbDelta` behavior or explicitly choose direct SQL with a tested policy.

## 15.7 Content types and field schemas

A solution can centralize post type, taxonomy, meta, option, and REST field declarations. Generated typed references are consumed by plugins, themes, templates, blocks, REST clients, and tests. Ownership remains with the module that registers the native WordPress object; other modules import its public contract package.

## 15.8 Typed project-wide references

Generate project catalogs for:

- routes and REST endpoints;
- screens and menu slugs;
- hooks and filters;
- post types, taxonomies, meta, and options;
- capabilities and roles;
- nonce actions/fields;
- asset handles and bundle entrypoints;
- block names, patterns, styles, and variations;
- store names and selectors/actions;
- templates and template parts;
- translation keys/text domains.

Catalog generation must detect duplicates and ownership conflicts before target emission.

## 15.9 Development workflow

The workspace CLI coordinates, but does not replace, normal tools:

1. Haxe compile/macro planning.
2. PHP artifact generation and Composer/autoload preparation.
3. genes-ts TS/TSX generation.
4. `@wordpress/scripts` or configured bundler execution.
5. translation and asset metadata generation.
6. manifest transaction publication.
7. optional sync/mount into a local WordPress install.
8. PHPUnit/Playwright/test commands.

Watch mode observes effective inputs from all stages. It must not declare success until generated output, typechecking, and artifact publication complete atomically.

HMR is post-MVP and should use the selected normal browser toolchain. PHP changes may use page reload or a standard local-development plugin; the SDK should not invent a production runtime protocol.

## 15.10 Deployment and updates

- Production artifacts contain no Haxe compiler, macros, CLI, Node dependencies, or source maps unless explicitly included for debug packages.
- Plugin/theme ZIPs include runtime Composer dependencies or generated autoload files required by the artifact.
- Update metadata may integrate with WordPress.org, Composer/Satis, GitHub Releases, or private update services, but no proprietary service is mandatory.
- Upgrade tests install the previous released package, create representative data, install the candidate, run upgrade routines, and verify behavior.
- Rollback instructions and data compatibility are part of release notes.


---

# 16. Compiler, macros, target emission, and runtime architecture

## 16.1 Compiler architecture by responsibility

| Layer | Owns | Must not own |
|---|---|---|
| Haxe compiler | Typed AST, normal macro execution, target-independent language semantics | WordPress API knowledge |
| Generic genes-ts | Haxe → strict TS/TSX/JS lowering, ESM/package semantics, source maps | WordPress package names or block behavior |
| Generic native PHP compiler | Haxe → PHP AST/IR, native arrays/callables/references, namespaces/classes/functions, deterministic printer, source locations | Plugin headers, hook catalogs, Core replacement paths |
| SDK WordPress PHP profile | Plugin/theme files, public adapters, WordPress calls, templates, metadata, coding style | Full Core linker/original-path replacement |
| SDK semantic-plan macros | Collect typed declarations, validate profiles/contracts, produce immutable build plan | Textually patch emitted PHP/TS |
| SDK artifact generators | `block.json`, `theme.json`, asset/translation/package manifests, source-map indexes | Runtime behavior that belongs to WordPress/Gutenberg |
| Full-port linker | Existing Core path/segment replacement and distribution assembly | SDK extension authoring contract |

## 16.2 Semantic build plan

Macros should not write final target files ad hoc. They produce a deterministic semantic plan with stable schema, for example:

```json
{
  "schema": "wordpress-hx.semantic-plan.v1",
  "profile": "wp70-release",
  "modules": [
    {
      "kind": "plugin",
      "id": "acme-books",
      "bootstrap": { "phpPath": "acme-books.php" },
      "hooks": [],
      "restEndpoints": [],
      "blocks": [],
      "exports": [],
      "assets": []
    }
  ]
}
```

The real plan contains typed source locations and canonical IDs. Requirements:

- no absolute local paths in canonical output;
- deterministic ordering independent of filesystem traversal;
- every declaration retains Haxe source file/line/column;
- duplicates and profile conflicts fail before emission;
- plan schema is versioned and tested as a public build contract only when external tools are permitted to consume it;
- emitters receive immutable plans and return complete staged artifact descriptions.

## 16.3 PHP generation strategy

### 16.3.1 Public PHP is a product surface

Public plugin/theme PHP MUST be emitted through a native-shaped WordPress profile, not treated as incidental compiler output. This includes:

- root plugin and mu-plugin bootstrap files;
- activation/deactivation/uninstall registration;
- public facade classes/functions;
- REST callbacks;
- dynamic block render callbacks;
- template files;
- hook registration units;
- generated Composer/autoload integration;
- files another plugin/theme is expected to include or call.

The emitter should operate on PHP IR rather than string concatenation. Any temporary literal segment is an explicit `RawPhpSegment` with source/provenance, a reason, owner, and removal gate.

### 16.3.2 Stock Haxe PHP is sufficient only for bounded private implementation

Stock Haxe PHP is acceptable in MVP when all of these are true:

- the emitted class is namespaced and reached only through an SDK-owned adapter;
- its symbol/file shape is not part of the public WordPress contract;
- its runtime helpers are packaged deterministically;
- its PHP syntax floor passes the project matrix;
- stack frames can be correlated to Haxe;
- native boundary values are converted immediately and do not leak Haxe collection/runtime shapes into WordPress;
- bundle size and bootstrap cost remain within budget.

It is not sufficient by itself for arbitrary public WordPress files because WordPress-facing contracts can require global functions, reference parameters/returns, native associative arrays, conditional declarations, include-time side effects, plugin header comments, exact template paths, mixed PHP/HTML, and caller scope.

### 16.3.3 Reusable Reflaxe/custom PHP target

The recommended destination is a reusable compiler package, not an SDK-local printer forever:

```text
Haxe typed AST
      │
      ▼
reflaxe.php-native core
  - PHP semantic IR
  - expression/statement lowering
  - functions/classes/namespaces
  - native arrays/callables/references
  - source locations
  - deterministic printer
      │
      ▼
wordpress-hx PHP profile
  - plugin/theme file plan
  - WordPress adapters
  - headers/guards/autoload
  - template segments
  - coding-standard formatting
```

Initial implementation order:

1. Extract or recreate the generic IR/printer and proven runtime/std behavior outside the full-port namespace.
2. Build a minimal SDK profile for plugin bootstrap, hooks, REST, block render, exported facade, and bounded template.
3. Use stock Haxe PHP behind those adapters for private logic.
4. Expand custom lowering only when a real SDK boundary requires it and a generic fixture exists.
5. Decide before `1.0` whether private stock output remains a supported lane or a migration mechanism.

### 16.3.4 Native PHP constructs

The public emitter MUST support the following with typed IR:

| Construct | Requirement |
|---|---|
| Global functions | Stable declared names, native signatures, optional conditional declaration, source map entry |
| Classes/interfaces/traits | Native namespaces and readable names; public signatures specified by contract |
| Plugin headers | Exact root comment header generated from typed manifest |
| Conditional declarations | Structured `if (!function_exists(...))`/equivalent plan, never raw string assembly |
| References | By-reference args/returns represented in PHP IR; Haxe implementation boundary explicitly adapts value/reference behavior |
| Arrays | Native indexed/associative PHP arrays at WordPress boundaries; no automatic `StringMap`/runtime wrapper leakage |
| Callbacks | Native callables, closures, class-method arrays, stable identity for removable hooks |
| Globals/constants | Typed accessors that emit native `$GLOBALS`, `global`, `defined`, and constants where required |
| Template files | Direct `.php`/mixed PHP-HTML emission at declared theme/admin path with typed segment plan |
| Includes | Deterministic native `require`/`require_once` only from declared package graph |
| Top-level statements | Allowed only in explicit bootstrap/template file plans, not incidental class compilation |
| PHPDoc/attributes | Generated where useful for static analysis, IDEs, and interoperability; not a substitute for runtime behavior |

MVP does not require arbitrary Haxe source to emit every possible global PHP construct. It requires the semantic plan to express the public constructs used by supported SDK features.

## 16.4 Browser generation through genes-ts

### Development lane

- genes-ts emits split ESM `.ts` and `.tsx`.
- `tsc --strict` runs before bundling.
- generated source is readable, formatted, and source-mapped.
- imports reference exact profile-approved package exports.
- public exports use explicit retention metadata so dead-code elimination does not remove interop surfaces.
- normal `@wordpress/scripts` or a configured equivalent bundles and externalizes packages.

### Differential lane

Selected fixtures also compile through classic Genes JavaScript. Differential runtime tests compare observable behavior, not formatting. This catches compiler-mode regressions and preserves an escape path if one emitter has a bounded defect. The product should not promise that every application can switch modes without review until the tested corpus proves it.

### Production lane

- build the same semantic modules with production defines;
- bundle/minify through normal WordPress tooling;
- retain external package/dependency extraction behavior;
- generate final `*.asset.php`, script-module metadata, translation metadata, content hashes, and source maps according to release policy;
- prohibit target-language post-processing that changes behavior without a source-level fixture.

## 16.5 Macros

Macros are appropriate for:

- schema derivation and validation;
- registration declaration collection;
- typed reference generation;
- profile capability checks;
- hook callback validation;
- block metadata/deprecation checks;
- HXX parsing and typed lowering;
- public export collection;
- artifact and dependency planning;
- negative diagnostics with source locations.

Macros are not appropriate for:

- broad textual replacement of generated PHP/TS;
- reading arbitrary application state by executing WordPress/plugin code;
- hiding unsupported compiler constructs behind raw target snippets;
- generating public APIs from ambiguous reflection without a review report;
- network access during a normal deterministic build.

All macro inputs, including files, environment keys, package metadata, and profile catalogs, must be part of the effective build fingerprint.

## 16.6 Source maps and stack traces

### JavaScript/TypeScript

- genes-ts emits Haxe-to-TS/TSX source maps.
- the bundler emits JS-to-TS maps.
- the build attempts standards-based composition into JS-to-Haxe maps.
- when complete composition is not reliable, both map layers are shipped in debug artifacts and `wphx-sdk trace` resolves them sequentially.
- Playwright deliberately throws from a Haxe line and verifies the mapped browser stack.

### PHP

PHP has no universally consumed browser-style source-map standard. The SDK should emit:

- `*.haxe-map.json` mapping generated PHP file/line ranges to Haxe source and semantic-plan node;
- source comments where they do not disturb headers/output;
- a package-level source index;
- `wphx-sdk trace php <stack-file>` for offline mapping;
- optional development-only WordPress error-handler integration that augments logs without suppressing native frames.

Public adapter frames should remain readable even without mapping. Production exceptions/logging remain native PHP/WordPress behavior.

## 16.7 Determinism and readability

Generated output requirements:

- stable sort order for declarations, JSON keys where semantically irrelevant, and manifest entries;
- normalized UTF-8 and line endings;
- no timestamps, machine usernames, temp paths, or absolute source paths in reproducible artifacts;
- stable generated names derived from declared identities, not traversal order;
- no minified PHP by default;
- formatting inside the generation transaction;
- comments identifying the Haxe source and generator version at public files without using comments as ownership proof;
- deterministic package archives with normalized file order, permissions, and timestamps;
- double-build byte comparison in CI.

Readability is evaluated by a human review gate: a WordPress/PHP developer should be able to identify registration, permission, render, and facade behavior without understanding Haxe compiler internals.

## 16.8 Development versus production output

| Concern | Development | Production |
|---|---|---|
| PHP | Readable, assertions/diagnostic metadata allowed, source map index | Readable, optimized autoload, no dev handlers, same public ABI |
| TS/TSX/JS | Unminified, source maps, watch rebuild | Bundled/minified, content hashes, optional external maps |
| HXX | Source-location-rich diagnostics | Same lowered semantics |
| Metadata | Pretty-printed for inspection | Deterministic compact or pretty form; policy fixed per file type |
| Logs | Verbose compiler/profile diagnostics | Build summary and provenance; no secret values |
| Dead code | Conservative to aid debugging | Enabled with public export retention tests |

Development and production builds must pass the same type/profile/ownership checks. Production is not allowed to introduce a separate untyped code path.

## 16.9 Coding standards and static analysis

Blocking generated-PHP checks:

- `php -l` on every generated PHP file;
- WordPress Coding Standards through PHPCS, with a small versioned generated-code ruleset only for justified compiler artifacts;
- PHPStan or Psalm with WordPress stubs at a documented level, raising the level over time rather than hiding baseline errors;
- Composer autoload validation;
- no duplicate global symbols;
- PHP minimum-syntax compatibility;
- selected reflection tests for public signatures and reference behavior.

Blocking generated-browser checks:

- `tsc --strict`;
- package export resolution;
- no unexplained `any`/`unknown` inventory;
- ESLint/WordPress scripts rules where applicable;
- bundle dependency and asset-handle checks;
- source-map validation.

Haxe source uses formatter, compiler warnings-as-errors for SDK packages, and the escape-hatch scanner.

## 16.10 Runtime architecture

There is no monolithic `wordpress-hx-sdk` runtime on the server or browser.

Generated packages may contain small implementation support modules for:

- Haxe standard-library behavior actually used;
- schema codecs;
- enum/option/result encoding;
- callback adapters;
- source correlation in development;
- shared domain functions.

Support code must be tree-shaken or dependency-closed, namespaced, versioned within the package, and measured. It must not install a second hook registry, React runtime, REST server, template dispatcher, or data store framework.

## 16.11 Packaging combination

Use a justified combination:

- **Haxelib/lix:** SDK authoring libraries, exact compiler package pins, Haxe dependency graph.
- **npm:** CLI/build orchestration, genes-ts integration, WordPress browser dependencies, optional generated public JS packages.
- **Composer:** project PHP dependencies, WordPress/PHP stubs and analysis tools, optimized autoload used in final ZIP when required. The SDK should avoid a mandatory remotely installed production Composer package.
- **WordPress ZIPs:** primary deployable plugin/theme artifacts.
- **OCI/Docker:** test environments only, not required deployment.

Every final ZIP contains a build manifest and version metadata but not source-only tooling.

---

# 17. Typed boundary and escape-hatch policy

## 17.1 Default rule

Application and SDK source must use the narrowest practical Haxe type. Open target values are decoded or wrapped immediately at the boundary. `Dynamic`, `untyped`, raw PHP/JavaScript, broad casts, emitted `any`, and emitted `unknown` are defects unless a reviewed boundary record explains why the target contract is genuinely open.

## 17.2 Boundary categories

| Category | Example | Allowed mechanism |
|---|---|---|
| Closed public API | `register_post_type`, stable package export | Generated extern plus typed wrapper |
| Open structural payload | filter-added array fields, REST `_links` | Structural type with known fields plus explicit extras map |
| Versioned external plugin | Composer/plugin API | Adoption contract with version/source hash |
| Optional runtime feature | optional class/function/package | Typed capability token |
| Experimental upstream API | `__experimental*`, private API | Experimental package/define and waiver |
| Truly opaque value | third-party callback payload with no metadata | Named opaque abstract; operations limited to reviewed decoder/accessors |
| Raw target requirement | unsupported syntax at a narrow adapter | `UnsafePhp`/`UnsafeJs` segment with manifest record and removal gate |

## 17.3 Required escape-hatch record

Every durable unsafe use includes machine-readable metadata:

```haxe
@:wordpressHxUnsafe({
  id: "SDK-UNSAFE-0007",
  reason: "Provider exposes callback payload without stable schema",
  boundary: "Acme Inventory 3.2 webhook",
  owner: "interop-php",
  expires: "before SDK 1.0",
  evidence: "fixtures/interop/acme-inventory-webhook"
})
```

The exact syntax may change, but the fields are required. CI produces an inventory grouped by package, category, owner, and release blocker. An expired waiver fails the build.

## 17.4 `Dynamic` and `untyped`

- Prohibited in stable public APIs.
- Prohibited in examples marketed as recommended authoring.
- Allowed inside a narrow generated interop implementation only with an opaque typed facade and waiver.
- Never used as the default output of adoption generators.
- A broad cast from untrusted input to a schema type is forbidden; decoding must occur.
- `untyped` target injection must not appear in application source.

## 17.5 TypeScript `any` and `unknown`

- Generated `any` is a release-blocking issue unless a profile contract explicitly contains an `any` and a local wrapper narrows it immediately.
- `unknown` is acceptable only at an actual untrusted/opaque boundary and must be decoded before domain use.
- Inventories distinguish upstream-declared openness from compiler loss.
- Compiler-induced `any`/`unknown` requires a generic genes-ts issue and fixture.

## 17.6 Native PHP value policy

At WordPress boundaries:

- arrays are PHP arrays;
- callbacks are PHP callables;
- `WP_Error` remains a native object or a typed view over it;
- IDs remain native integers/strings with Haxe abstracts erased at emission;
- global values are read/written through native semantics;
- by-reference behavior is preserved by public adapters;
- Haxe collection/runtime wrappers must not cross into APIs that expect native arrays.

## 17.7 Public API maturity

Every generated extern/wrapper records:

- upstream provider and exact profile;
- symbol/package path;
- public/experimental/private/deprecated classification;
- evidence source;
- SDK test status;
- known semantic gaps.

Stable application code cannot import private APIs without an explicit unsafe dependency. Documentation generation must visually separate classifications.

## 17.8 Custom identifiers and strings

Typing does not mean pretending strings disappear. Custom slugs, hook names, routes, and message IDs are declared as data, validated, then exposed as branded refs. The generated artifacts retain the literal native value. Arbitrary target source strings are different and remain unsafe.

## 17.9 Negative diagnostics

The SDK must include compile-fail fixtures for at least:

- wrong hook callback arity/return type;
- action used as filter;
- duplicate post type/block/asset handle;
- invalid block attribute default;
- forward API under `wp70-release`;
- unsafe HTML interpolation;
- missing REST permission policy;
- client/server schema mismatch;
- browser import from server module;
- secret referenced from browser/shared source;
- modified generated file during regeneration;
- unversioned third-party adoption contract;
- unwaived private API;
- emitted public export removed by DCE;
- ambiguous PHP signature mapped to `Dynamic`;
- unsupported ts2hx construct in strict mode.

Diagnostics name the native concept and a concrete remediation; they should not expose only macro internals.

---

# 18. HXX/template architecture

## 18.1 Principle

HXX is a typed authoring syntax and AST, not a runtime. It lowers at build time to one of:

- React TSX/JSX or typed React calls for Gutenberg/browser UI;
- ordinary PHP/HTML template files or PHP expression trees for server/admin/theme rendering;
- deterministic static block markup fixtures where appropriate.

No HXX parser, virtual DOM, component registry, or template resolver ships solely to render server templates at runtime.

## 18.2 Parser and typed resolution

Use `tink_hxx` as a source/architecture reference and, if compatible, a pinned dependency for parsing and node concepts. WordPress-specific behavior belongs in SDK generators:

- HTML tag prop/event types;
- React/Gutenberg component resolution;
- server element and attribute escaping contexts;
- typed WordPress helper components;
- template locals and partial refs;
- child/slot contracts;
- source locations.

Do not fork syntax casually. Any divergence needs an ADR and parser diagnostics/tests.

## 18.3 Browser HXX

Browser HXX resolves components to imported React/Gutenberg symbols and emits TSX or typed create-element calls through genes-ts.

Requirements:

- props and required children are compile-time checked;
- event/ref/context types are preserved;
- fragments, conditionals, loops, spreads, and component children lower predictably;
- spread values use closed structural types where possible;
- generated TSX remains readable;
- accessibility labels and relationships can use typed refs/message keys;
- raw JSX strings are not an escape route.

## 18.4 Server HXX

Server HXX builds a typed HTML/PHP segment AST. Text and attributes carry output-context types. WordPress helpers are target-shaped components/functions, for example:

- `WpLink` requiring `EscapedUrl` and text children;
- `NonceField` requiring a typed nonce action;
- `TemplatePart` requiring a declared template ref and locals;
- `AdminNotice` requiring a level and escaped/known-safe content;
- `BlockMarkup` integrating server-rendered block wrapper attributes.

The emitter may generate direct HTML with `<?php ... ?>` expressions or PHP string/echo statements depending on the file plan. The choice is deterministic and visible; it cannot change caller-scope behavior silently.

## 18.5 Template ownership modes

| Mode | Source of truth | SDK behavior |
|---|---|---|
| Haxe-owned template | HXX/Haxe | Generate native template file; manifest-owned |
| Existing external template | PHP/HTML file | Typed `Template.external` reference; validate path/locals contract where declared; never overwrite |
| Partially adopted template | Explicit segment contract | Generated segments and external segments have separate provenance; experimental until behavior is proven |
| Raw target escape | Reviewed raw segment | Manifest waiver, source hash, removal gate |

MVP should support Haxe-owned bounded templates and external references. Arbitrary partial conversion of legacy mixed PHP/HTML is not an MVP requirement.

## 18.6 WordPress template semantics

HXX does not erase:

- template hierarchy and selected file paths;
- include versus require behavior;
- caller scope and documented globals;
- output buffering;
- query loop/global post state;
- header/footer/sidebar calls;
- theme and plugin hook execution;
- direct file access concerns.

A generated Haxe-owned template declares its inputs and generated global bridges. Existing templates with unknown scope remain external until inventoried.

## 18.7 Output safety

- Plain `String` interpolated into text becomes escaped text, not trusted HTML.
- URLs, attributes, CSS values, JSON/script data, and HTML use distinct constructors and emitters.
- `TrustedHtml` cannot be produced by concatenating strings.
- Rich text from WordPress may enter as `KsesSafeHtml` only after an explicit policy.
- Browser `dangerouslySetInnerHTML` and server raw HTML share an unsafe review mechanism.
- The generated target should visibly call native escape helpers where relevant.

## 18.8 HXX feasibility gate

HXX becomes stable only after fixtures prove:

- typed embedded expressions, not raw target expressions;
- useful source-located diagnostics;
- exact/normalized output parity for representative server templates;
- React runtime and type parity for representative editor components;
- source maps through generated TSX;
- manifest/provenance integration;
- no shipped runtime template engine;
- external-template coexistence and collision safety.

---

# 19. Generated artifact ownership and regeneration policy

## 19.1 Fail-closed rule

A path is generated-owned only if the current ownership manifest names that exact normalized relative path and expected content hash. Comments, directory names, extensions, or “looks generated” heuristics never establish ownership.

## 19.2 Manifest shape

Proposed root file: `build/_GeneratedFiles.json`.

```json
{
  "schema": "wordpress-hx.generated-files.v1",
  "generator": {
    "sdkVersion": "0.1.0",
    "toolchainDigest": "sha256:...",
    "profile": "wp70-release"
  },
  "sourceDigest": "sha256:...",
  "generationDigest": "sha256:...",
  "files": [
    {
      "path": "packages/acme-books/acme-books.php",
      "sha256": "...",
      "kind": "plugin-bootstrap-php",
      "owner": "module:acme-books",
      "sources": ["src/server/Plugin.hx:12-40"]
    }
  ]
}
```

Requirements:

- normalized forward-slash relative paths only;
- no absolute paths, traversal, duplicates, case-folding collisions, or symlink escapes;
- ordered file entries;
- content hashes for every file;
- generator/profile/toolchain provenance;
- source references stored in reproducible project-relative form;
- schema migrations are explicit and tested.

## 19.3 Generation transaction

1. Resolve and fingerprint all effective inputs.
2. Read and validate the current manifest.
3. Verify every currently owned file still matches its recorded hash.
4. Build the complete next output tree in an isolated staging directory.
5. Format, lint, typecheck, and validate staged files.
6. Detect collisions with unowned live paths.
7. Compute stale owned paths and verify they are still unmodified.
8. Write a transaction journal.
9. Atomically publish new/changed files and remove verified stale files.
10. Publish the new manifest last.
11. Remove the journal after success.
12. On the next command, recover or roll back an interrupted transaction before doing new work.

A failed build leaves the previous live tree and manifest intact.

## 19.4 Collision and edit policy

- Unowned destination exists: fail before modifying anything.
- Owned file hash differs: fail and show diff/ownership instructions.
- Stale owned file was modified: fail; never delete it automatically.
- Manifest is missing but output directory has files: treat every file as unowned.
- Legacy manifest schema: migrate only through a tested migration with preflight; otherwise fail.
- Generated file outside declared output roots: fail.

## 19.5 Intentionally taking ownership by hand

To convert a generated artifact into handwritten source:

1. move it to a declared handwritten source location if appropriate;
2. remove its manifest entry through `wphx-sdk adopt-generated <path>`;
3. regenerate and verify the tool no longer targets the path;
4. remove or update generated headers;
5. add an external/adoption contract if Haxe still references it.

Editing the file and hoping the generator stops owning it is not supported.

## 19.6 Stale cleanup and `clean`

`wphx-sdk clean` deletes only manifest-owned files after verifying hashes and paths. It does not recursively delete a build directory based on naming. Package-manager caches and ephemeral staging directories have separate bounded cleanup rules.

## 19.7 Generated output in version control

Project policy is configurable but explicit:

- **Library/SDK repository:** commit deterministic golden fixtures and selected generated API/profile catalogs; do not commit transient local packages.
- **Application repository:** may commit generated PHP/TS/metadata for review/deployment or regenerate in CI. The project manifest records the policy.
- **Release:** always regenerate from source and verify against any committed output; release packages never trust stale committed artifacts.

Whether committed or not, generated files remain uneditable and manifest-owned.

## 19.8 Provenance and receipts

Each release artifact should be traceable to:

- SDK and package versions;
- upstream profile commits;
- Haxe/genes-ts/PHP compiler pins;
- project source commit;
- build configuration/profile;
- generated-file manifest digest;
- test/evidence receipt IDs;
- final ZIP/hash/SBOM.

This provenance is the bridge to downstream full-port compatibility testing without conflating claims.

---

# 20. Interoperability and gradual-adoption strategy

## 20.1 Boundary philosophy

Interop should look ordinary on the target side:

- existing PHP calls a namespaced class or global function;
- generated PHP calls existing functions/classes through native PHP;
- existing JavaScript imports an ESM export or calls a registered WordPress API;
- generated TSX imports existing npm packages;
- WordPress discovers plugins, blocks, themes, templates, REST routes, and assets normally.

The Haxe side uses generated/curated externs, schemas, facades, and capability tokens. Generated migration output is never automatically considered trusted source.

## 20.2 Adoption modes

### Mode 1 — one typed Haxe island inside an existing plugin or theme

| Dimension | Contract |
|---|---|
| Source ownership | Existing PHP/JS remains hand-owned; one Haxe module and its facade are SDK-owned |
| Generated artifacts | Namespaced private PHP/JS module, stable public facade, maps, ownership manifest |
| Runtime dependencies | Native WordPress plus packaged generated support only |
| Workflow | Adopt selected external symbols → build island → call from existing code → run existing tests |
| Migration boundary | Explicit facade. The generator never rewrites surrounding files except opt-in marker blocks |

### Mode 2 — Haxe-authored plugin consumed by ordinary PHP

| Dimension | Contract |
|---|---|
| Source ownership | Plugin behavior and exported facades in Haxe; consumer PHP remains external |
| Generated artifacts | Root plugin PHP, autoload, generated classes/functions, metadata, ZIP |
| Runtime dependencies | Native WordPress/PHP; no Haxe compiler at runtime |
| Workflow | Declare exports and plugin lifecycle → package → consumer calls documented PHP ABI |
| Migration boundary | Public PHP ABI is SemVer-governed and tested with non-Haxe callers |

### Mode 3 — Haxe-authored block/editor extension inside an existing Gutenberg project

| Dimension | Contract |
|---|---|
| Source ownership | Existing npm/TS/JS project remains external; selected block/extension Haxe-owned |
| Generated artifacts | TS/TSX/JS entrypoints, `block.json`, assets, source maps, asset metadata |
| Runtime dependencies | Native React/Gutenberg packages and existing bundler |
| Workflow | Add Haxe compile stage before existing WordPress build; import or register generated module |
| Migration boundary | Existing package config and unrelated source are not generated-owned |

### Mode 4 — mixed existing PHP/JS project gradually adopting typed Haxe contracts

| Dimension | Contract |
|---|---|
| Source ownership | Per-boundary; contracts may be Haxe-owned while implementations remain PHP/JS |
| Generated artifacts | Externs, facades, schemas, generated clients, marker-bounded integration snippets if approved |
| Runtime dependencies | Existing project dependencies |
| Workflow | Inventory → generate precise contracts → review omissions → adopt one boundary at a time |
| Migration boundary | Ownership manifest and adoption report; no whole-project translation |

### Mode 5 — new Haxe-first plugin

| Dimension | Contract |
|---|---|
| Source ownership | Haxe for plugin logic/configuration; resources remain native files where appropriate |
| Generated artifacts | Complete native plugin tree and ZIP |
| Runtime dependencies | Native WordPress, packaged PHP dependencies/support |
| Workflow | Scaffold → build/watch → real WP tests → package/update |
| Migration boundary | Public PHP/REST/hook contracts; no hand edits to generated tree |

### Mode 6 — new Haxe-first block collection

| Dimension | Contract |
|---|---|
| Source ownership | Haxe block metadata, React UI, render code, shared schemas |
| Generated artifacts | Plugin bootstrap, per-block metadata, TSX/JS/CSS, render PHP, assets, ZIP |
| Runtime dependencies | Native Gutenberg/React/WordPress packages |
| Workflow | Generate block modules → editor/frontend tests → package |
| Migration boundary | Each block has stable name, attribute/deprecation history, and public serialization contract |

### Mode 7 — Haxe-first theme

| Dimension | Contract |
|---|---|
| Source ownership | Theme declaration, bounded templates/HXX, tokens, behavior in Haxe; external templates allowed |
| Generated artifacts | `style.css` header, `functions.php`, templates/parts, `theme.json`, assets, ZIP |
| Runtime dependencies | Native WordPress theme/template runtime |
| Workflow | Scaffold → compile templates/assets → template hierarchy/visual tests → package |
| Migration boundary | External templates remain external; HXX owns only declared files |

### Mode 8 — complete Haxe-first WordPress solution

| Dimension | Contract |
|---|---|
| Source ownership | Shared Haxe domain/contracts plus module-specific Haxe; normal deployable boundaries |
| Generated artifacts | Multiple plugin/theme/block ZIPs and deployment manifest |
| Runtime dependencies | Native WordPress/Gutenberg and declared third-party plugins/packages |
| Workflow | Workspace build/watch/test/package; independent module updates where supported |
| Migration boundary | Module public contracts and deployment manifest; no proprietary runtime kernel |

## 20.3 Adoption generator rules

- Read-only by default.
- Never execute PHP/WordPress/plugin application code unless the user chooses an isolated reflection mode and the contract records it.
- Prefer stubs/declarations/signatures over implementation inference.
- Deterministic output from exact inputs.
- Precise-or-omitted; do not guess with `Dynamic`.
- Emit a review report containing unsupported symbols, ambiguity, confidence source, versions, and required manual contracts.
- Generated adoption contracts are separately owned from application logic and can be regenerated safely.
- Marker-block edits to existing files require exact anchors, preflight, backup/diff, and fail-fast collision behavior.

## 20.4 Required illustrative APIs and generated target shapes

The examples below define the intended ergonomics and boundary behavior. Exact class/package spelling may be refined by ADR, but the type-safety and native-output properties are requirements.

### Example 1 — typed `add_action` / `add_filter`

**Haxe authoring:**

```haxe
package acme.books.server;

import wordpress.hx.server.hooks.WpActions;
import wordpress.hx.server.hooks.WpFilters;
import wordpress.hx.server.hooks.Priority;
import wordpress.hx.server.html.PostContentHtml;

final class PluginBoot {
  public static function configure():Void {
    WpActions.Init.listen(registerContent, Priority.Default);
    WpFilters.TheContent.map(addReadingTime, Priority.Late);
  }

  static function registerContent():Void {
    BooksContent.register();
  }

  static function addReadingTime(content:PostContentHtml):PostContentHtml {
    return ReadingTime.appendTo(content);
  }
}
```

The action contract infers zero accepted arguments; the filter contract requires and returns `PostContentHtml`.

**Representative generated PHP:**

```php
<?php
namespace Acme\Books\Generated;

add_action( 'init', array( PluginBoot::class, 'registerContent' ), 10, 0 );
add_filter( 'the_content', array( PluginBoot::class, 'addReadingTime' ), 20, 1 );
```

Native WordPress hook ordering and filter execution remain authoritative.

### Example 2 — custom post type plus REST schema

**Haxe authoring:**

```haxe
final class BookSchema {
  public static final postType = ContentType.define(
    AcmeIds.PostTypes.Book,
    {
      labels: Messages.BookLabels,
      publicVisibility: Public,
      showInRest: true,
      supports: [Title, Editor, Thumbnail],
      capabilityModel: Capabilities.EditBooks
    }
  );

  public static final isbn = PostMeta.define(
    postType,
    AcmeIds.Meta.Isbn,
    Schema.string({ minLength: 10, maxLength: 17, pattern: Isbn.pattern }),
    { single: true, showInRest: true, sanitize: Isbn.sanitize }
  );
}
```

**Representative generated PHP shape:**

```php
register_post_type(
    'acme_book',
    array(
        'public'       => true,
        'show_in_rest' => true,
        'supports'     => array( 'title', 'editor', 'thumbnail' ),
        /* generated labels and capability mapping */
    )
);

register_post_meta(
    'acme_book',
    '_acme_isbn',
    array(
        'single'       => true,
        'show_in_rest' => array( 'schema' => array( 'type' => 'string' ) ),
        'sanitize_callback' => array( \Acme\Books\Generated\BookSchema::class, 'sanitizeIsbn' ),
    )
);
```

The registration arrays and REST behavior are WordPress-native; Haxe owns their declaration and codecs.

### Example 3 — static Gutenberg block

**Haxe authoring:**

```haxe
@:wpBlock(AcmeBlocks.Callout)
final class CalloutBlock implements StaticBlock<CalloutAttrs> {
  public static final attributes = Schema.object({
    message: Schema.richText({ defaultValue: "" }),
    tone: Schema.enumValue(CalloutTone, { defaultValue: Info })
  });

  public static function edit(props:EditProps<CalloutAttrs>):ReactNode {
    return hxx(<Notice status={props.attributes.tone.toNoticeStatus()}>
      <RichText
        value={props.attributes.message}
        onChange={props.set.message}
        placeholder={Messages.CalloutPlaceholder}
      />
    </Notice>);
  }

  public static function save(props:SaveProps<CalloutAttrs>):ReactNode {
    return hxx(<aside {...BlockProps.save({ className: props.attributes.tone.cssClass() })}>
      <RichText.Content value={props.attributes.message} />
    </aside>);
  }
}
```

**Representative generated `block.json`:**

```json
{
  "apiVersion": 3,
  "name": "acme/callout",
  "title": "Callout",
  "attributes": {
    "message": { "type": "string", "source": "html" },
    "tone": { "type": "string", "default": "info" }
  },
  "editorScript": "file:./index.js"
}
```

**Representative generated TSX:**

```tsx
export function save(props: SaveProps<CalloutAttrs>) {
  return <aside {...useBlockProps.save({ className: toneClass(props.attributes.tone) })}>
    <RichText.Content value={props.attributes.message} />
  </aside>;
}
```

Gutenberg’s parser and validation decide whether saved markup is valid.

### Example 4 — dynamic block with generated PHP render boundary

**Haxe authoring:**

```haxe
@:wpBlock(AcmeBlocks.BookGrid)
final class BookGridBlock implements DynamicBlock<BookGridAttrs> {
  public static final attributes = Schema.object({
    count: Schema.int({ min: 1, max: 24, defaultValue: 6 }),
    showExcerpt: Schema.bool({ defaultValue: true })
  });

  public static function edit(props:EditProps<BookGridAttrs>):ReactNode {
    return hxx(<ServerSideRender
      block={AcmeBlocks.BookGrid}
      attributes={props.attributes}
    />);
  }

  public static function render(ctx:BlockRenderContext<BookGridAttrs>):SafeHtml {
    final books = Books.queryRecent(ctx.attributes.count);
    return BookGridTemplate.render({ books: books, showExcerpt: ctx.attributes.showExcerpt });
  }
}
```

**Representative generated PHP boundary:**

```php
register_block_type(
    __DIR__,
    array(
        'render_callback' => static function ( array $attributes, string $content, \WP_Block $block ): string {
            $decoded = \Acme\Books\Generated\BookGridAttrsCodec::decode( $attributes );
            if ( $decoded instanceof \WP_Error ) {
                return '';
            }
            return \Acme\Books\Generated\BookGridBlock::render( $decoded, $content, $block );
        },
    )
);
```

WordPress remains responsible for block registration, context, and render invocation.

### Example 5 — editor sidebar / SlotFill extension

**Haxe authoring:**

```haxe
final class BookAuditPlugin {
  public static function register():Void {
    EditorPlugins.register(AcmeEditorPlugins.BookAudit, render);
  }

  static function render():ReactNode {
    final postType = CoreEditor.select.currentPostType();
    if (postType != AcmeIds.PostTypes.Book) return null;

    return hxx(<PluginDocumentSettingPanel
      name={AcmePanels.BookAudit}
      title={Messages.BookAuditTitle}
    >
      <BookAuditPanel />
    </PluginDocumentSettingPanel>);
  }
}
```

**Representative generated TSX:**

```tsx
registerPlugin('acme-book-audit', {
  render: BookAuditPlugin_render,
});
```

The generated component imports the profile-correct SlotFill package; focus and keyboard behavior are tested in the real editor.

### Example 6 — typed data-store selector/action

**Haxe authoring:**

```haxe
final class BookEditorStore {
  public static final store = DataStore.define(
    AcmeStores.BookEditor,
    State.schema,
    Actions,
    Selectors
  );

  public static function useBook(id:PostId<BookPost>):Loadable<BookDto> {
    return Hooks.useSelect(
      registry -> registry.select(store).book(id),
      [id]
    );
  }

  public static function save(book:BookDraft):Promise<Result<BookDto, SaveError>> {
    return Data.dispatch(store).save(book);
  }
}
```

**Representative generated TS:**

```ts
export const store = createReduxStore<State, Actions, Selectors>('acme/book-editor', {
  reducer,
  actions,
  selectors,
});
register(store);
```

The wrapper preserves `@wordpress/data` registry, resolution, and React subscription behavior.

### Example 7 — typed REST endpoint with generated browser client

**Haxe authoring:**

```haxe
final class GetBookEndpoint {
  public static final contract = Rest.endpoint({
    method: HttpMethod.Get,
    route: AcmeRoutes.BookById,
    path: Schema.object({ id: Schema.postId(BookSchema.postType) }),
    query: Schema.object({ context: Schema.enumValue(BookContext, { defaultValue: View }) }),
    response: BookDto.schema,
    errors: BookApiError.schema,
    permission: Permissions.require(Capabilities.ReadBook)
  });

  public static function handle(req:RestRequest<GetBookEndpoint>):RestResult<BookDto, BookApiError> {
    return Books.findForRest(req.path.id, req.query.context);
  }
}
```

**Generated Haxe browser API:**

```haxe
final result:Promise<Result<BookDto, BookApiError>> =
  BookApi.getBook({ id: bookId, context: View });
```

**Representative generated TS client:**

```ts
export async function getBook(input: GetBookInput): Promise<Result<BookDto, BookApiError>> {
  const value = await apiFetch({ path: routeForBook(input.id, input.context), method: 'GET' });
  return decodeBookResult(value);
}
```

A non-Haxe curl/PHP client fixture verifies that the endpoint is not coupled to the generated client.

### Example 8 — HXX-authored theme or admin template

**Haxe authoring:**

```haxe
@:wpTemplate(AcmeTemplates.AdminBookList)
final class AdminBookListTemplate {
  public static function render(model:AdminBookListView):HtmlDocument {
    return hxx(<div class="wrap">
      <h1>{model.title}</h1>
      <NonceField action={AcmeNonces.BulkBooks} />
      <table class="widefat striped">
        <tbody>
          <for {book in model.books}>
            <tr>
              <td><WpLink href={book.editUrl}>{book.title}</WpLink></td>
              <td>{book.isbn}</td>
            </tr>
          </for>
        </tbody>
      </table>
    </div>);
  }
}
```

**Representative generated PHP/HTML:**

```php
<div class="wrap">
    <h1><?php echo esc_html( $model['title'] ); ?></h1>
    <?php wp_nonce_field( 'acme_bulk_books', '_acme_bulk_books_nonce' ); ?>
    <table class="widefat striped"><tbody>
    <?php foreach ( $model['books'] as $book ) : ?>
        <tr>
            <td><a href="<?php echo esc_url( $book['edit_url'] ); ?>"><?php echo esc_html( $book['title'] ); ?></a></td>
            <td><?php echo esc_html( $book['isbn'] ); ?></td>
        </tr>
    <?php endforeach; ?>
    </tbody></table>
</div>
```

There is no runtime HXX engine; WordPress/PHP includes and renders the file normally.

### Example 9 — calling an existing PHP plugin through an adoption contract

**Generated reviewed extern from provider stubs:**

```haxe
package acme.books.adopted.inventory;

@:native("\\Vendor\\Inventory\\Api")
extern final class InventoryApiNative {
  public static function reserve(productId:Int, quantity:Int):PhpMixed;
}

final class InventoryApi {
  public static function reserve(product:ProductId, quantity:PositiveInt):Result<ReservationId, InventoryError> {
    return InventoryCodec.decodeReservation(
      InventoryApiNative.reserve(product.toInt(), quantity.toInt())
    );
  }
}
```

**Application use:**

```haxe
switch InventoryPlugin.requireVersion(InventoryVersions.V3_2) {
  case Available(api): api.reserve(productId, quantity);
  case Missing(reason): Err(InventoryError.DependencyMissing(reason));
}
```

The `@:native` symbol is generated from a versioned adoption contract, not repeated as raw strings throughout application code.

### Example 10 — ordinary PHP or JavaScript calling SDK-generated Haxe code

**Haxe export declaration:**

```haxe
@:wpExport(AcmeExports.PriceQuote)
final class PriceQuoteService {
  public static function quote(input:QuoteInput):Result<Quote, QuoteError> {
    return Pricing.quote(input);
  }
}
```

**Ordinary PHP caller:**

```php
$result = \Acme\Pricing\PriceQuoteService::quote(
    array( 'product_id' => 42, 'quantity' => 3 )
);
```

**Ordinary JavaScript caller:**

```js
import { quote } from '@acme/pricing-generated';
const result = await quote({ productId: 42, quantity: 3 });
```

The exported PHP/ESM ABI is documented, SemVer-governed, retained under DCE, and tested from non-Haxe callers.

## 20.5 Migration boundaries

A migration is successful only when the authority change is explicit:

- external PHP/JS → generated adoption contract does not transfer implementation ownership;
- adoption contract + new Haxe implementation + parity tests may transfer one bounded unit;
- generated target files never become the preferred editable source;
- ts2hx output remains review/migration material until accepted as Haxe-owned and covered by runtime parity;
- removing Haxe must remain possible at the same public facade/module boundary for gradual-adoption modes.


---

# 21. Developer experience and tooling

## 21.1 Installation

Recommended development installation:

```bash
# Project-local Haxe dependency management.
npx lix scope create
npx lix install haxelib:wordpress-hx-core@<exact-version>
npx lix install haxelib:wordpress-hx-server@<exact-version>
npx lix install haxelib:wordpress-hx-gutenberg@<exact-version>

# Project-local CLI/build orchestration.
npm install --save-dev @wordpress-hx/cli@<exact-version>
```

A generated project pins Haxe, SDK packages, genes-ts, generic PHP compiler, Node package manager, WordPress profile, and build tooling. Global `haxelib dev` or floating sibling paths are contributor conveniences only and cause `doctor`/release checks to fail.

## 21.2 CLI surface

Proposed binary: `wphx-sdk` until the naming ADR chooses a final non-confusing command.

| Command | Purpose |
|---|---|
| `wphx-sdk init` | Add SDK configuration and build directories to an existing project without taking ownership of existing source |
| `wphx-sdk new plugin` | Scaffold a new Haxe-first plugin |
| `wphx-sdk new mu-plugin` | Scaffold a mu-plugin with correct lifecycle guidance |
| `wphx-sdk new block` | Add static or dynamic block module |
| `wphx-sdk new block-collection` | Scaffold plugin plus multiple blocks |
| `wphx-sdk new theme` | Scaffold Haxe-first theme with external-template coexistence |
| `wphx-sdk new solution` | Scaffold multi-module workspace |
| `wphx-sdk generate rest` | Generate endpoint skeleton from typed contract choice |
| `wphx-sdk generate content-type` | Generate post type/taxonomy/meta declarations |
| `wphx-sdk adopt php` | Generate precise-or-omitted PHP extern/facade contracts |
| `wphx-sdk adopt ts` | Adopt declarations or run optional ts2hx review flow |
| `wphx-sdk build` | Compile, typecheck, emit, validate, and publish generated tree |
| `wphx-sdk dev` | Watch effective inputs and coordinate normal WordPress build tools |
| `wphx-sdk check` | Run type/profile/ownership/generated-code gates without packaging |
| `wphx-sdk test` | Run configured unit/integration/editor suites |
| `wphx-sdk inspect` | Explain generated files, source provenance, dependencies, handles, and profiles |
| `wphx-sdk trace` | Map PHP/JS stack traces to Haxe source |
| `wphx-sdk diff-profile` | Show API/package/metadata differences between exact profiles |
| `wphx-sdk upgrade` | Analyze SDK/profile upgrade and generate a review plan; never auto-accept breaking changes |
| `wphx-sdk clean` | Safely remove only verified manifest-owned files |
| `wphx-sdk package` | Produce validated WordPress ZIPs, checksums, SBOM, and provenance |
| `wphx-sdk doctor` | Diagnose toolchain pins, profile mismatch, PHP/Node/Composer/npm, WordPress test site, and modified artifacts |

Commands have `--json` output for CI and editor integrations. Human diagnostics remain the default.

## 21.3 Scaffold principles

Generators MUST:

- ask or require an exact profile;
- generate the smallest working native project;
- use project-local pins;
- declare which files are handwritten versus generated;
- avoid hidden global state;
- include a real WordPress test path, not only unit tests;
- produce no unsupported API examples;
- use marker-bounded changes for existing hand-owned files and fail on missing/duplicate markers;
- support `--dry-run` with a complete file/action plan;
- remain deterministic.

Generators MUST NOT create dozens of placeholder abstractions, a bespoke service container, or default `Dynamic` facades.

## 21.4 Build commands and stages

A typical project exposes normal package-manager aliases:

```json
{
  "scripts": {
    "hx:build": "wphx-sdk build --profile wp70-release",
    "hx:dev": "wphx-sdk dev --profile wp70-release",
    "hx:check": "wphx-sdk check --profile wp70-release",
    "hx:test": "wphx-sdk test --profile wp70-release",
    "hx:package": "wphx-sdk package --profile wp70-release"
  }
}
```

`build` stage labels should be stable and actionable:

1. `configuration`
2. `profile-resolution`
3. `haxe-typing-and-plan`
4. `php-emission`
5. `browser-emission`
6. `metadata-emission`
7. `format-and-static-check`
8. `asset-build`
9. `artifact-validation`
10. `ownership-publish`

A failure names the stage, source location, generated path if any, profile, and remediation.

## 21.5 Watch workflow

Watch mode fingerprints:

- transitive Haxe sources and HXMLs;
- profile catalogs;
- project configuration;
- resources and HXX inputs;
- Composer/npm lockfiles and package metadata;
- macro-declared external inputs;
- asset source files;
- compiler/toolchain identities.

It coalesces changes and publishes only a complete valid transaction. Browser and PHP rebuilds may run independently when the dependency graph proves isolation. A failed browser typecheck must not publish a new `block.json` that points to a missing bundle.

The default feedback loop is readable console diagnostics plus optional local WordPress reload. HMR is an optimization after correctness and must integrate through ordinary bundler/editor mechanisms.

## 21.6 IDE completion, diagnostics, navigation, and formatting

- Haxe Language Server provides authoring completion/navigation.
- Generated profile catalogs include documentation, upstream package/symbol, classification, and profile availability.
- Macro-generated diagnostics preserve source spans and avoid “error in generated expression” where a user declaration can be named.
- `wphx-sdk inspect symbol <ref>` opens or prints the upstream evidence and generated target shape.
- Generated PHP/TS includes source references suitable for editor navigation through a language-server extension or CLI URI.
- Haxe formatting is standardized repository-wide.
- Generated TS/TSX/PHP formatting is deterministic and executed inside the artifact transaction.
- The SDK does not require a custom IDE to remain usable.

## 21.7 Diagnostics quality

Diagnostics use stable codes and contain:

- what contract failed;
- native WordPress/Gutenberg name;
- selected profile;
- Haxe source span;
- expected and actual types/values;
- why runtime detection is or is not sufficient;
- one or two concrete fixes;
- documentation/ADR reference.

Examples:

```text
WPX2102: Hook callback for `the_content` must return PostContentHtml.
Received: Void at src/server/ContentFilters.hx:31.
This is a filter, not an action. Return the transformed value or bind to a different hook.
```

```text
WPX3307: Block attribute `count` defaults to 0, outside declared range 1...24.
Declaration: src/blocks/BookGridBlock.hx:14.
The invalid default would be emitted into block.json and rejected before registration.
```

## 21.8 Generated-output inspection

`wphx-sdk inspect build` should provide:

- module → generated files;
- source declaration → PHP/TS/JSON ranges;
- package import → script handle/dependency;
- block → metadata/assets/render callback;
- REST endpoint → PHP registration/client function/schema;
- public export → PHP/ESM ABI;
- unsafe boundary inventory;
- stable/experimental/private API inventory;
- profile requirements;
- generated file ownership and hash status.

A `--why <path>` command explains exactly why a file exists. This is critical for trust and debugging.

## 21.9 Schema/API discovery

Provide read-only discovery commands:

- list profile WordPress functions/classes/hooks used or available;
- list Gutenberg packages/exports and classifications;
- search hook signatures;
- show block metadata keys and profile support;
- inspect script handles and package dependencies;
- inspect third-party adoption contract coverage;
- diff SDK/profile versions before upgrade.

Discovery output is generated from locked evidence and must not imply runtime support merely because a symbol was inventoried. Each entry shows `inventoried`, `typed`, `generated`, `runtime-tested`, or `production-supported` status.

## 21.10 Safe regeneration and stale cleanup

The CLI always performs ownership preflight. It supports:

- `--dry-run` file plan;
- `--diff` staged target diff;
- `--check` no-write reproducibility check;
- `clean` manifest-only deletion;
- recovery of interrupted transaction;
- explicit `adopt-generated` flow;
- stale artifact report grouped by module/source deletion.

There is no `--force` flag that overwrites modified/unowned files. A deliberate destructive recovery requires a separate command, explicit paths, and backup output.

## 21.11 Upgrade and compatibility diagnostics

`wphx-sdk upgrade --to <version/profile>` produces:

- package and toolchain changes;
- public Haxe API breaking/deprecation changes;
- profile API additions/removals/classification changes;
- generated PHP/TS/metadata diffs;
- block serialization/deprecation risk;
- REST schema/client changes;
- PHP/Node/browser support changes;
- new unsafe boundaries or emitted `any`/`unknown`;
- required migration actions and test matrix.

The command does not rewrite source across breaking changes without a separately reviewed codemod. It can generate patches into a review branch/directory.

## 21.12 Escape-hatch developer workflow

When a supported API is missing, documentation should direct users to:

1. verify profile availability;
2. generate or write a narrow extern/adoption contract;
3. add a typed facade and runtime fixture;
4. file a catalog/compiler issue if the limitation is generic;
5. use a reviewed unsafe boundary only if delivery cannot wait;
6. assign a removal gate.

“Use `untyped`” is never the primary troubleshooting advice.

---

# 22. Testing and evidence architecture

## 22.1 Evidence principle

A typed declaration, generated file, snapshot, or mocked test is not proof that WordPress/Gutenberg accepts the artifact. Production support requires a chain from Haxe source through generated artifacts to the real native runtime.

```text
Haxe compile/negative tests
          │
          ▼
generated PHP/TS/metadata validation
          │
          ▼
real WordPress install + PHPUnit/API tests
          │
          ▼
real editor/browser/frontend behavior
          │
          ▼
packaged ZIP install/upgrade/rollback evidence
```

## 22.2 Test layers

### Layer A — pure Haxe/unit tests

May mock external systems. Covers:

- schemas and codecs;
- branded identifiers;
- pure domain logic;
- declaration validation;
- semantic-plan normalization;
- profile capability logic;
- manifest path/hash validation;
- migration functions that are pure;
- HXX AST rules.

### Layer B — compiler/emitter fixtures

May use small target stubs, but must also compile/lint generated output. Covers:

- PHP IR and target shapes;
- genes-ts output and TS strictness;
- source maps;
- block/theme metadata;
- plugin headers/bootstrap;
- deterministic generation;
- negative diagnostics;
- adoption generator precise-or-omitted behavior;
- ownership transaction and rollback.

### Layer C — target runtime micro-fixtures

Uses real PHP/Node/browser runtimes, but may not need WordPress for generic semantics. Covers:

- PHP references, arrays, callables, exceptions, class/function ABI;
- generated JSON codecs on PHP and JS;
- ESM exports and DCE retention;
- React component/hook behavior in controlled fixtures;
- source-map stack correlation.

### Layer D — real WordPress integration

Uses a clean installed WordPress profile with real database. Covers:

- activation/deactivation/uninstall/upgrade;
- hooks and priorities;
- REST routing/permissions/schemas;
- content registration and persistence;
- options/capabilities/nonces;
- dynamic block rendering;
- enqueue/dependency/translation behavior;
- template hierarchy/admin screens;
- non-Haxe PHP caller interop.

### Layer E — real Gutenberg editor/browser

Uses Playwright against a real WordPress editor. Covers:

- block insertion/edit/save/reload/validation;
- InnerBlocks constraints;
- sidebar/SlotFill behavior;
- selectors/actions/store updates;
- keyboard/focus/accessibility;
- frontend rendering and Interactivity behavior where supported;
- non-Haxe JS imports/callers;
- browser source maps.

### Layer F — packaging and downstream

Installs final immutable artifacts into clean environments. Covers:

- ZIP shape and plugin/theme headers;
- absence of build-time dependencies at runtime;
- Composer/autoload behavior;
- upgrade from previous release;
- stale-file handling;
- checksums/SBOM/provenance;
- vanilla WordPress and, when available, future WordPressHx provider compatibility.

## 22.3 What may be mocked

Mocks/fakes are acceptable for:

- pure domain logic;
- codec vectors;
- semantic-plan construction;
- filesystem transaction unit tests in addition to real temp-directory tests;
- HTTP failure shapes in unit tests, provided real `wp_remote_*` integration exists for supported behavior;
- external third-party plugins that cannot legally or practically run in every CI lane, provided support wording says contract-tested rather than runtime-certified.

## 22.4 What must use real installed WordPress

The following cannot be production-certified through mocks alone:

- plugin/mu-plugin loading and lifecycle;
- hook ordering/removal and global filter behavior;
- REST registration, permission callbacks, nonce/cookie behavior, and schema exposure;
- post type/taxonomy/meta/options/settings persistence;
- users, roles, and capabilities;
- `WP_Query`, `$wpdb`, caching, cron, media, mail, or template behavior when claimed;
- block registration/rendering/parser validation;
- script handles, dependency extraction, asset metadata, translations;
- admin screens and AJAX;
- theme hierarchy and template inclusion;
- editor package integration and SlotFill;
- frontend hydration/interactivity;
- package activation/update.

## 22.5 Strict Haxe typing gate

- compiler warnings treated as errors for SDK source;
- escape-hatch inventory has no unwaived entry;
- public API signatures contain no `Dynamic`;
- structural types are closed where the provider contract is closed;
- nullability is explicit;
- profile-conditional branches compile in every declared profile;
- negative fixture suite verifies prohibited code fails for the intended diagnostic code.

## 22.6 Generated PHP gates

Blocking for release:

- lint every PHP file on the syntax-floor runtime;
- static analysis with WordPress stubs;
- PHPCS WordPress standards;
- public reflection snapshot for names, parameters, references, defaults, visibility, and return types where declared;
- no unexpected global symbols;
- native array/callable/reference runtime fixtures;
- stack trace/source correlation fixture;
- no direct output before headers from plugin bootstrap;
- direct file guards where required;
- real activation and request execution.

Generated code review should sample every new emitter construct, not only changed examples.

## 22.7 Generated TypeScript/TSX/JavaScript gates

- strict typecheck with exact TypeScript version(s);
- emitted `any`/`unknown` inventory diff;
- module resolution against selected profile packages;
- ESM import/export and side-effect tests;
- classic JS differential lane for representative source;
- React/TSX render and event tests;
- bundle and source-map validation;
- DCE/public export retention;
- no undeclared globals;
- browser runtime tests in editor/frontend.

## 22.8 WordPress PHPUnit/integration architecture

Maintain two families:

1. **SDK fixture tests:** generated plugin/theme code tested with WordPress test suite and real DB.
2. **Consumer-style tests:** a normal PHP test project installs the packaged artifact and calls public APIs without Haxe test helpers.

The test harness pins the WordPress source/distribution profile and records database/PHP details. Tests must avoid depending on state left by earlier suites.

## 22.9 Plugin/theme activation tests

For every release example and template:

- install ZIP into a clean site;
- activate through CLI/admin-equivalent native action;
- verify no PHP warning/fatal/output corruption;
- verify declared tables/options/roles/content types;
- deactivate/reactivate;
- uninstall according to data policy;
- network-activate only for artifacts claiming multisite support;
- run on PHP floor and primary PHP versions.

Theme tests additionally activate, load frontend/admin, and verify required templates/assets.

## 22.10 Gutenberg Playwright tests

Blocking MVP scenarios:

- open editor and wait for no console errors;
- insert static block;
- edit attributes and verify controls;
- save, reload, and verify no block validation warning;
- inspect frontend saved markup;
- insert dynamic block and verify editor preview/server render;
- open sidebar/SlotFill via mouse and keyboard;
- trigger typed store action and observe selector update;
- verify undo/redo where state changes content;
- verify translation strings load;
- intentionally trigger a browser error in debug fixture and validate source mapping.

Tests use stable accessibility roles/labels rather than fragile internal selectors where possible.

## 22.11 Frontend rendering, hydration, and interactivity

For features with frontend JavaScript:

- verify server HTML before JS;
- verify behavior after JS loads;
- verify no-JS baseline where promised;
- verify initial state codec and hydration mismatch absence;
- verify navigation and repeated mount/unmount;
- verify multiple block instances and namespace isolation;
- verify error behavior and console cleanliness;
- measure added requests and bundle size.

Interactivity API production support requires these tests on every claimed profile.

## 22.12 Accessibility and keyboard gates

- automated axe or equivalent checks in editor and frontend;
- keyboard-only operation for extension controls;
- focus entry/exit and restoration for sidebars/modals/popovers;
- accessible names/descriptions and error messaging;
- color/contrast checks for SDK-owned styles;
- reduced-motion behavior where animations exist;
- screen-reader announcement behavior for notices and dynamic updates where relevant;
- no accessibility regression accepted solely because the native component is being used incorrectly.

Manual assertions and test instructions supplement automation.

## 22.13 Visual regression

Post-MVP blocking for theme/component surfaces and recommended for MVP reference UI:

- fixed WordPress/profile, browser viewport, font/assets, locale, and seed content;
- editor and frontend screenshots;
- semantic masks only for genuinely nondeterministic content;
- review threshold tied to component area rather than whole-page noise;
- visual approval does not replace DOM/accessibility tests.

## 22.14 Source maps and stack traces

Release evidence includes:

- Haxe → generated TS line mapping;
- bundled JS → Haxe mapping or documented two-stage resolution;
- generated PHP public adapter frame readability;
- private PHP → Haxe map;
- normalized local/container paths;
- mapping after production minification where maps are generated;
- CLI trace tool tests with representative WordPress logs.

## 22.15 Deterministic rebuilds

CI performs at least one isolated double build:

- fresh temp roots;
- same source/toolchain/environment whitelist;
- byte-compare generated tree, manifests, and package archive;
- fail on absolute paths/timestamps/unordered metadata;
- separately verify signed/attested envelope reproducibility rules.

## 22.16 Asset metadata and script-handle parity

For every browser entrypoint:

- compare generated/imported package dependencies to final `*.asset.php` or script-module metadata;
- verify registered/enqueued handles and versions in real WordPress;
- verify translations attach to the actual handle;
- test legacy `wp.*` global mapping where supported;
- reject missing or extra dependencies that change runtime order;
- run both development and production bundle modes.

## 22.17 Packaging, install, and update tests

- inspect ZIP path normalization and file permissions;
- reject source secrets, caches, test databases, node modules, or build-only toolchains;
- verify plugin/theme metadata through native WordPress discovery;
- install from ZIP in clean site;
- upgrade from previous stable artifact with representative data;
- verify data-version routine and stale generated file removal inside the package build, not on user sites;
- verify rollback instructions and compatible data behavior where promised;
- validate checksums, SBOM, license inventory, and provenance.

## 22.18 PHP and browser compatibility matrix

MVP release lanes should distinguish:

- **blocking syntax floor:** PHP 7.4;
- **blocking primary:** PHP 8.4 based on supplied oracle evidence, subject to project pin;
- **additional:** selected intermediate PHP and PHP 8.5 after pinned validation;
- **database:** MySQL and MariaDB exact versions;
- **browser:** Chromium blocking; Firefox/WebKit required before broad production-ready browser wording;
- **Node/TypeScript:** exact toolchain pins, no floating latest.

Every matrix cell reports `not-run`, `failed`, `passed`, or `unsupported`; blank cells are not interpreted as support.

## 22.19 Performance and bundle-size tests

Benchmarks compare equivalent native hand-written oracles:

- plugin boot and hook callback;
- REST request encode/decode/handler;
- dynamic block render;
- static block bundle gzip size and parse/execute time;
- editor extension interaction latency;
- clean/incremental build time;
- package size and class/autoload count.

Run multiple iterations, record hardware/container, median and tail values, and retain raw results. Do not publish universal speed claims from one runner.

## 22.20 Security gates

- nonce/capability negative tests;
- sanitization/validation/escaping corpus;
- XSS payloads through HXX, REST, block attributes, admin forms, and dynamic render;
- SQL placeholder/raw boundary checks;
- SSRF/redirect tests for HTTP helpers when supported;
- dependency and container vulnerability scans;
- secret scan;
- package integrity/provenance checks;
- unsafe-boundary inventory review;
- generated-code diff review for new emitter constructs;
- no critical/high known vulnerability in shipped supported scope without explicit release stop.

## 22.21 Vanilla and future WordPressHx compatibility

### Vanilla gate

Blocking SDK release gate: run unchanged final artifacts on exact vanilla `wp70-release` source/distribution.

### Future WordPressHx gate

Initially non-blocking because the distribution may not exist or be production-ready. When available:

- the full port pins the exact SDK release and unchanged package hash;
- runs the same integration/editor/frontend suite where applicable;
- reports results to both projects through a receipt;
- a failure does not retroactively invalidate vanilla SDK support unless the shared public contract is wrong;
- once the port publishes a compatible stable provider, dual-provider compatibility may become an SDK downstream gate by ADR.

## 22.22 Evidence ledger

Every public capability has an evidence row:

| Capability | Profile | Typed | Emitted | Static checked | Real WP | Browser | Package | Status |
|---|---|---:|---:|---:|---:|---:|---:|---|
| Typed `init` action | wp70 | yes | yes | yes | yes | n/a | yes | supported |
| Interactivity directive X | forward-23.4 | yes | yes | yes | partial | partial | no | experimental |

“Typed” alone never yields “supported.” Release notes and generated docs consume this ledger.


## 22.23 Exact production-readiness evidence contract

The project **MUST NOT** describe the SDK generically as “production-ready.” A production-readiness claim is valid only for a named SDK version, an exact profile, a published capability ledger, and a finite set of package/toolchain versions. The first eligible wording is:

> `wordpress-hx-sdk X.Y` is production-ready for the documented MVP capability set on the exact `wp70-release` profile.

That wording requires every criterion below. A green typecheck, generated demo, or passing mock suite is not sufficient.

| Required proof | Blocking evidence |
|---|---|
| Frozen claim boundary | A release-committed profile manifest, public API inventory, PHP/browser/toolchain matrix, API-stability classification, and capability ledger with no blank or implied support cells |
| Nontrivial consumer proof | Two packaged reference products: one greenfield plugin/block solution exercising hooks, lifecycle, REST, static and dynamic blocks, an editor extension, a typed store, security, i18n, and ordinary PHP/JS callers; and one mixed-adoption project proving a bounded Haxe island inside existing PHP/JS. At least one consumer must be reviewed or operated by someone outside the SDK core implementation team |
| Final-artifact execution | The exact release ZIPs—not source-tree shortcuts—install, activate, execute, deactivate, upgrade from the previous supported release, and uninstall according to policy in clean real WordPress installations |
| Type and target integrity | Strict Haxe passes; public SDK surfaces contain no unexplained `Dynamic`; generated PHP passes lint, WordPress static analysis, PHPCS, ABI/reflection fixtures, and real execution; generated TS/TSX passes strict checking with an empty unexplained `any`/`unknown` delta |
| WordPress behavior | All advertised server capabilities execute against a real database and exact vanilla `wp70-release`; hook order/arity, permissions, nonces, persistence, render callbacks, assets, translations, and native PHP interop are verified |
| Editor and browser behavior | Playwright passes block insert/edit/save/reload/validation, dynamic rendering, the supported SlotFill/sidebar, typed store behavior, keyboard/focus flows, browser interop, frontend behavior, and console-error checks on the declared browser matrix |
| Security and accessibility | Threat model reviewed; nonce/capability/validation/sanitization/escaping negative corpus passes; no unwaived critical/high vulnerability; automated and manual keyboard/focus/accessibility gates pass for every SDK-owned UI surface |
| Determinism and ownership | Two isolated clean builds produce byte-identical generated trees and unsigned archives; manifests prove ownership; overwrite/collision/stale-cleanup/rollback/recovery tests pass without touching user-owned files |
| Debuggability | Representative PHP, REST, editor, and production-minified browser failures map to useful Haxe source locations; generated public adapters remain readable without proprietary debugging infrastructure |
| Performance and package fitness | Recorded budgets pass for plugin boot, REST, dynamic rendering, editor interaction, bundle/package size, and clean/incremental builds; runtime packages contain no compiler, Node toolchain, source secrets, or undeclared network dependency |
| Release operations | SemVer/stability policy, supported upgrade path, security reporting and patch process, SBOM/license/provenance data, reproducible release instructions, and deprecation policy are published and exercised through a release-candidate rehearsal |
| Defect threshold | No open P0/P1 defect in the claimed scope, no failed blocking compatibility cell, and every accepted P2 limitation is documented in the capability ledger and release notes with an owner or explicit non-support decision |

The gate requires **three consecutive clean release-candidate runs from fresh environments** to expose nondeterministic and order-dependent failures; this is a reliability check, not a substitute for the two consumer proofs. An external security review is required before `1.0` if the SDK ships code-generation paths for authentication, authorization, SQL, HTML, JavaScript, or update/install operations—which the proposed MVP does.

Compatibility with a future WordPressHx distribution is reported separately as a provider qualification receipt. Until that distribution exists and runs the unchanged package hash, absence of the second-provider result does not block a carefully scoped vanilla `wp70-release` production-ready claim. Conversely, the SDK **MUST NOT** claim dual-provider production readiness based on contract similarity, full-port scaffolding, or SDK test reuse alone.

---

# 23. Security, accessibility, performance, i18n, and operational requirements

## 23.1 Security model

### Trust boundaries

The SDK must model at least:

- HTTP request input;
- REST path/query/body data;
- block attributes and serialized content;
- post/meta/option/database values;
- user identity, capabilities, and nonces;
- third-party plugin/API values;
- HTML/attribute/URL/JS/CSS output;
- build configuration and environment variables;
- generated-file paths;
- npm/Composer/Haxelib/compiler dependencies;
- package/update artifacts.

### Secure defaults

- REST endpoints require explicit permission policy.
- State-changing admin/HTTP actions require declared nonce and capability checks.
- HXX escapes by output context.
- SQL APIs prepare by construction; raw SQL is explicit.
- File paths are rooted and normalized.
- URL fetch helpers default to WordPress-safe HTTP behavior and explicit allow/deny policies where applicable.
- External plugin capability/version checks are explicit.
- Debug source maps/diagnostics do not expose secrets in production packages.
- Generated plugin bootstrap prevents unintended direct execution where appropriate.

### Security review triggers

A dedicated review is required for:

- new raw target emitter construct;
- new unsafe API classification;
- unserialized/open payload boundary;
- upload/filesystem/archive behavior;
- authentication/authorization changes;
- custom SQL;
- HTML trust constructor;
- remote update mechanism;
- new package installer or code execution path;
- build macro reading external files or environment.

## 23.2 Accessibility requirements

- SDK-authored UI targets WCAG-aligned WordPress/Gutenberg expectations; exact conformance claim requires a separate audit.
- Prefer native WordPress components but test their use, labels, focus, and keyboard behavior.
- Typed component APIs should require accessible names for controls without visible labels.
- HXX should detect obvious invalid relationships where IDs/refs are typed, such as label-to-control references.
- Generated IDs must be stable per instance and collision-safe.
- Editor extensions must not trap focus or rely on pointer-only interaction.
- Dynamic notices and save/error states use appropriate native announcement mechanisms.
- Theme/template examples include semantic landmarks and heading-order guidance.

## 23.3 Performance requirements

### Runtime

- No central SDK runtime bootstrap on every request beyond plugin-owned registration.
- Modules load only when their native WordPress hook/screen/block requires them where practical.
- Browser bundles split by editor/frontend/view entrypoints.
- Dynamic blocks avoid loading editor code on frontend.
- Codecs and abstractions must not copy large native arrays unnecessarily.
- Reflection is a build/adoption tool, not a request-time mechanism.
- Generated PHP remains opcache-friendly and Composer classmaps may be optimized in production.

### Build

- Incremental graph includes only effective dependencies.
- Profile catalogs are pre-generated, not re-scraped from upstream on every build.
- genes-ts and PHP emission may run in parallel after one semantic plan.
- deterministic formatting and typechecking remain mandatory; speed does not justify publishing invalid partial output.

### Measurement

Performance claims require maintained native oracles, pinned environments, raw results, and variance. Regression thresholds trigger review rather than automatic micro-optimization that harms readability.

## 23.4 Internationalization requirements

- One declared text domain per deployable unless WordPress conventions require otherwise.
- Typed message keys include singular/plural/context/placeholder schema.
- PHP and JS use native WordPress gettext/i18n functions.
- Extraction output includes translator comments and source provenance.
- Locale-sensitive formatting uses native WordPress/browser APIs or explicit shared algorithms with two-target tests.
- Right-to-left style generation/integration follows normal WordPress tooling.
- Editor and frontend tests run at least one non-English locale before production-ready status.
- User-supplied content is never treated as a translation key.

## 23.5 Operational and observability requirements

- Generated failures preserve native PHP/JS exception behavior.
- SDK source correlation augments rather than replaces WordPress/PHP/browser logs.
- Public adapters use stable readable names.
- `doctor` reports exact toolchain/profile/package state.
- Build and package manifests are inspectable without proprietary services.
- Runtime logging uses WordPress/PHP mechanisms or explicit project logging adapters; the SDK does not create a mandatory telemetry backend.
- No telemetry is enabled by default. Any optional usage analytics require informed opt-in, documented payload, and privacy review.
- Error messages avoid secrets and sensitive request bodies.

## 23.6 Supply-chain requirements

- Exact dependency pins or lockfiles for release.
- External CI actions pinned to immutable commits.
- Haxelib/npm/Composer package integrity verified.
- Compiler binaries/source and container images recorded by version/digest.
- SBOM for release packages and toolchain artifact.
- Secret and vulnerability scans.
- Reproducible build evidence.
- Protected release credentials and canonical release workflow.
- Third-party generated stubs/contracts record license and provenance.

## 23.7 Data and privacy requirements

The SDK itself should collect no runtime data. Generated applications may process personal data, but schemas should support:

- data classification annotations;
- redaction in logs/errors;
- export/erase hook integration post-MVP;
- explicit retention/cleanup policy for plugin-owned data;
- avoidance of browser exposure for server-only fields/secrets.

These annotations assist developers; they do not automatically establish regulatory compliance.

## 23.8 Operational supportability

A production-supported release requires:

- public security reporting channel;
- supported version matrix;
- patch/backport policy;
- issue severity/triage rules;
- release and rollback owner;
- documented generated-code debugging workflow;
- deprecation windows;
- dependency update cadence;
- honest statement of maintainer capacity.

Green CI without an owner and response policy is not a stable product promise.

---

# 24. Distribution, packaging, versioning, and release policy

## 24.1 Distribution channels

| Artifact | Channel | Contents |
|---|---|---|
| Haxe authoring packages | Haxelib and lix scopes | Source APIs, macros, profile types, HXX/testing packages |
| CLI/build tooling | npm | Node orchestration, generators, package/build tools |
| Generic PHP compiler | Its own Haxelib/repository release | Reflaxe PHP core, runtime/std support, compiler tests |
| Profile data | Bundled with SDK release and checksummed standalone JSON | Exact API/package/hook/handle inventories |
| Consumer PHP dependencies | Composer as project choice | Third-party packages and analysis stubs; bundled into ZIP where required |
| Deployable extensions | WordPress ZIP artifacts | Native PHP/JS/CSS/JSON/assets/autoload and license metadata |
| Source release | Git tag/archive | Hand-authored source, locks, manifests, docs, tests |

## 24.2 Version policy

### SDK SemVer

- `0.x`: APIs may break, but every release still publishes migration notes and exact profile/toolchain support.
- `1.0`: stable public Haxe APIs, CLI commands/options, project/manifest schemas, generated callable ABI, and supported artifact conventions are SemVer-governed.
- Patch: compatible bug/security fixes and profile evidence corrections that do not change public behavior unexpectedly.
- Minor: additive stable APIs, new exact profiles, deprecated APIs, new generator capabilities.
- Major: breaking public APIs, project/manifest schema changes without transparent migration, generated public ABI break, or removal outside deprecation policy.

All public packages stay on one version train through `1.0`. Package manifests list exact compatible sibling versions.

### Profile versions

Profile identity includes upstream baseline and a monotonically versioned SDK catalog revision:

```text
wp70-release/catalog-v1
```

Correcting an erroneous signature may be breaking even if upstream did not change. Release notes classify the impact and regenerate evidence.

### Generated output

Exact formatting is not a public API, but these are:

- declared public PHP symbol names/signatures;
- ESM export names/types;
- plugin/theme/block identities;
- REST and serialization contracts;
- manifest schemas;
- ownership safety behavior;
- source-map lookup contract;
- package layout required by WordPress.

Emitter updates may change private formatting only when deterministic and behavior/static checks remain green.

## 24.3 Release channels

- `nightly`: exact commit, unsupported, no compatibility promise; never used as a floating dependency in release examples.
- `preview`: bounded feature/profile preview with explicit unstable APIs.
- `stable`: passed production-readiness gates for the documented scope.
- security patch releases: prioritized on supported stable lines.

Forward Gutenberg profile work should generally ship as preview/experimental until tied to a supported WordPress release or an explicit Gutenberg-plugin compatibility product decision.

## 24.4 Canonical release workflow

1. Land all changes and pass canonical CI on one exact commit.
2. Freeze toolchain/profile pins.
3. Build packages from a clean checkout.
4. Run full source and installed-package test matrices.
5. Run external clean-project consumer tests.
6. Generate API/profile/claim diffs.
7. Build deterministic WordPress sample ZIPs twice.
8. Generate SBOM, license inventory, checksums, provenance, and signatures/attestations if adopted.
9. Review unsafe-boundary and `any`/`unknown` diffs.
10. Approve release claim matrix.
11. Publish immutable Haxelib/npm/source artifacts from the tested commit.
12. Verify downloaded artifacts and tags.
13. Publish migration/support notes and rollback version.

Local maintainer machines must not assemble unverified release files from a dirty worktree.

## 24.5 Compatibility support policy

Before stable release, choose and publish:

- exact WordPress profile support duration;
- PHP/Node/browser/DB support windows;
- whether old profiles receive security-only fixes;
- how quickly a new WordPress release gets an experimental and then stable profile;
- whether Gutenberg plugin forward profiles are supported independently;
- deprecation period, recommended at least one minor release and a documented migration path for stable APIs;
- compiler pin upgrade policy.

The MVP supports only `wp70-release`; lack of support for another version is an explicit status, not a presumed compatibility failure or success.

## 24.6 WordPress ZIP requirements

- root plugin/theme files at expected paths;
- no enclosing directory ambiguity beyond normal WordPress package convention;
- exact plugin/theme headers;
- production dependencies included;
- no Haxe compiler, npm cache, source fixture, secret, or local absolute path;
- `readme.txt`/metadata as project chooses;
- license notices for generated/runtime/third-party code;
- build manifest, package version, profile, and provenance in a non-executing metadata file;
- install/activate test of the exact final bytes.

## 24.7 Composer policy

Composer is a normal optional/conditional part of build and runtime packaging:

- use it for project dependencies and static-analysis stubs;
- final ZIP includes `vendor/` when runtime dependencies require it;
- generated bootstrap loads one deterministic autoloader;
- avoid forcing production sites to run `composer install` after upload;
- public PHP ABI does not expose internal Composer package classes unintentionally;
- Composer package versions and licenses appear in SBOM.

The SDK should not require a central `wordpress-hx-runtime` Composer package on the server unless measurement proves bundled per-plugin support is unsustainable and an ADR addresses version conflicts.

## 24.8 npm policy

- project-local exact CLI/compiler/build versions;
- normal `@wordpress/*`, React, and WordPress scripts dependencies according to profile/tooling;
- generated browser packages may be published only when they have a stable non-Haxe consumer API;
- package export maps and types are tested;
- no postinstall script may modify files outside the package/project-owned area;
- dependency extraction output is validated against final bundle.

## 24.9 Licensing decision

Licensing is unresolved and requires a dedicated ADR plus qualified review before public release. The decision must separately address:

- SDK Haxe source and WordPress-facing APIs;
- generic compiler packages;
- generated PHP/JS output and copied runtime/std support;
- examples/templates;
- generated contracts derived from WordPress/Gutenberg or third-party metadata;
- compatibility with upstream dependency licenses and intended plugin distribution.

Do not make casual claims that generated output is automatically exempt from, or necessarily subject to, a particular license. The release must publish an intelligible license inventory and output guidance.

---

# 25. Documentation and example strategy

## 25.1 Documentation principles

- Start with ownership, profile, generated-output, and native-runtime mental models.
- Show the generated target shape next to important Haxe APIs.
- Distinguish supported, experimental, inventoried, and aspirational surfaces.
- State when native WordPress/Gutenberg knowledge is required.
- Prefer executable examples and negative diagnostics to broad feature lists.
- Never describe the SDK as a port or count SDK progress as full-port ownership.
- Every versioned guide identifies the exact SDK/profile/toolchain used.

## 25.2 Required documentation sets

### Evaluation and onboarding

- “Should you use this?” comparison with PHP/TypeScript.
- Architecture in ten minutes.
- Install and exact-profile selection.
- Existing project typed-island tutorial.
- New plugin tutorial.
- New static/dynamic block tutorial.
- Debug generated PHP/TS.
- Generated-file ownership and recovery.

### Core concepts

- profiles and capability detection;
- Haxe source authority versus native artifacts;
- server/browser/shared source sets;
- schemas/codecs;
- identifiers and hook contracts;
- HXX and output safety;
- interop/adoption contracts;
- public/experimental/private/unsafe APIs;
- packaging and updates.

### Reference

- public Haxe API docs;
- CLI reference;
- project/manifest schemas;
- exact profile API/package/hook catalogs;
- diagnostic code catalog;
- generated PHP/TS conventions;
- escape-hatch inventory format;
- compatibility and evidence matrix.

### Operations

- CI setup;
- real WordPress test harness;
- PHP/browser matrix;
- source-map and stack-trace workflow;
- package/release provenance;
- security reporting and patch policy;
- SDK/full-port cross-project receipts.

## 25.3 Example portfolio

| Example | Proves | Profile |
|---|---|---|
| `01-existing-plugin-island` | PHP calls generated Haxe; generated Haxe calls adopted PHP | wp70 |
| `02-haxe-plugin` | Lifecycle, hooks, content, REST, admin, package | wp70 |
| `03-existing-gutenberg-block` | Haxe module inside normal npm/TS project | wp70 |
| `04-block-collection` | Static/dynamic blocks, deprecations, InnerBlocks, SlotFill, store | wp70 |
| `05-haxe-theme` | HXX, external templates, hierarchy, `theme.json` | post-MVP wp70 |
| `06-complete-solution` | Plugin/theme/blocks/shared contracts and independent ZIPs | post-MVP wp70 |
| `07-forward-gutenberg-lab` | Separately labeled forward APIs without WP 7.0 claim | forward-23.4 |
| `compatibility-fixture` | Unchanged artifact for vanilla and future WordPressHx provider | wp70 |

Every example is installed and tested from its packaged artifact. Example source does not use hidden test-only APIs unavailable to consumers.

## 25.4 Generated API documentation

Generated reference pages include:

- Haxe symbol;
- native WordPress/Gutenberg symbol/package;
- exact profile(s);
- maturity classification;
- signature and boundary notes;
- generated target example;
- evidence status and tests;
- known gaps/escape requirements;
- upstream source reference.

A search result must not imply support merely because a symbol appears. Status badges are machine-generated from the evidence ledger.

## 25.5 Compatibility documentation

Publish profile diffs that answer:

- package/export added/removed/changed;
- hook/function/class signature changes;
- block metadata changes;
- script handle changes;
- API classification changes;
- tested toolchain/runtime matrix;
- migration impact.

The `wp70-release` and `gutenberg-forward-23.4` pages are visually distinct and cross-link only through an explicit comparison.

## 25.6 Troubleshooting

Troubleshooting should begin from observable native failures:

- plugin does not activate;
- callback signature/priority wrong;
- REST permission/schema mismatch;
- block invalid after reload;
- package import/handle missing;
- editor component crashes;
- generated file modified/collision;
- PHP/JS stack trace points to generated code;
- profile API unavailable;
- third-party adoption contract incomplete.

Each guide shows native WordPress/PHP/browser tools plus SDK correlation commands. It must not instruct users to delete manifests or force-regenerate as a first response.


---

# 26. Milestones with named feasibility gates and acceptance criteria

Milestones are gates, not calendar promises. A gate closes only with executable evidence and immutable receipts. Later work may proceed experimentally, but release claims cannot skip a failed prerequisite.

## Gate G0 — Product authority and baseline lock

**Purpose:** establish the project as an independent SDK product before implementation creates accidental coupling.

**Acceptance criteria:**

- separate repository, governance, issue authority, security policy, and release policy skeleton;
- accepted ADRs for product boundary, repository separation, exact baseline profiles, package topology, and claim language;
- `wp70-release` and `gutenberg-forward-23.4` profile manifests with exact commits and hashes;
- toolchain lock covering Haxe, genes-ts, Reflaxe/native PHP compiler, Node, PHP images, Composer/npm/Haxelib dependencies;
- generated API maturity classification schema;
- no import or path dependency on `wordpresshx-port` internals;
- reference artifact hashes and snapshot methodology recorded.

**Stop condition:** if maintainers will not maintain separate SDK and full-port claims/task authority, do not create the SDK repository; an ambiguous shared project will mislead users.

## Gate G1 — Native PHP boundary feasibility

**Purpose:** prove that a Haxe-authored plugin can present normal WordPress PHP without raw-string scaffolding becoming the architecture.

**Required fixture:** minimal plugin with header, bootstrap, one action, one filter, one public PHP export, activation hook, and one dynamic render callback.

**Acceptance criteria:**

- public files emitted through structured PHP IR/profile;
- private implementation may use stock Haxe PHP only behind documented adapters;
- PHP 7.4 syntax lint and PHP 8.4 execution pass;
- WordPress Coding Standards and selected static analysis pass or produce a bounded reviewed baseline with no correctness/security error;
- callback arity, priority, callable identity, native arrays, `WP_Error`, and one by-reference boundary fixture pass;
- plugin installs/activates in real WordPress 7.0;
- public reflection and non-Haxe PHP caller tests pass;
- representative stack trace maps to Haxe;
- generated PHP is judged readable by at least one reviewer comfortable with WordPress/PHP but not involved in emitter implementation;
- generic compiler changes are extracted/pinned outside WordPress profile code.

**Stop condition:** if public PHP requires pervasive raw templates, leaks opaque runtime wrappers into WordPress APIs, cannot meet the syntax floor, or cannot produce understandable stack frames, pause product breadth and redesign the PHP lane.

## Gate G2 — Strict browser/TSX boundary feasibility

**Purpose:** prove profile-correct Haxe → TSX → WordPress bundle behavior.

**Required fixture:** one real React/Gutenberg component using props, events, a hook, a ref or context boundary, package imports, styles, translations, and a public ESM export.

**Acceptance criteria:**

- genes-ts strict TS/TSX output passes exact TypeScript toolchain;
- no unexplained `any`/`unknown` in user modules;
- imports resolve against `wp70-release` package inventory;
- normal WordPress build/dependency extraction produces correct handles and `*.asset.php`;
- browser runtime, accessibility, visual, keyboard, and source-map fixtures pass;
- selected source also passes classic Genes differential runtime evidence;
- public export survives DCE and is callable from ordinary JavaScript;
- no WordPress-specific compiler branch is added to genes-ts.

**Stop condition:** if strict TSX routinely degrades to weak types or package/dependency output cannot match normal WordPress tooling, narrow the browser promise before building block APIs.

## Gate G3 — Semantic plan and fail-closed ownership

**Purpose:** ensure every later generator is safe and deterministic.

**Acceptance criteria:**

- versioned semantic-plan schema and deterministic canonicalization;
- staged full-tree generation;
- path traversal, symlink, duplicate, case collision, unowned destination, modified owned file, stale modified file, and malformed manifest tests;
- formatter/typechecker/linter execution inside transaction;
- interruption recovery/rollback journal;
- manifest-only clean;
- double-build byte equality and deterministic ZIP proof;
- `inspect --why` provenance for every fixture artifact.

**Stop condition:** any scenario can overwrite or delete unowned/modified source, or a failed build can publish a partial tree.

## Gate G4 — First vertical server plugin

**Purpose:** prove typed WordPress value beyond a wrapper catalog.

**Required fixture:** Haxe-first “Books” plugin with lifecycle, hooks, custom post type/meta/taxonomy, capabilities, nonce-protected admin action, typed REST endpoint/client, i18n, and ordinary PHP export.

**Acceptance criteria:**

- compile-time failures for wrong hook arity, duplicate identifiers, missing permission policy, invalid schema/default, and unsafe output;
- generated root plugin and public PHP remain native-shaped;
- real WordPress lifecycle, persistence, REST, permission, nonce, and upgrade tests;
- generated browser client works and a non-Haxe caller also works;
- shared codec vectors pass PHP and JS;
- package installs from final ZIP on PHP floor and primary lane;
- security corpus passes.

**Stop condition:** server abstractions require developers to bypass types for routine WordPress behavior or hide native failure semantics.

## Gate G5 — Static/dynamic block and editor extension vertical

**Purpose:** prove the Gutenberg product path.

**Required fixture:** one static block, one dynamic block, one deprecation/migration, InnerBlocks use, one editor sidebar/SlotFill, and one custom data store.

**Acceptance criteria:**

- typed `block.json` generation under `wp70-release`;
- static save markup parses, validates, saves, reloads, and renders without recovery prompts;
- dynamic block server callback decodes attributes and returns context-safe HTML;
- asset dependencies, handles, translations, editor/frontend separation, and source maps match final bundles;
- editor Playwright scenarios pass, including keyboard/focus/accessibility;
- data-store selectors/actions are strict and update UI correctly;
- no forward-only API appears in artifacts;
- block deprecation/migration fixtures preserve old content.

**Stop condition:** the SDK must hand-code target-language metadata or casts for ordinary blocks, or generated save markup is not stable under native Gutenberg validation.

## Gate G6 — Gradual adoption and bidirectional interop

**Purpose:** prove the SDK can enter and coexist with existing projects.

**Required fixtures:** existing PHP plugin island, existing Gutenberg npm project, third-party PHP adoption contract, ordinary PHP/JS callers.

**Acceptance criteria:**

- PHP adoption generator is deterministic, precise-or-omitted, and does not execute provider code by default;
- unsupported signatures generate review output rather than `Dynamic`;
- existing PHP calls generated Haxe through stable ABI;
- Haxe calls real existing PHP through a versioned facade;
- existing JS imports generated ESM; generated TSX imports existing package components;
- removal/rollback at the facade boundary is documented and tested;
- generator marker edits fail closed.

**Stop condition:** adoption requires rewriting project ownership wholesale or type safety collapses immediately at common third-party boundaries.

## Gate G7 — HXX server-template pilot

**Purpose:** prove typed server markup without creating a runtime engine.

**Required fixtures:** bounded admin template and bounded theme template plus an external PHP template reference.

**Acceptance criteria:**

- HXX expressions are typed Haxe;
- context-aware escaping is visible in generated PHP/HTML;
- exact/normalized target parity fixture passes;
- template path, locals, and external references are validated;
- generated file participates in ownership/source maps;
- real admin/theme rendering, visual, and accessibility tests pass;
- no HXX runtime ships.

**Stop condition:** template lowering cannot preserve native include/scope semantics for declared supported modes, or safe markup requires frequent raw PHP/HTML escapes.

## Gate G8 — MVP release candidate

**Purpose:** turn feasibility into a bounded supported product.

**Acceptance criteria:**

- G0–G7 closed for the documented MVP scope;
- clean external consumer installs SDK packages and builds the reference plugin from source;
- exact final ZIP passes vanilla WordPress 7.0 install, activation, integration, editor, frontend, package, update, accessibility, security, source-map, determinism, and performance gates;
- public API/diagnostic/manifest/ABI inventories reviewed;
- no open P0/P1 in supported scope;
- unsafe and `any`/`unknown` inventories approved and ideally empty for examples/public APIs;
- support/version/license/security/release policies published;
- claim-evidence matrix contains no unsupported marketing statement;
- independent review challenges output readability, ownership safety, compatibility claims, and full-port separation.

**Non-acceptance:** passing examples on a developer checkout without installed-package and final-ZIP evidence is not G8.

---

# 27. Initial issue/epic backlog with dependencies

## 27.1 Critical path

```text
SDK-000 Product bootstrap
   ├─► SDK-010 Baseline/profile authority
   ├─► SDK-020 Generic PHP compiler extraction
   ├─► SDK-030 genes-ts pin and browser contract
   └─► SDK-040 Semantic plan + ownership

SDK-020 + SDK-040 ─► SDK-050 Hooks/lifecycle ─► SDK-053 REST/content vertical
SDK-030 + SDK-040 ─► SDK-060 Block metadata/static block ─► SDK-062 dynamic/editor vertical
SDK-053 + SDK-062 + SDK-070 interop + SDK-090 test harness ─► SDK-100 package RC
```

## 27.2 Epics

| ID | Priority | Epic/outcome | Depends on |
|---|---:|---|---|
| `SDK-000` | P0 | Bootstrap separate repository, governance, task authority, AGENTS, security/support skeleton | — |
| `SDK-001` | P0 | Accept product-boundary and claim-separation ADR | `SDK-000` |
| `SDK-002` | P0 | Licensing/output-distribution review and provisional policy | `SDK-000` |
| `SDK-003` | P1 | Contribution/release governance and maintainer support contract | `SDK-000` |
| `SDK-010` | P0 | Lock `wp70-release` source/distribution/profile evidence | `SDK-000` |
| `SDK-011` | P0 | Lock separate `gutenberg-forward-23.4` profile and prohibition rules | `SDK-010` |
| `SDK-012` | P0 | Define profile schema, capability tokens, and generated API classifications | `SDK-010` |
| `SDK-013` | P0 | Build profile generator from exact WordPress/Gutenberg evidence | `SDK-012` |
| `SDK-014` | P1 | Profile diff and upgrade diagnostic tool | `SDK-013` |
| `SDK-020` | P0 | Decide/extract generic Reflaxe PHP compiler package boundary | `SDK-001` |
| `SDK-021` | P0 | Generic PHP IR/printer: functions, classes, arrays, callbacks, references, source locations | `SDK-020` |
| `SDK-022` | P0 | WordPress public PHP profile: plugin header/bootstrap/guards/autoload | `SDK-021`, `SDK-012` |
| `SDK-023` | P0 | Public adapter emission for hooks, REST, block render, exports | `SDK-022` |
| `SDK-024` | P0 | Stock Haxe PHP private-lane packaging and boundary audit | `SDK-022` |
| `SDK-025` | P0 | PHP source-correlation map and trace CLI | `SDK-021` |
| `SDK-026` | P1 | PHP coding-standard formatter/static-analysis integration | `SDK-022` |
| `SDK-027` | P1 | Generic PHP compiler upstream fixture/release process | `SDK-021` |
| `SDK-030` | P0 | Pin genes-ts release/commit and run full upstream CI receipt | `SDK-000` |
| `SDK-031` | P0 | Strict TS/TSX output profile and public export retention | `SDK-030`, `SDK-012` |
| `SDK-032` | P0 | React/Gutenberg HXX package and component prop/event/ref fixtures | `SDK-031` |
| `SDK-033` | P0 | WordPress dependency extraction, handles, `*.asset.php`, translations | `SDK-031`, `SDK-013` |
| `SDK-034` | P0 | Browser source-map composition/trace gate | `SDK-031` |
| `SDK-035` | P1 | Classic Genes differential fixture lane | `SDK-030` |
| `SDK-036` | P2 | ts2hx strict adoption integration with loss report | `SDK-030`, `SDK-072` |
| `SDK-040` | P0 | Versioned semantic-plan schema and macro collection | `SDK-001`, `SDK-012` |
| `SDK-041` | P0 | Fail-closed generated-file manifest and transaction | `SDK-040` |
| `SDK-042` | P0 | Deterministic build fingerprint and double-build gate | `SDK-040`, `SDK-041` |
| `SDK-043` | P0 | CLI build/check/inspect/clean/doctor foundation | `SDK-040`, `SDK-041` |
| `SDK-044` | P1 | Watch graph and atomic incremental publish | `SDK-042`, `SDK-043` |
| `SDK-045` | P1 | Scaffold generators for island/plugin/block/solution | `SDK-043` |
| `SDK-050` | P0 | Typed hook catalog subset, custom hook contracts, priority/arity/removal | `SDK-013`, `SDK-023` |
| `SDK-051` | P0 | Plugin/mu-plugin lifecycle and versioned upgrade routines | `SDK-022`, `SDK-041` |
| `SDK-052` | P0 | Security boundary types: nonce, capability, validation, sanitization, output contexts | `SDK-012`, `SDK-021` |
| `SDK-053` | P0 | Content type/meta/taxonomy typed declarations and generated registration | `SDK-050`, `SDK-052` |
| `SDK-054` | P0 | REST contract, permission policy, PHP registration, codecs, generated client | `SDK-023`, `SDK-031`, `SDK-052` |
| `SDK-055` | P0 | Typed i18n keys, PHP/JS lowering, extraction/translation metadata | `SDK-023`, `SDK-033` |
| `SDK-056` | P1 | Options/settings/admin forms/notices | `SDK-052`, `SDK-053` |
| `SDK-057` | P1 | Bounded `WP_Query` typed arguments and result wrappers | `SDK-053` |
| `SDK-058` | P2 | WP-CLI and cron packages | `SDK-050`, `SDK-052` |
| `SDK-060` | P0 | Typed block declaration and profile-specific `block.json` generator | `SDK-032`, `SDK-033`, `SDK-040` |
| `SDK-061` | P0 | Static block edit/save, attributes, serialization, deprecations | `SDK-060` |
| `SDK-062` | P0 | Dynamic block PHP render boundary and server/editor preview | `SDK-023`, `SDK-060`, `SDK-052` |
| `SDK-063` | P0 | Editor plugin/sidebar/SlotFill typed example | `SDK-032`, `SDK-033` |
| `SDK-064` | P0 | Custom data store plus selected native selectors/actions | `SDK-031`, `SDK-013` |
| `SDK-065` | P1 | InnerBlocks, variations, styles, transforms, richer supports | `SDK-061` |
| `SDK-066` | P1 | Patterns, bindings, categories, rich-text formats | `SDK-065`, `SDK-014` |
| `SDK-067` | P2 | Interactivity API bounded end-to-end package | `SDK-062`, `SDK-014` |
| `SDK-070` | P0 | PHP adoption contract schema and precise-or-omitted generator | `SDK-021`, `SDK-041` |
| `SDK-071` | P0 | Bidirectional PHP facade/export ABI and non-Haxe caller tests | `SDK-023`, `SDK-070` |
| `SDK-072` | P0 | JS/TS package adoption and generated ESM export contracts | `SDK-031`, `SDK-041` |
| `SDK-073` | P1 | Third-party plugin contract package/version capability system | `SDK-070`, `SDK-012` |
| `SDK-080` | P0 | HXX architecture ADR and parser dependency decision | `SDK-001` |
| `SDK-081` | P1 | Server HXX typed AST/output-context lowering | `SDK-052`, `SDK-080`, `SDK-021` |
| `SDK-082` | P1 | Admin template pilot and native parity fixture | `SDK-081`, `SDK-056` |
| `SDK-083` | P1 | Theme manifest/external templates/HXX hierarchy pilot | `SDK-081`, `SDK-055` |
| `SDK-084` | P2 | `theme.json`, design tokens, patterns, full theme package | `SDK-083`, `SDK-014` |
| `SDK-090` | P0 | Real WordPress 7.0 Docker/test harness and database lanes | `SDK-010` |
| `SDK-091` | P0 | WordPress PHPUnit/plugin activation/package consumer suite | `SDK-090`, `SDK-051` |
| `SDK-092` | P0 | Gutenberg Playwright/editor/frontend suite | `SDK-090`, `SDK-061`, `SDK-063` |
| `SDK-093` | P0 | Security corpus, dependency/secret scans, unsafe inventory | `SDK-052`, `SDK-091`, `SDK-092` |
| `SDK-094` | P1 | Accessibility/manual keyboard and visual regression harness | `SDK-092` |
| `SDK-095` | P1 | Performance/build-size benchmark oracles | `SDK-091`, `SDK-092` |
| `SDK-096` | P1 | Future WordPressHx unchanged-artifact compatibility receipt protocol | `SDK-001`, `SDK-100` |
| `SDK-100` | P0 | Reference plugin/block collection vertical integration | `SDK-053`, `SDK-054`, `SDK-061`, `SDK-062`, `SDK-063`, `SDK-064`, `SDK-071` |
| `SDK-101` | P0 | WordPress ZIP packaging, SBOM, provenance, deterministic archive | `SDK-041`, `SDK-091`, `SDK-100` |
| `SDK-102` | P0 | External clean-consumer and upgrade-from-prior-release gates | `SDK-101` |
| `SDK-103` | P0 | MVP claim/evidence review and release candidate | `SDK-002`, `SDK-093`, `SDK-095`, `SDK-102` |
| `SDK-110` | P1 | Complete solution workspace with independent modules/packages | `SDK-045`, `SDK-101` |
| `SDK-111` | P1 | Haxe-first theme and deployment manifest example | `SDK-084`, `SDK-110` |

## 27.3 Backlog discipline

Every issue must name:

- product/profile scope;
- source authority;
- layer owner (generic compiler, SDK profile, application API, full port);
- generated artifacts affected;
- real runtime evidence required;
- unsafe/compatibility risk;
- acceptance commands/receipts;
- dependencies and stop condition.

Issues such as “support Gutenberg,” “improve types,” or “make output native” are not actionable and should be rejected until decomposed.

---

# 28. Risk register with mitigations and stop conditions

| Risk | Likelihood | Impact | Mitigation/evidence | Stop or scope-reduction condition |
|---|---:|---:|---|---|
| Public PHP remains opaque or unidiomatic | High | Critical | G1 native review, structured IR, stable names, reflection/stack tests | Pause breadth if ordinary WP developer cannot debug registration/callbacks |
| Custom PHP compiler scope explodes into a second full port | High | Critical | Minimal public constructs, generic extraction, private stock-PHP lane, issue routing | Stop adding APIs until compiler responsibilities are re-partitioned |
| Stock Haxe PHP runtime causes unacceptable size/startup overhead | Medium | High | Dependency-closed runtime, tree-shaking, benchmarks, custom lowering migration | Remove stock private lane from supported production path if budgets repeatedly fail |
| `wp70-release` accidentally imports forward APIs | Medium | Critical | Separate generated packages, forbidden dependency checks, artifact scans | Block release on any forward symbol/package/metadata leakage |
| Profile catalogs are inventories, not accurate semantic contracts | High | High | Curated evidence states, runtime fixtures, no support from inventory alone | Do not expose stable wrapper until signature and behavior are tested |
| Gutenberg package APIs drift rapidly | High | High | Exact profiles, generated diffs, unstable namespaces, support windows | Keep forward surface experimental; do not promise ranges |
| genes-ts emits weak or incorrect TSX for real components | Medium | Critical | Generic fixtures, full compiler CI, strict TS, runtime/visual/source maps, classic differential | Narrow component/API support or block release on compiler defect |
| ts2hx output is mistaken for idiomatic owned source | High | High | Review directory, loss reports, strict mode, parity before ownership | Disable implementation migration in stable CLI if users cannot distinguish status |
| HXX hides escaping or template scope behavior | Medium | Critical | Context types, generated PHP visibility, bounded templates, real parity | Limit HXX to browser or bounded admin components if server semantics cannot be preserved |
| Generated-file system overwrites user files | Low after design | Critical | Manifest hashes, staged transaction, collision tests, no force overwrite | Any data-loss reproduction is P0 and release stop |
| Source maps are incomplete after bundling/minification | High | Medium | Two-stage maps, trace CLI, public adapter readability | Do not claim full source mapping; ship documented partial workflow until fixed |
| Third-party PHP metadata is ambiguous or unsafe to inspect | High | High | Precise-or-omitted, no execution default, version/source hashes | Omit unsupported providers; do not generate broad dynamic facade |
| Native WordPress semantics are obscured by “better” abstractions | Medium | High | target-shaped API review, generated output examples, reject generic CMS layer | Remove/rename abstraction if users cannot map it to upstream docs/debugging |
| Complete-solution layer becomes proprietary site builder | Medium | High | build-only workspace, independent ZIPs, no runtime kernel | Stop workspace feature that requires proprietary runtime routing/storage |
| Security types create false assurance | Medium | Critical | real nonce/capability/XSS/SQL tests, docs distinguish validation/sanitization/escaping | Withdraw “safe” type/API if it can bypass native security requirements |
| Block serialization changes silently | Medium | Critical | golden/native parser roundtrips, deprecation records, upgrade tests | Block release on unreviewed saved-markup diff |
| Asset handles/dependencies differ from final bundle | Medium | High | final-bundle extraction/parity and real enqueue tests | Block affected package release; no manual asset.php patching |
| PHP 7.4 target conflicts with compiler/runtime features | Medium | High | syntax-floor CI from G1, conservative emitted syntax | Raise floor only through ADR and explicit narrower WordPress compatibility claim |
| Test suite is flaky or too slow to gate releases | Medium | High | layered tests, deterministic fixtures, retry policy only for diagnosed external flake | Remove unsupported claim rather than make real runtime test optional |
| Visual/accessibility evidence is superficial | Medium | High | semantic browser assertions, keyboard/manual checks, stable snapshots | Do not claim accessible/production-ready UI without closing failures |
| Licensing of SDK/generated runtime/output is unclear | High | Critical | licensing ADR and qualified review before public release | No public release/package publication until policy is intelligible |
| Monorepo package count becomes operational burden | Medium | Medium | lockstep versions, promote packages only with consumers | Collapse internal packages before `1.0` rather than maintain fake independence |
| Compiler pins become stale or unavailable | Medium | High | immutable source/package mirrors, exact locks, downstream CI | Freeze support or ship patched compiler release; never float to latest silently |
| WordPress/Gutenberg upstream tests are too broad to run | High | Medium | focused real fixtures plus selected upstream suites; evidence ledger | Narrow claims to tested surfaces; do not infer whole-runtime compatibility |
| Maintainer bus factor/support capacity is insufficient | High | High | governance/support policy, release ownership, conservative scope | Do not call stable if security/compatibility response cannot be sustained |
| SDK progress is reported as full-port ownership | Medium | Critical | separate repos/dashboards/claim fields/receipts | Correct release/status immediately; block shared marketing language |
| Full port imports SDK internals or SDK imports port internals | Medium | High | package pins, dependency scans, cross-repo ADR | Break build on forbidden path/import; no release until removed |
| Future WordPressHx provider differs subtly from vanilla | High | Medium | unchanged artifact dual-provider tests, triage ownership | Keep provider claim separate; do not weaken vanilla behavior to fit port internals |
| Broad MVP scope delays all usable evidence | High | High | hard cut line and G1–G5 vertical gates | Defer themes/WP-CLI/Interactivity/broad catalogs rather than weaken core gates |
| Generated PHP/TS diffs are too noisy for review | Medium | Medium | deterministic printer, stable names/order, semantic diff tooling | Treat readability/diff noise as release issue for emitter changes |
| Shared server/browser logic behaves differently across targets | Medium | High | common vector corpus, target-specific boundaries, no broad isomorphism claim | Split implementation by target when equivalence cannot be proven |
| Third-party plugin conflicts with generated namespace/runtime helpers | Medium | High | project namespace, dependency isolation, duplicate/version tests | Redesign support packaging before recommending multi-plugin production use |

---

# 29. Required ADRs and unresolved questions

## 29.1 Required ADRs before implementation breadth

| ADR | Decision |
|---|---|
| `ADR-001 Product and repository boundary` | Separate SDK authority, relationship to full port, claim language |
| `ADR-002 Exact compatibility profiles` | `wp70-release`, `gutenberg-forward-23.4`, no silent mixing, range criteria |
| `ADR-003 Package topology and lockstep versioning` | Public/internal package boundaries and release train |
| `ADR-004 Generic PHP compiler extraction` | Ownership, repository/package, API surface, shared use by SDK/full port |
| `ADR-005 Public versus private PHP emission` | Stock Haxe PHP allowance, public adapter requirements, migration path |
| `ADR-006 Semantic plan and emitter contract` | Schema, source locations, determinism, extension points |
| `ADR-007 Generated artifact ownership` | Manifest schema, transaction, recovery, clean, adoption |
| `ADR-008 Profile generation and API classification` | Evidence sources, public/experimental/private/unsafe/deprecated namespaces |
| `ADR-009 Schema and codec authority` | Canonical schema API and PHP/JS/REST/block derivation rules |
| `ADR-010 Hook contract model` | Built-in/custom/dynamic hooks, arity, priority, callback identity |
| `ADR-011 HXX parser and lowering architecture` | `tink_hxx` dependency/fork policy, server/browser ASTs, no runtime |
| `ADR-012 Output-context safety` | safe HTML/text/attribute/URL/JSON types and raw escape policy |
| `ADR-013 genes-ts output mode and WordPress build integration` | TS/TSX primary, JS differential, package externalization, DCE |
| `ADR-014 Source maps and PHP trace correlation` | map formats, composition, production/debug package policy |
| `ADR-015 Interop/adoption contract format` | metadata precedence, no-execution default, precise-or-omitted, versioning |
| `ADR-016 Project/CLI configuration` | `wordpress-hx.json`, command names, package manager support, effective inputs |
| `ADR-017 Generated output VCS policy` | committed versus regenerated artifacts and release verification |
| `ADR-018 Runtime support packaging` | per-plugin support code, Composer/autoload, namespace/version conflict policy |
| `ADR-019 Security and unsafe-boundary governance` | waiver schema, expiration, release blocking, security review triggers |
| `ADR-020 Licensing and generated output` | SDK/compiler/examples/runtime/output licenses and guidance |
| `ADR-021 Release/support policy` | stable definition, version windows, deprecations, security patches |
| `ADR-022 Full-port compatibility receipts` | exact SDK pins, unchanged artifact protocol, separate evidence ownership |

## 29.2 Explicit unresolved decisions

| Question | Current recommendation | Decision deadline |
|---|---|---|
| Final product/package/CLI name? | Keep `wordpress-hx-sdk` provisional; use non-confusing `wphx-sdk` binary in prototypes | Before public package reservation |
| Is generic PHP compiler a new repo or existing Reflaxe package? | Separate reusable package/repo, jointly consumed; do not place under port internals | G1 start |
| How much arbitrary Haxe does custom PHP target support at MVP? | Only constructs needed by public adapters plus generic foundations; private logic may use stock PHP | G1 exit |
| Does stock Haxe PHP remain supported after `1.0`? | Decide from size/readability/runtime evidence; do not guarantee now | Before G8 API freeze |
| `tink_hxx` dependency, fork, or parser concepts only? | Prefer pinned dependency/adapters; fork only for upstreamed/general changes or unavoidable diagnostics | Before G2/G7 implementation |
| Canonical schema syntax: value builders, metadata, or macro-derived typedefs? | Support builder plus derivation; one semantic schema IR | Before REST/block APIs stabilize |
| Commit generated PHP/TS in consumer projects by default? | Do not force; scaffold CI-regeneration default and offer commit policy | Before first generators |
| Bundle runtime support per plugin or share a Composer package? | Per-plugin namespaced/dependency-closed for MVP to avoid site-level version conflicts | G1/G8 evidence |
| Exact PHP matrix beyond 7.4 and 8.4? | Add one intermediate and 8.5 only after pinned tests | Before preview release |
| Exact Node/package manager? | Project-local exact pin; choose based on WordPress scripts and genes-ts verified lane | G2 start |
| Use `@wordpress/scripts` exclusively? | Default yes; permit adapter contract for equivalent bundlers post-MVP | G2 exit |
| HMR scope? | Not MVP; use normal bundler HMR only if editor state/reload semantics are reliable | Post-MVP ADR |
| React/component type authority? | Exact package declarations/export inventory plus curated tests; no broad source inference | G2/G5 |
| PHP adoption reflection mode? | Disabled by default; isolated opt-in only after threat model | G6 |
| Third-party contract package registry? | Start in application repos; central registry only with provenance/maintenance model | Post-MVP |
| Interactivity API stable package timing? | After static/dynamic/editor vertical and exact profile behavior gate | Post-MVP |
| Theme MVP or post-MVP? | Post-MVP; only bounded HXX template pilot before first SDK MVP | G7/G8 |
| Monorepo packages independently versioned after `1.0`? | Keep lockstep until real independent consumers justify split | Post-1.0 review |
| Licensing? | No release recommendation without dedicated review; generic compiler may differ from WordPress-facing SDK | Before any public release |
| Future WordPressHx compatibility blocking? | Non-blocking downstream receipt until a stable provider exists | When provider publishes candidate |
| Profile source generation against missing standalone Gutenberg snapshot? | Bootstrap from locked full-port inventory, then require direct standalone upstream checkout in SDK CI | G0/G2 |

## 29.3 Questions that should not block bootstrap

These can remain open while G0–G2 proceed, provided no public promise is made:

- full theme API breadth;
- WP-CLI command ergonomics;
- broad `$wpdb` query DSL;
- update-service integrations;
- central third-party contract registry;
- visual site composition UI;
- independent package SemVer;
- HMR;
- broad WordPress version ranges.

---

# 30. Alternatives considered

## 30.1 Option A — SDK-only project; stop the full port

**Advantages:** concentrates resources on an independently useful product; much smaller compatibility surface; faster path to user value.

**Disadvantages:** abandons the research/product objective of Haxe-owned WordPress/Gutenberg runtime implementation; loses a demanding compiler pressure source; cannot test the ideal two-provider compatibility thesis.

**Verdict:** viable as a business/resource choice, but not recommended by this PRD because the prompt establishes the full port as a parallel objective. The projects solve different problems.

## 30.2 Option B — full-port-only project; no SDK

**Advantages:** one repository and task authority; all compiler work justified by port parity; no product-boundary coordination.

**Disadvantages:** users receive little independent value until a vast port is usable; extension-authoring ergonomics become secondary; vanilla compatibility is not the primary contract; typed wrappers/scaffolds risk being misreported as runtime ownership; gradual adoption suffers.

**Verdict:** rejected. A full port is neither a prerequisite nor a substitute for a native-runtime SDK.

## 30.3 Option C — parallel SDK and full port

**Advantages:** independent user value and evidence; shared generic compiler pressure; the SDK provides realistic compatibility fixtures; the port remains free to pursue implementation ownership; two-provider test becomes possible.

**Disadvantages:** coordination, exact pins, duplicate contract inventories, claim-management burden, and maintainer capacity risk.

**Verdict:** recommended, with strict dependency direction and separate repositories/releases/task authority.

## 30.4 Option D — SDK embedded in the full-port repository

**Advantages:** easiest initial code sharing; one lockfile/task system; direct access to inventories and emitters.

**Disadvantages:** strongest risk of circular dependencies and misleading progress; SDK releases become coupled to port internals; vanilla users inherit a massive unrelated repository; product versioning and issue authority blur; port-specific linker assumptions can leak into extension tooling.

**Verdict:** rejected for durable product code. A short PRD/bootstrap experiment may reference copied fixtures, but accepted SDK work belongs in its own repository.

## 30.5 Option E — separate SDK repository

**Advantages:** clear product contract, release cadence, support matrix, documentation, and maturity claims; vanilla WordPress is the direct gate; full port can pin public contracts; generic compiler packages can be shared neutrally.

**Disadvantages:** requires package extraction, cross-repo receipts, and disciplined profile synchronization.

**Verdict:** recommended. Coordination cost is lower than the long-term cost of product and ownership ambiguity.

## 30.6 Option F — use only stock Haxe PHP and hand-written PHP bootstrap templates

**Advantages:** fastest prototype; no new compiler; familiar Haxe target.

**Disadvantages:** public ABI/file shapes remain constrained; hand-written templates become a second authority; references/global functions/conditional declarations/templates are awkward; output may be opaque and runtime-heavy.

**Verdict:** acceptable only as a bounded G1 control/temporary private lane. Rejected as the complete public architecture.

## 30.7 Option G — generate only TypeScript/TSX; keep all server code in PHP

**Advantages:** avoids PHP compiler risk; Gutenberg path can deliver sooner; existing PHP remains native.

**Disadvantages:** loses shared server/client contracts and Haxe-first plugin/theme/product thesis; still needs generated PHP metadata/render boundaries; does not satisfy the requested server SDK.

**Verdict:** useful fallback scope if G1 fails, but not the recommended product.

## 30.8 Option H — generic CMS portability framework

**Advantages:** superficially larger market and provider abstraction.

**Disadvantages:** no second real provider requirement; hides WordPress semantics; weakens types at the most important boundaries; enormous design surface; difficult debugging.

**Verdict:** explicitly rejected until a second independently implemented provider creates concrete common contracts.

## 30.9 Decision matrix

| Criterion | SDK only | Port only | Parallel, embedded | Parallel, separate |
|---|---:|---:|---:|---:|
| Vanilla user value | High | Low/late | Medium | High |
| Full-port objective | None | High | High | High |
| Claim clarity | High | Medium | Low | High |
| Incremental adoption | High | Low | Medium | High |
| Compiler reuse | Medium | High | High but coupled | High through packages |
| Release independence | High | Low for SDK | Low | High |
| Coordination cost | Low | Low | Medium | High |
| Long-term coupling risk | Low | n/a | Critical | Manageable |
| Recommended | No, given parallel objective | No | No | **Yes** |

---

# 31. Recommended first 90-day bounded plan

This plan is intended to answer the riskiest architectural questions and deliver one credible vertical artifact. It does **not** promise a complete WordPress/Gutenberg SDK, Haxe-first theme platform, broad API catalog, Interactivity API, WP-CLI, or multi-version support in 90 days.

## Days 1–15 — Authority, profiles, and executable skeleton

**Outcomes:**

- bootstrap separate repository and governance files;
- accept ADR-001 through ADR-003 in provisional form;
- lock Haxe, WordPress, embedded Gutenberg, forward Gutenberg, genes-ts, Reflaxe/native PHP prototype, Node/PHP images;
- define profile, semantic-plan, evidence, and generated-file manifest schemas;
- import/generate minimal `wp70-release` catalogs for the APIs needed by the vertical sample;
- create empty package topology and canonical CI stages;
- build real WordPress 7.0 test container/site harness;
- implement claim/status vocabulary.

**Gate:** G0.

**Deliverable:** repository can run `doctor`, validate profiles, start a clean WordPress site, and produce a no-op deterministic manifest without generating application code.

## Days 16–35 — Native PHP feasibility and ownership transaction

**Outcomes:**

- decide generic PHP compiler extraction boundary;
- implement/reuse structured PHP IR for plugin bootstrap, classes/functions, arrays/callbacks, references needed by fixture;
- generate root plugin header/guard/autoload and one action/filter/public facade;
- use stock Haxe PHP only for one private implementation module;
- implement staged ownership transaction, collision checks, clean, interruption recovery, deterministic output;
- add PHP lint, floor syntax, PHPCS/static analysis, reflection, stack trace map;
- install/activate generated plugin in real WordPress.

**Gates:** G1 and G3 foundations.

**Go/no-go decision:** if public PHP is not readable, native, and safe without pervasive raw segments, stop feature breadth and redesign the compiler boundary. Do not compensate with more wrappers.

## Days 36–55 — Server vertical: hooks, content, REST, contracts

**Outcomes:**

- typed hook signature/priority/arity API;
- plugin activation/deactivation and versioned upgrade step;
- security/output-context primitives;
- custom post type and metadata schema;
- one typed REST endpoint with explicit permission policy;
- shared PHP/JS codec vectors and generated browser client skeleton;
- typed message keys and translation metadata;
- real WordPress PHPUnit/integration tests and non-Haxe PHP caller.

**Gate:** most of G4.

**Deliverable:** packaged server-only Books plugin vertical with no editor block yet.

## Days 56–75 — Browser/block vertical

**Outcomes:**

- pin/verify genes-ts strict TS/TSX lane;
- React/Gutenberg HXX component fixture;
- profile-aware imports and WordPress dependency extraction;
- typed `block.json` generation;
- one static block with attributes/save/validation/deprecation;
- one dynamic block using the server render boundary;
- one editor sidebar/SlotFill and one typed custom store;
- source maps, translations, assets, Playwright, accessibility/keyboard assertions;
- classic Genes differential fixture for a representative source.

**Gates:** G2 and most of G5.

**Go/no-go decision:** if strict TSX or native block validation requires routine `any`, raw TS, or manual metadata edits, narrow the MVP and fix the generic compiler/profile before adding APIs.

## Days 76–90 — Interop, final package, and evidence review

**Outcomes:**

- PHP adoption generator supports one bounded authoritative metadata source;
- existing PHP calls generated export; Haxe calls real adopted PHP facade;
- ordinary JS imports one generated ESM function;
- integrate complete reference plugin/block collection;
- deterministic final ZIP, SBOM, provenance, install/activation/update test;
- performance baselines against hand-written PHP/TS oracles;
- security corpus and unsafe/weak-type inventories;
- generated-output human review;
- external clean-project install/build test;
- draft preview release notes with explicit unsupported areas and full-port separation.

**Gates:** G6, G8 readiness assessment. G7 HXX server-template pilot may start only if critical path is green; it is not allowed to displace the plugin/block vertical.

## 31.1 What 90 days should not claim

At the end of this plan, the project should not claim:

- comprehensive WordPress server API coverage;
- production-ready Haxe-first themes;
- broad WordPress version support;
- stable forward Gutenberg support;
- full Interactivity API support;
- arbitrary PHP/TypeScript migration;
- compatibility with all third-party plugins;
- full-port progress or ownership;
- `1.0` stability unless the independent evidence review unexpectedly closes every gate.

A credible outcome is a preview-quality, exact-profile vertical with honest compiler and product evidence.

## 31.2 90-day success criteria

The plan succeeds if it produces one final immutable ZIP whose source is Haxe, whose artifacts are native and inspectable, whose server and browser contracts agree, and whose behavior is proven in real vanilla WordPress 7.0—and if it identifies with evidence which compiler/product assumptions failed. A narrower truthful product is preferable to a broad scaffold.

---

# 32. Appendix: inspected repositories, commits, dirty state, and authority

## 32.1 Inspection method

The supplied ZIP archives were unpacked read-only under a separate analysis directory. Applicable `AGENTS.md` files were read before repository content. Repomix XML file entries were extracted without modifying any source repository. This PRD itself is a new artifact outside those snapshots.

Archive SHA-256 values:

| Uploaded archive | SHA-256 |
|---|---|
| `repomix-output.wordpresshx-port.xml.zip` | `c975d91d5057196eb651c1f17000aefcd44445ebff294a4871bfa6ca67bc69a4` |
| `repomix-output.wordpress.xml(2).zip` | `eaf2bd846ea05388dfaa3be13c416d9f98fe819edce1d35f2c1b7f6c306a280f` |
| `repomix-output-genes-ts.xml(3).zip` | `770c338027253e1031e33ef25812dd16a14ff760d6d2fcfb775657ef50b76bca` |
| `repomix-output.haxe.ruby.xml(1).zip` | `1c3185e7721f059dcee36807448cb4cb10b6cdc0d66c2e24425c5359712f3709` |
| `repomix-output-haxe.elixir.xml(4).zip` | `a1fa93fc0be88c832b9e52a45d8a7366df1d80ed39965aad112710e96e6d80a2` |
| `repomix-output-haxe.compilerdev.reference.xml(2).zip` | `d9803c73ae08e0d324c9e9324cc15078122aec342c71c0251190bbb97830bd35` |

No standalone Gutenberg Repomix ZIP was present in the uploaded set. Gutenberg findings therefore come from exact locked manifests, source-unit/package inventories, and repository records embedded in the `wordpresshx-port` snapshot. This is sufficient for profile architecture and pinned evidence, but it is not represented as a direct standalone Gutenberg source inspection. The SDK bootstrap should require a direct exact Gutenberg checkout in its own CI.

## 32.2 `AGENTS.md` files read

| Snapshot/repository | Applicable instructions read | Material constraints carried into this PRD |
|---|---|---|
| `wordpresshx-port` | root `AGENTS.md` | SDK/full-port claim separation; custom public PHP lane; no raw target shortcuts; generated ownership; exact evidence |
| genes-ts | root `AGENTS.md` | generic compiler fixes only; TS and classic JS both first-class; strict weak-type policy |
| RailsHx/Reflaxe.Ruby | root `AGENTS.md` | generated output as product surface; target compatibility floor; fail-closed ownership; gradual adoption |
| PhoenixHx/Reflaxe.Elixir | root and docs `AGENTS.md` | native output model; HXX compile-time only; strict interop; manifest-backed generation |
| WordPress oracle | no applicable `AGENTS.md` found in snapshot | upstream source treated as runtime authority |
| combined compiler reference | no applicable root instruction for Haxe/Reflaxe/tink_hxx; an unrelated Rails file was not applied | source used as compiler/HXX reference only |

## 32.3 Repository and snapshot state

“Dirty state” below is reported only where the supplied evidence records it. A Repomix archive does not generally contain enough information to reconstruct `git status`; unknown is stated rather than guessed.

| Repository/reference | Commit/ref observed | Dirty/worktree state observed | Inspection role |
|---|---|---|---|
| `wordpresshx-port` / `wordpress-hx` full port | Root archive commit not encoded in the supplied Repomix XML; exact program HEAD therefore **unknown** | Root dirty state **unknown** from archive | Directly inspected product/architecture evidence; authoritative for its own port policy and recorded pins, not vanilla runtime behavior |
| Vanilla WordPress `wordpress-develop` | `26b68024931348d267b70e2a29910e1320d0094f`, tree `f3ad96f2357d2309f64a8d42a5808be502639c70`, lightweight tag `7.0.0` in full-port repository map | Recorded as detached HEAD with Repomix artifacts untracked | Direct WordPress snapshot plus locked record; authoritative oracle for `wp70-release` behavior/contracts |
| Embedded Gutenberg for WordPress 7.0 | `a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd` | Standalone worktree state not available | Locked embedded browser/package baseline for `wp70-release` |
| Forward Gutenberg | `98a796c8780c480ef7bcfe03c42302d9564d785c`, tree `ca453617695fda86c57c4a731475f4ae1c5aad9f`, tag `v23.4.0` | Recorded as detached HEAD with Repomix artifacts untracked | Indirectly inspected through full-port locks/inventories; authoritative only for forward profile evidence, not a WordPress 7.0 claim |
| genes-ts | Full-port pin `45a020e0e9abb9d335020be014afff09b6f8c02f` (`v1.13.0-13-g45a020e`) while the uploaded package metadata reports a later package version `1.32.0`; the archive’s own exact Git HEAD was not encoded | Full-port lock records untracked `genes-ts.xml` and `repomix-output-genes-ts.xml.zip`; tracked dirty state not reported | Direct compiler/docs snapshot; generic TypeScript/TSX/JS authority for the inspected implementation, with exact release pin to be re-established during SDK bootstrap |
| Reflaxe.Ruby / RailsHx | Archive exact HEAD not encoded. Snapshot documentation records immutable `v1.0.0` released from `82f7b09d807bd468febd98bf540a391d3484857a`; this is release evidence, not asserted as archive HEAD | Unknown from archive | Architectural precedent for gradual adoption, typed views, generators, interop, routing authority, and fail-closed generated ownership; not WordPress authority |
| Reflaxe.Elixir / PhoenixHx | Archive exact HEAD not encoded. Readiness review baseline: `v0.18.0`, commit `dae5b4d2507982fc3084aeec43bdade7f9c81a25` | Unknown from archive | Architectural precedent for native output, HXX, Mix workflow, router DSL, Ecto boundaries, transactional ownership; not WordPress authority |
| Haxe compiler | `e0b355c6be312c1b17382603f018cf52522ec651`, tag `4.3.7` | Full-port lock: detached with untracked generated/test artifacts; no tracked dirty files observed | Direct compiler/PHP generator and stdlib reference |
| Reflaxe | `3ec70a83936a8919e5441e03a6fdc1b17ec79881`, branch `main` in included Git metadata | Full-port lock records untracked `repomix-output-reflaxe.xml`; tracked dirty state not reported | Direct generic custom-target framework reference |
| `tink_hxx` | `75ef63c78851fcd7c1846d74959cbd4cea0b4ced`, branch `master` in included Git metadata | Unknown from archive | Direct parser/AST/syntax reference; not a WordPress template behavior authority |
| Combined `haxe.compilerdev.reference` root | Not a single Git repository | Not applicable | Collection of nested compiler/library references |

The genes-ts version discrepancy is important: the full-port toolchain lock pins an earlier exact commit/version while the uploaded genes-ts archive contains package metadata for `1.32.0`. The SDK must establish one exact compiler commit and run its complete test suite; this PRD does not assume the later archive and earlier pin are interchangeable.

## 32.4 Key inspected sources

### Full-port/control-plane evidence

- `docs/prd/wordpress-haxe-port.md`
- `docs/operations/port-philosophy.md`
- `docs/operations/ownership-state-model.md`
- `docs/operations/hhx-template-policy.md`
- `docs/operations/dependent-libraries.md`
- `docs/operations/generated-files.md`
- `docs/operations/repositories.md`
- `docs/operations/build-profiles.md`
- `docs/operations/wphx-php-compiler.md`
- `docs/operations/php-abi.md`
- `docs/operations/wp-boundary-types.md`
- `docs/operations/haxe-escape-hatches.md`
- `docs/operations/wp-debug-source-maps.md`
- ADRs 001, 002, 003, 004, 005, 013, 015, 016, and 017
- `manifests/baseline-policy.v1.json`
- `manifests/oracle/vanilla-oracle-baseline.v1.json`
- `manifests/genes-ts/wphx-401-output-modes.v1.json`
- `manifests/genes-ts/wphx-402-browser-inventory.v1.json`
- `manifests/genes-ts/wphx-404-f9-react-tsx.v1.json`
- `toolchain.lock.json`

### RailsHx precedent

- `docs/railshx-gradual-adoption.md`
- `docs/railshx-typed-views.md`
- `docs/railshx-generated-artifact-ownership.md`
- `docs/railshx-routing-design.md`
- `docs/railshx-generator-workflows.md`
- `docs/railshx-generators-and-tasks-design.md`
- `docs/ruby-extension-interop.md`
- `docs/rbs-to-haxe-generator.md`
- `docs/profiles.md`
- `docs/public-contract.md`
- `docs/railshx-production-readiness.md`

Material precedent: mixed applications should remain ordinary; existing templates/code can be external typed contracts; adoption generation is precise-or-omitted and should not execute app code; route ownership modes must be explicit; generated ownership uses checksums and refuses overwrite/delete of modified artifacts.

### PhoenixHx precedent

- `docs/02-user-guide/GENERATED_OUTPUT_OWNERSHIP.md`
- `docs/02-user-guide/HXX_SYNTAX_AND_COMPARISON.md`
- `docs/02-user-guide/INTEROP_WITH_EXISTING_ELIXIR.md`
- `docs/05-architecture/HXX_ARCHITECTURE.md`
- `docs/05-architecture/PHOENIX_OUTPUT_MODEL.md`
- `docs/05-architecture/AUTHORING_PROFILE_CONTRACT.md`
- `docs/06-guides/PHOENIX_GRADUAL_ADOPTION.md`
- `docs/04-api-reference/ROUTER_DSL.md`
- `docs/04-api-reference/MIX_TASK_GENERATORS.md`
- Ecto integration and scaffolding documents

Material precedent: output remains normal host-framework source; HXX is compile-time only; existing code is consumed through typed externs; in-place generation needs manifest hashes, staging, atomic publication, recovery, and collision checks; target-specific APIs remain target-shaped.

### genes-ts / ts2hx evidence

- `docs/OUTPUT_MODES.md`
- `docs/typescript-target/COMPILER_CONTRACT.md`
- `docs/typescript-target/REACT_HXX.md`
- `docs/typescript-target/INTEROP.md`
- `docs/typescript-target/DEBUGGING.md`
- `docs/typescript-target/TYPING_POLICY.md`
- `docs/typescript-target/TYPING_AUDIT.md`
- `docs/ts2hx/USAGE.md`
- `docs/ts2hx/LIMITATIONS.md`
- `docs/PRIME_TIME_CRITERIA.md`
- `docs/PACKAGING.md`

Material evidence: strict TypeScript/TSX and classic JS are separate first-class modes; generated TS is bounded by tested corpora; public exports need retention; weak types require explicit justification; source-map composition has limits; ts2hx is experimental, fail-closed in strict mode, and not a lossless preferred authoring source.

### Haxe/Reflaxe/HXX references

- Haxe `src/generators/genphp7.ml`
- Haxe `std/php/*`, including `php.Syntax`
- Reflaxe README and compiler framework sources
- `tink_hxx` README and `tink.hxx` parser/generator/node/tag sources

Material evidence: stock Haxe PHP provides useful implementation/runtime behavior; Reflaxe supports typed-AST custom targets and manual file output; `tink_hxx` supplies JSX-like parsing and typed tag resolution concepts. WordPress public-file suitability remains an SDK/full-port design responsibility.

## 32.5 Authority classification

| Source | Authority level for this PRD |
|---|---|
| Vanilla WordPress 7.0 source/distribution and executable oracle | **Authoritative** for `wp70-release` WordPress behavior |
| Embedded Gutenberg exact pin and package/artifact evidence | **Authoritative** for the WordPress 7.0 embedded browser baseline, subject to direct SDK re-materialization |
| Gutenberg 23.4 exact pin/inventory | **Authoritative only for the forward profile**; no WordPress 7.0 distribution claim |
| WordPress full-port PRD/operations/ADRs | **Authoritative for full-port policy and recorded experiments**, not for vanilla behavior beyond cited oracle evidence |
| genes-ts/Haxe/Reflaxe source | **Authoritative for inspected compiler implementation/contracts**, with exact pin revalidation required |
| RailsHx and PhoenixHx | **Architectural precedent only** |
| `tink_hxx` | **Markup parser/architecture reference only** |
| This PRD’s proposed APIs and milestones | **Recommendation**, not existing implementation evidence |

## 32.6 Evidence-derived architectural conclusions

1. Stock Haxe PHP is useful for private implementation but insufficient as the sole public WordPress emitter.
2. A reusable custom PHP compiler core should be independent of WordPress and consumed by an SDK WordPress profile.
3. Exact profile separation is already justified by distinct embedded and forward Gutenberg pins; a single “latest Gutenberg” namespace would be unsafe.
4. Generated artifact ownership must be manifest-backed, checksum-verified, staged, and fail-closed.
5. HXX should lower at compile time and coexist with external native templates.
6. genes-ts can support strict TS/TSX on bounded proven corpora, but broad readiness must be earned per SDK usage; ts2hx remains assisted adoption.
7. Gradual adoption works best when ownership direction and native facades are explicit.
8. The SDK and full port should share contracts and compiler packages through exact releases, never circular internals.

---

## Final recommendation

Proceed with a separate `wordpress-hx-sdk` repository only after accepting the product-boundary, exact-profile, PHP-compiler, and generated-ownership ADRs. Build one exact `wp70-release` vertical and make its final native ZIP the organizing artifact. Treat every additional API as a claim that must move through typed, emitted, static-checked, real-runtime, and packaged evidence states. Keep the forward Gutenberg profile visibly experimental, keep the solution layer build-time-only, and stop rather than normalize opaque PHP, weak TSX, unsafe HXX, or ambiguous ownership.
