# ADR-017: Generated output version-control policy

- Status: proposed
- Date: 2026-07-19
- Owners/reviewers: Marcelo Serpa (product and developer-experience owner); Codex (architecture, policy-contract, Git-fixture, and sibling-reference review)
- Bead: `wordpresshx-adr-017`
- Profiles/layers: SDK repository; generated consumer projects; exact-profile build, package, and release lanes
- Supersedes: none; resolves the generated-output VCS question deferred by ADR-016
- Superseded by: none

## Context

WordPressHx makes Haxe the maintained application and site-authoring surface.
PHP, JavaScript/TypeScript, CSS, WordPress metadata, maps, translations, and
deployment packages are useful because ordinary WordPress and browser tooling
can inspect and execute them. Their inspectability does not make them authored
authority.

Version control still needs a deliberate policy. A compiler repository benefits
from committed expected output because an exact diff is a dense review surface.
A consumer may deploy directly from Git to a host that cannot run Haxe. Another
consumer may prefer a small source repository whose CI and deployment system
always compile. A bootstrap compiler may exceptionally require generated code
to build without its predecessor. Treating all of those cases as either “always
commit generated files” or “never commit generated files” loses important
information.

This is distinct from generated-file ownership. ADR-007 decides whether a live
path may be replaced or removed by the SDK. This ADR decides whether a generated
artifact belongs in Git and what proof is required when it does. A Git-tracked
file does not grant generator ownership, and an ADR-007 manifest entry does not
by itself make a file suitable for Git or release.

The PRD recommends that consumer projects not be forced to commit generated
PHP/TypeScript and that scaffolds default to CI regeneration. ADR-016 commits the
small bootstrap, exact project lock, and CLI-owned projections needed to make
that regeneration reproducible. ADR-021 separately controls release channels
and publication. ADR-020 separately controls licensing; this decision grants no
license and authorizes no publication.

## Decision

### Classify by role, not by whether bytes were generated

[`wordpress-hx.generated-output-vcs.v1`](../../manifests/generated-output-vcs-policy.json)
is the closed machine-readable policy. Every relevant artifact has one named
role:

| Artifact role | SDK repository default | Consumer default | Release treatment |
| --- | --- | --- | --- |
| Authored Haxe, tests, and hand-owned assets | Commit | Commit | Immutable source input |
| Exact locks and bootstrap projections | Commit | Commit | Materialize from and verify exact locked identities without recalculating dependency resolution |
| Reviewed goldens, catalogs, receipts, or required bootstrap inputs | Commit only for a declared SDK review/build role | Do not commit by default | Regenerate and compare when consumed |
| PHP, JS/TS, CSS, metadata, maps, and other deployment output | Ignore scratch output | Ignore and regenerate | Generate in a new private stage |
| Ownership journals, stages, and caches | Ignore | Ignore | Never trust or package |
| ZIPs, checksums, SBOMs, provenance bundles, and debug companions | Ignore as normal branch source | Ignore as normal branch source | Produce as immutable release artifacts |

“Generated” is not an admission class. A generated file may be committed only
because it is an exact input, an explicit review contract, or a consumer's
explicit deployment choice. Its role must be visible in its path, manifest, or
policy. A familiar extension, a generated-looking header, Git history, or equal
bytes does not assign a role or ownership.

Haxe remains the application authority in every mode. A committed generated
artifact is a derived projection. It may be reviewed, deployed, or used as a
bootstrap input, but it never supersedes Haxe, the exact project lock, or the
generator's typed contracts. The developer changes Haxe or the responsible
generator and regenerates; hand-editing generated output is unsupported.

### SDK repository default: commit review contracts, ignore scratch output

The WordPressHx SDK repository commits:

- authored source, schemas, policies, tests, documentation, and hand-owned
  fixtures;
- exact dependency, profile, toolchain, and upstream locks;
- CLI-owned bootstrap projections needed to type or build a fixture;
- reviewed expected-output snapshots and catalogs whose exact diff is a test
  contract; and
- content-bound receipts and exceptional generated bootstrap inputs with a
  named producer, source identity, tool identity, regeneration command, and
  consumer.

The SDK ignores ordinary compiler output, local deployment trees, private
stages, transactions, caches, and release archives. A snapshot tests the exact
shape selected by its fixture; it does not make printer formatting, helper
naming, or disposable output a public API. Behavioral compatibility and runtime
claims still require their own tests.

An exceptional generated build input—such as a future stage0-free compiler
snapshot—must be reproducible only through its named script. It is never patched
by hand. The same change contains the source/generator/lock change, regenerated
snapshot, reviewed diff, and evidence that the snapshot can perform its stated
build role. This exception cannot be inferred from another compiler repository.

### Consumer default: commit Haxe and exact inputs; regenerate output

New consumer projects default to committing authored Haxe, hand-owned assets and
tests, `wordpress-hx.json`, exact dependency/tool/profile locks, and the small
CLI-owned bootstrap projections required for a clean build. They ignore
generated PHP, JavaScript/TypeScript, CSS, WordPress metadata, source maps,
ownership transaction state, build directories, distribution directories, and
deployment archives.

The scaffolded CI default is a clean `wphx check`/`wphx build` and relevant
runtime tests from the committed source and exact locks. This keeps the ordinary
repository dense and avoids reviewing derived noise while preserving a complete
reproducible consumer path. A developer need not touch or understand PHP merely
because WordPress ultimately executes it.

An ignored stale local build cannot affect a release. Packaging starts from a
new checkout or equivalent immutable source material and uses private output
stages outside that checkout. A clean `git status` alone is insufficient because
it does not report ignored files.

### Consumer committed-output mode is explicit and per output root

A consumer may opt in when generated output must travel through Git—for example,
a Git-only WordPress host. The opt-in is not global and is never inferred from
an existing generated file. It names each output root and records an exact
ADR-007 manifest for every committed generated path.

The committed-output mode requires all of the following:

1. authored Haxe and exact locks remain committed and authoritative;
2. the opt-in policy and generated ownership manifest are committed;
3. every committed generated file has an exact path, byte size, SHA-256, source
   plan, generator, SDK/CLI, profile, and toolchain identity;
4. a new private regeneration compares the complete path set and exact bytes in
   CI;
5. source, generator, lock, policy, manifest, and generated diff are reviewed as
   one change; and
6. deployment consumes only a complete manifest-bound generation.

An output root not named by the opt-in retains the consumer default. Same bytes
do not silently adopt an unowned file. An existing native PHP or JavaScript file
also remains hand-owned unless a separate explicit adoption workflow changes
the project source-of-truth boundary.

### Drift and review workflow

For every committed generated contract or consumer opt-in, the gate performs
the following ordered workflow:

1. resolve exact source, SDK/CLI, generator, profile, and toolchain identities;
2. generate the complete result into a new private stage;
3. validate the ADR-007 manifest and every staged validator;
4. compare exact relative paths, byte sizes, SHA-256 digests, and bytes against
   the committed generation;
5. inspect the authored and generated diffs together; and
6. succeed without live mutation for validation-only commands; for a requested
   update, publish manifest-last, and on any failed check leave live output
   unchanged.

The comparison fails on a missing or extra path, any byte difference, stale
identity, undeclared artifact role, generated-only change with no responsible
source/generator/lock/policy change, or manual edit. Formatters do not repair a
committed generated file in place. The remediation is to change Haxe or the
responsible generator and regenerate.

“Reviewed together” means the accountable maintainer examines the complete
change and regeneration evidence. It does not require a pull request in this
repository; routine WordPressHx work continues to follow the direct-to-main
policy after gates pass.

### Release always regenerates, independent of branch policy

Packaging and release apply one invariant protocol whether consumer generated
output is ignored, committed, or used as a bootstrap input:

1. resolve an immutable clean commit or tag and all exact locks;
2. create fresh isolated source material and private stages outside the source
   checkout;
3. ignore ambient caches and never consume working-tree generated output;
4. regenerate the complete deployment tree twice from the exact inputs;
5. compare the two trees by exact relative path, size, SHA-256, and bytes;
6. if a committed generated artifact is a declared build input, separately
   regenerate and compare it exactly before consuming it;
7. validate ownership, target quality, license/notices, package contents, and
   runtime gates against the staged bytes;
8. assemble the normalized archive twice and compare it byte-for-byte;
9. bind source commit, toolchain lock, profile, generator, generated manifest,
   and archive digests in provenance; and
10. prove the source checkout remained unchanged.

The release job never trusts a committed artifact merely because a drift gate
passed earlier, and it never publishes a ZIP copied from a branch. Release ZIPs,
SBOMs, checksums, provenance, and debug companions are immutable release outputs,
not normal source files. SDK-101 owns the production WordPress archive,
installation, SBOM, and attestation implementation.

This decision cannot relax the regeneration step. Changing the consumer default
requires a superseding ADR plus scaffold migration. Changing ADR-007 ownership
meaning requires a new ownership-contract major. Publication remains blocked
until the separate licensing and release policies authorize it.

## Rationale

The selected policy optimizes the common Haxe-first workflow without removing a
practical Git-only deployment escape hatch. It also keeps compiler development
honest: committed goldens make output changes visible, while fresh output proves
that the golden was not edited into existence.

Role-based admission is more durable than an extension list. PHP may be a
disposable consumer build output, a reviewed SDK snapshot, or an exceptional
bootstrap input; those need different VCS rules even though the suffix is the
same. Exact provenance and ADR-007 ownership make an explicit consumer opt-in
safe enough to reason about without redefining generated PHP as authored source.

Release regeneration is intentionally stricter than both repository modes. It
removes stale ignored output, local caches, and prior CI stages from the trust
boundary. Double generation and double archive assembly separate deterministic
compiler/package behavior from Git convenience. The final archive remains the
artifact that later runtime and installation evidence must identify exactly.

The sibling reference review informed, but did not supply, this implementation:

- `haxe.elixir.codex` commits `intended/` output as a reviewed compiler contract
  while generating fresh disposable `out/` trees;
- `haxe.ruby` distinguishes Haxe-owned and framework-owned source authority and
  uses committed output snapshots without treating disposable output as API;
  and
- `haxe.ocaml` demonstrates the exceptional bootstrap case: a committed
  generated build input has an explicit regeneration path and must not be
  hand-edited.

The policy records exact sibling commit, path, blob, and SHA-256 identities. No
code or fixture bytes were copied and no sibling checkout became a runtime or
build dependency.

## Alternatives considered

### Always commit consumer generated output

This supports simple Git-only deployment and makes target diffs visible. It is
rejected as the default because it expands routine reviews, invites manual PHP
or JavaScript edits, and lets stale artifacts appear authoritative. It remains
available only as the explicit per-root mode with exact manifests and drift CI.

### Never commit any generated output

This gives a clean conceptual source boundary. It is rejected as a universal
rule because compiler goldens are valuable review contracts, some environments
deploy only repository bytes, and a future self-hosted compiler may need an
explicit bootstrap snapshot. Each admitted exception instead has a named role
and stronger regeneration proof.

### Commit output and let Git diffs detect drift

Git identifies changed tracked bytes but cannot prove what generated them,
detect ignored stale inputs, validate an ADR-007 ownership manifest, or show
that a clean regeneration is complete. It also cannot establish deterministic
archives. Exact private regeneration remains required.

### Trust committed output after CI once

This would reduce release work. It is rejected by the stop condition: branch
artifacts, caches, CI stages, and release inputs can diverge after an earlier
gate. The release must recreate and compare its own exact bytes from immutable
source.

### Store release archives in the main branch

This can make downloads convenient but bloats source history, complicates
immutability, and obscures whether the archive or source is authoritative.
Archives belong to an immutable release channel after SDK-101 and the licensing
and release gates authorize publication.

## Consequences

Positive consequences:

- the default consumer repository remains Haxe-first and compact;
- developers who do not want to touch PHP or JavaScript do not have to maintain
  those files;
- compiler and catalog changes retain exact reviewable output contracts;
- Git-only deployment remains possible through an explicit, verifiable mode;
- hand edits, stale output, and provenance drift fail deterministically; and
- releases have one policy independent of consumer repository preference.

Costs and limits:

- committed-output consumers pay for larger diffs and clean regeneration CI;
- SDK maintainers must state why every committed generated artifact exists;
- exact byte comparisons mean intentional generator changes require reviewed
  snapshot updates;
- double generation and double archive construction add release time; and
- the attached rehearsal is synthetic policy evidence, not proof of production
  PHP, Genes, WordPress, browser, ZIP, SBOM, or registry behavior.

## Evidence and commands

The executable contract is:

- [`manifests/generated-output-vcs-policy.json`](../../manifests/generated-output-vcs-policy.json);
- [`scripts/generated-output-vcs/check-policy.py`](../../scripts/generated-output-vcs/check-policy.py);
- [`scripts/generated-output-vcs/test-policy.py`](../../scripts/generated-output-vcs/test-policy.py); and
- [`fixtures/generated-output-vcs/`](../../fixtures/generated-output-vcs/README.md).

Run:

```bash
python3 scripts/generated-output-vcs/test-policy.py
bash scripts/check-repository.sh
```

The test rejects 19 unsafe policy mutations and four security-sensitive receipt
mutations. It uses 13 temporary Git repositories and seven release clones to
exercise default ignored output, reviewed SDK golden drift, a closed explicit
per-root consumer policy, absent/extra/nested/inferred-root rejection, consumer
committed-output drift and provenance, dirty-source rejection, stale committed
deployment output exclusion, exact comparison of a declared generated build
input, stale build-input rejection, different ignored cache contents,
byte-identical double generation and deterministic ZIP assembly, complete
release provenance binding, and checkout non-mutation.

The receipt is
[`ADR-017-GENERATED-OUTPUT-VCS-POLICY`](../../manifests/evidence/adr-017-generated-output-vcs-policy.json).
It preserves the synthetic boundary: production `wphx` integration,
deterministic WordPress ZIPs, actual registry publication, and production
support remain untested.

## Migration, rollback, and supersession

Existing generated consumer projects migrate to the default by first proving a
clean exact build, then removing generated roots from Git and adding the
scaffolded ignore policy in one reviewed change. They retain authored Haxe and
exact locks. A host that requires Git-carried output instead selects the explicit
per-root mode, generates an ADR-007 manifest, commits the complete generation,
and enables fresh byte-comparison CI before deployment.

No migration infers ownership from tracked files. Existing hand-owned native
files remain hand-owned. Adoption uses the explicit ADR-007/source-authority
workflow and creates a backup before any destructive transition.

Rollback of an opt-in returns to ignored regeneration only after the exact
generated manifest is clean, deployment has moved to a build-capable path, and
the generated files and policy are removed together. Rollback does not delete
unowned files or edit a manifest by hand.

A superseding ADR must preserve release regeneration or replace it with stronger
runtime evidence accepted by the product owner. The current policy remains
fail-closed for unknown artifact roles and policy versions.

## Follow-up beads

- `wordpresshx-sdk-045` owns generated-project defaults and clean consumer
  scaffolds.
- `wordpresshx-sdk-045.3` owns the explicit per-root committed-output CLI and
  generated-project drift gate.
- `wordpresshx-sdk-101` owns production deterministic WordPress ZIP, SBOM,
  provenance, exact-byte installation, and release replay.
