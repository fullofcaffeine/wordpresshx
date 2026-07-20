# Typed block metadata fixture

This fixture shows the first WordPressHx block declaration path. Application
authors maintain Haxe only:

- a normal attribute class supplies the editor/server value shape;
- field metadata selects native Gutenberg extraction, roles, and defaults;
- Haxe enums supply closed `enum` values through `@:wpValue`;
- `Block.define(...)` supplies discoverability, supports, context, and logical
  asset IDs; and
- the exact profile supplies API version 3, the upstream schema identity, and
  the stable metadata vocabulary.

The compiler resolves each logical asset through `assets.manifest.json`, checks
the final file hash or exact WordPress handle capability, then writes ordinary
`block.json` files. It also writes a registration plan proving that native PHP
and `@wordpress/blocks` use the same name, metadata path, and digest. Neither
plan is a runtime framework.

The real-WordPress lane uses a small handwritten PHP oracle under
`test/block-metadata-runtime`. It is intentionally an external consumer, not
application source: product registration/render adapters remain Haxe-authored,
while the oracle observes WordPress independently so a compiler bug cannot also
rewrite the assertion that is supposed to catch it.

Run the deterministic compiler, replay, verifier, and compile-negative corpus:

```sh
bash packages/gutenberg/scripts/test-block-metadata.sh
```

The committed JavaScript, CSS, and PHP files are bounded native-build fixtures.
In an application, Genes, the PHP compiler, and the style pipeline stage those
files first; the block metadata compiler then refuses to publish references to
anything missing, stale, owned by another block, or unavailable in the selected
WordPress profile.
