# Provisional repository layout

The PRD recommends a monorepo because the first stable contract crosses Haxe APIs, exact profiles, macros, PHP/browser emitters, ownership, CLI orchestration, examples, and installed WordPress tests.

The bootstrap reserves these concerns without declaring their package APIs:

| Path | Intended concern | Decision/evidence gate |
|---|---|---|
| `packages/` | Candidate Haxe authoring and build packages | ADR-003; SDK-012/040 and later APIs |
| `compiler/reflaxe.php/` | Private 0.x generic PHP compiler package, independently extractable | ADR-004; SDK-020/021/027 |
| `compiler/wordpress/` | SDK-owned WordPress PHP profile consuming the generic compiler API | ADR-004/005; SDK-022 |
| `profiles/` | Exact WordPress/Gutenberg catalogs and manifests | ADR-002/008; G0 |
| `schemas/` | Versioned project/profile/plan/ownership/evidence schemas | ADR-006/007/009/016 |
| `tools/` | Profile/adoption/package/source-map tooling | Corresponding implementation beads |
| `examples/` | Consumer-facing, package-tested examples | G4–G8 |
| `fixtures/` | Compile, emitter, interop, ownership, and negative evidence | G1–G7 |
| `test/` | Unit, compiler, PHP, WordPress, browser, package suites | SDK-090–095 |
| `docker/` | Pinned test environments only | SDK-090 |
| `manifests/` | Toolchain/upstream/evidence/release locks and receipts | G0/G8 |

Top-level directory names are organizational placeholders, not published-package commitments. ADR-003 must decide which packages are public versus internal and retain lockstep versioning through at least 1.0 unless evidence supports a later split.

Dependency direction must remain:

```text
pure domain -> contracts -> server/browser authoring APIs
profiles ----^             ^
build/macros inspect these layers but do not ship as runtime dependencies
```

The SDK may consume the private `compiler/reflaxe.php` workspace package during 0.x and may later pin its extracted releases. It may not import full-port implementation paths, Core linker machinery, runtime state, or a mutable sibling compiler checkout.
