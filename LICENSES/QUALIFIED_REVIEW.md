# ADR-020 qualified review packet

## Current record

- Review status: **pending**
- Qualified reviewer: **unassigned**
- Reviewer qualification: **unrecorded**
- Review date: **unrecorded**
- Product-owner approval: **not granted**
- Root license grant: **absent**
- Publication: **blocked**

Codex prepared provenance, inventory, proposed policy, and automated consistency
checks. Codex is not recorded as the qualified licensing reviewer and has not
accepted ADR-020.

## Reviewer scope

The named reviewer must be qualified to evaluate open-source licensing and the
distribution model for the actual artifacts. The review must cover:

1. ownership and contributor rights for repository-original work;
2. compatibility and wording of the candidate GPL-2.0-or-later grants;
3. preservation of the imported `wordpresshx-port` compiler grant and notices;
4. whether generated WordPress/Gutenberg profiles and contract catalogs are
   correctly characterized, attributed, and licensed;
5. the output-origin model, including Haxe/Genes/runtime/standard-library,
   emitter boilerplate, HXX compile-time elimination, scaffolds, and templates;
6. plugin/theme/site, Haxelib, npm, source-archive, and WordPress.org notice and
   source-distribution obligations;
7. every metadata-versus-license-text conflict and missing license text in
   `components.json`;
8. the complete notice set, SBOM, provenance, and license files of exact packed
   release candidates;
9. trademark boundaries and any non-code asset terms;
10. whether different artifact classes need different grants or additional
    exceptions/permissions.

The WordPress project's view that plugins and themes are derivative work, and
the WordPress.org requirement that submitted code/data/images be GPL-compatible,
must be considered for WordPress distribution. Those statements are policy and
upstream positions; this file does not independently decide their application.

## Evidence to review

- `LICENSES/policy.json`
- `LICENSES/components.json`
- `LICENSES/GENERATED_OUTPUT.md`
- `LICENSES/THIRD_PARTY_NOTICES.md`
- `docs/adr/020-licensing-and-generated-output.md`
- `compiler/reflaxe.php/provenance.json`
- `manifests/upstream.lock.json`
- `packages/hxx/dependency-lock.json`
- exact generated catalogs and their source locks/receipts
- the final packed artifacts, manifests, SBOMs, license texts, and notice bundle
  created by SDK-002

## Acceptance record required

Acceptance must update the closed machine-readable policy and record all of:

```text
reviewer name:
qualification/basis:
scope reviewed:
exact repository commit:
exact artifact hashes reviewed:
upstream discrepancy resolutions:
approved SPDX expressions by artifact class:
generated-output conclusion:
required notices/source obligations:
reviewed-at UTC timestamp:
product-owner name and approval timestamp:
ADR status and supersession rule:
```

The validator must reject partial records. A name without qualification, an
approval without an exact commit/artifact set, or an accepted ADR while a
blocking finding remains is invalid.

## Handoff to SDK-002

ADR-020 may be accepted only after the reviewer resolves the policy questions.
SDK-002 then applies the accepted result to real pack manifests, license texts,
notices, SBOMs, source archives, generated packages, and publication gates. No
registry credentials or public release should be exercised merely to prepare
the legal review.
