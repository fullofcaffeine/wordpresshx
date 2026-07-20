# Typed Gutenberg editor sidebar

This is the smallest runnable WordPressHx editor extension. You author the
plugin registration, post-type rule, state, Gutenberg controls, and markup in
Haxe/HXX. The build produces an ordinary native WordPress plugin; there is no
browser HXX parser and no handwritten JavaScript registration entry.

It answers one practical question: **can a Haxe component participate in the
real Gutenberg editor without recreating Gutenberg?** The installed test opens
the native SlotFill menu, enters the sidebar with the keyboard, changes state,
closes with focus restored, checks that the extension stays out of the Page
editor, unregisters it through the public API, and runs axe accessibility
checks in Chromium.

This is a focused SDK proof. It is not the persistent Todo Studio application:
its controls use local React state and do not save todo records.

## Prerequisites

- Docker Desktop or another working Docker daemon with Compose v2
- Haxe 4.3.7 selected through Lix 15.12.4
- Node 22.17.0 and npm 10.9.2
- Python 3, Git, and the repository dependencies installed by `lix download`

The gate checks these versions before it builds. Run it from the repository
root:

~~~sh
SDK063_VISUAL_OUTPUT=packages/gutenberg/sdk063-preview \
  bash packages/gutenberg/scripts/test-editor-plugin.sh
~~~

Expect the final line:

~~~text
SDK-063 typed editor plugin gate passed
~~~

The command compiles twice, type-checks the emitted TSX, creates development
and production bundles with the exact WordPress dependency extractor, emits an
installable plugin, checks PHP 7.4 and 8.4, installs exact WordPress 7.0 with
MySQL, and exercises the editor in real Chromium. The temporary WordPress site
is removed automatically. Retained output is under
`packages/gutenberg/sdk063-preview/`, including the generated plugin and the
editor screenshot.

To leave a local site running so you can click through the example:

~~~sh
bash packages/gutenberg/scripts/start-example-server.sh editor-sidebar
~~~

The script prints the exact editor URL and local test login. It reuses the
retained plugin when present and otherwise builds it first. Stop and remove its
isolated database with:

~~~sh
bash packages/gutenberg/scripts/start-example-server.sh editor-sidebar stop
~~~

For a faster compiler-and-package check without Docker WordPress or Chromium:

~~~sh
bash packages/gutenberg/scripts/test-editor-plugin.sh --skip-wordpress
~~~

## Read the Haxe source

Start with
[`Main.hx`](../../packages/gutenberg/test/editor-plugin-fixture/src/sdk063/fixture/Main.hx).
The important flow is:

~~~text
typed Haxe identities + inline HXX
  -> Genes emits strict TSX
  -> the official WordPress build externalizes Gutenberg packages
  -> generated PHP registers the native editor asset
  -> Gutenberg owns rendering, focus, and SlotFill behavior
~~~

`PluginName.literal`, `SidebarName.literal`, and `PostTypeName.literal` reject
invalid literal identities at the Haxe source location. Component props and
event handlers are checked before TSX exists. The generated PHP, JavaScript,
asset metadata, translations, and screenshot are evidence to inspect—not files
the application developer maintains.

## Make a small change

Change visible copy or the HXX layout in `Main.hx`, then rerun the gate. If you
give a Gutenberg component the wrong prop type, omit a required child, mix up
the branded identities, or introduce a forbidden weak Haxe type, the build
stops before WordPress starts and points back to the Haxe source.

For the next step—shared state through WordPress' native data registry—use the
[`Todo data-store lab`](../todo-data-store-lab/README.md).
