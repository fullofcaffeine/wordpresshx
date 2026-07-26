# G3 — Semantic plan and fail-closed ownership

Gate G3 makes generation safe enough for later WordPress and Gutenberg
features to build on it. A failed build leaves the previous generated tree
unchanged, and cleanup can remove only files that the current manifest still
owns with the expected bytes.

This is a build-safety milestone. It does not claim that a generated plugin is
compatible with WordPress, that packages may be published, or that the SDK is
ready for production.

## The build in one pass

```text
typed Haxe declarations
  -> canonical semantic plan
  -> complete private output tree
  -> format, static, schema, package, and artifact checks
  -> one ownership transaction
  -> generated files, with the ownership manifest published last
```

A **semantic plan** is the versioned, canonical build description produced
after Haxe has typed the source. Canonical means the same meaning is encoded
into the same bytes, so its digest can identify an exact plan.

A **private output tree**, or stage, is a complete proposed generation outside
the live generated paths. Validators inspect this complete proposal. The PHP
quality tools run on the exact proposed PHP bytes before publication; the
ownership callback then proves that the complete stage still contains those
same bytes and the authenticated quality report. If either link fails, the
publisher does not begin changing the live tree.

The **ownership manifest** lists every generated file with its exact path,
size, content hash, source nodes, source spans, projections, and validators.
Publishing it last makes it the commit marker: a current manifest never
promises a file that an interrupted transaction did not finish publishing.

## What fail closed means

Suppose a developer edits a generated PHP file by hand and then rebuilds.
WordPressHx compares the live file with the path, size, and hash recorded in the
current manifest. The mismatch stops the build before publication. The tool
does not overwrite the edit because a filename or generated-looking comment is
never ownership evidence.

The same rule applies to cleanup. `wphx clean` derives its removal set only from
the current manifest, verifies every owned byte, and publishes the reduced
manifest through the same transaction. Unowned files and modified generated
files are preserved; the latter produce a diagnostic that asks the developer
to resolve the ownership conflict.

The transaction journal records the exact prior and proposed states. After a
process interruption, recovery either finishes a fully committed next state or
restores the exact prior state. Tests stop the process at every supported
checkpoint to exercise both paths.

## Finding why a file exists

After a build, ask for one exact manifest entry:

```bash
wphx inspect --why .wphx/generated/effective-inputs.json --json
```

The result includes the artifact hash and its source, projection, owner, and
validator provenance. `inspect provenance <generated-path>` remains an
equivalent explicit form. The production fixture runs this lookup for every
generated fixture artifact and verifies that each result matches both the
manifest entry and the live content hash.

## Evidence map

| G3 requirement | Primary evidence |
|---|---|
| Versioned canonical semantic plan | ADR-006 and `SDK-040-SEMANTIC-COLLECTOR` |
| Complete staging and ownership protocol | ADR-007 and `SDK-041-OWNERSHIP-TRANSACTION` |
| Traversal, links, collisions, edits, stale files, and malformed manifests | `SDK-041-OWNERSHIP-TRANSACTION` |
| Quality checks before publication with exact staged-byte binding | `SDK-026-GENERATED-PHP-QUALITY` and `SDK-045-PLUGIN-SCAFFOLD` |
| Journal recovery and rollback | ADR-007 and `SDK-041-OWNERSHIP-TRANSACTION` |
| Manifest-only clean | ADR-007, SDK-041, and `SDK-043-PROJECT-CLI` |
| Byte-identical builds and unsigned ZIPs | `SDK-042-DETERMINISTIC-BUILD` |
| Exact artifact provenance | `SDK-043-PROJECT-CLI` plus the G3 closure re-verification |

The aggregate receipt
`manifests/evidence/g3-semantic-ownership.json` binds these records, the current
`inspect --why` implementation, the exact acceptance claims, and hosted job
identities. Its validator also rejects reduced failure coverage, stale subject
hashes, invented hosted proof, publication bypasses, and broader compatibility
claims.

## Verification

```bash
python3 scripts/gates/test-g3-closure.py
bash scripts/semantic-collector/test.sh
bash scripts/ownership/test.sh
bash scripts/determinism/test-production.sh
bash scripts/project-cli/test-production.sh
bash scripts/php-quality/test-production.sh
bash scripts/scaffold/test-production.sh
bash scripts/check-repository.sh
```

The exact command outcomes and hosted workflow IDs live in the aggregate
receipt. Power-loss durability, hostile concurrent mutation, Windows and
network filesystems, WordPress runtime compatibility, package publication, and
production support remain outside the G3 claim.
