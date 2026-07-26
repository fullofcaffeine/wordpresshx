# ADR-012 independent Oracle rereview 2

- Reviewed commit: `0bc2349f359668180d92f1309a4be207c0c12adf`
- Reviewer: GPT-5.6 / OpenAI / independent Oracle agent
- Immutable packet SHA-256: `9a752664f2cfd97960c91aefafdc74f33483c30fe9be4c7d738cb19c2ae1b410`
- Prompt SHA-256: `c077fea427243916800d026f0d388d9b8984c2e67616d3a0c55c32a75d1e45bb`
- Repository snapshot SHA-256: `0481b9318ba872c62bdfe531bd97e63002e1583096e236a6be454769defe6dc8`
- Final decision: **changes-required**

The second correction pass closes F001, F003, and F005 for the explicitly bounded architecture prototype. F002, F004, F007, F008, and F009 remain closed. F006 remains blocking because mutable public arrays can change the native KSES policy after its content-addressed identity is computed.

## Finding dispositions

### ADR012-F001 — closed (high confidence)

`HxxPositionGuard` now requires resolved namespace state, rejects every non-HTML namespace and namespaced attribute, permits only a closed ordinary-attribute grammar, permits only a closed child-element grammar, rejects void-element children, and retains explicit failures for events, `srcdoc`, `srcset`, style, script, iframe, textarea, and dynamic position names. The negative fixtures cover the previously demonstrated SVG descendant (`use`/`xlink:href`), unknown URL-bearing attribute (`video`/`poster`), unknown child, and void child. This is sufficient for the bounded classifier; it is not evidence that the unfinished production HXX lowerer exists.

Evidence: `fixtures/output-context/src/wordpress/hx/output/prototype/HxxPositionGuard.hx`, the `hxx_*` negative fixtures, and their assertions in `scripts/output-context/test.sh`.

### ADR012-F002 — closed (high confidence)

No regression. One Haxe-generated plan remains byte-identical across Haxe interpreter, Genes/Node, and PHP generation; the React and WordPress probes consume that exact plan and return its SHA-256. The native payloads are no longer independently hard-coded.

Evidence: `fixtures/output-context/test/Main.hx`, both runtime probes, and `scripts/output-context/test.sh`.

### ADR012-F003 — closed (high confidence)

`CompilerMarkup` now owns a private `ResolvedHxxAst`; only the exact generated fragment and sink are allowed to construct/access it. The closed node/attribute enums distinguish text, ordinary attributes, and validated URL attributes. `OutputSinks.markup` lowers that tree, derives its structural digest, and emits the contextual plan. Both PHP and React recursively render the same plan; the PHP renderer applies `esc_html`, `esc_attr`, and `esc_url`, while React uses child/attribute rendering. Adversarial contextual values verify that segment types control lowering. This closes the finding for the bounded generated-fragment prototype, not the unimplemented production compiler.

Evidence: `Output.hx`, `generated/TodoCardMarkup.hx`, `OutputSinks.hx`, `browser.mjs`, `wordpress-probe.php`, and the WordPress assertions in `test-wordpress.sh`.

### ADR012-F004 — closed (high confidence)

No regression. Both JSON terminals execute the typed codec, preserve success versus explicit `EncodingFailure`, and the generated plan plus native probes assert the failure branch.

Evidence: `Output.hx`, `Main.hx`, and both runtime probes.

### ADR012-F005 — closed (high confidence)

Inline and stylesheet CSS now use separate `InlineDeclaration` and `StylesheetDeclaration` enums and separate printers. Each property constructor accepts only its property-specific value type (`CssColor`, `CssDisplay`, or `CssLength`). The new mismatch and cross-context negative fixtures fail compilation. The remaining values are a closed enum/integer algebra without arbitrary string tokens.

Evidence: `Output.hx`, `OutputSinks.hx`, `test-negative/css_property_value_mismatch/Main.hx`, `test-negative/stylesheet_as_inline/Main.hx`, and `scripts/output-context/test.sh`.

### ADR012-F006 — open (blocking, high confidence)

Duplicate tags, attributes, and protocols are normalized, and the happy-path WordPress probe now derives `wp_kses` arguments from the Haxe-generated rule/protocol plan. However, the content-addressed authority is mutable after hashing:

- `CustomKsesPolicy.rules` and `.protocols` are public `Array` values.
- Each public `KsesRule.attributes` is also a mutable `Array`.
- `KsesPolicy.rules` and `.protocols`, reachable through public `KsesHtml.policy`, remain mutable.
- Array copies are shallow and do not recompute or verify `canonicalDocument`/`digest`.

A packet-derived Haxe probe constructed a policy for `a[href]` and `https`, then appended `onmouseover` and `javascript`. It compiled under the same strict settings and produced:

```text
canonical: profile=wp70-release;version=mutation.v1;tags=a[href];protocols=https
runtime attributes: href,onmouseover
runtime protocols: https,javascript
```

The `policyIdentity` remained the SHA-256 of the original canonical document. Because `wordpress-probe.php` builds its `wp_kses` allowlist and protocol list from the mutated arrays, the exact runtime policy is not bound by the identity. The checked happy-path mutation merely creates a second policy before hashing and cannot detect post-hash mutation.

Required correction: retain the canonical policy in an immutable typed representation, expose no mutable arrays from policy or terminal objects, and either derive sink arguments from that immutable representation or recompute and verify the canonical digest immediately before lowering. Add an adversarial post-construction mutation negative/test.

### ADR012-F007 — closed (high confidence)

No regression. Browser and WordPress consume the shared adversarial URL matrix; executable and whitespace-obfuscated schemes are rejected; event attributes fail compilation; and no public raw-rich-HTML browser path is used.

### ADR012-F008 — closed (high confidence)

No regression. Genes remains consistently identified as 1.38.0, with the validator deriving its target prefix from the immutable dependency lock.

### ADR012-F009 — closed (high confidence)

No regression. Terminal retention is accurately stated as repository SDK policy rather than a Haxe linear-type guarantee.

## New findings

None. The post-hash mutability defect is a direct continuation of ADR012-F006.

## Evidence boundary

The packet declares hosted run `30222742845`, job `89847822705`, and implementation commit `68e5effa9d9a07163eafbd08864ccc872f76e0ad`, but contains no immutable hosted log or attestation. Those declarations were not treated as independent proof. Subject hashes recorded by the evidence manifest match the packet files, and no forbidden `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` token appears in the ADR-012 Haxe fixture.

## Final decision

**changes-required**. ADR-012 must not move to accepted status until ADR012-F006 is corrected and independently rereviewed. This decision is limited to the bounded architecture evidence and makes no production-support claim for the unfinished SDK lowerer.
