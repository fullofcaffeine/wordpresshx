# ADR-012: Output-context safety

- Status: reopened after an independently reproduced JSON codec regression
- Date: 2026-07-19
- Owners/reviewers: Marcelo Serpa (product owner and security direction), Codex (architecture and executable-fixture implementation), GPT-5.6 Oracle (independent review; accepted the earlier bounded design, then found a regression)
- Bead: `wordpresshx-adr-012`
- Profiles/layers: shared output contracts, PHP compiler, WordPress profile, HXX lowering, Genes browser output, REST, blocks, admin UI
- Supersedes: none; makes PRD §29.1 and ADR-011's contextual-lowering requirement concrete
- Superseded by: none

## Context

WordPressHx lets an application use one Haxe domain model across native PHP,
server HXX, WordPress REST, Gutenberg/React, a Genes SPA, and a possible
NextJsHx BFF or SSR application. Those targets do not have one interchangeable
notion of a safe string. Text, an attribute, a URL, rich HTML, JSON, script
data, CSS, and compiler-produced markup have different grammars and different
native security operations.

A universal `SafeHtml`, a marker abstract with an implicit `String`
conversion, or early escaping would create false authority. A value escaped
for element text can still break an attribute; a JSON document can close an
HTML script element; KSES-filtered server markup is not automatically approved
for a browser raw-HTML API; React escapes text but does not establish an
application URL policy. Escaping is not assumed to be idempotent, so an escaped
value must not be persisted and later escaped again.

WordPress's own guidance requires escaping as late as possible for the exact
output context. Its native functions remain the PHP authority. The Haxe layer
must make the correct path concise and statically visible without replacing
those functions with a proprietary runtime or forcing ordinary users to write
escape helpers around every HXX expression.

## Decision

### No universal safe type

The output model has distinct, terminal contracts:

| Context | Terminal contract | Native WordPress/PHP lowering | Browser lowering |
|---|---|---|---|
| Element text | `HtmlText` | `esc_html` at the final sink | React child escaping |
| Ordinary attribute | `HtmlAttribute` | `esc_attr` at the final sink | React attribute escaping |
| URL attribute | `HtmlUrl` from `ValidatedUrl` | URL validation, then `esc_url` at the final sink | the same validation policy, then an ordinary React attribute |
| Textarea content | `TextareaText` | `esc_textarea` at the final sink | typed React textarea value |
| Rich HTML | policy-branded `KsesHtml` | `wp_kses_post`, `wp_kses_data`, or a content-addressed custom `wp_kses` policy at the final sink | a separate browser-policy result before an internal rich-HTML lowerer |
| JSON document | `JsonDocument<T>` | the contract codec and `wp_json_encode`, with explicit failure handling | the contract codec and `JSON.stringify` for a JSON response/document |
| HTML script data | `HtmlScriptData<T>` | `wp_json_encode` with `JSON_HEX_TAG`, `JSON_HEX_AMP`, `JSON_HEX_APOS`, and `JSON_HEX_QUOT`, with explicit failure handling | `JSON.stringify` plus script-data character escaping |
| Inline CSS declarations | `InlineStyle` | a closed property/value printer, then `esc_attr` at the style-attribute sink | a typed React style object |
| Stylesheet asset | `Stylesheet` | a separate closed selector/property/value printer, without HTML attribute escaping | a generated stylesheet asset |
| Compiler markup | `CompilerMarkup` | static native markup plus separately lowered contextual segments | typed HXX-to-React/Gutenberg output |
| Unsafe raw target | withheld | not published | not published |

The terminal contracts have no public constructors, raw-value accessors,
implicit string conversions, SDK serialization APIs, or cross-context
conversion. They represent authority for one immediate sink, not reusable
domain data. Repository-owned APIs enforce a retention policy: they do not
accept a terminal value for storage, logging, a REST model, another context,
or a later render pass. Haxe does not provide linear types, so this is an
audited SDK API policy rather than a claim that the language makes arbitrary
user retention impossible.

`esc_url_raw` is not an output operation. Sanitization, validation, escaping,
authorization, and nonce verification remain independent decisions. In
particular, a nonce never turns untrusted input into output-authorized markup.

### Trust and conversion graph

The source states `untrusted`, `validated`, `sanitized`, and `domain-value` do
not themselves grant output authority. A terminal conversion is selected only
at a known sink:

```text
String/domain text ---------------------------> HtmlText
String/typed attribute -----------------------> HtmlAttribute
String -- URL validator --> ValidatedUrl ------> HtmlUrl
String ----------------------------------------> TextareaText
String + named native/exact custom KSES policy > KsesHtml<policy>
T + ContractCodec<T> --------------------------> JsonDocument<T>
T + ContractCodec<T> --------------------------> HtmlScriptData<T>
TypedCssDeclaration[] -------------------------> InlineStyle
TypedCssRule[] --------------------------------> Stylesheet
resolved typed HXX AST + source span ----------> CompilerMarkup
admitted provider + exact typed contract ------> ProviderMarkup
```

Every arrow terminates at its named sink. There are no arrows between the
terminal types. In particular, `HtmlText` cannot become `HtmlAttribute`,
`JsonDocument<T>` cannot become `HtmlScriptData<T>`, and `KsesHtml` cannot
become `CompilerMarkup`. Rich HTML records the policy kind, identity, and
version. A custom policy additionally binds the element/attribute allowlist and
explicit protocol set by digest. A server KSES result cannot cross into the
browser as a raw-HTML proof.

Provider-owned markup is admitted only through an exact compatibility-profile
capability, provider version, typed contract, and evidence receipt. The native
plugin remains the runtime owner. Plugin recognition never creates an ambient
trusted-string constructor.

### HXX inference and developer ergonomics

The normal authoring surface stays direct:

```haxe
public static function render(model:TodoView):ServerMarkup {
  return <article aria-label={model.label}>
    <h2>{model.title}</h2>
    <a href={model.detailsUrl}>Open task</a>
  </article>;
}
```

The HXX resolver knows the syntactic position before lowering. Its closed
position graph inserts the
text operation for an ordinary child, attribute escaping for an ordinary
attribute, textarea handling for textarea content, and the URL path for
`href`, `src`, `action`, and `formaction`. A static URL literal is checked at
compile time; a dynamic URL must already satisfy the typed validator. Style
positions accept only typed CSS declarations. Rich-content and script-data
positions require their explicit terminal contracts. Server inline event
attributes are rejected; browser event positions accept typed callbacks.
Nested-document `srcdoc`, URL-list `srcset`, SVG/MathML namespace attributes,
raw `style`, `script`, `iframe`, and `textarea` children, and non-literal
position names fail closed until a dedicated typed grammar is admitted.

The exact compiler-generated fragment class creates `CompilerMarkup` only
after resolving and typing the HXX AST, retaining fragment identity, source
span, structural digest, and typed contextual segments. Application code
cannot call that private constructor or supply its own provenance. The PHP and
React probes lower the same generated tree and apply text, attribute, and URL
operations according to each typed segment. The constructor never accepts a
string that happens to contain markup. This keeps the common `return <markup>`
path dense while making unusual trust transitions explicit and searchable.

### JSON is data until its final embedding context

A WordPress REST callback returns typed data or a `WP_REST_Response`; it does
not HTML-escape the domain payload. The response encoder owns JSON document
encoding. Embedding the same domain value inside an HTML script element is a
different operation and requires `HtmlScriptData<T>`. Both paths use the same
ADR-009 `ContractCodec<T>`, but their output terminals are intentionally
incompatible. An encoding failure is represented and handled; `false` from
`wp_json_encode` cannot silently become an empty response or markup fragment.

Executable inline JavaScript is not a normal HXX output context. WordPress
script registration/enqueue APIs and module assets are preferred. The script
data context is for non-executable, schema-owned data consumed by an admitted
asset.

### Rich markup and policy identity

KSES is policy sanitization, not universal trust. The SDK exposes named
WordPress policies such as post content and data markup, plus exact custom
allowlists. Native named policies are profile-bound but may remain filterable
by ordinary WordPress runtime code; their brand describes that observed native
semantics and does not pretend the effective allowlist is content-addressed. A
custom policy binds its complete element/attribute allowlist and an explicit
protocol set by digest. Changing either creates a new version and identity.
The policy operation remains at the final native sink.

Browser rich HTML is deliberately not implemented by reusing a server policy
brand. A later browser policy must declare its own implementation, dependency
lock, vectors, and relation to the server policy. Until then, browser HXX uses
normal typed children and React escaping, and no public
`dangerouslySetInnerHTML` equivalent exists.

### Raw and trusted construction

ADR-012 publishes no general raw-markup constructor. ADR-019 may define a
narrow unsafe waiver only if it records a stable waiver ID, exact source hash,
owner, reason, expiry, review, and removal gate. The compiler and repository
gates must make every such use searchable. A waiver will not convert one safe
context to another or imply production support.

The only non-waiver trust constructors are:

- a compiler-resolved typed HXX AST with source provenance;
- a named, versioned native KSES policy or a content-addressed custom KSES
  policy with explicit protocols;
- an exact-profile admitted native provider with a typed contract and receipt.

### Layer ownership

The generic PHP compiler may own neutral output-context IR, context tags, and
native-call emission hooks. It must not contain WordPress policy names or
plugin branches. The WordPress compiler/profile owns mappings to `esc_html`,
`esc_attr`, `esc_textarea`, `esc_url`, KSES, JSON flags, block callbacks, admin
helpers, and asset APIs. Genes owns browser TypeScript output; WordPressHx owns
the typed HXX/context semantics passed to it. This preserves a usable generic
PHP-only compiler while letting the SDK optimize the WordPress happy path.

## Rationale

Nominal terminal types let Haxe reject cross-context reuse before either PHP
or TypeScript exists. Late native lowering retains WordPress compatibility and
lets the generated PHP stay recognizable to WordPress developers and security
tools. Position-driven HXX inference removes routine ceremony without hiding
the security boundary. Keeping JSON document and script data separate closes a
common server-rendering gap, while policy-branded rich markup prevents a KSES
allowlist from silently becoming global trust.

The result also supports the reference architectures consistently: a native
theme, a Gutenberg block, a Genes SPA, a NextJsHx renderer, and a BFF can share
domain contracts while each retains its own final rendering authority.

## Alternatives considered

### One `SafeHtml` or `EscapedString` abstract

Rejected. It is compact but cannot represent the grammar that made the value
safe. Implicit conversion makes accidental reuse easy, and early escaping
conflicts with WordPress's late-escaping guidance.

### Escape every string as HTML text

Rejected. Text escaping is wrong for URLs, script data, CSS, textarea content,
and rich markup. It produces both security gaps and avoidable double encoding.

### Trust React and WordPress to infer everything at runtime

Rejected. React escapes ordinary children and attributes but is not the URL or
rich-markup policy authority. PHP templates are otherwise stringly typed, and
the error appears only after generation. The HXX compiler already knows the
position and can reject incompatible values earlier.

### Sanitize once on input and persist the result

Rejected. Input policy and output grammar answer different questions. A stored
sanitized value can later enter an attribute, JSON, email, feed, or browser
context that needs a different operation. Persisted values remain domain data.

### Publish a raw escape immediately

Rejected for this decision. An easy raw API would undermine the typed default
before waiver ownership exists. ADR-019 must establish governance and negative
gates first.

### Defer output safety until production HXX lowering

Rejected. SDK-052, server HXX, blocks, examples, and provider adapters would
otherwise grow around incompatible assumptions. The type and trust graph must
precede their public APIs.

## Consequences

Positive consequences:

- ordinary inline HXX remains concise while dangerous context changes become
  compile errors;
- server PHP uses native WordPress functions at inspectable final sinks;
- browser code can rely on React only for the contexts React actually owns;
- native, SPA, SSR, BFF, and dual-delivery examples can share contracts without
  sharing unsafe rendered strings;
- provider adapters and future raw waivers have explicit admission seams.

Costs and constraints:

- the compiler must retain exact HXX position and source provenance through
  lowering;
- rich HTML needs separately evidenced server and browser policies;
- terminal values cannot be cached or serialized as a convenience;
- typed CSS initially supports a deliberately closed property/value subset;
- each new output grammar requires a new terminal contract, native mapping,
  negative fixtures, and runtime evidence rather than another string alias.

## Evidence and commands

The corrected bounded prototype is in
[`fixtures/output-context`](../../fixtures/output-context/README.md). Its
terminal constructors are private, compiler markup is owned by an exact
generated fragment class, and it contains no repository-forbidden weak Haxe
operation. Twenty-seven compile-negative fixtures cover cross-context
substitution, direct construction, and the closed HXX rejection categories.
One canonical native-runtime plan is byte-identical on Haxe 4.3.7
interpretation, Genes 1.41.4 plus TypeScript 5.9.3/Node 22.17.0, and
stock-Haxe PHP 8.4.7.

The React and WordPress probes consume that exact Haxe-generated plan and
return its digest, connecting typed terminals to the tested native sinks. The
runtime corpus checks React DOM Server 18.3.1 and a clean pinned WordPress
7.0/MariaDB installation. The WordPress probe exercises text, attribute,
textarea, accepted and adversarial URLs, two native and two canonical
digest-bound custom KSES policies, successful and failed JSON codecs,
script data, a native dynamic-block callback, a REST response, and
`wp_admin_notice`. The browser probe exercises the same plan through React
text, attribute, textarea, validated URL, typed inline CSS, stylesheet output,
compiler provenance, and script-data behavior without a raw-HTML API.

```bash
python3 scripts/output-context/validate-architecture.py
bash scripts/output-context/test.sh
bash scripts/check-repository.sh
```

The independent Python validator authenticates the fixture tree and expected
transcript, asserts the complete context/conversion model, and rejects
thirty-six mutations. The combined gate is configured as the `output-context`
job in the focused output-context workflow. Hosted evidence and a fresh
independent review are separate gates. Historical public run
[`29713766565`](https://github.com/fullofcaffeine/wordpresshx/actions/runs/29713766565),
job `88262490140`, passed the complete corpus at commit
`11ec7cc273ca65130c1fcd79505347390dba3d9a`; it predates and is superseded by
the Oracle corrections. Corrected commit
`60e0516db0b1542e7eeba9da02254e115b1abaab` passed public run
[`30221651100`](https://github.com/fullofcaffeine/wordpresshx/actions/runs/30221651100),
job `89845003958`. Fresh independent rereview remains required before this ADR
can move to accepted. The second correction pass at commit
`68e5effa9d9a07163eafbd08864ccc872f76e0ad` passed public run
[`30222742845`](https://github.com/fullofcaffeine/wordpresshx/actions/runs/30222742845),
job `89847822705`.

The design follows the official
[WordPress escaping guidance](https://developer.wordpress.org/apis/security/escaping/),
the [`wp_kses_post` contract](https://developer.wordpress.org/reference/functions/wp_kses_post/),
and the [`wp_json_encode` contract](https://developer.wordpress.org/reference/functions/wp_json_encode/).
The manifest records exact commits, blobs, and hashes for the WordPress,
WordPressHx-port, RailsHx, and PhoenixHx patterns reviewed. No source or fixture
bytes were copied and no sibling runtime dependency was created.

## Migration, rollback, and supersession

Because the production types are not implemented yet, rollback means removing
the prototype, validator, workflow job, and proposed record together. Once
SDK-052 publishes types, a change that weakens a terminal boundary, adds a
cross-context conversion, or changes a native lowering requires a superseding
ADR, migration diagnostics, and exact-profile evidence. Strengthening a URL or
rich-markup policy can reject previously accepted input and therefore also
requires a versioned policy and compatibility note.

## Follow-up beads

- `wordpresshx-adr-019`: define unsafe-boundary waivers, audit ownership, and
  enforcement before any raw output API exists.
- `wordpresshx-sdk-052`: implement production output-context types, HXX
  resolution, WordPress lowerings, and diagnostics.
- `wordpresshx-sdk-081`: integrate safe native server HXX lowering.
- `wordpresshx-sdk-083`: prove templates, blocks, REST, and admin behavior in a
  complete Haxe-authored site.
- `wordpresshx-sdk-117`: admit exact provider versions before provider markup
  adapters can be used by examples.
- `wordpresshx-sdk-plan.4`: validate immutable review prompt paths against the
  exact archived packet inventory before dispatch.

## Independent Oracle review

The content-addressed GPT-5.6 Oracle review dated 2026-07-26 returned
**changes required**. The authoritative details are in
[`ORACLE-REVIEW.md`](../../review/oracle/results/ORACLE-REVIEW.md) and
[`adr-decisions.json`](../../review/oracle/results/adr-decisions.json).

Remediation bead `wordpresshx-g4.1` owns ADR012-F001 through ADR012-F009. It
must close every security-sensitive HXX position, connect typed terminals to
real PHP/browser lowerers, make compiler-markup construction compiler-owned,
retain executable JSON codec/failure authority, separate CSS grammars,
implement content-addressed custom KSES policy, strengthen browser negatives,
remove exact-tool drift, and state non-cacheability as an enforceable policy
rather than a linear-type guarantee.

The first correction pass was independently rereviewed from immutable packet
`c39ed85e6b293357cc74c82b835a8fd9650fd21c2b91231a42c2229e93dc5676`.
That rereview closed F002, F004, F007, F008, and F009, but kept F001, F003,
F005, and F006 open: namespace/ancestor state was incomplete, compiler markup
did not retain a typed AST, CSS property/value combinations remained
interchangeable, and the custom KSES document did not drive the native
allowlist.

The second correction pass makes namespace state explicit and rejects unknown
attributes, unknown children, and void-element children; retains a
content-addressed typed markup AST lowered by both runtimes; uses distinct
property-specific inline and stylesheet enums/printers; normalizes policy
duplicates; and derives the exact `wp_kses` allowlist and protocols from the
Haxe plan. This ADR remains unaccepted until those changes pass hosted evidence
and a fresh Oracle rereview.

The second rereview closed F001, F003, and F005, leaving only F006 open. It
demonstrated that public mutable policy arrays could be changed after their
digest was computed. The final correction stores policy semantics only as
private final booleans and immutable strings; neither the custom policy nor its
terminal exposes rules, attributes, or protocol arrays. The sink derives fresh
JSON arrays from that immutable representation, and a compile-negative fixture
proves post-hash mutation is inaccessible. The immutable-policy correction at
commit `4d403cdb33ff2ce6e7da196e1062163e15c9e302` passed public run
[`30223402796`](https://github.com/fullofcaffeine/wordpresshx/actions/runs/30223402796),
job `89849614666`.

The final independent rereview examined immutable evidence commit
`e51dbaadb3ba8dfc4edb145834fb7316b82501a9` from packet
`43d6db1c63a60c8e6d0d96cfe1ac7492df0641f1b163707fdd65ea5ded0cad07`.
It independently reproduced the inaccessible post-hash mutation, varied every
custom-policy identity component against its emitted plan, and accepted the
bounded ADR-012 architecture with F001 through F009 closed. The exact decision
is in
[`ORACLE-FINAL-REREVIEW.md`](../../review/oracle/results/adr012-final-e51dbaa/ORACLE-FINAL-REREVIEW.md).
Its sole new finding, ADR012-R3-N001, is non-blocking: five paths in the review
prompt were stale, while the actual manifest-bound prototype paths existed,
matched their receipt hashes, and were reviewed. Future review prompts must be
validated against their packet path inventory.

The combined independent rereview of commit
`76a90da1639aa28e163c1713067274323e5b4db2`, returned on 2026-07-27,
reopened F004. `TodoCardCodec` rejects only NUL and the fixture-local
`PlanJson.quote` does not escape every JSON-forbidden C0 control. The sink can
therefore brand bytes as successful JSON even though PHP
`JSON_THROW_ON_ERROR` and JavaScript `JSON.parse` reject them. The earlier
acceptance remains useful historical evidence for F001–F003 and F005–F009, but
it no longer establishes the codec/native-boundary invariant. P0 remediation
bead `wordpresshx-g4.1.1` owns a standards-compliant shared codec path,
cross-target control/Unicode/depth/failure vectors, and a fresh
content-addressed rereview. See the
[combined review integration](../../review/oracle/results/combined-rereview-76a90da/INTEGRATION.md).

The next content-addressed GPT-5.6 Pro rereview examined repair commit
`0e01ab5e18fe023e43f2d45e1052bdccef658f05` and again returned
**changes required**. It confirmed the C0 codec path itself was repaired, but
found an equivalent public `JsonPlan.success(schemaId, encoded)` bypass plus
two narrow ADR-009 encoder defects: leaf-dependent container depth and
non-total malformed-value handling. The current correction makes successful
plan construction private and sink-owned, adds all-target compile negatives,
and uses the hardened checked encoder described by ADR-009. F004, ADR-009, and
ADR-012 remain open pending fresh content-addressed acceptance. See the
[exact rereview and integration](../../review/oracle/results/adr012-f004-rereview-0e01ab5/INTEGRATION.md).

The final rereview of correction commit
`552c7affabe16af9a1976cf6393ed34f4ba31a2b` also returned **changes
required**. It accepted the hard 64-container depth correction,
validate-before-sort behavior, immutable snapshot, C0 escaping, and removal of
the ordinary `JsonPlan.success` factory. It found three remaining blocking
paths: an empty codec failure creates the same paired-empty-string shape used
as success; Haxe `@:privateAccess` can override the private plan constructor;
and null boolean/integer payloads silently become successful JSON. The
maintained malformed corpus also omits Genes/strict TypeScript, while the
public `JsonEncoded(String)` documentation overstates a forgeable enum variant.
Independent local reproduction confirmed the three blocking paths across the
available Haxe, Genes, JavaScript, and PHP lanes. F004 remains open; unrelated
retained ADR-012 findings remain closed. See the
[bound response and local disposition](../../review/oracle/results/adr012-f004-final-rereview-552c7af/INTEGRATION.md).

The next local repair replaces the paired empty strings with a closed plan
state. A plan is now encoded or rejected. An empty codec error becomes the
stable rejection `codec-rejected-without-reason`; it cannot become success.
Consumers can inspect a plan only through `fold`. They cannot pass raw JSON to
a public success factory.

A compiler-profile guard runs after Haxe typing. It rejects any direct
`JsonPlan` construction outside `OutputSinks`, including construction exposed
after normal macro expansion and `@:privateAccess`. The next independent review
correctly found that the first guard inspected ordinary fields and statics but
omitted instance constructors and the class initialization expression. It also
found that `Type.createInstance` remained available. The repaired guard visits
fields, statics, constructors, and class initialization. The admitted profile
now rejects reflective `Type.createInstance` access, including aliasing the
function before use. Arbitrary untrusted compiler macros remain outside this
bounded claim. The all-target negative fixtures pin these diagnostics for Haxe
interpretation, Genes with strict TypeScript, and generated PHP.

The focused repair started with three red observations: a null boolean became
the JSON bytes `false`, an empty codec failure produced an ambiguous plan, and
the private constructor bypass compiled. The same tests now pass or fail at the
intended boundary. The architecture state is
`final-rereview-findings-repaired-pending-rereview`. F004 stays open until a
fresh independent review accepts the current bytes.

The GPT-5.6 Pro review of commit
`99b5f21f2e36bef907650cd7c2b1d30d61dadfbd` returned **changes required**.
In addition to the incomplete construction traversal above, it found that the
checked JSON encoder trusted a valid foreign enum index without verifying its
constructor identity, and that the current receipt overstated a WordPress lane
that Docker had not run. All three findings were reproduced locally and
repaired. The receipt now distinguishes historical WordPress runtime proof from
the current unexecuted lane. This remains a local correction, not acceptance;
F004 stays open until a fresh independent review accepts the corrected commit.
See the [review and local disposition](../../review/oracle/results/adr012-f004-final-repair-99b5f21/INTEGRATION.md).
