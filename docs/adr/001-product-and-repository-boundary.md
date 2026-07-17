# ADR-001: Product and repository boundary

- Status: accepted
- Date: 2026-07-16
- Owners/reviewers: Marcelo Serpa (product owner; direction confirmed in the implementation session), Codex (architecture and implementation review)
- Bead: `wordpresshx-adr-001`
- Profiles/layers: repository-wide; all SDK profiles, generic compiler boundaries, and provider claims
- Supersedes: none; formalizes the provisional PRD recommendation
- Superseded by: none

## Context

`wordpress-hx-sdk` and the full `wordpress-hx` port pursue related but different products. The SDK generates ordinary plugins, themes, blocks, and assets for a named native WordPress/Gutenberg provider. The full port owns replacement-distribution concerns such as Core file paths, load order, linker segments, ownership progression, and whole-distribution parity.

Putting durable SDK code inside the port would make vanilla SDK releases depend on unrelated port internals, blur issue and release authority, and allow work in one product to be reported as evidence for the other. Copying compiler code into either product would create a different ambiguity: fixes would have no neutral owner or reusable release boundary.

The PRD therefore recommends a separate SDK repository, shared generic compilers, exact cross-project pins, and provider-specific receipts. The project owner additionally confirmed that browser work uses the generic genes-ts repository and that the custom Reflaxe PHP work originating in `wordpresshx-port` must be extracted as a generalized compiler rather than consumed through port internals.

## Decision

### Independent product authority

This repository is the sole authority for the `wordpress-hx-sdk` product: its roadmap, issues, public packages, profiles, schemas, generated-artifact contracts, examples, releases, and SDK claim language. Its beads database is not a mirror of the full port's tracker.

The full port remains the sole authority for whole-WordPress implementation ownership, original-path replacement, Core linking/load behavior, distribution assembly, and full-port parity claims. Neither repository may close, relabel, or broaden the other product's claim by implication.

### Allowed sharing

The projects may share only boundaries that remain intelligible to an independent consumer:

- released generic compiler packages or immutable compiler commits with hashes and test receipts;
- versioned public SDK packages, schemas, profile manifests, and documented command/ABI contracts;
- independently materialized upstream WordPress/Gutenberg source and artifact snapshots with provenance;
- minimized, license-compatible fixtures with explicit source and ownership;
- unchanged final SDK package bytes submitted to another provider, with a provider qualification receipt;
- architecture knowledge expressed as a new neutral contract, never as an import of private implementation state.

Contributor sibling checkouts may accelerate local diagnosis, but they are not release dependencies. A release must resolve every cross-project input to an immutable version/commit, tree/package digest, compatibility profile, evidence receipt, upgrade owner, and rollback identity.

### Forbidden coupling

The SDK must not import, copy as an undeclared fork, or execute against:

- `wordpresshx-port` internal source paths or unpublished packages;
- the port's Core linker, original-path replacement, adapter registry, ownership progression, or distribution assembly machinery;
- port-only bootstrap classes, globals, generated distribution layout, task database, or runtime state;
- a mutable sibling worktree, floating branch, global `haxelib dev`, or local filesystem path in a release build;
- full-port scaffolding, bridges, or parity results as proof of vanilla SDK support.

The full port must not import unpublished SDK internals or treat an SDK scaffold/type catalog as implementation ownership. It may consume released public SDK contracts and report its own compatibility result for unchanged artifact bytes.

Generic compiler repositories must not acquire WordPress hook names, package handles, plugin classes, SDK imports, or `if wordpress` lowering branches. A defect that can be stated without WordPress semantics is fixed generically; a WordPress-specific mapping or policy is implemented in this SDK.

### Dependency direction

The durable dependency graph is one-way:

```text
Haxe / WordPress / Gutenberg immutable upstreams
                 |
                 v
generic compiler releases -----> wordpress-hx-sdk release
                                           |
                                           v
                              optional full-port consumer
                              + separate provider receipt
```

There is no durable arrow from the SDK into full-port internals, from a generic compiler into SDK/WordPress semantics, or from the full port back into an SDK release build.

### Claim vocabulary

Every capability claim is keyed by an exact SDK version or artifact hash, exact profile, finite capability, environment/toolchain, evidence receipt, and provider. A status without those keys is informational only and cannot be a support claim.

Evidence maturity uses these exact ordered terms:

| Status | Meaning |
|---|---|
| `inventoried` | The symbol/capability was found in an exact upstream input; no type or behavior claim. |
| `typed` | A reviewed Haxe/contract representation exists for the named profile; no generated/runtime claim. |
| `generated` | The named artifact was emitted and passed applicable schema/static checks; no runtime claim. |
| `runtime-tested` | The exact artifact passed the named real-runtime evidence in the recorded environment. |
| `production-supported` | The exact finite scope passed the production-readiness contract and is inside the published support window. |

Administrative results are `not-tested`, `failed`, `not-applicable`, `unsupported`, and `withdrawn`. They do not fit between evidence levels and must include a reason. Evidence does not silently inherit across profiles, package versions, environments, artifacts, or providers.

Release notes and status surfaces must keep at least these fields separate:

- SDK artifact/capability status on vanilla `wp70-release`;
- opt-in `gutenberg-forward-23.4` status;
- future WordPressHx provider qualification status.

`production-ready`, `supports WordPress`, `supports Gutenberg`, `full-port-compatible`, and `dual-provider` are prohibited as unqualified phrases. `Production-ready` may be used only for a named SDK version, profile, capability ledger, toolchain/runtime matrix, artifact hash, provider, and completed production-readiness evidence. A future full-port result requires that provider to run the unchanged SDK artifact hash; contract similarity or shared tests are insufficient.

### Correction policy

If a claim is broader than its evidence or a blocking result later fails:

1. correct or retract the claim immediately in every controlled status/release/documentation surface; do not wait for the next feature release;
2. mark the affected keyed result `withdrawn`, `failed`, or `unsupported` and preserve the prior receipt rather than rewriting history;
3. open a P0 claim-correction bead with the exact artifact/profile/provider scope, evidence, owner, and user impact;
4. stop publishing or promoting the affected scope until correction evidence passes;
5. publish corrected metadata/docs and, when shipped behavior or package metadata is affected, an appropriate patch/replacement release under the release policy;
6. notify the other project when its public statement or receipt references the affected artifact, while leaving that project's authority and correction to its maintainers.

Immutable tags and receipts are not silently edited. A compromised artifact follows the future security/revocation policy; an ordinary evidence correction is additive and auditable.

## Rationale

A separate repository gives vanilla WordPress users a comprehensible dependency and release boundary. Neutral compiler ownership lets both products improve Haxe target quality without either inheriting the other's application semantics. Immutable pins and one-way consumption make failures attributable. Keyed, provider-specific claim terms prevent a type catalog, generated file, or port scaffold from being mistaken for installed-runtime support.

The coordination cost is real, but it is bounded and visible: package extraction, pin upgrades, and receipts. Circular code and merged claims would create hidden costs at every release and make rollback or support ownership ambiguous.

## Alternatives considered

### Embed the SDK in `wordpresshx-port`

This offers one checkout, tracker, and lockfile, plus immediate access to port inventories. It is rejected for durable product code because Core-linker/original-path assumptions can leak into ordinary extensions, vanilla users inherit unrelated distribution machinery, and version/support authority becomes inseparable.

### One umbrella monorepo with nominally independent packages

Strict build graphs and package visibility could theoretically enforce separation while retaining atomic changes. This is the strongest alternative, but repository-level issue, release, CI, and claim surfaces would still default to a shared authority. The current port also contains machinery the SDK must never need. Revisit only through a superseding ADR with demonstrated enforcement and a migration plan; convenience alone is insufficient.

### Copy compiler/profile code between repositories

Copying is fast for a prototype and avoids release coordination. It is rejected because fixes diverge, license/provenance and security ownership become unclear, and neither project can name a canonical compiler artifact. Small fixtures may be copied only with provenance; compiler implementation is extracted and released generically.

### Defer the boundary until after the vertical prototype

Deferral reduces immediate process work but lets the riskiest coupling become the de facto architecture. The repository and compiler directions are prerequisites for broad implementation, so deferral is rejected. Experimental spikes may be discarded; accepted product code follows this ADR now.

### Omit the SDK and continue only the full port

This removes coordination and gives one project authority, but it abandons the independent native-extension product and cannot make vanilla WordPress the direct acceptance gate. It is a valid future product-cancellation decision, not an implementation architecture. Cancellation would freeze this repository through a superseding decision rather than merge its claims into the port.

## Consequences

Positive consequences:

- SDK users receive an independent, ordinary dependency/release surface.
- Generic PHP and browser compiler improvements remain reusable and testable outside WordPress.
- Vanilla, forward-profile, and future full-port results cannot overwrite one another.
- Release inputs and rollbacks are reproducible through exact pins and receipts.
- Ownership and defect routing have an explicit default.

Costs and constraints:

- Cross-repository changes require generic reduction, upstream review, releases/pins, and downstream receipts.
- Some fixtures/inventories may need independent rematerialization instead of direct reuse.
- The SDK cannot take shortcuts through mature port-only linkers or state.
- Status, docs, and releases must carry more precise profile/provider fields.
- A missing generic compiler release can block SDK work even when a local sibling fix exists.

This ADR does not accept a license, package topology, exact compatibility profile, PHP public/private emission model, or release support window. Those remain with their dedicated ADRs.

## Evidence and commands

Reviewed evidence:

- [PRD product/full-port boundary and alternatives](../../wordpress-hx-sdk-product-requirements.md#6-relationship-to-the-full-wordpress-hx-port);
- [PRD dependency-direction rules](../../wordpress-hx-sdk-product-requirements.md#12-dependency-direction-rules);
- [PRD required ADRs](../../wordpress-hx-sdk-product-requirements.md#291-required-adrs-before-implementation-breadth);
- [repository governance](../../GOVERNANCE.md);
- [compiler contribution boundary](../../CONTRIBUTING.md);
- [genes-ts immutable pin and receipt](../architecture/browser-compiler.md).

Acceptance checks:

```bash
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

The repository check validates required policy/ADR/pin files and rejects direct `wordpresshx-port` source/package and `haxelib dev` dependencies in implementation/configuration files. SDK-030 independently demonstrated the generic compiler pin/receipt boundary against a dirty sibling checkout and a clean detached worktree.

## Migration, rollback, and supersession

The repository is new, so no released consumer migration is required. Existing sibling paths remain contributor-local only and must never enter release manifests.

If maintaining an independent SDK becomes unsustainable, maintainers must freeze affected releases/claims, preserve published artifacts and receipts, and accept a superseding ADR that names the destination, dependency graph, issue/release authority, migration, deprecation, and user impact. Code must not be silently folded into the full port, and full-port evidence must not retroactively relabel SDK artifacts.

Generic compiler rollback uses the prior immutable compiler release recorded in the applicable lock and requires a fresh SDK receipt. It does not authorize vendoring or a floating local patch.

## Follow-up beads

- `wordpresshx-sdk-001`: verify the accepted boundary and claim-separation implementation.
- `wordpresshx-adr-002`: exact compatibility profiles.
- `wordpresshx-adr-003`: package topology and lockstep versioning.
- `wordpresshx-adr-004`: generic Reflaxe PHP compiler extraction.
- `wordpresshx-adr-020`: licensing and generated output.
- `wordpresshx-adr-021`: release and support policy.
- `wordpresshx-adr-022`: unchanged-artifact full-port compatibility receipts.
- `wordpresshx-sdk-004`: configure canonical Git and beads remotes without guessing a destination.
