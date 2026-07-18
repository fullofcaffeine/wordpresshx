# ADR-005: Public versus private PHP emission

- Status: accepted
- Date: 2026-07-18
- Owners/reviewers: Marcelo Serpa (product owner and Haxe-first direction), Codex (compiler/interop architecture review)
- Bead: `wordpresshx-adr-005`
- Profiles/layers: `wp70-release`, generic PHP compiler, WordPress PHP profile, generated plugin/theme packages
- Decision lock: `manifests/php-emission-policy.json`
- Supersedes: none
- Superseded by: none

## Context

WordPress discovers and calls PHP through native file paths, comments, functions,
classes, callables, globals, arrays, references, include timing, and mixed
PHP/HTML templates. Those shapes are observable by WordPress, other plugins,
site maintainers, debuggers, static analysis, and ordinary PHP callers. They are
therefore part of this product even when Haxe is the maintained source.

Stock Haxe PHP remains useful for compiling ordinary private implementation
logic and for supplying proven Haxe runtime/standard-library behavior. It is not
by itself a sufficient public WordPress emitter: its runtime representations,
generated names, bootstrap assumptions, and file layout need not match the ABI
or loading shapes that WordPress expects. Requiring the custom compiler to own
arbitrary Haxe and the complete runtime before the first vertical plugin would,
however, delay the evidence that tells us which additional generic lowering is
actually needed.

ADR-004 placed a generic, structured PHP IR/printer in
`compiler/reflaxe.php/` and a separate WordPress profile in
`compiler/wordpress/`. SDK-021 proved the initial generic IR and printer on PHP
7.4 and 8.4 without claiming WordPress support. This ADR decides how the two PHP
emission lanes may compose before SDK-022 implements the first WordPress
profile.

The decision also has to preserve the Haxe-only site-authoring direction. A
developer should eventually write an ordinary typed Haxe render method such as
`return <main>...</main>`. Server HXX must lower at compile time into readable
native PHP/HTML in the public lane; it must not force a stock-Haxe template
runtime, a component registry, or handwritten PHP onto the user.

## Decision

WordPressHx adopts two explicitly classified PHP lanes with one-way adapters:

```text
typed Haxe declarations / HXX
              |
              v
    immutable semantic file/symbol plan
       |                         |
       v                         v
public native lane       private stock-Haxe lane
structured PHP IR        dependency-closed internals
       |                         |
       +---- native adapter <----+
              |
              v
 ordinary WordPress PHP, PHP/HTML, and packages
```

The public native lane is the product boundary. The private stock-Haxe lane is
a bounded implementation and migration mechanism. It is not a promised `1.0`
feature until the evidence and API-freeze decision below retain it.

### Classification is semantic and fail-closed

The build plan classifies every emitted PHP file, declared symbol, and call edge
as `public-native` or `private-stock-haxe`. Haxe visibility alone is not the
classification authority: a Haxe-private callback registered with WordPress is
still a public native boundary, while a public Haxe helper can remain an
internal implementation detail if no host consumer can reach it.

Classification defaults to rejection. The emitter must not infer that an
unclassified generated file is private, discover a public edge after printing,
or allow an opaque wrapper to make a private symbol appear native. The plan
retains the owning Haxe source span, stable artifact identity, selected profile,
boundary class, and adapter edges. ADR-006 will define the full serialized plan;
this ADR fixes the required vocabulary and invariants.

Moving a released symbol or file from public to private is a breaking public
contract change. Moving a private implementation into the public lane requires
the public evidence matrix before it can be claimed supported.

### Public native lane inventory

The following are always `public-native` when generated or owned by the SDK:

- root plugin and mu-plugin files, plugin headers, direct-access guards,
  deterministic autoload inclusion, and boot calls;
- activation, deactivation, uninstall, and upgrade registration and callbacks;
- hook registration units and every action/filter callable passed to WordPress;
- REST registration, permission, validation, sanitization, and endpoint
  callbacks;
- dynamic block render callbacks and server-render entry points;
- theme and admin template files, template hierarchy entry points, template
  parts, and mixed PHP/HTML output;
- public facade functions/classes, conditional declarations, exported PHP APIs,
  and any file another plugin/theme is expected to include;
- WordPress-discovered class names, callback arrays, global functions,
  constants, globals, asset handles, and include-time side effects;
- every adapter that crosses into a private implementation closure; and
- every generated stack entry intended to be read or called by a WordPress/PHP
  consumer.

Public files are emitted from structured `PhpFile`/PHP IR plus a typed WordPress
profile. The profile may extend generic IR with validated semantic nodes; it may
not concatenate root scaffolds or smuggle plugin headers through application
raw strings. A future unsafe raw segment is governed by ADR-019, must carry
source/provenance, owner, reason, waiver, and removal gate, and cannot replace a
routine public construct.

### Required public shapes

The public lane emits ordinary PHP 7.4-compatible shapes:

- native scalar, nullable, object, `array`, `iterable`, and `callable` values;
- indexed and associative PHP arrays, including native callable arrays;
- native functions, methods, closures, namespaces, interfaces, traits, classes,
  constants, globals, and conditional declarations;
- parameter and return references where the PHP/WordPress ABI requires them;
- stable callback identity suitable for registration and removal;
- native `WP_Error`, `WP_REST_Response`, and other provider-owned objects at the
  boundary rather than look-alike Haxe wrappers;
- deterministic `require`/`require_once`, top-level statements only in declared
  bootstrap/template plans, and no incidental output before headers;
- readable PHP names and stack entry frames correlated to Haxe source; and
- direct mixed PHP/HTML output for server HXX and WordPress templates, with
  contextual safety types selected before printing.

No stock-Haxe Boot type, collection wrapper, closure wrapper, reflection
registry, generated anonymous carrier, or mangled implementation name may
appear in a public signature or be passed directly to WordPress. Public ABI
names are explicit plan data and are protected independently from private
printer formatting.

### Representative target shapes

The exact SDK API remains the responsibility of SDK-022 and the related ADRs.
The emitted product shape is fixed by this decision.

A root plugin file is small and native:

```php
<?php
/**
 * Plugin Name: Acme Books
 * Requires PHP: 7.4
 * Requires at least: 7.0
 */

defined('ABSPATH') || exit;

require_once __DIR__ . '/vendor/autoload.php';

Acme\Books\Bootstrap::boot();
```

A WordPress callback is directly reflectable and callable by PHP:

```php
namespace Acme\Books;

final class PublicHooks
{
    public static function filterTitle(string $title, int $postId): string
    {
        return PrivateBridge::filterTitle($title, $postId);
    }
}
```

The adapter owns the representation conversion. Its public inputs and output
remain native even if the implementation closure was produced by stock Haxe
PHP:

```php
final class PrivateBridge
{
    public static function filterTitle(string $title, int $postId): string
    {
        return (string) \Acme\Books\Internal\TitleLogic::apply($title, $postId);
    }
}
```

The illustrative internal name above is not a stable API. The implementation
may change, be regenerated, or migrate into custom lowering without changing
the public callable.

A server HXX method ultimately needs no explicit rendering wrapper in ordinary
user code:

```haxe
public static function render(model:BookModel):ServerNode {
  return <article class={Styles.book}>
    <h1>{model.title}</h1>
    <WpPrice value={model.price} />
  </article>;
}
```

The generated template or callback contains proportionate PHP/HTML and native
WordPress helper calls. `ServerHxx.render(...)`-style macro APIs are prototype
or advanced compiler seams, not required user ceremony and not a runtime.

### Private stock-Haxe lane

A stock-Haxe-generated symbol is admitted only when all of these conditions
hold:

1. it belongs to one package-owned, namespaced, dependency-closed private
   implementation closure;
2. no WordPress dispatcher, hook registry, REST/block system, template loader,
   reflection consumer, include consumer, or non-Haxe PHP caller reaches it
   directly;
3. every entry edge passes through an SDK-owned `public-native` adapter;
4. the adapter immediately converts native boundary values and prevents Haxe
   collection, callable, exception, reflection, and runtime representations
   from escaping;
5. its exact stock Haxe compiler/runtime inputs, files, symbols, helpers,
   bootstrap order, byte size, and hashes are recorded in the final artifact
   manifest;
6. its complete closure passes the PHP syntax/runtime matrix, source-correlation
   checks, namespace/conflict checks, and package determinism checks; and
7. the emitted closure is private to one plugin/theme package for the MVP; no
   site-global shared Haxe runtime or implicit cross-plugin singleton is used.

The lane is forbidden for plugin/theme root files, templates, public facade
symbols, hook/lifecycle/REST/block callbacks, WordPress-discovered names, or any
consumer extension point. An adapter cannot merely forward an opaque Haxe
carrier. It must state and test the native contract on both sides of the
representation boundary.

Private names and helper formatting have no SemVer guarantee. The public
adapter ABI, artifact ownership manifest, and any intentionally published
source-correlation format do.

### Private-lane audit

Every final package using the private lane records, at minimum:

- the exact Haxe version and stock PHP target/runtime identity;
- the semantic-plan IDs of all adapters and private closure roots;
- every generated private file and declared symbol with a content hash;
- every runtime/helper file and why it was retained after DCE;
- all public-to-private and private-to-public type conversions;
- compressed and uncompressed byte totals plus bootstrap/runtime timing from
  the representative fixture;
- namespace/global-symbol conflict results across two independently generated
  plugins; and
- source-map/trace receipt IDs and the exact G1/G8 evidence receipts.

Missing inventory is a build failure, not an empty audit result. DCE may remove
unreachable private code but cannot remove a public adapter, a declared public
ABI member, or signature-reachable types required by a non-Haxe caller.

### Evidence required before support claims

ADR acceptance records architecture, not runtime support. All current PHP lane
claims remain `not-tested` except the already bounded generic IR/printer and PHP
matrix evidence owned by SDK-021.

Gate G1 must add executable evidence for:

- PHP 7.4 lint and PHP 8.4 execution of the generated plugin;
- WordPress Coding Standards and selected PHP static analysis;
- native arrays, callables, callback arity/priority/identity, `WP_Error`, and a
  by-reference boundary;
- real WordPress 7.0 install/activation and the declared lifecycle/hook/render
  behavior;
- reflection snapshots of every public name/signature and an ordinary non-Haxe
  PHP consumer calling the facade;
- an exception stack correlated from readable generated PHP to Haxe source;
- deterministic package/manifest output, private runtime inventory, size, and
  bootstrap cost;
- two-plugin namespace/runtime-conflict coverage when the private lane is used;
  and
- sign-off by at least one WordPress/PHP reviewer who did not implement the
  emitter, specifically covering readability and debuggability.

Compiler snapshots, PHP lint, mocked WordPress APIs, or Haxe-origin calls alone
cannot promote the public WordPress claim. The ordinary PHP caller and real
WordPress runtime are separate required authorities.

### Migration, retention, and removal triggers

The private stock-Haxe lane is a provisional `0.x` mechanism. Before the G8 API
freeze, a follow-up decision must choose one of:

- retain it as a documented supported private implementation profile with
  measured budgets and conflict/support evidence;
- retain it only as an explicit migration/compatibility profile outside the
  default greenfield output; or
- remove it after the custom generic compiler can lower the required private
  closure and an artifact/behavior migration fixture passes.

An individual symbol or closure must migrate to the custom native lane when it
becomes host-visible, needs more than one representation-preserving adapter,
leaks a Haxe runtime shape, prevents useful source correlation, violates the
syntax/security/static-analysis floor, creates a package conflict, or causes
measured size/bootstrap/readability budgets to fail.

The entire private lane enters removal review when its fixed runtime cost or
cross-plugin isolation dominates the representative package, its upstream
runtime cannot meet the supported PHP matrix, security maintenance cannot be
owned independently, or the custom compiler covers the admitted closure with
equal behavior and simpler packaging. No numeric budget is invented in this
ADR; SDK-022/G1 measure the baseline and ADR-018/G8 approve durable limits.

Conversely, implementation convenience alone does not justify retention. The
lane may be retained only when it remains bounded and auditable and produces a
clear maintenance/runtime benefit over custom lowering.

### Stop and rollback rules

Pause PHP feature breadth and redesign the lane if routine public output needs
pervasive raw templates, exposes Haxe runtime wrappers, cannot keep PHP 7.4
syntax, cannot produce ordinary native ABI/reflection shapes, or yields stack
frames an experienced WordPress/PHP reviewer cannot understand.

Before a public release, rollback can remove the WordPress profile and generated
fixture without changing the generic IR/printer or importing the full-port
compiler. After a release, rollback preserves the published native facade and
replaces its private implementation behind the same adapter; removing or
renaming that facade follows the normal breaking-change policy.

## Rationale

This split spends custom-compiler effort where WordPress and PHP consumers can
observe it while retaining a finite way to compile ordinary Haxe logic during
feasibility work. It also gives private implementation an honest exit: adapters
are stable seams, not permanent evidence that stock-Haxe shapes are suitable for
WordPress.

The decisive property is host-language truthfulness. WordPress should see the
same kind of file, signature, array, callable, reference, object, and stack entry
that a careful PHP implementation would expose. Haxe users keep a typed,
high-density authoring surface; PHP maintainers keep inspectable artifacts.

## Alternatives considered

### Use stock Haxe PHP for every file

This minimizes initial compiler work and maximizes stock runtime coverage. It is
rejected for public output because root headers, include-time behavior, global
functions, references, exact callbacks, native arrays, templates, and readable
host ABI would depend on wrappers or handwritten scaffolds. Stock PHP remains
the bounded private lane and semantic oracle.

### Emit handwritten PHP templates around stock-Haxe classes

This can produce a quick plugin, but string templates make names, references,
source spans, safety, ownership, and deterministic migrations invisible to the
typed plan. It is accepted only as an independently inventoried unsafe escape
under later policy, never as routine root/bootstrap/template architecture.

### Custom-lower all Haxe and runtime behavior immediately

This offers one uniform backend and could eliminate the private adapter seam.
It is deferred because arbitrary-Haxe/runtime breadth is not required to prove
the public WordPress boundary. The compiler expands only from generic fixtures
driven by real SDK needs; the private-lane removal triggers preserve this as the
preferred destination when evidence supports it.

### Keep separate handwritten PHP facades as maintained consumer source

This provides native ABI but violates the Haxe-only source-of-truth goal and can
drift from Haxe contracts. Generated native facades remain intentionally
inspectable and callable, but their authority is the typed plan and Haxe source.

### Ship one shared site-wide Haxe runtime

This could reduce duplicate bytes across multiple generated plugins. It is
rejected for MVP because WordPress loads independently versioned plugins in one
process; a shared global runtime creates order and version conflicts. Each
package is namespaced and dependency-closed until ADR-018 accepts a different
model with real multi-plugin evidence.

## Reference architecture review

The decision adapted patterns, not code, from the requested sibling references:

- RubyHx separates public source/callable/runtime ABI from private generated
  formatting, emits direct native calls without wrappers, and creates adapters
  only for genuine method-value representation boundaries.
- PhoenixHx distinguishes authoring contracts from native framework output and
  keeps framework semantics in a profile rather than the generic compiler.
- Genes separates application DCE from externally retained library surfaces,
  uses ownership manifests for generated files, and requires strict external
  consumers rather than treating a compiler pass as export proof.
- the Go/Rust/OCaml compiler references separate typed transforms, printer,
  stable runtime support, per-program glue, and narrow intrinsic escape hatches;
  they do not make large raw target strings the default compiler architecture.

The repositories remain read-only architecture references and are not inputs or
dependencies. No source was copied for this ADR.

## Consequences

Benefits:

- WordPress/PHP consumers receive ordinary native ABI and file shapes;
- Haxe authors can incrementally own private logic without waiting for an
  arbitrary-Haxe custom backend;
- adapters provide a measurable, replaceable migration seam;
- HXX can become the default server markup surface without shipping a template
  runtime; and
- public and private readiness claims can no longer be conflated.

Costs and constraints:

- the compiler/profile must preserve two code-generation and packaging paths;
- every boundary conversion and private runtime helper requires inventory and
  tests;
- duplicate private runtimes may cost bytes until evidence justifies another
  packaging model;
- public API retention must account for non-Haxe callers outside Haxe DCE; and
- the pre-`1.0` retention decision is mandatory rather than implied by early
  implementation convenience.

This ADR does not claim that SDK-022, server HXX lowering, hook contracts,
WordPress activation, source maps, static analysis, or production packaging are
implemented. Licensing and publication remain blocked by ADR-020 and SDK-002.

## Evidence and commands

Reviewed authorities:

- PRD §§13.3, 16.3, 22, Gate G1, 29.1, 29.2, and 30.6;
- ADR-001, ADR-003, ADR-004, ADR-011, and SDK-020/021 receipts;
- `../haxe.ruby` public contract and callable ABI documentation;
- `../haxe.elixir.codex` authoring/profile and native output documentation;
- `../genes` compiler contract, interop, and output-mode documentation;
- `../haxe.go`, `../haxe.rust`, and `../haxe.ocaml` compiler/runtime ownership
  references.

Acceptance checks:

```bash
python3 scripts/php/test-emission-policy.py
bash scripts/check-repository.sh
bd lint
bd dep cycles
git diff --check
```

The decision lock deliberately leaves all G1 runtime evidence `not-tested`.
SDK-022 creates the representative generated target and begins those receipts.

## Follow-up beads

- `wordpresshx-sdk-022`: implement the WordPress public PHP profile, plugin
  root/bootstrap, native adapter seam, and first private-lane inventory.
- `wordpresshx-adr-006`: serialize the semantic file/symbol/edge plan.
- `wordpresshx-adr-010`: define hook types, callback identity, priority, and
  arity over the native callable boundary.
- `wordpresshx-adr-011` / `wordpresshx-sdk-081`: lower direct-return server HXX
  through generic markup IR and the public WordPress lane.
- `wordpresshx-adr-014` / `wordpresshx-sdk-025`: define and prove PHP source and
  stack correlation.
- `wordpresshx-adr-018`: decide runtime packaging and durable size/conflict
  budgets.
- `wordpresshx-g1`: close only after the complete real WordPress/native PHP
  evidence matrix passes.
- `wordpresshx-g8`: decide private-lane retention, migration-only status, or
  removal before the public API freeze.
