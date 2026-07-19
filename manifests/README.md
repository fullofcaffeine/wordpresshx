# Locks and evidence manifests

This directory contains immutable toolchain/upstream locks, architecture locks, evidence receipts, and future release manifests. No placeholder hash may be interpreted as a pin; exact identities are added by the corresponding gate bead.

- `package-topology.json` is the accepted ADR-003 public-artifact, source-module, dependency-direction, and independent-versioning map. Its `not-published` claim and `publicationAuthorized: false` are deliberate; topology acceptance is not a registry release.
- `php-emission-policy.json` is the accepted ADR-005 semantic file/symbol/edge
  classification, native public PHP ABI, bounded private stock-Haxe lane,
  adapter, HXX, evidence, stop, and pre-G8 migration/removal lock. Its G1
  evidence remains `not-tested`, stock-Haxe output is not guaranteed after
  `1.0`, and publication remains blocked.
- `runtime-support-packaging.json` is ADR-018's accepted per-deployable,
  dependency-closed private-support contract. It derives a stable private PHP
  prefix and authoritative class map from typed Haxe project/module authority,
  discards stock Haxe's process-global front controller, guards the exact
  process-wide polyfill ABI before private boot, keeps the MVP runtime Composer
  graph empty, and forbids a shared site runtime. Its executable prototype does
  not implement SDK-024, admit runtime Composer packages, retain the stock-Haxe
  lane after `1.0`, or claim production support.
- `private-runtime-implementation.json` records SDK-024's production
  integration of that contract. A single typed Haxe static method reference
  selects a dependency-closed stock-Haxe PHP closure; the CLI derives its
  per-plugin 96-bit prefix, exact class map, guarded polyfill boundary, native
  public adapter, artifact inventory, and ownership metadata. The zero-argument
  plugin declaration still packages no private runtime. This bounded title
  filter proof does not claim arbitrary Haxe-to-PHP coverage, admitted runtime
  Composer packages, qualified license approval, post-`1.0` retention, or
  production support.
- `php-quality-implementation.json` records SDK-026's Haxe-inferred,
  complete-stage generated-PHP gate. The CLI authenticates an exact Composer,
  PHPCS/WPCS, PHPCompatibility, PHPStan, and WordPress-stub graph, applies
  versioned public/private policies before publication, and owns a canonical
  report bound to every emitted plugin artifact. Projects maintain no PHP tool
  configuration; a failed or tampered policy has no publication authority.
- `hxx-architecture.json` is the accepted ADR-011 inline-authoring, parser-selection, generic-PHP/WordPress lowering ownership, safety, density, escape-hatch, and no-runtime lock. SDK-080 resolves its parser closure through `packages/hxx/dependency-lock.json` and proves only the bounded parser-adapter prototype; native lowering remains owned by later evidence beads.
- `browser-build-architecture.json` is the accepted ADR-013 strict TS/TSX
  primary lane, bounded classic Genes differential, exact project
  Node/npm/TypeScript tuple, public export/DCE retention, normal WordPress
  package externalization, and final-asset authority lock. SDK-031 through
  SDK-035 now provide the bounded strict fixture, Gutenberg HXX, bundle/asset
  parity, source-map, and classic runtime evidence. Those receipts do not
  broaden the explicit fixture corpus into a universal output switch or
  production-support claim.
- `source-correlation-architecture.json` is the accepted ADR-014 content-bound
  PHP range-map, package source-index, browser composition/two-stage fallback,
  offline trace, logical-path, and debug-retention lock. SDK-025 implements the
  native PHP path and SDK-034 implements the exact esbuild/real-Chromium browser
  path. Receipt `G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION` projects the same
  contract through the exact SDK-033 entry and official development/production
  commands into a private debug companion; none of these bounded receipts is
  general production support.
- `semantic-plan-architecture.json` is the accepted ADR-006 canonical plan,
  content-addressed node-schema registry, stable identity/source-span,
  build-time extension, and staged-emitter boundary. Its two-node contract
  fixture proves schema/canonicalization/traceability rules only; it remains a
  historical contract record and does not retroactively claim the SDK-040
  implementation.
- `semantic-collector-architecture.json` is the SDK-040 implementation lock for
  typed module/hook/resource/public-environment declarations, compilation-server
  metadata recovery, canonical plan and input-sidecar generation, exact-profile
  validation, and the SDK-043/044 development-loop handoff. It does not claim a
  production emitter, target publication, or real `wphx dev` service loop.
- `generated-artifact-ownership.json` is the accepted ADR-007 exact-path/hash
  authority, portable path confinement, complete-stage, manifest-last journal,
  recovery, clean, and adoption lock. Its temporary-filesystem harness validates
  the historical contract. `ownership-implementation.json` records the SDK-041
  Haxe/Genes implementation, its exact runtime profile, and its bounded locked
  Linux filesystem evidence; target emitters remain later work.
- `project-cli-architecture.json` is the accepted ADR-016 bootstrap, exact-lock,
  effective-input, `wphx` command/stage/event, isolated compiler-server, and
  one-command development-loop lock. Its synthetic transcript proves dry-run,
  last-good, reload-order, and shutdown semantics. The separate
  `project-cli-implementation.json` records SDK-043's real bounded Haxe/Genes
  command, exact input resolver, read-only modes, and ownership publication.
- `scaffold-implementation.json` records SDK-045.1's Haxe-first `wphx new site`
  and `wphx init` foundation: one-slug derivation, exact typed dry-runs,
  same-filesystem staging, collision/link refusal, marker-bounded hand-owned
  edits, and exact rollback. Native site/plugin/block producers and public
  package installation remain explicit non-claims.
- `plugin-scaffold-implementation.json` records SDK-045.2's Haxe-first
  `wphx new plugin` path: a zero-argument typed declaration derives ordinary
  metadata, the existing structured WordPress PHP profile emits readable
  native files, and the established owner publishes a deterministic plugin ZIP.
  Its receipt covers compile-server reuse and clean WordPress activation while
  keeping hooks beyond bootstrap and public package installation as non-claims.
- `dev-loop-implementation.json` records SDK-044's real compile/watch core:
  managed project-local compiler lifecycle, effective-graph subscriptions,
  coalesced serialized rebuilds, input-stability checks, last-good retention,
  clean compiler shutdown, and strictly typed external-service supervision with
  bounded readiness, collision-safe ports, restart, and reverse shutdown. It
  also records the Haxe-derived `wp70-release` provider's exact image lock,
  private generated Compose configuration, secret interpolation, and bounded
  lifecycle. Its controlled process/configuration proof is distinct from a real
  `wphx dev` WordPress-container run. It also records the Haxe-authored,
  Genes-emitted embedded reload client, capability-protected loopback stream,
  private development MU-plugin, and controlled-boundary real-Chromium proof.
  The optional Next.js adapter remains an explicit non-claim.
- `plugin-development-implementation.json` records SDK-044.3's ceremony-free
  generated-plugin development path. The current compiler `PluginPlan` is the
  sole inference authority; plain `wphx dev` revalidates the exact emitted
  plugin tree, mounts it read-only, performs a fresh WordPress install and
  native activation before readiness, retains the active last-good generation,
  reloads only after a complete publication, and removes all owned Docker and
  private runtime resources. It does not broaden this bounded plugin proof into
  a complete generated-site, Next.js, or production-support claim.
- `deterministic-build-implementation.json` records SDK-042's Haxe/Genes
  reproducibility report, fixed-representation unsigned ZIP writer, complete
  owned-generation comparator, two-fresh-root gate, and safe additive
  migration from the SDK-043 metadata-only output-root set.
- `release-support-policy.json` is the accepted ADR-021 finite-channel, exact-matrix, ownership, deprecation, security, direct-main contribution, release, and immutable-rollback contract. Its empty supported-version list and disabled publication flags are deliberate stable blockers, not placeholders.

- `upstream.lock.json` records resolved cross-project inputs. Its `partial` status means only the listed entries are pinned; omitted upstreams remain unresolved rather than receiving guessed or floating values.
- `toolchain.lock.json` is the closed G0 aggregate projection over the exact
  Haxe, formatter, Genes, co-located PHP compiler, Node/PHP images, Lix, and HXX
  inputs. It also records the SDK-026 build-only Composer graph and inactive
  root npm graph explicitly. The
  aggregate does not make a package publishable and later gates must add or
  supersede an entry before admitting a new input.
- `evidence/` contains the command, environment, hosted-CI, limitation, and artifact evidence behind a lock entry.

The first resolved external input is genes-ts `v1.33.0`, recorded by
`wordpresshx-sdk-030`. SDK-031 preserves that selection record and admits the
active `v1.36.3` browser fixture through
`packages/gutenberg/dependency-lock.json`, which proves the baseline, generic
fix, reviewed merge, and release lineage. The canonical public Git and Beads
transport is recorded by `evidence/sdk-004-canonical-repository.json`. The
first co-located PHP compiler import is recorded by
`evidence/sdk-020-reflaxe-php-bootstrap.json`; it is an internal source receipt,
not an external release pin.

Receipt `SDK-031-STRICT-BROWSER-PROFILE` records the generalized upstream
Array-index fix, immutable Genes v1.36.3 admission, strict/classic compiler
differential, public ESM retention, weak-type inventory, ordinary JavaScript
runtime, deterministic generated tree and bundle hashes, and local portability
boundary. It does not claim React/Gutenberg HXX or WordPress browser-runtime
support; those remain SDK-032 and later evidence.

Receipt `SDK-032-REACT-GUTENBERG-HXX` records direct inline-markup returns,
the SDK-owned neutral parser tree, exact-profile Button/Notice and hook
contracts, typed events/refs/context/children/control flow, deterministic
runtime and visual bundles, compile negatives, real React/Gutenberg behavior,
source-map composition, and local Chrome accessibility/visual review. It does
not claim dependency extraction, translations, real WordPress editor loading,
the classic differential, complete G2 closure, publication, or production
support.

Receipt `SDK-035-CLASSIC-GENES-DIFFERENTIAL` compiles one retained Haxe/HXX
facade through strict TSX and classic JavaScript plus declarations from the
same immutable Genes 1.36.3 input. It compares the authored public contract,
strict external consumers, pure data behavior, React SSR, mounted hook state,
and a real click transition across byte-identical clean replays. Expected
printer differences are classified separately; no unexplained semantic or
contract difference is admitted. The receipt is bounded to this corpus and
does not make classic output the default or claim arbitrary same-source
switching.

Receipt `ADR-006-SEMANTIC-PLAN-CONTRACT` records the closed plan/emission
schemas, content-addressed node schemas, canonical fixture digests, source and
artifact traceability, sibling-pattern provenance, six canonicalization
vectors, and 21 fail-closed mutations. It is architecture-contract evidence;
SDK-040 collection and SDK-041 ownership publication now have separate
implementation receipts; real emitters and runtime compatibility remain
unproven.

Receipt `ADR-018-RUNTIME-SUPPORT-PACKAGING` records the dependency-closed
private-support architecture prototype. Strict Haxe logic is compiled twice
under two derived 96-bit PHP prefixes, while a generated authoritative class
map replaces the stock front controller. The bounded packages are byte-equal,
remain below the review ceilings, coexist on PHP 7.4/8.4 and clean WordPress
7.0, expose only native public signatures, and contain no runtime Composer
graph. SDK-024 production integration, runtime Composer packages, independent
PHP readability review, final ZIP/SBOM, post-`1.0` retention, and production
support remain explicit non-claims.

Receipt `SDK-024-PRIVATE-PHP-RUNTIME` records the corresponding production CLI
path. The compile-time plugin plan retains the exact typed callback identity and
source range, full DCE packages only its reachable closure, and a generated
native adapter exposes only `string, int -> string`. Two independently built
plugins are byte-deterministic, use distinct derived prefixes, coexist on PHP
7.4/8.4 and clean WordPress 7.0, reject an incompatible process-wide polyfill
before private boot, and remain below the recorded size and cold-boot ceilings.
The receipt remains bounded to `titleFilter`; general hooks, runtime Composer
dependencies, qualified license approval, post-`1.0` retention, and production
support are explicit non-claims.

Receipt `SDK-026-GENERATED-PHP-QUALITY` records the exact generated-PHP policy
and its Haxe CLI transaction. Three compiler fixtures produce deterministic
receipts; syntax, formatter, WPCS security, PHPStan, symbol, installed-policy,
and private-classmap mutations fail before publication. Public and private
plugin reports are canonical, byte-bound to the emission and ownership
manifest, and exercised on PHP 7.4/8.4 and clean WordPress 7.0. The tool graph
is build-only and absent from generated runtime artifacts.

Receipt `SDK-027-GENERIC-PHP-COMPILER-READINESS` records the co-located
compiler's independently installable package seam. Two deterministic
source-only archives are byte-identical; the exact archive installs into a
disposable local Haxelib repository and a neutral external Haxe application
emits, lints, and runs PHP without resolving WordPressHx or a checkout path.
It also records generic-versus-WordPress issue routing and the trigger-based,
history-preserving extraction procedure. No repository split or package
publication is claimed.

Receipt `SDK-040-SEMANTIC-COLLECTOR` records the first real Haxe macro
collector, four deterministic direct/server compilations, ten source-located
compile failures, five schema/input mutations, exact effective inputs, and
full-DCE runtime absence. It emits intermediate plan/input artifacts only;
the SDK-041 owner is implemented separately, while target emitter integration
and SDK-044 application services remain unproven.

Receipt `SDK-043-PROJECT-CLI` records the Haxe-authored, Genes-emitted `wphx`
command foundation. Its exact Node corpus covers strict discovery and lock
validation, parity with ADR-016's effective-input fingerprint, direct Haxe
typing, no-write check/inspect/doctor/dry-run behavior, manifest-last build,
provenance, exact clean, tamper rejection, and preservation of the frozen
`wphx-sdk` trace entry. PHP/browser/asset emitters, real WordPress/Next.js
runtimes, and production support remain explicit non-claims.

Receipt `SDK-045-SCAFFOLD` records the Haxe-authored project-creation surface.
Its exact Node corpus proves two fresh byte-identical trees, JSON and human
plans, no-write dry-runs, bounded `.gitignore` marker replacement, collision,
unsafe-name/profile/kind and live/dangling-link rejection, projection-drift
diagnostics, a forced mid-publication rollback, actual Haxe typing, and the
current doctor/check/build foundation. It does not claim a deployable WordPress
site, native target emitters, installed public packages, or production support.

Receipt `SDK-044-DEV-LOOP` records the Haxe-authored compile/watch loop on exact
Linux Node 22.17.0. Its controlled process corpus proves initial publication,
burst coalescing, source failure retention, nested HXX create/rename/delete,
lock repair, compiler-identity restart, edit-during-build follow-up, SIGINT
cleanup, path privacy, byte equality with a clean build, authenticated typed
service-plan consumption, dependency-order external processes, HTTP/log/TCP
readiness, collision recovery, bounded restart exhaustion, secret
non-propagation, and reverse shutdown. Its built-in WordPress provider case
additionally proves exact locked image selection, private canonical mode-`0600`
Compose generation, real Compose v2 syntax validation, placeholder-only secret
configuration, no restart for an unchanged service graph, post-publication
reload-request ordering, and normal process/config cleanup. Its strictly typed
Haxe reload client is compiled twice by pinned Genes, deterministically bundled
and embedded, then exercised in real Chromium against the controlled WordPress
boundary. The runtime proves five endpoint-security mutations, no navigation
after a failed build, exactly one full-page navigation after the repaired
manifest-last publication, and absence from production-owned artifacts.
SDK-090 separately runtime proves the exact WordPress/MariaDB image pair. The
receipt does not claim that SDK-044 starts that real pair, mounts a generated
site, implements the optional Next.js adapter/native HMR, or supports Windows/
network filesystems, package publication, or production use.

Receipt `SDK-044-INFERRED-PLUGIN-DEVELOPMENT` records the additive SDK-044.3
proof. A freshly scaffolded plugin uses only its existing
`WordPress.plugin()` declaration and plain `wphx dev`; the SDK derives the real
WordPress 7.0/MariaDB service from the typed compiler plan, rejects extra plugin
tree entries before service start, installs and activates the native plugin,
gates readiness on active-plugin HTTP success, suppresses reload after failure,
reloads the next committed generation without restarting WordPress, and removes
containers, network, named and anonymous volumes, compiler state, and private
files on shutdown. Complete site generation, Next.js, publication, and
production support remain separate work.

Receipt `SDK-042-DETERMINISTIC-BUILD` records two clean builds in unrelated
fresh roots, byte-identical Genes output and complete owned generations, a
canonical reproducibility report, fixed-mode/fixed-time stored ZIP entries,
path-privacy scanning, three actionable comparison failures, and the safe
additive migration from SDK-043's existing output-root set. The bounded archive is
not yet a deployable WordPress or Next.js package.

Receipt `ADR-007-GENERATED-ARTIFACT-OWNERSHIP` records the closed exact-file
manifest and journal schemas, canonical old/new/create/replace/remove fixtures,
portable path and collision rules, real temporary-filesystem rollback/recovery,
manifest-only clean, explicit relinquishment, 11 positive filesystem scenarios,
17 fail-closed filesystem cases, and 25 schema/journal mutations. It remains the
historical contract receipt; the SDK-041 implementation has its own receipt.
Power-loss/Windows behavior, real site trees, packaging, and production support
remain untested.

Receipt `SDK-041-OWNERSHIP-TRANSACTION` records the Haxe-authored,
Genes-emitted Node implementation of exact manifest ownership, complete private
staging, journal-before-mutation publication, manifest-last commit, exact-hash
rollback/finalization, manifest-only clean, and explicit adoption. Its locked
Linux/Node corpus includes deterministic compiler replay, 17 successful
invocations, 26 fail-closed invocations, and all 13 durable crash checkpoints.
It does not claim power-loss durability, Windows or network filesystems,
hostile concurrent mutation, final `wphx` command integration, real WordPress or
Next.js generated trees, or production support.

Receipt `ADR-016-PROJECT-CLI-CONFIGURATION` records four closed schemas, a
synthetic Haxe-only consumer, an exact generated project lock, nine effective
files, five discovery roots, eight toolchain components, 22 dry-run events,
23 development events, and 28 fail-closed mutations. It establishes no real
watcher, service, browser reload, installed-consumer, or production claim.

`upstream.lock.json` now also includes the exact `wp70-release` source authority. Its detailed source/distribution lock lives under `profiles/wp70-release/`, and receipt `SDK-010-WP70-RELEASE-SOURCE` records direct clean materialization. The recorded capability level is only `inventoried`; runtime and production claims remain `not-tested`.

The exact `gutenberg-forward-23.4` authority is a separate lock entry and profile tree. Receipt `SDK-011-GUTENBERG-FORWARD-23.4` records direct source/release materialization, compile-admission negatives, and final-artifact leak scans. It remains experimental; WordPress 7.0 compatibility is forbidden and runtime/production claims are `not-tested`.

Receipt `SDK-012-PROFILE-SCHEMA` records the closed profile schema, exact minimal fixtures, Haxe profile/capability contracts, compile-fail availability checks, and request-scope separation. It validates how future catalogs are represented; it does not generate the SDK-013 catalogs or advance WordPress/browser/production compatibility.

Receipt `SDK-013-PROFILE-GENERATOR` records the exact-object, read-only catalog generator, its reviewed selection contract, committed catalog/omission/report hashes, double-run equality, known-entry checks, and failed-publication negative. The 33 emitted capabilities are lexical inventories only. Four ambiguous or private candidates are explicit omissions; no typed, runtime, browser, package, or production claim advances.

Receipt `SDK-014-PROFILE-DIFF` records the read-only exact-catalog comparison tool, its closed content-digested JSON report, human migration diagnostics, reviewed contract payload rules, upstream-versus-correction authority checks, and golden/negative fixtures. Its synthetic target profile is not compatibility evidence; the tool infers no range, rewrites no source, and auto-accepts no breaking change.

Receipt `SDK-003-RELEASE-GOVERNANCE` records the closed policy validator and deterministic issue/security/release/rollback rehearsal. The rehearsal is synthetic: private reporting remains disabled, the backup role remains unassigned, stable publication remains blocked, no registry credential or package is exercised, and no SLA or production-support claim is created.

Receipt `ADR-020-LICENSE-AUDIT-PREPARATION` records the provisional licensing
policy, exact component/origin inventory, generated-output model, human review
packet, deterministic blocked-publication diagnostic, and negative mutations.
It deliberately records no license grant or qualified acceptance; ADR-020 and
SDK-002 remain open and all public publication remains blocked.

Receipt `CI-CHECKOUT-NODE24` records the official `actions/checkout` v7.0.0
release, exact verified commit/tree/license evidence, Node 24 runtime declaration,
all eleven immutable workflow pins, and preservation of full Git history only for
the security lane. Its hosted claim is limited to the exact GitHub-hosted
Ubuntu 24.04 workflow run; it creates no SDK or generated-artifact claim.

Receipt `G0-PRODUCT-AUTHORITY-BASELINE` closes the independent product,
repository, exact-profile, toolchain, classification, full-port-separation, and
reference-hash feasibility baseline. It deliberately leaves ADR-020 and SDK-002
open and publication blocked: the PRD assigns qualified licensing review to the
release path, not to permission for experimental G1–G3 work.

Receipt `SDK-090-WORDPRESS-HARNESS` records the exact WordPress 7.0 container distribution proof and fresh installed runtime lanes over MySQL 8.4.10 and MariaDB 11.4.5. It advances only the vanilla harness and named environment evidence. SDK behavior, browser compatibility, packaged plugin/theme installation, PHP 7.4 WordPress hosting, and production support remain untested.

Receipt `SDK-022-WORDPRESS-PUBLIC-PHP-PROFILE` records the first Haxe-authored,
structured public PHP plugin bootstrap: deterministic native headers, direct
access guard, local autoload, and stable namespaced boot class. Exact PHP
7.4/8.4 native callers and real WordPress 7.0 activation over both database
lanes pass. Hook/REST/block adapters, lifecycle behavior, WPCS/static analysis,
independent readability sign-off, publication, and production support remain
separately gated.

Receipt `SDK-080-HXX-PARSER-PROTOTYPE` records the exact `tink_hxx` 0.25.1 artifact and five-transitive closure, parser-only adapter, normal Haxe expression and closed-spread typing, named slots, relative source spans, server/browser semantic parity, target-leakage negatives, density snapshots, and final-artifact no-runtime scans. Its stock PHP/JavaScript carriers are evidence-only; it does not advance native `reflaxe.php`, Genes, WordPress runtime, or production claims.
