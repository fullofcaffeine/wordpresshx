# Browser compiler pin and ownership

The SDK's browser compiler authority is the separate, generic [genes-ts repository](https://github.com/fullofcaffeine/genes-ts). The immutable SDK-030 audit baseline is `genes-ts` `v1.33.0`:

- commit `7999b7cff09f78ebb8e09c3db6e221beb141b67b`;
- Git tree `5ec14a28160ae676d24e6092ace8f1d2a4ad6dc5`;
- released `submit.zip` SHA-256 `4bf2d2d1046ee5a99830ef31158a90033bfa521da12eb1d5ecd136b35b4fd145`.

The machine-readable lock is [`manifests/upstream.lock.json`](../../manifests/upstream.lock.json). The complete SDK-030 verification, including the clean-worktree replay, hosted jobs, package hashes, discarded harness attempt, and the experimental Haxe 5 limitation, is [`manifests/evidence/sdk-030-genes-ts-v1.33.0.json`](../../manifests/evidence/sdk-030-genes-ts-v1.33.0.json).

SDK-031's active Gutenberg/browser package uses the later immutable
`genes-ts` `v1.36.3` release. Its package-local
[`dependency-lock.json`](../../packages/gutenberg/dependency-lock.json) records
the complete SDK-030 baseline -> generalized fix -> reviewed merge -> release
lineage. Keeping both records is intentional: SDK-030 explains the compiler
selection, while SDK-031 proves the exact compiler version used by the strict
WordPress browser fixture.
The complete admission, strict-output, DCE, runtime, and reproducibility proof
is recorded by
[`SDK-031-STRICT-BROWSER-PROFILE`](../../manifests/evidence/sdk-031-strict-browser-profile.json).

SDK-035 closes the representative React differential with the same immutable
Genes 1.36.3 pin. One SDK-owned Haxe/HXX facade is emitted as strict TSX and as
classic JavaScript plus declarations, consumed under strict TypeScript 5.9.3,
and executed through pure functions, React SSR, a mounted hook, and a real
click. The clean replay and all four isolated runtime transcripts match. The
comparison is intentionally corpus-scoped; classic output is neither the
default production lane nor a universal fallback. The complete proof is
[`SDK-035-CLASSIC-GENES-DIFFERENTIAL`](../../manifests/evidence/sdk-035-classic-genes-differential.json).

ADR-013 selects how that compiler enters WordPress projects. Its
machine-readable contract is
[`manifests/browser-build-architecture.json`](../../manifests/browser-build-architecture.json):
strict split ESM TS/TSX is primary, classic ESM JS plus declarations is a
bounded semantic differential, explicit Genes library roots retain public
exports through DCE, and normal WordPress tooling owns externalization and
final asset metadata.

## Evidence boundary

The supported upstream release gate passed with Haxe 4.3.7, Node 20, Yarn 1.22.22, TypeScript 5.5.4/6.0.2/7.0.2, classic JavaScript output, strict TypeScript output, ts2hx, security scans, and real Playwright runs. Node 22 upstream smoke/classic lanes and CodeQL also passed.

Haxe `5.0.0-preview.1` is an explicitly non-blocking upstream experiment. Its job failed on preview macro/library API incompatibilities (`ExprDef`, `tink.OutcomeTools`, and `ClassBuilder` were unavailable). That failure is not represented as supported Haxe 4.3.7 evidence, and this SDK makes no Haxe 5 browser-compiler claim.

This pin resolves the older PRD snapshot discrepancy between a `v1.13.0`-era full-port lock and later `1.32.0` package metadata. Neither historical value is used implicitly.

The compiler release toolchain and generated-project toolchain are separate.
SDK-030's exact local replay used Node 20.19.3 and Yarn 1.22.22. The selected
WordPress project tuple is Node 22.17.0, npm 10.9.2, and TypeScript 5.9.3:
WordPress 7.0's source admits that Node/npm line, embedded Gutenberg selects
TypeScript 5.9.3, and the checksum-locked Node image reports those exact
versions. SDK-031 must still prove the project tuple against the strict
fixture; the ADR is not runtime compatibility evidence.

## Ownership rule

WordPress package maps, handles, profiles, metadata, and build integration belong in this SDK. Generic lowering, TypeScript/JavaScript semantics, module behavior, source maps, declarations, and ts2hx compiler behavior belong in genes-ts.

ADR-014 keeps each Genes/bundler layer in standard Source Map v3, but requires
the SDK package index to authenticate the exact files and layer order. A final
JS-to-Haxe map is admitted only for the exact entry/mode after deliberate
development and minified throws pass; otherwise the supported result is an
explicit JS-to-TS/TSX-to-Haxe two-stage chain. SDK-034 now proves that contract
for its exact Genes 1.36.3/esbuild 0.27.2 fixture in real Chromium, including
the two-stage fallback and production retention. That receipt is not evidence
for webpack or Next.js. `wordpresshx-g2.4` owns the exact official
`@wordpress/scripts` projection, and SDK-113 must admit each future NextJsHx
adapter/entry/mode independently.

If SDK work exposes a generic compiler defect:

1. reduce it to a fixture with no WordPress or SDK dependency;
2. create an isolated worktree from the genes-ts authority repository;
3. implement and test both strict TypeScript and classic JavaScript behavior;
4. run the full upstream release gate and all directly affected lanes;
5. open an upstream PR only after the worktree is clean and regressions are green;
6. update the active package lock only to an immutable merged commit or release
   and record the PR/receipt without rewriting the earlier selection receipt.

No genes-ts change or PR was needed to establish the historical `v1.33.0`
baseline. SDK-031 later exposed a generic `Array<T>` indexed-read issue under
TypeScript's `noUncheckedIndexedAccess`; the fix was reduced without WordPress
symbols, tested across strict TypeScript, classic Genes, standard Haxe, and
supported TypeScript versions, then merged as upstream PR #3. Release builds
consume the resulting immutable release/commit, never the floating sibling
checkout.

SDK-035 found no generic compiler defect. It reuses the released Genes JSX
intent contract and records the upstream `DualJsxMain.hx` fixture only as an
immutable concept reference; no source bytes or sibling checkout enter the
build. The SDK-owned HXX parser disables Genes' second source-markup parser in
both differential profiles, while Genes remains the sole owner of TSX and
classic JavaScript printing.

## Upgrade and rollback

The generic compiler maintainers own upgrades. The immediate recorded rollback is `v1.32.0` at commit `09a17f57ae5645d719d2edbb9c795b40abd8e4f1`, tree `06f5ced331180886047161d8dfaa850ccdc6984a`. Any upgrade or rollback still requires a fresh SDK receipt; the existence of a prior release is not itself compatibility evidence.
