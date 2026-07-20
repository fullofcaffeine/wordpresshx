# ADR-015 adoption-contract fixture

This bounded synthetic fixture proves the proposed precise-or-omitted adoption
format. It is architecture evidence for ADR-015, not the SDK-070/073 production
generator, a real WordPress plugin integration, or provider trust admission.

`inputs/` represents four statically inspected provider sources: authoritative
PHP stubs, authoritative TypeScript declarations, package metadata, and a
plugin main file. The plugin file contains a poison sentinel that would be
written if the provider were executed; the gate proves static generation never
loads it.

`contract/` contains three closed, self-digested records:

- the exact provider/profile/input contract with three precise bindings;
- two scoped capability declarations for PHP request and browser-module use;
- a review report with four omissions and one authority conflict.

The Haxe prototype under `src/` is deliberately small. It models nominal
provider and capability identities, private request-scoped tokens, exact
version/artifact/binding probes, a thin facade, and typed unavailability. The
four `test-negative/` programs prove that application code cannot construct a
token, substitute one capability for another, reuse a token across request
scopes, or call a member omitted from the facade.

Run the complete local proof from the repository root:

```bash
bash scripts/adoption/test.sh
```

The gate validates the closed schemas and thirty-one fail-closed mutations,
checks Haxe formatting and forbidden weak constructs, then requires a
byte-identical transcript from Haxe 4.3.7 interpretation, Genes 1.36.3 with
strict TypeScript 5.9.3/Node 22.17.0, and stock-Haxe PHP on PHP 8.4.7. It uses
only temporary generated outputs and confirms that provider runtime code was
not executed.
