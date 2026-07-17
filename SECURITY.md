# Security Policy

## Supported versions

There are no published or supported versions of `wordpress-hx-sdk` yet. The repository is in bootstrap/pre-feasibility state. No generated authentication, authorization, HTML, SQL, install/update, or package path is approved for production use.

A supported-version table, patch/backport window, response owners, and disclosure timeline must be accepted before a stable release.

## Reporting a vulnerability

Do not include exploit details, secrets, personal data, or a working proof of concept in a public issue.

When the repository is hosted on GitHub with private vulnerability reporting enabled, use the repository's **Security → Report a vulnerability** flow. If that private flow is unavailable, contact a repository maintainer through an already established private channel and ask for a secure reporting path before sending sensitive details.

No dedicated public security address has been established during bootstrap. Establishing and testing that channel is a release blocker tracked by the security/support governance work; this document does not invent an unmonitored address.

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
