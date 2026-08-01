# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

> **Architecture in one line:** Issues live in a local Dolt database
> (`.beads/dolt/`); cross-machine sync uses `bd dolt push/pull` (a
> git-compatible protocol), stored under `refs/dolt/data` on your git
> remote — separate from `refs/heads/*` where your code lives.
> `.beads/issues.jsonl` is a passive export, not the wire protocol.
>
> See [SYNC_CONCEPTS.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md)
> for the one-screen overview and anti-patterns (don't treat JSONL as the
> source of truth; don't `bd import` during normal operation; don't
> reach for third-party Dolt hosting before trying the default).

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bash scripts/beads/push-safe.sh  # Scan decoded records/history, then push Beads data
```

## Direct-to-Main Delivery

- Commit and push ordinary WordPressHx repository work directly to `main` after all relevant quality gates pass.
- Do not create pull requests for routine SDK, documentation, test, compiler, or Beads changes in this repository.
- Use a pull request only when the user explicitly requests one or for unusually hard, isolated upstream work in another project (for example, a generalized change to `../genes`). Follow that project's contribution workflow.
- If a pull request is created, do not leave it closed without merging: make its gates pass and merge it unless the user explicitly directs otherwise.

## Independent Review

- Never make progress depend on a manual human review merely because the
  reviewer is human. When independent judgment is required, prepare a
  content-addressed evidence bundle and ask a separate Oracle/review agent to
  adopt the relevant expert perspective.
- The review agent must not share the implementation turn, author the reviewed
  change, prepare its own evidence, or receive hidden conclusions. Record its
  model identity, review prompt, immutable input hashes, findings, and decision.
- Treat an Oracle review as technical evidence, not as a legal opinion or an
  automatic publication decision. The product owner retains decisions that
  require owner authority. A human specialist may be consulted voluntarily or
  when the user explicitly requests one, but human participation is not a
  default blocking gate.
- For an exceptionally complex manual GPT-5.6 Pro handoff, use the globally
  installed `$oracle-review` skill. It prepares a content-addressed, sanitized
  Repomix package, checks for pending requests, and manages the `/tmp/oracle`
  archive lifecycle; the independence and authority rules above still apply.
  Public source and install instructions:
  https://github.com/fullofcaffeine/caf-skills/tree/main/skills/oracle-review

## Strictly Typed Haxe

- Do not use `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` in Haxe code. Leverage concrete types, typedefs, enums, abstracts, generics, typed adapters/codecs, and compiler-checked pattern matching instead.
- Treat decoded configuration, JSON, macro expressions, foreign-runtime values, and generated data as typed boundaries. Validate and convert them immediately into concrete project types; never propagate an untyped value through domain or compiler logic.
- An exception is allowed only when an external or compiler API makes a typed implementation genuinely impossible after typed alternatives have been exhausted. Keep it to the smallest expression or boundary adapter, convert immediately to a concrete type, and add an inline comment that explains why it is unavoidable and states the invariant that makes it safe.
- Existing untyped code is not precedent. Remove violations in any code being touched, and do not add or expand suppressions to bypass this rule.

## Haxe-First Ergonomics

- When Haxe can safely infer, default, derive, validate, or generate something, prefer doing so in the Haxe layer instead of requiring repetitive author code or handwritten PHP, JavaScript, JSON, shell, or framework configuration.
- Design the common path for high information density: typed defaults, focused macros, enums/abstracts, reusable declarations, generated adapters, and IDE-visible APIs should make ordinary code concise while preserving compile-time checks and deterministic output.
- Turn statically knowable framework invariants into source-positioned Haxe compile errors. Invalid stores, actions, selectors, blocks, components, metadata, capabilities, and configuration should fail before PHP, JavaScript, WordPress, or Gutenberg runs; reserve runtime validation for values that genuinely depend on the installed environment or request.
- Keep advanced behavior available through explicit typed options and narrow escape hatches. Ergonomic helpers must not hide ownership, weaken validation, introduce ambiguous magic, or couple the core SDK to an optional integration.

## Behavior-First Testing

- Before broad automation for meaningful behavior, record the preconditions, action or compilation path, observable result, edge or failure behavior, owning product surface, and exact protected claim.
- Start a fix at the lowest faithful owner. Record the focused command and concise intended red result in its Bead or durable evidence, make it green, then run the next broader real boundary. Keep the focused regression when a browser or system test discovers a stable lower-level compiler, generator, or PHP defect.
- Give every material expectation an independent oracle: an upstream specification, manually authored expectation, pinned differential reference, invariant, reviewed golden with provenance, or real consumer behavior. Never generate an expected value with the implementation under test or refresh a snapshot without semantic review.
- Establish one tracer bullet through authored Haxe, generation/compilation, native target checks, the relevant WordPress or browser boundary, and a real observer before multiplying fixtures.
- Keep independent scorecards for compiler/adapter, WordPress runtime and public ABI, package/install, Gutenberg/browser, and migration/downstream behavior. A green result for one surface must not advance another surface's claim.
- Treat maintained examples as executable ecosystem QA and label each as a flagship application, capability showcase, or compile-only snippet. It may support only the level it actually builds, installs, boots, or exercises.
- Preserve the R0-R5 feedback rings, always-run sentinels, conservative selector fallback, cold release proof, cache/artifact separation, and explicit no-retry/quarantine policy. Affected-test selection remains observation-only until its false-negative evidence justifies promotion.
- For compiler representation, runtime, ABI, package, security, migration, or claim changes, perform a review pass distinct from implementation that challenges oracle independence, negative cases, mocked boundaries, selector omissions, and scorecard laundering.
- The checked authority, commands, current timings, and bounded claims live in `manifests/testing-strategy.json` and `docs/testing-strategy.md`.

## Product Documentation and Positioning

- Lead the WordPressHx README, related NextJsHx integration documentation, and
  later beginner guides with the practical reasons to choose the Haxe/HXX
  surface over maintaining raw PHP plus JavaScript/TypeScript: one typed
  cross-layer authoring model, compile-time framework checks, reusable
  contracts, generated native artifacts, deterministic tooling, source
  correlation, and explicit interoperability escape hatches.
- Demonstrate those advantages with small comparable workflows or
  before/after examples. Explain what repetitive configuration, duplicated
  models, late runtime failure, or cross-language drift Haxe removes; do not
  rely on abstract claims that Haxe is merely safer or cleaner.
- Make native compatibility a central product promise: WordPressHx extends
  ordinary WordPress and Gutenberg rather than replacing their runtimes, and
  its generated PHP, HTML, metadata, CSS, and browser modules must remain
  inspectable and consumable by the existing ecosystem.
- Keep positioning evidence-bound. Until the relevant exact-profile,
  artifact, and runtime gates pass, describe “100% compatible” as the intended
  architecture and state the precise verified profile or bounded capability;
  never turn a design goal into an unqualified current support claim.

## Genes and Downstream Ownership

- Put reusable Haxe-to-JavaScript/TypeScript language and tooling capabilities
  in **Genes**, not directly in consumer frameworks or projects such as
  WordPressHx/GutenbergHx or NextJsHx. This includes generally applicable
  typed authoring support, JS/TS/TSX lowering and emission, source maps,
  module/runtime interop, compiler diagnostics, and framework-neutral frontend
  primitives. The rationale is reuse by other present or future Haxe-to-JS/TS
  projects, not only the integration that first exposed the need.
- Treat generic React capabilities the same way. React component, Hook,
  HXX/JSX, props, children, refs, dependency, event, and module-export
  mechanisms that are useful across hosts belong in Genes, normally under its
  framework-neutral `genes.react` layer. This repository owns only the
  WordPress/Gutenberg provider bindings, exact component and data contracts,
  profile policy, and application ergonomics built on that shared mechanism.
- Keep downstream code focused on intrinsic product or framework semantics:
  WordPress and Gutenberg contracts, Next.js contracts, exact-profile
  adapters, integration policy, packaging, and application behavior. A
  downstream fixture may prove the need for a general Genes capability, but
  the downstream must not become its permanent implementation home.
- Decide ownership from semantics, not discovery location. Move a capability
  upstream only when its API and tests are useful without WordPressHx-specific
  types, paths, fixtures, profiles, or assumptions; do not create speculative
  abstractions merely to make code appear general.
- Make generalized Genes changes in an isolated worktree under `../genes`,
  follow that repository's contribution rules, prove its existing and new
  quality gates without regressions, and use a pull request. Before planning,
  editing, tracking, committing, or publishing there, read and obey the complete
  applicable `AGENTS.md` hierarchy and referenced workflow instructions from
  the Genes checkout. Operate as the Genes repository agent for that work:
  use its architecture, Beads/worktree model, testing strategy, documentation
  standards, hooks, commit/PR conventions, release rules, and completion
  protocol rather than carrying over WordPressHx shortcuts or assumptions.
  Layer the user's current request and compatible WordPressHx directives on
  top; if instructions conflict, the target repository's instructions govern
  work performed in that repository unless the user explicitly overrides them.
  Re-read the target instructions when they change or when a new worktree/task
  begins; a remembered summary is not a substitute.
- Apply the same target-repository mode to any neighboring upstream or sibling
  project, not only Genes. Its root and scoped `AGENTS.md` files govern work
  inside that repository, while this file governs WordPressHx work and the
  cross-repository ownership decision.
- Tell the user when the upstream PR is ready or merged. Do not hide an
  unmerged upstream change in a permanent downstream fork; any necessary
  temporary compatibility bridge must be narrow, explicitly tracked, and
  removable.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

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
   Publish Beads state with `bash scripts/beads/push-safe.sh`; do not invoke the underlying Dolt push directly.
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
