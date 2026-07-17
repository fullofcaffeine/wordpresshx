# Repository layout and package boundary

The PRD recommends a monorepo because the first stable contract crosses Haxe APIs, exact profiles, macros, PHP/browser emitters, ownership, CLI orchestration, examples, and installed WordPress tests.

ADR-003 accepts this monorepo layout. Directory and namespace boundaries are real ownership boundaries, but they are not automatically public registry packages:

| Path | Intended concern | Decision/evidence gate |
|---|---|---|
| `packages/` | Haxe authoring/build source modules assembled into the public `wordpress-hx` Haxelib | ADR-003; SDK-012/040 and later APIs |
| `compiler/reflaxe.php/` | Private 0.x generic PHP compiler package, independently extractable | ADR-004; SDK-020/021/027 |
| `compiler/wordpress/` | SDK-owned WordPress PHP profile consuming the generic compiler API | ADR-004/005; SDK-022 |
| `profiles/` | Exact WordPress/Gutenberg catalogs and manifests | ADR-002/008; G0 |
| `generated/` | Committed, content-addressed exact-profile inventory outputs | SDK-013; regenerated only from pinned inputs |
| `schemas/` | Versioned project/profile/plan/ownership/evidence schemas | ADR-006/007/009/016 |
| `tools/` | Profile/adoption/package/source-map tooling | Corresponding implementation beads |
| `examples/` | Consumer-facing, package-tested examples | G4–G8 |
| `fixtures/` | Compile, emitter, interop, ownership, and negative evidence | G1–G7 |
| `test/` | Unit, compiler, PHP, WordPress, browser, package suites | SDK-090–095 |
| `docker/` | Pinned test environments only | SDK-090 |
| `manifests/` | Toolchain/upstream/evidence/release locks and receipts | G0/G8 |

Top-level directory names are organizational boundaries, not published-package commitments. Through `1.x`, the public release unit is one `wordpress-hx` Haxelib plus the exactly matching `@wordpress-hx/cli` npm artifact. `manifests/package-topology.json` is the machine-checked classification and dependency map. Component publication or independent versioning requires the evidence and superseding ADR defined by ADR-003.

Dependency direction must remain:

```text
core -> profiles/contracts/hxx -> server/browser authoring APIs
                                  -> build -> testing
build/macros inspect authoring layers but do not ship as runtime dependencies
```

The SDK may consume the private `compiler/reflaxe.php` workspace package during 0.x and may later pin its extracted releases. It may not import full-port implementation paths, Core linker machinery, runtime state, or a mutable sibling compiler checkout.

The same rule applies to the wider Haxe solution family: integration uses versioned public packages, schemas, CLIs, immutable identities, and independent receipts. Similar concepts in sibling repositories do not create a dependency until real consumers prove a shared contract.
