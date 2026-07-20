# Examples

Consumer-facing examples use public SDK paths and are installed and tested from
their generated native packages. Two focused examples are runnable today; they
are small capability proofs, not yet the complete Todo Studio flagship:

| Example | What it proves | Start here |
| --- | --- | --- |
| Editor sidebar | Haxe/HXX registers a native Gutenberg SlotFill extension with typed components and post-type gating. | [`editor-sidebar/README.md`](editor-sidebar/README.md) |
| Todo data-store lab | A compile-time-validated Haxe store drives native `@wordpress/data`, HXX UI, subscriptions, and async error recovery. | [`todo-data-store-lab/README.md`](todo-data-store-lab/README.md) |

Hidden test-only APIs and unsupported capability demonstrations remain
forbidden. Each guide identifies what is production-shaped and what is still
deliberately deferred, so a compiler proof is not mistaken for a complete app.

The planned production-evidence portfolio is led by the flagship Todo Studio
and includes a complete native Haxe-managed WordPress site, a subject-specific
landing page, an editorial blog, an open-source WooCommerce shop, a paid
consultation booking funnel, a native Gutenberg extension/block workbench, and
a community events atlas. A companion recipe catalog maps each public stable
SDK capability and modern architecture lane to a smallest runnable example and
an integrated application—or records that capability as deferred.

Reusable typed WordPress/Gutenberg/provider/token/rendering contracts and the
payment-to-booking state machine belong in SDK packages; site-specific content
and art direction stay here. Each example is Haxe-only on the happy path and
exercises native PHP/server HXX plus the immutable Genes browser path as
applicable. NextJsHx is an optional adapter for examples that explicitly select
it, not a prerequisite for native WordPress examples.

The paid-booking example uses server-verified order state, request-scoped
eligibility, conflict-safe slots, explicit time-zone and retry behavior, and an
offline test payment method. It may not rely on a redirect, browser flag, live
credential, proprietary extension, or unreviewed booking provider. The
Gutenberg workbench must use the public typed block/editor surface and pass
real editor, serialization, preview, accessibility, update, and removal gates.

The exact native WordPress, block-theme, hybrid-island, admin-SPA, decoupled
SPA/PWA, headless SSR/SSG/ISR, BFF, dual-renderer, widget, multisite, and
event-driven coverage is defined in the
[`reference-application-architectures.md`](../docs/architecture/reference-application-architectures.md)
matrix. Its third-party plugin table is a dated research shortlist, not an
admission or support claim.

Design work follows the exact canonical Anthropic frontend-design reference
pinned in
[`haxe-first-site-authoring.md`](../docs/architecture/haxe-first-site-authoring.md#reference-site-design-evidence):
two-pass subject-grounded planning, one memorable signature, genericity review,
real copy, and screenshot-based responsive/accessibility critique. These
requirements are evidence gates, not permission to couple the compiler to an
example aesthetic.
