# Beads history security reader

`bash scripts/beads/push-safe.sh` scans both the current issue records and every
decoded historical issue state before it publishes the Dolt data ref. This is
important because removing a secret from the current issue does not remove it
from database history.

Released Beads 1.1.0 cannot read historical rows whose text columns became
`NULL` during an earlier schema migration. The failure is tracked by upstream
[issue 4867](https://github.com/gastownhall/beads/issues/4867) and
[pull request 4912](https://github.com/gastownhall/beads/pull/4912).

The compatibility path is deliberately narrow:

1. Try the installed released `bd` first.
2. Admit the fallback only for the exact known NULL-to-string diagnostic.
3. Build the exact v1.1.0 source plus the single pinned upstream correction.
4. Run the upstream embedded-Dolt regression before caching that reader.
5. Copy the embedded database into a private temporary Git repository.
6. Read and scan only that copy; never give the compatibility reader the live
   database path.
7. Reject any issue-set mismatch, unknown read failure, machine-local path, or
   Gitleaks finding before publication.

The source identities, allowed changed files, regression, and retirement
condition are closed in `history-reader.lock.json`. Once an admitted Beads
release includes the equivalent fix, the installed release becomes the normal
reader and this temporary builder can be removed.

Run the focused checks with:

```bash
bash scripts/security/test-beads-decoded-state.sh
bash scripts/security/test-beads-history-failure.sh
bash scripts/beads/test-history-reader.sh
```

The final command scans the real local history but compares the decoded live
issue state before and after, failing if it changed.
