# Browser compiler pin and ownership

The SDK's browser compiler authority is the separate, generic [genes-ts repository](https://github.com/fullofcaffeine/genes-ts). The current immutable baseline is `genes-ts` `v1.33.0`:

- commit `7999b7cff09f78ebb8e09c3db6e221beb141b67b`;
- Git tree `5ec14a28160ae676d24e6092ace8f1d2a4ad6dc5`;
- released `submit.zip` SHA-256 `4bf2d2d1046ee5a99830ef31158a90033bfa521da12eb1d5ecd136b35b4fd145`.

The machine-readable lock is [`manifests/upstream.lock.json`](../../manifests/upstream.lock.json). The complete SDK-030 verification, including the clean-worktree replay, hosted jobs, package hashes, discarded harness attempt, and the experimental Haxe 5 limitation, is [`manifests/evidence/sdk-030-genes-ts-v1.33.0.json`](../../manifests/evidence/sdk-030-genes-ts-v1.33.0.json).

## Evidence boundary

The supported upstream release gate passed with Haxe 4.3.7, Node 20, Yarn 1.22.22, TypeScript 5.5.4/6.0.2/7.0.2, classic JavaScript output, strict TypeScript output, ts2hx, security scans, and real Playwright runs. Node 22 upstream smoke/classic lanes and CodeQL also passed.

Haxe `5.0.0-preview.1` is an explicitly non-blocking upstream experiment. Its job failed on preview macro/library API incompatibilities (`ExprDef`, `tink.OutcomeTools`, and `ClassBuilder` were unavailable). That failure is not represented as supported Haxe 4.3.7 evidence, and this SDK makes no Haxe 5 browser-compiler claim.

This pin resolves the older PRD snapshot discrepancy between a `v1.13.0`-era full-port lock and later `1.32.0` package metadata. Neither historical value is used implicitly.

## Ownership rule

WordPress package maps, handles, profiles, metadata, and build integration belong in this SDK. Generic lowering, TypeScript/JavaScript semantics, module behavior, source maps, declarations, and ts2hx compiler behavior belong in genes-ts.

If SDK work exposes a generic compiler defect:

1. reduce it to a fixture with no WordPress or SDK dependency;
2. create an isolated worktree from the genes-ts authority repository;
3. implement and test both strict TypeScript and classic JavaScript behavior;
4. run the full upstream release gate and all directly affected lanes;
5. open an upstream PR only after the worktree is clean and regressions are green;
6. update this lock only to an immutable merged commit or release and record the PR/receipt.

No genes-ts change or PR was needed to establish `v1.33.0`. Release builds must consume the immutable release/commit, never the floating sibling checkout.

## Upgrade and rollback

The generic compiler maintainers own upgrades. The immediate recorded rollback is `v1.32.0` at commit `09a17f57ae5645d719d2edbb9c795b40abd8e4f1`, tree `06f5ced331180886047161d8dfaa850ccdc6984a`. Any upgrade or rollback still requires a fresh SDK receipt; the existence of a prior release is not itself compatibility evidence.
