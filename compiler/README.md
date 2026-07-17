# Compiler workspace

During 0.x this monorepo owns two deliberately separate PHP compiler layers:

- `reflaxe.php/`: generic PHP IR, lowering, printing, runtime/stdlib adaptation, generic fixtures, compiler package metadata, and the ADR-011 typed PHP-markup IR/lowerer;
- `wordpress/`: the future SDK-owned WordPress application profile, package/file mapping, public ABI policy, typed WordPress HXX/helper extensions, and WordPress-specific fixtures.

The generic package must not import SDK packages or contain WordPress concepts. The WordPress profile may depend on the generic package; the reverse dependency is forbidden. Full-port Core linking, original-path replacement, ownership state, and distribution assembly remain outside this repository.

Server HXX therefore belongs to this compiler family in two layers: generic typed markup and native PHP/HTML emission in `reflaxe.php`, then WordPress hierarchy/helper/escaping ergonomics in `wordpress/` and SDK adapters. It replaces hand-authored mixed PHP markup for Haxe-owned templates without shipping an HXX runtime. Browser HXX remains a separate Genes concern.

[ADR-004](../docs/adr/004-generic-php-compiler-home.md) defines the temporary monorepo ownership model and explicit extraction triggers.
