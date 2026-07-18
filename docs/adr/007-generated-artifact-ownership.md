# ADR-007: Generated artifact ownership

- Status: accepted
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product owner and PRD authority), Codex (architecture and filesystem contract review)
- Bead: `wordpresshx-adr-007`
- Profiles/layers: SDK/CLI artifact owner, every generated output root, semantic-emission staging, package inputs
- Supersedes: none; makes PRD §19 normative and completes ADR-006's live-publication boundary
- Superseded by: none

## Context

WordPressHx will generate ordinary PHP, JavaScript/TypeScript, metadata, CSS,
translations, source maps, themes, plugins, blocks, and package files. Those
artifacts are intentionally inspectable and may coexist with files a developer,
WordPress, another generator, or a package manager owns. A generator that infers
ownership from a directory name, header comment, extension, or familiar bytes can
overwrite or delete user work.

ADR-006 already forbids target emitters from writing the live tree. They return a
complete, content-bound staged result. A single artifact-owner layer must decide
whether those bytes may become live, validate the complete staging tree, and
recover an interrupted publication without guessing. This decision defines that
layer. `wordpresshx-sdk-041` remains responsible for implementing the production
Haxe/CLI transaction; this ADR's Python harness is a filesystem contract fixture,
not shipped application code.

No portable filesystem offers one atomic rename for an arbitrary set of files
that may share directories with unowned content. The contract therefore needs to
be precise about its guarantee: a normal or caught-failure command is
failure-atomic, the manifest is the commit marker, and an abrupt interruption is
crash-consistent through a durable journal and backups. A reader can observe a
short per-file publication window during an abrupt kill, but no later SDK command
may proceed until it deterministically finalizes the complete new generation or
restores the complete prior generation. Packaging and runtime installation only
consume a finalized manifest.

## Decision

### Exact path and content are the only ownership authority

The root ownership document conforms to
[`wordpress-hx.generated-files.v1`](../../schemas/generated-files.schema.json).
A live path is generated-owned only when the current valid manifest contains its
exact normalized project-relative path, expected SHA-256, and byte size. The live
path must be a regular file whose bytes match. Ownership is not established by:

- a generated-looking comment, filename, extension, or directory;
- bytes matching a newly staged artifact;
- an owner/module name without the exact path and current content hash;
- a stale, malformed, unsupported, or missing manifest; or
- a previous manifest, Git history, cache, journal, receipt, or dry-run plan.

The manifest uses `wordpress-hx.canonical-json.v1`: UTF-8 NFC, closed fields,
sorted object keys and declared set arrays, no floats or duplicate keys, compact
JSON, and exactly one final LF. `manifestDigest` binds the canonical document with
that field omitted. File entries are sorted by exact path and bind:

- output root, content hash, byte size, artifact kind, and semantic owner;
- source nodes, projections, and content-bound Haxe source spans;
- every staged validator that admitted the bytes; and
- exact SDK/CLI/toolchain/profile, source-plan, emission-result, and generation
  digests.

The manifest is metadata authority, not a support claim. A valid entry proves
only that the named bytes passed the recorded generation transaction. It does not
by itself prove WordPress, PHP, browser, Next.js, package, accessibility, visual,
or production behavior.

### Portable paths and confinement

V1 accepts only NFC, forward-slash, project-relative paths with a conservative
portable ASCII segment vocabulary. Absolute, drive-relative, UNC, empty, dot,
traversal, backslash, control-character, trailing-dot/space, and Windows device
segments fail. Exact duplicates and Unicode case-folding collisions fail even on
a case-sensitive host.

Output roots are explicit, non-nested, and sorted. Every generated path belongs
to exactly one declared root. The manifest path and private transaction root also
belong to a declared root, but generated entries may name neither. Directories
are never manifest-owned.

Before admission and immediately before each mutation, the owner uses `lstat`- or
equivalent no-follow checks on every existing component from the project root to
the destination. Symbolic links, junctions/reparse points, broken links, special
files, and a root that changes identity fail. Regular-file hard links are never
written through: publication replaces the directory entry, and stale cleanup
unlinks only that exact entry. Concurrent hostile filesystem mutation is not an
admitted compilation environment, but the implementation still revalidates
after acquiring its exclusive lock and before every rename.

V1 requires all declared output roots, transaction staging, and backups to use
one filesystem with atomic same-filesystem file rename semantics. A project that
spans devices must narrow its roots or wait for a separately proven protocol; it
cannot silently fall back to copy-and-delete publication.

### Preflight and complete staging

One build transaction performs these checks before mutating any live generated
path:

1. recover or stop on any prior lock/journal state;
2. parse the current manifest strictly and verify its self-digest and schema;
3. validate every path, root, reserved location, ordering rule, and collision;
4. verify every currently owned file still has its recorded bytes;
5. validate the complete next manifest against the locked semantic plan and all
   staged emission results;
6. materialize the complete next tree, including byte-identical unchanged
   artifacts, only below the private transaction root;
7. reject staged links, special files, undeclared files, missing artifacts, hash
   or size mismatches, and paths outside the declared roots;
8. run formatter, linter, typechecker, schema, package, and target validators
   against staging, then re-hash every staged file; and
9. compute create, replace, remove, unchanged, and—only for the explicit command—
   relinquish operations.

If the manifest is absent, every existing destination is unowned. If it is
malformed or from an unsupported version, the tool does not reinterpret or
migrate it. A migration is a separate tested transaction with exact before and
after bytes. Validators cannot write the live tree or mutate the next manifest.

`--dry-run`, `--diff`, and `--check` stop after producing or validating this exact
plan. They create no journal and acquire no publication authority.

### Journaled publication

Publication conforms to
[`wordpress-hx.ownership-journal.v1`](../../schemas/ownership-transaction-journal.schema.json).
The SDK acquires one exclusive project lock and creates a collision-resistant
private work root. The canonical, self-digested journal binds:

- build, clean, or adopt-generated mode and transaction identity;
- the exact manifest, transaction, lock, stage, and backup locations;
- prior and next manifest content states and durable copies; and
- a sorted operation list with exact old/new content states and deterministic
  stage/backup paths.

The journal becomes durable before any live generated path is mutated. Each file
replacement moves the verified old regular file to the same-filesystem backup,
then renames the verified staged file into place. A removal is the first rename
without a replacement. A create first proves the destination is still absent.
The implementation durably records journal phase transitions and syncs file and
parent-directory metadata as required by its supported filesystem profile.

The new manifest is published last and is the commit marker. Only after its
bytes and every live entry match the complete next generation may the tool
remove backups, journal, lock, and private staging. Unchanged paths need no live
rewrite, but an ordinary build still validates their staged bytes. An identical
manifest and fully staged tree is a publication no-op, which supports byte-stable
double builds.

The operation list must be exactly derivable from the journal-bound prior and
next manifest bytes. Build journals may create, replace, and remove but never
relinquish; clean journals may only remove; adopt-generated journals may only
relinquish exact current entries and cannot rewrite retained entries. The next
manifest state is always present, including the canonical empty ownership
manifest produced by clean.

Power-loss durability is a platform/filesystem capability claim, not an
assumption. The contract fixture proves process-level failure and interruption
on its recorded hosts. `wordpresshx-sdk-041` must add exact supported-platform
primitive checks before claiming power-loss safety.

### Recovery is inference from hashes, never a blind replay

Every SDK command checks ownership recovery state before new work.

- If the live manifest equals the journal's next-manifest content and every
  next-owned path matches while every removal is absent and every relinquished
  file is unchanged, recovery finalizes the complete new generation.
- Otherwise recovery walks operations in reverse, removes a new path only when
  it matches the exact journaled new content, restores only an exact backup of
  the old content, restores or removes the manifest to its exact prior state,
  and then clears private state.
- If a live file, backup, manifest, journal, lock, or path has an unexpected
  type or content, automatic recovery stops. It preserves all remaining bytes
  and reports explicit paths and expected/actual hashes. It never guesses which
  side is newer.

A caught error after the complete next manifest and tree are live runs this same
inference, finalizes the committed generation, and reports publication rather
than attempting a blind rollback. A caught error before the commit marker
restores the exact prior tree or stops for explicit recovery.

A lock-only state created before the durable journal cannot authorize any live
mutation under this protocol. The production implementation must distinguish an
active owner from an abandoned pre-publication owner before clearing it; it must
not use a time threshold alone. A malformed journal after live mutation is a P0
protocol failure and requires the separate explicit recovery workflow with a
backup artifact.

There is deliberately no general `--force` build flag. A destructive recovery
tool, if admitted later, is a different command that requires exact paths,
creates an external backup first, records accountable approval, and never
silently becomes the normal regeneration path.

### Collision and edit behavior

The contract fails before live publication when:

- a next destination exists but is not current-manifest-owned;
- an owned, replaced, or stale file is missing, changed, linked, or not regular;
- two emitters, roots, case variants, or normalized names collide;
- an undeclared file appears in staging;
- an external process changes a destination after preflight;
- a validator fails or changes staged bytes; or
- any requested semantic projection lacks its complete artifact coverage.

Same bytes do not waive an unowned collision. Editing generated output does not
implicitly adopt it. Diagnostics identify the exact owner, old/new hashes,
source/projection provenance, and the supported `diff`, `adopt-generated`, or
source-edit remediation without exposing machine-local absolute paths in durable
receipts.

### `clean` and `adopt-generated`

`wphx-sdk clean` uses the same transaction and an empty next ownership set. It
removes only exact current-manifest entries after path/type/hash verification,
publishes an empty canonical manifest, preserves every unowned file, and prunes
only empty directories created below declared roots. It never recursively
deletes a live output root.

`wphx-sdk adopt-generated <exact-path>` means relinquish SDK ownership while
keeping the exact verified live bytes. It accepts explicit manifest entries, not
globs or directories. The reduced manifest is published transactionally; the
file itself is not moved, rewritten, or deleted. If the semantic plan still
targets that path, the next build sees an unowned collision and fails. The user
must first change the Haxe declaration/output path or declare a checked external
contract.

Scaffold edits to an existing hand-owned file are not generated-file ownership.
They require a separate marker-bounded action plan with an exact whole-file
precondition and reviewed before/after bytes. Routine builds never patch
hand-owned text.

### Versioning and migration

Changing manifest ownership meaning, digest material, path normalization,
collision rules, or transaction/recovery semantics requires a new manifest or
journal major identity. Additive artifact kinds are compatible only when their
file and validator semantics fit v1 unchanged.

Legacy manifests are preserved and rejected until a pure, explicit migration is
implemented. A migration validates original bytes, stages a new manifest, runs
the same collision and recovery corpus, and retains a before/after receipt. It
does not widen an old path list or infer missing hashes. Rollback of a manifest
migration uses the prior immutable SDK/CLI plus its schema and a fresh ownership
preflight; it never edits the manifest by hand.

## Rationale

Exact path+hash authority is understandable and composable. It allows generated
files to coexist with WordPress resources and hand-owned assets without granting
the SDK ownership of an entire directory. A complete staged tree prevents one
emitter from publishing metadata that points at a browser or PHP artifact another
emitter failed to produce.

Per-file backup renames plus a persistent journal are more complex than a whole
directory swap, but a directory swap cannot safely preserve unowned neighbors.
Publishing the manifest last ensures it never promises a file the transaction
has not placed. Hash-inferred recovery handles a crash between an OS mutation and
a journal phase update without trusting an incomplete step counter.

The read-only reference review supports these boundaries without importing an
implementation. Genes demonstrates buffered multi-file output with manifest-last
rollback inside one output directory. Haxe-Go demonstrates typed relative paths,
path-redacted diagnostics, and repeated symlink-component confinement. The full
WordPressHx port demonstrates why semantic/template ownership labels are useful
for claims, while also showing that a path list without exact live hashes is not
sufficient publication authority. This SDK contract adds persistent recovery,
exact old/new hashes, portable collision policy, clean/adoption semantics, and
one authority across PHP, Genes, metadata, theme, and package emitters.

## Alternatives considered

### Replace the entire output directory atomically

A same-filesystem directory rename is attractive and gives one visible switch.
It is rejected as the universal policy because output roots may contain
hand-owned resources or artifacts from another tool. Swapping the directory
would either discard those files or require copying them into staging and
implicitly claiming their state. Dedicated package-finalization directories may
still use directory swap behind this same manifest preflight.

### Let each emitter own a subdirectory

This reduces collisions and transaction breadth. It is rejected as the only
model because WordPress package shapes, root plugin files, block metadata,
theme hierarchy, assets, and translations cross emitter boundaries. It would
also duplicate journals and allow a partial cross-target generation.

### Trust generated headers or Git-tracked files

Headers are useful warnings and Git can restore many mistakes. Neither is a safe
ownership authority: comments can be copied, files may be untracked or deployed
without Git, and a generator must not depend on recovery after data loss. Headers
remain informational only.

### Overwrite when unowned bytes equal staged bytes

This feels harmless and eases adoption. It is rejected because byte equality
does not establish who may delete or change the path later. Explicit
`adopt-generated` or an external contract keeps the ownership transition
reviewable.

### Keep only an in-memory rollback snapshot

This handles caught exceptions and is simpler. It is rejected because process
termination loses the snapshot precisely when recovery is needed. Durable
same-filesystem backups and a self-digested journal are required before live
mutation.

### Roll forward every interrupted transaction

The staged bytes were already validated, so completing them can be tempting. It
is rejected as the default because storage or external mutation may have damaged
the staged/backup set. Recovery finalizes only when the complete new manifest and
tree already match; otherwise it restores exact prior bytes.

### Provide `--force`

A force switch is familiar and can unblock local work. It is rejected because it
would turn every path/symlink/hash safety decision into an optional warning and
would eventually become automated. Explicit relinquishment or backed-up,
path-specific destructive recovery communicates the real ownership change.

### Reuse the full-port ownership manifests

The port's manifests carry valuable semantic claim axes and bounded HXX/template
ownership evidence. They are not reused as SDK publication authority because
their product is original-path/Core ownership and the reviewed pilot manifest
lists paths without exact current live hashes or a crash journal. The concepts
remain a read-only provenance reference; no source or fixture bytes are copied.

## Consequences

Benefits:

- later PHP, Genes, HXX, Gutenberg, theme, metadata, and package generators share
  one fail-closed publisher;
- a build cannot delete or overwrite an unowned or modified regular file through
  the supported path;
- interrupted publication has deterministic finalize/rollback behavior;
- `clean`, adoption, inspection, and source provenance operate on the same exact
  authority; and
- generated artifacts remain ordinary, reviewable WordPress/Next.js inputs with
  no runtime ownership kernel.

Costs and constraints:

- generation needs staging space for the complete next tree and backups for every
  affected old file;
- V1 rejects cross-filesystem roots, nested roots, links, and platform-ambiguous
  names rather than attempting clever fallbacks;
- every validator must be staging-aware and deterministic;
- hard interruption can briefly expose per-file mixed bytes until recovery, so
  package/install consumers require the finalized manifest and build lock;
- schema migrations and deliberate ownership transfers are explicit operations;
  and
- SDK-041 still needs a production Haxe/CLI implementation and broader platform,
  power-loss, permission, disk-full, and concurrency evidence.

This ADR does not prove the SDK-041 production owner, real generated WordPress or
Next.js trees, deterministic ZIPs, package installation, power-loss durability,
Windows filesystem behavior, hostile concurrent mutation resistance, or
production support.

## Evidence and commands

Machine authority:

- [`generated-artifact-ownership.json`](../../manifests/generated-artifact-ownership.json)
- [`generated-files.schema.json`](../../schemas/generated-files.schema.json)
- [`ownership-transaction-journal.schema.json`](../../schemas/ownership-transaction-journal.schema.json)
- [`ownership fixtures`](../../fixtures/ownership/README.md)

The reference-only harness uses real temporary filesystem trees. It proves
successful replace/create/stale removal, first generation, caught-failure
rollback, partial-crash rollback, abrupt and caught post-manifest finalize,
manifest-only clean, explicit relinquishment, complete-stage identical-build
no-op, and entry replacement/removal without mutating hand-owned hard links. It
rejects 25 schema/journal mutations and 17 real filesystem cases covering
traversal, case collision, reserved names and metadata overlap, unowned paths,
modified owned/stale files, malformed/legacy/missing manifests, parent/file/
broken symlinks, special files, concurrent/orphan locks, validator failure,
incomplete or drifted staging, and undeclared staging files. Its 11 positive
filesystem scenarios never write outside their temporary project roots.

Read-only references are recorded at exact commit, path, Git blob, and SHA-256 in
the machine manifest. `copiedBytes` and `dependencyCreated` are false. Genes was
not changed.

Acceptance commands:

```bash
bash scripts/ownership/test.sh
bash scripts/check-repository.sh
bash scripts/hooks/test.sh
bash scripts/lint/hx-format-guard.sh
bd lint
bd dep cycles
git diff --check
```

## Migration, rollback, and supersession

There is no released ownership manifest consumer. Before SDK-041 lands, rollback
is removal of this unshipped contract and reopening ADR-007. After a production
owner exists, a replacement needs a superseding ADR, immutable old/new schema and
transaction fixtures, crash recovery from every old journal phase, a manifest
migration command, and consumer/package evidence.

If per-file journal recovery proves too fragile on an admitted platform, that
platform is withdrawn or narrowed before release. A dedicated-root directory
swap may be admitted as another implementation only if it preserves the same
exact manifest, unowned-file, diagnostics, clean, and adoption semantics.

## Follow-up beads

- `wordpresshx-sdk-041`: implement this manifest, staging, lock, journal,
  recovery, clean, adoption, and inspection contract in the production CLI.
- `wordpresshx-sdk-040`: make the canonical semantic plan and complete emission
  results the only production inputs to the owner.
- `wordpresshx-adr-016`: bind project configuration to exact manifest/output
  roots without weakening confinement.
- `wordpresshx-adr-017`: decide which generated artifacts are committed while
  retaining this ownership contract.
- `wordpresshx-adr-019`: govern explicit destructive recovery and unsafe
  filesystem waivers.
- `wordpresshx-sdk-045`: prove scaffold ownership boundaries in a generated
  Haxe-first project.
- `wordpresshx-sdk-084`: publish full theme/site artifacts only through this
  transaction.
