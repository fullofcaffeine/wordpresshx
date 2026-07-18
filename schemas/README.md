# Schemas

Reserved for versioned project, profile, semantic-plan, generated-ownership, adoption, and evidence schemas after their ADRs are accepted. A schema must define migration/correction behavior and may not turn inventory into a support claim.

[`profile.schema.json`](profile.schema.json) is the closed SDK-012 exact-profile catalog schema. Schema version, catalog revision, upstream identities, and content digest are independent fields. All object shapes reject unknown fields; API classifications, evidence states, administrative results, provenance, exact pins, continuous evidence stages, reviewed diffable contracts, and additive corrections are validated by `scripts/profiles/validate-profile-schema.py`. A reviewed contract is legal only at `typed` evidence or later. Signature authority excludes heuristic inference, metadata facts contain canonical JSON, and contract receipts must be indexed.

[`profile-diff.schema.json`](profile-diff.schema.json) is the closed SDK-014 report schema. It separates upstream-profile changes from direct SDK catalog corrections, records exact endpoints and before/after values, carries conservative impact and migration actions, and fixes policy fields to exact-catalog advisory output with no inferred range or source rewrite.

[`semantic-plan.schema.json`](semantic-plan.schema.json) is the accepted ADR-006
immutable build-plan envelope. Its one delegated `payload` object is valid only
after the exact content-addressed schema named by the node registry passes; the
first closed examples live under `semantic-nodes/`. Stable node/projection IDs,
exact-profile capabilities, content-bound source spans, acyclic dependencies,
and canonical plan digests are mandatory before emission.

[`semantic-emission.schema.json`](semantic-emission.schema.json) is the matching
staged-emitter result. It binds a validated plan and exact emitter to complete
projection coverage, artifact bytes, owner/source nodes, source spans, and
required validators. It grants no permission to write live files; ADR-007 owns
publication and recovery.

[`semantic-collector-config.schema.json`](semantic-collector-config.schema.json)
closes the generated SDK-040 macro bootstrap: exact project/profile/toolchain,
resource roots, public build environment allowlist, and content-addressed node
schemas. [`semantic-collector-inputs.schema.json`](semantic-collector-inputs.schema.json)
is the collector's canonical effective-input sidecar. It records only logical
paths and public environment value digests, binds every exact tool identity,
and links its fingerprint to the semantic plan without creating a circular
digest. SDK-043 will merge this bounded graph with ADR-016's complete CLI graph.

[`generated-files.schema.json`](generated-files.schema.json) is the accepted
ADR-007 exact generated-file authority. It binds canonical manifest bytes,
portable output roots, exact path/hash/size ownership, plan/emission/profile
inputs, source provenance, and staged validator results.

[`ownership-transaction-journal.schema.json`](ownership-transaction-journal.schema.json)
binds exact prior/next manifest states and sorted create/replace/remove/
relinquish operations to private stage and backup paths. It enables hash-inferred
finalize or rollback after interruption; it is not the SDK-041 production
transaction implementation.

[`project.schema.json`](project.schema.json) and
[`project-lock.schema.json`](project-lock.schema.json) are the accepted ADR-016
bootstrap and exact generated project-lock contracts. The bootstrap is limited
to pre-Haxe discovery; typed site modules and development services remain Haxe
semantic-plan authority. The lock binds exact profile, SDK/CLI, compiler,
runtime, package-manager, build-tool, manifest, and lockfile identities.

[`effective-inputs.schema.json`](effective-inputs.schema.json) closes the
content-addressed source/discovery/tool/environment graph shared by bounded
builds and watch mode. [`cli-event.schema.json`](cli-event.schema.json) closes
the canonical JSONL command/stage/diagnostic/service event vocabulary. Their
contract fixture proves deterministic state transitions only; SDK-043/044
still own the production CLI, watcher, server, and process implementation.

[`php-haxe-map.schema.json`](php-haxe-map.schema.json) and
[`source-correlation-index.schema.json`](source-correlation-index.schema.json)
are the accepted ADR-014 contracts. The PHP format binds half-open UTF-8 byte
ranges and redundant one-based-line/zero-based-byte-column coordinates to exact
generated and source content. It distinguishes Haxe, admitted native, and
compiler-generated origins and uses unique emitter-owned trace anchors for
line-only PHP frames. The package index binds PHP maps and standard Source Map
v3 browser layers to complete file identities, supports proven composition,
explicit two-stage resolution, and unavailable outcomes, and carries debug
retention policy. The schemas and contract fixture do not claim SDK-025/034
runtime completion by themselves.

SDK-025 now implements and independently validates the PHP side: deterministic
map/index emission, deliberate public/private WordPress failures, offline
Haxe/Genes CLI lookup, stable native-plus-correlated output, debug-companion
retention, tamper/privacy negatives, exact PHP 7.4/8.4 execution, and clean
WordPress 7.0 MySQL/MariaDB runtime lanes. The bounded receipt is
[`SDK-025-PHP-SOURCE-CORRELATION`](../manifests/evidence/sdk-025-php-source-correlation.json).
SDK-034 still owns browser stack parsing, composed/two-stage lookup, and
development/minified throw evidence.
