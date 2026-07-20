# Reference application architectures

- Status: accepted portfolio direction; applications remain planned unless a
  linked evidence receipt says otherwise
- Product owner clarification: 2026-07-19
- Tracking: `SDK-112`, `SDK-113`, `SDK-117`, `SDK-120`, `SDK-122`, and
  `SDK-123`
- Exact research snapshot: 2026-07-19; plugin popularity is discovery input,
  never an admission or security claim

## Purpose

The reference suite must prove more than one attractive frontend. It must show
how the same typed Haxe authority improves several architectures that modern
WordPress teams actually deploy. Each example therefore names an architecture,
a real user job, its runtime owners, and the boundary that WordPressHx makes
smaller, safer, or more maintainable.

Haxe does not flatten the architectures into a generic CMS runtime. WordPress
still owns content, permissions, plugins, PHP lifecycle, block parsing, and the
native APIs used by a lane. Genes owns browser compilation. NextJsHx is used
only by examples that explicitly select a Next.js lane. Shared Haxe domain
types, codecs, state machines, design tokens, and capability contracts may be
reused while target semantics remain visible.

## Architecture showcase matrix

The first nine rows are maintained integrated lanes. The final three are
smaller recipes until repeated demand justifies another maintained application.

| Lane | Request and rendering shape | Best proof application | What the Haxe layer improves |
|---|---|---|---|
| Native server-rendered WordPress | WordPress routes a normal theme request; HXX compiles to PHP/HTML templates; no client runtime is required | Landing, booking, editorial, and public Todo project pages | Typed template models, contextual escaping, hierarchy coverage, hooks, forms, metadata, and one source for PHP plus markup |
| Native block theme and Gutenberg | WordPress renders block templates, parts, registered patterns, synced content, dynamic blocks, and optional core Interactivity directives | Complete site, landing, Gutenberg workbench, and Todo project templates | Typed block trees and attributes, HXX composition, derived `theme.json`/`block.json`, patterns, styles, translations, and compile-time editor constraints |
| Hybrid islands | Server HXX supplies useful initial HTML; narrowly mounted Genes components add rich interactions without taking over routing | **Todo Studio primary lane** and paid booking | One typed server/browser contract, smaller hydration boundary, progressive failure behavior, source correlation, and explicit ownership of every island |
| WordPress-admin application | A Genes/React SPA mounts inside `wp-admin`; same-origin REST, nonces, capabilities, notices, and WordPress components stay native | Todo operations console and Gutenberg workbench | Typed stores/actions/selectors, permission-aware clients, HXX WordPress components, generated assets, and no handwritten JS bridge |
| Decoupled SPA with WordPress backend | A Genes SPA owns the browser route tree while WordPress owns authenticated domain APIs and persistence | Todo board mode and community events explorer | Shared schema-derived REST client, closed loading/error/conflict states, compile-time routes, explicit CORS/auth mode, and portable Haxe domain logic |
| Offline-first PWA | The SPA adds an installable shell, local command queue, cache policy, and deterministic reconciliation with WordPress | Todo Studio optional field mode | Typed offline commands, versioned snapshots, optimistic/conflict state machines, replay invariants, and a visibly bounded service-worker projection |
| Headless SSR, SSG, and ISR | NextJsHx emits a Next.js App Router frontend that reads WordPress through typed REST or an admitted provider; pages choose dynamic SSR, static generation, or revalidation | Editorial field journal, landing, and commerce catalog | Shared content/block unions, server/client component boundaries, preview types, cache tags, invalidation events, and HXX rendering without copied TypeScript models |
| Backend for frontend | Next route handlers/server actions validate, compose, and normalize WordPress plus admitted provider APIs; credentials and provider quirks do not reach the browser | WooCommerce workshop and paid booking | One Haxe contract through BFF and browser, typed provider errors, server-only secrets, webhook/revalidation handling, and explicit authorization boundaries |
| Dual native/headless delivery | The same WordPress content and domain contract is rendered by a native theme and a separately deployed frontend | Landing, editorial, and commerce comparison lanes | Differential fixtures reveal abstraction leaks while keeping common props, tokens, codecs, and block semantics genuinely reusable |
| Embeddable widget or microfrontend | A small Genes bundle mounts into an existing theme or non-WordPress host and talks to a narrow WordPress endpoint | Booking/capture widget recipe | Typed mount props, isolated styles/assets, versioned host contract, small bundle budget, and a safe incremental-adoption path |
| Multisite or multi-tenant WordPress | WordPress Multisite remains the tenant/site authority; generated packages and capabilities are network- or site-scoped | Multisite publishing recipe | Site/network IDs, scoped capabilities, deterministic per-site configuration, upgrade plans, and cross-site leakage negatives |
| Event-driven integration | WordPress hooks, cron, REST callbacks, or webhooks produce explicit idempotent commands consumed by a bounded worker/BFF | Commerce inventory and publishing-invalidation recipes | Typed event envelopes, retry/idempotency policy, signature checks, dead-letter evidence, and no stringly shared payloads |

The matrix is not a promise that every domain should use every lane. The
flagship intentionally has no mandatory Next.js frontend: its primary proof is
that a sophisticated native WordPress application can be authored entirely in
Haxe/HXX. The dual-runtime sites exist where a second renderer teaches a real
contract lesson.

## Application portfolio

| Application | Product experience | Required architecture proof | Optional admitted plugin pressure |
|---|---|---|---|
| **Todo Studio** (`SDK-122`) | A distinctive personal/team work studio with capture, board, list, calendar, focus, collaboration, keyboard and offline/conflict behavior | Hybrid native application; admin SPA; decoupled SPA and PWA variants reuse the same task contract | The Events Calendar for milestone/focus-session overlays; BuddyPress for groups/activity when collaboration earns the dependency |
| Complete Haxe-managed site (`SDK-111`) | A whole installable site, not a component demo | Native block theme, server hierarchy, plugins, blocks, patterns, packages, update and rollback | None required; this is the core-only control |
| Observatory landing (`SDK-114`) | A high-conversion research/consulting landing page with real editorial control | Native server/block theme plus one progressive island; optional dual rendering | Contact Form 7 typed form companion or Polylang only after admission |
| Editorial field journal (`SDK-115`) | Media-rich reporting, authors, series, search, preview, and live publishing | Native WordPress plus headless SSR/SSG/ISR comparison | WPGraphQL as an optional provider; ActivityPub as a federated publishing extension |
| WooCommerce workshop (`SDK-116`) | A tactile product configurator and complete storefront rather than a product-grid mockup | Native WooCommerce plus a NextJsHx BFF/headless storefront | WooCommerce core and its public Store/REST APIs; no paid extension in the baseline |
| Paid architecture booking (`SDK-118`) | A polished consultation funnel that permits booking only after verified payment | Server-first WordPress plus a BFF comparison where useful | WooCommerce order state; Contact Form 7 only if its form boundary adds value without owning payment authority |
| Gutenberg extension workbench (`SDK-119`) | A beautiful editor-native pattern/block/style laboratory | Gutenberg editor extension, dynamic/static blocks, data stores, native frontend | Exact-profile plugin interop recipes, not a private replacement editor |
| Community Events Atlas (`SDK-123`) | A visually rich local-events and community hub with calendars, groups, profiles, activity, saved itineraries, and federated event stories | Native block/hybrid site plus a decoupled explorer; headless rendering is optional evidence | The Events Calendar, BuddyPress, and ActivityPub are independently capability-gated so the core site degrades cleanly |
| Recipe catalog (`SDK-120`) | Small executable explanations and architecture comparisons | Every supported lane gets one clean-consumer recipe or an explicit deferred row | Companion adoption recipes include provider present/absent/update/removal cases |

Every integrated application must be attractive enough to stand on its own,
but visual polish cannot hide a fake backend. Its public tour should make both
sides legible: the user experience, then the compact Haxe/HXX authority, then
the ordinary generated WordPress/Genes/Next artifacts and evidence that tie
them together.

## Plugin research shortlist

These are candidates for `SDK-117`, not approved dependencies. The dated
signals below come from official project or WordPress.org pages and can change.
An actual lock must still verify the exact release artifact, checksum, source,
license, maintainers, supported WordPress/PHP profile, advisories, transitive
runtime behavior, capabilities, and removal path.

| Candidate | Dated official signal | Best Haxe companion idea | Portfolio role | Current disposition |
|---|---|---|---|---|
| [WooCommerce](https://wordpress.org/plugins/woocommerce/) | 10.9.4, updated within two weeks, 7+ million active installs; open-source core with documented REST, Store API, hooks, blocks, and webhooks | Exact money/product/variation/cart/order/webhook contracts plus HXX block and checkout-state ergonomics | Commerce and paid booking | Highest-priority admission candidate; free core only |
| [Contact Form 7](https://wordpress.org/plugins/contact-form-7/) | 6.1.6, 10+ million active installs, source browsable from WordPress.org | A typed form-tag and mail-template DSL where field IDs, validation, messages, and submitted values share one Haxe declaration | Landing, lead capture, and booking intake | Evaluate; core WordPress form abstractions remain the fallback |
| [Elementor](https://wordpress.org/plugins/elementor/) | 4.1.5, updated within five days, 10+ million active installs; free core plus a separate commercial surface | Generate an ordinary Elementor addon from typed Haxe widget/control definitions and server HXX rendering | Interoperability recipe for existing sites | Lab candidate only; never a foundation, never assume Pro, and pin the exact public extension API |
| [Polylang](https://wordpress.org/plugins/polylang/) | 3.8.5, updated within one month, 800,000+ active installs | Typed language/translation references, locale-aware routes, menu/content associations, and missing-translation states | Multilingual landing/editorial comparison | Evaluate after public API and free/Pro boundary inventory |
| [The Events Calendar](https://wordpress.org/plugins/the-events-calendar/) | 6.17.0, updated within two weeks, 700,000+ active installs; free plugin exposes a self-documenting events REST API | Generate precise event/venue/organizer codecs from the exact admitted API document; add HXX calendar/card ergonomics without reimplementing its runtime | Todo calendar companion and Community Events Atlas | Preferred Todo visual-plugin candidate, pending full admission |
| [BuddyPress](https://wordpress.org/plugins/buddypress/) | 14.5.0, updated within two weeks, 100,000+ active installs; community-owned REST resources cover members, activity, groups, messages, notifications, and media | Typed capability-scoped member/group/activity clients and HXX community components | Todo teams and Community Events Atlas | Strong collaboration candidate, optional and independently removable |
| [WPGraphQL](https://wordpress.org/plugins/wp-graphql/) | 2.17.0, updated within four weeks, 30,000+ active installs; project describes itself as free and open source | Schema-introspected Haxe operations/codecs with closed error/data states; REST remains canonical baseline | Headless editorial and optional commerce provider | High-value optional headless provider candidate |
| [ActivityPub](https://wordpress.org/plugins/activitypub/) | 9.0.2, updated within three weeks, 6,000+ active installs; community plugin with public source | Typed actor/activity capability hooks and publication-status diagnostics at the narrow supported boundary | Federated field journal and Community Events Atlas | Visually compelling research candidate; not needed for core use |
| [CoBlocks](https://wordpress.org/plugins/coblocks/) | 3.1.17 and 300,000+ active installs, but its directory page reports testing only through WordPress 6.8.6 | Exact block metadata/attribute adoption and HXX constructors for an admitted subset | Gutenberg visual-block recipe | Hold for the `wp70-release` suite until profile compatibility and maintenance pass admission |

Popularity is deliberately shown next to, but never substituted for, technical
admission. Elementor's commercial split and CoBlocks' profile lag are useful
negative examples: a popular plugin can still be unsuitable for a baseline.

## Companion-package shape

The first integration is app-local. A reusable package is justified only after
two applications need a stable public subset:

```text
packages/providers/<provider>/
├── src/                           # precise Haxe contracts and ergonomics
├── profiles/<provider-version>/  # immutable API/capability inventory
├── fixtures/                     # generated-shape and compile negatives
├── test/                         # boundary tests, not an upstream re-test
└── manifests/                    # source, license, hash, capability evidence

examples/<application>/
├── src/.../providers/             # app-local adoption before graduation
├── assets/
├── test/
└── .wphx/provider.lock.json
```

The installed native plugin remains the runtime owner. The compiler sees
generic external contracts and capability tokens, never provider names. An
inventory generator emits only declarations it can prove. Unknown members are
reported and omitted, not widened to `Dynamic`, `Any`, `cast`, `Reflect`, or
`untyped`. Runtime use requires a fresh capability scoped to the active plugin
identity and request/process lifetime.

## Evidence and presentation bar

Every maintained architecture lane must provide:

- a clean `wphx dev`, `check`, `test`, and `package` path from public packages;
- a fresh WordPress install and exact provider setup where applicable;
- real desktop/mobile screenshots and an interaction journey with keyboard,
  focus, reduced-motion, contrast, loading, empty, error, and recovery states;
- a short Haxe/HXX source tour paired with the generated native artifact and
  source-map trace, so the maintainability gain is inspectable;
- permission, nonce, escaping, malicious-input, provider-absence, update,
  removal, rollback, deterministic-build, performance, and data-retention
  evidence proportionate to the lane; and
- a capability matrix that says `deferred` or `unsupported` instead of filling
  a gap with private APIs, mocks, weak types, or handwritten target code.

This document chooses showcase coverage. It does not promote any application,
plugin, provider, or architecture to `typed`, `generated`, `runtime-tested`, or
`production-supported`.
