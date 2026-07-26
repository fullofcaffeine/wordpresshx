# WordPressHx independent Oracle review

## Outcome

Overall decision: **changes required**.

- **G1 generated PHP readability/debuggability: accepted**, narrowly. The supplied PHP is recognizable native WordPress/PHP, public and private boundaries are inspectable, and the current maps/traces route representative native failures to exact Haxe statements without hiding unmapped frames. This acceptance is not publication, compatibility, security, or production-support approval.
- **ADR-012 output-context safety: changes required.** The core direction—nominal context types plus late native escaping—is sound, but the HXX position table is not fail-closed for all nested-markup/URL/raw-text positions, CSS contexts are conflated, custom KSES/codec claims exceed the executable prototype, and exact compiler identities drift.
- **ADR-015 interop/adoption: changes required.** Static no-execution, precise-or-omitted selection, native provider ownership, and app-local facades are good. The fixture nevertheless guesses JavaScript types, leaves the exact capability document unbound, permits caller-forged observations, does not operationalize exact runtime artifact identity or required-provider failure, and exposes under-constrained public schemas.
- **ADR-020 licensing/generated output: changes required. Publication remains blocked.** The origin-sensitive output model is prudent, but no root grant or contributor-rights conclusion exists; important dependency graphs are absent from the inventory; actual copied Haxe runtime/polyfill bytes lack a final artifact-specific conclusion; upstream license conflicts and derived catalogs remain unresolved.

Review identity:

- Reviewer: Oracle, independent `oracle-agent`
- Provider/model: OpenAI / GPT-5.6
- Prompt SHA-256: `ed22561d3393e340c00548d4c3ffc15e4517c1fe83329ea773b0638bee7bb559`
- Repository snapshot SHA-256: `c7182305f8e3b51a8ff59e2cd85fd8be753121673fbc80b856c77747a17bdba3`
- Snapshot record: commit `145390ec66ed9f0bec61fa834fa8d6713369f6d4`, including the pending Oracle-governance working diff
- References SHA-256: `1132cfa6672232b0737110e14d874de06adec67d90b0e0989e7a091bfb8a40ea`
- Review date: 2026-07-26

I did not implement the reviewed work, contribute to the reviewed implementation commits, or prepare the evidence bundle. I applied the requested expert perspectives without claiming human or legal credentials. I inspected the immutable repository snapshot and focused references; I did not rerun or invent external hosted results.

## Blocking findings

### ORA-001 — HXX does not fail closed for every security-sensitive position

Severity: blocking/high
Affected paths: `docs/adr/012-output-context-safety.md`; `manifests/output-context-architecture.json`; `scripts/output-context/test.sh`; `fixtures/output-context/runtime/browser.mjs`

Observed facts:

- The HXX graph applies URL policy only to `href`, `src`, `action`, and `formaction`.
- An ordinary attribute accepts a string or typed attribute value.
- No supplied negative/runtime case covers `srcdoc`, URL lists such as `srcset`, SVG URL-bearing attributes, raw-text elements, or an unclassified security-sensitive attribute.

Inference: a lowerer that follows this table can contextually escape an attribute while missing the nested grammar it represents. `srcdoc` is the clearest example: protecting the outer attribute grammar does not establish the safety of the HTML document represented by its value.

Practical consequence: believable generated output can type-check and look escaped while retaining an XSS/context-confusion path.

Required remediation: publish a closed element/attribute context table; reject unclassified nested-document, raw-text, URL-list, SVG, event, style, and script positions; then add source-positioned negatives and real browser/WordPress vectors for every admitted exception.

### ORA-002 — One CSS terminal conflates two grammars

Severity: blocking/high
Affected paths: `docs/adr/012-output-context-safety.md`; `manifests/output-context-architecture.json`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx`

Observed facts:

- `CssDeclarations` names both a style attribute and a generated stylesheet declaration as sinks.
- Its one server lowering is “typed CSS printer, then `esc_attr`.”
- The prototype contains a small CSS AST but no printer or native sink.

Inference: `esc_attr` belongs to the HTML attribute boundary, not a stylesheet. Style attributes, external stylesheet bytes, and style-element content need different final handling.

Practical consequence: expansion can produce broken CSS or hide injection assumptions around delimiters, URL-valued properties, and HTML-closing sequences.

Required remediation: separate inline-style and stylesheet contracts, define a closed printer/URL policy for each, withhold style-element output unless separately modeled, and test malicious values at the actual sinks.

### ORA-003 — ADR-012 evidence overstates custom-policy and codec execution

Severity: blocking/high
Affected paths: `docs/adr/012-output-context-safety.md`; `manifests/output-context-architecture.json`; `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`; `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx`; `fixtures/output-context/runtime/wordpress-probe.php`; `scripts/output-context/test.sh`

Observed facts:

- The ADR requires a custom KSES policy identity to bind tags, attributes, and protocols by digest.
- The Haxe prototype only exposes the two native policies. A handwritten PHP probe calls custom `wp_kses`, but that call is not connected to a typed digest-bearing constructor.
- `OutputCodec<T>` exposes only `schemaId()`. The terminal retains no encoder and the Haxe “sink” prints a declarative transcript.
- The WordPress probe does not deliberately exercise `wp_json_encode` failure.

Inference: nominal type separation is real, but content-addressed custom policies, codec-owned bytes, and explicit encoding failure are not proved.

Practical consequence: an implementation could ignore the codec, hash incomplete policy material, or mishandle encoding failure while satisfying the current evidence shape.

Required remediation: implement a canonical custom-policy codec/digest, retain executable codec authority through the sink, exercise success/failure on PHP and browser targets, and derive the transcript from real operations.

### ORA-004 — ADR-015 manufactures JavaScript precision

Severity: blocking/high
Affected paths: `fixtures/adoption-contract/inputs/index.d.ts`; `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/AcmeCalendar.hx`; `docs/adr/015-interop-and-adoption-contract-format.md`

Observed facts:

- The TypeScript declaration says `count: number`; the contract says `int32`.
- The TypeScript declaration says `CalendarBadge(...): object`; the contract says native nominal `ReactElement`.
- The ADR prohibits guessed types and field-spliced authority.

Inference: the generated binding is more specific than its strongest source. Neither integer-only semantics nor React-element identity follows from the reviewed declaration.

Practical consequence: the facade can reject valid provider behavior or accept invented assumptions as compile-time truth.

Required remediation: map to the exact admitted numeric algebra, omit insufficiently described members, or require an authoritative/curated exact source. Add mutations that specifically reject these two translations.

### ORA-005 — The exact capability set is not bound by the adoption contract

Severity: blocking/high
Affected paths: `schemas/adoption-contract.schema.json`; `schemas/adoption-capability.schema.json`; `fixtures/adoption-contract/contract/acme-calendar.contract.json`; `fixtures/adoption-contract/contract/acme-calendar.capability.json`

Observed facts:

- The contract references its capability set by ID and version only.
- The capability document binds the contract digest and has its own self-digest.
- No reviewed package root binds the contract, capability, review, facade, and ownership records together.

Inference: another self-consistent capability document can reuse the same ID/version while changing probes or scope.

Practical consequence: runtime authority can drift without changing the generated binding contract.

Required remediation: add an acyclic adoption-bundle manifest containing exact digests for every record and generated file set; consumers must require that root identity.

### ORA-006 — The capability prototype permits forged premises and blurs lifecycle scopes

Severity: blocking/high
Affected paths: `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/Adoption.hx`; `fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/AcmeCalendar.hx`; `fixtures/adoption-contract/contract/acme-calendar.capability.json`; related negative fixtures

Observed facts:

- `Adoption.observeExact(...)` is public and accepts caller-provided provider/version/artifact/binding values.
- `Adoption.beginRequest(...)` is public and accepts a caller-provided identity.
- Both PHP request and browser-module capability uses flow through `RequestScope`.
- The token constructor is private, but public factories mint it from those caller-controlled premises.

Inference: “direct token construction fails” is weaker than trusted capability minting. The prototype also does not model browser-module reload/lifetime independently from a PHP request.

Practical consequence: application code can manufacture apparent availability or reuse it under the wrong lifecycle, producing stale or false authority.

Required remediation: make observations and scopes target-owned, use distinct nominal lifecycle types/private factories, bind all checked facts into the token, and add forgery, reload, stale-process, and cross-target negatives.

### ORA-007 — Required-provider behavior and exact runtime artifact identity are under-specified

Severity: blocking/high
Affected paths: `docs/adr/015-interop-and-adoption-contract-format.md`; `schemas/adoption-capability.schema.json`; `fixtures/adoption-contract/contract/acme-calendar.capability.json`; `manifests/adoption-contract-architecture.json`

Observed facts:

- All probes require exact artifact SHA-256.
- The schema does not define how an installed plugin tree or transformed browser bundle proves the original artifact digest.
- Capability records contain `optional`, but the authority object supplies one fallback behavior and no distinct required-provider startup diagnostic.

Inference: real runtime adapters may have to reject valid installations or quietly weaken “exact artifact” semantics. The required path described in prose cannot be represented precisely.

Practical consequence: exact adoption can become either unusable or silently inexact.

Required remediation: define deployed target-specific identity manifests and normalization rules; model required absence separately; test present, absent, upgraded, transformed, partial-install, and removal states.

### ORA-008 — ADR-015 public schemas accept substring matches

Severity: blocking/medium
Affected paths: `schemas/adoption-contract.schema.json`; `schemas/adoption-capability.schema.json`; `schemas/adoption-review.schema.json`

Observed facts: identity, SemVer, SHA-256, and Haxe-path patterns lack `^`/`$` anchors. JSON Schema regular-expression matching is substring-based.

Inference: external schema consumers can accept values with otherwise invalid prefixes/suffixes even if the repository’s Python validator rejects selected mutations.

Practical consequence: malformed identities can enter a supposedly exact cross-tool contract.

Required remediation: anchor all whole-string patterns and add prefix/suffix, Unicode, and cross-record semantic tests.

### ORA-009 — No repository-original license grant or demonstrated contributor authority exists

Severity: blocking/critical
Affected paths: `docs/adr/020-licensing-and-generated-output.md`; `LICENSES/policy.json`; `LICENSES/components.json`; `LICENSES/QUALIFIED_REVIEW.md`; `README.md`

Observed facts:

- There is no root `LICENSE`.
- The policy says `repositoryLicenseGrant: not-granted` and all publication modes are false.
- The component inventory calls contributor rights and the root grant blockers.

Inference: GPL-2.0-or-later is a candidate, not a grant. This Oracle cannot establish that all contributors authorized publication under that expression.

Practical consequence: the reviewed evidence authorizes no public SDK, CLI, source archive, generated template package, registry release, or WordPress.org submission.

Required remediation: establish contributor/imported-source rights; record owner decisions; add complete reviewed license text/notices; bind approval to exact source and artifacts. The product owner can make owner decisions from verified rights evidence, but cannot manufacture missing rights by policy declaration.

### ORA-010 — The license inventory omits major dependency graphs

Severity: blocking/high
Affected paths: `LICENSES/components.json`; `LICENSES/THIRD_PARTY_NOTICES.md`; `packages/gutenberg/build-tooling/package.json`; `packages/gutenberg/editor-tooling/package.json`; `packages/gutenberg/hxx-tooling/package.json`; `packages/gutenberg/tooling/package.json`; `packages/cli/browser-tooling/package.json`

Observed facts:

- The component inventory covers selected Haxe, PHP, CI, Docker, compiler, and profile inputs.
- Exact private manifests separately pin React, React DOM, TypeScript, esbuild, webpack, Playwright, axe-core, Babel, and many WordPress packages.
- Those npm components are absent from the inventory/ledger even though its stated scope includes CI/build tools and exact runtime-test inputs.

Inference: “inventoried” currently means “present in a curated expected list,” not “complete relative to every lock and bundle.”

Practical consequence: license conflicts, copied browser runtime, notices, and bundle obligations can escape the publication gate.

Required remediation: generate SBOMs from every npm/Haxelib/Composer/OCI lock and final bundle; require an explanation for every included or excluded component.

### ORA-011 — Actual generated PHP runtime bytes lack a closed output-license decision

Severity: blocking/high
Affected paths: `manifests/private-runtime-implementation.json`; `manifests/evidence/sdk-024-private-php-runtime.json`; `LICENSES/GENERATED_OUTPUT.md`; `LICENSES/components.json`; `compiler/reflaxe.php/provenance.json`

Observed facts:

- The private lane packages 15 stock Haxe runtime PHP files, a classmap, and global polyfills.
- Test artifacts record per-file component/license fields.
- The repository-wide license inventory still lists the generated runtime boundary as unresolved, and no final artifact notice/license set is bundled for review.

Inference: the copied-runtime question is not hypothetical; current generated plugin evidence contains the relevant byte class.

Practical consequence: a generated plugin may redistribute code without complete attribution, license text, or corresponding-source treatment.

Required remediation: review the exact packed plugin, file-origin map, source correspondence, SBOM, full texts, and notices; repeat for Genes/browser and scaffold output.

### ORA-012 — Third-party license conflicts and missing texts remain unresolved

Severity: blocking/high
Affected paths: `LICENSES/components.json`; `LICENSES/THIRD_PARTY_NOTICES.md`; `packages/hxx/dependency-lock.json`; `docs/adr/020-licensing-and-generated-output.md`

Observed facts:

- `tink_hxx`, `tink_anon`, and Lix have recorded metadata/text conflicts.
- Multiple exact Haxelib archives omit license texts; `tink_parse` lacks a standalone source license in the reviewed revision.
- The notice document is expressly provisional and does not carry the final complete texts.

Inference: the snapshot correctly preserves uncertainty but cannot identify final distributable terms for those inputs.

Practical consequence: a final notice can be incomplete or misstate third-party terms.

Required remediation: obtain authoritative upstream clarification/source grants, keep affected packages build-only or replace them as appropriate, then generate exact notices from resolved inputs. This is technical risk advice, not a legal compatibility conclusion.

### ORA-013 — Derived catalog treatment remains an unresolved ownership/license question

Severity: blocking/high
Affected paths: `generated/wp70-release/catalog-v1/catalog.json`; `generated/gutenberg-forward-23.4/catalog-v1/catalog.json`; their generation reports/source locks; `LICENSES/components.json`

Observed facts:

- The catalogs contain selected identifiers, signatures, classifications, and provenance derived from exact WordPress/Gutenberg material.
- The candidate policy characterizes them as facts/identifiers and proposes GPL-2.0-or-later with provenance.
- The inventory itself marks that characterization as unresolved and publication-blocking.

Inference: exact hashes establish origin, not the legal treatment of every selected expression or the collection.

Practical consequence: publishing under a project-authored grant can overstate ownership or omit upstream terms.

Required remediation: generate per-field extraction provenance and copied-versus-normalized analysis; retain upstream notices; obtain qualified artifact-specific advice where necessary; then record the product owner’s decision.

### ORA-014 — Exact evidence identities drift in both proposed technical ADRs

Severity: blocking/medium
Affected paths: ADR-012/ADR-015 documents, fixture READMEs, architecture manifests, and evidence receipts

Observed facts:

- Both ADR/fixture prose records name Genes 1.36.3.
- Both architecture/evidence records name Genes 1.38.0.
- ADR-015’s architecture claim says hosted testing is pending while the same file records a passed hosted gate and its evidence receipt says local-and-hosted.

Inference: evidence was refreshed without atomically refreshing every authority surface.

Practical consequence: exact reproduction and evidence-stage interpretation are ambiguous.

Required remediation: generate tool/version and hosted-state prose from a single lock/receipt, fail on drift, and issue new content-addressed ADR packets.

## Non-blocking findings

### ORA-N01 — G1’s supplemental SDK-025 receipt is stale relative to the reviewed artifact

Severity: non-blocking
Affected paths: `review/g1-php-readability/packet/evidence/sdk-025-php-source-correlation.json`; current map, PHP, and packet manifest

Observed facts:

- SDK-025 records `FailureCallbacks.php` SHA-256 `e2612cf416877983e712c930ee6fc0e36ccd3f37c451b964a8f5af990ee7e157`.
- The reviewed PHP, range map, and packet manifest bind `d3534a6374ebec4ded2265850d93fb0be6f2b73c55f4ac213cbb6e811db00dc2`.
- The current map and supplied traces agree on generated lines and Haxe throw statements.

Inference/consequence: the supplemental receipt cannot be cited as current-artifact proof, but direct current evidence remains sufficient for the narrow readability decision.

Recommendation: refresh it or explicitly label it historical and record the transition.

### ORA-N02 — `autoload.php` is an eager include/registration graph

Severity: observation
Affected paths: G1 `includes/autoload.php`; `includes/register-adapters.php`; plugin root

Observed fact: requiring “autoload” immediately requires the registration file, which executes `add_action`/`add_filter`.

Consequence: a PHP reader may initially assume lazy class loading. The actual flow remains only three local includes and is easy to debug.

Recommendation: emit a comment or use a name such as `includes.php`; no G1 blocker.

### ORA-N03 — Terminal non-cacheability is not a type-system guarantee

Severity: non-blocking/medium
Affected paths: ADR-012 and `fixtures/output-context/.../Output.hx`

Observed fact: private constructors/raw fields prevent unauthorized construction and extraction, but ordinary code can retain a terminal object reference created by a public factory.

Inference/consequence: “cannot be cached” overstates enforceability. The real guarantee is nominal context separation and native escaping at the final sink.

Recommendation: phrase non-retention as an API/lint policy unless a sink-bound representation enforces it.

### ORA-N04 — Adoption removal is prose-bound, not fixture-proved

Severity: non-blocking/medium
Affected paths: ADR-015, adoption contract/README, architecture manifest

Observed fact: the contract stores ownership policy strings but no generated facade path/hash inventory; the fixture does not execute regeneration/removal against modified files.

Consequence: production code can satisfy the schema without proving it only removes exact owned files.

Recommendation: bind an ADR-007 generated-files manifest into the adoption bundle and test no-op replay, modification, removal, rollback, and provider preservation.

### ORA-N05 — The repository-wide gate is a maintenance hotspot

Severity: non-blocking/medium
Affected path: `scripts/check-repository.sh`

Observed fact: the packed file is 11,645 lines and combines a very large required-path list with many policy/receipt checks.

Inference/consequence: adding or moving one capability can require broad hand edits and can create stale duplicated authority—consistent with the version drift found here.

Recommendation: split it into manifest-driven focused validators with one small orchestrator and machine-check each manifest against the filesystem.

### ORA-N06 — Canonical/closed JSON logic is duplicated

Severity: non-blocking/medium
Affected examples: `compiler/reflaxe.php/src/reflaxe/php/map/PhpCanonicalJson.hx`; `packages/build/src/wordpress/hx/build/_internal/CanonicalJson.hx`; `packages/cli/src/wordpresshx/cli/closedjson/*`; `packages/contracts/src/wordpress/hx/contracts/*`

Observed fact: several layers independently implement JSON parsing/canonicalization/closed-object behavior.

Consequence: Unicode ordering, number spelling, presence/null semantics, and unknown-field handling can diverge while each focused test remains green.

Recommendation: keep target-specific adapters but derive/shared-test one canonical wire contract with a cross-implementation vector corpus.

## Evidence strengths

1. **Generated PHP is ordinary native code.** The G1 plugin has a standard header/guard, root-owned activation hook, local eager includes, ordinary callable arrays, visible priorities/accepted counts, native REST/block APIs, normal escaping, typed PHP signatures where PHP 7.4 permits them, and PHPDoc for the remaining unions.

2. **Native frames are preserved.** Hook, REST, render, and private traces retain exception class/message, PHP file/line, callable sequence, and unmapped frames. The correlator adds exact Haxe statement anchors and does not replace native text or guess the private intermediate frame.

3. **The generic PHP compiler boundary is real.** Production source under `compiler/reflaxe.php/src` is neutral IR/printer/map code. The only WordPress/full-port references in that package snapshot are tests, package guards, documentation, and provenance—not source imports or provider branches.

4. **The browser compiler stays separately owned.** WordPressHx pins Genes as an immutable external compiler authority, and WordPress/Gutenberg semantics live in SDK profiles/lowerers. This follows the useful sibling pattern without copying sibling architecture wholesale.

5. **Strict Haxe typing is unusually disciplined.** A lexical scan of all 435 tracked `.hx` files in the snapshot found no standalone `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped`. Negative fixtures cover many profile, schema, HXX, block, editor, data-store, ownership, and project-contract mistakes.

6. **Evidence maturity is generally explicit.** Receipts regularly distinguish generated, runtime-tested, unsupported publication, and production not tested. Searchable `productionSupport`/publication fields consistently remain closed rather than claiming readiness.

7. **Determinism, ownership, and rollback are first-class.** The repository has content hashes, exact source locks, manifest-last transactions, staged publication, stale-file ownership, rollback journals, cold/warm comparisons, and isolated package-consumer tests.

8. **Real-runtime evidence is scoped.** The snapshot contains recorded WordPress 7.0 MySQL/MariaDB, PHP 7.4/8.4, React/Chromium, native caller, accessibility, and source-correlation results. These are strong for their named fixtures. I treat them as immutable records, not as rerun results or general compatibility.

## Per-ADR decisions

### ADR-012 — changes required

Acceptable direction:

- no universal safe string;
- nominal terminal contexts;
- late WordPress-native escaping/sanitization;
- separate JSON-document and HTML-script-data terminals;
- no public browser raw-HTML surface;
- no raw compiler-markup string constructor.

Required before acceptance:

- closed/fail-closed HXX context coverage;
- split CSS grammars;
- executable custom KSES and codec/failure evidence;
- exact tool identity reconciliation;
- documentation that distinguishes enforceable opacity/context rules from non-enforceable non-caching guidance.

### ADR-015 — changes required

Acceptable direction:

- static inspection by default;
- isolated reflection only with explicit receipt;
- whole-binding precedence with precise-or-omitted output;
- native provider remains owner;
- app-local first, companion package later;
- generated bytes and removal delegated to deterministic ownership.

Required before acceptance:

- remove guessed `number -> int32` and `object -> ReactElement` types;
- content-bind all adoption records/files under one root;
- make capability observations and scope factories trusted/target-specific;
- define deploy-observable exact artifact identity and required-provider behavior;
- anchor schemas and test independent schema consumers;
- reconcile exact compiler/hosted identities;
- add adoption-specific regeneration/removal transaction evidence.

### ADR-020 — changes required

The proposed fail-closed policy is a useful guardrail, not a license conclusion. The product owner can decide:

- whether GPL-2.0-or-later remains the candidate for repository-original work after rights confirmation;
- whether to obtain upstream clarification, keep dependencies build-only, or replace them;
- whether to fund exact packed-artifact SBOM/origin/notice work;
- whether and when to seek qualified legal advice.

The evidence does **not** establish contributor authority, resolve third-party terms, characterize all derived/catalog material, decide copied runtime obligations, or authorize publication. Those uncertainties remain.

## Product and architecture assessment

### Separation and coupling

The repository’s major ownership boundaries are coherent:

```text
generic reflaxe.php IR/printer
  <- WordPress PHP profile and public adapters
  <- SDK/CLI semantic plans and artifact ownership

Genes compiler
  <- WordPress/Gutenberg browser profile and HXX lowerer
  <- native WordPress asset/package emission
```

Generated PHP/JS/metadata remain native artifacts rather than a proprietary WordPress runtime. The browser and PHP source-correlation layers compose at the CLI without putting WordPress names into generic compiler code. The sibling references support these choices: Genes’ typed-AST/planning boundary and RailsHx’s native-owner/app-local facade pattern are useful precedents, not hidden dependencies.

The main coupling risks are evidence/control-plane duplication: multiple canonical JSON implementations, exact identity repeated across prose/manifests/receipts, and one very large repository gate. The observed Genes drift is a concrete example of that risk.

### Current product truth

The snapshot is much more than a paper design: it contains substantial CLI/ownership/project implementation, a bounded stock-Haxe private PHP plugin lane, native public PHP adapters, browser HXX, blocks/editor/data-store fixtures, deterministic packaging, source correlation, and real WordPress/browser evidence.

It is still narrower than the opening product description:

- the generic PHP package does not yet provide broad arbitrary typed-Haxe AST lowering;
- the current private PHP production-shaped lane is intentionally one typed title-filter callback;
- server HXX remains a prototype and SDK-081 work;
- theme hierarchy/complete Haxe-owned site authoring remains planned;
- the two runnable “examples” point into repository test fixtures rather than installed public packages;
- no public Haxelib/npm release or final consumer artifact exists.

The README eventually states pre-feasibility clearly, but its first paragraphs use present-tense full-product language before the status warning. A newcomer can understand the architecture, but only after navigating a large volume of ADR/receipt vocabulary. Lead the first page with “implemented today / prototype / planned,” then route to one shortest runnable path.

### Compile-time validation and fail-closed behavior

This is a strong area. The project uses typed abstracts/enums/generics, closed JSON readers, macro source diagnostics, negative Haxe fixtures, exact profile identities, deterministic ownership, and publication blockers. No forbidden weak Haxe constructs were found in the snapshot.

The highest-risk gap is not weak typing; it is **false precision at a typed boundary**. ADR-015’s guessed TypeScript translations and ADR-012’s incomplete position classification demonstrate that strong nominal types are only as safe as the evidence and context graph used to construct them.

### Tests and receipts

Most receipts state their exact scope and avoid production/readiness overclaims. Snapshots are usually paired with typing, runtime, negative, determinism, source-map, or real WordPress/browser checks. G1 is particularly reviewable because generated PHP, native callers, traces, source maps, Haxe sources, and manifests are co-located.

Do not treat every receipt as current merely because it is content-addressed. The stale SDK-025 digest and Genes/hosted-state drift show a missing relation check between historical evidence and the current packet. A hash proves which bytes a record names; it does not prove that those bytes are the current subject.

## Prioritized next work

1. **P0: close ADR-012 before production server HXX.** Make the position graph closed/fail-closed, split CSS contexts, and prove custom KSES, real codecs, encoder failures, script/raw-text/nested-document cases, and actual HXX source diagnostics.

2. **P0: correct ADR-015’s authority model.** Remove guessed types, add a content-addressed adoption bundle root, trusted target-owned capability factories/lifecycles, observable deployed artifact identity, required-provider behavior, and ownership/removal tests.

3. **P0: keep ADR-020 publication closed and build the real inventory.** Derive complete SBOMs from all locks and exact bundles, audit the already-generated Haxe PHP runtime/polyfills, resolve or replace conflicting dependencies, map catalog fields to origins, establish contributor authority, and review full license/notice sets.

4. **P1: eliminate evidence identity drift.** Generate version/commit/status prose from locks and receipts; add cross-checks for subject digests; label historical receipts explicitly; rebuild the G1 packet’s SDK-025 supplemental record.

5. **P1: implement the next honest vertical slice.** Complete generic typed-Haxe-to-PHP lowering and production server HXX/context lowering for one small plugin/theme path, retaining readable native PHP and statement maps. Test it as an installed package, not only from repository fixtures.

6. **P1: prove a consumer-facing package path.** Convert one current Gutenberg fixture into a clean-project example that installs only exact packed SDK/CLI artifacts, then builds, installs, debugs, updates, and removes the native plugin.

7. **P2: reduce control-plane duplication.** Split the 11,645-line repository gate into manifest-driven validators and put all canonical/closed JSON implementations through one cross-target vector corpus.

## Final boundary

This review accepts only the narrow G1 readability/debuggability question. It does not certify security, legal compliance, compatibility ranges, package publication, operational readiness, or production support. ADR-012, ADR-015, ADR-020, SDK-002, and the release gates remain independent blockers.
