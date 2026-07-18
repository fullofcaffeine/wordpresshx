# ADR-020: Licensing and generated output

- Status: proposed
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product owner; approval pending), qualified licensing reviewer (unassigned), Codex (provenance and policy preparation only; not the qualified reviewer)
- Bead: `wordpresshx-adr-020`
- Profiles/layers: repository source, SDK/CLI/compiler, HXX and Genes toolchains, derived profile catalogs, generated application output, examples/scaffolds/templates, WordPress packages, notices, and publication
- Supersedes: provisional no-license placeholder only after acceptance
- Superseded by: none

## Context

WordPressHx intends to publish Haxe source packages, compilers and build tooling,
generated PHP/TS/JS/CSS/JSON/markup, examples and scaffolds, derived exact-profile
contracts, and ordinary WordPress plugin/theme/site artifacts. Those classes do
not necessarily have the same origin or distribution obligations.

The repository currently has no root license grant. Its generic PHP compiler has
documented GPL-2.0-or-later provenance from `wordpresshx-port`. WordPress 7.0 and
the two exact Gutenberg authorities are GPL-governed upstream sources from which
the profile generator selects facts and identifiers. Genes, Haxe, HXX parser
dependencies, build tools, CI actions, and Beads add separate evidence and
possible notice boundaries.

The component audit found unresolved evidence: exact `tink_hxx` and `tink_anon`
manifests declare MIT while their exact source LICENSE files contain the
Unlicense; the Lix 15.12.4 npm metadata declares MIT while its shipped LICENSE is
the Unlicense; several Haxelib archives declare MIT but omit a license text; and
`tink_parse` has MIT metadata but no standalone source license file at the exact
commit inspected. Generated runtime/standard-library/boilerplate bytes and the
legal treatment of derived catalogs have not yet been closed.

Automated checks can prove this inventory remains internally consistent. They
cannot supply contributor rights, interpret the law for the final artifacts, or
act as the required qualified reviewer.

## Proposed decision

This section is a candidate for qualified review, not an accepted grant.

1. License repository-original public SDK, CLI, generic compiler changes,
   documentation, examples, scaffolds, templates, and default WordPress packages
   under GPL-2.0-or-later, preserving all compatible third-party grants and
   notices. Use the same candidate for derived WordPress/Gutenberg catalogs with
   exact provenance, subject to a specific review of their copyright and
   database/contract characterization.
2. Do not claim ownership of user-authored input or automatically relicense all
   compiler output. Classify final bytes by origin: user input, original emitter
   boilerplate, toolchain runtime/standard-library, and third-party/upstream
   derived material.
3. Treat substantial copied runtime, standard-library, template, scaffold,
   helper, or boilerplate portions according to their exact source licenses and
   notices. HXX syntax is intended to disappear at compile time; compile-time
   status does not excuse copied implementation bytes if any reach output.
4. Generate an artifact-specific origin manifest, SBOM, provenance record, full
   applicable license texts, and third-party notices from the exact packed bytes.
   A repository-wide dependency list is insufficient.
5. Fail publication on unknown origins, missing evidence, metadata/text
   conflicts, unreviewed new dependencies, or absent human approvals. Raw
   metadata overrides cannot manufacture a license conclusion.
6. Keep all registry publication, promoted downloads, WordPress.org submissions,
   and release archives blocked until a named qualified reviewer and the product
   owner approve the exact policy and SDK-002 proves its application to packed
   artifacts.

No root `LICENSE` is added by this proposed ADR. Acceptance must add the reviewed
grant and complete notices together so repository metadata cannot imply a
decision that has not occurred.

## Rationale

GPL-2.0-or-later is the conservative candidate because it aligns with WordPress,
the imported compiler source, and the intended default plugin/theme/site
distribution while avoiding a misleading permissive umbrella over mixed-origin
artifacts. Origin-sensitive output guidance preserves user authorship and keeps
copied compiler/runtime material visible. Exact artifact-derived notices make the
policy testable rather than relying on prose or dependency-manager metadata.

The official WordPress license statement identifies WordPress as GPL version 2
or later and states the project's position that plugins and themes are
derivative. WordPress.org's plugin guidelines require submitted code, data, and
images to be GPL-compatible. The Haxe Foundation separately identifies compiler
and standard-library licenses. GNU GPL guidance says output is generally governed
by its input, except that substantial copied program text may bring the program's
license into the output. Qualified review must apply those inputs to the actual
WordPressHx distribution.

## Alternatives considered

### MIT for all repository-original work

This would be familiar for SDK consumption and align with many Haxe/build tools,
but it would not resolve GPL compatibility, the imported compiler provenance,
derived WordPress/Gutenberg material, or copied-output obligations. A single MIT
label could falsely imply that all distributed bytes are permissively licensed.

### GPL-3.0-or-later for the whole repository

Several sibling Haxe compiler projects use GPLv3, and it offers a strong copyleft
baseline. It is not the conservative default here because WordPress and the
imported compiler identify GPL-2.0-or-later, and WordPress package compatibility
must be evaluated explicitly. A qualified reviewer may still recommend a
different compatible expression by artifact class.

### Permissive SDK with a separately GPL compiler and WordPress packages

This could reduce obligations for interface-only consumers, but it creates more
boundaries, notice rules, package manifests, and contributor intent questions.
It remains a credible option if qualified review demonstrates clear separability
and maintenance value. It must not be inferred merely from directory layout.

### Defer all licensing work until the first release candidate

This avoids premature conclusions but lets incompatible dependencies, copied
runtime code, and derived-data assumptions accumulate. The chosen process instead
builds a provisional fail-closed inventory now while deferring the legal grant
and publication decision to qualified review of real artifacts.

## Consequences

- No public license or publication authorization exists while this ADR is
  proposed.
- New dependencies and copied/generated support code require inventory entries
  and origin evidence before merge.
- Emitters and packagers must expose byte origins instead of hiding them behind
  one generated-file label.
- The repository carries more evidence and notice-generation work, but release
  claims become reproducible and auditable.
- Upstream licensing discrepancies can block publication even when affected
  tools are currently build-only; qualified review may narrow that blocker once
  distribution boundaries are proven.
- SDK-002 must implement artifact-specific license/notice/SBOM generation and
  consumer-package verification after the decision is accepted.

## Evidence and commands

Primary audit inputs and exact observations are recorded in:

- `LICENSES/policy.json`
- `LICENSES/components.json`
- `LICENSES/GENERATED_OUTPUT.md`
- `LICENSES/THIRD_PARTY_NOTICES.md`
- `LICENSES/QUALIFIED_REVIEW.md`
- `compiler/reflaxe.php/provenance.json`
- `manifests/upstream.lock.json`
- `packages/hxx/dependency-lock.json`

Validation commands:

```bash
python3 scripts/licenses/test-license-policy.py
python3 scripts/licenses/check-license-policy.py --publication-gate
```

The first command must pass while proving the second exits 3 with the committed
blocked-publication message. A green audit means the block is truthful; it is not
ADR acceptance.

## Migration, rollback, and supersession

Before acceptance, rollback is deletion of this proposal and its provisional
machine-readable artifacts; the pre-existing state remains no license grant and
no publication. After acceptance, changes to a grant, output rule, component
conclusion, or notice obligation require a superseding ADR, qualified review,
owner approval, new exact artifact receipts, and migration guidance. Published
artifact licenses are immutable for those bytes.

## Follow-up beads

- `wordpresshx-adr-020`: remains open until qualified review and owner approval.
- `wordpresshx-sdk-002`: applies the accepted decision to exact packages,
  notices, SBOMs, provenance, generated-output manifests, and publication gates.
