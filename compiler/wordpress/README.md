# WordPress PHP profile

This internal profile consumes the generic `compiler/reflaxe.php` IR and emits
WordPress-specific public PHP artifacts. The dependency is one-way:

```text
compiler/reflaxe.php <- compiler/wordpress
```

SDK-022 owns typed plugin headers, the root-file `ABSPATH` guard, deterministic
autoload inclusion, and a stable namespaced bootstrap class. SDK-023 adds a
closed native-adapter plan for actions, filters, REST routes with explicit
permission callbacks, dynamic block render callbacks, and stable PHP exports.
The profile checks callback visibility, static shape, argument and return types,
by-reference parameters, duplicate registrations, and reserved generated names
before emitting PHP.

SDK-025 projects the generic compiler's authenticated UTF-8 byte mappings into
the public WordPressHx range-map and package-index formats. A representative
five-file plugin deliberately fails through an action, REST callback,
dynamic-block renderer, and public-to-private call. The exact same adapter PHP
is exercised in development, packaged-evidence, and PHP-only production
profiles. Line-only native frames map only through unique emitter-owned trace
anchors; no nearest-line or basename lookup is allowed.

Both fixtures are Haxe-only application inputs. Their public artifacts contain
ordinary WordPress functions, callable arrays, native arrays and objects, and
readable stable classes; no application raw-PHP string, stock Haxe runtime, or
HXX runtime enters the output. The adapter fixture is exercised by an ordinary
non-Haxe PHP caller, exact PHP 7.4 and 8.4 containers, and clean WordPress 7.0
MySQL and MariaDB installs. Its runtime proof includes a native action/filter,
REST success and `WP_Error` paths, escaped dynamic-block rendering, reflection,
and by-reference mutation.

The source-correlation fixture also runs as a genuinely activated plugin on
clean WordPress 7.0 MySQL and MariaDB installs. Its native exception frames are
preserved. A deterministic production ZIP contains the five readable PHP files
and no diagnostic metadata; a separate content-bound debug companion contains
the adapter map and source index but no PHP or Haxe source. The Haxe/Genes CLI
consumer is documented in [`packages/cli`](../../packages/cli/README.md).

The compiler fixtures also pass SDK-026's pinned syntax, formatter, WPCS,
PHP-compatibility, PHPStan, duplicate-symbol, and autoload policy. In the CLI,
the same policy runs inside the complete private staging transaction and emits
an ownership-bound report; applications maintain no PHP tool configuration.
The emitted compiler manifests remain internal evidence records. They do not
claim the ADR-006 semantic-plan schema, the full typed hook/REST/block catalogs,
HXX lowering, publication, or production support. Those surfaces remain
dependency-gated.

Run the local generator, snapshot, fail-closed validation, and native-caller
gate:

```bash
bash compiler/wordpress/scripts/test.sh
bash scripts/php-quality/test-production.sh
```

Then run the exact PHP 7.4/8.4 container matrix and real WordPress 7.0 fixture:

```bash
bash compiler/wordpress/scripts/test-php-matrix.sh
bash compiler/wordpress/scripts/test-wordpress.sh
```

ADR-005 defines the public/private emission contract. Publication remains
blocked by ADR-020 and SDK-002.
