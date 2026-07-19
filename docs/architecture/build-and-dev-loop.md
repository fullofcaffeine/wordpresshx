# Build and development loop

Status: SDK-040 collection, SDK-041 fail-closed publication, SDK-042
deterministic packaging, and the SDK-043 bounded `wphx` command foundation are
implemented and hosted verified. SDK-044's long-running compile/watch core,
managed Haxe server, last-good publication, and clean compiler shutdown are
implemented and locally production-gate verified. The typed Haxe development-
service plan now feeds a closed, strictly typed CLI decoder and generic external
service supervisor. Dependency ordering, collision-safe loopback ports, bounded
readiness, redacted environments, bounded graph restarts, and reverse shutdown
are locally runtime verified. The SDK-owned `wp70-release` WordPress process
provider is implemented and locally controlled-process verified, including its
generated Docker Compose v2 configuration. Its zero-configuration development
adapter and Haxe-authored browser client now provide automatic full-page reload;
the controlled provider boundary is locally proven in real Chromium. The native
plugin lane additionally infers that provider directly from its compiler
`PluginPlan`, mounts the exact generated tree, performs a fresh real WordPress
install and activation, and is locally production-gate verified through failed-
build retention, successful reload, and complete Docker cleanup. Next.js is an
optional integration boundary rather than a core service dependency.

## Developer surface

A scaffolded project has one default development command:

```text
wphx dev
```

The developer does not maintain HXML, PHP scripts, npm orchestration scripts,
or a second watcher configuration. `wphx build`, `wphx check`, `wphx inspect`,
`wphx clean`, and `wphx doctor` are the bounded one-shot companions. The
compile/watch-only form is:

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

SDK-041 provides the exact-hash, complete-stage, journaled manifest-last
transaction that preserves the last good generation. SDK-043 constructs
ADR-016's project, HXML/classpath, package, discovery, public-environment, and
tool graph from the strict generated bootstrap and lock. Its production corpus
reproduces the accepted fixture fingerprint exactly, including nested source
discovery and runtime-secret exclusion. SDK-044 now watches this same graph;
there is no separate handwritten list of directories that can silently omit a
macro, lock, resource, or newly discovered Haxe/HXX source.

Recursive source, HXX, and asset discovery uses portable non-recursive native
directory subscriptions. The small set of compiler-identity files is also
polled by content identity so edits remain visible on bind mounts whose native
file events are incomplete. Output, transaction, runtime, dependency, and VCS
roots are excluded by the authenticated graph.

## Implemented bounded lifecycle

`wphx build`, `check`, `inspect`, `clean`, and `doctor` share one project
resolver and one stage pipeline. One-shot builds type Haxe directly rather than
silently inheriting a developer compilation server. `build` stages a complete
generation privately and publishes through the SDK-041 owner; `check`,
`doctor`, `inspect`, and `build --dry-run` have no publication authority.

The generic site generation remains intentionally limited to CLI effective-
input metadata plus its reproducibility report and unsigned archive. Missing
PHP, browser, and asset producers remain explicit skipped stages. The generated
plugin lane has a registered structured PHP producer and ordinary installable
ZIP. The stable `wphx dev` entry performs an initial complete transaction,
starts an owned project-local Haxe wait server when its exact identity is safe,
and stays alive watching the effective graph. `--services=none` is a real
compile/watch-only mode.

For a generated plugin, its existing typed declaration is sufficient:

```haxe
WordPress.plugin();
```

After publication, the CLI reads the process-local compiler `PluginPlan`,
re-derives and validates the exact native emission, and infers the built-in
WordPress service only when no explicit service plan exists. A non-plugin site
or an advanced override can still declare the service explicitly:

```haxe
Dev.wordpress();
```

Both paths derive the stable ID, working directory, preferred port, bounded HTTP
readiness probe, restart policy, URL, and full-page reload mode. Typed options
override only what differs on the explicit path. No handwritten Compose file or
Docker image choice is part of the common path: the CLI derives a private
canonical mode-`0600` Compose configuration from typed compiler authority, the
exact `wp70-release` image lock, and its allocated loopback port. For a plugin,
the graph shares a named WordPress volume with a private installer, bind-mounts
only the exact generated plugin read-only, installs WordPress, and activates the
plugin before readiness can pass. The installer starts only after an exec-form
healthcheck proves the pinned image has completed the required WordPress core,
include, configuration, and plugin-entry files in that shared volume. It passes
database and administrator secrets through required environment interpolation,
never embeds secret values in the file, passes only a closed Docker CLI
host-environment allowlist, runs Compose without a shell, and removes its
generated files, containers, network, and volumes after bounded shutdown.

Both the inferred plugin path and `Dev.wordpress()` derive automatic
development reload.
The CLI embeds a browser client authored in strictly typed Haxe, compiled by the
pinned Genes 1.36.3 profile, and bundled deterministically by pinned esbuild
0.27.2. It serves that asset and an event stream from a loopback-only endpoint
guarded by a fresh 256-bit capability and the exact admitted WordPress origin.
A private mode-`0600` development MU-plugin adds the client at the WordPress
footer boundary; its URLs arrive only through required runtime interpolation,
not generated source or Compose bytes. A failed build sends nothing. A complete
manifest-last publication sends one reload. Shutdown closes the stream and
removes the private adapter. None of the client, endpoint, capability, or
adapter enters a production-owned artifact.

The exact WordPress 7.0/PHP 8.4 and MariaDB 11.4.5 images are runtime proven
independently by SDK-090 and now also run together through plain `wphx dev` for
the generated-plugin lane. That proof is bounded to a fresh plugin development
install; it is not a complete generated-site or production-hosting claim.

`Dev.service({...})` is the explicit, no-shell external-process escape hatch:
Haxe derives an admitted executable from its exact lock component and defaults
omitted argv to `[]`. For admitted services the CLI authenticates the current
compiler generation, starts processes without a shell in dependency order,
waits for typed bounded readiness, and owns their complete lifecycle. It does
not invent commands or infer an executable outside the closed component
mapping. Generic external services receive no automatic browser injection;
their reload behavior remains an explicit typed integration boundary.

## Deterministic clean-build oracle

Every bounded build derives one canonical artifact set in memory before live
publication. The transaction contains the effective-input document,
`dist/wordpress-hx-build.json`, and `dist/wordpress-hx.zip`. The report binds
the exact project/profile/toolchain fingerprint and every payload path, byte
length, SHA-256, and normalized mode. The Haxe ZIP32 writer uses sorted portable
paths, stored entries, the 1980 ZIP epoch, regular-file mode `0644`, no extra
fields, and no archive or entry comments. It has no host `zip`, Python, zlib,
locale, timezone, mtime, or permission input.

The SDK-042 gate compiles the Genes CLI twice, then builds the same fixture in
two unrelated fresh roots with deliberately different input mtimes and modes.
It byte-compares the complete ownership manifest, generated artifacts, report,
and archive, validates the archive independently, scans for host/temp/user path
leaks, and exercises path-specific byte/mode/missing diagnostics. A safe
additive ownership-root migration admits the new distribution root from an
SDK-043 generation; removing or rewriting an existing root remains forbidden.
This clean-build result is the oracle SDK-044 incremental generations must
match before they can be promoted.

## SDK-044 `wphx dev` lifecycle

The stable lifecycle is:

1. Discover the project and validate its generated lock without modifying it.
2. Run one complete build into a private transaction and publish it only after
   all target validators pass.
3. Start a project/toolchain/profile-bound Haxe wait server only when its
   compatibility identity is exact; otherwise compile directly.
4. Supervise the built-in WordPress service and any admitted extension service,
   select collision-safe loopback ports, and use bounded readiness probes.
5. Watch the effective graph, debounce and coalesce bursts, then invalidate the
   smallest stage whose isolation is proven. Ambiguity triggers a full build.
6. Promote a complete transaction atomically and request browser reload only
   after the ownership-manifest commit marker is durable.
7. On a compile or validation error, keep the last known good site running and
   report the Haxe source span. A failed target never publishes sibling target
   metadata.
8. On Ctrl-C, child failure, or watcher restart, stop owned processes in reverse
   order and leave no repository-local Haxe server or stale child behind.

The implemented core covers the initial atomic build, project-bound compiler
lease, conservative full rebuild, 100 ms sorted/deduplicated coalescing,
single-flight serialization, edit-during-build stability checks, exact
last-good retention, manifest-last generation admission, and compiler cleanup.
The CLI consumes only a newly generated canonical semantic plan bound to the
exact project, profile catalog, and project lock. Its external-service runtime
proves dependency-order startup, HTTP/log/TCP readiness, collision recovery,
bounded full-graph restart, environment allowlisting, reverse shutdown, and no
leaked container process. The built-in WordPress path additionally proves
private canonical generated configuration, exact image-lock selection, secret
placeholder transport, Compose v2 syntax, normal teardown, and that an ordinary
Haxe source edit does not restart an unchanged service graph. Reload requests
are emitted only after publication. The Haxe/Genes browser client, capability-
protected loopback stream, derived WordPress adapter, failed-build suppression,
and exactly one successful full-page navigation are locally runtime proven in
real Chromium against the controlled provider boundary. The generated-plugin
corpus additionally runs the exact image pair, proves install and activation
before HTTP readiness, observes the same post-commit reload stream, retains the
last-good mounted bytes after a failed Haxe generation, and removes all owned
runtime resources on shutdown. The generic metadata-only site lane still has no
deployable site output. When isolation is not proven, every change takes the
full atomic path. An optional Next.js package must bring its own typed adapter
and evidence; core does not hard-code a Next provider or native-HMR claim.

CI and one-shot `wphx build` use bounded direct compilation. They never start an
unbounded watcher or inherit a developer's compilation server.

## Proven patterns and adaptation

The development contract adapts the exact-input discovery, managed compiler
server, debounced watcher, and stable-output promotion lessons from the pinned
`haxe.elixir.codex` reference. The owned-process cleanup boundary also adapts
the ensure-owned lifecycle lesson from `haxe.ruby` and bounded
SIGTERM-to-SIGKILL lesson from Genes. WordPressHx keeps those concepts in its
own CLI/build layer: it does not depend on Mix, Phoenix, Rails, a sibling
checkout, or any copied sibling bytes.

SDK-040 already exercises the important compiler-server boundary. A direct
Haxe 4.3.7 build and two builds through one `haxe --wait` process produce the
same plan and input bytes. Declaration facts are recovered from typed module
metadata on every generation, so a cached module cannot create an empty or
stale semantic registry.
