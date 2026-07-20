# Typed static block walkthrough

This fixture is a small but complete example of why a Haxe layer is useful for
Gutenberg. The application author writes one attribute model and ordinary HXX
for both editor and saved markup. WordPressHx then checks and generates the
native pieces that otherwise drift across `block.json`, JavaScript registration,
edit callbacks, save callbacks, and old-content migrations.

## What the example builds

The “Durable callout” block has two string attributes:

- `label`, read from `.wphx-callout__label`, defaults to `NOTE`;
- `message`, read from `.wphx-callout__message`, defaults to an empty string.

Both defaults are explicit. Missing values therefore have one predictable
meaning, while `null` is rejected by the Haxe type rather than being handled
later in JavaScript.

The editor and saved views are intentionally different. The editor contains an
eyebrow and two native Gutenberg `PlainText` controls. The saved page contains
only the durable `<aside>` markup. That distinction is enforced by separate
types: `EditProps<CalloutAttributes>` can update attributes, while
`SaveProps<CalloutAttributes>` has no setter.

Start with these files:

- [`CalloutAttributes.hx`](src/sdk061/fixture/CalloutAttributes.hx) is the one
  attribute schema used by metadata, edit, save, and serialization.
- [`CalloutBlock.hx`](src/sdk061/fixture/CalloutBlock.hx) contains the HXX edit,
  save, legacy-save, and migration functions.
- [`Main.hx`](src/sdk061/fixture/Main.hx) registers the browser behavior and its
  ordered immutable deprecation record.
- [`MetadataMain.hx`](src/sdk061/fixture/MetadataMain.hx) declares native
  WordPress discovery metadata and logical assets.

The old `0.9.0` block stored only `text` and saved a `<div>`. The deprecation
describes those old bytes exactly, then migrates them into the current
`label/message` model. Existing posts are readable without weakening the new
type or silently changing the current save function.

## Run it

From the repository root, run the compiler, deterministic replay, strict
TypeScript, six compile-negative cases, native Gutenberg parser/serializer,
and real WordPress 7.0 editor/frontend proof:

```sh
bash packages/gutenberg/scripts/test-static-block.sh
```

The real browser lane inserts the Haxe-authored block through WordPress' native
registry, edits both fields, exercises undo and redo, saves and reloads the
post, and checks the public frontend. It also opens committed legacy bytes,
requires migration without a validation/recovery prompt, saves them in the new
format, and checks the migrated frontend.

For a deterministic compiler/runtime check without starting WordPress:

```sh
bash packages/gutenberg/scripts/test-static-block.sh --skip-wordpress
```

## What is generated and what is not

Genes emits readable TSX and source maps from the Haxe/HXX browser source. The
official WordPress build emits the browser bundle and `editor.asset.php`. The
SDK-060 metadata compiler emits `block.json` from the same Haxe attribute class
and refuses stale logical assets. The resulting block is consumed by ordinary
WordPress APIs; there is no HXX parser or WordPressHx UI runtime in the browser.

The small PHP files under `test/static-block-runtime` are deliberately
independent test harnesses. They activate and observe the generated artifact on
real WordPress so the compiler cannot rewrite its own oracle. They are not
application source or a manual-PHP requirement. Product projects use the
Haxe-authored plugin/theme assembly path as that adapter becomes available.

The fixture stylesheet is a bounded native asset used to prove exact ownership
and hashing. Typed Haxe design-token/style generation belongs to the later site
authoring slice; SDK-061 does not claim it yet.

## Useful compile failures

The negative fixtures show the guardrails directly. Compilation fails when an
edit callback accepts save props, a field update has the wrong Haxe type, save
code tries to call the editor setter, a migration returns the wrong attribute
model, a default is omitted, or a lookalike deprecation marker is used.
