# ADR-015: Interop and adoption contract format

- Status: proposed
- Date: 2026-07-19
- Owners/reviewers: Marcelo Serpa (product direction), Codex (architecture and executable-fixture implementation), fresh independent review pending
- Bead: `wordpresshx-adr-015`
- Profiles/layers: PHP adoption, JavaScript/TypeScript adoption, WordPress plugins, application facades, reusable companion packages, CLI generation, runtime capabilities
- Supersedes: none; makes PRD §29.1's adoption boundary concrete
- Superseded by: none

## Context

WordPressHx must let a developer consume an existing WordPress plugin, PHP
package, browser module, or project-native extension without abandoning Haxe.
The native provider often owns both sides of an application: PHP hooks and
functions on the server, and JavaScript exports or Gutenberg components in the
browser. A useful Haxe layer therefore needs more than a handwritten extern or
a list of discovered symbol names. It needs one exact provider identity,
precise signatures, explicit omissions, runtime availability checks, and a
removal boundary that does not take ownership of the provider itself.

The risk is false precision. PHP reflection, TypeScript declarations, stubs,
package metadata, documentation, and implementation source may disagree or may
describe only part of a callable. Combining a parameter from one source, a
return type from another, and optionality from a third produces a signature
that no source actually asserted. Replacing uncertainty with `Dynamic`, `Any`,
`cast`, `Reflect`, or `untyped` would move the failure out of Haxe and into the
application. This repository forbids those weak fallbacks.

Loading a plugin merely to inspect it is also unsafe as a default. A WordPress
plugin's main file is executable PHP and can perform work as soon as it is
loaded. Static metadata is different: WordPress defines the main-file header
as plugin metadata, and its own `get_plugin_data()` implementation reads only
the beginning of the file for that purpose. Inventory must preserve that
distinction rather than treating executable source as a harmless schema.

The contract is not a trust admission. An exact version and hash identify what
was inspected; they do not establish license suitability, maintenance quality,
security, provenance, WordPress compatibility, or production support. Those
remain separate SDK-117 admission decisions with their own evidence.

## Decision

### Three closed, versioned records

Adoption uses three independent but cross-bound records:

| Record | Schema identity | Responsibility |
|---|---|---|
| Adoption contract | `wordpress-hx.adoption-contract.v1` | Exact profile/provider/generator/input identity, admitted bindings, capability references, and ownership/removal policy |
| Capability set | `wordpress-hx.adoption-capability.v1` | Exact runtime probes and the scope of conditional typed authority |
| Review report | `wordpress-hx.adoption-review.v1` | Included bindings, every omission and conflict, reflection status, evidence stage, and claims not earned |

The schemas are closed: unknown fields fail validation. Each document has a
canonical self-digest, and cross-document references bind identity, version,
and digest where doing so does not create a digest cycle. The provider is bound
to its exact version, artifact SHA-256, source revision/tree SHA-256, and exact
WordPress compatibility-profile catalog. The generator and every input are
content-addressed as well.

Contract generation is deterministic. Inputs, bindings, capabilities,
omissions, and conflicts use stable IDs and stable ordering. Regenerating the
same inputs with the same generator produces the same private staged bytes.
Publication occurs only after schema, semantic, type, and review gates pass.

### Source precedence

The generator applies this precedence, strongest first:

1. authoritative signature: provider stubs, TypeScript declarations,
   `block.json`, or an authoritative REST schema;
2. explicitly approved isolated-reflection snapshot;
3. package metadata or a source-level signature, including a statically read
   WordPress plugin header;
4. documentation metadata;
5. a curated exact contract.

The unit of selection is one complete native binding. All parameters,
requirements, passing modes, callback shapes, return type, native name, and
conditional capability for a generated binding come from one complete,
non-conflicting source record. The generator never splices fields from several
sources into a synthetic signature.

A stronger but incomplete source does not automatically prevent a lower source
from supplying a separate complete binding. However, when a stronger and a
weaker source make incompatible claims about the same native binding, the
binding is omitted and the conflict is reported. A lower-precedence source may
add a distinct, uncontested binding. A curated contract is deliberately last:
it can precisely describe a surface that has no machine-readable signature,
but it cannot silently override stronger evidence.

Every admitted type must fit the closed v1 type algebra and preserve target ABI
semantics. Unknown unions, open property bags, magic members, unsupported
callbacks, private APIs, and reference/variadic combinations that cannot be
proven are omitted. Each omission records a stable code, reason, contributing
input IDs, and required action. There is no generated broad fallback.

### Static inspection and isolated reflection

The default mode is `static-no-execution`. The generator may read provider
artifacts and source as bytes, parse declared metadata and signatures, and hash
them, but it does not include, import, require, activate, or execute provider
runtime code. For WordPress plugins this includes statically parsing the plugin
header documented by WordPress; the contract later uses normal runtime probes
to determine activation and symbol availability.

Reflection is a separate, explicit opt-in mode, not an automatic fallback. It
must run with:

- a recorded approval ID and exact image digest;
- no network;
- provider inputs mounted read-only;
- output written only to a private stage;
- content-addressed command and output;
- an isolation receipt referenced by the contract and review report.

A reflection snapshot describes only that exact isolated environment. It does
not become universal authority and does not itself advance provider trust or
runtime-support claims. If isolation or a precise result cannot be established,
the affected binding remains omitted.

### Generated Haxe surface and facades

The generator emits precise Haxe-native declarations and a thin facade over
the native boundary. The public application works with nominal provider and
capability types rather than raw symbol strings. Optional providers return a
typed availability result:

```haxe
switch runtime.probe(Calendar.provider, Calendar.read) {
	case Available(token):
		return CalendarFacade.listEvents(scope, token, query);
	case Unavailable(reason):
		return coreCalendarFallback(reason);
}
```

Only admitted bindings exist on the facade. An omitted native member has no
Haxe field, so an attempted call fails while Haxe is typing the application.
Direct capability-token construction, use with the wrong capability, and use
across scopes also fail at compile time.

The native provider remains the runtime implementation owner. WordPressHx does
not copy, fork, translate, vendor, activate, update, or uninstall the provider
by generating a contract. The facade is intentionally thin and removable. Haxe
application logic stays on the Haxe side of the same facade/module boundary, so
a native integration can later be replaced without rewriting unrelated domain
code.

### Runtime capability authority

A contract proves what was generated, not what is currently available in a
process. Before an optional provider binding is called, the runtime probes the
exact provider ID, version, artifact identity, required native symbols, and
required generated binding IDs declared by the capability set. WordPress PHP
probes may combine plugin activation with symbol checks. Browser probes check
the exact admitted module exports. Composite capabilities may require both.

A successful probe creates a nominal capability token scoped to exactly one of:

- the current PHP request;
- the current process, for an explicitly process-stable provider;
- the current browser module instance.

The token is not serializable, cacheable, or an authentication credential. It
cannot be constructed publicly, and a stale or differently scoped token grants
no authority. If any exact version, artifact, binding, or native-symbol check
fails, the whole capability is unavailable; it is never partially authorized.
An optional integration must then use its declared Haxe/core fallback. A
required integration fails with a typed, actionable startup/build diagnostic.

These probes reduce time-of-check ambiguity but do not replace authorization,
nonce verification, output-context safety, provider security review, or SDK-117
trust admission.

### Application-local and reusable provider layers

The first adoption of a provider is application-local. The consuming project
owns the generated contract/facade bytes and review of the exact provider it
uses. This keeps experimental or site-specific assumptions out of the compiler
and public SDK.

A provider layer may graduate to a separately versioned reusable WordPressHx
companion package only after repeated stable use, independent maintenance
ownership, precise contracts, and thin real-provider boundary tests. The
provider still owns its native runtime. The compiler recognizes the generic
adoption-contract mechanism only; it must never contain branches for plugin or
package names. WordPress-specific inventory/probe adapters belong in the SDK
interop layer, while neutral contract machinery may later be extracted with
the generic PHP compiler.

This follows the ownership separation reviewed in RailsHx at exact commit
`a74818e996b68e467621a76cfaae520f553c6960`:

- [`docs/railshx-gem-layers.md`](../../../haxe.ruby/docs/railshx-gem-layers.md)
  for native-runtime ownership and app-local/companion separation;
- [`docs/railshx-gem-layer-testing.md`](../../../haxe.ruby/docs/railshx-gem-layer-testing.md)
  for generated-boundary and thin real-provider testing;
- [`lib/hxruby/generators/adopt.rb`](../../../haxe.ruby/lib/hxruby/generators/adopt.rb)
  for deterministic metadata-first inventory and review markers.

The architecture manifest records the exact Git blob and SHA-256 for each
reference. No source or fixture bytes were copied and no sibling dependency was
created.

### Evidence stages and claims

Evidence advances monotonically and explicitly:

1. `inventoried`: exact metadata bytes and candidates are recorded;
2. `contract-generated`: the closed schemas, precise bindings, omissions, and
   review report validate;
3. `contract-tested`: positive/negative Haxe typing and the generated native
   ABI boundary pass;
4. `provider-runtime-tested`: the declared thin seam passes against the exact
   admitted native provider.

No earlier stage implies a later one. In particular, a contract-tested
synthetic fixture does not claim WordPress runtime compatibility, provider
trust, real-provider behavior, package-consumer behavior, or production
support. SDK-117 additionally admits exact license, security, provenance,
maintenance, and compatibility evidence before a real provider can be used in
a supported example.

### Regeneration, edits, removal, and rollback

Generation writes to a private stage and presents a deterministic diff before
publication. Generated contract and facade files are CLI-owned, separate from
Haxe application logic, and tracked by the exact ADR-007 ownership mechanism.
Modified generated bytes fail closed: regeneration neither overwrites nor
deletes them silently.

When a tool must edit an owned marker region, it first proves the exact anchor,
records the prior hash, stages the next bytes, and retains a rollback copy until
the ownership transaction commits. Missing, duplicated, or edited anchors stop
the operation.

Removing an adoption deletes only exact, unmodified manifest-owned contract and
facade bytes. It leaves the native provider, its package-manager state, user
data, WordPress configuration, and application-authored Haxe untouched. A
modified owned file blocks removal and receives a recovery diagnostic. Provider
uninstallation is always a separate, explicit native package-manager or
WordPress operation.

## Rationale

Complete-binding precedence prevents a generator from manufacturing certainty
that no source supplied. Precise-or-omitted output uses Haxe's compiler as the
earliest enforcement point and keeps review effort focused on a finite loss
report. Static inspection avoids arbitrary execution during a routine adoption
command, while a constrained reflection lane remains available for providers
whose real signatures genuinely require it.

Exact provider and capability identity makes optional plugin integrations safe
to degrade without pretending they are always installed or compatible. Keeping
the native provider as runtime owner preserves the WordPress ecosystem and
makes gradual adoption possible: applications gain a cohesive Haxe surface
without requiring a full platform port.

## Alternatives considered

### Generate broad externs with weak fallback types

Rejected. `Dynamic`, `Any`, unchecked casts, reflection, and untyped escape
hatches erase the main value of the Haxe layer and make a generated API look
safer than its evidence. Omission with a stable diagnostic is honest and
actionable.

### Merge the best field from every source

Rejected. Field-level precedence creates a Frankenstein signature no authority
asserted and can combine mutually dependent details incorrectly. Selection is
therefore per complete binding.

### Execute or activate every provider during discovery

Rejected as the default. It permits side effects, ambient-network behavior,
secret access, and machine-specific discovery. Explicit isolated reflection is
available only with a content-addressed receipt.

### Treat source code as always authoritative

Rejected. Dynamic registration, conditional declarations, filters, generated
APIs, magic members, and version-specific build output can make source parsing
incomplete or misleading. Source signatures are useful but lower precedence
than an authoritative published signature.

### Handwrite all integrations

Limited to curated exact contracts at the lowest precedence. Handwritten
facades can be excellent for a small stable surface, but without the same
provider identity, omission report, capability probes, and ownership records
they are not auditable or safely regenerable.

### Put provider-specific knowledge in the compiler

Rejected. Plugin-name branches would couple the PHP compiler to ecosystem
packages and make extraction harder. Provider knowledge belongs in generated
app-local contracts or independent companion packages over generic compiler and
SDK mechanisms.

### Port every provider to Haxe

Rejected as a prerequisite. It duplicates mature native implementations and
creates a permanent maintenance fork. WordPressHx instead ports only what is
valuable and wraps the rest behind precise Haxe interfaces; a full replacement
remains possible behind the same facade when justified.

## Consequences

Positive consequences:

- PHP, browser/Gutenberg, SPA, SSR, and BFF examples can share one provider
  identity and Haxe domain surface;
- unsupported provider shapes become compile errors and review entries instead
  of runtime surprises;
- optional plugins have typed availability and explicit fallbacks;
- provider runtime/package ownership remains conventional and removable;
- reusable integrations can emerge from proven app-local contracts without
  contaminating compiler core;
- exact hashes and staged evidence make regeneration and review reproducible.

Costs and constraints:

- useful coverage may initially be narrower than a provider's native API;
- each real provider needs exact-version evidence and maintenance as upstream
  signatures change;
- reflection, when indispensable, requires a deliberately expensive isolated
  workflow;
- runtime probes add a small boundary check and require lifecycle-aware scope
  handling;
- public companion packages require tests on both the generated boundary and a
  thin exact real-provider seam;
- SDK-117 admission remains mandatory even when contract generation succeeds.

## Evidence and commands

The bounded synthetic `Acme Calendar` proof lives in
[`fixtures/adoption-contract`](../../fixtures/adoption-contract/README.md). It
contains PHP stubs, TypeScript declarations, package metadata, and poison
provider source that would write a sentinel if executed. Static generation
admits three precise bindings and reports four omissions, including one
cross-source conflict. It does not use or execute a real provider.

The Haxe prototype has private token construction and nominal provider,
capability, and request-scope parameters. Four negative fixtures prove direct
token construction, wrong-capability use, cross-request use, and access to an
omitted member fail during Haxe typing. One canonical transcript is
byte-identical on Haxe 4.3.7 interpretation, Genes 1.36.3 plus strict TypeScript
5.9.3/Node 22.17.0, and stock-Haxe PHP 8.4.7.

```bash
python3 scripts/adoption/validate-architecture.py
bash scripts/adoption/test.sh
bash scripts/check-repository.sh
```

The independent Python validator authenticates every input, schema, fixture,
contract, capability set, review report, and architecture invariant, then
rejects thirty-one independent mutations. The focused hosted job is
`adoption-contract`. Public run
[`29716562008`](https://github.com/fullofcaffeine/wordpresshx/actions/runs/29716562008),
job `88270893309`, passed the complete corpus at implementation commit
`be8041d0d00c21d44fe2c0198e2d101c1f383908`. Hosted execution and fresh
independent review are separate gates; this ADR remains proposed pending that
fresh review.

The static WordPress metadata boundary follows the official
[plugin header requirements](https://developer.wordpress.org/plugins/plugin-basics/header-requirements/)
and [`get_plugin_data()` documentation](https://developer.wordpress.org/reference/functions/get_plugin_data/).
Runtime activation checks can use WordPress's documented
[`is_plugin_active()`](https://developer.wordpress.org/reference/functions/is_plugin_active/)
as one input to a capability probe, but activation alone never proves symbols,
artifact identity, trust, or compatibility.

## Migration, rollback, and supersession

This decision currently governs only closed schemas and a synthetic architecture
fixture. Rollback removes the proposed ADR, schemas, architecture manifest,
fixture, validator, and focused workflow together; no native provider is
changed. SDK-070 and SDK-073 must use versioned contract migrations once they
publish production generators or facades.

A change to source precedence, complete-binding selection, provider identity,
capability scope, no-execution default, weak-fallback prohibition, runtime
ownership, or removal boundary requires a superseding ADR. Additive omission
codes or type-algebra nodes require schema versioning when an older consumer
cannot reject or interpret them safely. Existing generated contracts remain
bound to their original generator and provider hashes until explicitly
regenerated and reviewed.

## Follow-up beads

- `wordpresshx-sdk-070`: implement PHP metadata inventory and the
  precise-or-omitted app-local contract generator.
- `wordpresshx-sdk-073`: implement JavaScript/TypeScript adoption and the
  browser/Gutenberg facade boundary.
- `wordpresshx-sdk-117`: admit exact open-source providers with license,
  security, provenance, compatibility, and runtime evidence.
- `wordpresshx-sdk-122`: build Todo Studio's first admitted visual-provider
  integration with a typed core fallback.
- `wordpresshx-sdk-083`: exercise the shared contracts in a complete
  Haxe-authored WordPress site.
