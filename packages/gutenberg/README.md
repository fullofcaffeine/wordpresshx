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

## Typed block metadata and native `block.json`

SDK-060 removes a common three-way drift problem: the Haxe attribute type, the
browser registration, and WordPress' `block.json` can no longer describe
different blocks. A public Haxe class is the attribute schema. Field metadata
adds only the WordPress facts Haxe cannot infer, such as where saved markup is
read from:

~~~haxe
extern class CalloutAttributes {
  @:wpSource(AttributeSource.RichText)
  @:wpSelector("p")
  @:wpRole(AttributeRole.Content)
  @:wpDefault("")
  public var message:String;

  @:wpDefault(CalloutTone.Info)
  public var tone:CalloutTone;
}
~~~

`CalloutTone` is a normal Haxe enum whose constructors have explicit
`@:wpValue` strings. The compiler checks its default, derives the allowed JSON
values, and gives later edit/save code the same closed Haxe type. A block then
declares user-facing metadata, stable supports, and logical asset IDs:

~~~haxe
Block.define(CalloutAttributes, {
  name: "wordpresshx/callout",
  title: "Editorial callout",
  category: BlockCategory.Design,
  supports: {
    anchor: true,
    align: [BlockAlignment.Wide, BlockAlignment.Full],
    color: {background: true, text: true}
  },
  assets: {
    editorScript: "callout-editor",
    style: "callout-style"
  }
});
~~~

The selected profile supplies API version 3, the exact upstream schema
identity, and the admitted metadata/support vocabulary. The asset manifest
maps each logical ID to either a final staged file with its SHA-256 digest or a
profile-owned WordPress handle. The compiler fails before publication if a
file is absent, stale, assigned to another block, has the wrong asset kind, or
uses a handle outside `wp70-release`.

Output is ordinary deterministic `block.json`, not a WordPressHx runtime
format. An adjacent registration plan records the same block name, metadata
path, and metadata digest for native `register_block_type` and
browser `registerBlockType`; it is build evidence consumed by later emitters.
WordPress remains the runtime registry and metadata authority.

Start with the two-block walkthrough in
[`test/block-metadata-fixture`](test/block-metadata-fixture/README.md). Run the
compiler, exact-profile verifier, replay, and negative fixtures without Docker:

~~~sh
bash packages/gutenberg/scripts/test-block-metadata.sh --skip-wordpress
~~~

Omit `--skip-wordpress` to install the generated metadata on exact WordPress
7.0 and prove static registration plus a real dynamic render-file call.

## Typed editor plugins and SlotFill

SDK-063 adds a Haxe-only editor extension on the same exact WordPress 7.0
profile. Plugin, sidebar, and post-type identities are distinct branded types;
valid literals are checked during compilation and runtime input has explicit
parsers. The public surface wraps native `registerPlugin`, `unregisterPlugin`,
`useSelect`, `PluginSidebar`, `PluginSidebarMoreMenuItem`, `PanelBody`, and
`ToggleControl` APIs. WordPress still owns the registry, editor store, SlotFill
runtime, components, and focus model.

The normal application source is dense Haxe/HXX:

~~~haxe
private static final pluginName =
  PluginName.literal("wordpresshx-todo-readiness");
private static final sidebarName = SidebarName.literal("todo-readiness");

private static function render():ReactNode {
  return <if {CurrentPost.isType(PostTypeName.literal("post"))}>
    <Main.ReadinessSidebar/>
  <else><></></if>;
}

private static function ReadinessSidebar():ReactNode {
  final required = useState(false);
  final menuItem:ReactNode =
    <PluginSidebarMoreMenuItem target={sidebarName}>
      Todo Studio readiness
    </PluginSidebarMoreMenuItem>;
  final sidebar:ReactNode =
    <PluginSidebar name={sidebarName} title="Todo Studio readiness">
      <PanelBody title="Before this ships">
        <ToggleControl
          label="Require editorial review"
          checked={required.value}
          onChange={next -> required.set(next)}
        />
      </PanelBody>
    </PluginSidebar>;
  return [menuItem, sidebar];
}
~~~

The Array at the root is React's typed sibling-node form. Haxe 4's inline
markup lexer cannot use a fragment literal as the outermost expression;
nested `<>...</>` fragments remain supported. There is no authored JS/TS
registration file, browser HXX parser, private Gutenberg import, or recreated
SlotFill implementation.

Run the deterministic build and real editor proof while retaining an
inspectable plugin and screenshot:

~~~sh
SDK063_VISUAL_OUTPUT=packages/gutenberg/sdk063-preview \
  bash packages/gutenberg/scripts/test-editor-plugin.sh
~~~

Use `--skip-wordpress` for the compile, strict-TypeScript, official bundle,
replay, generated-plugin, and PHP-matrix checks only. The complete lane also
installs the generated plugin on exact WordPress 7.0/MySQL and uses real
Chromium to prove keyboard opening through the `menuitemcheckbox` SlotFill,
bounded keyboard focus entry, keyboard and mouse state changes, focus-preserving
close through the pinned toolbar control, zero serious/critical axe findings,
post-only visibility, public unregister behavior, and zero console/page errors.

The editor overlay is selected explicitly with
`-D wordpress_hx_browser_hxx_catalog=editor-plugin`. It composes with the
unchanged SDK-032 base catalog, so adding this vertical does not rewrite or
invalidate the earlier browser-HXX receipt. Its exact source and package proof
is recorded in
[`SDK-063-EDITOR-PLUGIN-SLOTFILL`](../../manifests/evidence/sdk-063-editor-plugin-slotfill.json).

## Compile-time-validated WordPress data stores

SDK-064 builds on the editor surface with a typed facade over native
`@wordpress/data`. The application declares one state type, one closed action
type, an initial value, and a pure reducer. `DataStore.define` validates their
relationship during Haxe compilation and returns a branded native store
descriptor:

~~~haxe
private static final key =
  StoreKey.literal("wordpresshx/todo-studio-lab");

private static final store:TypedDataStore<TodoState, TodoAction> =
  DataStore.define(key, TodoDomain.initial(), TodoDomain.reduce);
~~~

Invalid namespaced keys, reducers that return another state, actions without a
string-compatible `type` discriminator, and dispatches from the wrong action
domain fail at the Haxe source position. Runtime validation remains appropriate
for values that can only be known from the installed site or current request;
it is not used as a substitute for a statically knowable store contract.

The first public facade deliberately keeps a narrow, precise shape:

- `DataStores.register` installs the descriptor in WordPress' registry;
- `snapshot` and `useSnapshot` return the exact state type;
- `send` and `useSender` accept only the exact action type; and
- `subscribe` keeps the native WordPress subscription lifecycle.

Applications layer meaningful command and selector names over those primitives
in ordinary Haxe. WordPress remains runtime owner of Redux registration,
dispatch, selection, subscriptions, and React updates; WordPressHx adds the
compile-time contract and Haxe/HXX authoring surface.

Run the deterministic compiler and packaging lane:

~~~sh
bash packages/gutenberg/scripts/test-data-store.sh --skip-wordpress
~~~

Run the full exact-WordPress and Chromium proof while retaining its generated
plugin, plan, screenshot, and browser evidence:

~~~sh
SDK064_VISUAL_OUTPUT=packages/gutenberg/sdk064-preview \
  bash packages/gutenberg/scripts/test-data-store.sh
~~~

The beginner-oriented walkthrough is
[`examples/todo-data-store-lab`](../../examples/todo-data-store-lab/README.md).
