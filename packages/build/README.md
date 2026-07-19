# Build and semantic-plan module

`packages/build` owns the SDK's compile-time declaration collector. It is part
of the single lockstep `wordpress-hx` Haxelib; it has no independent package or
runtime identity.

Application code declares WordPress facts through typed Haxe calls:

```haxe
Module.plugin({
	id: "acme-observatory",
	name: "Acme Observatory",
	version: "0.1.0",
	namespace: "Acme\\Observatory"
});

Hook.action({
	id: "register-visits",
	module: "acme-observatory",
	name: "init",
	callback: registerVisits,
	priority: 10
});

// The common local WordPress service needs no duplicated command or config.
Dev.wordpress();
```

Typed `WordPressDevelopmentOptions` override only non-default behavior. Services
without a dedicated SDK adapter use the explicit `Dev.service({...})` escape
hatch, whose component must exist in the exact project lock and whose command
is argv-based rather than an implicit shell string.

The generated HXML installs `SemanticPlan.install(...)`. Declarations expand
to `null` markers and are removed by normal DCE; the collector writes only a
canonical intermediate semantic plan and its effective-input report. It does
not write PHP, JavaScript, metadata, or live project output.

The v1 collector deliberately accepts only literal, printable-ASCII contract
strings. This fail-closed subset is already NFC-stable. A future widening to
arbitrary Unicode must add an independently proven NFC implementation without
changing canonical JSON v1.

Extension node kinds are admitted only through a versioned typed collector,
an exact locked node schema, and compatible emitter registrations. There is no
public `Dynamic` node or runtime plugin escape hatch.
