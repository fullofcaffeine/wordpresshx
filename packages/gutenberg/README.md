# Gutenberg and browser source module

This directory owns the WordPressHx browser profile inside the assembled
wordpress-hx Haxelib. It is not a separately published package.

SDK-031 establishes the first bounded compiler/profile fixture:

- exact Genes v1.36.3 source at its immutable release commit, admitted through
  the generalized Array-index fix in upstream PR #3;
- Haxe 4.3.7 and a scoped Lix dependency graph;
- exact Node 22.17.0, npm 10.9.2, TypeScript 5.9.3, and esbuild 0.27.2
  verification tooling;
- strict split-ESM TypeScript as the primary source lane;
- classic split-ESM JavaScript plus declarations as a bounded differential;
- an SDK-owned Haxe export directive projected to the generic
  @:genes.library retention contract;
- full-DCE public facade retention and private-member removal;
- binding-free side-effect and live ESM import behavior; and
- an ordinary JavaScript caller of both bundled outputs.

The SDK-030 Genes v1.33.0 receipt remains the historical compiler-selection
baseline. This package's dependency lock records the later baseline -> fix ->
merge -> release chain; it does not rewrite that earlier receipt or read from a
mutable sibling checkout.

The exact upstream and package proof is recorded in
[`SDK-031-STRICT-BROWSER-PROFILE`](../../manifests/evidence/sdk-031-strict-browser-profile.json).

The fixture is intentionally independent of WordPress package symbols.
WordPress package externs and React/Gutenberg HXX belong to SDK-032; official
dependency extraction, handles, asset PHP, and translations belong to SDK-033.
This boundary ensures a failure can be reduced to Genes without adding
WordPress names to the generic compiler.

The Haxe source remains the application authoring surface. TypeScript and
JavaScript under test/consumer and test/runtime are external-consumer/native
module fixtures, not required application source.

Run the complete gate from the repository root:

~~~sh
bash packages/gutenberg/scripts/test.sh
~~~

The gate downloads only checksum/commit-locked inputs, writes generated output
under temporary directories, and executes the Node portion inside the exact
content-addressed image selected by ADR-013. Its committed artifact inventory
also detects byte drift in the replayed generated tree and both browser
bundles, in addition to semantic, runtime, DCE, and size checks.

## Typed React and Gutenberg HXX

SDK-032 adds the first browser UI surface on top of that compiler profile. A
Haxe component can return inline markup directly; the profile-installed build
macro recognizes the Haxe `@:markup` expression and lowers it at compile time:

~~~haxe
public static function App():BrowserNode {
  final accepted = useState(false);
  final button = useRef((null : Null<HtmlButtonElement>));

  return <main aria-labelledby="title">
    <h1 id="title">Compiler proof</h1>
    <Notice status={NoticeStatus.Info} isDismissible={false}>
      This child is required and typed.
    </Notice>
    <Button
      ref={button}
      onClick={(event:ReactMouseEvent<HtmlButtonElement>) -> {
        event.preventDefault();
        accepted.set(true);
      }}
    >Accept proof</Button>
  </main>;
}
~~~

The application author does not call a browser parser or write companion JSX.
The neutral `tink_hxx` syntax tree is resolved against the exact
`wp70-release` browser-HXX profile and lowered through Genes to readable TSX.
The emitted bundle contains ordinary React and `@wordpress/*` imports and no
HXX parser, component registry, or markup runtime.

The admitted surface is deliberately bounded: curated HTML props, Button and
Notice from `@wordpress/components` 32.2.0, five hooks from
`@wordpress/element` 6.40.0, typed mouse/keyboard events, DOM refs, context,
children, fragments, conditionals, Array loops, closed prop spreads, and child
spreads. Unknown props, missing required children, open spreads, incorrect
event/ref targets, switch controls, and raw JSX fail during Haxe compilation.
Typed Haxe function components are the reusable component escape hatch.

The registration-proof fixture in
[`test/hxx-fixture`](test/hxx-fixture/src/sdk032/fixture/Main.hx) is a complete
Haxe-authored responsive page. It uses live Gutenberg Button and Notice
components, state, context, a ref, mouse and keyboard events, and reduced-motion
styles. To run all compiler, exact-source, strict-TypeScript, deterministic
bundle, React runtime, keyboard, accessibility, and source-map checks while
retaining a browser-preview build:

~~~sh
SDK032_VISUAL_OUTPUT=packages/gutenberg/sdk032-preview \
  bash packages/gutenberg/scripts/test-hxx.sh
python3 -m http.server 41732 --directory packages/gutenberg/sdk032-preview
~~~

The verifier builds the visual entry with the automatic React JSX runtime and
the exact Gutenberg component stylesheet. The provider declaration graph also
gets a full `skipLibCheck: false` lane. Its upstream Ariakit declarations do
not support `exactOptionalPropertyTypes`; generated user modules therefore get
a separate stricter lane with that option enabled and zero public `any` or
`unknown` types.

## Same-source strict/classic differential

SDK-035 adds a deliberately small cross-printer contract on top of the SDK-032
compile-time HXX lowerer. One Haxe facade exports typed summary functions and a
hook-driven counter that returns inline markup. The exact Genes 1.36.3 source
is compiled twice: strict split-ESM TSX, and classic split-ESM JavaScript with
adjacent declarations. The SDK parser has already produced typed Genes JSX
intent, so both profiles set `genes.react.no_inline_markup`; running Genes'
source markup parser a second time would be ambiguous.

Run the complete differential gate from the repository root:

~~~sh
bash packages/gutenberg/scripts/test-differential.sh
~~~

The gate compiles each lane twice, compares every generated byte and retained
export manifest, and type checks the strict source and classic declarations
from the same external consumer under TypeScript 5.9.3 with
`skipLibCheck: false`. It inventories the authored public aliases and methods,
admits no public `any` or `unknown`, bundles with the automatic React JSX
transform, and runs four isolated Node 22.17.0/jsdom/React 18 processes. Pure data output,
server-rendered markup, initial mounted state, and a real bubbling click must
all match exactly.

TSX syntax versus `React.createElement`, adjacent declarations versus inline
types, and emitter-owned local spelling are recorded target differences. No
semantic difference is accepted, classic output remains a differential rather
than the production default, and the proof says nothing about source outside
the named corpus. The upstream `DualJsxMain.hx` fixture is recorded as a
concept reference at an immutable blob; it is not copied or used as a build
input. No Genes change or PR was needed.

## Official WordPress assets and translations

SDK-033 takes the same Haxe/HXX source through the exact official WordPress
build. Its fixture imports Gutenberg components and i18n from Haxe; an
SDK-owned native mount entry is supplied as a bounded build-boundary input.
Later scaffolding must generate that entry from typed Haxe declarations before
the project surface can claim to be entirely Haxe-authored. Developers do not
author or patch `asset.php`, dependency handles, versions, enqueue PHP, or
translation JSON.

Run the complete deterministic bundle and real WordPress proof:

~~~sh
bash packages/gutenberg/scripts/test-assets.sh
~~~

The gate compiles twice with Genes, installs the exact npm lock in the pinned
Node image with lifecycle scripts disabled, and builds both one-shot
development and minified production lanes with `@wordpress/scripts` 31.5.0.
It compares source imports, the official externalized report, final bundles,
unchanged official asset PHP, exact profile mappings, and a semantic native
enqueue plan. It also validates the Genes and Webpack Source Map v3 layers
independently, then throws deliberately in real Chromium from both official
bundles and resolves each frame to the same exact Haxe token. No filename,
basename, or nearest-line guessing is allowed. Finally, it emits an inspectable
plugin, checks PHP 7.4 and 8.4 syntax, and runs that plugin on WordPress
7.0/MySQL to prove dependency order, the final content version, and translation
attachment.

For a build-only replay, omit the database lane:

~~~sh
bash packages/gutenberg/scripts/test-assets.sh --skip-wordpress
~~~

Set `SDK033_ASSET_OUTPUT` to retain the semantic plan and generated native
plugin for inspection. Set `G24_SOURCE_CORRELATION_OUTPUT` to an empty directory
to retain the production ZIP, separate debug companion, source index, normalized
maps, real Chromium stacks, and canonical trace output. The installable ZIP
contains no maps, source index, Haxe/TSX source, source content, or inline map
directive; operators keep the content-bound debug companion separately and
provide source roots only during offline diagnosis. The emitted PHP/JS/JSON are
build artifacts; the Haxe fixture remains the application authoring surface.
Script Modules and unrelated entries or adapters are not claimed and require
their own exact-profile parity proof.
