# Provisional third-party review ledger

This is an inventory for qualified review. It is **not** the final notice file
for a release, does not reproduce all required license texts, and is not a
license grant. Exact machine-readable evidence lives in `components.json`.

| Component or group | Current role | Observed declaration/evidence | Current treatment |
|---|---|---|---|
| WordPress 7.0 | exact profile/runtime authority | GPL-2.0-or-later at exact source | derive facts/contracts with provenance; review pending |
| Gutenberg embedded and 23.4.0 | exact editor profile authorities | project GPL statement; post-2021 contribution dual-license statement | keep profiles separate; derived-data review pending |
| `wordpresshx-port` compiler origin | copied/generalized PHP compiler seed | GPL-2.0-or-later exact source grant and file-level provenance | preserve attribution/grant; final repository treatment pending |
| Genes 1.33.0 | generic browser compiler input | exact MIT source license; release archive omits license file | build input; future notice/output audit required |
| Haxe 4.3.7 | compiler and standard-library input | compiler GPL-2.0-or-later; standard library MIT per Haxe Foundation | build provenance plus per-target copied-output audit |
| `tink_hxx` 0.25.1 | compile-time parser | metadata says MIT; exact source LICENSE is Unlicense; archive omits license | unresolved conflict; publication blocked |
| `tink_anon` 0.7.0 | compile-time parser dependency | exact manifest says MIT; exact LICENSE is Unlicense | unresolved conflict; publication blocked |
| Lix 15.12.4 | build package manager | npm metadata says MIT; shipped LICENSE is Unlicense | unresolved conflict; publication blocked |
| `tink_parse` 0.4.1 | compile-time parser dependency | exact manifest says MIT; no source license file found | authoritative license text required |
| `html-entities` 1.0.0, `tink_core` 2.1.1, `helder.set` 0.3.1 | compile-time/transitive dependencies | Haxelib metadata says MIT; inspected archives omit license text | authoritative license texts required before redistribution |
| `tink_macro` 0.23.0 | compile-time parser dependency | MIT manifest and exact MIT license agree | build provenance; review still pending |
| Formatter 1.18.0, Gitleaks 8.30.0 | local/CI build tools | exact/tag MIT license evidence | not bundled; record build provenance |
| Composer 2.10.2 and exact generated-PHP quality graph | build-only formatter, compatibility, security, stubs, and static analysis | exact Composer artifact plus ten-package lock; package metadata declares MIT, LGPL-3.0-or-later, and BSD-3-Clause | ephemeral vendor graph; not bundled in generated plugins; qualified review pending |
| `actions/checkout`, `krdlab/setup-haxe` | hosted CI actions | exact pinned MIT license evidence | not bundled; record build provenance |
| Beads 1.0.4 | issue tooling and managed hook/instruction source | exact pinned MIT license | attribute copied managed sections |
| OCI test images | exact runtime test inputs | digest locks only; layered license inventory not audited here | no redistribution; no aggregate license conclusion |

## Final notice-generation requirements

For every public artifact, generate the notice set from the artifact contents,
not merely this repository-wide ledger. It must include only applicable
components and must carry:

- component name, exact version/commit, upstream source, and artifact digest;
- preserved copyright and attribution statements;
- the full text of every applicable license;
- copied source/runtime/template file provenance;
- an SBOM and deterministic artifact-to-notice binding;
- explicit unresolved status for any component the build cannot classify.

Build-only tools belong in build provenance unless their bytes are copied or
redistributed. Conversely, a compile-time dependency cannot be omitted merely
because it ran at compile time if its implementation bytes appear in the final
artifact.

## Known blocking findings

The authoritative blocking list is `components.json.unresolvedFindings`. The
validator requires every listed finding to block publication. Removing a row,
renaming a discrepancy, or changing a conclusion requires new upstream evidence
and qualified review; silence is not resolution.
