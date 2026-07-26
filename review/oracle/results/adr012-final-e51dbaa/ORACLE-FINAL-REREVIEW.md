# ADR-012 independent Oracle final rereview

- Reviewed commit: `e51dbaadb3ba8dfc4edb145834fb7316b82501a9`
- Reviewer: GPT-5.6 / OpenAI / independent Oracle agent
- Immutable packet SHA-256: `43d6db1c63a60c8e6d0d96cfe1ac7492df0641f1b163707fdd65ea5ded0cad07`
- Prompt SHA-256: `17f00275feb3fc44823716bda793c320e62c18488f00b3504c0d4231ca9eb664`
- Repository snapshot SHA-256: `ea8bf34154e31ef17a9fa7310e65998ac06ca61c47a374ddd9bd598be583ee6e`
- Final decision: **accepted**

ADR012-F006 is closed. The previous post-hash mutation path is removed: policy authority is retained only in immutable strings and private final scalar fields, the terminal exposes neither the policy nor mutable rules/protocols, and the sink derives fresh rule/protocol JSON directly from those same private fields. The other eight findings remain closed, with no security regression or forbidden weak Haxe construct found.

Acceptance is strictly limited to the bounded ADR-012 architecture evidence. It does not authorize production support for the unfinished SDK or production HXX lowerer.

## Finding dispositions

### ADR012-F001 — closed (high confidence)

The closed HXX classifier remains unchanged in substance: resolved namespace state is required; non-HTML namespaces, namespaced and unknown attributes, unknown and void-element children, events, nested grammars, raw-text positions, and non-literal position names fail compilation. Its negative fixtures and gate assertions remain present.

### ADR012-F002 — closed (high confidence)

The Haxe-generated plan remains the common input consumed by the PHP/WordPress and React probes and is byte-identical across the tested Haxe, Genes, and PHP generation paths.

### ADR012-F003 — closed (high confidence)

`CompilerMarkup` still retains the private resolved typed AST and source provenance; the shared tree is lowered contextually by PHP and React for text, ordinary attributes, and validated URLs.

### ADR012-F004 — closed (high confidence)

Typed JSON codecs still execute before either terminal and retain explicit success or `EncodingFailure`; the failure path remains asserted.

### ADR012-F005 — closed (high confidence)

Inline and stylesheet CSS retain separate property-specific declaration enums and printers, with compile-negative property/value and cross-context mismatches.

### ADR012-F006 — closed (high confidence)

The final correction removes the demonstrated authority split:

- `CustomKsesPolicy` retains only public final identity strings and private final booleans for paragraph, strong, link-href, link-title, HTTP, and HTTPS semantics.
- `KsesPolicy` and `KsesHtml.policy` are private outside the exact constructor/sink allowlist.
- No policy, terminal, rule, attribute, or protocol array/reference is exposed or retained.
- Input arrays are synchronously reduced into scalar flags; later input-array mutation cannot affect the policy.
- `OutputSinks.richHtml` derives fresh `rulesJson` and `protocolsJson` from the exact private booleans copied from the hashed custom policy.
- The exact prior mutation form, `policy.https = false`, independently fails Haxe compilation with `Cannot access private field https` and an inaccessible-for-writing diagnostic.

An independent packet-derived probe also varied each identity component separately. Version, tag, attribute, and protocol changes produced distinct canonical documents, distinct SHA-256 identities, and corresponding rule/protocol plans. A duplicate-only input normalized to byte-identical canonical identity and plan:

```text
base       tags=a[href],p;      protocols=https
version    version=v2           -> distinct identity
tag        tags=a[href],strong  -> distinct identity and rules
attribute  tags=a[title],p      -> distinct identity and rules
protocol   protocols=http       -> distinct identity and protocols
duplicates                         -> identical to base
```

The WordPress probe builds the actual `wp_kses` allowlist from the emitted rules and passes the emitted protocols directly. It verifies permissive versus restricted policy effects against real WordPress behavior. There is no hard-coded parallel custom allowlist in the sink path.

### ADR012-F007 — closed (high confidence)

The shared adversarial URL matrix, event-attribute compile failure, and prohibition on raw browser rich-HTML insertion remain intact.

### ADR012-F008 — closed (high confidence)

Genes remains consistently identified as 1.38.0 and is checked against the dependency-lock-derived target identity.

### ADR012-F009 — closed (high confidence)

Terminal retention remains accurately scoped as enforceable SDK API policy rather than a Haxe linear-type guarantee.

## New findings

### ADR012-R3-N001 — review prompt contains stale minimum-path names (non-blocking, high confidence)

Five paths named for minimum inspection do not exist in the immutable repository snapshot:

- `packages/php/src/wordpresshx/output/Output.hx`
- `packages/php/src/wordpresshx/output/OutputSinks.hx`
- `fixtures/output-context/src/OutputContextProbe.hx`
- `fixtures/output-context/runtime/wordpress-runtime-probe.php`
- `scripts/output-context/validate.py`

The packet’s evidence manifest itself does not claim those paths. It correctly names and hashes the actual bounded-prototype gate and validator, and the complete snapshot contains the corresponding implementation under:

- `fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx`
- `fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx`
- `fixtures/output-context/test/Main.hx`
- `fixtures/output-context/runtime/wordpress-probe.php`
- `scripts/output-context/validate-architecture.py`

Those actual files were reviewed. Because the ADR and receipt explicitly disclaim production SDK implementation, the stale prompt transcription does not undermine the bounded architecture evidence or change acceptance. Future immutable review prompts should be generated or validated against the packet path inventory.

## Evidence integrity and boundary

Both packet input hashes verified before review. The prior second-rereview report matches its stated SHA-256 `a2001c52ad597ab009c2485184c409db8ff19b9e5ae4f2e74405498a944f8c74`. Every ADR-012 subject hash in the evidence receipt matches the corresponding packet file. The canonical Haxe interpreter plan matches the checked transcript hash `95eb7931a6fdd4761f79d7e897b45fb63f5ccd4d43d6d854d38390bceff16d43`. No `Dynamic`, `Any`, `cast`, `Reflect`, or `untyped` token appears in the ADR-012 Haxe sources or tests.

The packet records hosted run `30223402796`, job `89849614666`, and implementation commit `4d403cdb33ff2ce6e7da196e1062163e15c9e302`, but contains no immutable hosted log or attestation. Those metadata declarations were not treated as independent proof; acceptance rests on the packet-bound source, compile-negative reproduction, deterministic plan, and native-probe design.

## Final decision

**accepted** for the bounded ADR-012 architecture evidence. All ADR012-F001–F009 are closed. The sole new finding is a non-blocking prompt-path provenance defect and does not authorize or imply production support.
