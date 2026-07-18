# Licensing review status

WordPressHx currently has **no repository-wide license grant**. This directory is
a review packet, not permission to use, copy, publish, or redistribute the
repository. Public Haxelib/npm packages, source releases, promoted downloads,
and WordPress plugin/theme/site ZIPs remain blocked by ADR-020 and SDK-002.

The provisional recommendation is GPL-2.0-or-later for repository-original SDK,
CLI, compiler, documentation, examples, scaffolds, templates, and default
WordPress packages. That recommendation has not been accepted. It requires
contributor-rights confirmation, a named qualified licensing reviewer, product
owner approval, resolution of the recorded upstream discrepancies, final
license texts/notices, and evidence from the exact packed artifacts.

## Review artifacts

- `policy.json` is the closed, machine-readable provisional policy and
  publication state.
- `components.json` inventories repository origins and exact third-party/build
  inputs, including unresolved evidence conflicts.
- `GENERATED_OUTPUT.md` explains the proposed origin-sensitive output model.
- `THIRD_PARTY_NOTICES.md` is the human review ledger. It is not yet a final
  notice bundle.
- `QUALIFIED_REVIEW.md` defines the human review and acceptance record that is
  still missing.
- `docs/adr/020-licensing-and-generated-output.md` records the proposed decision
  and alternatives. Its status must remain `proposed` while review is pending.

Run the audit locally with:

```bash
python3 scripts/licenses/test-license-policy.py
```

The publication assertion intentionally exits with status 3:

```bash
python3 scripts/licenses/check-license-policy.py --publication-gate
```

A zero exit from the ordinary audit means the repository accurately records a
blocked provisional state. It does **not** mean publication is allowed.

## Scope distinctions

The review distinguishes:

- repository-original Haxe, shell, Python, Node/build, documentation, and data;
- generic PHP compiler source adapted from `wordpresshx-port`;
- external compile-time/build tools such as Haxe, Genes, HXX dependencies, Lix,
  Formatter, Gitleaks, GitHub Actions, and Beads;
- profiles and catalogs derived from exact WordPress/Gutenberg sources;
- user-authored input and generated PHP/TS/JS/CSS/JSON/markup;
- emitter boilerplate, templates, runtime or standard-library portions copied
  into generated output;
- final Haxelib/npm/source/plugin/theme/site artifacts, SBOMs, provenance, and
  applicable license texts/notices.

Tool license, source license, and output license are separate questions. A
compiler's license does not by itself classify every emitted byte, while copied
runtime, standard-library, scaffold, or template bytes can retain obligations
from their source. The final artifact manifest must make those origins visible.

## Authoritative background

The packet uses the official [WordPress licensing statement](https://wordpress.org/about/license/),
[WordPress plugin-directory guidelines](https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/),
[WordPress license inclusion guidance](https://developer.wordpress.org/plugins/plugin-basics/including-a-software-license/),
[Haxe Foundation licensing statement](https://haxe.org/foundation/open-source.html),
and [GNU GPL compiler-output guidance](https://www.gnu.org/licenses/gpl-faq.en.html)
as review inputs. Links are evidence, not a substitute for qualified advice
applied to the exact WordPressHx artifacts.

## Change rule

Every new dependency, copied source file, generated runtime/helper, scaffold, or
public manifest requires an inventory update. Missing evidence, metadata/text
conflicts, an unclassified copied byte range, or an absent approval must fail
publication. Never replace an unresolved finding with a guessed SPDX result.
