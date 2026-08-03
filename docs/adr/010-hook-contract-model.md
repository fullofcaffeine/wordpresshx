# ADR-010: Hook contract model

- Status: proposed
- Date: 2026-08-02
- Owners/reviewers: Marcelo Serpa (product owner and PRD authority), Codex (architecture and WordPress 7.0 source review); independent compatibility review pending
- Bead: `wordpresshx-adr-010`
- Profiles/layers: `wp70-release` built-in hooks, project/third-party hook contracts, server authoring API, semantic plan, WordPress PHP profile
- Decision lock: [`manifests/hook-contract-decision.json`](../../manifests/hook-contract-decision.json)
- Supersedes: none; refines ADR-005, ADR-006, and ADR-008 for hook registration/removal
- Superseded by: none

## Context

WordPress actions and filters share the native `WP_Hook` engine, but they do not
have the same application contract. An action reports an event and ignores the
callback return. A filter passes a value through a callback chain and each
callback's return becomes the next value. WordPress also exposes observable
priority ordering, same-priority insertion order, accepted-argument truncation,
callback identity, removal results, and dynamic hook names.

A generic event bus would hide those facts. So would an API that accepts an
arbitrary hook string, callback, integer, and `accepted_args`: it would merely
rename `add_action` and `add_filter` without using Haxe to rule out invalid
combinations. At the other extreme, a closed priority enum or finite catalog of
literal hook names would reject valid WordPress behavior and make custom and
dynamic hooks second-class.

The exact WordPress 7.0 source lock identifies commit
`26b68024931348d267b70e2a29910e1320d0094f`. In that source,
`add_action` delegates to `add_filter`; `WP_Hook` sorts numeric priorities in
ascending order and preserves insertion order within a priority; callback
invocation passes no arguments when `accepted_args` is zero, all arguments when
the count is large enough, and an ordered prefix otherwise. Removal uses the
same callback identity and exact priority used at registration. String,
object/closure, object-method, and static-method callbacks receive different
native identity construction.

The repository already contains useful but bounded implementation evidence:
the SDK-040 collector distinguishes actions and filters, infers callback arity,
requires `Void` for actions, and requires a filter to accept and return its
first value type. SDK-023 emits native `add_action`/`add_filter` calls and has a
real WordPress 7.0 action/filter fixture. Those slices do not define typed
truncation, custom/dynamic provenance, public priorities, removal, or
same-priority order. They cannot be treated as the complete SDK-050 contract.

During this decision, a real mismatch was found: semantic hook schema v1 and
the SDK-040 collector rejected negative priorities even though WordPress accepts
signed integer priorities. The focused fixture was first observed red with
`WPHX4017`; hook schema v2 removes that false restriction while preserving v1
as historical contract evidence. This fix does not by itself establish the
complete public hook API.

## Decision

### Hook references preserve WordPress meaning

The public typed layer uses separate references:

```haxe
ActionHook<Args>
FilterHook<Value, ExtraArgs>
```

`Args` and `ExtraArgs` are closed ordered argument products generated from an
exact-profile contract. This notation does not require application authors to
construct tuples manually; SDK-050 may expose arity-specific helpers or generated
methods as long as the compiler sees every position and no weak carrier enters
the public API.

An action callback returns `Void`. WordPress ignores action returns, so exposing
a returned value would create false data flow. A filter callback accepts the
filtered value in position zero and returns the same Haxe type. Additional
arguments are ordered and typed but are not returned. Nullable or branded value
types remain exactly as declared by the hook contract.

A built-in reference exists only when the selected exact profile contains the
hook and a reviewed typed contract has established action/filter kind, ordered
arguments, returned value, maximum documented arguments, provenance, and
evidence state. Inventory alone does not generate a stable wrapper. Ambiguous
signatures are omitted or kept experimental under ADR-008.

WordPress's special `all` hook has name-first/variadic behavior that does not fit
ordinary action references. It is withheld until a separate typed contract and
runtime proof exist; it must not be approximated by a broad callback.

### Accepted arguments are inferred and prefix-safe

The normal `listen`/`map` call infers native `accepted_args` from the statically
known callback arity. The inferred count must not exceed the hook contract's
maximum. An action may infer zero. An ordinary filter must accept at least the
filtered value, so zero-argument filters are rejected even though the native
engine can invoke a zero-argument callback.

Passing a smaller integer beside a wider callback is forbidden. Intentional
truncation uses an explicit typed prefix helper. That helper exposes a callback
whose Haxe arguments are exactly the selected prefix, records the matching
native count, and cannot skip or reorder positions. A count larger than the
contract or callback is a source-positioned compile error. SDK-050 owns the
exact ergonomic spelling and compile-negative matrix.

### Priority is branded, signed, and open-ended

`Priority` is an abstract over the complete signed Haxe `Int` domain, not an
enum. It supplies conventional presets:

| Preset | Value | Meaning |
| --- | ---: | --- |
| `Priority.Earliest` | `-100` | earliest SDK convention |
| `Priority.Default` | `10` | WordPress native default |
| `Priority.Late` | `100` | late SDK convention |

The preset names are conveniences, not bounds. `Priority.of(-1000)` and other
signed `Int` values remain valid after compile-time construction. The SDK makes
no claim that `Earliest` is the lowest value WordPress or PHP can represent.
Target-native integers outside Haxe's portable `Int` domain are not silently
rounded; a future target-specific escape requires its own typed boundary and
evidence.

Lower priorities execute first. Same-priority callbacks execute in registration
order, so that order is semantic plan data rather than an accidental consequence
of node-ID sorting, filesystem traversal, or emitter iteration. SDK-050 must add
and prove the explicit sequence representation before it claims tie ordering.

### Removable registrations retain native identity

The ordinary removable path uses a declared named function, declared static
method, or SDK-generated static method. Registration returns a typed
subscription/registration value that owns:

- the exact hook kind and resolved name;
- the exact native callback identity;
- the exact priority used for registration; and
- the selected profile/contract identity needed for diagnostics.

Removal emits or invokes ordinary `remove_action` or `remove_filter` with the
same callback and priority and returns the native `Bool`. `accepted_args` is not
part of WordPress's removal key. Changing priority is modeled as removal at the
old priority followed by registration at the new priority. Failure is preserved
as `false`; the SDK does not turn it into `Void` or unconditional success.

Anonymous callbacks whose stable identity cannot be retained are admitted only
through an explicit `PermanentListener`. That value has no removal API and makes
the lifecycle cost visible at the call site. The public happy path must not
promise removal for a reconstructed closure or object.

### Custom and dynamic hooks are typed contracts

A project-owned custom hook is declared through a versioned, content-addressed
typed project contract. A third-party hook is supplied by the ADR-015 adoption
bundle. Both record owner, kind, ordered argument types, filter return type,
maximum arguments, contract version/digest, and content-bound declaration or
source provenance. A consumer cannot upgrade an inventoried name into a typed
contract merely by choosing Haxe types at the call site.

A dynamic hook such as `save_post_{$postType}` is represented by a generated
pattern constructor with typed and validated segments. The constructor owns the
literal scaffold, segment encoding/validation, resulting action/filter contract,
and provenance. Arbitrary runtime concatenation produces no supported hook
reference. A low-level native extern may remain available as an explicitly
classified escape, but it cannot advance stable or runtime-tested hook claims.

### Emission stays native and ordered

The WordPress profile emits ordinary `add_action`, `add_filter`,
`remove_action`, and `remove_filter` calls. Hook names are literals from an exact
contract or results of an admitted typed pattern. Public callbacks are native PHP
callables with readable names and source correlation under ADR-005/ADR-014.

Registration order for equal priorities must survive collection, canonical plan
serialization, lowering, and PHP execution. A canonical sort used for byte
determinism may not become execution order unless it is sorting an explicit
sequence key. Native WordPress failures, warnings, callback exceptions, and
`false` removal results remain observable.

### Evidence boundaries

This ADR selects the architecture. It does not claim the SDK-050 authoring API,
custom-contract generator, dynamic patterns, removals, or full hook runtime
matrix are implemented. Current evidence is separated as follows:

- signed priority collection through hook schema v2: focused local compile
  evidence;
- static action/filter registration and value transformation: bounded historical
  SDK-023 WordPress 7.0 evidence;
- priority order, tie order, accepted-argument permutations, removal success and
  failure, permanent listeners, custom hooks, and dynamic patterns: not tested,
  owned by `wordpresshx-sdk-050`.

No publication, broad WordPress compatibility, or production-support state is
advanced by this decision.

## Rationale

Separate action and filter types turn the most important WordPress distinction
into a compiler error while still mapping directly to native calls. Arity
inference removes repetitive `accepted_args` without hiding truncation. An
explicit prefix adapter makes intentional truncation readable and type-checked.
An open signed priority preserves real WordPress ordering instead of pretending
three common values are exhaustive.

Stable static/named identities give removal a direct native meaning. Marking
unremovable callbacks permanent is more honest than returning a subscription
that cannot work. Versioned project/adoption contracts and generated dynamic
patterns let the API grow beyond built-ins without accepting arbitrary strings
or guessed types.

The design patterns consulted in `haxe.elixir.codex` and `haxe.ruby` reinforce
closed typed framework contracts, deferred validation, and generated ergonomic
surfaces, but neither repository supplies a WordPress hook model. The complete
port in `wordpresshx-port` supplies useful compatibility-oracle scenarios for
priority, accepted arguments, removal, `all`, references, and hook stacks. No
sibling code or fixture bytes are copied and no sibling checkout becomes a
build dependency.

## Alternatives considered

### Expose typed wrappers over raw hook strings

This is easy to implement and remains close to WordPress. It is rejected for the
authoring layer because action/filter kind, ordered arguments, returned value,
maximum arity, dynamic-name grammar, and provenance would remain caller claims.
It may exist only as an extern/unsafe boundary with appropriately narrow claims.

### Use one generic event bus

A framework-neutral `Event<T>` could look familiar outside WordPress. It is
rejected because filters transform values, removal uses native callable identity
plus exact priority, accepted arguments truncate positionally, and native order
and failures are public behavior. Hiding those rules would reduce compatibility
and diagnostic quality.

### Use a closed priority enum

Three named priorities would be concise. It is rejected because WordPress
accepts arbitrary signed integers and plugins routinely coordinate with values
outside three presets. The branded `Int` retains discoverable constants without
a false closed-domain claim.

### Treat every listener as removable

Retaining runtime closure objects can sometimes make removal work in one request.
It is rejected as the default contract because reconstruction, reload, generated
code, and lifecycle boundaries can change object identity. Removability is
promised only for forms whose exact native identity the SDK owns.

### Generate dynamic hook names by string interpolation

Interpolation is compact but cannot prove segment validation, action/filter
kind, or argument contract. Generated typed pattern constructors are selected.

### Defer the decision and keep the current collector shape

The existing collector and adapter fixture could support more examples quickly.
It is rejected because the false nonnegative priority restriction and missing
tie/removal/truncation semantics would become accidental public architecture.

## Consequences

Positive consequences:

- invalid action/filter return shapes and excessive arity fail during Haxe
  compilation;
- common hook registration needs no handwritten `accepted_args` or PHP;
- negative and custom priorities remain available;
- removal either maps to a stable native identity or is visibly permanent;
- custom and dynamic hooks can grow without weak types or arbitrary strings;
- generated PHP remains ordinary, debuggable WordPress code.

Costs and constraints:

- profile contracts must curate ordered arguments and filter return types, not
  just inventory names;
- same-priority order needs explicit semantic plan data;
- typed prefix truncation requires generated arity-specific APIs or equivalent
  compiler support;
- stable removal restricts the ordinary callback forms;
- dynamic patterns and third-party contracts require provenance and versioning;
- `all` remains withheld until its special variadic behavior is modeled.

## Evidence and commands

Independent behavior authority:

- exact WordPress 7.0 `src/wp-includes/plugin.php`, blob
  `0ca495b6f76d44986ae3725973b525aa65fffe32`, SHA-256
  `2e06902ae7d65d7dad37cbafd8e8feff83e4aeeff3a7839885ce7fe4f0c94d68`;
- exact WordPress 7.0 `src/wp-includes/class-wp-hook.php`, blob
  `cd6860c0f81f2401709debb4a40f4704ef249748`, SHA-256
  `a66fe7372af72876fc702e50943f9a2a8dff4ed7394163e07491b80a06e27f1d`;
- PRD §13.2 and the exact `wp70-release` source/catalog locks;
- SDK-023 bounded native action/filter WordPress fixture;
- `wordpresshx-port` commit
  `7fdda0aa5ea66900819842aefeac6747421e9130` hook-oracle design notes, consulted
  read-only without copied bytes.

The behavior-first signed-priority scenario is:

- precondition: a Haxe-authored action declares priority `-20`;
- action: the SDK-040 macro collects and serializes the hook node;
- result: schema v2 retains `-20` and inferred `acceptedArgs: 0`;
- prior edge behavior: base commit
  `48df6023f85ffa6de4c1554ae52776ec8b9046be` plus the new fixture failed with
  `WPHX4017: hook priority cannot be negative`;
- oracle: pinned WordPress 7.0 numeric priority sorting;
- owning surface: WordPress runtime/ABI contract with a focused semantic-
  collector owner; no compiler or package claim is advanced.

Acceptance checks for the proposed record:

```bash
python3 scripts/hook-contract/check-decision.py
bash scripts/semantic-collector/test.sh
bash compiler/wordpress/scripts/test.sh
git diff --check
```

The signed-priority compiler test is a focused owner. SDK-050 must add the
tracer bullet from ordinary Haxe hook references through generated PHP to real
WordPress order, accepted arguments, transformation, and removal observations.
An independent content-addressed compatibility review is required before this
record changes from proposed to accepted.

## Migration, rollback, and supersession

Hook semantic node v1 remains readable historical evidence. V2 changes only the
priority domain from nonnegative to signed integer and is the active collector
schema. It does not add tie-order, removal, or custom-contract fields; SDK-050
must introduce the appropriate versioned node/contract rather than overloading
v2.

No public hook package has been released. Prototype callers using raw `Int`
priorities migrate to `Priority`; ordinary literal values remain source-level
simple. Prototype manual `acceptedArgs` inputs migrate to inferred arity or an
explicit typed prefix adapter. Any code assuming anonymous callbacks are
removable must choose a stable named callback or `PermanentListener`.

Rollback may restore the previous collector/schema tuple, but that also restores
the known false rejection of negative priorities and cannot satisfy ADR-010.
A superseding ADR is required to collapse actions and filters, admit arbitrary
dynamic strings, change the removal key, make priority closed, permit implicit
truncation, or broaden `all` without its own contract.

## Follow-up beads

- `wordpresshx-sdk-050`: implement the typed public API, explicit registration
  order, truncation, stable removal, custom/dynamic contracts, negative compile
  corpus, and real WordPress tracer/matrix.
- `wordpresshx-sdk-013`: extend exact profile generation with typed hook
  signature/return provenance and the required removal function capabilities;
  inventory alone remains insufficient.
- `wordpresshx-adr-015` / `wordpresshx-g6.1`: supply accepted third-party
  adoption bundles before third-party hooks can become stable typed references.
- `wordpresshx-adr-019`: govern any raw-name/native-callable escape that bypasses
  this contract.
