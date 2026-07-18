# Build and development loop

Status: SDK-040 collection and SDK-041 fail-closed publication are implemented;
SDK-042 through SDK-044 deterministic orchestration, CLI, and long-running
watcher work remains planned and tracked in beads.

## Developer surface

A scaffolded project has one default development command:

```text
wphx dev
```

The developer does not maintain HXML, PHP scripts, npm orchestration scripts,
or a second watcher configuration. `wphx build`, `wphx check`, `wphx inspect`,
`wphx clean`, and `wphx doctor` are the bounded one-shot companions. To run the
same incremental compiler loop without WordPress or Next.js services, use:

```text
wphx dev --services=none
```

The generated `.wphx/bootstrap/*.hxml` files remain inspectable escape hatches,
not the ordinary interface.

## One effective graph

SDK-040 now produces `wordpress-hx.semantic-collector-inputs.v1`. It binds the
declaration sources, declared resources, public build environment value
digests, exact profile catalog, exact node schemas, collector implementation,
and every generated project-lock tool identity. Runtime secrets are absent.

SDK-041 now provides the exact-hash, complete-stage, journaled manifest-last
transaction that preserves the last good generation. SDK-043 will merge the
collector report with ADR-016's project, HXML/classpath, package, and discovery
graph. SDK-044 will watch that merged graph. There is no separate
handwritten list of directories that can silently omit a macro, lock, resource,
or newly discovered Haxe source.

## Planned `wphx dev` lifecycle

The stable lifecycle is:

1. Discover the project and validate its generated lock without modifying it.
2. Run one complete build into a private transaction and publish it only after
   all target validators pass.
3. Start a project/toolchain/profile-bound Haxe wait server only when its
   compatibility identity is exact; otherwise compile directly.
4. Supervise configured WordPress and Next.js development services, select
   collision-safe loopback ports, and use bounded readiness probes.
5. Watch the effective graph, debounce and coalesce bursts, then invalidate the
   smallest stage whose isolation is proven. Ambiguity triggers a full build.
6. Promote a complete transaction atomically and request browser reload only
   after the ownership-manifest commit marker is durable.
7. On a compile or validation error, keep the last known good site running and
   report the Haxe source span. A failed target never publishes sibling target
   metadata.
8. On Ctrl-C, child failure, or watcher restart, stop owned processes in reverse
   order and leave no repository-local Haxe server or stale child behind.

CI and one-shot `wphx build` use bounded direct compilation. They never start an
unbounded watcher or inherit a developer's compilation server.

## Proven patterns and adaptation

The development contract adapts the exact-input discovery, managed compiler
server, debounced watcher, stable-output promotion, and process cleanup lessons
from the pinned `haxe.elixir.codex` reference. WordPressHx keeps those concepts
in its own CLI/build layer: it does not depend on Mix, Phoenix, the sibling
checkout, or any copied sibling bytes.

SDK-040 already exercises the important compiler-server boundary. A direct
Haxe 4.3.7 build and two builds through one `haxe --wait` process produce the
same plan and input bytes. Declaration facts are recovered from typed module
metadata on every generation, so a cached module cannot create an empty or
stale semantic registry.
