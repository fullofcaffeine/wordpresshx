# ADR-021: Release and support policy

- Status: accepted
- Date: 2026-07-17
- Owners/reviewers: Marcelo Serpa (product owner and current release/compatibility owner), Codex (release architecture and evidence-boundary review)
- Bead: `wordpresshx-adr-021`
- Profiles/layers: SDK/CLI release train, exact profiles, compiler/toolchain pins, generated artifacts, security response, compatibility claims, and rollback
- Supersedes: the provisional no-release wording in the bootstrap governance files
- Superseded by: none

## Context

The repository has green source, profile, compiler-foundation, HXX-parser, and
WordPress-harness evidence, but it has no installable SDK release and no complete
application artifact at `production-supported` evidence. Green CI proves only
the finite checks it ran. It does not establish maintainer capacity, a security
response channel, a compatibility window, or a promise to ship fixes.

Release scope is unusually easy to overstate here. An SDK version is useful only
with its exact WordPress/Gutenberg profile and catalog digest, Haxe and target
compiler pins, PHP/Node/browser/database matrix, generated public ABI, final ZIP
hashes, and evidence receipts. A vanilla WordPress result does not transfer to
the forward Gutenberg profile or a future full-port provider. Likewise, finding
an API or running a compiler fixture does not make a deployable site supported.

The project currently has one accountable human maintainer. GitHub private
vulnerability reporting was queried on 2026-07-17 and returned
`{"enabled":false}`. No backup release/security credential holder or tested
private intake exercise exists. Licensing and generated-output terms also remain
blocked by ADR-020 and SDK-002. The policy must therefore define a sustainable
future stable contract without manufacturing one today.

## Decision

### Release eligibility and evidence

There are no stable releases during `0.x`. A normal-versioned release may use the
word **stable** only at `1.0.0` or later and only when all of these are true for
the exact release candidate:

1. G8 and every dependency of its claimed capability set are closed with
   immutable evidence.
2. ADR-020 and SDK-002 authorize publication and the final artifacts carry the
   required license inventory and notices.
3. The public Haxelib and npm CLI have the same exact SDK version as required by
   ADR-003; packed clean-project consumer tests reject mixed versions.
4. Every advertised capability is `production-supported` for the named exact
   profile, provider, artifact, and environment. Aggregate wording may not exceed
   the weakest included capability.
5. The release manifest contains a closed support table with exact profile and
   catalog digests, exact tool/runtime versions, final artifact hashes, evidence
   receipt IDs, publication time, support end time, and owners.
6. Final Haxelib/npm/source/WordPress ZIP bytes are built twice from one clean
   immutable commit, pass installed-package and rollback tests, and are verified
   after download.
7. A private vulnerability channel, release credentials, revocation path, and
   primary plus backup owners have been exercised successfully. A name in a file
   without access and a completed rehearsal is not ownership evidence.
8. The named maintainer explicitly accepts the finite support term and confirms
   capacity for security review, dependency maintenance, release, and rollback.

Failure of any condition permits continued development or a visibly labeled
preview; it forbids stable, supported, production-ready, or unqualified
WordPress-compatibility wording.

### Channels

| Channel | Immutable identity | Intended use | Support contract |
|---|---|---|---|
| development | exact Git commit and local/CI receipts | architecture and feasibility work | none; not a release |
| nightly | exact commit plus ephemeral artifact digest | early integration and diagnostics | unsupported; no compatibility or retention promise; never a floating release dependency |
| preview | exact SemVer prerelease/tag, profile/catalog, manifest, and checksums | bounded evaluation of explicitly unstable scope | best-effort issue triage only; no patch/backport or production promise |
| stable | normal SemVer `1.0.0+`, exact release manifest, final package hashes, and current support term | production use only for the manifest-listed finite scope | the published finite support contract in this ADR and the release manifest |
| security patch | patch release on an active stable line, with advisory and replacement hashes | correct a vulnerability without broad feature work | inherits only the remaining support term of the affected stable line unless release notes explicitly extend it |

Nightly and preview artifacts must say `unsupported` and identify gaps. A preview
does not become stable because it has been used successfully. The
`gutenberg-forward-23.4` profile remains preview/experimental and has no vanilla
WordPress 7.0 or independent production-support claim.

Publication of every channel other than contributor-local development remains
blocked until ADR-020/SDK-002 permits the relevant artifact class. This ADR does
not resolve licensing.

### Version and support term

ADR-003's lockstep `wordpress-hx` and `@wordpress-hx/cli` version is the support
line through `1.x`.

- `0.x` may break public prototypes in a minor release, but every release still
  publishes an exact API/profile diff, migration notes, toolchain manifest, and
  known limitations. No `0.x` version receives a support or backport promise.
- Every stable minor line has a default support term of **180 consecutive days**
  beginning at its publication timestamp. The release manifest records the exact
  UTC start and end instants. Once published, that end cannot move earlier.
- Release notes may promise a longer term before publication. They may not leave
  the end date implicit or retroactively shorten it.
- During the term, the latest patch on that minor line receives compatible defect
  and security fixes. Earlier patches are immutable rollback inputs, not separate
  maintained lines.
- A successor minor does not terminate the predecessor's published term. Before
  releasing overlapping stable lines, the release owner must attest that all
  active terms are sustainable; otherwise the successor remains preview.
- At end of term, the line becomes `end-of-support`. Artifacts and receipts remain
  available and immutable, but no further fix or compatibility promise exists.
  A vulnerability discovered after end-of-support may still be disclosed, but a
  backport is not promised.
- A major version has no automatic relationship to a prior major's term. Its
  release cannot shorten an already published term.

There is no “latest means supported” shortcut. A support page is generated from
release manifests and lists exact active and ended terms.

### Exact profile and environment windows

Support is membership in a release manifest, not version comparison.

- The first possible stable WordPress profile is the exact `wp70-release`
  catalog admitted by G8. Its name alone proves nothing; the release records the
  catalog digest and complete capability/evidence ledger.
- `gutenberg-forward-23.4` is not a stable WordPress distribution profile. A
  future independent Gutenberg-plugin support decision requires its own exact
  provider/runtime matrix and does not inherit the vanilla result.
- Adding a WordPress release creates another exact profile or explicitly
  versioned catalog identity. It does not create a `7+`, caret, wildcard, or
  inferred intermediate range. A range requires all ADR-002 admission evidence.
- An old profile is maintained only inside the remaining term of a stable SDK
  line that lists it. A new profile does not silently extend or terminate that
  term.
- A runtime or toolchain patch not present in the manifest is untested, not
  presumed compatible. It may be admitted by a new SDK patch only after the
  applicable exact matrix and final-artifact checks pass.

Every stable release manifest must list exact identities for:

- WordPress source/distribution, embedded or standalone Gutenberg, profile
  revision, and catalog digest;
- Haxe, Lix/Haxelib inputs, `reflaxe.php`, Genes, parser libraries, formatters,
  and build tools;
- PHP syntax floor and every executed PHP lane;
- Node, npm/package manager, bundler, and TypeScript/React packages;
- Chromium plus any Firefox/WebKit lanes claimed for user-facing behavior;
- MySQL and MariaDB images/versions used for database-dependent behavior;
- operating-system/container images, architecture, and provider identity where
  behavior can differ.

The current evidence is not a stable matrix. Haxe 4.3.7, compiler PHP 7.4/8.4
fixtures, and the WordPress 7.0 PHP 8.4.23 MySQL 8.4.10/MariaDB 11.4.5 harness
remain separately scoped receipts. Node/browser images are inventoried rather
than SDK-runtime certified, and no final plugin/theme/site ZIP has passed G8.

### Deprecation and breaking changes

For a stable public contract:

1. Deprecation lands in a minor release with a machine-readable classification,
   source-located diagnostic where applicable, replacement or explicit
   no-replacement reason, migration example, and earliest removal version/date.
2. The old contract remains functional for at least one subsequent stable minor
   and **at least 180 days** after its deprecation release. Both conditions must
   pass.
3. Removal normally occurs only in a major release and only after generated API,
   profile, ABI, serialization, and migration diffs have been reviewed.
4. Experimental, private, and unsafe surfaces do not receive stable compatibility
   promises, but their changes still appear in preview notes and unsafe
   inventories.
5. A profile catalog correction is classified independently from upstream
   change. Correcting a public signature can be breaking even when upstream bytes
   did not change; the replacement links the prior digest and carries an explicit
   migration.

A security vulnerability or upstream withdrawal may require immediate
withdrawal before the ordinary window. That is an additive claim correction,
not a silent deletion: preserve the old receipt, mark the affected scope
`withdrawn`/`unsupported`, publish an advisory and safe replacement or mitigation,
and explain why the normal window could not be honored.

### Security, patch, and dependency policy

Only an active stable line has a security-patch commitment. Preview reports are
accepted and triaged best effort, but there is no response-time or fix SLA.

For an active stable line:

- the private reporting path and access are tested before release;
- severity and affected exact tuples are recorded without placing exploit or
  personal data in public issues or Beads;
- a minimal patch is prepared from the affected immutable line, with all
  invalidated source, compiler, generated target, real WordPress/browser,
  package, and rollback gates rerun;
- backports do not copy a green result across profile, compiler, runtime, or
  artifact hashes;
- compromised artifacts are revoked/yanked when ecosystem controls permit and
  replaced by a new immutable version; tags and package bytes are never silently
  overwritten;
- advisories identify affected and fixed versions, exact artifact hashes,
  mitigation, and any support-term effect;
- every active stable line receives a dependency/advisory review at least once
  per 30 consecutive days and before each release. If that cadence cannot be
  maintained, no new stable release is authorized and the status page must state
  the capacity problem.

No numeric first-response or resolution SLA is promised by this ADR. SDK-003
must define severity/triage mechanics and tested channels without inventing an
unmonitored mailbox.

### Accountability and capacity

The current accountable owner assignments are:

| Responsibility | Current owner | Stable-release condition |
|---|---|---|
| product scope and final claim matrix | Marcelo Serpa | explicit approval of the exact release manifest |
| release cut, registry publication, and downloaded-byte verification | Marcelo Serpa | exercised protected credentials and clean workflow |
| rollback, yanking/revocation, and status correction | Marcelo Serpa | successful rehearsal against immutable artifacts |
| compatibility profiles and backport scope | Marcelo Serpa | current exact-profile evidence and active-term capacity |
| private security intake and coordination | Marcelo Serpa, provisional | private reporting enabled/tested and a qualified backup assigned |
| backup release/security recovery | unassigned | must be a named human with tested access before stable |

Automated agents may build, test, prepare diffs, or execute an approved release
workflow. They are not accountable owners and cannot accept a support term,
security disclosure, claim matrix, or destructive rollback.

The project is presently single-maintainer and provides no SLA. The unassigned
backup, disabled private vulnerability reporting, unresolved licensing, and
incomplete G8 evidence are explicit stable-release blockers. If maintainer
capacity falls below an already published term, the owner must disclose the risk
and prioritize security/claim correction; capacity does not authorize silently
ending the term.

### Canonical release and rollback

A canonical release follows PRD §24.4 and additionally produces one signed-off
release manifest that binds source commit, package versions, profiles, matrices,
claims, support term, owners, final hashes, SBOM/licenses/provenance, diffs,
unsafe inventory, receipts, and rollback version. Publication occurs only from
the tested CI workflow; a dirty maintainer checkout cannot create release bytes.

Rollback never moves a tag or overwrites a registry/archive object:

1. Stop promotion and identify the affected exact release/profile/artifact.
2. Preserve evidence and mark an overstated or unsafe claim failed, unsupported,
   or withdrawn.
3. Select the last known-good immutable version recorded by the release manifest.
4. Test its installation and supported downgrade/restore path against clean and,
   where relevant, upgraded state. Database/content changes are rolled back only
   when an explicit reversible migration passed; otherwise ship a forward repair.
5. Yank/deprecate the bad version where possible, publish status/advisory text,
   and issue a new patch/replacement version rather than republishing bytes.
6. Verify downloaded replacement bytes and update the support/claim index
   additively.

Rollback is an operational response, not evidence that the prior version remains
supported outside its published term.

## Rationale

A fixed 180-day term is finite enough for a small project to evaluate honestly
and long enough to make “stable” materially different from preview. Requiring an
exact support table avoids an open-ended “latest” promise and preserves the
profile architecture: users can see exactly which SDK, WordPress, PHP, browser,
database, compiler, and artifact tuple is maintained.

Keeping all `0.x` work unsupported permits rapid contract learning without
pretending that migration notes or green CI constitute production operations.
The stable gate then binds engineering evidence to actual humans, credentials,
security intake, and rollback capacity. The backup requirement deliberately
blocks a single inaccessible credential holder from becoming the whole response
plan.

## Alternatives considered

### Support only the latest release indefinitely

This is common shorthand and easy to document, but it has no finite end, lets a
new release terminate an old promise without notice, and cannot be budgeted by a
small team. It is rejected in favor of release-specific dates.

### Long-term-support and multiple concurrent branches at 1.0

An LTS line can reduce upgrade pressure, but this project has no evidence that it
can maintain even one production line yet. Multiple backport branches would
multiply profile/compiler/browser matrices and security work. A future
superseding ADR may add LTS only after real demand and staffing evidence.

### Treat previews as supported with best-effort wording

“Supported, best effort” still implies a fix and response commitment while
leaving its duration and scope ambiguous. Preview remains explicitly unsupported;
reproducible issue reports are still welcome.

### Infer WordPress/PHP/Node compatibility ranges

Ranges are convenient for package metadata but cannot be proved by endpoint
inventory or one runtime lane. This is rejected. Exact versions can later be
combined into a range only through ADR-002's finite admission evidence.

### Defer every window and owner decision until G8

Deferral avoids an early policy choice, but implementation would then optimize
for a release shape whose operational cost is unknown. This ADR fixes the
default term, channel semantics, and stable blockers now; G8 supplies concrete
dates, versions, people, and evidence without changing the rules.

## Consequences

Positive consequences:

- development may proceed through 0.x without an accidental support promise;
- every future stable claim has finite dates, exact inputs, evidence, and owners;
- profile/toolchain absence is visible instead of inferred as compatibility;
- users receive deprecation and migration time for stable contracts;
- security fixes and rollbacks preserve immutable artifacts and receipts;
- single-maintainer capacity is an explicit gate rather than hidden risk.

Costs and constraints:

- `1.0` cannot ship until security intake, backup access, licensing, G8 evidence,
  and rehearsals exist;
- faster minor releases may create overlapping 180-day maintenance terms;
- exact environment admission requires additional patch releases and matrices;
- stable public removals are slow even when implementation maintenance would be
  easier after deletion;
- monthly active-line dependency review and release-specific support pages add
  operational work beyond CI.

This ADR does not make any current capability, profile, package, or artifact
supported. It defines how a future release may earn and retain that status.

## Evidence and commands

Reviewed evidence:

- PRD §§23.8 and 24.1–24.9 (operational supportability, channels, SemVer,
  canonical release, compatibility windows, packaging, and licensing gate);
- PRD §29.1 ADR-021 requirement and §29.2 unresolved runtime matrices;
- [ADR-001 claim and correction vocabulary](001-product-and-repository-boundary.md);
- [ADR-002 exact-profile/range admission](002-exact-compatibility-profiles.md);
- [ADR-003 lockstep public release unit](003-package-topology-and-lockstep-versioning.md);
- [ADR-008 evidence maturity, deprecation, and additive corrections](008-profile-generation-and-api-classification.md);
- current [governance](../../GOVERNANCE.md), [support](../../SUPPORT.md),
  [security](../../SECURITY.md), and [release skeleton](../release/README.md);
- `gh api repos/fullofcaffeine/wordpresshx/private-vulnerability-reporting`,
  observed `{"enabled":false}` on 2026-07-17.

Acceptance checks:

```bash
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

SDK-003 must translate this decision into the public governance/support/security
documents, a machine-readable release/support contract, canonical release and
rollback checklists, and a dry-run exercise. G8 must bind a real candidate rather
than treating this ADR as readiness evidence.

## Migration, rollback, and supersession

No released consumer exists, so accepting this ADR creates no user migration.
Bootstrap wording that said all release/support policy was unresolved must now
point to this decision while continuing to say that no current version is
supported.

A future policy may extend terms, add LTS, assign different owners, or admit an
independent forward-profile line through a superseding ADR. It may not shorten a
term already published in an immutable release manifest. If the project cannot
sustain stable releases, it keeps existing promises through their end dates,
marks later work preview, and publishes a superseding freeze/archival decision;
it does not silently redefine stable.

## Follow-up beads

- `wordpresshx-sdk-003`: implement governance, support/security channels,
  machine-readable policy, release/rollback workflow, and rehearsal evidence.
- `wordpresshx-adr-020` and `wordpresshx-sdk-002`: resolve licensing before any
  public artifact publication.
- `wordpresshx-sdk-100` through `wordpresshx-sdk-103`: assemble, rehearse, audit,
  and approve the first candidate under this policy.
- `wordpresshx-g8`: bind the exact support matrix, dates, owners, and final bytes
  before any stable claim.
- `wordpresshx-adr-022`: keep any future full-port provider receipt separate and
  non-blocking for vanilla support.
