# Packages

These directories are Haxe authoring/build source modules assembled into the single public `wordpress-hx` Haxelib distribution. ADR-003 classifies their supported namespaces and dependency direction. They are not separately published packages through `1.x`; do not create package metadata solely to mirror the directory tree.

The separately distributed `@wordpress-hx/cli` is the exactly version-matched host/build executable. Internal interop, compiler-profile, and tool modules may be bundled as implementation but are not supported APIs. The private generic `compiler/reflaxe.php` workspace has its own ADR-004 extraction boundary and never receives the SDK version merely because it is co-located.

SDK-012 establishes the [`core`](core/README.md) profile-contract source tree. It is compiled directly in CI and deliberately has no per-module package metadata. Publication of the assembled SDK remains prohibited until ADR-020, SDK-002, and release evidence authorize it.

SDK-080 establishes the [`hxx`](hxx/README.md) parser-adapter prototype. Its package-local scoped Lix closure is exact and compile-time-only; server and browser evidence fixtures prove shared inline syntax, normal Haxe typing, useful source spans, distinct result contracts, and no parser/UI-runtime leakage. The serialized snapshots are evidence artifacts, not the supported native renderer.

SDK-031 establishes the [`gutenberg`](gutenberg/README.md) browser compiler profile. It admits an immutable Genes release through a recorded generic upstream-fix lineage, emits strict split-ESM TypeScript as the primary lane, keeps classic Genes output as a bounded differential, and proves retained public exports, live ESM behavior, full-DCE privacy, ordinary JavaScript consumption, and deterministic output. Gutenberg/React HXX APIs build on this compiler boundary in SDK-032; this first package slice deliberately contains no WordPress-specific compiler patch.

SDK-032 adds the first typed React/Gutenberg HXX slice to that same
[`gutenberg`](gutenberg/README.md) module. Application components return Haxe
inline markup directly; an exact-profile compile-time resolver checks native
props, WordPress components, children, events, refs, hooks, context, closed
spreads, and control flow before Genes emits ordinary readable TSX. The proof
page bundles and runs real React 18 and WordPress Button/Notice code while
shipping no HXX parser or UI runtime. No sibling Genes checkout or
WordPress-specific Genes branch is used.
