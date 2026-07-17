# Core profile contracts

Internal SDK-012 source tree for exact profile identities, API/evidence enums,
compile-time availability, and request-scoped runtime capability results.

Run its positive and compile-fail fixtures from the repository root:

```bash
bash scripts/profiles/test-profile-haxe.sh
```

This is not yet a publishable Haxelib package. ADR-003 owns final package
topology/versioning, while ADR-020 and SDK-002 own source/output licensing. The
current `0.x` implementation path is exercised directly with `-cp`; adding
package metadata must not imply that either pending decision has been made.
