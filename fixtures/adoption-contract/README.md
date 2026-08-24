# ADR-015 adoption-contract fixture

This synthetic fixture proves the proposed precise-or-omitted adoption format.
It does not prove a production generator, a public provider integration, or provider trust admission.

The `inputs/` directory contains exact PHP and JavaScript provider sources.
It also contains authoritative PHP stubs, TypeScript declarations, and package metadata.

The static generator reads these files without executing provider code.
It derives nine candidate symbols, admits five bindings, and reports four omissions.
One omission records a conflict between an authoritative stub and the runtime source.

The generator writes one adoption content bundle with seven members:

- The exact provider, profile, input, and binding contract.
- Two capability declarations for a PHP request and a browser module.
- The review and loss report.
- The generated Haxe provider surface.
- Generated PHP and JavaScript facades.
- The exact deterministic provider artifact.

The content root binds the exact bytes of all seven members. It excludes the
final ownership manifest, which avoids a digest cycle. The existing ADR-007
owner publishes the seven members, the bundle, and the final manifest as one
transaction. The provider artifact is a deterministic ZIP of the runtime
fixture files.

The Haxe prototype models three lifecycle types.
These types are PHP request, PHP process, and browser module.
Each runtime instance has a new private nonce.
Application code cannot create observations, scopes, runtimes, or tokens.

Eight negative programs prove type and access restrictions, including exact
spoofs of the former test friend path and the internal authority-owner name.
Runtime cases reject reuse across two instances of the same lifecycle type.
They also reject browser reload and stale PHP process authority.

Source-owned target adapters ask the generated facades to derive the content
root from captured bundle bytes and verify captured provider bytes before they
mint capability authority. Callers do not supply the content digest. The
generated facades execute or import those captured bytes, not a mutable path.
The runtime proof covers success, absence,
wrong version, wrong artifact, missing symbols, arrays, provider exceptions,
and post-verification facade and provider swaps. A vertical observer crosses
from authored Haxe through each generated native facade to the PHP and
JavaScript providers.

The production ADR-007 owner validates and publishes the complete staged
content bundle. The proof covers no-op regeneration, provider updates, manual
edits, removal, crash recovery, provider-owned files, and a self-consistent
ownership manifest whose staged bundle semantics are stale.

Run the complete local proof from the repository root:

```bash
bash scripts/adoption/test.sh
```

The gate rejects 84 layer-isolated document mutations, relative-path
traversal, and JSON Schema prefix or suffix attacks. Each non-stale mutation
gets a fresh self-digest before its own schema and semantic layer evaluates it.
It uses Haxe 4.3.7, TypeScript 5.9.3, Node 22.17.0, and PHP 8.4.7.
The exact Genes version and commit come from `packages/cli/dependency-lock.json`.
Set `WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP=1` to exercise the pinned PHP
container path even when exact PHP is installed on the host.

Static generation does not execute provider code. Local pass evidence is
recorded only after the schema, native, Haxe, mutation, and ownership observers
all pass against one content root. Hosted and independent-review evidence stay
separately bound. Runtime cases execute only the exact provider bytes that pass
the bundle and artifact checks.
