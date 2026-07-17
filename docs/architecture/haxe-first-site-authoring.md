# Haxe-first site authoring

- Status: accepted product direction; implementation is dependency-gated
- Product owner clarification: 2026-07-17
- Tracking: `wordpresshx-hy6`
- Implements later through: `SDK-045`, `SDK-081`, `SDK-083`, `SDK-084`, `SDK-110`, and `SDK-111`
- Does not claim: implemented scaffolding, HXX lowering, full theme support, or production compatibility

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
wphx dev
wphx check
wphx test
wphx inspect
wphx package
```

Command names remain provisional until the CLI ADR. `dev` may coordinate normal file watching, browser bundling, and page reload. It must not introduce a production application kernel or proprietary PHP hot-reload protocol.

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

## Implementation and evidence sequence

- `SDK-045` proves the Site.hx-centered scaffold and generated ownership boundaries.
- `ADR-011` and `SDK-080` select the HXX parser and lowering architecture.
- `SDK-081` implements typed server HXX and contextual output lowering.
- `SDK-083` proves a Haxe-authored native theme and hierarchy path before the MVP release gate.
- `SDK-084` expands theme metadata, design tokens, patterns, parts, and generated styling.
- `SDK-110` implements the complete multi-deployable solution workspace.
- `SDK-111` is the P0 acceptance vertical: a complete site with zero handwritten PHP, JS/TS, WordPress JSON metadata, or CSS configuration.

Each bead advances only its named evidence. This document defines intended architecture; it does not promote any capability to `typed`, `generated`, `runtime-tested`, or `production-supported`.
