# Locks and evidence manifests

This directory contains immutable toolchain/upstream locks, architecture locks, evidence receipts, and future release manifests. No placeholder hash may be interpreted as a pin; exact identities are added by the corresponding gate bead.

- `package-topology.json` is the accepted ADR-003 public-artifact, source-module, dependency-direction, and independent-versioning map. Its `not-published` claim and `publicationAuthorized: false` are deliberate; topology acceptance is not a registry release.

- `upstream.lock.json` records resolved cross-project inputs. Its `partial` status means only the listed entries are pinned; omitted upstreams remain unresolved rather than receiving guessed or floating values.
- `evidence/` contains the command, environment, hosted-CI, limitation, and artifact evidence behind a lock entry.

The first resolved external input is genes-ts `v1.33.0`, recorded by `wordpresshx-sdk-030`. The canonical public Git and Beads transport is recorded by `evidence/sdk-004-canonical-repository.json`. The first co-located PHP compiler import is recorded by `evidence/sdk-020-reflaxe-php-bootstrap.json`; it is an internal source receipt, not an external release pin.

`upstream.lock.json` now also includes the exact `wp70-release` source authority. Its detailed source/distribution lock lives under `profiles/wp70-release/`, and receipt `SDK-010-WP70-RELEASE-SOURCE` records direct clean materialization. The recorded capability level is only `inventoried`; runtime and production claims remain `not-tested`.

The exact `gutenberg-forward-23.4` authority is a separate lock entry and profile tree. Receipt `SDK-011-GUTENBERG-FORWARD-23.4` records direct source/release materialization, compile-admission negatives, and final-artifact leak scans. It remains experimental; WordPress 7.0 compatibility is forbidden and runtime/production claims are `not-tested`.

Receipt `SDK-012-PROFILE-SCHEMA` records the closed profile schema, exact minimal fixtures, Haxe profile/capability contracts, compile-fail availability checks, and request-scope separation. It validates how future catalogs are represented; it does not generate the SDK-013 catalogs or advance WordPress/browser/production compatibility.

Receipt `SDK-013-PROFILE-GENERATOR` records the exact-object, read-only catalog generator, its reviewed selection contract, committed catalog/omission/report hashes, double-run equality, known-entry checks, and failed-publication negative. The 33 emitted capabilities are lexical inventories only. Four ambiguous or private candidates are explicit omissions; no typed, runtime, browser, package, or production claim advances.

Receipt `SDK-090-WORDPRESS-HARNESS` records the exact WordPress 7.0 container distribution proof and fresh installed runtime lanes over MySQL 8.4.10 and MariaDB 11.4.5. It advances only the vanilla harness and named environment evidence. SDK behavior, browser compatibility, packaged plugin/theme installation, PHP 7.4 WordPress hosting, and production support remain untested.
