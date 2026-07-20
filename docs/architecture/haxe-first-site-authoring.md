# Haxe-first site authoring

- Status: accepted product direction; site foundation and native plugin bootstrap implemented
- Product owner clarification: 2026-07-17
- Tracking: `wordpresshx-hy6`
- Implements later through: `SDK-045`, `SDK-081`, `SDK-083`, `SDK-084`,
  `SDK-110`, `SDK-111`, and the `SDK-112` through `SDK-120` reference suite
- Does not claim: HXX lowering, full theme/site production, public package installation, or production compatibility

## Outcome

WordPressHx must let a developer maintain a complete WordPress site through Haxe and HXX without requiring handwritten PHP, JavaScript/TypeScript, WordPress JSON metadata, or CSS configuration. Static assets such as images and fonts remain ordinary assets. Native source files remain visible build artifacts and optional interoperability surfaces, but they are not mandatory maintained inputs.

This is the application/site-level alternative to the full WordPressHx port. It aims for the same or similar Haxe-first authoring and refactoring experience over code the project owns while vanilla WordPress and Gutenberg remain the runtime. It does not replace WordPress Core, link a new distribution, or claim Core implementation ownership.

## Authoring contract

The greenfield happy path has one maintained authority:

```text
typed Haxe declarations + Haxe behavior + HXX markup + static assets
```

The CLI and build system derive every native projection required by WordPress and its normal tools:

```text
PHP / HTML / TS / TSX / JS / JSON / CSS / POT / asset metadata / ZIPs
```

Generated projections are manifest-owned, deterministic, staged atomically, and rejected when manually changed. A developer may inspect and debug them, but regeneration never requires copying a fix back into PHP or JavaScript. Source correlation maps generated failures to the originating Haxe span.

Existing projects use the same architecture incrementally. They may keep native implementations authoritative behind typed contracts, introduce one Haxe-owned module, or progress to the complete Haxe-only authoring surface without adopting the full port.

The full-port repository remains useful as bounded prior evidence, not as an SDK dependency. Its typed admin/theme markup pilots already demonstrate typed domain inputs, explicit escaped-value ownership, deterministic WordPress-compatible bytes, file-segment manifests, caller-scope boundaries, and narrow oracle claims. WordPressHx may adapt those concepts and later oracle fixtures with exact per-file provenance. It does not copy the port's Core linker or replacement model, inherit its parity claims, or treat its hand-built markup AST as the SDK's inline-HXX implementation. Receipt `SDK-080-HXX-PARSER-PROTOTYPE` records the first such review.

## Conventional project tree

The exact package and API names remain subject to ADR-003 and ADR-016. The intended user-facing shape is:

```text
acme-site/
├── src/acme/site/
│   ├── Site.hx                    # solution identity, profile, and modules
│   ├── shared/
│   │   ├── Models.hx              # portable DTOs and enums
│   │   ├── Validation.hx          # portable validation rules
│   │   └── Contracts.hx           # server/browser codecs and references
│   ├── content/
│   │   ├── PostTypes.hx
│   │   ├── Taxonomies.hx
│   │   ├── Fields.hx
│   │   └── TestSeed.hx            # optional local/test content seed
│   ├── plugin/
│   │   ├── CorePlugin.hx
│   │   ├── Hooks.hx
│   │   ├── RestApi.hx
│   │   ├── Admin.hx
│   │   └── Upgrades.hx
│   ├── theme/
│   │   ├── Theme.hx               # identity, supports, menus, assets
│   │   ├── Design.hx              # theme.json, tokens, generated styles
│   │   ├── templates/
│   │   │   ├── Index.hx
│   │   │   ├── FrontPage.hx
│   │   │   ├── Single.hx
│   │   │   └── NotFound.hx
│   │   ├── parts/
│   │   │   ├── Header.hx
│   │   │   └── Footer.hx
│   │   └── patterns/
│   │       └── Hero.hx
│   ├── blocks/
│   │   └── hero/
│   │       ├── Block.hx            # attributes, supports, registration
│   │       ├── Edit.hx             # browser HXX
│   │       └── Render.hx           # server HXX
│   └── browser/
│       └── Interactivity.hx
├── assets/                          # images, fonts, and other static bytes
├── test/                            # Haxe plus real WordPress/browser tests
├── .wphx/                           # generated locks and CLI projections
├── build/                           # generated native artifact trees
└── dist/
    ├── acme-core.zip
    ├── acme-theme.zip
    └── deployment.json
```

`Site.hx` is the application authority. Tool bootstrap files that must exist before Haxe macro execution are created and maintained by the CLI under a documented generated boundary. The user should not have to maintain a duplicate JSON module graph.

## Illustrative Haxe surface

This example communicates the desired ownership and type shape. It is not a committed API or valid evidence that these symbols exist:

```haxe
class Site {
  public static final definition = WordPress.site({
    id: SiteId.of("acme-site"),
    profile: Wp70Release,
    modules: [
      CorePlugin.definition,
      AcmeTheme.definition,
      HeroBlock.definition
    ]
  });
}
```

A theme definition owns native WordPress concepts instead of hiding them:

```haxe
class AcmeTheme {
  public static final definition = Theme.define({
    slug: ThemeSlug.of("acme"),
    supports: [TitleTag, PostThumbnails, EditorStyles],
    templates: [
      Template.frontPage(FrontPage.render),
      Template.single(Single.render),
      Template.notFound(NotFound.render)
    ],
    design: Design.definition
  });
}
```

ADR-011 selects Haxe 4 inline markup as the primary HXX surface. A typical component keeps typed data, control flow, and markup together without a string-template wrapper:

```haxe
typedef PostCardProps = {
  final post:PostSummary;
}

class PostCard {
  public static function render(props:PostCardProps):ServerNode {
    return <article class={Styles.card}>
      <h2><WpLink href={props.post.url}>{props.post.title}</WpLink></h2>
      <PostExcerpt value={props.post.excerpt} />
    </article>;
  }
}

class FrontPage {
  public static function render(model:FrontPageModel):ServerNode {
    return <main class={Styles.page}>
      <SiteHeader navigation={model.navigation} />
      <section class={Styles.posts} aria-label={Messages.latestPosts}>
        {for (post in model.posts)
          <PostCard post={post} />
        }
      </section>
    </main>;
  }
}
```

The exact API names remain illustrative. The contract is not: component props, children, named slots, attributes, refs, profile capabilities, and embedded expressions are compile-time checked; target-specific return types select server or browser lowering; generated output contains native structure and framework calls rather than a component registry or HXX runtime.

High-density abstractions cover recurring WordPress concepts such as navigation, template parts, loops, pagination, post fields, nonces, admin notices, forms, block wrappers, media, translations, theme parts/patterns, design tokens, and Gutenberg components. Server abstractions extend the generic typed PHP-markup capability in `reflaxe.php`; the WordPress compiler profile maps them to native semantics. Each abstraction must compile to proportionate, recognizable PHP/HTML or Genes TSX. Concise Haxe is not successful if it produces opaque scaffolding.

Escape hatches follow an explicit checked hierarchy: typed facade first, checked existing native template/component, typed external contract, policy-produced trusted fragment, then a waivered unsafe raw target segment. Escape API names reveal the boundary, and the complete Haxe/HXX happy path requires none of them.

## Build and development flow

```text
Site.hx + module declarations + HXX
                  │
                  ▼
       profile-validated semantic plan
          │             │              │
          │             │              └─ metadata/style emitters
          │             │                 theme.json, block.json, CSS,
          │             │                 translations, asset manifests
          │             │
          │             └─ Genes ──────► strict TS/TSX/JS
          │
          └─ PHP compiler/profile ─────► PHP and PHP/HTML templates
                  │
                  ▼
       ownership manifest + source maps
                  │
                  ▼
       ordinary plugin/theme/block ZIPs
                  │
                  ▼
          unmodified WordPress runtime
```

The intended commands are:

```text
wphx new site acme --profile wp70-release
wphx new plugin acme-plugin --profile wp70-release
wphx dev
wphx check
wphx test
wphx inspect
wphx package
```

[ADR-016](../adr/016-project-and-cli-configuration.md) accepts these `wphx`
names and makes `dev` the one-command initial-build, effective-input watch,
WordPress/Next service, readiness, and reload loop. Typed service declarations
stay in Haxe; a small generated bootstrap exists only for pre-Haxe discovery.
For a generated plugin, its existing `WordPress.plugin()` declaration also
derives the provider, fresh install and activation, readiness, and development-
only full-page reload adapter. No `Dev.wordpress()` call or user-authored PHP,
JavaScript, Compose, ports, or capability configuration is required.
`Dev.wordpress()` remains the explicit typed service surface for other project
kinds and advanced overrides.
`dev` retains the last complete ownership generation on failure and introduces
no production application kernel or proprietary PHP hot-reload protocol.

The first private behavior surface keeps the callback beside the plugin
definition and asks for no PHP, namespace, adapter, autoloader, or package
configuration:

```haxe
final class Site {
    public static final definition = WordPress.plugin({
        titleFilter: filterTitle
    });

    public static function filterTitle(title:String, postId:Int):String {
        return postId > 0 ? title + " · Typed" : title;
    }
}
```

Haxe checks the callback signature and static method identity at compile time.
The build derives a stable private prefix, compiles only the reachable PHP
closure, discards the stock front controller, generates an exact package-local
class map and native `string, int -> string` WordPress adapter, and publishes
everything through the existing ownership transaction. Omitting `titleFilter`
omits the entire private lane. General hooks and lifecycle APIs remain separate
typed surfaces to add only as their runtime boundaries pass evidence.

## Native artifact mapping

| Haxe authority | Native generated artifacts | Runtime authority |
|---|---|---|
| Site and module declarations | project/build plan, deployment manifest, checksums | WordPress install and activation rules |
| Plugin definition and hooks | root plugin PHP, autoload/bootstrap, callbacks, upgrade units | WordPress plugin lifecycle and hook dispatcher |
| Theme definition | `style.css` header, `functions.php`, setup and asset units | WordPress theme activation and setup hooks |
| Server HXX templates | hierarchy-named `.php` and mixed PHP/HTML templates | WordPress native template hierarchy and include behavior |
| Block-template declarations | native block-theme `.html` templates/parts where supported | WordPress block-template parser and editor |
| Block declarations | `block.json`, PHP render adapter, editor/frontend entries | WordPress block registry and Gutenberg |
| Browser HXX and behavior | strict TS/TSX, then normal JS bundles | React, Gutenberg packages, and the browser |
| Design declarations | profile-valid `theme.json`, token projections, CSS | WordPress global styles and the browser cascade |
| Message declarations | POT, Jed JSON, PHP translation metadata | Native WordPress internationalization APIs |

The generated files must remain recognizable to a WordPress developer. Public PHP uses stable project-controlled names and normal WordPress calls. A production server receives no Haxe compiler, SDK CLI, HXX parser, Node toolchain, or proprietary template runtime.

## Server HXX rules

Server HXX is a compile-time typed AST and lowerer, not a runtime templating system.

The default public authoring form is a typed render/template method that returns inline markup directly (`return <main>...</main>`). Its declared server-markup result type or enclosing HXX-enabled component/template contract selects server lowering at compile time. Explicit calls such as the SDK-080 prototype's `ServerHxx.render(...)` are internal macro boundaries or advanced escape hatches, not the normal site-authoring API. Implicit lowering is scoped to declared HXX contexts so unrelated Haxe expressions are never reinterpreted.

- Template identities map to real WordPress hierarchy paths.
- Locals, loop items, component props, children, helpers, and partial refs are typed.
- Text, attribute, URL, JavaScript, JSON, and raw-HTML contexts are distinct.
- Normal interpolation emits visible context-correct native escaping.
- Unsafe raw output requires a narrow explicit unsafe value or waiver.
- Loops and conditionals lower to deterministic PHP control flow and native markup.
- Generated/external ownership is checked before any file is written.
- Source maps and diagnostics point back to the Haxe/HXX source.
- No parser, virtual DOM, router, or template resolver ships with the theme.

WordPress remains the only runtime dispatcher. For example, WordPress selects `front-page.php`; that file calls or contains the generated implementation for the Haxe `FrontPage` template. The SDK does not intercept the request to choose a Haxe template itself.

## Browser HXX rules

Browser components and editor surfaces lower through the pinned Genes compiler into strict TS/TSX and then use the configured normal WordPress browser toolchain. React and Gutenberg component semantics stay visible. Server-only services cannot enter browser modules, and browser APIs cannot enter server modules through shared code.

Shared domain models may cross targets when their codec and behavior contracts are proved on both targets. Theme/server components and React components are target-specific by default; similar syntax does not make their runtime semantics interchangeable.

## Gradual ownership model

The unit of adoption is a bounded application interface:

1. **Typed interface only.** Generate or curate Haxe externs/contracts for existing PHP, plugin, Composer, JavaScript, or TypeScript APIs. Native code remains authoritative.
2. **Haxe-owned island.** Implement one service, contract, callback, block, or template in Haxe and expose a stable native facade to existing callers.
3. **Haxe-owned deployable.** Maintain a complete plugin, theme, or block collection in Haxe while interoperating with native dependencies.
4. **Haxe-only site authoring.** Maintain all owned behavior, templates, metadata, and styling declarations in Haxe/HXX and emit independent native deployables.

Moving forward is optional and reversible at module boundaries. The SDK must not imply that wrapping an API ports its implementation, or that a Haxe-authored plugin owns the WordPress API it calls.

Escape hatches remain available but explicit:

- external PHP templates through typed path/local contracts;
- native PHP/JavaScript externs and stable generated facades;
- third-party assets and normal package dependencies;
- narrow unsafe/raw boundaries with diagnostics and manifest evidence.

The happy path must not require any escape hatch.

## Unified Haxe solution family

WordPressHx should remain composable with the maintainer's broader Haxe compiler and framework family without becoming a monorepo-wide runtime or importing sibling internals.

```text
portable Haxe domain and contracts
        ├─ WordPressHx  → WordPress PHP/themes/plugins + Genes browser assets
        ├─ Ruby/RailsHx → Ruby/Rails artifacts + Genes browser assets
        ├─ NextJsHx     → Next.js TS/TSX adapters
        ├─ reflaxe.go   → Go artifacts
        └─ reflaxe.rust → Rust artifacts

future control-plane tooling may compose versioned manifests and evidence
```

Candidate family contracts include portable result/schema types, compiler metadata, semantic-plan fragments, generated-artifact manifests, source correlation, deterministic packaging vocabulary, and evidence states. A contract becomes shared only after at least two real consumers demonstrate compatible semantics. Until then, the WordPress SDK owns its WordPress-shaped contract.

Cross-project integration requires a public versioned package, schema, or CLI contract; an immutable version/commit and content hash; independent consumer evidence; and a rollback identity. Floating sibling worktrees and private implementation imports are forbidden release dependencies. Cafetera or other future composition tooling may consume published manifests/evidence as a control plane, but it does not become a WordPress runtime dependency.

## Reference application portfolio

The example strategy has two complementary scales. Focused recipes teach and
regress one public capability with the smallest useful Haxe source. Integrated
applications prove that the same contracts compose across WordPress PHP,
server HXX, Gutenberg/Genes, persistence, security, packaging, and—only where
the example explicitly selects it—NextJsHx.

Native WordPress is the primary product lane. A Next.js frontend is an optional
adapter and useful cross-target pressure; it is not required for a native theme,
plugin, block collection, editor extension, or complete WordPressHx site. Each
example names its lanes, and only those named lanes gate completion.

| Bead | Maintained example | Principal contract pressure |
|---|---|---|
| `SDK-111` | Complete Haxe-managed WordPress site | Theme, plugin, blocks, hierarchy, metadata, styles, packaging, and deployment with no required handwritten target source |
| `SDK-114` | Core-only observatory landing site | Editable core-block content, native theme/HXX, focused conversion, and optional dual rendering |
| `SDK-115` | Editorial field journal | Posts, authors, taxonomies, media, search, preview, feeds, block trees, and cache invalidation |
| `SDK-116` | WooCommerce workshop | Products, variants, money, stock, cart, checkout, orders, webhooks, and provider lifecycle |
| `SDK-118` | Paid architecture-session booking | One typed payment-to-eligibility-to-slot state machine reused by server, admin, REST, browser, and optional Next rendering |
| `SDK-119` | Gutenberg extension workbench | Static/dynamic blocks, migrations, InnerBlocks, editor sidebar, data store, patterns/styles, accessibility, and native validation |
| `SDK-120` | Capability recipe catalog | Small runnable examples and a public-capability-to-example conformance matrix |

The paid-booking example must never trust a checkout redirect or client-owned
flag. WordPress verifies an exact paid/completed order and request identity,
then issues request-scoped booking eligibility. Typed states cover unpaid,
eligible, booked, rescheduled, cancelled, refunded, expired, and conflict
outcomes. Slot claims, retries, webhooks, time zones, daylight-saving changes,
and uninstall/data-retention policy are explicit. Automated evidence uses an
offline test payment method; a live gateway or third-party booking provider is
admitted only through the exact open-source provenance and capability policy in
`SDK-117`.

The Gutenberg workbench is deliberately native-WordPress evidence. It must
exercise public Haxe APIs for `block.json`, edit/save/render boundaries,
serialization and migration, server preview, editor SlotFill, a typed data
store, nested blocks, and exact-profile optional capabilities. It cannot use
private Gutenberg imports, example-only compiler branches, or snapshots as a
substitute for real editor and frontend behavior.

### Cohesive Gutenberg authoring surface

`SDK-121` owns the public authoring experience across the Gutenberg capability
families implemented by `SDK-060` through `SDK-067` and the theme/design work in
`SDK-084`. The objective is not just to make one custom block compile. A site
author should be able to build a polished editor and frontend experience in
Haxe/HXX without repeatedly hand-synchronizing PHP registration, React code,
block metadata, serialized markup, theme configuration, styles, translations,
and package dependencies.

The exact-profile catalog covers these families as their native evidence is
admitted:

- core-block references, typed attributes, nested block trees, templates,
  allowed-child/parent/ancestor contracts, locking, and block context;
- static and dynamic custom blocks, edit/save/render separation, supports,
  deprecations, migrations, variations, styles, transforms, and bindings;
- registered starter patterns and categories, synced-pattern content handles,
  templates, template parts, rich-text formats, media flows, design tokens,
  `theme.json`, and generated styling;
- `BlockControls`, `InspectorControls`, toolbars, panels, accessible WordPress
  components, editor plugins, SlotFill surfaces, and profile-stable commands,
  notices, and preferences;
- typed WordPress data stores, selectors, actions, resolution/error states,
  undo-aware updates, and declared dependencies; and
- the native Interactivity API only in profiles and maturity tiers whose SSR,
  state-codec, hydration, navigation, security, and performance behavior has
  passed its separate gate.

Every admitted capability has two layers. A generated low-level facade retains
the exact upstream names, packages, props, metadata, and runtime semantics. A
concise Haxe/HXX abstraction derives duplicated identifiers, registrations,
schemas, assets, and native projection files where the type system can do so
soundly. Authors can drop to the typed facade when the higher-level abstraction
does not fit. Unsupported or private behavior uses an explicit interop or
unsafe boundary; it never widens the normal API to arbitrary strings or weak
values.

The SDK reuses Gutenberg and WordPress components, data registries, editor
state, parser, style engine, and frontend runtime. It does not clone them into a
Haxe component library, state manager, renderer, or site runtime. Ergonomic
Haxe is successful only when its generated PHP, metadata, block markup, and
Genes output remain recognizable and proportionate to those native APIs.

Pattern abstractions preserve WordPress's own lifecycle distinctions. A
source-owned registered pattern is typed HXX plus metadata projected to normal
pattern registration/files. A synced pattern is a persisted WordPress content
entity addressed through a typed ID/status/capability contract; it is not
silently copied into source control or mistaken for a static pattern. Block
templates and template parts likewise compile to their native theme artifacts
and parser-valid block markup. The Haxe layer derives names, categories,
dependencies, attributes, translations, and package placement once, while
still exposing the exact typed low-level registration surface when a site needs
native behavior beyond the concise abstraction.

Reusable models, codecs, identifiers, state machines, components, design
tokens, and provider adapters move to their owning SDK packages. Examples keep
only the subject, content, composition, and art direction that make their user
job concrete. A capability with no sound public typed surface is marked
deferred in the `SDK-120` matrix rather than imitated with raw PHP, JavaScript,
weak types, or hidden test APIs.

## Reference-site design evidence

The user-facing landing, editorial, commerce, paid-booking, and Gutenberg
workbench reference applications use the canonical
[Anthropic frontend-design rubric](https://github.com/anthropics/skills/blob/fa0fa64bdc967915dc8399e803be67759e1e62b8/skills/frontend-design/SKILL.md)
at commit `fa0fa64bdc967915dc8399e803be67759e1e62b8`, blob
`decdff43d05908b4c1fc2cfd2d80fc5743440934`. The rubric is a design-process
reference, not a runtime/build dependency and not copied SDK code.

Each site must pin a concrete subject, audience, and single page job; define a
subject-grounded four-to-six-color palette and deliberate display/body/utility
type roles; compare layout sketches; select one justified signature element;
and critique away choices that could belong to any generic site. Copy uses real
domain content. Responsive, keyboard-focus, reduced-motion, accessibility, and
overflow checks are blocking. Desktop/mobile screenshots and a post-build
critique are retained as evidence. The applications must not converge on one
template, palette, type pair, or fashionable default aesthetic.

## Implementation and evidence sequence

- `SDK-045.1` proves the Site.hx-centered site foundation and generated ownership boundaries.
- `SDK-045.2` proves the concise typed plugin declaration through ordinary PHP, deterministic packaging, compile/watch reuse, and clean WordPress activation.
- `ADR-011` and `SDK-080` select and prototype the exact compile-time HXX parser boundary; native lowering remains later work.
- `SDK-081` implements typed server HXX and contextual output lowering.
- `SDK-083` proves a Haxe-authored native theme and hierarchy path before the MVP release gate.
- `SDK-084` expands theme metadata, design tokens, patterns, parts, and generated styling.
- `SDK-110` implements the complete multi-deployable solution workspace.
- `SDK-111` is the P0 acceptance vertical: a complete site with zero handwritten PHP, JS/TS, WordPress JSON metadata, or CSS configuration.
- `SDK-112` through `SDK-117` build and verify the reusable reference-site
  foundation plus distinct landing, editorial, and WooCommerce integrations.
- `SDK-118` proves a real paid consultation funnel whose server-authoritative
  order and booking state is shared safely across the declared layers.
- `SDK-119` turns the Gutenberg surface into a maintained native editor/block
  workbench rather than treating a visual compiler proof as an application.
- `SDK-120` keeps every public capability connected to a smallest runnable
  recipe and at least one integrated example, or records it as deferred.
- `SDK-121` unifies the exact-profile block, pattern, theme, editor-component,
  data, and interactivity capabilities into one coherent Haxe/HXX authoring
  surface without replacing Gutenberg runtime semantics.

Each bead advances only its named evidence. This document defines intended architecture; it does not promote any capability to `typed`, `generated`, `runtime-tested`, or `production-supported`.
