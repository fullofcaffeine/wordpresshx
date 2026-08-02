# Beads history security reader

`bash scripts/beads/push-safe.sh` scans both the current issue records and every
decoded historical issue state before it publishes the Dolt data ref. This is
important because removing a secret from the current issue does not remove it
from database history.

The original released Beads 1.1.0 reader could not read historical rows whose
text columns became `NULL` during an earlier schema migration. The failure is tracked by upstream
[issue 4867](https://github.com/gastownhall/beads/issues/4867) and
[pull request 4912](https://github.com/gastownhall/beads/pull/4912).
The repository database has since advanced to schema 62, so the authoritative
CI reader must also match the exact source identity in `.beads-toolchain`; the
older schema-53 compatibility binary cannot open current Beads state.

The compatibility path is deliberately narrow:

1. Try the installed released `bd` first.
2. Admit the fallback only for the exact known NULL-to-string diagnostic.
3. Build the exact schema-62 source commit named by the repository toolchain.
4. Prove that the pinned upstream correction is an exact ancestor with the
   reviewed file set, then run its embedded-Dolt regression before caching the
   reader.
5. Copy the embedded database into a private temporary Git repository.
6. Read and scan only that copy; never give the compatibility reader the live
   database path.
7. Reject any issue-set mismatch, unknown read failure, machine-local path, or
   Gitleaks finding before publication.

The source identity, schema, client identity, fix ancestry, allowed changed
files, regression, and retirement condition are closed in
`history-reader.lock.json` and cross-checked with `.beads-toolchain`. The
isolated builder remains necessary while security policy requires an
independently reconstructed historical-state reader.

Run the focused checks with:

```bash
bash scripts/security/test-beads-decoded-state.sh
bash scripts/security/test-beads-history-failure.sh
bash scripts/beads/test-history-reader.sh
```

The final command scans the real local history but compares the decoded live
issue state before and after, failing if it changed.

Hosted security also runs the cold builder-only contract:

```bash
bash scripts/beads/test-history-reader.sh --build-only
```

That mode does not require or inspect a live Beads database. It builds in a
fresh cache, runs the pinned upstream regression, and requires stdout to contain
exactly one executable path. The security-policy check selects this mode only
for the hosted `security` job so other repository jobs do not repeat the costly
cold Go build.
