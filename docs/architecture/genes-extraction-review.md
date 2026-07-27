# Genes extraction review

- Status: architecture review; no upstream implementation is implied
- Date: 2026-07-27
- Bead: `wordpresshx-sdk-plan.3.1`
- Scope: reusable Haxe-to-JavaScript/TypeScript, React, HXX, export, source-map,
  and validation mechanisms discovered in WordPressHx/GutenbergHx

## Outcome

The dependency direction remains:

```text
Genes generic JS/TS/React capability
  <- WordPressHx/GutenbergHx typed provider and build adapters
  <- WordPress application code
```

NextJsHx is a sibling consumer, not a WordPressHx dependency. It is useful
second-consumer evidence because a capability shared by Gutenberg and Next.js
is unlikely to be intrinsically tied to either framework.

The review found:

1. one strong near-term upstream consolidation: shared React types and Hook
   intent;
2. two promising Genes-owned seams that need a framework-neutral reduction
   before implementation: an external-HXX bridge and a compiler-owned public
   root manifest;
3. two reusable tooling candidates that should wait for a concrete second
   consumer: Source Map v3 consumption/composition and a packaged typing-policy
   runner; and
4. several important WordPress/Gutenberg mechanisms that must remain here.

The sibling `../genes` and `../nextjshx` checkouts were review inputs only.
They are not build inputs, and this document does not bind their mutable HEADs.

## Ownership test

A candidate belongs in Genes only when all of these are true:

1. Its useful contract can be named without WordPress, Gutenberg, Next.js,
   profile, package-handle, block, store, route, or application concepts.
2. A neutral fixture can prove it using ordinary Haxe plus JavaScript,
   TypeScript, TSX, React, or a standard JS tooling format.
3. Genes can own its semantics and diagnostics in both strict TypeScript and
   classic JavaScript output where applicable.
4. Downstreams can supply their framework facts through typed adapters rather
   than making Genes import downstream code or data.
5. Moving it removes a duplicated mechanism or a private compiler coupling; it
   is not an abstraction created only because reuse seems possible someday.
6. Full Genes regression gates and the affected downstream gates can prove the
   change before a downstream pin advances.

Discovery location does not decide ownership. Conversely, a generic-looking
helper does not belong in Genes when its behavior is actually controlled by a
WordPress or framework runtime contract.

## Candidate matrix

| ID | Candidate | Disposition | Why |
|---|---|---|---|
| GXR-01 | React types, tuple/state views, and reusable Hook intent | strong; `wordpresshx-sdk-plan.3.2` | WordPressHx and NextJsHx independently define the same React-shaped types and state ergonomics, while Genes already owns the shared React HXX/type layer |
| GXR-02 | Supported bridge from an alternative compile-time HXX parser into Genes JSX intent | promising; `wordpresshx-sdk-plan.3.3` | WordPressHx currently reaches into `genes.react.internal.Jsx`; parsing and Gutenberg profiles stay downstream, but compiler-marker construction should have a supported generic owner |
| GXR-03 | Compiler-owned manifest of retained public Genes library roots | promising; `wordpresshx-sdk-plan.3.4`, aligned with SDK-072 | Genes owns `@:genes.library` retention and output publication, while WordPressHx currently re-derives compiler facts in a macro-owned export manifest |
| GXR-04 | Strict Source Map v3 reader, lookup, and composition core | defer until a second runtime consumer is committed | the algorithms are general and repeated, but WordPress artifact authentication and trace policy are not compiler responsibilities |
| GXR-05 | Packaged generated-output typing-policy/downstream-contract runner | defer; first prove a stable public tool contract | Genes has reusable internal tooling and WordPressHx repeats parts of it, but project-specific allowlists and profile claims must remain downstream |

## GXR-01: shared React and Hook foundation

### Evidence

WordPressHx currently owns:

- `packages/gutenberg/src/wordpress/hx/gutenberg/react/ReactTypes.hx`;
- `packages/gutenberg/src/wordpress/hx/gutenberg/react/Hooks.hx`; and
- `packages/gutenberg/src/wordpress/hx/gutenberg/react/DomTypes.hx`.

Those files define React nodes, keys, events, refs, contexts, dependency lists,
state tuples, and Hook bindings. Several already duplicate public Genes types:

- `genes.react.Node`;
- `genes.react.Element`;
- `genes.react.MouseEvent`;
- `genes.react.KeyboardEvent`; and
- `genes.react.ReactRef`.

Genes still keeps dependency-list and state-tuple wrappers inside its Todo
example at `../genes/examples/todoapp/src/todo/web/ReactTypes.hx`, rather than
as a reusable public surface.

NextJsHx independently defines the same generic family under
`../nextjshx/src/nextjs/raw/react/` and an allocation-free semantic state view
at `../nextjshx/src/nextjs/client/State.hx`. Its callable-state and dependency
intent checks live in `../nextjshx/src/nextjshx/client/ReactHooksMacro.hx`.
That is concrete second-consumer evidence.

### Genes boundary

The first upstream change should be small:

- close the reusable React context, dependency-list, dispatch,
  state-action/result, and tuple/state-view types under `genes.react` or a
  lower framework-neutral Genes tuple package;
- reconcile `ReactNode` ergonomics with the existing `genes.react.Node`
  contract instead of adding a second node hierarchy;
- reuse existing Genes event, ref, and DOM element types; and
- prove zero-wrapper output and precise TS/TSX projections in both Genes output
  modes.

A later change may generalize Hook intent such as “eager replacement versus
lazy initializer” and typed dependency packaging. It must not hard-code
`@wordpress/element`, Next.js analyzers, Client Components, or a particular
application runtime. The raw runtime import remains a downstream/provider
binding when the host re-exports React from another package.

### Downstream boundary

WordPressHx keeps:

- `@wordpress/element` imports and exact version/profile admission;
- Gutenberg component property contracts;
- WordPress editor, store, block, and SlotFill behavior; and
- WordPress-specific diagnostics and documentation.

NextJsHx keeps Next analyzer constraints, server/client boundaries, App Router
rules, and Next-native diagnostics. Both consumers should import the same
Genes-owned React foundation after a merged, immutable upstream release.

### Required proof

- no `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` in the new Haxe surface;
- neutral React fixtures with no WordPressHx or NextJsHx identifiers;
- strict TypeScript/TSX and classic Genes JS plus declarations;
- runtime React Hook/component evidence where the abstraction has behavior;
- full Genes CI;
- WordPressHx SDK-032, SDK-035, SDK-063, and SDK-064 gates; and
- the directly affected NextJsHx React/Hook/HXX gates before either consumer
  advances its pin.

## GXR-02: alternative-HXX parser bridge

`packages/gutenberg/src/wordpress/hx/gutenberg/hxx/_internal/BrowserHxxLowerer.hx`
correctly keeps WordPress profile selection and property contracts downstream,
but it constructs:

- `genes.react.internal.Jsx.__jsx`;
- `genes.react.internal.Jsx.__frag`;
- `genes.react.internal.Jsx.__hxxChildJsx`; and
- `genes.react.internal.Jsx.__hxxChildFrag`.

That private dependency couples the SDK parser to a compiler implementation
detail. Moving `BrowserHxxLowerer` into Genes would be wrong because it also
owns Gutenberg profile admission, WordPress diagnostics, and the neutral
WordPressHx parser tree.

The reusable upstream capability is narrower: a supported compile-time API
through which an alternative parser can submit typed tags, closed property
records, children, authored positions, and nested-child ownership to Genes.
Genes must still validate the resulting plan and preserve its one-evaluation,
immutability, source-map, TSX, and classic-JS invariants. A public API must not
turn internal marker calls into an unchecked escape hatch.

Before implementation, reduce the WordPress call site to a neutral second HXX
parser fixture inside an isolated Genes worktree. If a safe public contract
cannot be expressed without exposing compiler-internal ownership tokens, keep
the current pinned integration and document the private compatibility boundary
instead of publishing a forgeable API.

## GXR-03: public library-root manifest

`packages/gutenberg/src/wordpress/hx/gutenberg/browser/BrowserExport.hx`
performs two different jobs:

1. it selects `@:genes.library` and records compiler facts such as Haxe source,
   source span, type identity, generated module, export name, and output
   profile; and
2. it adds WordPress facts such as the stable SDK export ID, selected profile,
   and capability references.

Genes already owns library-root discovery, public-graph retention, source maps,
and transactional generated-file publication through `LibraryProfile`,
`PublicSurface`, and `OutputTransaction`. The compiler-fact half is therefore
a plausible Genes manifest. It should be emitted from the same typed plan and
publication transaction as the generated modules, not re-derived by a
downstream macro.

WordPressHx must continue to own stable product IDs and profile capability
references. Its adapter would join those facts to a content-addressed
Genes-produced root record and fail when either side is missing or ambiguous.
This work should proceed with SDK-072 rather than introducing another
independent export manifest.

## GXR-04: Source Map v3 consumption and composition

The following code contains general Source Map v3 mechanics:

- `packages/cli/src/wordpresshx/cli/SourceMapV3.hx`;
- `packages/cli/scripts/package-browser-source-correlation.py`; and
- `packages/gutenberg/scripts/package-source-correlation.py`.

The two Python packagers share substantial path, archive, source-inventory, and
mapping logic. Genes already owns source-map generation, portable Haxe source
identities, and generated-output transactions. A reusable strict reader,
lookup, remap, and composition core could eventually support WordPress,
Next.js, and other Haxe-to-JS/TS build chains.

Do not move these downstream policies into Genes:

- authenticated WordPress package/source indexes;
- development versus production source retention;
- WordPress artifact IDs and archive shape;
- browser CLI output schemas; or
- exact webpack/esbuild/WordPress entry admission.

No upstream implementation should begin until a second consumer needs the same
reader/composer contract. At that point, reduce only the Source Map v3
algorithm and malformed-input corpus; keep artifact authority in each
downstream.

## GXR-05: typing-policy tooling

Genes already has internal reusable checks in:

- `../genes/scripts/typing-policy.ts`; and
- `../genes/scripts/downstream-contracts.ts`.

WordPressHx repeats generated weak-type, machine-path, map, and downstream
consumer checks in `packages/gutenberg/scripts/verify-hxx.mjs` and related
fixture verifiers. A versioned Genes CLI or library could provide the generic
scan and command-execution mechanism.

The public contract is not yet clear. “No weak types” differs between a
compiler-owned module, a decoded external boundary, and a downstream public
API; blindly sharing one regex would create false confidence. Genes should own
only format-independent compiler output policy and a configurable runner.
WordPressHx keeps its exact-profile allowlists, waiver authority, generated
artifact identities, and release claims.

## Keep in WordPressHx/GutenbergHx

These mechanisms are intentionally not Genes candidates:

- `BrowserHxxProfile` and all exact WordPress/Gutenberg component catalogs;
- `@wordpress/components`, `@wordpress/editor`, `@wordpress/data`,
  `@wordpress/blocks`, `@wordpress/i18n`, and `@wordpress/element` bindings;
- block metadata, attributes, deprecations, transforms, patterns, SlotFill,
  data-store, and editor-plugin macros;
- WordPress script handles, dependency extraction, asset PHP, plugin ZIP
  packaging, and exact-profile capability checks;
- the WordPress source index, artifact authentication, release retention
  policy, and `wphx trace` presentation;
- server HXX, typed PHP/HTML lowering, WordPress escaping/KSES policy, and the
  PHP compiler profile; and
- the shared server/browser HXX syntax tree merely because one consumer is
  Genes. A multi-target parser could later become its own neutral library, but
  it is not a JS/TS compiler responsibility.

Likewise, Next.js routes, directives, React Server/Client boundaries, analyzer
constraints, caching, and deployment conventions must never enter Genes.

## Recommended sequence

1. Contribute GXR-01's smallest shared React type foundation to Genes in an
   isolated worktree and PR.
2. After the upstream release is immutable, migrate WordPressHx to consume it
   and remove only proven duplicates.
3. Reduce GXR-02 to a neutral alternative-parser fixture and obtain an upstream
   architecture decision before exposing a bridge.
4. Design GXR-03 with SDK-072 so only compiler-owned root facts move upstream.
5. Defer GXR-04 and GXR-05 until a second concrete consumer fixes their public
   contract.

Every upstream change must be framework-neutral, pass full Genes CI without
regressions, and be merged before WordPressHx consumes a new immutable pin.
Temporary downstream bridges must have a removal Bead and must not fork generic
compiler behavior.
