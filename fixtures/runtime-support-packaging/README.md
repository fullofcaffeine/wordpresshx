# ADR-018 runtime-support packaging fixture

This is an executable architecture fixture, not the SDK-024 production
packager.

`src/fixture/privateimpl/Main.hx` is the only maintained private application
logic. The evidence builder compiles it twice with exact Haxe 4.3.7, selecting
two compile-time markers and two automatically derived `php-prefix` values. It
then assembles temporary ordinary WordPress plugins with native public adapters,
an exact package-local class map, an exact global-polyfill compatibility guard,
and a complete private-runtime inventory.

The stock PHP front controller is retained only long enough to prove it was not
packaged. No generated PHP is committed. `runtime/` contains native test
consumers that exercise the package as ordinary PHP and WordPress would; they
are not application-authoring examples or shipped runtime support. The conflict
probe proves that an incompatible process-wide polyfill marker rejects the
private boot before callbacks or public support classes are loaded.

Run the bounded local proof:

```bash
bash scripts/runtime-support/test.sh
```

Run the exact PHP 7.4/8.4 and clean WordPress 7.0 proof:

```bash
bash scripts/runtime-support/test-production.sh
```

The fixture proves the architecture contract only. Production semantic-plan
integration, source correlation, optimized dependency slicing, WPCS/static
analysis, licenses/SBOM, and final ZIP packaging remain SDK-024/G1/G8 work.
