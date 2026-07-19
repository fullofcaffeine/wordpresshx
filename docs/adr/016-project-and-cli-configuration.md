# ADR-016: Project and CLI configuration

- Status: accepted
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product and developer-experience owner); Codex (architecture, contract, and reference review)
- Bead: `wordpresshx-adr-016`
- Profiles/layers: project bootstrap; exact project lock; SDK CLI/build orchestration; local WordPress and Next.js development
- Supersedes: the provisional `wphx-sdk` command spelling in PRD §21
- Superseded by: none

## Context

WordPressHx needs one reproducible way to find a project, select its exact
profile and tools, type its Haxe authority, produce the ADR-006 semantic plan,
publish through ADR-007, and explain every input and output. It also needs a
development loop fast enough to feel native: one initial build, incremental Haxe
typing, normal WordPress and Next.js services, useful URLs, source diagnostics,
and reliable rebuilds without exposing a half-generated site.

Those goals pull configuration in two directions. The CLI needs a small file it
can read before Haxe or macros are available. The product direction, however,
requires Haxe to remain the complete maintained application and site-authoring
surface. A second JSON module graph, JSON service topology, handwritten HXML,
or hand-maintained PHP/JavaScript build file would recreate the drift this SDK
exists to remove.

Watch mode is also a correctness boundary, not merely a filesystem convenience.
Haxe sources, HXX, profiles, locks, assets, macro inputs, compiler identities,
and package metadata can all change output. Browser and PHP stages may be
invalidated independently, but a new `block.json` cannot become visible while
the bundle it names failed. ADR-007 already requires complete staging and a
manifest-last transaction; the development loop must preserve that contract.

The sibling `haxe.elixir.codex` repository demonstrates useful operational
patterns: one fingerprint graph for freshness and watch roots, a debounced
watcher, direct one-shot compilation in bounded commands, an explicitly owned
Haxe `--wait` server with a compatibility cookie, and bounded readiness probes.
It also contains a best-effort output-promotion workaround that is inappropriate
here because ADR-007 supplies the stronger complete transaction. This decision
adapts the concepts only. It copies no source or fixture bytes and creates no
dependency on that checkout.

This ADR fixes the contract. Production Haxe/Genes CLI and development-loop
evidence is recorded separately by `wordpresshx-sdk-043` and
`wordpresshx-sdk-044`. The Python corpus attached to this ADR remains a closed
architecture fixture, not evidence for the shipped watcher or services.

## Decision

### `wphx` is the project-local command

The public binary is `wphx`, supplied by the exact project-local
`@wordpress-hx/cli` package. Generated projects expose ordinary short package
scripts:

```json
{
  "scripts": {
    "build": "wphx build",
    "check": "wphx check",
    "dev": "wphx dev",
    "test": "wphx test"
  }
}
```

`wphx-sdk` was a useful unambiguous prototype name, but it is not the selected
product command. The current private trace prototype may retain that bin alias
while SDK-043 migrates its fixtures. It creates no public compatibility
guarantee and must not appear in generated projects at the stable boundary.

The command families are:

- project creation and change: `init`, `new`, `add`, `generate`, `adopt`,
  `profile`, `lock`, and `upgrade`;
- deterministic bounded work: `build`, `check`, `test`, `inspect`, `trace`,
  `diff-profile`, `clean`, `package`, and `doctor`; and
- the long-running local orchestrator: `dev`.

`new site` is the greenfield happy path. `init` adds the bootstrap to an
existing project without adopting native files. `profile use` and `lock` are
explicit reviewable mutations; ordinary `build`, `check`, and `dev` never
silently rewrite a stale project lock or install a package.

There is no separate stable `watch` command in v1. `wphx dev` is the memorable
one-command loop, and `wphx dev --services=none` is its compile/watch-only form.
`wphx build` is the one-shot equivalent and the default in CI. This avoids two
watch commands whose rebuild semantics could drift.

### The bootstrap is small; the site definition stays in Haxe

The project-root `wordpress-hx.json` conforms to
[`wordpress-hx.project.v1`](../../schemas/project.schema.json). It is a closed
bootstrap contract containing only information required before Haxe typing:

- stable project ID and fully qualified Haxe entry type;
- one explicit exact-profile ID;
- authored source, test, and asset roots;
- generated output, distribution, and private state roots;
- the generated exact-lock path and npm manifest/lock paths; and
- a named environment allowlist with build/runtime and secret classification.

It does not declare WordPress modules, hooks, blocks, theme templates, Next.js
routes, development services, readiness probes, or application behavior. Those
remain typed Haxe authority rooted at `Site.hx` and enter orchestration through
the validated semantic plan. This ordering is intentional: the CLI reads the
bootstrap, types the Haxe authority, publishes the initial complete generation,
then starts the services declared by that generation.

`wphx new` and `wphx init` generate the bootstrap. Conventional greenfield
projects should never need to edit it directly; `profile use`, `lock`, and later
typed scaffold commands make normal changes. The closed JSON remains an
inspectable escape hatch for unusual existing layouts. It is not an alternative
application configuration language.

CLI-owned pre-Haxe projections live below `.wphx/bootstrap/`. Exact generated
locks live at `.wphx/project.lock.json`. Ephemeral ports, process cookies,
leases, compiler sockets, logs, and transaction scratch state live below
`.wphx/runtime/` or `.wphx/transactions/` and are ignored by source control and
build fingerprints. ADR-007 separately owns the generated-file manifest and
publication journal.

### The project lock binds every executable input

`.wphx/project.lock.json` conforms to
[`wordpress-hx.project-lock.v1`](../../schemas/project-lock.schema.json). It is
canonical, self-digested generated data and binds:

- the exact SDK and CLI release pair;
- semantic content of `wordpress-hx.json`;
- the profile catalog revision and digest;
- Haxe, Lix, Genes, the co-located `reflaxe.php` package, Node, npm, the SDK,
  and admitted browser build tools;
- provider-specific immutable identities and a digest of every component lock
  entry; and
- exact `package.json` and `package-lock.json` bytes plus lifecycle-script
  policy.

A release project uses public package or source identities. The checked fixture
uses a clearly labelled co-located SDK identity because no SDK artifact is
published; it does not invent a registry release. Floating sibling paths,
`haxelib dev`, `file:`, `link:`, ranges such as `^1.2.3`, and an implicit global
Haxe are invalid release inputs. Contributor overrides may exist outside the
lock, but `doctor`, packaging, and support evidence report them as non-release
mode.

Npm 10.9.2 with lockfile v3 is the only v1 project package-manager adapter. It
matches the exact Node/WordPress browser lane already under evidence. Pnpm and
Yarn are not treated as approximately compatible; a future adapter needs an
exact install/build/package/runtime matrix and an explicit schema capability.
Using another package manager to invoke the npm CLI artifact does not make its
project graph supported.

`build`, `check`, and `dev` consume an already installed exact graph and perform
no implicit network resolution. Networked resolution belongs to explicit
`new`, `init`, `lock`, or `upgrade` work, produces a reviewable lock diff, and
never accepts a breaking profile or API change automatically.

### Effective inputs are one deterministic graph

Every build materializes
[`wordpress-hx.effective-inputs.v1`](../../schemas/effective-inputs.schema.json)
before typing. The document contains project-relative logical paths and exact
content digests for:

- the bootstrap, project lock, generated HXML, and Haxe tool configuration;
- transitive Haxe/HXX source and test inputs;
- asset/resource roots and current matched files;
- package manifests and lockfiles;
- macro-declared external files;
- exact profile/catalog and compiler/tool identities; and
- explicitly declared non-secret build environment values, represented only by
  SHA-256 in durable machine output.

Discovery roots and their include/exclude patterns are fingerprinted alongside
the current files. Watching a root therefore catches creation, deletion, and
rename, then recomputes the complete graph; a list of only currently imported
files would miss a new module or asset. Generated roots, distributions,
`node_modules`, Git metadata, runtime state, and transaction state are excluded.
Links and special files fail closed rather than expanding the authority graph.

The graph's fingerprint is SHA-256 over canonical normalized JSON with only the
`fingerprint` field omitted. Ordering is explicit; filesystem traversal order,
mtimes, absolute checkout paths, PIDs, ports, wall clocks, locale, shell state,
and undeclared environment variables never enter it. A declared public build
environment value changes both the build fingerprint and compile-server
compatibility. Runtime-only values, including secret values, never do. Secret
names and presence requirements may be diagnosed, but their values are never
written to an event, lock, manifest, receipt, or cache cookie.

Macro APIs must declare external reads before plan completion. A macro that
reads an undeclared file, environment value, clock, network response, or process
state is non-reproducible and fails the supported build. Operational variables
such as `PATH` and a temporary directory may help locate or run an exact locked
tool, but cannot change emitted semantics; `doctor` explains resolution.

Target invalidation is an optimization over this graph. PHP, browser, metadata,
asset, service, and test scopes may rebuild independently only when dependency
edges prove isolation. The ownership publisher still receives a complete next
staging tree, including validated byte-identical artifacts from unaffected
targets. Unknown impact means a full build.

### Build stages and diagnostics are stable

The build-stage vocabulary and order are:

1. `configuration`
2. `profile-resolution`
3. `haxe-typing-and-plan`
4. `php-emission`
5. `browser-emission`
6. `metadata-emission`
7. `format-and-static-check`
8. `asset-build`
9. `artifact-validation`
10. `ownership-publish`

Development orchestration adds `compiler-server`, `service-start`,
`service-readiness`, `watching`, and `shutdown`; these do not reorder or weaken
the build stages. A skipped target stage is emitted explicitly with the graph
reason. `check` runs through complete staged validation without publication.
`build --dry-run` and `--diff` produce the exact action plan without creating a
journal or acquiring publication authority. Dry-run stage events describe the
planner's ordered traversal; `mode: dry-run` never claims that an emitter or
native target process ran. `clean` uses ADR-007's empty-next-
manifest transaction. `inspect` and `doctor` are read-only.

Every diagnostic has a stable `WPHXnnnn` code, severity, stage, exact profile,
project-relative Haxe source position, generated path when one exists, expected
and actual safe values, one or two concrete remediations, and a documentation or
ADR reference. Absolute paths can be rendered locally for a human/editor but do
not enter durable machine output. A compiler or native-tool message without an
exact source mapping remains attached as native context; it is never guessed
into a Haxe span.

Exit-code families are stable:

- `0`: requested bounded work completed successfully;
- `2`: CLI usage or bootstrap configuration error;
- `3`: schema, content-integrity, or ownership error;
- `4`: ambiguous or unsupported contract/capability;
- `5`: source typing, build, check, or test failure;
- `6`: missing or incompatible toolchain/environment;
- `7`: development service/readiness failure;
- `70`: unexpected internal protocol failure; and
- `130`: an interactive long-running command handled SIGINT and cleaned up.

Human output is the default. `--json` emits canonical JSON Lines using
[`wordpress-hx.cli-event.v1`](../../schemas/cli-event.schema.json): one ordered
event per line, a stable run ID and sequence, integer elapsed time, command,
event, stage, status, and a closed payload. Bounded orchestration commands end
with `command-completed`; `dev` streams until shutdown. The existing trace
prototype's `--format json` payload remains readable while SDK-043 introduces
the common envelope; no caller must parse colored prose.

### `wphx dev` owns the complete local loop

The normal sequence is:

1. validate bootstrap and exact lock, then recover/stop on ADR-007 state;
2. discover and fingerprint effective inputs;
3. start or safely attach to the compatible project-local Haxe server;
4. perform an initial complete build and publish it atomically;
5. start typed development services in dependency order;
6. wait on bounded readiness probes and print each resolved URL;
7. subscribe to every discovery root and enter the ready state;
8. coalesce changes, rebuild, and reload only after a new manifest commits; and
9. on SIGINT/termination, stop owned children in reverse order and clear owned
   runtime state.

The default debounce is 100 ms after the most recent event. A burst becomes one
sorted changed-path set. Only one build/publication may run at a time; changes
arriving during a build mark the loop dirty and cause one new build from the
latest graph after the current attempt finishes. There is no unbounded queue and
no parallel ownership transaction.

A failed rebuild never changes the live manifest. The CLI emits the source
diagnostic and `build-retained` with the exact last-good manifest digest; it
does not request reload. The next successful complete publication advances the
generation and may trigger reload. On a fresh project with no last-good
generation, interactive `dev` keeps watching but does not start artifact-
dependent services until a build succeeds. If a verified last-good generation
exists, it may start services against that generation while displaying an
unmistakable stale-build state. `--fail-fast` exits instead and is implied by
non-interactive/CI use.

WordPress PHP changes use a normal full-page reload adapter. Next.js uses its
own admitted development/HMR mechanism. A missing reload adapter leaves the
site running and reports the new generation without fabricating HMR. No Haxe
compiler, watcher, reload client, route dispatcher, or hot-patching protocol is
included in production plugin/theme/Next artifacts.

### The Haxe compile server is isolated and disposable

One-shot `build`, `check`, packaging, and CI compile directly by default. `dev`
starts a project-local Haxe `--wait` server to reuse parsed/typed state. Its
compatibility cookie binds:

- a local hash of the resolved project root (the path itself is not persisted);
- project/config and exact-lock digests;
- Haxe, Genes, `reflaxe.php`, SDK, Lix, classpath, defines, and macro policy;
- generated HXML and dependency/package lock identities; and
- declared public build-environment value digests.

An existing server is attachable only when that entire cookie matches, its
project-local lease names a live owner, and a bounded probe succeeds. A process
that merely answers Haxe `--connect`, an editor's global server, a matching port,
or a stale cookie is not compatible. An attached command does not acquire the
right to kill a server it does not own.

Source and asset changes reuse the compatible server. Changes to HXML, Haxe
configuration, project/lock/package files, compiler identities, classpaths,
defines, or build-environment values restart it before compilation. Ports are
allocated locally instead of relying on a globally fixed port. If the cache
server cannot start, interactive development emits a warning and uses direct
compilation; caching may not change semantics. The owning `dev` process stops
its server on normal exit, handled signal, or supervised failure and verifies
stale state before cleanup.

### Development services are typed Haxe declarations

The Haxe site definition supplies a closed service DAG after plan validation.
Each service has a stable ID and typed provider (`wordpress`, `nextjs`, or an
explicit external escape hatch), dependency IDs, an executable/provider
identity, argv without an implicit shell, working directory, admitted input and
output scopes, environment allowlist, port policy, readiness probe, restart
policy, URL projection, and reload behavior.

The ordinary providers choose preferred ports (WordPress 8888 and Next.js 3000
in the contract fixture), reserve an available port, and record the local choice
only under `.wphx/runtime/`. A user override is exact and fails with a useful
occupant/alternative diagnostic rather than killing an unrelated process.
Readiness is bounded—60 seconds by default in the fixture—and may use a typed
HTTP, TCP, process, or admitted log probe. A process existing is not equivalent
to an HTTP service being ready.

Secret runtime variables are passed only to declared services and are redacted
from output. Commands are spawned in owned process groups. Graceful termination
has a bounded timeout followed by forced termination of owned descendants;
compatible attached processes are never killed. Unexpected exits produce a
structured service diagnostic and follow the typed bounded restart policy rather
than an infinite silent loop.

This contract deliberately leaves exact provider packages and final typed API
names to SDK-044 and the site/Next integration beads. It fixes their semantics
so implementation cannot move service configuration back into handwritten
JavaScript or arbitrary shell strings.

### Versioning, migration, and rollback

Unknown bootstrap, lock, effective-input, or event fields fail. A change to
field meaning, fingerprint material, environment authority, path safety,
command semantics, stage order, event state meaning, or server compatibility
requires a new major schema identity. Additive commands/events and a newly
proven package-manager provider require explicit producer/consumer negotiation;
an older CLI may never silently ignore them.

Lock migration is an explicit `wphx upgrade`/`wphx lock` plan with old/new
digests and package/profile differences. A normal build does not migrate.
Rollback restores the prior Haxe source, bootstrap, and exact lock, then rebuilds
through the same transaction. Generated-output VCS defaults remain ADR-017's
decision; this ADR requires the bootstrap and exact lock to be available to a
clean supported build regardless of output policy.

## Rationale

The small bootstrap solves the unavoidable pre-compiler discovery problem
without creating a second application model. Typed Haxe retains the dense,
checked site and service surface, while the CLI still has enough information to
select exact tools and fail before executing an untrusted or incompatible
graph.

One effective-input contract keeps one-shot builds, watch mode, compiler-server
reuse, dry-run, CI freshness, and `inspect --why` aligned. Directory discovery
rules cover new files; content digests remove mtimes and checkout locations;
explicit environment classes keep secrets and local ports out of reproducible
authority.

`wphx dev` gives the user one obvious entry point. Initial publication before
services, last-good retention, and reload-after-commit make the fast path obey
the same safety boundary as production builds. A compatible isolated Haxe
server improves latency without making global process state part of correctness.

## Alternatives considered

### Put the entire project graph in `wordpress-hx.json`

This would let Node plan everything without first compiling Haxe. It is rejected
because modules, blocks, templates, services, schemas, and target relationships
would be duplicated outside the typed application surface. JSON would become
the real framework and Haxe a callback language.

### Use only `Site.hx` and no bootstrap file

This is aesthetically pure, but the CLI would need undocumented conventions or
global state to find the entry point, profile, dependency manager, and compiler
before it could type `Site.hx`. It is limited to the greenfield convention; the
small generated bootstrap is the explicit existing-project and tooling seam.

### Require handwritten HXML/package scripts and native service configuration

These are familiar to Haxe/Node developers. They are rejected as maintained
authority because they drift from typed declarations and violate the Haxe-only
happy path. CLI-owned HXML and generated ordinary package scripts remain
inspectable projections and escape hatches.

### Support npm, pnpm, Yarn, and Bun immediately

This broadens adoption but multiplies install graph, lifecycle, lockfile,
WordPress scripts, packaging, and CI behavior before the first project is
proven. It is deferred in favor of exact npm evidence and independent adapters.

### Share any reachable global Haxe compilation server

This maximizes cache reuse. It is rejected because different Haxe versions,
classpaths, defines, macro inputs, or compiler plugins can reuse incompatible
state or crash the compiler. Exact compatible attach is the only shared case.

### Let every emitter or watcher update its output directly

This can feel faster for one file. It is rejected because cross-target metadata
can point to missing output and users can observe deleted/recreated bundles.
Complete ADR-007 publication and last-good retention are required even for
incremental development.

### Add a separate `wphx watch` command

This makes compile-only use explicit but creates overlapping long-running
semantics. It is rejected for v1; `wphx dev --services=none` exposes the same
lower-level mode without a second lifecycle contract.

### Copy the sibling Elixir watcher/server implementation

That code is coupled to Mix, OTP, its application tree, and its own output
promotion needs. Copying it would add the wrong runtime and lifecycle model. The
decision records only its general fingerprint, debounce, compatible-server,
ownership, and readiness lessons.

## Consequences

Benefits:

- Greenfield users type `npm run dev` or `wphx dev` and keep site/service
  semantics in Haxe.
- Clean builds and watch rebuilds use the same exact inputs, stages, locks, and
  publication boundary.
- Editors and CI receive a stable JSONL stream with source-correlated errors.
- Runtime secrets, ports, paths, PIDs, and clocks cannot poison reproducibility.
- Incremental Haxe compilation is fast without attaching to an arbitrary global
  cache.
- WordPress and Next.js can be supervised together without introducing a
  production application kernel.

Costs and limits:

- The CLI must implement filesystem watching, process groups, port reservation,
  readiness, signal behavior, and cache-cookie validation across supported
  hosts.
- V1 deliberately supports only npm and direct/managed Haxe compilation.
- Typed service declarations cannot be known until an initial Haxe plan exists,
  so fresh broken projects can watch but cannot start artifact-dependent
  services.
- Automatic WordPress page reload needs an admitted development adapter; it is
  not a PHP HMR claim.
- The contract corpus proves architecture and deterministic state transitions,
  not real watcher latency, process cleanup, Next.js, WordPress, Windows, or
  production behavior.

## Evidence and commands

The executable corpus contains four closed schemas, a synthetic Haxe-only
consumer, an exact generated project lock, a nine-file effective-input graph,
five discovery roots, eight toolchain components, a 22-event bounded dry-run,
and a 23-event development transcript. The development transcript proves the
required order: initial publish, service readiness, watch readiness, two-change
coalescing, source failure, exact last-good retention with no reload, repaired
publication, WordPress full reload, Next native HMR, and reverse-order shutdown.

Run:

```bash
bash scripts/project-cli/test.sh
```

The gate also proves deterministic replay; build-environment invalidation;
runtime-secret exclusion; new-source discovery; generated-output exclusion;
dry-run non-mutation; link/special-file rejection; and 28 fail-closed mutations.
The current expected summary is recorded in
[`project-cli-architecture.json`](../../manifests/project-cli-architecture.json).

Read-only reference review used `haxe.elixir.codex` commit
`40254f38d9c07c069c7c3e19831096dcc2d6c95d`:

- `lib/haxe_watcher.ex` for 100 ms debounce and watcher ownership;
- `lib/mix/tasks/haxe.watch.ex` for direct bounded compilation, managed watch
  mode, and effective watch roots;
- `lib/haxe_server.ex` for the compatible cookie, explicit attach policy, and
  owned process cleanup;
- `lib/haxe_compiler.ex` for direct/server fallback and freshness integration;
- `tooling/phoenix_scaffold/src_haxe/phoenix_scaffold_tooling/GenesContract.hx`
  for a Haxe-authored host-tool contract; and
- `scripts/qa-sentinel.sh` for bounded asynchronous readiness.

Exact blobs and SHA-256 values are in the machine architecture manifest. No
bytes were copied, no dependency was created, and Genes source was unchanged.

## Migration, rollback, and supersession

SDK-043 introduces `wphx` while keeping the frozen private trace entry and its
evidence readable at `wphx-sdk`. Generated projects use only `wphx`; historical
trace fixtures retain their authenticated spelling. A project created before
this ADR is initialized explicitly; existing source/native files remain
unowned until a separate adoption action.

Before stable release, a clean installed consumer must reproduce its lock and
effective graph without monorepo or sibling paths. If the selected command,
bootstrap split, npm-only policy, event stream, or server isolation proves
unworkable, this ADR is superseded with an explicit schema/command migration;
implementations may not drift in place.

## Follow-up beads

- `wordpresshx-sdk-040`: collect the Haxe semantic plan consumed by this CLI.
- `wordpresshx-sdk-041`: implement the ADR-007 production publisher used by
  every build and rebuild.
- `wordpresshx-sdk-043`: implement the Haxe/Genes `wphx` command foundation,
  project/lock validation, stages, diagnostics, JSONL, and dry-run.
- `wordpresshx-sdk-044`: finish the typed service supervisor, ports, readiness,
  and reload adapters on top of the implemented Haxe server, effective watcher,
  last-good behavior, and compiler cleanup core.
- `wordpresshx-sdk-112` through `wordpresshx-sdk-117`: consume the same contract
  in the landing, blog, commerce, and Next.js reference sites.

## SDK-043 and SDK-044 implementation status

The bounded command foundation is implemented in Haxe and emitted as Node ESM
by immutable Genes 1.36.3. It validates the generated bootstrap and exact lock,
derives the accepted effective-input graph, types the Haxe project directly,
and exposes build/check/inspect/clean/doctor plus canonical JSONL diagnostics.
Build publication uses the SDK-041 manifest-last owner; all read-only commands
and dry-run are proven not to publish. The original trace entry and ownership
JSON implementation remain byte-identical to their earlier receipts.

SDK-044 now supplies the initial atomic build, managed project-local Haxe wait
server, effective-input watcher, conservative serialized rebuild, last-good
retention, edit-during-build retry, and clean compiler shutdown. The
compile/watch-only form is production-gate tested on exact Linux Node 22.17.0.
Typed WordPress/Next.js service processes, readiness, service ports, and reload
adapters are still non-claims and are reported as skipped rather than inferred
from shell configuration. The exact SDK-043 implementation is in
[`project-cli-implementation.json`](../../manifests/project-cli-implementation.json)
and [`SDK-043-PROJECT-CLI`](../../manifests/evidence/sdk-043-project-cli.json);
the SDK-044 core and its bounded non-claims are in
[`dev-loop-implementation.json`](../../manifests/dev-loop-implementation.json)
and [`SDK-044-DEV-LOOP`](../../manifests/evidence/sdk-044-dev-loop.json).
