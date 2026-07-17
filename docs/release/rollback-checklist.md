# Immutable rollback and claim-correction checklist

Accountable rollback owner: Marcelo Serpa. Backup recovery owner: unassigned,
which is a stable-release blocker. This checklist must be exercised on final
package/state shapes before stable.

1. Stop promotion and identify the exact SDK version, profile/catalog digest,
   provider, environment, artifact hashes, user/state impact, and evidence.
2. Preserve the old tag, bytes, manifests, and receipts. Mark the effective claim
   `failed`, `unsupported`, or `withdrawn` additively when warranted.
3. Select the release manifest's last known-good immutable tuple. Never move a
   tag, overwrite a package version, or substitute new bytes under an old hash.
4. Test clean installation and the supported downgrade/restore path. Reverse a
   database/content migration only when its exact reversible fixture passed;
   otherwise prepare a forward state repair.
5. Yank/deprecate the affected artifact where ecosystem controls permit and
   publish status/advisory text without exposing embargoed details.
6. Build a new patch/replacement version through the full invalidated matrix,
   including final-byte install, upgrade, rollback, security, and consumer tests.
7. Verify downloaded replacement hashes and update support/claim indexes while
   retaining prior evidence.
8. Notify downstream providers that reference the affected unchanged artifact;
   they retain authority over their separate claims.

The SDK-003 synthetic rehearsal proves only that policy chooses this path. It is
not a registry, credential, final-ZIP, database-state, or disclosure exercise.
