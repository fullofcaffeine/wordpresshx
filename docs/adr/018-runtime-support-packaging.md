# ADR-018: Runtime support packaging

- Status: accepted
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product owner and Haxe-first direction), Codex (PHP packaging architecture and executable prototype review)
- Bead: `wordpresshx-adr-018`
- Profiles/layers: `wp70-release`, SDK PHP packaging, bounded stock-Haxe private lane, Composer boundary, generated WordPress deployables
- Decision lock: `manifests/runtime-support-packaging.json`
- Supersedes: none
- Superseded by: none

## Context

ADR-005 makes native, structured PHP the WordPress-facing boundary and permits
stock Haxe PHP only behind generated native adapters. Stock Haxe supplies useful
private Haxe semantics, but even a small PHP compilation retains a non-trivial
Boot and standard-library closure. WordPress then loads independently versioned
plugins and themes into one PHP process. A support package that is global,
unprefixed, remotely installed, or loaded through a process-wide search path can
therefore make one deployable depend on another deployable's load order or
runtime version.

The common authoring path must remain substantially simpler than PHP packaging.
A Haxe developer should declare application behavior, not select an internal
namespace, construct a Composer graph, copy runtime helpers, or understand the
stock PHP front controller. Haxe and the semantic plan already know the logical
project, module, compiler identity, reachable private closure, and public
adapter edges. Those are sufficient to derive the safe defaults.

The stock Haxe 4.3.7 PHP probe also exposes one concrete hazard: `php-prefix`
correctly prefixes generated classes, but the generated front controller adds
its library directory to PHP's process-wide `include_path`. Once more than one
plugin has loaded, an earlier autoloader can resolve a later plugin's class
through that shared search path. Unique class names keep the bytes correct in
the bounded probe, but ownership and load isolation are no longer local. The
front controller is an application launcher, not a suitable WordPress package
autoload contract.

This decision resolves the MVP package, namespace, autoload, Composer, conflict,
budget, and future-sharing rules. SDK-024 still owns production integration and
the full private Haxe fixture. Acceptance here proves the package architecture;
it does not turn the provisional stock-Haxe lane into a `1.0` guarantee.

## Decision

### Haxe derives the common path

The routine Haxe author writes no runtime-support configuration. The typed build
layer derives the private closure, package identity, namespace prefix, class
map, bootstrap order, inventory, and boundary scans from the semantic plan and
exact toolchain lock.

The normal declaration remains application-shaped. Enabling a feature that
needs private support causes Haxe typing to add a reasoned dependency edge; it
does not require a `RuntimeConfig`, a namespace string, `composer.json`, or a
PHP bootstrap fragment. Advanced inspection and policy overrides may be typed,
but there is no override that disables isolation, inventory, exact locking, or
public-ABI validation.

An unknown runtime need, missing transitive helper, unclassified edge, or
unrepresentable native adapter rejects the build before publication. The SDK
does not silently fall back to the full stock runtime.

### One dependency-closed support package per native deployable

For the MVP, every plugin or theme using the private lane contains its own
transitively complete private implementation and support closure. It neither
requires nor provides a site-global WordPressHx runtime. Removing or disabling
one deployable cannot break another generated deployable.

The package layout is:

```text
<plugin>/
  <plugin>.php                         public-native root
  includes/
    autoload.php                       one root include and loader boundary
    Bootstrap.php                      public-native boot class
    ...                                public-native adapters/registrations
  private/wordpresshx/
    classmap.php                       generated authoritative private map
    runtime/<prefixed namespace>/...   dependency-closed stock-Haxe PHP
    runtime-manifest.v1.json           non-executing exact inventory
```

The exact owner may omit `private/wordpresshx/` when the private closure is
empty. It never emits an empty runtime, placeholder files, or a Composer graph
just to preserve the directory shape. All paths are owned by the same
manifest-last transaction as the public plugin files.

Only transitively required generated classes, runtime helpers, polyfills, and
initialization files are packaged. DCE is useful input, not proof of closure:
the packager verifies every generated class reference and required file against
the final inventory. Missing and extra executable PHP both fail the package.

### Namespace identity is stable, derived, and package-specific

The private Haxe prefix is derived as follows:

```text
identity = "wordpress-hx.private-runtime.v1\0" + projectId + "\0" + moduleId
prefix   = "wphx_internal.p" + first_24_lower_hex(SHA-256(identity))
```

The dot-separated value is passed to stock Haxe as `-D php-prefix=<prefix>`.
The 96-bit suffix gives unrelated logical deployables different private class
names while keeping a deployable's generated names stable across ordinary
source edits. `projectId` and `moduleId` are already closed, lowercase Haxe
authorities. Users do not choose or repeat the prefix.

The complete 256-bit derivation digest, inputs, emitted prefix, Haxe version,
and stock PHP target identity are recorded. A workspace collision between
logical identities or emitted case-insensitive PHP names is a planning error.
The package scanner also rejects an emitted class, function, constant, or file
outside the declared private prefix, except for an individually inventoried
stock-Haxe global polyfill whose guarded semantics and hash have passed the PHP
matrix. New global symbols are not admitted by analogy.

The package loader also guards the unavoidable process-wide polyfill ABI before
it registers the private class map or loads a public adapter. It compares the
exact `_polyfills.php` hash through the fixed
`WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256` compatibility marker. A pre-existing
polyfill function is accepted only when PHP reports it as native/internal or
when reflection identifies a real declaring file with that exact admitted
hash. A different marker, a user-defined function from a different or missing
file, or a newly emitted global function rejects private boot with diagnostic
`WPHX5201`. The marker is compatibility metadata, not a shared runtime: every
deployable still contains and owns its complete dependency closure.

The prefix intentionally excludes application content and package version.
Changing every private class name after each edit would create noisy diffs,
opcache churn, and unstable traces. Different logical plugins receive different
prefixes. Two installed versions of the same logical plugin still share public
WordPress identity and public PHP names, so simultaneous activation is not a
supported configuration; hiding that conflict with a private content hash would
be misleading. The solution planner rejects duplicate logical module IDs.
Repeated inclusion of the exact same root must remain idempotent and non-fatal.

### The stock front controller is discarded

The stock-Haxe-generated PHP front file is a build intermediate and is never
packaged. In particular, no generated deployable may call `set_include_path`,
`stream_resolve_include_path`, or register an unbounded namespace-agnostic
autoload closure.

For the no-Composer common path, the SDK generates a package-local,
authoritative class map. The loader recognizes only exact fully qualified class
names in that map and requires only their exact package-relative files. It does
not scan directories, perform network I/O, consult another plugin, or prepend
itself ahead of host/application autoloaders. The public root includes only
`includes/autoload.php`; that file owns the private loader and the deterministic
native bootstrap sequence.

The class map and runtime manifest are data projections from the typed closure.
They are not user-authored configuration. Their entries, order, file hashes,
and package-relative paths are deterministic and covered by ownership.

### Composer is conditional and absent from the MVP private lane

Composer remains valid for build-time stubs, static-analysis tools, and future
exact project PHP dependencies. It is not required for the current stock-Haxe
support closure, and the server never runs `composer install` for a generated
WordPressHx deployable.

The MVP private lane therefore has an explicitly empty runtime Composer graph:
no `composer.json`, `composer.lock`, `vendor/`, Composer bootstrap, or remote
package is emitted. The generated authoritative class map is the sole private
autoload mechanism. This is the accepted Composer validation result for the
MVP, not an implied permission to add unlocked packages later.

A future runtime Composer dependency is admitted only after all of the
following become executable package contracts:

1. a typed Haxe dependency declaration resolves through an explicit networked
   `wphx lock` operation into an exact `composer.lock` and toolchain pin;
2. normal `build`, `check`, and `dev` remain offline and consume that lock;
3. the final ZIP contains the required production files and optimized,
   authoritative package-local autoload output, with no server install step;
4. every third-party class/function/constant is either safely rewritten below
   the same package-specific namespace or admitted by an exact globally shared
   ABI policy; merely placing two versions under separate `vendor/` directories
   is not isolation in one PHP process;
5. public signatures and WordPress callback identities expose only accepted
   native/provider types, never internal Composer classes;
6. exact packages, hashes, licenses, notices, and byte origins enter the SBOM;
   and
7. two-plugin version-skew, install, update, rollback, and ordinary non-Haxe PHP
   caller fixtures pass.

Until a follow-up implements those conditions, runtime Composer dependencies
fail closed as unsupported. Build-only Composer use does not cause its packages
to enter a WordPress ZIP.

### Public ABI cannot expose support types

Every WordPress-discovered callable and intentionally public PHP export stays in
the public-native lane. Parameters, returns, properties, parents, implemented
interfaces, traits, attributes, constants, default values, thrown contract, and
reflection-visible names are scanned. A private prefix, stock-Haxe carrier, or
internal Composer type in any public surface rejects the package.

A generated public-native adapter may name a private class in its method body.
It immediately converts native inputs to the bounded private representation and
converts the result back to the declared native type. The private name is an
implementation edge recorded in the manifest, not a public type. WordPress
registrations always point to the public adapter.

### Inventory, size, and startup gates

Every private package records:

- exact project/module/prefix derivation and compiler/runtime identities;
- every private root, transitive dependency reason, generated file, declared
  symbol, global polyfill, and content hash;
- the authoritative class map and initialization order;
- every public-to-private adapter edge and conversion;
- executable PHP count and compressed/uncompressed byte totals;
- isolated cold-boot samples and representative WordPress request evidence;
- duplicate include and two-plugin/version-skew results;
- exact global-polyfill compatibility and mismatched-hash rejection; and
- source-correlation, license/SBOM, syntax, static-analysis, ownership, and
  clean-install receipt IDs.

The existing product ceiling remains authoritative: a server-only starter
plugin's generated PHP/runtime is at most 400 KiB uncompressed, excluding
third-party Composer dependencies and translations. This ADR adds conservative
prototype review thresholds of 160 KiB for the private stock-Haxe closure and
20 ms p50 for an isolated, opcache-disabled PHP cold boot. They are stop/review
thresholds, not production performance claims. SDK-024 must replace the
prototype values with its real implementation fixture; G8 still owns the
durable warm WordPress request budget and the pre-`1.0` retain/migration/remove
decision.

Crossing a threshold, retaining an unexplained helper, leaking a local path, or
failing coexistence blocks the private lane. The build may migrate the logic to
the custom native compiler; it may not hide the excess by excluding inventory.

### No shared runtime without a superseding decision

A site-wide or central Composer WordPressHx runtime is forbidden for the MVP.
It may be reconsidered only by a superseding ADR after all of these conditions
are measured:

- at least the landing, editorial, and WooCommerce reference solutions each
  install multiple independently removable generated deployables;
- per-deployable support passes SDK-024/G1/G8 but duplicated fixed runtime bytes
  or bootstrap cost materially break the package/request budgets in at least
  two representative solutions;
- a versioned runtime ABI, exact compiler/runtime compatibility rule, dependency
  resolver, security owner, finite support window, and public deprecation policy
  exist;
- clean install, mixed-version activation order, independent update, failed
  update rollback, deactivation/removal, and no-network production operation
  pass on the exact WordPress/PHP matrix;
- an absent, older, newer, corrupt, or conflicting shared runtime fails with a
  bounded native WordPress diagnostic rather than a fatal error or silent
  fallback; and
- the shared design is measurably smaller/faster than the dependency-closed
  packages after its own loader, metadata, compatibility, and maintenance costs
  are included.

One successful microbenchmark, code deduplication in a ZIP, or implementation
convenience is insufficient. Per-deployable packaging remains the rollback path
for any shared-runtime experiment.

## Rationale

Package-local support makes each WordPress artifact installable, removable, and
debuggable on its own. A stable derived prefix prevents unrelated generated
plugins from defining the same stock-Haxe runtime classes. Discarding the stock
front controller removes the one observed process-global autoload coupling,
while an exact class map avoids requiring Composer for a dependency graph that
the compiler already knows.

The decision also improves the Haxe experience. There is no second package
language for routine private logic: Haxe reachability selects support, Haxe
project/module identity selects isolation, and the compiler emits the required
native boundary and inventory. PHP and Composer remain inspectable deployment
artifacts and optional ecosystem boundaries, not mandatory authoring surfaces.

Keeping runtime Composer packages closed for the MVP is deliberately narrower
than pretending that separate `vendor/` directories solve PHP symbol conflicts.
The follow-up admission conditions leave room for the ecosystem without making
multi-plugin safety depend on an unproved namespace-rewriting tool or global
singleton.

## Alternatives considered

### One shared `wordpress-hx-runtime` Composer package

This can deduplicate the fixed Boot/standard-library bytes. It is rejected for
the MVP because independently updated plugins would share one load order,
version, security, and rollback boundary. A site missing the package would also
turn an ordinary plugin ZIP into an incomplete deployment. The future criteria
above require measured need and a complete compatibility protocol first.

### Package the stock Haxe front controller unchanged

This is the smallest implementation change and the private namespaces prevent
direct class-name collisions. It is rejected because the front controller owns
application startup, mutates process-wide `include_path`, and registers an
unbounded resolver. The executable probe demonstrated that an earlier plugin's
autoload closure can search a later plugin's library root.

### Bundle a separate Composer `vendor/` tree in every plugin

This is normal for PHP packaging and remains a future conditional path. It is
not sufficient isolation by itself: PHP class/function/constant names are
process-global even when files live in different directories. Without exact
namespace rewriting or a proved shared ABI, version-skew can still make the
first-loaded dependency win. The stock-Haxe-only MVP needs neither Composer nor
that extra conflict surface.

### Prefix all third-party PHP packages immediately

Tools such as PHP namespace rewriters can make per-plugin Composer graphs safer.
Adopting one now would add an executable toolchain, semantic rewrite rules,
reflection/serialization concerns, licenses, and a second source-correlation
stage before a real runtime dependency exists. It is deferred to the explicit
Composer admission follow-up and cannot be introduced as an incidental SDK-024
implementation detail.

### Custom-lower all private Haxe immediately

This removes the stock runtime and is the preferred eventual shape when the
generic compiler covers the required semantics. It remains deferred as the only
option because ADR-005 deliberately uses a bounded stock lane to measure what
private constructs are actually needed. Any closure that fails this ADR's
budgets or isolation rules migrates to custom lowering rather than weakening
the rules.

### Remove the private lane now

This is the safest packaging shape and remains the stop-condition outcome. It
would also force the custom compiler to implement broad private Haxe semantics
before the first representative applications reveal which ones matter. The
bounded package and removal gates preserve the learning value without promising
the lane after `1.0`.

## Consequences

Benefits:

- a generated plugin remains a normal self-contained WordPress ZIP with no
  Haxe, Node, Composer, or WordPressHx runtime installation on the server;
- users write no namespace, autoload, or runtime inventory configuration;
- unrelated generated plugins can carry different private implementations and
  stock runtime revisions without class-name collisions;
- the loader owns only an exact package-local class map and does not mutate the
  host include path;
- every retained byte has a compiler reason and an extraction/migration path;
  and
- public WordPress/PHP ABI remains readable and independent of stock-Haxe and
  Composer implementation types.

Costs and constraints:

- multiple generated plugins initially duplicate some support bytes;
- SDK-024 must replace the stock front controller and validate the complete
  class/reference closure rather than copying a compiler directory blindly;
- simultaneous activation of two versions of the same logical plugin remains
  unsupported because their public WordPress/PHP identity conflicts;
- runtime Composer packages remain unavailable until their exact isolation and
  release path is implemented; and
- the private lane remains provisional and can be removed before `1.0`.

No production support, arbitrary Composer package support, server HXX runtime,
theme packaging, public release, or shared-runtime claim is created by this
decision.

## Evidence and commands

The executable architecture fixture is authored in strict Haxe, compiled twice
with exact Haxe 4.3.7 under two derived private prefixes, and packaged only in a
temporary evidence tree. It proves deterministic prefixing, exact class maps,
stock-front exclusion, absence of a runtime Composer graph, PHP 7.4/8.4 syntax
and behavior, duplicate inclusion, two-plugin version-skew coexistence,
reflection-clean public signatures, size/cold-boot measurement, and clean
WordPress 7.0 installation/activation.

```bash
python3 scripts/runtime-support/test-policy.py
bash scripts/runtime-support/test.sh
bash scripts/runtime-support/test-production.sh
```

The machine-readable contract is
`manifests/runtime-support-packaging.json`; the exact commands, subject hashes,
measurements, image identities, and claim boundaries are recorded in
`manifests/evidence/adr-018-runtime-support-packaging.json`.

Reference patterns were reviewed read-only; no source or fixture bytes were
copied and no sibling dependency was created:

- `../haxe.rust` commit `c1c95fbe7debccac68975ac9b5d75c115894675f`,
  `docs/consumer-runtime-benchmark-corpus.md` and
  `docs/schemas/runtime-plan-v4.schema.json`: reasoned selective-runtime plans,
  deterministic inventories, and separate output-shape/performance gates;
- `../haxe.go` commit `6f93082877bd3e65b5ad26a61bc594075c857ec9`,
  `docs/hxrt-selective-runtime.md`: dependency-complete inferred support slices
  with an explicit full-runtime fallback rather than silent omissions;
- `../haxe.ruby` commit `cf1cbfcecc60b44ecc5e53f0a69dd5675ebc74eb`,
  `runtime/README.md` and the runtime-ownership section of the `1.0` review:
  runtime helpers must be explicit and compiler/runtime compatibility must be
  atomic or versioned;
- `../haxe.ocaml` commit `56310df380f5094d9e4eac664ec2f03c5de52c90`,
  `README.md`: deterministic per-plugin module prefixes prevent promoted plugin
  unit collisions while preserving host-owned modules;
- `../genes` commit `2b4b71b00528fb376f7f0f8527237cf336b0f36b`,
  `src/genes/LibraryProfile.hx`: derive a dependency-complete externally
  retained surface before DCE and keep executable output honest; and
- `../haxe.elixir.codex` commit
  `fa4be51176f9e84360e47d21ff49efaa9e89f3ae`: compile-time framework contracts
  and deterministic release artifacts remain separate from target runtime
  ownership.

## Migration, rollback, and supersession

Before a public release, rollback removes the private stock-Haxe lane and routes
the admitted logic through custom native lowering or rejects that capability.
Public-native adapters and their ABI remain unchanged. A package may migrate a
private closure from stock Haxe to custom lowering behind the same adapter when
behavior, source correlation, and artifact migration fixtures pass.

Changing the prefix derivation for an existing module invalidates private
opcache/class identities and requires a generated-artifact migration record,
but it is not a public ABI change while no private type leaks. Enabling runtime
Composer dependencies or a shared runtime requires a follow-up or superseding
ADR, exact locks, coexistence/update/rollback evidence, and new SBOM/license
receipts. Returning from a failed shared-runtime experiment to per-deployable
support is mandatory and must not require application-source changes.

## Follow-up beads

- `wordpresshx-sdk-024`: implement the production dependency-closed stock-Haxe
  private lane, authoritative loader, inventory, boundary scan, and real budget
  evidence.
- `wordpresshx-g1`: retain only the private lane supported by the complete
  native PHP feasibility matrix.
- `wordpresshx-sdk-101`: package exact production dependencies, provenance,
  notices, SBOM, and deterministic ZIP bytes.
- A dedicated runtime-Composer admission bead owns exact lock generation,
  namespace isolation, optimized bundled autoload, and version-skew evidence;
  it is not implicit in SDK-024.
- `wordpresshx-g8`: decide retain, migration-only, or removal before API freeze
  and approve durable warm-request/package budgets.
