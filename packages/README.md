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

SDK-035 uses one additional Haxe/HXX facade to compare the strict TSX and
classic JavaScript-plus-declarations printers. Both outputs retain the same
declared module, pass strict external TypeScript consumption, and produce the
same data, SSR, mounted-state, and click behavior in isolated React 18
processes. This is a bounded regression corpus, not a universal mode switch;
it required no Genes source change or sibling build input.

SDK-025 establishes the [`cli`](cli/README.md) build source for
`@wordpress-hx/cli`. Its PHP trace application is authored in Haxe and compiled
to Node ESM by immutable Genes 1.36.3. It validates exact package indexes and
PHP range maps offline, preserves native frames, emits stable text or canonical
JSON, and consumes separately retained debug companions. Browser trace
correlation remains SDK-034 work. No Genes source change, sibling checkout, or
WordPress-specific compiler branch was required.

ADR-016 selects `wphx` as that package's final project-local binary and defines
the project bootstrap, exact lock, effective inputs, stable stages/events, and
`wphx dev` lifecycle. SDK-043 now provides the bounded final command while the
existing trace-only prototype remains available as the private `wphx-sdk`
compatibility bin. SDK-044 owns the real watcher and service supervisor.

SDK-040 establishes the [`build`](build/README.md) compile-time module. Typed
module, hook, resource, and public-environment declarations are recovered from
Haxe module metadata even under a persistent compilation server, validated
against exact profile/schema/tool inputs, and serialized into one canonical
semantic plan plus an inspectable input report. Full DCE leaves no build API or
collector in application JavaScript. The collector does not emit target files.
SDK-041 adds the Haxe-authored artifact owner inside [`cli`](cli/README.md): it
validates the complete stage, owns only exact manifest path+hash entries,
publishes the manifest last, and recovers a durable journal without overwriting
unexpected bytes. SDK-043 connects that library to `wphx build` and `clean`, adds
strict project/lock/effective-input resolution, read-only check/inspect/doctor
modes, and preserves the previous trace implementation byte-for-byte.
