# Contributing

`wordpress-hx-sdk` is at bootstrap stage. Contributions should strengthen the dependency-gated vertical product path rather than add unaudited API breadth.

## Start with beads

Run the repository workflow context, choose ready work, inspect it, and claim it before changing implementation files:

```bash
bd prime
bd ready
bd show <id>
bd update <id> --claim
```

Use beads for all task tracking. Do not create parallel Markdown task lists. New work must include the scope/authority/artifact/evidence/risk/acceptance/stop-condition fields required by the PRD. Preserve the stable `SDK-*`, `ADR-*`, and gate references when refining existing work.

## Architectural working agreement

- Vanilla WordPress is the blocking runtime authority for the primary SDK profile.
- `wp70-release` and `gutenberg-forward-23.4` are separate profiles; no symbol, package, handle, or metadata key may leak between them.
- Generated public PHP and browser output are product surfaces: deterministic, readable, native-shaped, statically checked, and runtime-tested.
- Generated ownership is exact-path and checksum based. Never add a force-overwrite shortcut.
- Generic compiler defects stay generic. WordPress-specific behavior belongs in SDK profile code.
- SDK work is never reported as full-port implementation ownership.

## Compiler changes

### PHP

Continue from the custom Reflaxe PHP compiler developed in the full-port project, but extract and consume a versioned generic compiler boundary. Do not copy in or import port-only Core linking, original-path replacement, adapter registry, or distribution assembly code.

A compiler change needs a minimized fixture that can be described without WordPress semantics, the relevant upstream regression suite, an immutable commit/release, and a downstream pin receipt.

### genes-ts

Use the authoritative genes-ts checkout/repository for browser compiler work. If this SDK uncovers a compiler defect:

1. create an isolated worktree in the genes repository;
2. reduce the failure to a generic fixture with no WordPress or SDK dependency;
3. implement the generalized fix in genes;
4. run the complete relevant upstream regression suite, including classic/TypeScript lanes as applicable;
5. create an upstream PR only after the evidence is green;
6. record the PR URL and final immutable pin in the SDK bead and lock manifest.

Do not add `if wordpress` branches, SDK package imports, or a floating sibling path to genes release builds.

## Quality and evidence

Install the tracked Git hooks once in each clone or worktree:

```bash
bash scripts/hooks/install.sh
bash scripts/hooks/test.sh
```

The pre-commit path formats staged Haxe with Formatter 1.18.0, rejects machine-local paths and whitespace errors, and scans staged bytes with Gitleaks 8.30.0. The pre-push path scans every reachable Git revision. Do not bypass these hooks. Use the decoded-state guard for Beads synchronization because the Dolt ref is separate from ordinary Git branches:

```bash
bash scripts/beads/push-safe.sh
```

Run checks in proportion to the changed layer and record exact commands and versions on the bead. The bootstrap checks are:

```bash
bash scripts/check-repository.sh
bd lint
bd dep cycles
```

Later beads add strict Haxe, PHP floor/runtime/static analysis, strict TypeScript, real WordPress, editor/browser, security, accessibility, determinism, and packaging gates. A snapshot or mock is not a substitute for a required native-runtime check.

Before ending a work session, follow the repository's `bd prime` close protocol: create follow-up beads, run quality gates, update/close issues, commit intentionally, pull/rebase and push, run the safe Beads push, verify status, and provide a handoff.
