# Ordinary Haxe WordPress consumer

This is the first small end-to-end proof that WordPress can consume PHP emitted
from ordinary application Haxe. The application is intentionally easy to read:

```haxe
package wordpress_consumer;

import wordpress.hx.wordpress.TextOptions;

class Main {
	public static function main():Void {
		TextOptions.set("wordpresshx_reflaxe_consumer", "ordinary-haxe");
	}
}
```

`TextOptions` is a typed, text-only view of WordPress' public `update_option`
function. The application writes no PHP and imports no `PhpExpr`, `PhpStmt`, or
other backend IR. The generic compiler recognizes only a reusable validated
native-function annotation; the WordPress-owned fixture facade remains outside
the generic compiler and the package topology stays in `compiler/wordpress`,
preserving the one-way dependency:

```text
compiler/reflaxe.php <- compiler/wordpress
```

## Run the package proof

From the repository root:

```bash
bash compiler/wordpress/scripts/test-reflaxe-wordpress-consumer.sh
```

This compiles twice, compares the authenticated module graphs, compares the
manually authored generated-PHP expectation, builds the plugin ZIP twice, and
checks its exact inventory. The package manifest deliberately continues to say
that WordPress runtime compatibility is not claimed.

## Run the WordPress proof

With Docker available:

```bash
bash compiler/wordpress/scripts/test-reflaxe-wordpress-consumer-runtime.sh
```

This starts a fresh checksum-pinned WordPress 7.0/MySQL site, installs and
activates the clean ZIP, observes the text option on activation and a fresh
request through native WordPress APIs, then deactivates and deletes the plugin.
Warnings, fatals, activation errors, unexpected output, an absent native
function, a wrong value, or leftover plugin files fail visibly.

The compiler-adapter, package-install, and WordPress-runtime results are kept as
separate scorecards. This fixture proves one text-option call only. Hooks,
callbacks, arbitrary option values, a public PHP ABI, broad WordPress
compatibility, and production support remain separate work.
