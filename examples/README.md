# Examples

Reserved for consumer-facing examples that use only public SDK paths and are
installed/tested from their final packages. There are no working examples yet;
hidden test-only APIs and unsupported capability demonstrations are forbidden.

The planned production-evidence portfolio includes a complete native
Haxe-managed WordPress site, a subject-specific landing page, an editorial
blog, an open-source WooCommerce shop, a paid consultation booking funnel, and
a native Gutenberg extension/block workbench. A companion recipe catalog maps
each public stable SDK capability to a smallest runnable example and an
integrated application—or records that capability as deferred.

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

Design work follows the exact canonical Anthropic frontend-design reference
pinned in
[`haxe-first-site-authoring.md`](../docs/architecture/haxe-first-site-authoring.md#reference-site-design-evidence):
two-pass subject-grounded planning, one memorable signature, genericity review,
real copy, and screenshot-based responsive/accessibility critique. These
requirements are evidence gates, not permission to couple the compiler to an
example aesthetic.
