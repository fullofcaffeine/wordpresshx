# ADR-015 adoption-contract fixture

This synthetic fixture proves the proposed precise-or-omitted adoption format.
It does not prove a production generator, a public provider integration, or provider trust admission.

The `inputs/` directory contains exact PHP and JavaScript provider sources.
It also contains authoritative PHP stubs, TypeScript declarations, and package metadata.

The static generator reads these files without executing provider code.
It derives nine candidate symbols, admits five bindings, and reports four omissions.
One omission records a conflict between an authoritative stub and the runtime source.

The generator writes one adoption bundle with these parts:

- The exact provider, profile, input, and binding contract.
- Two capability declarations for a PHP request and a browser module.
- The review and loss report.
- Generated PHP and JavaScript facades.
- The ADR-007 generated-file ownership manifest.

The bundle root binds the exact bytes of each part.
The provider artifact is a deterministic ZIP of the runtime fixture files.

The Haxe prototype models three lifecycle types.
These types are PHP request, PHP process, and browser module.
Each runtime instance has a new private nonce.
Application code cannot create observations, scopes, runtimes, or tokens.

Six negative programs prove type and access restrictions.
Runtime cases reject reuse across two instances of the same lifecycle type.
They also reject browser reload and stale PHP process authority.

The generated facades load and call the native fixture providers.
The runtime proof covers success, absence, wrong version, wrong artifact, missing symbols, arrays, and provider exceptions.

The production ADR-007 owner publishes the generated files.
The proof covers no-op regeneration, provider updates, manual edits, removal, crash recovery, and provider-owned files.

Run the complete local proof from the repository root:

```bash
bash scripts/adoption/test.sh
```

The gate rejects 33 document mutations and JSON Schema prefix or suffix attacks.
It uses Haxe 4.3.7, TypeScript 5.9.3, Node 22.17.0, and PHP 8.4.7.
The exact Genes version and commit come from `packages/cli/dependency-lock.json`.
Set `WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP=1` to exercise the pinned PHP
container path even when exact PHP is installed on the host.

Static generation does not execute provider code.
Separate runtime cases execute only the exact provider bytes that pass the bundle and artifact checks.
