# Future repository extraction

`reflaxe.php` stays in the WordPressHx monorepo while its API is changing. This
file describes how to preserve the package boundary now and how to move it only
when ADR-004 records a concrete reason to do so.

## Current ownership

The generic package owns PHP language IR, printing, source correlation,
portable compile-time markup lowering, generic diagnostics, and neutral
fixtures. It must remain usable without WordPress.

WordPress-specific lowering and native conventions belong to
`compiler/wordpress`; public authoring ergonomics and project orchestration
belong to the SDK packages. Those layers may evolve quickly and may request new
generic capabilities, but dependencies continue in one direction:

```text
reflaxe.php <- WordPress PHP profile <- WordPressHx SDK
```

Issue routing follows the same boundary:

- PHP syntax, generic Haxe lowering, IR, printer, source-map, or portable markup
  defects belong to `reflaxe.php` and require a minimized neutral fixture.
- Hook, REST, block, theme, template-hierarchy, WordPress ABI, or profile-policy
  defects belong to the WordPress profile or SDK and retain a WordPress fixture.
- A WordPress fixture may expose a generic defect, but the generic fix is not
  accepted until the behavior is reproduced without WordPress names or runtime
  state.

## Readiness maintained during co-location

The package-owned readiness gate must continue to prove:

1. the generic tests run without the WordPress profile or SDK classpaths;
2. two package builds from the same source are byte-identical;
3. the source-only ZIP has a complete file/hash manifest and immutable archive
   digest;
4. a disposable Haxelib repository can install the ZIP and a neutral external
   Haxe application can emit and run PHP without resolving this checkout;
5. release inputs contain no sibling checkout, `haxelib dev`, machine-local, or
   other floating filesystem dependency; and
6. downstream WordPress compiler fixtures remain green on the same commit.

The package stays at `0.0.0` and publication remains forbidden until ADR-020
and SDK-002 authorize licensing and release policy.

## Extraction trigger

Do not split merely because the package is technically movable. First accept
one of ADR-004's measured triggers, such as an independent PHP consumer,
different release ownership or cadence, approved public distribution, or a
demonstrated monorepo maintenance cost.

## Extraction procedure

Once a trigger is accepted:

1. Start from a clean, immutable WordPressHx commit and record its commit, tree,
   package source digest, archive digest, provenance record, and passing generic
   and downstream receipts.
2. Export the history for `compiler/reflaxe.php` into a temporary repository,
   removing the monorepo prefix while retaining commit attribution. Record the
   source-to-destination commit mapping and exact exported-file inventory.
3. Run secret, machine-local-path, license, and provenance audits against the
   complete filtered history before creating a destination repository.
4. Run the package-owned tests and isolated install proof from a clean clone
   that cannot access WordPressHx source. Rebuild twice and require the recorded
   archive identity.
5. Give the extracted package its own version, changelog, support declaration,
   release permissions, immutable artifact, and rollback owner. Do not use a
   moving branch, sibling checkout, submodule, subtree, or `haxelib dev` as a
   release dependency.
6. Replace WordPressHx workspace resolution with an exact package version and
   artifact digest. Run the focused WordPress compiler fixtures and every
   affected broader runtime gate against that exact artifact.
7. Move issue and documentation authority, remove the old writable package
   source, and avoid maintaining two editable copies.

Rollback is an explicit WordPressHx pin change to the last accepted immutable
artifact. It never rewrites a tag or copies an unrecorded source patch between
repositories.
