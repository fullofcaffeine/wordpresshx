# ADR-011: HXX parser and lowering architecture

- Status: accepted
- Date: 2026-07-17
- Owners/reviewers: Marcelo Serpa (product owner and HXX-first direction), Codex (parser/lowering and reference architecture review)
- Bead: `wordpresshx-adr-011`
- Profiles/layers: HXX syntax, server markup, Gutenberg/browser markup, WordPress component facades, output safety
- Supersedes: the conditional parser choice in PRD §18.2
- Superseded by: none

## Context

WordPressHx is intended to author complete sites, themes, plugins, blocks, and admin UI from Haxe. Markup therefore cannot be a peripheral string-template feature. Haxe inline markup and HXX should be the default, high-density way to keep presentation structure next to typed data and behavior while still producing ordinary WordPress artifacts.

The same syntax must serve two native environments without pretending that they share one runtime:

- server/theme/admin markup passes through a generic typed PHP-markup IR in `reflaxe.php` and becomes ordinary PHP/HTML, WordPress helper calls, block markup, or static HTML;
- editor/browser markup becomes strict TSX or typed element calls through the independently pinned Genes compiler and the normal Gutenberg/React runtime.

The architecture must catch knowable errors at Haxe compile time: malformed markup, unknown tags/attributes, missing or invalid component props, wrong child/slot shapes, target leakage, unavailable profile capabilities, and unsafe interpolation contexts. It must not ship a parser, virtual DOM, component registry, template resolver, or proprietary rendering kernel to WordPress.

Several references demonstrate useful parts of the solution:

- `tink_hxx` supplies a generic positioned syntax tree, Haxe inline-markup parsing, normal Haxe expression parsing, control nodes, spreads, and typed tag-generation concepts.
- Coconut demonstrates compact typed attributes, callbacks, children, defaults, and composition over HXX, but its state/view/VDOM model is a browser runtime and is not adopted.
- PhoenixHx demonstrates intercepting compile-time-only typed markup entry points and emitting normal HEEx, with raw target syntax explicit rather than normal.
- RailsHx demonstrates Haxe inline markup, typed locals/components/slots, checked external templates, native ERB output, and searchable escape hatches without a view runtime.

The local `tink_hxx` reference is exact tag `0.25.1`, commit `75ef63c78851fcd7c1846d74959cbd4cea0b4ced`, tree `ef1ae3be1574e745c7877f5567d9b76ea36dca47`. Its package metadata targets Haxe 4.3 compatibility and uses the MIT license. The official Haxelib catalog still reports `0.25.1` as the latest stable version at decision time.

## Decision

### Inline HXX is the primary authoring surface

Haxe 4 inline markup is canonical:

```haxe
public static function render(model:FrontPageModel):ServerNode {
  return <main class={Styles.page}>
    <SiteHeader navigation={model.navigation} />
    <section class={Styles.posts}>
      {for (post in model.posts)
        <PostCard post={post} />
      }
    </section>
  </main>;
}
```

The `@:markup` expression emitted by the Haxe parser is rewritten at compile time. Embedded expressions are real Haxe expressions and pass through the normal typer. Users do not wrap ordinary markup in a string macro, concatenate HTML, write PHP template syntax, or select a lowerer at every call site. The enclosing typed return/entry contract selects `server`, `browser`, or an explicitly admitted cross-target subset.

String-form `hxx("...")`, external `.hxx`, and raw native templates may exist for migration or interoperability, but documentation, scaffolds, and canonical examples use inline markup. An escape must not become simpler than the typed happy path.

### Parser dependency and ownership

Use public Haxelib `tink_hxx` version `0.25.1` as a compile-time parser dependency. SDK-080 resolved the immutable release artifact and all five selected transitives in `packages/hxx/dependency-lock.json`: Haxelib inputs have exact byte sizes and SHA-256 digests, Git inputs have commit/tree identities, and the package-local Lix scope contains no floating version, `haxelib dev`, or repository-relative input.

The SDK consumes only the parser, positioned syntax-node concepts, and narrowly required parsing helpers behind an internal adapter. No `tink.hxx.*` type appears in the public WordPressHx API, semantic plan, evidence schema, or generated output. This protects the public contract from parser-library changes and allows a later compatible parser without rewriting application code.

The generic `tink_hxx` generator is not used as the WordPress semantic authority. WordPressHx owns tag resolution, typed props/children, output contexts, exact-profile checks, semantic plans, and target lowerers. Coconut, Coconut VDOM/renderers, and Coconut state/view classes are reference material only and are not dependencies.

There is no default fork. A generic parser defect is first reduced to a neutral fixture and proposed upstream with the upstream regression suite. A temporary patch must be isolated, provenance-recorded, and content-pinned; a maintained fork requires a superseding ADR covering release, security, merge, and rollback authority. WordPress semantics never enter the generic parser.

### Compile-time pipeline

The pipeline has explicit phases:

```text
Haxe inline markup (`@:markup`) + original spans
                  |
                  v
       pinned tink_hxx parser adapter
                  |
                  v
   neutral positioned syntax tree
  tags / attrs / text / expressions /
  fragments / if / for / switch / spreads
                  |
                  v
 Haxe resolver expressions and normal Haxe typing
                  |
                  v
 typed target-neutral markup contract
       /                         \
      v                           v
server semantic plan       browser semantic plan
      |                           |
      v                           v
generic reflaxe.php          Genes TSX/element lowering
typed markup IR
      |                           |
      v                           |
WordPress PHP profile             |
and helper extensions             |
      |                           |
      v                           v
native PHP/HTML             native TSX/JS + Gutenberg/React
```

Parser nodes retain original source spans. Resolution creates typed Haxe calls or values, so the Haxe typer—not a string reparser—validates expressions, generic props, nullability, callbacks, children, and component results. The semantic plan retains source correlation, selected target, output context, profile capability IDs, ownership, and provenance.

### PHP compiler integration and WordPress extension

Server HXX is a first-class capability of the co-located generic PHP compiler, not a separate string-template emitter. `compiler/reflaxe.php` owns a reusable typed markup IR and deterministic PHP/HTML lowering for:

- positioned static text/elements, attributes, typed dynamic segments, and fragments;
- direct conditions, loops, switches, local bindings, and bounded component calls;
- generic output contexts and explicit trusted/unsafe segment boundaries;
- mixed PHP/HTML file rendering, PHP expression/statement rendering, source correlation, and density accounting;
- neutral fixtures that contain no WordPress names, paths, helpers, or metadata.

This generic layer replaces handwritten mixed PHP markup for Haxe-owned templates with a typed compiler surface. It does not replace the PHP runtime, own WordPress routing, or become an HTML framework runtime.

The intended public ergonomics are direct markup returns from typed render/template methods, for example `return <main>...</main>`. The method result type or an HXX-enabled component/template contract supplies the target context and triggers compile-time lowering. Parser macro wrappers used by bounded prototypes remain internal or explicit advanced boundaries; they must not become ceremony required at every render site. Automatic lowering is admitted only inside declared HXX contexts, never as an unscoped rewrite of arbitrary Haxe syntax.

`compiler/wordpress` and the SDK server/HXX modules extend the generic markup lowering through registered, typed profile adapters. They own WordPress hierarchy identities, template globals/locals, loop/post semantics, navigation, template parts, nonces, admin UI, forms, blocks, media, translations, profile capability checks, native helper calls, and WordPress-specific escaping policy.

The dependency remains one-way:

```text
reflaxe.php typed markup IR/lowerer
                ^
                |
compiler/wordpress profile adapters
                ^
                |
SDK HXX/server components and build plan
```

The generic compiler never imports SDK HXX/server packages. SDK macros may produce stable compiler-recognized metadata/call shapes, and the WordPress profile may register typed adapters, but neither mechanism permits WordPress branches in generic lowering. Browser HXX remains entirely under the Genes path.

### Shared syntax, target-shaped semantics

Both targets share lexical syntax and these neutral concepts:

- elements, components, text, typed expression children, fragments, conditionals, loops, switches, and local bindings;
- required/optional props, typed children, named slots, statically known attribute spreads, and child spreads;
- original positions, deterministic whitespace policy, diagnostics, and stable component identities.

They do not share a fake runtime node type. Server and browser node/result types are distinct. A component is target-specific by default. A component may declare a cross-target contract only when every prop, child, expression, tag, and effect is in a tested portable subset and both lowerers have conformance fixtures.

Server modules cannot accept browser callbacks, refs, DOM nodes, or Gutenberg components. Browser modules cannot call WordPress PHP helpers, rely on PHP globals, or import server-only components. Similar visual output does not erase the target boundary.

### High-density typed abstractions

The SDK should build concise abstractions over HXX rather than expose raw WordPress calls everywhere. Admitted abstraction families include:

- typed HTML/SVG elements and context-aware attributes;
- component functions/classes with typed props, children, and named slots;
- WordPress-native components such as navigation, template parts, post fields, loops, pagination, nonces, admin notices, block wrappers, forms, media, translations, and asset refs;
- theme layout, part, pattern, and block composition tied to declared native identities;
- typed design tokens, CSS classes, IDs, ARIA relationships, URLs, message keys, hook/event names, block attributes, and route refs;
- small pure presentation helpers kept beside markup when their effects and output type are statically known.

These abstractions extend the generic PHP-markup layer and compile away to recognizable native constructs. A `WpNavMenu` component should become the appropriate native WordPress call and surrounding markup, not a generic runtime component lookup. A typed partial/component ref owns a real native path/identity and locals contract. Named slots lower to native capture/buffering or direct structure only where the target already supports that behavior.

Attribute spreads require closed structural types. Explicit attributes win over spread values, duplicates are diagnosed, and missing required props still fail. `Dynamic`, arbitrary maps, and reflection do not become a back door around component typing. Open `data-*`/`aria-*` surfaces remain deliberate typed/open attribute families rather than accepting every unknown attribute.

### Output safety

Markup values carry position-specific safety contracts. At minimum, text, attribute, URL, CSS, HTML, JSON/script-data, and browser event/ref positions are distinct. Normal strings in text and attributes are escaped. A markup node cannot be used where a scalar is required.

Server output visibly uses native WordPress/PHP escaping and sanitization such as the appropriate `esc_*` or admitted `wp_kses*` call. Browser output preserves React/Gutenberg escaping semantics and prohibits casual `dangerouslySetInnerHTML`. A trusted-rich-content value can only come from a narrow typed constructor backed by an explicit policy; string concatenation cannot manufacture it.

SDK-052 owns the complete security/output-context types. SDK-081 and SDK-032 may not weaken those types to make a fixture compile.

### Output-density and inspectability budget

High-level HXX must have proportionate native output:

- static elements become static markup, not constructor/registry calls;
- control flow becomes direct PHP or JS control flow;
- target helpers become ordinary WordPress/Gutenberg/React calls;
- component composition becomes bounded native functions/templates/calls with stable names;
- unused abstractions do not enter generated artifacts;
- no reflection table, runtime AST traversal, parser data, generic component registry, or duplicate rendering kernel is emitted.

SDK-080 establishes representative source-to-output snapshots and an explicit density receipt. SDK-081/032 expand it. A lowering change that adds material support bytes or indirection must identify the native behavior it enables and pass readability, size, and runtime gates. Shorter source is not a win if the target artifact becomes opaque.

### Escape-hatch hierarchy

Escape hatches are necessary for gradual adoption and uncommon native behavior. They are ordered from most checked to least checked:

1. add or generate a typed WordPress/Gutenberg facade or component;
2. reference an existing native template/component through a compile-time checked path, symbol, props/locals, and ownership contract;
3. use an external typed contract whose implementation remains PHP/JS/third-party owned;
4. insert a policy-produced trusted HTML/native fragment with an explicit provenance and sanitizer identity;
5. use a narrowly scoped `unsafe` raw target segment with waiver ID, source hash, diagnostic, manifest entry, audit inventory, and removal owner.

Escape APIs use names such as `existing`, `external`, `trusted`, or `unsafe`; none masquerades as an ordinary string or component. Absolute/traversing paths, missing checked files, untyped locals, target-language expressions embedded in normal HXX, and unrecorded raw segments fail closed.

The Haxe-only happy path requires none of these. Existing sites can use them at bounded seams without giving generated code ownership of native files.

### Runtime prohibition

Server packages and final ZIPs must contain no HXX parser, `tink_hxx` implementation, Coconut runtime, VDOM, component registry, template resolver, or WordPress request dispatcher. Browser bundles may use React/Gutenberg because those are the selected native browser authorities, but HXX adds no second UI runtime.

Generated native helper functions or classes are allowed when they are the direct compiled form of application components. They must not accept or traverse a generic HXX node tree at runtime.

## Rationale

The accepted design maximizes the benefit of Haxe's inline markup: structure, data, branching, component inputs, and refactorable identifiers live in one typed source graph. The positioned parser avoids inventing a WordPress-only syntax, while an internal adapter keeps a small replacement seam.

Separate semantic lowerers preserve native authority. PHP templates and Gutenberg components have different effects, escaping rules, events, and runtime APIs; forcing them through a shared runtime would weaken both. Sharing syntax and compile-time contracts gives the desired developer experience without shipping a framework kernel.

The reference projects reinforce this boundary. PhoenixHx and RailsHx get their value by producing the host framework's ordinary templates. Tink supplies strong parser and typed tag ideas. Coconut demonstrates ergonomic props/children composition, but its runtime behavior is intentionally not copied.

## Alternatives considered

### Write a WordPress-specific HXX parser

This gives complete control but creates syntax drift, parser diagnostics work, editor inconsistency, and a permanent maintenance burden before WordPress semantics are even reached. It is rejected while the exact `tink_hxx` parser handles the required neutral syntax.

### Use the entire `tink_hxx` generator contract directly

This would quickly provide typed tags and spreads, but would expose external macro types and generic generation semantics as public SDK contracts. It does not own WordPress output contexts, profiles, PHP plans, or Genes imports. Only parser concepts are selected.

### Build on Coconut UI/VDOM

Coconut offers dense typed view authoring and is valuable inspiration for component props/children. Its observable state, view lifecycle, and renderer/VDOM are a different browser framework and cannot produce the required runtime-free server templates. It is rejected as a dependency/runtime.

### Use separate PHP templates and TSX files

This keeps native syntax maximally direct, but breaks the Haxe-only source graph and moves component props, expressions, locals, and refactoring across multiple languages. It remains an interoperability escape hatch, not the product default.

### Lower both targets to one runtime markup tree

This makes component reuse superficially easy but ships a new renderer, obscures native escaping and lifecycle behavior, and competes with WordPress/React. It is prohibited.

### Allow raw PHP/HEEx/JSX-like target expressions inside HXX

This is convenient for missing features but bypasses Haxe typing and turns compiler errors into target/runtime failures. Raw target segments remain explicit audited escapes only.

## Consequences

Benefits:

- inline markup becomes the concise default across complete site authoring;
- props, children, expressions, helpers, refs, and profiles receive compile-time checks;
- server and browser outputs stay ordinary and inspectable;
- parser maintenance remains upstream and generic;
- generic typed PHP markup can serve future non-WordPress compiler consumers;
- component abstractions can grow without adding a production framework runtime;
- gradual adoption retains checked native seams and explicit unsafe boundaries.

Costs and constraints:

- the SDK must maintain two semantic lowerers and a conformance subset;
- macro phase/source-span handling requires focused compiler fixtures;
- target-specific components may look similar but cannot always share implementation;
- exact `tink_hxx` and transitive pins add toolchain/release work;
- generic markup IR and WordPress profile adapters require independent boundary fixtures;
- output-context types and native semantic parity gate otherwise attractive syntax sugar.

This ADR is still the architecture authority rather than a runtime-support claim. SDK-080 separately proves a bounded parser adapter, neutral component/prop/slot/spread typing, relative source spans, target admission, and compile-time dependency erasure. It does not prove either native lowerer, production components, output safety, source maps, WordPress runtime behavior, or Gutenberg browser behavior.

## Evidence and commands

Reviewed exact references:

- `tink_hxx` `0.25.1` at commit/tree recorded above: `Parser.hx`, `Node.hx`, `Generator.hx`, `Tag.hx`, README inline-markup/control/component/spread semantics;
- `haxe.elixir.codex` commit `2f6b7ccc805fcd94017d8c826099c355f5863955`: `InlineMarkup.hx`, `HeexTemplate.hx`, `TemplateHelpers.hx`, and the HXX2 default-authoring plan;
- `haxe.ruby` commit `6de8c37a6fefd9361ef6058aa0d8e239be745bc6`: `RailsInlineMarkup.hx`, typed-view/component/helper docs, escape-hatch audit, and native ERB examples;
- `coconut.ui` commit `497a1124aab38c23e30864bc3d0500d8009d8eb1`: typed attributes, callbacks, children, defaults, and view-builder concepts;
- `tink_domspec` commit `cfc8efdea3952e5fe3d5c75d9e4fefdd47890b5d`: target-neutral typed HTML/attribute catalog precedent;
- PRD §§18 and 29.1, ADR-003's module direction, ADR-004's generic/profile separation, and the Haxe-first site-authoring architecture.

`manifests/hxx-architecture.json` is the machine-checked decision lock. It links the resolved dependency closure and receipt `SDK-080-HXX-PARSER-PROTOTYPE`, while keeping native lowering explicitly unimplemented.

Acceptance commands:

```bash
bash scripts/check-repository.sh
bash packages/hxx/scripts/test.sh
bash scripts/hooks/test.sh
bd lint
bd dep cycles
git diff --check
```

SDK-080 supplies the parser positive/negative/source-span prototypes and immutable dependency receipt. SDK-081/032 own native-output evidence.

## Migration, rollback, and supersession

There is no released SDK syntax to migrate. New examples use inline markup. Early string-template experiments, if any, remain migration fixtures and do not define the stable API.

If `tink_hxx` 0.25.1 cannot pass Haxe 4.3.7, source-span, security, or clean-package prototypes, SDK-080 must stop. A superseding ADR may select a newer compatible release, a narrow provenance-tracked patch, or another parser while preserving the public inline syntax and internal neutral AST boundary. It may not silently fork syntax or weaken typing.

If a server feature repeatedly requires unsafe/raw segments or opaque generated scaffolding, restrict that feature to external native templates or the browser target. If package scans find an HXX runtime, the gate fails and the runtime must be removed before capability evidence advances.

## Follow-up beads

- `wordpresshx-sdk-080`: pin and prototype the parser adapter, spans, diagnostics, syntax subset, density snapshots, and no-runtime scan.
- `wordpresshx-sdk-032`: implement and prove React/Gutenberg HXX props, events, refs, imports, and Genes output.
- `wordpresshx-sdk-052`: implement the shared security/output-context type system.
- `wordpresshx-sdk-081`: implement the server semantic AST and PHP/HTML lowering.
- `wordpresshx-sdk-082`: prove a native admin HXX pilot.
- `wordpresshx-sdk-083`: prove native theme hierarchy, external templates, and HXX coexistence.
- `wordpresshx-sdk-084`: add typed theme parts, patterns, design tokens, and styling abstractions.
- `wordpresshx-sdk-111`: prove a complete Haxe-only site using the inline HXX happy path.
