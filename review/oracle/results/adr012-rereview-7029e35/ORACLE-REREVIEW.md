# ADR-012 independent Oracle rereview

- Reviewed commit: `7029e35764a09e19cda12c4e17d0fc2a6cdd873d`
- Reviewer: GPT-5.6 / OpenAI / independent Oracle agent
- Immutable packet: `c39ed85e6b293357cc74c82b835a8fd9650fd21c2b91231a42c2229e93dc5676`
- Prompt: `af40ea56a61a5088f7343c3bcfc5e52509fc4be0a82696143cc7b1c80cdd9d3b`
- Repository snapshot: `958536fc5746b10fc3b29383c0b66f4a63d8b3f8c99efc30daec94b26eda285e`
- Decision: **changes-required**

The packet shows meaningful corrections: one Haxe-generated plan is consumed by the PHP, WordPress, Genes, and React probes; JSON codecs execute and retain explicit failure; the URL matrix is shared; Genes is consistently identified as 1.38.0; and the retention claim is now accurately bounded as SDK policy. Acceptance is nevertheless blocked because three prior security findings remain open in the executable prototype and one remains only partially closed.

## Prior-finding dispositions

### ADR012-F001 — open (blocking, high confidence)

The manifest enumerates 15 HXX position classes and negative fixtures cover the named cases, but the classifier is not a closed position graph. `HxxPositionGuard.attribute` receives only the current tag and attribute strings, not namespace/ancestor or parsed-position state. It rejects attributes when the tag itself is exactly `svg` or `math`, yet a descendant such as `use` with `xlink:href` falls through as an ordinary attribute. Other URL-bearing positions outside the four hard-coded names also fall through. The validator tests manifest inventory, not equivalence between that inventory and classifier behavior. Evidence: `fixtures/output-context/src/wordpress/hx/output/prototype/HxxPositionGuard.hx`, `scripts/output-context/validate-architecture.py`, and the negative-fixture list in `scripts/output-context/test.sh`.

Required correction: classify positions from the resolved HXX AST, including namespace/ancestor state, and prove every admitted attribute/child category maps to a terminal while unknown or nested-grammar positions fail closed.

### ADR012-F002 — closed (high confidence)

`Main.hx` emits one deterministic runtime plan; the PHP and React probes require that plan, consume its values, and return its SHA-256; the gates compare Haxe interpreter, Genes/Node, and PHP plan bytes. This closes the prior independence/hard-coded-payload defect for the bounded prototype. Evidence: `fixtures/output-context/test/Main.hx`, both files under `fixtures/output-context/runtime/`, and `scripts/output-context/test.sh`.

### ADR012-F003 — open (blocking, high confidence)

The public factory is gone and construction is narrowed to `TodoCardMarkup`, but the represented value is still only four forge-resistant metadata fields. No resolved or typed HXX AST is stored or lowered, despite the architecture requiring `ResolvedHxxAst->CompilerMarkup` and provenance including a typed AST. `TodoCardMarkup` is a hand-authored fixture stand-in whose public `create()` returns fixed metadata; `OutputSinks.markup` merely copies that metadata into the JSON plan. Thus the evidence proves nominal constructor restriction, not compiler ownership of typed markup or contextual segment lowering. Evidence: `fixtures/output-context/src/wordpress/hx/output/generated/TodoCardMarkup.hx`, `Output.hx`, and `OutputSinks.hx`; compare `manifests/output-context-architecture.json` trust-constructor and allowed-edge claims.

Required correction: make an actual resolved typed AST (or a content-addressed generated representation of it) part of compiler-owned provenance and demonstrate lowering of its contextual segments, with application code unable to manufacture the authority.

### ADR012-F004 — closed (high confidence)

Both JSON terminals invoke `codec.encode(value)`, preserve `EncodedJson` versus `EncodingFailure`, and the generated plan plus native probes assert the explicit failure path. Evidence: `Output.hx`, `fixtures/output-context/test/Main.hx`, and both runtime probes.

### ADR012-F005 — open (blocking, high confidence)

Arbitrary string tokens were removed and inline/stylesheet wrappers are distinct, but CSS values are not property-specific: `CssDeclaration(property:CssProperty, value:CssValue)` permits nonsensical combinations such as `Color + Pixels(16)` or `Gap + Keyword(None)`. Both contexts share the same declaration AST and `printDeclarations`/`valueName` path, contrary to the receipt's claim of distinct typed ASTs and closed property/value printers. The gate has only a raw-string negative and no illegal property/value compile negatives. Evidence: `Output.hx`, `OutputSinks.hx`, `test-negative/css_from_string/Main.hx`, and `scripts/output-context/test.sh`.

Required correction: encode admissible value grammar in each property type/constructor, add compile-negative mismatched property/value cases, and separately prove inline-style and stylesheet lowering rules.

### ADR012-F006 — open (blocking, high confidence)

The Haxe policy now computes a canonical-document digest, but the WordPress sink does not execute that document. It hard-codes a different allowlist: the plan declares `a[href,title]`, while `wordpress-probe.php` calls `wp_kses` with only `a[href]`. The digest is checked as metadata and then ignored when constructing the runtime policy. Duplicate tags/attributes are also not canonicalized away, so semantically equivalent policies can receive different identities. Evidence: `CustomKsesPolicy.create` in `Output.hx` and the custom-policy block in `fixtures/output-context/runtime/wordpress-probe.php`.

Required correction: derive the exact runtime allowlist/protocol arguments from a typed, canonical policy representation, reject or normalize duplicates, and test allowlist/protocol mutations against actual `wp_kses` behavior.

### ADR012-F007 — closed (high confidence)

The generated plan carries one URL validation matrix used by both browser and WordPress probes; it includes mixed-case HTTPS and hostile scheme/whitespace/protocol-relative/data inputs. Event attributes have a source-positioned compile-negative, and the browser probe prohibits unsafe rich-HTML insertion. This closes the concrete prior evidence gap for the bounded admitted URL grammar. Evidence: `Output.validateUrl`, `Main.urlMatrix`, `browser.mjs`, `wordpress-probe.php`, and the HXX event negative.

### ADR012-F008 — closed (high confidence)

The packet consistently records Genes 1.38.0, and the validator derives the expected target prefix from the dependency lock rather than preserving the prior 1.36.3 prose identity. Evidence: ADR prose, both manifests, and `validate-architecture.py`.

### ADR012-F009 — closed (high confidence)

The ADR and manifest now characterize opacity/non-retention as an enforceable repository SDK API policy and explicitly state that Haxe does not provide linear-type enforcement. This is the accurate bounded claim. Evidence: ADR lines describing terminal retention and `authority.terminalRetentionPolicy`.

## New findings

None. The remaining defects are direct continuations of ADR012-F001, F003, F005, and F006.

## Evidence boundary

The packet contains declarations of hosted run `30221651100`, job `89845003958`, and implementation commit `60e0516db0b1542e7eeba9da02254e115b1abaab`, but no immutable hosted log or attestation. Those declarations were not independently treated as proof. This does not change the decision because the blocking findings are visible in the reviewed source snapshot.

## Final decision

**changes-required**. ADR-012 must not move to accepted status until ADR012-F001, ADR012-F003, ADR012-F005, and ADR012-F006 are corrected and independently rereviewed.
