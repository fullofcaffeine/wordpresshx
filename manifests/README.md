# Locks and evidence manifests

This directory contains immutable toolchain/upstream locks, architecture locks, evidence receipts, and future release manifests. No placeholder hash may be interpreted as a pin; exact identities are added by the corresponding gate bead.

- `package-topology.json` is the accepted ADR-003 public-artifact, source-module, dependency-direction, and independent-versioning map. Its `not-published` claim and `publicationAuthorized: false` are deliberate; topology acceptance is not a registry release.
- `php-emission-policy.json` is the accepted ADR-005 semantic file/symbol/edge
  classification, native public PHP ABI, bounded private stock-Haxe lane,
  adapter, HXX, evidence, stop, and pre-G8 migration/removal lock. Its G1
  evidence remains `not-tested`, stock-Haxe output is not guaranteed after
  `1.0`, and publication remains blocked.
- `hxx-architecture.json` is the accepted ADR-011 inline-authoring, parser-selection, generic-PHP/WordPress lowering ownership, safety, density, escape-hatch, and no-runtime lock. SDK-080 resolves its parser closure through `packages/hxx/dependency-lock.json` and proves only the bounded parser-adapter prototype; native lowering remains owned by later evidence beads.
- `browser-build-architecture.json` is the accepted ADR-013 strict TS/TSX
  primary lane, bounded classic Genes differential, exact project
  Node/npm/TypeScript tuple, public export/DCE retention, normal WordPress
  package externalization, and final-asset authority lock. It selects the
  architecture only: SDK-031 through SDK-035 still own strict fixture,
  Gutenberg HXX, bundle/asset parity, source-map, and classic runtime evidence.
- `source-correlation-architecture.json` is the accepted ADR-014 content-bound
  PHP range-map, package source-index, browser composition/two-stage fallback,
  offline trace, logical-path, and debug-retention lock. Its contract fixtures
  are schema-only: SDK-025 and SDK-034 still own native PHP/browser throws,
  trace CLI implementation, official WordPress build correlation, and packaged
  runtime evidence.
- `release-support-policy.json` is the accepted ADR-021 finite-channel, exact-matrix, ownership, deprecation, security, direct-main contribution, release, and immutable-rollback contract. Its empty supported-version list and disabled publication flags are deliberate stable blockers, not placeholders.

- `upstream.lock.json` records resolved cross-project inputs. Its `partial` status means only the listed entries are pinned; omitted upstreams remain unresolved rather than receiving guessed or floating values.
- `toolchain.lock.json` is the closed G0 aggregate projection over the exact
  Haxe, formatter, Genes, co-located PHP compiler, Node/PHP images, Lix, and HXX
  inputs. It also records inactive Composer/root npm graphs explicitly. The
  aggregate does not make a package publishable and later gates must add or
  supersede an entry before admitting a new input.
- `evidence/` contains the command, environment, hosted-CI, limitation, and artifact evidence behind a lock entry.

The first resolved external input is genes-ts `v1.33.0`, recorded by
`wordpresshx-sdk-030`. SDK-031 preserves that selection record and admits the
active `v1.36.3` browser fixture through
`packages/gutenberg/dependency-lock.json`, which proves the baseline, generic
fix, reviewed merge, and release lineage. The canonical public Git and Beads
transport is recorded by `evidence/sdk-004-canonical-repository.json`. The
first co-located PHP compiler import is recorded by
`evidence/sdk-020-reflaxe-php-bootstrap.json`; it is an internal source receipt,
not an external release pin.

Receipt `SDK-031-STRICT-BROWSER-PROFILE` records the generalized upstream
Array-index fix, immutable Genes v1.36.3 admission, strict/classic compiler
differential, public ESM retention, weak-type inventory, ordinary JavaScript
runtime, deterministic generated tree and bundle hashes, and local portability
boundary. It does not claim React/Gutenberg HXX or WordPress browser-runtime
support; those remain SDK-032 and later evidence.

Receipt `SDK-032-REACT-GUTENBERG-HXX` records direct inline-markup returns,
the SDK-owned neutral parser tree, exact-profile Button/Notice and hook
contracts, typed events/refs/context/children/control flow, deterministic
runtime and visual bundles, compile negatives, real React/Gutenberg behavior,
source-map composition, and local Chrome accessibility/visual review. It does
not claim dependency extraction, translations, real WordPress editor loading,
the classic differential, complete G2 closure, publication, or production
support.

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

Receipt `G0-PRODUCT-AUTHORITY-BASELINE` closes the independent product,
repository, exact-profile, toolchain, classification, full-port-separation, and
reference-hash feasibility baseline. It deliberately leaves ADR-020 and SDK-002
open and publication blocked: the PRD assigns qualified licensing review to the
release path, not to permission for experimental G1–G3 work.

Receipt `SDK-090-WORDPRESS-HARNESS` records the exact WordPress 7.0 container distribution proof and fresh installed runtime lanes over MySQL 8.4.10 and MariaDB 11.4.5. It advances only the vanilla harness and named environment evidence. SDK behavior, browser compatibility, packaged plugin/theme installation, PHP 7.4 WordPress hosting, and production support remain untested.

Receipt `SDK-022-WORDPRESS-PUBLIC-PHP-PROFILE` records the first Haxe-authored,
structured public PHP plugin bootstrap: deterministic native headers, direct
access guard, local autoload, and stable namespaced boot class. Exact PHP
7.4/8.4 native callers and real WordPress 7.0 activation over both database
lanes pass. Hook/REST/block adapters, lifecycle behavior, WPCS/static analysis,
independent readability sign-off, publication, and production support remain
separately gated.

Receipt `SDK-080-HXX-PARSER-PROTOTYPE` records the exact `tink_hxx` 0.25.1 artifact and five-transitive closure, parser-only adapter, normal Haxe expression and closed-spread typing, named slots, relative source spans, server/browser semantic parity, target-leakage negatives, density snapshots, and final-artifact no-runtime scans. Its stock PHP/JavaScript carriers are evidence-only; it does not advance native `reflaxe.php`, Genes, WordPress runtime, or production claims.
