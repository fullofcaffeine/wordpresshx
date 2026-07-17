# Support

## Current status

`wordpress-hx-sdk` has no released packages, supported versions, supported compatibility profile, migration promise, or response-time SLA. The current repository is suitable for architecture and feasibility development only.

The PRD uses exact future profiles, but their names do not constitute support until the corresponding manifests and real-runtime evidence gates close.

## Getting help during bootstrap

Contributors should search and use the local beads tracker:

```bash
bd search <term>
bd ready
bd show <id>
```

When a public repository and issue channel are configured, non-sensitive reproducible defects and documentation questions may use that channel. Security-sensitive material must follow [SECURITY.md](SECURITY.md).

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
