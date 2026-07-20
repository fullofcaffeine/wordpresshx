# ADR-012 output-context fixture

This bounded architecture fixture proves that output authority belongs to an
exact final context rather than to a universal safe string. It is evidence for
ADR-012, not the public SDK implementation.

The Haxe prototype defines terminal text, attribute, textarea, validated URL,
policy-branded rich HTML, JSON-document, script-data, typed-CSS, and
compiler-markup contracts. JSON terminals require a fixture-local typed stand-in
for ADR-009's `ContractCodec<T>` authority, and the two native KSES policies
retain distinct phantom brands plus profile identities. Constructors are
private and terminal values expose no raw string conversion. Eight negative
fixtures prove that representative cross-context substitutions and direct
construction fail during Haxe typing.

`test/Main.hx` emits a context-plan transcript through Haxe interpretation,
Genes/strict TypeScript/Node, and stock-Haxe PHP. `runtime/browser.mjs` verifies
ordinary React SSR escaping without a raw-HTML API.
`runtime/wordpress-probe.php` runs on a clean exact WordPress 7.0 installation
and exercises native escaping, KSES policies, script JSON, a dynamic block,
REST data, and an admin notice.

Run the complete proof from the repository root:

```bash
bash scripts/output-context/test.sh
```

The gate requires Haxe 4.3.7 through the Lix shim, Genes 1.36.3, TypeScript
5.9.3, Node 22.17.0, PHP 8.4.7, Docker, and the repository's pinned
WordPress/MariaDB images. It creates only temporary outputs and removes its
Compose project on exit.
