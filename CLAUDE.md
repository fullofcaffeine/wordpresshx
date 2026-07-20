# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

_Add your project-specific conventions here_

### Strictly Typed Haxe

- Do not use `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` in Haxe code. Prefer concrete types, typedefs, enums, abstracts, generics, typed adapters/codecs, and compiler-checked pattern matching.
- An exception is allowed only at the smallest unavoidable external or compiler boundary, followed immediately by conversion to a concrete type and an inline comment stating why the boundary is safe.

### Haxe-First Ergonomics

- When Haxe can safely infer, default, derive, validate, or generate something, do it in the Haxe layer instead of requiring repetitive author code or handwritten PHP, JavaScript, JSON, shell, or framework configuration.
- Turn statically knowable framework invariants into source-positioned Haxe compile errors. Invalid stores, actions, selectors, blocks, components, metadata, capabilities, and configuration should fail before PHP, JavaScript, WordPress, or Gutenberg runs; reserve runtime validation for values that genuinely depend on the installed environment or request.
- Keep the common path concise, typed, IDE-visible, deterministic, and compatible with explicit advanced options and narrow escape hatches.
