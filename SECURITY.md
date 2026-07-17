# Security Policy

## Supported versions

There are no published or supported versions of `wordpress-hx-sdk` yet. The repository is in bootstrap/pre-feasibility state. No generated authentication, authorization, HTML, SQL, install/update, or package path is approved for production use.

ADR-021 now defines the future finite window, but no release has earned it. A supported-version table, exact manifest, tested private intake, primary and backup access, final-artifact patch/rollback rehearsal, and active maintainer capacity must all exist before stable.

## Reporting a vulnerability

Do not include exploit details, secrets, personal data, or a working proof of concept in a public issue.

GitHub private vulnerability reporting is currently disabled (verified 2026-07-17). Do not send exploit details through a public issue, discussion, pull request, commit, log, or Bead. Contact Marcelo Serpa without sensitive details and request a secure channel; if no authenticated private channel is available, retain the details until one is established.

No dedicated security address has been established. Enabling and testing private reporting, assigning a qualified backup with access, and rehearsing intake are a stable-release blocker. This document does not invent an unmonitored address or imply that a public contact is a secure disclosure channel.

No numeric response-time or resolution SLA is promised. Preview reports are triaged best effort. Only a future active stable term carries a patch/backport commitment, and any timeline must be stated in the private case/advisory according to its actual scope rather than pre-promised here.

## Triage and patch flow

The coordinator records the affected exact SDK/profile/provider/toolchain/artifact tuple and assigns release-blocking severity when the report plausibly enables authorization bypass, code execution, secret exposure, unsafe output, arbitrary overwrite/deletion, dependency compromise, or a false production claim. Sensitive evidence stays outside public task records.

A stable security fix is a new immutable patch version. It is built from the affected line, reruns every invalidated source/compiler/generated/native/package/rollback gate, verifies downloaded replacement bytes, and publishes an advisory with affected/fixed hashes and mitigation. Tags, package versions, receipts, and ZIP bytes are never overwritten. Backports are limited to active stable terms; previews and ended terms have no fix promise.

Every active stable line requires dependency/advisory review at least once per 30 consecutive days and before release. If that capacity or channel cannot be maintained, no new stable version is authorized.

## Leak prevention

Every clone must install the tracked hooks with `bash scripts/hooks/install.sh`. Commits are guarded by exact Haxe formatting, machine-local path rejection, whitespace checks, and staged Gitleaks scanning. Pushes scan all reachable Git history, and public CI repeats the full-history checks with a checksum-pinned Gitleaks binary and commit-pinned actions.

Beads records live in decoded Dolt state as well as the passive JSONL export. Publish them only through `bash scripts/beads/push-safe.sh`, which scans current records and every issue-history revision before invoking the Dolt push. Never put real credentials, exploit material, or sensitive personal data into a canary or allowlist.

A useful private report includes:

- affected commit, package, profile, and generated artifact hash;
- trust boundary and expected versus observed behavior;
- minimal reproduction in a clean environment;
- impact and preconditions;
- suggested mitigation, if known;
- whether details have been shared elsewhere.

## Security scope

Security review covers both maintained source and generated artifacts, including:

- REST, admin, block, template, and browser inputs;
- nonces, capabilities, authentication, and authorization;
- validation, sanitization, escaping, trusted HTML, JSON, CSS, and URL contexts;
- file paths, manifests, staging, cleanup, archives, and update/install flows;
- PHP/JavaScript interop and unsafe target segments;
- Haxelib, npm, Composer, compiler, action, image, and toolchain provenance;
- source maps, logs, secrets, and production diagnostics.

Any reproducible overwrite/deletion of user-owned data, profile-boundary leak, authorization bypass, code execution, or unescaped user-controlled output is treated as release-blocking until triaged. Typed wrappers do not reduce the requirement to prove native WordPress/browser behavior.
