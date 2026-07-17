# ADR-004: Generic PHP compiler home and extraction boundary

- Status: accepted
- Date: 2026-07-16
- Owners/reviewers: Marcelo Serpa (product owner; monorepo-first direction), Codex (architecture and source-boundary review)
- Bead: `wordpresshx-adr-004`
- Profiles/layers: generic PHP compiler, SDK WordPress PHP profile, full-port consumer boundary
- Supersedes: the immediate-extraction requirement in the PRD recommendation and PHP-specific portions of ADR-001
- Superseded by: none

## Context

The custom PHP emitter currently lives in `wordpresshx-port` as `WphxPhpCompiler`. It already uses Reflaxe infrastructure and contains useful generic PHP statement/expression IR, deterministic printing, and typed-expression lowering. It also contains port-specific responsibilities: `@:wp.*` metadata, original WordPress file paths, WordPress adapter selection and bodies, Haxe bootstrap assumptions, emission manifests, template pilots, and full-port naming.

The PRD initially recommended extracting that work into an independent compiler repository before SDK consumption. That is a clean long-term ownership model, but it creates repository, release, pin, and cross-project coordination before the compiler API has stabilized. The SDK is itself an early monorepo and has no released consumer. The product owner therefore chose to co-locate the generic compiler here for now and extract it only when evidence justifies the additional boundary.

Co-location is useful only if it does not turn the generic compiler into a WordPress-specific implementation directory. The package structure, dependencies, fixtures, provenance, and gates must preserve an actual extraction seam from the first import.

## Decision

### Temporary package home

During 0.x, the generic compiler lives at `compiler/reflaxe.php/` as a private workspace package. Its Haxe namespace is `reflaxe.php`. It owns:

- typed, target-language PHP IR and deterministic printing;
- general Haxe typed-AST lowering admitted by generic fixtures;
- PHP language semantics such as arrays, references, callables, closures, classes, functions, control flow, exceptions, names, and source ranges;
- carefully adapted Haxe PHP runtime/stdlib behavior where a future backend requires it;
- generic compiler diagnostics, source correlation, fixtures, package metadata, and release-readiness checks.

The package begins at version `0.0.0` and is not publishable while ADR-020 and SDK-002 remain open. Monorepo source identity, provenance, and test receipts replace an external release pin during this phase.

### Separate WordPress profile

WordPress-specific compiler integration belongs under `compiler/wordpress/` or SDK packages selected by ADR-003. That layer owns:

- WordPress/Gutenberg profile selection and package/file maps;
- public PHP ABI annotations and compatibility policy;
- plugin/theme/block bootstrap shapes;
- WordPress hook, global, class, function, include, template, and metadata mappings;
- WordPress-specific adapter plans and real WordPress fixtures.

The allowed dependency is:

```text
compiler/reflaxe.php  <-  compiler/wordpress  <-  SDK build/packages
```

The generic compiler must not import `compiler/wordpress`, any SDK package, or any WordPress/full-port module. It must not contain WordPress symbols, paths, handles, hook names, plugin classes, `@:wp.*` policy, or WordPress-conditioned lowering.

### Import and provenance

Existing proven work should be moved, not rewritten without reason. Every imported slice records:

- origin repository URL, exact commit, tree, source path, blob and content hashes;
- source license and the unresolved destination-distribution review;
- transformations such as namespace changes, file splits, type strengthening, and removed profile coupling;
- deliberately excluded port-only files and responsibilities;
- generic fixtures that prove the imported behavior independently.

The source authority for the first import is the clean `wordpresshx-port` commit `7fdda0aa5ea66900819842aefeac6747421e9130` and tree `a5cc51c68ca443108b5b133612c2f389ebf31364`. The source code is GPL-2.0-or-later. Importing it does not decide the final SDK/compiler/generated-output license; ADR-020 remains mandatory before publication.

### Reflaxe and stock PHP authority

Reflaxe is compiler infrastructure, not PHP semantic authority. Exact Reflaxe inputs will be locked when the driver begins consuming them. Haxe 4.3.7's stock PHP target and `std/php` remain the behavior/reference source for Haxe runtime, boot, standard-library, exception, iterator, closure, string, and target-intrinsic behavior until a later ADR accepts broader ownership.

Generic behavior must be demonstrated without a WordPress runtime. A WordPress fixture may expose compiler pressure, but the corresponding generic compiler test must use neutral names and inputs.

### Extraction triggers

Extraction into an independent repository/package becomes required when any one of these conditions is accepted in a follow-up bead:

1. a non-WordPress consumer needs the compiler;
2. the full port needs to consume the generic package without consuming the SDK repository;
3. compiler and SDK release cadences materially diverge;
4. independent maintainers, security response, or issue authority are needed;
5. public Haxelib distribution is approved;
6. CI cost or repository ownership makes the monorepo boundary harmful.

Extraction requires a clean subtree/history transfer, preserved provenance, passing generic gates in the new repository, an immutable release/commit, downstream compatibility receipts, and replacement of workspace references with exact pins. Until a trigger occurs, extraction work is deferred rather than repeatedly mirrored.

## API and enforcement boundary

The public compiler API is admitted incrementally. Initial APIs are typed IR and a deterministic printer; the Reflaxe driver and broader typed-AST/runtime surface follow only with generic evidence. Internal APIs may change during 0.x, but changes must keep the package's own tests green.

Repository gates must reject:

- imports from `reflaxe.php` into WordPress/full-port modules in the wrong direction;
- WordPress identifiers or `@:wp.*` metadata in the generic package;
- direct `../wordpresshx-port` runtime/class paths;
- floating Reflaxe or other sibling paths in release configuration;
- generated PHP committed as maintained source;
- unrecorded copied code.

The initial import may retain output-compatible formatting where tests protect it. General improvements—typed operators, validated names, removal of raw-string nodes, or source ranges—must be behaviorally reviewed and must not be implemented as WordPress exceptions.

## Rationale

This choice optimizes for learning while the API is still changing. One repository allows atomic compiler/profile/SDK changes and removes premature release choreography. A real internal package boundary retains most of the architectural value of a separate repository: one-way dependencies, neutral names, independent tests, explicit provenance, and an extraction-ready directory.

The decisive factor is not the number of repositories but whether the compiler can be understood, tested, and moved without WordPress SDK state. Enforcing that property now is cheaper than maintaining an external pre-release package whose API changes with every vertical slice.

## Alternatives considered

### Extract to an independent compiler repository immediately

This gives the clearest issue, release, and dependency authority and remains the expected mature shape. It is deferred because no second independent consumer or stable API exists yet, the SDK has no release, and cross-repository pin churn would slow the feasibility work. The extraction triggers prevent indefinite co-location by convenience.

### Continue consuming compiler code from `wordpresshx-port`

This avoids an initial move, but it makes the SDK depend on port internals, a mutable sibling checkout, WordPress adapter bodies, and full-port file/linker assumptions. It is rejected. The port is provenance and behavior evidence, not a runtime dependency.

### Copy the entire current compiler unchanged

This preserves every existing fixture quickly, but the current main compiler directly imports the WordPress adapter registry and embeds WordPress paths, metadata, bootstrap behavior, manifests, and templates. It would only relocate the coupling. The accepted approach imports generic slices and leaves WordPress behavior in a separate profile.

### Start a new generic compiler from scratch

This produces a clean namespace but discards proven IR/printer behavior and obscures the lineage of fixes. It is rejected unless a specific source slice cannot be separated safely. Refactoring and type strengthening are preferred to unexplained reimplementation.

### Use only stock Haxe PHP

Stock PHP remains a valuable private-output and runtime/stdlib oracle, but the PRD requires public PHP shapes, references, native arrays, file timing, and ecosystem-visible ABI that the existing port has already shown need a custom lane. Abandoning that evidence would recreate known pressure.

## Consequences

Benefits:

- compiler and SDK feasibility changes can land atomically;
- proven port work is retained with an auditable origin;
- generic and WordPress responsibilities become visible in the filesystem and dependency graph;
- extraction waits for a concrete consumer/release need;
- generic compiler tests run without WordPress.

Costs and constraints:

- repository checks must actively prevent boundary erosion;
- the monorepo temporarily owns compiler issue triage and release preparation;
- the full port cannot consume unpublished workspace paths as durable evidence;
- code movement loses original per-line Git history unless provenance records remain accurate;
- licensing must remain explicit while final distribution terms are unresolved.

This ADR does not claim that the imported compiler is already a complete arbitrary-Haxe PHP backend, owns Haxe's runtime/stdlib, or supports WordPress. Those claims require their own finite fixtures and receipts.

## Evidence and commands

Reviewed sources:

- `wordpresshx-port/src/wphx/compiler/php/WphxPhpCompiler.hx` at the exact origin above;
- `wordpresshx-port/src/wphx/compiler/php/WphxPhpWordPressAdapters.hx` as the profile code that must remain excluded from the generic package;
- full-port ADR-013 (Adapter IR), ADR-015 (backend strategy), ADR-016 (adoption track), and ADR-017 (runtime/stdlib strategy);
- SDK PRD §§2.4, 12.2, 16.3, 26, 27.2, and 29.1;
- ADR-001's independent product and claim boundary.

Acceptance checks:

```bash
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

SDK-020 owns the exact source inventory, provenance record, package scaffold, and first independent generic regression. SDK-021 owns the typed IR/printer breadth. SDK-027 owns eventual release/extraction mechanics.

## Migration, rollback, and supersession

No released SDK consumer exists. The port remains unchanged during the import, so rollback is removal of the internal package and restoration of the prior ADR requirement; it must not create a dependency back into the port.

If the internal package boundary fails—because WordPress imports become necessary, independent consumption is blocked, or release authority becomes ambiguous—open the extraction bead immediately and supersede this ADR with an independent-repository decision. If the custom compiler proves infeasible, preserve the provenance and evidence, mark the affected compiler claims unsupported, and decide the fallback in a superseding ADR rather than silently returning to port-internal paths.

## Follow-up beads

- `wordpresshx-sdk-020`: establish the co-located package boundary, inventory, provenance, and first generic fixture.
- `wordpresshx-sdk-021`: complete the initial generic PHP IR and deterministic printer foundations.
- `wordpresshx-sdk-027`: establish independent compiler fixtures and the release/extraction process.
- `wordpresshx-adr-003`: incorporate the private compiler workspace into package topology and lockstep policy.
- `wordpresshx-adr-005`: decide public versus private PHP emission.
- `wordpresshx-adr-017`: decide compiler/runtime/stdlib ownership for this SDK.
- `wordpresshx-adr-020`: decide licensing and generated-output terms before publication.
