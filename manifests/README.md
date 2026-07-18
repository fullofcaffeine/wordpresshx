# Locks and evidence manifests

This directory contains immutable toolchain/upstream locks, architecture locks, evidence receipts, and future release manifests. No placeholder hash may be interpreted as a pin; exact identities are added by the corresponding gate bead.

- `package-topology.json` is the accepted ADR-003 public-artifact, source-module, dependency-direction, and independent-versioning map. Its `not-published` claim and `publicationAuthorized: false` are deliberate; topology acceptance is not a registry release.
- `hxx-architecture.json` is the accepted ADR-011 inline-authoring, parser-selection, generic-PHP/WordPress lowering ownership, safety, density, escape-hatch, and no-runtime lock. SDK-080 resolves its parser closure through `packages/hxx/dependency-lock.json` and proves only the bounded parser-adapter prototype; native lowering remains owned by later evidence beads.
- `release-support-policy.json` is the accepted ADR-021 finite-channel, exact-matrix, ownership, deprecation, security, direct-main contribution, release, and immutable-rollback contract. Its empty supported-version list and disabled publication flags are deliberate stable blockers, not placeholders.

- `upstream.lock.json` records resolved cross-project inputs. Its `partial` status means only the listed entries are pinned; omitted upstreams remain unresolved rather than receiving guessed or floating values.
- `evidence/` contains the command, environment, hosted-CI, limitation, and artifact evidence behind a lock entry.

The first resolved external input is genes-ts `v1.33.0`, recorded by `wordpresshx-sdk-030`. The canonical public Git and Beads transport is recorded by `evidence/sdk-004-canonical-repository.json`. The first co-located PHP compiler import is recorded by `evidence/sdk-020-reflaxe-php-bootstrap.json`; it is an internal source receipt, not an external release pin.

`upstream.lock.json` now also includes the exact `wp70-release` source authority. Its detailed source/distribution lock lives under `profiles/wp70-release/`, and receipt `SDK-010-WP70-RELEASE-SOURCE` records direct clean materialization. The recorded capability level is only `inventoried`; runtime and production claims remain `not-tested`.

The exact `gutenberg-forward-23.4` authority is a separate lock entry and profile tree. Receipt `SDK-011-GUTENBERG-FORWARD-23.4` records direct source/release materialization, compile-admission negatives, and final-artifact leak scans. It remains experimental; WordPress 7.0 compatibility is forbidden and runtime/production claims are `not-tested`.

Receipt `SDK-012-PROFILE-SCHEMA` records the closed profile schema, exact minimal fixtures, Haxe profile/capability contracts, compile-fail availability checks, and request-scope separation. It validates how future catalogs are represented; it does not generate the SDK-013 catalogs or advance WordPress/browser/production compatibility.

Receipt `SDK-013-PROFILE-GENERATOR` records the exact-object, read-only catalog generator, its reviewed selection contract, committed catalog/omission/report hashes, double-run equality, known-entry checks, and failed-publication negative. The 33 emitted capabilities are lexical inventories only. Four ambiguous or private candidates are explicit omissions; no typed, runtime, browser, package, or production claim advances.

Receipt `SDK-014-PROFILE-DIFF` records the read-only exact-catalog comparison tool, its closed content-digested JSON report, human migration diagnostics, reviewed contract payload rules, upstream-versus-correction authority checks, and golden/negative fixtures. Its synthetic target profile is not compatibility evidence; the tool infers no range, rewrites no source, and auto-accepts no breaking change.

Receipt `SDK-003-RELEASE-GOVERNANCE` records the closed policy validator and deterministic issue/security/release/rollback rehearsal. The rehearsal is synthetic: private reporting remains disabled, the backup role remains unassigned, stable publication remains blocked, no registry credential or package is exercised, and no SLA or production-support claim is created.

Receipt `ADR-020-LICENSE-AUDIT-PREPARATION` records the provisional licensing
policy, exact component/origin inventory, generated-output model, human review
packet, deterministic blocked-publication diagnostic, and negative mutations.
It deliberately records no license grant or qualified acceptance; ADR-020 and
SDK-002 remain open and all public publication remains blocked.

Receipt `CI-CHECKOUT-NODE24` records the official `actions/checkout` v7.0.0
release, exact verified commit/tree/license evidence, Node 24 runtime declaration,
all ten immutable workflow pins, and preservation of full Git history only for
the security lane. Its hosted claim is limited to the exact GitHub-hosted
Ubuntu 24.04 workflow run; it creates no SDK or generated-artifact claim.

Receipt `SDK-090-WORDPRESS-HARNESS` records the exact WordPress 7.0 container distribution proof and fresh installed runtime lanes over MySQL 8.4.10 and MariaDB 11.4.5. It advances only the vanilla harness and named environment evidence. SDK behavior, browser compatibility, packaged plugin/theme installation, PHP 7.4 WordPress hosting, and production support remain untested.

Receipt `SDK-080-HXX-PARSER-PROTOTYPE` records the exact `tink_hxx` 0.25.1 artifact and five-transitive closure, parser-only adapter, normal Haxe expression and closed-spread typing, named slots, relative source spans, server/browser semantic parity, target-leakage negatives, density snapshots, and final-artifact no-runtime scans. Its stock PHP/JavaScript carriers are evidence-only; it does not advance native `reflaxe.php`, Genes, WordPress runtime, or production claims.
