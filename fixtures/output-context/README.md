# ADR-012 output-context fixture

This bounded architecture fixture proves that output authority belongs to an
exact final context rather than to a universal safe string. It is evidence for
ADR-012, not the public SDK implementation.

The Haxe prototype defines terminal text, attribute, textarea, validated URL,
policy-branded rich HTML, JSON-document, script-data, separate inline-style and
stylesheet, and compiler-markup contracts. JSON terminals require a
fixture-local typed stand-in for ADR-009's `ContractCodec<T>` authority and
retain either encoded output or an explicit failure. Native KSES policies have
distinct brands; a custom policy has a canonical allowlist/protocol document
and digest. Constructors are private, terminal values expose no raw conversion,
and only an exact generated fragment class can create compiler markup with
source provenance.

The proof has one data flow:

```text
typed Haxe terminals -> generated runtime plan -> PHP and React final sinks
```

`test/Main.hx` creates the plan. Haxe interpretation, Genes/strict
TypeScript/Node, and stock-Haxe PHP must emit identical bytes.
`runtime/browser.mjs` and `runtime/wordpress-probe.php` both consume those
exact bytes and return the plan digest. This prevents a handwritten runtime
fixture from accidentally testing different payloads than the Haxe layer.
Nineteen negative fixtures prove cross-context substitutions, direct
construction, and unsupported security-sensitive HXX positions fail during
Haxe typing.

Run the complete proof from the repository root:

```bash
bash scripts/output-context/test.sh
```

The gate requires Haxe 4.3.7 through the Lix shim, Genes 1.38.0, TypeScript
5.9.3, Node 22.17.0, PHP 8.4.7, Docker, and the repository's pinned
WordPress/MariaDB images. It creates only temporary outputs and removes its
Compose project on exit.
