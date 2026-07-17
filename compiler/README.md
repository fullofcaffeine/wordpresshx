# Compiler workspace

During 0.x this monorepo owns two deliberately separate PHP compiler layers:

- `reflaxe.php/`: generic PHP IR, lowering, printing, runtime/stdlib adaptation, generic fixtures, and compiler package metadata;
- `wordpress/`: the future SDK-owned WordPress application profile, package/file mapping, public ABI policy, and WordPress-specific fixtures.

The generic package must not import SDK packages or contain WordPress concepts. The WordPress profile may depend on the generic package; the reverse dependency is forbidden. Full-port Core linking, original-path replacement, ownership state, and distribution assembly remain outside this repository.

[ADR-004](../docs/adr/004-generic-php-compiler-home.md) defines the temporary monorepo ownership model and explicit extraction triggers.
