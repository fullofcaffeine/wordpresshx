# Support

## No supported versions

`wordpress-hx-sdk` has no released packages, supported versions, supported compatibility profile, migration promise, or response-time SLA. The current repository is suitable for architecture and feasibility development only. `manifests/release-support-policy.json` is the machine-readable authority and currently contains an empty `supportedVersions` array with publication and stable release disabled.

The PRD uses exact future profiles, but their names do not constitute support until the corresponding manifests and real-runtime evidence gates close. `wp70-release` is only the first possible stable candidate; `gutenberg-forward-23.4` remains preview-only. Neither name implies a version range.

## Channels and future terms

- Development and nightly artifacts are unsupported and identified by an exact commit/artifact digest.
- A preview is an exact evaluation build with best-effort triage and no patch, backport, retention, or production promise.
- Stable cannot begin before `1.0.0` and requires the complete ADR-021/G8/licensing/security/owner/rehearsal gates.
- A future stable minor has a default 180-day, non-shortenable term beginning at publication. Exact UTC dates, latest maintained patch, profiles/catalog digests, runtime/toolchain matrix, artifact hashes, and owners must appear in its exact release manifest.
- End-of-support artifacts remain immutable and available, but carry no further fix or compatibility promise.

There is no “latest,” caret, wildcard, or `WordPress 7+` support shortcut. A runtime/tool patch becomes supported only in a new exact manifest after its applicable gates pass.

## Getting help during bootstrap

Contributors should search and use the local beads tracker:

```bash
bd search <term>
bd ready
bd show <id>
```

Non-sensitive reproducible defects and documentation questions may use the repository's public GitHub issue channel. Security-sensitive material must follow [SECURITY.md](SECURITY.md) and must not be placed in GitHub issues or Beads.

A useful report states:

- exact commit and bead/ADR, if known;
- WordPress/Gutenberg profile and upstream hashes;
- Haxe/PHP/Node/browser/database/tool versions;
- source and generated artifact hashes;
- smallest reproduction and exact commands;
- native PHP/browser/WordPress logs with secrets removed;
- whether the failure occurs in a final package or only a source checkout.

## Deliberately unsupported today

Everything is unsupported until evidenced, including package installation, WordPress version ranges, forward Gutenberg APIs, themes, WP-CLI, Interactivity API, arbitrary PHP/TypeScript migration, third-party plugin compatibility, and a production runtime/security claim.

Users will still need native WordPress, PHP, Gutenberg/React, browser, database, and packaging knowledge. The future SDK is intended to make those boundaries safer and more consistent, not to hide them or replace their support ecosystems.

## Triage and expectations

Reports are triaged by impact and evidence, not arrival order alone. Security, authorization bypass, code execution, destructive ownership violations, and overstated release claims are release-blocking. Reproducible core failures are prioritized above speculative breadth; documentation and ergonomics work remain valuable but cannot override a safety gate.

No numeric response or resolution SLA exists. A report may be closed or redirected when it lacks a reproducible exact scope, concerns an unsupported preview, belongs to an upstream compiler/provider, or contains sensitive details in public. Acceptance of an issue is not acceptance of a support claim or delivery date.
