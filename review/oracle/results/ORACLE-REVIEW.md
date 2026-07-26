# WordPressHx independent Oracle review

## Outcome

**Overall decision: CHANGES REQUIRED.**

| Review surface | Decision | Boundary |
|---|---|---|
| G1 generated PHP readability/debuggability | **ACCEPTED** | The exact packet is readable native PHP and its representative native failures correlate to Haxe without replacing native frames. This is narrow evidence only. |
| ADR-012 output-context safety | **CHANGES REQUIRED** | Strong nominal direction, but typed authority does not yet drive real lowerers and the HXX/JSON/CSS/KSES claims are not closed. |
| ADR-015 interop/adoption | **CHANGES REQUIRED** | Good native-owner and precise-or-omitted policy, but the fixture is not source-derived, guesses types, and permits forged capability premises. |
| ADR-020 licensing/generated output | **CHANGES REQUIRED** | The fail-closed policy is appropriate; publication remains blocked and the supplied bundle cannot reproduce its own audit. |
| Publication authorization | **NO** | No root grant, contributor-rights conclusion, complete artifact inventory, or qualified approval exists. |
| Production-support claim | **NO** | Receipts remain bounded evidence and the repository explicitly records pre-feasibility/non-production status. |

**Reviewer identity**

- Reviewer: `Oracle`
- Review context: `oracle-agent`
- Provider/model: `OpenAI` / `GPT-5.6`
- Review date: `2026-07-26`
- Prompt SHA-256: `ed22561d3393e340c00548d4c3ffc15e4517c1fe83329ea773b0638bee7bb559`
- Repository snapshot SHA-256: `c7182305f8e3b51a8ff59e2cd85fd8be753121673fbc80b856c77747a17bdba3`
- Recorded repository commit: `145390ec66ed9f0bec61fa834fa8d6713369f6d4` (snapshot says it includes the pending Oracle-governance working diff)
- References SHA-256: `1132cfa6672232b0737110e14d874de06adec67d90b0e0989e7a091bfb8a40ea`; references are design inputs, not WordPressHx authority

Oracle did not implement the reviewed work, contribute to the recorded commit, or prepare the evidence bundle. The assigned senior WordPress/PHP, Haxe compiler, Gutenberg/React, application-security, and licensing-risk perspectives are applied without claiming human credentials or legal authority.

The central conclusion is consistent across the three proposed ADRs: **WordPressHx is strongest when it binds immutable artifacts and weakest when a validator authenticates a checked-in claim without re-deriving the claimed semantics from source or runtime authority.** Cryptographic self-consistency is necessary, but it is not a substitute for source derivation, trusted observation, or an artifact-specific distribution decision.

## Blocking findings

### ADR012-F001 — The HXX position graph is not closed for every security-sensitive HTML position.

**Severity:** `blocking-high`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `manifests/output-context-architecture.json`; `scripts/output-context/test.sh`; `fixtures/output-context/runtime/browser.mjs`

**Observed facts**

- The ADR and architecture route only href, src, action, and formaction through the URL terminal; ordinary attributes accept String or a typed attribute value.
- No supplied compile-negative or runtime vector covers srcdoc, srcset, SVG URL-bearing attributes, raw-text elements, style-element content, or an otherwise unclassified security-sensitive attribute.
- The runtime browser proof exercises an ordinary safe href and does not exercise a nested-document or URL-list grammar.

**Inference:** Attribute escaping preserves the outer HTML attribute grammar but does not establish the policy of a nested grammar such as HTML in srcdoc or a URL list in srcset.

**Practical consequence:** A future lowerer can follow the documented table, type-check, and still admit XSS or context-confusion through an unclassified position.

**Required remediation / acceptance rationale:** Publish a closed element/attribute context table; reject every unclassified nested-document, raw-text, URL-list, SVG, event, style, and script position by default; add source-positioned negatives and native/browser vectors for each admitted exception.

### ADR012-F002 — The typed terminal prototype is disconnected from the PHP and React sinks that are presented as runtime evidence.

**Severity:** `blocking-high`
**Affected paths:** `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx`; `fixtures/output-context/test/Main.hx`; `fixtures/output-context/runtime/wordpress-probe.php`; `fixtures/output-context/runtime/browser.mjs`; `manifests/output-context-architecture.json`

**Observed facts**

- Every OutputSinks method ignores the terminal payload and returns a descriptor string such as server=esc_html or server=wp_json_encode-with-failure.
- The Haxe test compares those descriptors across interpreter, Genes/Node, and stock Haxe PHP output.
- The WordPress and React probes independently hard-code payloads and native calls rather than consuming bytes or values lowered from the Haxe terminal objects.

**Inference:** The packet proves nominal type separation adjacent to handwritten native escaping, not that the typed context selected in Haxe controls the emitted native sink.

**Practical consequence:** An implementation could route the wrong terminal to a sink, drop the codec/policy, or emit different bytes while the current transcript and native probes continue to pass.

**Required remediation / acceptance rationale:** Implement executable terminal lowerers/printers and generate the PHP/React fixture inputs from the Haxe terminal plans. Compare the generated bytes and native behavior under adversarial vectors.

### ADR012-F003 — CompilerMarkup can be minted from a caller-provided string rather than a compiler-resolved typed AST and source span.

**Severity:** `blocking-high`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `fixtures/output-context/test/Main.hx`; `manifests/output-context-architecture.json`

**Observed facts**

- The ADR says the compiler creates CompilerMarkup only after resolving and typing HXX while retaining its source span.
- Output.resolvedHxxFragment(fragmentId:String) is a public method and constructs CompilerMarkup from an arbitrary identity string.
- The fixture calls that public method directly; no typed HXX AST, source span, macro-only entry point, or position resolver participates.

**Inference:** A private constructor does not establish compiler-only authority when a public factory accepts caller-controlled evidence.

**Practical consequence:** Application code can manufacture the same nominal authority that the ADR reserves for a resolved compiler path, and the current tests cannot detect incorrect HXX position inference.

**Required remediation / acceptance rationale:** Move construction behind a compiler/macro-internal API that accepts the resolved typed AST plus source provenance; execute real child, attribute, URL, textarea, style, rich-content, script-data, and event position fixtures with exact diagnostics.

### ADR012-F004 — The JSON codec and encoding-failure contract are declared but not implemented or exercised.

**Severity:** `blocking-high`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx`; `fixtures/output-context/runtime/wordpress-probe.php`; `scripts/output-context/test.sh`

**Observed facts**

- OutputCodec<T> exposes only schemaId(); JsonDocument and HtmlScriptData retain the domain value but not an encoder or encoded result.
- The Haxe sinks emit descriptor text and never invoke a codec.
- The WordPress probe calls wp_json_encode without a === false branch and does not supply invalid UTF-8, recursion, depth, or unsupported-value failures; the final json_encode is also unchecked.

**Inference:** The exact ADR-009 codec authority and explicit failure semantics can be omitted without failing current evidence.

**Practical consequence:** Encoding failure can silently become false, empty output, or a malformed response/script fragment while the architecture validator still reports success.

**Required remediation / acceptance rationale:** Carry an executable ContractCodec<T> or an explicit encoded Result through the terminal, model encoding errors, and test success plus invalid UTF-8, recursion/depth, and unsupported-value failures on PHP and browser paths.

### ADR012-F005 — One CSS terminal conflates inline-style and stylesheet grammars and admits arbitrary token strings without a printer proof.

**Severity:** `blocking-high`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `manifests/output-context-architecture.json`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx`

**Observed facts**

- The architecture lists both style-attribute and generated-stylesheet-declaration as sinks for CssDeclarations while naming one server lowering: typed printer followed by esc_attr.
- esc_attr is an outer HTML attribute operation, not a stylesheet escaping operation.
- CssValue.Token(name:String) accepts arbitrary strings; the fixture has no CSS printer, property/value compatibility rules, URL policy, or native sink.

**Inference:** The current nominal wrapper does not make the CSS grammar closed, and the same bytes cannot be safely finalized identically for style attributes and stylesheet assets.

**Practical consequence:** Future expansion can admit delimiters, URL/expression forms, invalid property/value pairs, or HTML-closing sequences while retaining the CssDeclarations brand.

**Required remediation / acceptance rationale:** Split inline-style values from stylesheet rules/assets; use property-specific validated value algebras and separate printers; withhold style-element output until modeled; test delimiters, URLs, control characters, and HTML-closing payloads at actual sinks.

### ADR012-F006 — Content-addressed custom KSES policy authority exists only in prose and a handwritten probe.

**Severity:** `blocking-high`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `manifests/output-context-architecture.json`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `fixtures/output-context/runtime/wordpress-probe.php`; `manifests/evidence/adr-012-output-context-safety.json`

**Observed facts**

- The ADR requires a custom policy identity to bind the complete tag/attribute allowlist and explicit protocol set by digest.
- The Haxe prototype publishes only postContent and dataHtml native-policy factories.
- The custom wp_kses call is hard-coded in the PHP probe and is not connected to a typed custom-policy constructor, canonicalization algorithm, digest, or branded result.
- The evidence receipt itself says a public custom-policy type constructor is not implemented.

**Inference:** Native-policy branding is demonstrated, but the stronger custom-policy authority can be claimed without executable construction or identity checks.

**Practical consequence:** Two different allowlists or protocol sets can accidentally share an identity, or an implementation can hash incomplete material, without the current gate detecting it.

**Required remediation / acceptance rationale:** Define a canonical policy document and digest over tags, attributes, protocols, profile, and version; construct a distinct branded terminal from it; add mutation and native KSES vectors showing identity changes for every policy change.

### ADR015-F001 — The review/loss report inventories symbols that do not exist in any supplied provider input.

**Severity:** `blocking-critical`
**Affected paths:** `fixtures/adoption-contract/inputs/index.d.ts`; `fixtures/adoption-contract/inputs/provider-stubs.php`; `fixtures/adoption-contract/inputs/plugin.php`; `fixtures/adoption-contract/contract/acme-calendar.review.json`; `scripts/adoption/validate-architecture.py`

**Observed facts**

- The TypeScript input contains CalendarBadgeProps, formatCalendarLabel, and CalendarBadge; the PHP stubs contain Event::title and list_events; plugin.php contains only fixture plugin metadata/sentinel content.
- The review report nevertheless claims omissions for CalendarRegistry, Event::__call, conditional_helper, and mutate_all and reports seven discovered symbols.
- validate_review checks sorting, counts, source-input IDs, and conflict precedence but never parses the provider inputs to prove that an included, omitted, or conflicting symbol exists there.

**Inference:** The validator authenticates a self-consistent narrative, not a source-derived loss report.

**Practical consequence:** Arbitrary fabricated omissions and discovery counts can pass, so “precise-or-omitted” and loss visibility are not trustworthy evidence.

**Required remediation / acceptance rationale:** Implement source parsers that derive a candidate symbol inventory; bind every admitted, omitted, and conflicting symbol to an exact input, byte/source span, and signature digest; make the validator re-derive and compare the inventory.

### ADR015-F002 — Admitted signatures manufacture precision not present in the authoritative source declarations.

**Severity:** `blocking-critical`
**Affected paths:** `fixtures/adoption-contract/inputs/index.d.ts`; `fixtures/adoption-contract/inputs/provider-stubs.php`; `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/AcmeCalendar.hx`; `docs/adr/015-interop-and-adoption-contract-format.md`

**Observed facts**

- TypeScript number becomes int32 for count and formatCalendarLabel.
- CalendarBadge returns object in the declaration but ReactElement in the contract.
- PHP int is represented as int32 even though PHP integer width follows the target platform and the supplied stub gives no 32-bit refinement.
- The ADR explicitly forbids guessed types and requires one complete authoritative binding.

**Inference:** The generated surface is narrower and more specific than its strongest authority.

**Practical consequence:** Valid provider behavior can be rejected and invented assumptions can be accepted as compile-time truth, producing runtime failure behind a precise-looking facade.

**Required remediation / acceptance rationale:** Use exact target ABI types such as JavaScript number and PHP int, retain object/opaque where that is all the source says, or omit the member until an authoritative curated declaration supplies the stronger type. Add mutations for these exact refinements.

### ADR015-F003 — No executable generator proves static no-execution, deterministic derivation, or precise-or-omitted output.

**Severity:** `blocking-high`
**Affected paths:** `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/contract/acme-calendar.review.json`; `fixtures/adoption-contract/inputs/generator.txt`; `scripts/adoption/validate-architecture.py`; `scripts/adoption/test.sh`

**Observed facts**

- The contract, capability, and review JSON are checked in before the test runs.
- generator.txt is a descriptor rather than a program that parses inputs and writes the records.
- The validator hashes inputs and validates record relationships but does not generate records from them.
- The poison/no-execution sentinel protects validation and Haxe compilation, not a provider-inspection generator that does not exist.

**Inference:** The fixture can prove that committed records were not executed during validation, but not that generation is deterministic, source-derived, or non-executing.

**Practical consequence:** A future generator can execute provider code, splice fields, or emit stale/fabricated records without this proof catching the behavior.

**Required remediation / acceptance rationale:** Implement a fixture generator that writes all three documents and the facade into a private stage from the exact inputs; run the poison sentinel around generation; compare canonical bytes on cold/warm runs and after independent input mutations.

### ADR015-F004 — Capability observations and scope identities are publicly forgeable and do not model target lifecycles.

**Severity:** `blocking-high`
**Affected paths:** `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/Adoption.hx`; `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/AcmeCalendar.hx`; `fixtures/adoption-contract/contract/acme-calendar.capability.json`; `fixtures/adoption-contract/test-negative/cross_request_scope/Main.hx`; `fixtures/adoption-contract/test-negative/direct_token_construction/Main.hx`

**Observed facts**

- Adoption.observeExact is public and accepts provider ID, version, artifact digest, and binding names directly from application code.
- Adoption.beginRequest is public and accepts a caller-provided identity string.
- The browser-module and PHP-request capabilities both use RequestScope; the cross-scope negative uses different phantom marker classes rather than two runtime instances of the same nominal scope.
- The token constructor is private, but public factories mint the token from caller-controlled premises.

**Inference:** Constructor privacy is not trusted observation. The phantom type and string identity do not create a runtime-owned, generative request/process/module capability.

**Practical consequence:** Application code can manufacture apparent availability or reproduce authority under the wrong lifecycle, leading to false/stale provider authorization.

**Required remediation / acceptance rationale:** Make observations target-owned and inaccessible to app code; use distinct request/process/browser-module scope types with generative nonces; bind all observed facts into the token; test forgery, same-type cross-instance reuse, reload, stale process, and cross-target misuse.

### ADR015-F005 — The generated facades never invoke the native provider.

**Severity:** `blocking-high`
**Affected paths:** `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/AcmeCalendar.hx`; `fixtures/adoption-contract/inputs/provider-stubs.php`; `fixtures/adoption-contract/inputs/index.d.ts`; `fixtures/adoption-contract/test/Main.hx`

**Observed facts**

- AcmeCalendarFacade.listEvents returns a php-call transcript string after token authorization.
- AcmeCalendarFacade.renderBadge returns a js-call transcript string.
- No generated PHP function call, JavaScript module import/export call, ABI conversion, exception path, reference behavior, callback, or lifecycle interaction is exercised.

**Inference:** The prototype proves type relationships around a descriptor, not that the facade preserves native provider ABI or ownership.

**Practical consequence:** Incorrect native symbol spelling, argument/return conversion, exceptions, arrays, references, module loading, or provider races can remain invisible.

**Required remediation / acceptance rationale:** Generate target-specific wrappers that call deterministic synthetic native stubs/modules first, then a bounded real-provider seam; exercise success, absence, wrong artifact/version, exception, reference/array, and reload behavior while keeping the native provider owner.

### ADR015-F006 — The contract does not content-bind the exact capability document, review report, facade, and ownership set under one root identity.

**Severity:** `blocking-high`
**Affected paths:** `schemas/adoption-contract.schema.json`; `schemas/adoption-capability.schema.json`; `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/contract/acme-calendar.capability.json`; `fixtures/adoption-contract/contract/acme-calendar.review.json`

**Observed facts**

- The contract references its capability set by ID and version only.
- The capability document binds the contract digest and has a self-digest, but the contract does not bind the capability digest.
- No package-level manifest binds the exact contract, capability set, review report, generated facade, and generated-file ownership manifest.

**Inference:** A different self-consistent capability document with the same ID/version can be substituted without changing the binding contract.

**Practical consequence:** Probe requirements, scope, optionality, and native symbols can drift silently from the generated facade authority.

**Required remediation / acceptance rationale:** Add an acyclic adoption-bundle manifest that binds exact digests for every record and generated file set; require consumers and runtime probes to verify that root identity.

### ADR015-F007 — “Exact artifact” identity is not a real provider artifact or operational runtime observation.

**Severity:** `blocking-high`
**Affected paths:** `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/contract/acme-calendar.capability.json`; `fixtures/adoption-contract/inputs/plugin.php`; `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/Adoption.hx`

**Observed facts**

- The provider artifact URL names acme-calendar.2.4.1.zip, but artifactSha256 equals the digest of inputs/plugin.php.
- The runtime prototype receives that digest as caller data rather than hashing deployed plugin/module bytes or reading a platform-owned build identity.
- The capability record claims exact-sha256 matching, yet no deploy-observable artifact definition is supplied.

**Inference:** The fixture conflates one source file with a provider archive and then treats a caller assertion as an exact runtime observation.

**Practical consequence:** A different deployed plugin/module can be authorized under the expected digest, making required/optional capability behavior fail open in practice.

**Required remediation / acceptance rationale:** Use an actual deterministic provider archive or explicitly name the exact main-file artifact; define target-specific observable identities (WordPress plugin/version/build manifest and JS module/package lock/export set); compute them in trusted probes and test required-capability failure separately from optional fallback.

### ADR015-F008 — Public JSON Schema patterns are not anchored for independent standards-compliant validators.

**Severity:** `blocking-medium`
**Affected paths:** `schemas/adoption-contract.schema.json`; `schemas/adoption-capability.schema.json`; `schemas/adoption-review.schema.json`; `scripts/adoption/validate-architecture.py`

**Observed facts**

- Patterns for IDs, SHA-256, semver, paths, and URLs omit ^ and $ anchors.
- JSON Schema pattern uses substring matching by specification.
- The repository’s custom ClosedSchemaValidator applies re.fullmatch, masking the weakness for this one implementation.

**Inference:** A conforming external validator can accept prefixed or suffixed garbage that the local validator rejects.

**Practical consequence:** Cross-tool consumers can disagree on identities and digests, weakening the claimed closed interoperable contract.

**Required remediation / acceptance rationale:** Anchor every full-string pattern, add adversarial tests through an independent JSON Schema implementation, and keep cross-record semantic validation separate from schema shape validation.

### ADR020-F001 — The supplied “every tracked file” snapshot cannot reproduce the repository’s own bootstrap or license gates.

**Severity:** `blocking-high`
**Affected paths:** `wordpresshx-repository.xml`; `scripts/check-repository.sh`; `scripts/gates/check-g0-baseline.py`; `scripts/licenses/check-license-policy.py`; `scripts/licenses/test-license-policy.py`; `manifests/toolchain.lock.json`

**Observed facts**

- The Repomix snapshot contains 1,071 file entries but omits six required package-lock.json files, scripts/project-cli/test-contract.py, and tooling/php-quality/composer.lock.
- scripts/check-repository.sh and the G0 baseline require those exact paths; the toolchain manifest records the lock paths.
- The ordinary license checker raises FileNotFoundError for tooling/php-quality/composer.lock, and the publication-gate/test wrapper cannot reach its expected controlled blocked result.
- Repomix itself can omit ignored/default-excluded files, so this may be bundle construction failure rather than repository deletion; either way the review input does not substantiate a complete tracked tree.

**Inference:** The immutable review bundle is incomplete for the exact whole-repository and licensing claims it asks Oracle to verify.

**Practical consequence:** A reviewer cannot independently reproduce the claimed pass/fail state, lock-derived inventory, or publication block from the supplied authority.

**Required remediation / acceptance rationale:** Rebuild the review bundle from git ls-files or a raw git archive, include ignored-but-tracked locks, publish a path/byte/hash inventory, and rerun the ordinary audit plus publication gate before relying on their receipts.

### ADR020-F002 — Repository-original work has no root license grant and contributor authority is unproven.

**Severity:** `blocking-critical`
**Affected paths:** `docs/adr/020-licensing-and-generated-output.md`; `LICENSES/policy.json`; `LICENSES/components.json`; `LICENSES/QUALIFIED_REVIEW.md`; `README.md`

**Observed facts**

- No root LICENSE grant is present in the snapshot.
- policy.json records provisional-no-license-grant, publication.allowed=false, and qualified review pending.
- components.json classifies repository-original work as LicenseRef-No-License-Grant and records contributor-rights confirmation as a blocker.

**Inference:** GPL-2.0-or-later is a candidate policy, not a granted license or demonstrated chain of title.

**Practical consequence:** No SDK, CLI, source archive, generated template package, registry artifact, or promoted download is authorized by this evidence.

**Required remediation / acceptance rationale:** Inventory contributors and imported/copied sections; record owner/contributor authority; obtain qualified review; add the complete approved root grant and notices; bind approval to an immutable commit and exact artifacts. Oracle cannot grant or infer these rights.

### ADR020-F003 — The component inventory is curated rather than complete and lock-derived.

**Severity:** `blocking-high`
**Affected paths:** `LICENSES/components.json`; `LICENSES/THIRD_PARTY_NOTICES.md`; `packages/gutenberg/build-tooling/package.json`; `packages/gutenberg/editor-tooling/package.json`; `packages/gutenberg/hxx-tooling/package.json`; `packages/gutenberg/tooling/package.json`; `packages/cli/browser-tooling/package.json`

**Observed facts**

- The component ledger inventories selected Haxe, compiler, PHP-quality, CI, Docker, and profile inputs.
- Exact package manifests separately pin React, React DOM, TypeScript, esbuild, webpack, Playwright, axe-core, Babel, and many @wordpress packages that are not enumerated in components.json or the provisional notices ledger.
- The policy scope includes build/CI tools and exact runtime-test inputs, but the checker does not derive the inventory from every lock or packed output.

**Inference:** Internal consistency of a curated component list is not evidence of dependency completeness.

**Practical consequence:** License conflicts, notices, copied browser runtime, and packed-artifact obligations can be missed while the inventory reports an inventoried state.

**Required remediation / acceptance rationale:** Generate SBOMs from every Haxelib, npm, Composer, OCI, and source lock plus each packed artifact; require every lock/bundle component to map to an origin/license decision or fail the publication gate.

### ADR020-F004 — Actual generated runtime/polyfill bytes lack a final artifact-specific origin, license, and notice closure.

**Severity:** `blocking-high`
**Affected paths:** `manifests/private-runtime-implementation.json`; `manifests/evidence/sdk-024-private-php-runtime.json`; `LICENSES/GENERATED_OUTPUT.md`; `LICENSES/components.json`; `compiler/reflaxe.php/provenance.json`

**Observed facts**

- The private PHP lane records stock Haxe runtime files, a classmap, global polyfills, and per-file evidence in test artifacts.
- The licensing policy still marks generated runtime/standard-library boundaries as publication-blocking and GENERATED_OUTPUT.md says Haxe/Genes/runtime copying is not closed per final artifact.
- No exact installable ZIP with complete byte-origin map, SBOM, source correspondence, full license texts, and final notices is supplied for review.

**Inference:** General statements about compiler output do not classify substantial copied runtime, standard-library, template, or helper bytes in a concrete distributable.

**Practical consequence:** A generated plugin/browser bundle can ship third-party/toolchain code without the applicable attribution, source, license text, or compatibility decision.

**Required remediation / acceptance rationale:** Produce exact candidate archives; map every file/range to user input, emitter-original boilerplate, third-party/upstream material, or toolchain runtime; include SBOM, source correspondence, complete licenses/notices, and deterministic byte-to-origin checks for PHP and Genes outputs.

### ADR020-F005 — Metadata/license-text conflicts and missing license texts remain unresolved.

**Severity:** `blocking-high`
**Affected paths:** `LICENSES/components.json`; `LICENSES/THIRD_PARTY_NOTICES.md`; `packages/hxx/dependency-lock.json`; `docs/adr/020-licensing-and-generated-output.md`

**Observed facts**

- tink_hxx and tink_anon metadata says MIT while exact source license files are recorded as the Unlicense.
- Lix metadata and shipped license evidence conflict.
- tink_parse lacks a standalone source license in the inspected revision, and multiple exact package artifacts lack a bundled license text.
- THIRD_PARTY_NOTICES.md is a provisional ledger rather than a final notice bundle containing all applicable texts.

**Inference:** The snapshot recognizes uncertainty but does not establish which terms a distributor may rely on for each exact input and artifact.

**Practical consequence:** A final notice set can be inaccurate or incomplete, and a blanket candidate grant can misdescribe included material.

**Required remediation / acceptance rationale:** Obtain authoritative upstream clarification or exact grants, preserve the evidence, decide whether affected components remain build-only or are replaced, and generate complete applicable texts from the resolved exact inputs.

### ADR020-F006 — Derived WordPress and Gutenberg catalogs lack a reviewed field-level origin and distribution conclusion.

**Severity:** `blocking-high`
**Affected paths:** `generated/wp70-release/catalog-v1/catalog.json`; `generated/gutenberg-forward-23.4/catalog-v1/catalog.json`; `generated/wp70-release/catalog-v1/generation-report.json`; `generated/gutenberg-forward-23.4/catalog-v1/generation-report.json`; `profiles/wp70-release/source.lock.json`; `profiles/gutenberg-forward-23.4/source.lock.json`; `LICENSES/components.json`

**Observed facts**

- The catalogs contain selected names, signatures, classifications, schema arrangements, and provenance derived from exact WordPress/Gutenberg inputs.
- The candidate policy describes them as facts/identifiers with provenance, while components.json explicitly leaves derived-catalog treatment pending and publication-blocking.
- Source hashes prove provenance but do not classify every copied or normalized field or the collection/arrangement as distributed expression.

**Inference:** The evidence does not support one universal ownership or license conclusion for the complete generated catalogs.

**Practical consequence:** Publishing them under one asserted grant can overstate repository ownership or omit upstream attribution/terms.

**Required remediation / acceptance rationale:** Generate a field-level extraction map, quantify copied versus normalized content, preserve upstream notices and exact spans, and obtain an artifact-specific owner/qualified review decision.

### ADR020-F007 — Exact Haxe license evidence is internally inconsistent and incompletely content-bound.

**Severity:** `blocking-medium`
**Affected paths:** `LICENSES/components.json`; `manifests/toolchain.lock.json`; `docs/adr/020-licensing-and-generated-output.md`

**Observed facts**

- The Haxe 4.3.7 component records commit e0b355c6be312c1b17382603f018cf52522ec651.
- Its license locator names a different revision, e0b3551ca0511b660d5f3ba8752b3c4c89587307.
- Several exact source-license evidence records have a null SHA-256 even when an immutable locator is named.

**Inference:** The exact component and the evidence used to classify its license are not guaranteed to be the same bytes.

**Practical consequence:** A changed or mistyped external locator can silently alter the terms used in the final decision.

**Required remediation / acceptance rationale:** Bind every license text to the same exact pinned commit/blob and a content hash; vendor the evidence snapshot into the review bundle; reject component/license locator mismatch and null hashes for publication-relevant inputs.

## Non-blocking findings

### G1-N01 — The supplemental SDK-025 source-correlation receipt is stale relative to the reviewed packet

**Severity:** `non-blocking`
**Affected paths:** `review/g1-php-readability/packet/evidence/sdk-025-php-source-correlation.json`; `review/g1-php-readability/packet/debug/includes/FailureCallbacks.php.haxe-map.json`; `review/g1-php-readability/packet/php/source-correlation/includes/FailureCallbacks.php`; `review/g1-php-readability/packet/packet-manifest.json`

**Observed facts:** the supplemental receipt records generated PHP digest `e2612cf4…`, while the current PHP, map, and packet bind `d3534a63…`. The current map/traces remain mutually consistent.

**Inference and consequence:** the receipt is historical or stale, not authority for the current packet. It does not block the exact G1 decision because current artifacts are correctly content-bound, but it can mislead later aggregation.

**Remediation:** refresh the supplemental receipt or mark it explicitly historical and add a relation gate that rejects a “current” receipt whose subject digest differs from the packet.

### G1-N02 — `autoload.php` is an eager include and registration graph

**Severity:** `observation`
**Affected paths:** `review/g1-php-readability/packet/php/acme-books-adapters/includes/autoload.php`; `review/g1-php-readability/packet/php/acme-books-adapters/includes/register-adapters.php`; `review/g1-php-readability/packet/php/acme-books-adapters/acme-books-adapters.php`

**Observed facts:** requiring `autoload.php` immediately requires `register-adapters.php`, which runs `add_action`/`add_filter` calls before the root registers activation and calls `Bootstrap::boot()`.

**Inference and consequence:** the flow is readable, but the name suggests lazy/PSR autoloading and the packet guide can be read as a different sequence.

**Acceptance rationale/remediation:** this does not obscure debugging enough to reject G1. Rename the file to `includes.php`, split registration, or add an explicit generated comment and correct the guide.

### G1-N03 — The G1 adapter result is a bounded manually planned PHP-IR slice

**Severity:** `observation`
**Affected paths:** `review/g1-php-readability/packet/haxe/fixtures/AcmeBooksAdapters.hx`; `review/g1-php-readability/packet/artifact-manifests/wordpresshx-public-php-adapters.v1.json`

**Observed facts:** the Haxe fixture directly constructs `PhpMethod`, `PhpStmt`, WordPress registration, and source-range IR; most public methods reuse one broad source range.

**Inference and consequence:** G1 proves the exact output is maintainable PHP, not that arbitrary ordinary application Haxe currently lowers this way or has fine-grained maps.

**Acceptance rationale/remediation:** keep the claim narrow. A later expansion should start from normal typed application Haxe and preserve independent declaration/member/statement origins.

### ARCH-N01 — The package-topology manifest mixes intended modules with currently absent directories

**Severity:** `major-medium`
**Affected paths:** `manifests/package-topology.json`; `packages/`

**Observed facts:** the manifest names `packages/profiles`, `packages/server`, `packages/testing`, `packages/interop-php`, and `packages/interop-js`; none exists in the snapshot. Existing top-level package directories are `build`, `cli`, `contracts`, `core`, `gutenberg`, and `hxx`.

**Inference and consequence:** the map appears to mix target architecture with present topology without a lifecycle/presence marker. Newcomers and tools can mistake planned paths for implemented modules.

**Remediation:** split intended and implemented topology or add an explicit lifecycle/presence field and validate every “implemented” path.

### ARCH-N02 — Evidence/control-plane breadth is ahead of the shortest end-user vertical

**Severity:** `major-medium`
**Affected paths:** `README.md`; `packages/README.md`; `examples/README.md`; `manifests/plugin-development-implementation.json`; `manifests/scaffold-implementation.json`

**Observed facts:** the repository has extensive ADRs, manifests, validators, receipts, and bounded production-shaped lanes, but only two focused examples. The generic site lane does not emit a complete deployable site/theme, server HXX remains a prototype, and no public SDK/package exists.

**Inference and consequence:** architecture is mature relative to product proof. A contributor must understand a large evidence vocabulary before completing the simplest install/debug/update/remove journey.

**Remediation:** prioritize one small public-artifact vertical—typed Haxe source to installable plugin with REST, dynamic block/server HXX, editor UI, watch/reload, diagnostics, deterministic package, update, and removal—then collapse duplicated evidence around that journey.

### ARCH-N03 — Exact versions and evidence-stage prose are duplicated and already drifting

**Severity:** `major-medium`
**Affected paths:** ADR-012/ADR-015 documents, their fixture READMEs, architecture manifests, evidence receipts, and dependency locks

**Observed facts:** current-looking documents repeat Genes 1.36.3 while exact manifests/receipts use 1.38.0; ADR-015 also retains a pending-hosted phrase beside passed hosted evidence.

**Inference and consequence:** hashes can remain internally valid while readers select the wrong current subject.

**Remediation:** generate status/version tables from locks and receipts, mark historical records explicitly, and make cross-record subject identity a repository gate.

### ARCH-N04 — The repository gate and canonical JSON logic are maintenance concentration points

**Severity:** `non-blocking-medium`
**Affected paths:** `scripts/check-repository.sh`; custom closed/canonical JSON validators across `scripts/`

**Observed facts:** the root shell gate is over eleven thousand lines and repeats path inventories and embedded validation logic. Multiple subsystems implement canonical/closed JSON behavior independently.

**Inference and consequence:** adding a lock or moving a file can break distant sections, and semantic differences between validators can remain hidden.

**Remediation:** move path/command inventories to typed manifests, split the gate into composable validators, and run every canonical JSON implementation against one cross-language vector corpus.

### ADR012-F007 — The browser URL and event negative assertions are too weak to establish the claimed shared policy.

**Severity:** `major-high`
**Affected paths:** `fixtures/output-context/runtime/browser.mjs`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `scripts/output-context/test.sh`

**Observed facts**

- The browser probe passes only a known-safe HTTPS URL, then asserts that javascript: is absent from the rendered markup.
- It asserts that onfocus= is absent even though no event-attribute payload is supplied.
- The Haxe URL validator and PHP esc_url probe are independent from the browser value path, and the corpus omits case/control/entity/protocol-relative/data-URL variants.

**Inference:** The negative assertions are partly vacuous and do not prove that one validated URL authority reaches both target sinks.

**Practical consequence:** Divergent target policies or a future unsafe URL regression can pass the current test.

**Required remediation / acceptance rationale:** Feed one generated validation result into both targets and add an adversarial matrix covering scheme casing, controls, whitespace, entities, protocol-relative URLs, fragments, data URLs, Unicode, and event/style attribute rejection.

### ADR012-F008 — Exact Genes identity drifts across the ADR, fixture guide, manifest, and receipt.

**Severity:** `major-medium`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `fixtures/output-context/README.md`; `manifests/output-context-architecture.json`; `manifests/evidence/adr-012-output-context-safety.json`

**Observed facts**

- The ADR and fixture README name Genes 1.36.3.
- The architecture manifest and evidence receipt name Genes 1.38.0 and commit 122162abefc2035b307508e521348ea4fb36dab7.
- The repository treats exact compiler identity as part of evidence authority.

**Inference:** At least one current-looking claim is stale, and the bundle alone does not establish which prose statement describes the hosted result.

**Practical consequence:** A reviewer can reproduce against the wrong compiler while believing the exact evidence identity is closed.

**Required remediation / acceptance rationale:** Generate all version/status prose from one dependency lock and reject drift across ADRs, fixture guides, manifests, receipts, and package locks.

### ADR012-F009 — Non-cacheable and non-serializable terminal semantics are policy rules rather than Haxe type-system guarantees.

**Severity:** `non-blocking-medium`
**Affected paths:** `docs/adr/012-output-context-safety.md`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`

**Observed facts**

- Constructors and raw fields are private, but ordinary application code can retain a terminal object reference in memory.
- The prototype supplies no affine, linear, sink-bound, or generation-scoped use discipline.

**Inference:** Nominal types prevent cross-context substitution but cannot literally prevent caching or delayed reuse.

**Practical consequence:** Documentation can overstate what the compiler enforces, especially if policy changes between construction and rendering.

**Required remediation / acceptance rationale:** State the enforceable invariant precisely—opaque raw content and final-sink contextual lowering—and treat non-retention as API design, linting, or a future sink-bound capability rather than a proven type property.

### ADR015-F009 — Regeneration, removal, modified-file protection, and rollback are prose-bound rather than adoption-specific executable evidence.

**Severity:** `major-medium`
**Affected paths:** `docs/adr/015-interop-and-adoption-contract-format.md`; `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/README.md`; `manifests/adoption-contract-architecture.json`

**Observed facts**

- The contract stores ownership-policy strings but no generated facade path/hash inventory.
- The fixture performs no no-op regeneration, changed-provider regeneration, modified-owned-file, removal, rollback, or provider-untouched filesystem transaction.
- The ADR delegates ownership mechanics to ADR-007 but does not bind an ADR-007 manifest into this adoption packet.

**Inference:** The policy is compatible with deterministic ownership, but the adoption handoff is not proven.

**Practical consequence:** A generator can satisfy schemas while overwriting user changes, leaving stale facades, or deleting provider-owned files.

**Required remediation / acceptance rationale:** Bind the generated-files ownership manifest into the adoption bundle and add cold/warm, update, modified-owned-file, removal, rollback, and provider-untouched tests.

### ADR015-F010 — Exact Genes version and hosted-evidence state drift across current-looking ADR records.

**Severity:** `major-medium`
**Affected paths:** `docs/adr/015-interop-and-adoption-contract-format.md`; `fixtures/adoption-contract/README.md`; `manifests/adoption-contract-architecture.json`; `manifests/evidence/adr-015-interop-adoption-contract.json`

**Observed facts**

- The ADR and fixture README name Genes 1.36.3 while the architecture manifest and receipt name 1.38.0.
- The architecture claim retains compile-tested-local-pending-hosted while the same record has a passed hosted gate and the receipt says local-and-hosted.

**Inference:** The packet was only partly refreshed after compiler/hosted evidence changed.

**Practical consequence:** Reproduction identity and evidence-stage interpretation are ambiguous.

**Required remediation / acceptance rationale:** Generate exact version and evidence-stage prose from one lock/receipt and reject stale phase words or version strings in the repository gate.

### ADR020-F008 — Imported compiler provenance is strong, but the local notice is not a complete distributable license set.

**Severity:** `major-medium`
**Affected paths:** `compiler/reflaxe.php/provenance.json`; `compiler/reflaxe.php/LICENSE.md`; `LICENSES/THIRD_PARTY_NOTICES.md`

**Observed facts**

- provenance.json identifies the exact wordpresshx-port origin, source blobs, transformations, and GPL-2.0-or-later expression.
- compiler/reflaxe.php/LICENSE.md is a short notice/link rather than the complete applicable GPL text and final preserved notice set.
- No final compiler archive with source correspondence and complete notices is supplied.

**Inference:** Provenance preservation does not by itself complete distribution materials.

**Practical consequence:** A Haxelib/source archive assembled from the tree can omit required license text, notices, or corresponding-source information.

**Required remediation / acceptance rationale:** For each candidate archive, include the complete applicable license text, preserved notices, file-level provenance, source correspondence, SBOM, and exact archive manifest.

## Evidence strengths

1. **The G1 PHP is genuinely ordinary and inspectable.** The plugin root, activation hook, action/filter registration, REST route, dynamic block callback, public exports, by-reference parameter, private helpers, PHPDoc unions, and WordPress native calls are visible without a proprietary runtime or opaque dispatcher.

2. **Native debugging information is preserved.** Hook, REST, render, and private traces retain exception class/message, generated PHP file/line, callable sequence, and unmapped frames. The correlator adds Haxe statement anchors rather than replacing native text or guessing the ambiguous private intermediate frame.

3. **The generic PHP compiler boundary is meaningfully separated.** Production source under `compiler/reflaxe.php/src` is neutral PHP IR/printer/map infrastructure; WordPress naming and policy live in the WordPress profile/SDK layers rather than provider branches in compiler core.

4. **The browser compiler remains externally and immutably owned.** Genes is pinned as browser compiler authority while WordPressHx owns WordPress/Gutenberg profiles, HXX lowering policy, asset packaging, and native artifacts. This is the correct ownership direction.

5. **Strict Haxe typing is unusually disciplined.** A repository-wide lexical scan found 435 `.hx` files and zero standalone uses of `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped`. The repository’s own guard passed across its 428-file official compiler/packages/fixtures scope. Many negative fixtures test context, schema, profile, HXX, ownership, data-store, and project mistakes.

6. **Deterministic ownership, fail-closed publication, and provenance are first-class concerns.** The repository has content hashes, exact locks, staged publication, manifest-last transactions, modified-owned-file protection, rollback journals, source maps, package inventories, and explicit publication/production false states.

7. **Many self-contained contract validators are real and useful.** The semantic-plan, ownership, source-correlation, schema-authority, release-governance, generated-output VCS, runtime-support, and PHP-emission policy validators independently passed in this review environment. Their exact scope should remain explicit.

8. **The project often states evidence maturity honestly.** Manifests distinguish invented/typed/generated/runtime-tested/production-supported states; README identifies bootstrap/pre-feasibility; examples call themselves focused capability proofs rather than the flagship product.

9. **ADR-015’s policy direction is worth retaining despite the fixture failure.** Static inspection by default, opt-in isolated reflection, one-complete-binding precedence, explicit omissions, native provider ownership, and app-local facades are good foundations once records are truly source-derived.

10. **ADR-020 fails closed instead of laundering uncertainty.** The candidate grant is explicitly non-final, compiler output is origin-sensitive, user input is not automatically relicensed, copied runtime may carry source obligations, qualified review is required, and publication remains false.

## Per-ADR decisions

### ADR-012 — CHANGES REQUIRED

The architecture should be retained, not rejected. Distinct terminal types, late native escaping, separate JSON-document/script-data types, no universal raw type, and separate server/browser rich-HTML authority are the correct direction.

Acceptance requires all of the following in one source-derived packet:

- a closed, fail-closed HXX element/attribute/child context table with positioned diagnostics;
- compiler-only `CompilerMarkup` construction from a typed AST and source span;
- executable lowerers that carry terminal authority into generated PHP and Genes/React output;
- a real ADR-009 codec with explicit PHP/browser encoding errors;
- separate inline-style and stylesheet grammars with closed printers;
- content-addressed custom KSES policies and mutation tests;
- adversarial URL/script/raw-text/nested-document vectors; and
- one exact generated toolchain identity.

### ADR-015 — CHANGES REQUIRED

The intended adoption model is valuable, but the current fixture cannot serve as its acceptance evidence. Its most serious defect is epistemic: the loss report lists nonexistent source symbols while the validator never derives symbols from source. That same gap permits guessed types and checked-in narratives to masquerade as generated contracts.

Acceptance requires:

- a real no-execution generator that parses exact inputs and writes contract/capability/review/facade bytes into a private stage;
- source-span/signature-digest binding for every included, omitted, and conflicting symbol;
- no `number -> int32`, `object -> ReactElement`, PHP-int-width, or comparable refinements without explicit authority;
- a content-addressed adoption bundle root;
- target-owned observations and generative request/process/module scopes;
- wrappers that invoke native PHP/JS stubs and later a bounded real provider;
- observable deployed-artifact identity and separate required/optional failure semantics;
- anchored public schemas validated by an independent implementation; and
- adoption-specific update/removal/rollback ownership evidence.

### ADR-020 — CHANGES REQUIRED; PUBLICATION BLOCKED

This section is technical licensing-risk analysis, **not legal advice**. The fail-closed policy is the right posture, but it is not a rights conclusion. The product owner can choose whether to pursue the candidate GPL-2.0-or-later policy, replace/clarify dependencies, build exact SBOM/origin tooling, and obtain qualified review. The evidence does not establish contributor authority, exact third-party terms, generated-output obligations, catalog treatment, or publication permission.

Before any publication decision, the owner needs:

- a complete git-derived evidence tree whose ordinary audit and publication gate reproduce;
- contributor/import provenance and an approved root grant;
- lock- and bundle-derived SBOMs for every candidate artifact;
- exact byte-origin maps for Haxe/Genes runtime, standard-library, template, polyfill, and emitter bytes;
- resolved metadata/license-text conflicts and complete license texts;
- field-level WordPress/Gutenberg catalog provenance and artifact-specific review; and
- exact archives with notices, source correspondence, hashes, and qualified owner disposition.

## Product and architecture assessment

### Layer separation and coupling

The target ownership model is coherent:

```text
neutral reflaxe.php IR / printer / source-map machinery
    <- WordPress PHP profile and public adapter planners
    <- SDK semantic plans, CLI, artifact ownership, packaging

immutable Genes browser compiler
    <- WordPress/Gutenberg browser profiles and HXX policy
    <- native WordPress scripts, metadata, PHP/JS/CSS/JSON artifacts
```

The generic compiler does not need provider-specific branches. WordPress and Gutenberg remain native runtime authorities. Generated PHP/JS/metadata are native artifacts, not a proprietary replacement runtime. The separate full `wordpress-hx` port boundary is documented and no direct import of unpublished port internals was found in the reviewed production source.

The main coupling risk is now the control plane itself: repeated exact identities across prose/manifests/receipts, multiple canonical JSON implementations, and a monolithic root gate. The Genes drift and missing bundle paths show how this can fail even when individual records are hashed.

### Strict typing and compile-time validation

The project’s primary technical risk is **not** weak Haxe typing. The snapshot is exceptionally strict and uses nominal types, enums, generics, abstracts, null-safety scopes, macros, closed JSON readers, source-positioned diagnostics, and compile-negative fixtures. The more dangerous failure is **false precision at the authority boundary**: a strong type manufactured from incomplete source evidence, or a safe-looking terminal not connected to the final sink.

ADR-015’s `number -> int32`, `object -> ReactElement`, and nonexistent omissions demonstrate this. ADR-012’s public `resolvedHxxFragment(String)` and descriptor-only sinks demonstrate the same pattern from the security side.

### Haxe-first developer ergonomics

The repository already proves useful pieces: typed Gutenberg components, HXX browser output, stores, native public PHP adapters, deterministic packaging, a bounded stock-Haxe private PHP lane, watch/dev-loop work, and source correlation. The two current examples are honest focused proofs.

The product story is still wider than the shortest supported user journey. A newcomer cannot yet install a released SDK and author one ordinary Haxe plugin/theme/block that uses server HXX, REST, browser HXX, watch/reload, native debugging, packaging, update, and clean removal end to end. The opening README states bootstrap/pre-feasibility, but the volume of later implementation receipts can make the product feel more complete than that user path.

The highest-value implementation work is therefore not another horizontal manifest. It is one small, public-artifact, end-to-end WordPress application that forces the security, adoption, ownership, source-map, dev-loop, packaging, and licensing contracts to meet on the same bytes.

### Tests and receipts

The best tests re-derive or execute their subject: generated PHP called by native PHP, WordPress/React runtime vectors, deterministic replay, ownership mutations, and source-map trace correlation. The weakest tests validate a checked-in statement about its own hashes and relationships without parsing the authority it summarizes.

ADR-015 is the concrete warning: 31 independent JSON mutations pass as a strong structural gate while a semantically fabricated discovery inventory remains accepted. Future high-risk evidence should include **source mutation → regeneration → semantic delta** tests, not only record mutation tests.

Recorded hosted receipts remain useful for their exact named fixture and toolchain. They should not be treated as current merely because they are content-addressed; a hash identifies bytes, not whether those bytes are the current subject.

### Documentation and newcomer clarity

The repository is candid but dense. Improve the first-run path with one generated status matrix:

- capability;
- implemented/prototype/planned;
- public API/package availability;
- exact reproduction command;
- latest subject digest/receipt;
- unsupported boundary.

Then give one golden path from clean project to installed plugin and link the deeper ADR/manifest vocabulary after that path. Planned package topology should be labeled planned, not presented in the same machine-readable shape as existing modules.

### Patterns worth borrowing from the supplied sibling references

The references are not authority, but three patterns are directly useful:

- **Genes and Haxe/Elixir HXX:** resolve positions in the typed AST and preserve source provenance before text emission. This is the right corrective model for ADR-012’s public string-based `CompilerMarkup` fixture.
- **Haxe/Ruby gradual adoption:** keep the native framework/provider as owner, generate app-local typed facades, prefer precise-or-omitted contracts, and make removal explicit. ADR-015 already chooses this direction and needs executable derivation/ownership proof.
- **Reflaxe standard/adoption contracts:** admit a portable/native representation only after a per-surface semantic contract and fixtures exist. This is the correct antidote to guessed `int32`/`ReactElement` refinements.

### Likely regressions and maintenance hotspots

- A bootstrap refactor can change registration order because `autoload.php` executes registration as a side effect.
- A dependency update can refresh one manifest/receipt while leaving ADR prose or fixture guides stale.
- A new ignored-but-tracked lock can disappear from a Repomix bundle and break independent audit reproducibility.
- A source input can change while a self-consistent adoption report remains semantically stale or fabricated.
- An HXX intrinsic/attribute expansion can silently fall through to the ordinary-attribute rule unless the context table is closed.
- A future CSS printer can assume arbitrary `Token(String)` is safe because the outer terminal type already looks authoritative.

## Prioritized next work

1. **P0 — Replace ADR-015’s checked-in narrative with a real source-derived generator.** Parse the exact TS/PHP/package inputs, produce candidate inventory, contract, omissions/conflicts, capability set, facade, and ownership manifest in a private stage; bind source spans/signature digests; remove all guessed types; add source-mutation differential tests.

2. **P0 — Close ADR-012 before production server HXX.** Implement typed-AST/source-span position resolution, fail-closed context classification, real target lowerers, codec error results, separate CSS grammars, exact custom KSES policies, and adversarial PHP/React/WordPress vectors.

3. **P0 — Rebuild the evidence bundle from Git authority.** Include every `git ls-files` path—especially ignored-but-tracked locks—and require the ordinary repository/license audit plus publication gate to reproduce from the bundle.

4. **P0 — Keep publication closed and produce exact candidate artifact inventories.** Establish contributor authority/root grant, derive complete SBOMs, resolve license conflicts, map copied runtime/stdlib/template bytes, review catalogs, and assemble full notices/source correspondence for exact archives.

5. **P1 — Build one honest public-artifact vertical.** A small plugin should include typed domain/schema, REST route, dynamic block/server HXX, Gutenberg editor UI/browser HXX, watch/reload, source-correlated PHP/JS diagnostics, deterministic ZIP, update, and safe removal. Test from a clean consumer project using only packed artifacts.

6. **P1 — Make capability authority target-owned.** Add trusted WordPress/plugin and JS-module probes, generative request/process/module scopes, observable artifact identity, required/optional failure behavior, and real native stub calls.

7. **P1 — Eliminate exact-identity drift.** Generate version/status prose and subject tables from locks/receipts; validate current-vs-historical relations; refresh the G1 supplemental SDK-025 record.

8. **P1 — Bind multi-document roots.** Add adoption/output-context/license evidence-pack manifests that acyclically bind every record, generated file set, toolchain identity, and ownership manifest.

9. **P2 — Reduce control-plane duplication.** Split `scripts/check-repository.sh`, make path inventories data-driven, and place all canonical/closed JSON readers on one cross-target vector corpus.

10. **P2 — Align topology and onboarding with current truth.** Label absent packages as planned, publish one capability/status matrix, and keep the first README page centered on what a clean-project user can run today.

## Review scope, verification, and limitations

### Input integrity

- `sha256sum -c BUNDLE-MANIFEST.sha256`: all three declared review inputs matched.
- The repository Repomix contained 1,071 `<file path=…>` entries and recorded commit `145390ec66ed9f0bec61fa834fa8d6713369f6d4` plus a pending governance diff.
- The G1 packet contained 38 manifest-listed files; every listed byte count and SHA-256 matched, and the packet digest recomputed exactly.

### Independently executed checks

- `python3 scripts/output-context/validate-architecture.py` — passed: 10 contexts, 14 forbidden edges, 21 independent mutations. This is structural evidence; it does not close the semantic findings above.
- `python3 scripts/adoption/validate-architecture.py` — passed: 31 independent mutations. This is self-consistency evidence; it does not parse provider declarations or establish the claimed discovery inventory.
- `python3 scripts/semantic-plan/test-contract.py` — passed.
- `python3 scripts/ownership/test-contract.py` — passed.
- `python3 scripts/source-correlation/validate-contracts.py` — passed.
- `python3 scripts/contracts/validate-schema-authority.py` — passed.
- `python3 scripts/release/test-governance.py` — passed.
- `python3 scripts/generated-output-vcs/check-policy.py` — passed.
- `python3 scripts/runtime-support/check-policy.py` — passed.
- `python3 scripts/php/check-emission-policy.py` — passed.
- `python3 scripts/lint/haxe-weak-type-guard.py compiler packages fixtures` — passed across 428 Haxe files. A separate scan of all 435 `.hx` files found zero standalone `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` tokens.
- `python3 scripts/licenses/check-license-policy.py` — did not reach its expected result; it raised `FileNotFoundError` for missing `tooling/php-quality/composer.lock`.
- `python3 scripts/licenses/check-license-policy.py --publication-gate` — failed for the same missing input rather than returning the documented controlled exit 3.
- `python3 scripts/licenses/test-license-policy.py` — failed because the ordinary checker could not load the missing lock.
- `bash scripts/check-repository.sh` — failed immediately on eight paths absent from the supplied snapshot: six npm lockfiles, `scripts/project-cli/test-contract.py`, and `tooling/php-quality/composer.lock`.

### Runtime boundary

The review inspected bundled native PHP, generated artifacts, maps, traces, manifests, and recorded hosted/runtime receipts. It did not fabricate or claim fresh external hosted, Docker, WordPress, browser, PHP matrix, package-registry, or legal-review results. Full runtime reproduction was not possible from the supplied snapshot because required lock/script inputs were absent. Where a record says “runtime-tested-hosted,” this report treats it as an immutable scoped record, not as a newly rerun result or broad compatibility proof.

### Final boundary

Only the narrow G1 readability/debuggability question is accepted. This review does not certify security, legal compliance, compatibility ranges, package publication, operational readiness, production support, or the unreviewed full `wordpress-hx` port. ADR-012, ADR-015, ADR-020, exact candidate artifacts, and release/publication gates remain independent blockers.
