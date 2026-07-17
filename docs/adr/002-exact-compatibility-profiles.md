# ADR-002: Exact compatibility profiles

- Status: accepted
- Date: 2026-07-17
- Owners/reviewers: Marcelo Serpa (product owner and PRD authority), Codex (architecture and implementation review)
- Bead: `wordpresshx-adr-002`
- Profiles/layers: profile selection, generated catalogs, build manifests, package graphs, artifact claims, and runtime capability boundaries
- Supersedes: none; accepts the exact-profile recommendation in PRD §9
- Superseded by: none

## Context

The SDK cannot honestly claim a broad WordPress or Gutenberg range from an API inventory or a single working build. WordPress core ships one embedded Gutenberg baseline, while a newer standalone Gutenberg tag may expose packages, exports, metadata keys, handles, signatures, or behavior that do not exist in the vanilla release. Treating the newer inventory as a superset would let forward-only APIs enter an artifact labeled for vanilla WordPress.

The PRD names two deliberately different authorities:

- `wp70-release` is the single exact vanilla MVP baseline and the only candidate for a future WordPress 7.0 distribution claim.
- `gutenberg-forward-23.4` is an opt-in forward-development inventory with no WordPress 7.0 or distribution compatibility claim.

Profile selection affects compile-time module availability, generated PHP and browser imports, asset handles, block metadata, package dependencies, diagnostics, test matrices, manifests, documentation, and support wording. A runtime version check occurs too late to make an unavailable package import or incompatible signature valid. The profile identity and isolation rules therefore have to be fixed before catalogs, public emitters, or browser mappings become broad implementation dependencies.

This ADR freezes the architecture identities supplied by the PRD. It does not claim that the upstream commits, distribution bytes, or generated catalogs have already been independently verified. SDK-010 and SDK-011 own that materialization and evidence.

## Decision

### Exact peer profiles

The accepted profiles are peers, not an inheritance chain:

| Profile | Exact architecture identity | Role | Claim boundary |
|---|---|---|---|
| `wp70-release` | WordPress `26b68024931348d267b70e2a29910e1320d0094f`; embedded Gutenberg `a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd`; `wp70-release/catalog-v1` | MVP vanilla baseline | Candidate `wordpress-7.0-compatible` distribution claim only after its full evidence gates pass |
| `gutenberg-forward-23.4` | Gutenberg `98a796c8780c480ef7bcfe03c42302d9564d785c`, tag `v23.4.0`; `gutenberg-forward-23.4/catalog-v1` | Opt-in forward experiment | No distribution or WordPress 7.0 compatibility claim; preview/experimental only |

`catalog-v1` is a versioned catalog contract identity, not a mutable filename. Any correction that changes the observable catalog must produce a new content digest and an auditable correction receipt. A breaking catalog-contract change requires a new catalog revision. Upstream commits and artifact hashes are independent fields and may not be replaced by the profile name.

The machine-readable authority for this decision is [`profiles/decision-lock.json`](../../profiles/decision-lock.json). Its current claim is `not-tested` and its catalog-contract status is `identity-frozen-schema-pending`. Those qualifiers remain until the dependent implementation beads replace them with direct evidence.

### Selection and artifact identity

Every emitted or packaged artifact has exactly one compatibility target during the MVP. CI requires an explicit profile selection. A local scaffold may initially choose `wp70-release`, but it must persist that choice in generated project configuration before a build is considered reproducible.

The selected profile is an effective build input. It must participate in fingerprints, caches, output paths, generated namespaces where relevant, manifests, package names, diagnostics, and receipts. Environment-only or ambient defaults cannot define a release artifact.

One workspace may build both profiles, but it produces separate package graphs, generated roots, artifact paths, manifests, tests, and claims. During the MVP, a combined ZIP or an undifferentiated “supports both” target is forbidden. A future ADR may admit a common-surface artifact only after both exact matrices pass and the manifest can prove that every emitted capability belongs to both profiles.

### Compile-time isolation

Availability is exact membership, not version ordering. A capability records every profile in which its exact contract is available. Selecting `gutenberg-forward-23.4` does not automatically make a `wp70-release` capability valid, and selecting `wp70-release` never admits a forward-only capability.

Profile-specific externs, handles, package exports, metadata keys, and typed capability references are generated into separate package graphs. The `wp70-release` graph must contain no forward-only symbol to import. Macros and build tooling reject a missing capability with source location, selected profile, required availability, and a remediation that preserves artifact separation.

Generated metadata and dependencies follow the same rule as source imports. A handle, package export, block key, or browser global cannot enter an artifact merely because it is represented as a string or exists at runtime on a developer's site.

### Runtime capability evidence

Runtime detection is allowed only for an optional feature whose ABI is already valid for the selected compile-time profile. A check such as `function_exists`, `class_exists`, `defined`, `method_exists`, plugin-version inspection, or registered-package inspection returns a typed, request-scoped capability result. It does not alter the selected profile and is not serializable authority for a later request or build.

Runtime detection cannot satisfy a compile-time profile requirement, add a package import, change a signature, admit a metadata key, or turn the forward profile into a vanilla compatibility claim. A boolean check detached from the guarded capability is insufficient for stable SDK APIs; SDK-012 will define the typed token form.

### Provenance and claims

Every generated artifact manifest must eventually record at least:

- profile ID, catalog revision, and catalog content digest;
- exact upstream commits and upstream artifact digests;
- generator and toolchain identities;
- required capabilities and their evidence receipt IDs;
- the exact artifact digest and its runtime-test scope.

The profile ID alone proves none of those facts. Catalog inventory is `inventoried`, not `typed`, `generated`, `runtime-tested`, or `production-supported`. Evidence and claims do not inherit between the two profiles.

Until the full evidence exists, permitted wording is “targets the exact `wp70-release` architecture identity” or “tested against the exact WordPress 7.0 baseline” with the actual test receipt. “WordPress 7+,” “supports Gutenberg,” and “compatible with WordPress 7.0” are prohibited without the corresponding finite evidence. The forward profile must always be visibly labeled opt-in preview/experimental and cannot borrow the vanilla result.

### Broader range admission

A future WordPress support range requires all of the following before an ADR or release may claim it:

1. an exact profile for every release used to establish the range;
2. generated API, package-export, handle, metadata, and behavior diffs;
3. real install, server, editor, and browser tests on every endpoint plus justified intermediate samples;
4. an explicit deprecation, removal, and correction policy;
5. proof that final artifacts do not accidentally depend on the newest profile;
6. a published support duration and security-maintenance commitment.

The range is a new evidence-backed product claim, not an alias or wildcard profile. Failing any criterion leaves each exact profile separately reportable and the range unsupported.

## Rationale

Exact peer profiles make absence meaningful. Code generation can omit unavailable APIs entirely, diagnostics can name one finite authority, and a package can be reproduced from immutable inputs. This is stronger than a version comparison because WordPress core and a standalone Gutenberg plugin are not guaranteed to form a monotonic ABI sequence.

Keeping the forward profile separately useful lets the SDK explore upcoming APIs without contaminating the vanilla MVP or pretending the forward tag is a WordPress distribution. Requiring explicit selection in CI prevents a local default from silently changing release bytes. Treating runtime evidence as request-scoped preserves optional integrations without turning an installed plugin into build authority.

## Alternatives considered

### Claim a broad `WordPress 7+` range immediately

This is attractive for adoption and reduces the number of generated packages. It is rejected because neither API inventory nor one endpoint test proves intermediate releases, removals, behavior, package exports, or artifact independence from the newest baseline.

### Generate one merged superset catalog

A superset offers convenient authoring and could attach minimum-version metadata to each symbol. It is rejected as the default because unavailable modules remain importable, strings and metadata bypass symbol guards, and the forward Gutenberg tag has no accepted monotonic relationship to the vanilla embedded version.

### Use runtime checks for every difference

This can support truly optional, ABI-compatible functions and third-party plugins. It cannot repair package resolution, PHP syntax, type signatures, block schema, or asset dependency differences. It is limited to request-scoped optional behavior already valid under the selected profile.

### Treat the forward profile as inheriting vanilla

Version-like naming makes inheritance look natural, but the forward profile is a standalone Gutenberg authority without a WordPress 7.0 distribution claim. Automatic inheritance would manufacture compatibility evidence. Exact availability may overlap, but overlap is recorded per capability rather than inferred globally.

### Omit the forward profile until after MVP

This is safer than mixing and remains a valid scheduling choice. It is not selected as the architecture because a separate experimental profile provides useful forward-development evidence and pressure-tests profile isolation. Nothing in this ADR requires the forward profile to block the vanilla MVP release.

### Permit one common-surface artifact for both profiles now

The PRD allows such an artifact only with complete matrices and a genuinely common surface. The MVP forbids it because the catalog and test machinery needed to prove that intersection does not exist yet. A future superseding or amending ADR may admit it with evidence.

## Consequences

Positive consequences:

- vanilla artifacts fail closed against forward-only APIs, metadata, handles, and packages;
- forward experimentation does not broaden WordPress support wording;
- caches, manifests, diagnostics, docs, and test results have one reproducible profile key;
- profile differences become generated, reviewable data rather than runtime folklore;
- a future range has explicit admission evidence and maintenance cost.

Costs and constraints:

- shared source may need profile source sets or conditional compilation and must be built separately;
- catalogs and tests are duplicated where the exact authorities differ;
- profile corrections require revisions/digests and cannot silently mutate released evidence;
- users must choose and persist a profile instead of relying on “latest”;
- forward experiments cannot be described as vanilla-compatible without independent proof.

No WordPress profile is supported merely because this ADR is accepted. The decision lock intentionally remains `not-tested`; SDK-010, SDK-011, SDK-012, SDK-013, and later runtime gates advance finite claims.

## Evidence and commands

Reviewed sources:

- [PRD §9 compatibility baselines and version profiles](../../wordpress-hx-sdk-product-requirements.md#9-compatibility-baselines-and-version-profiles);
- [PRD exact-profile acceptance contract](../../wordpress-hx-sdk-product-requirements.md#5-acceptance-contract-for-a-production-candidate);
- [PRD release/profile identity](../../wordpress-hx-sdk-product-requirements.md#24-packaging-versioning-release-engineering-and-update-policy);
- [ADR-001 claim vocabulary and provider separation](001-product-and-repository-boundary.md);
- [`profiles/decision-lock.json`](../../profiles/decision-lock.json).

Acceptance checks:

```bash
python3 scripts/profiles/check-decision-lock.py
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

The decision-lock test validates the exact frozen identities and proves negative fixtures for implicit CI selection, mixed targets, a forward-only capability in a vanilla artifact, vanilla availability inferred for the forward profile, and an unknown/floating profile. Direct upstream commit/tree/tag and distribution verification remains SDK-010/011 work and must not be inferred from this prototype.

## Migration, rollback, and supersession

No released profile consumer exists. SDK prototypes that used an implicit or merged profile must persist one exact profile and move outputs to a profile-specific root before they can become acceptance evidence.

Rolling back a generated catalog selects a prior immutable catalog revision/digest and reruns the artifact's complete profile gates. It does not move the profile name to different upstream bytes. A bad evidence record is corrected additively under ADR-001's claim-correction policy.

A change to exact upstream identity creates a new exact profile or an explicitly versioned catalog revision; it does not silently rewrite `wp70-release` or `gutenberg-forward-23.4`. Broadening to a range, allowing combined MVP artifacts, or adding profile inheritance requires an amended or superseding ADR with the admission evidence above.

## Follow-up beads

- `wordpresshx-sdk-010`: directly verify and lock the vanilla WordPress source/distribution, embedded Gutenberg, hashes, and evidence.
- `wordpresshx-sdk-011`: directly verify the separate forward Gutenberg source/tag and prohibition fixtures.
- `wordpresshx-adr-008`: decide catalog generation sources and API classifications within these identities.
- `wordpresshx-sdk-012`: define the versioned profile schema and typed compile-time/runtime capability model.
- `wordpresshx-sdk-013`: generate deterministic catalogs from exact read-only upstream evidence.
- `wordpresshx-adr-013`: bind genes-ts package resolution and output to the selected exact profile.
- `wordpresshx-adr-021`: define release/support windows and maintenance commitments required for future ranges.
