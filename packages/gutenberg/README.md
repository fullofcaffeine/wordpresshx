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
