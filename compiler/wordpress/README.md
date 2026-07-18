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

Both fixtures are Haxe-only application inputs. Their public artifacts contain
ordinary WordPress functions, callable arrays, native arrays and objects, and
readable stable classes; no application raw-PHP string, stock Haxe runtime, or
HXX runtime enters the output. The adapter fixture is exercised by an ordinary
non-Haxe PHP caller, exact PHP 7.4 and 8.4 containers, and clean WordPress 7.0
MySQL and MariaDB installs. Its runtime proof includes a native action/filter,
REST success and `WP_Error` paths, escaped dynamic-block rendering, reflection,
and by-reference mutation.

The emitted manifests are internal evidence records. They do not claim the
ADR-006 semantic-plan schema, ADR-007 transactional ownership, WPCS/static
analysis, a general Haxe-to-PHP driver, the full typed hook/REST/block catalogs,
private stock-Haxe packaging, HXX lowering, publication, or production support.
Those surfaces remain dependency-gated.

Run the local generator, snapshot, fail-closed validation, and native-caller
gate:

```bash
bash compiler/wordpress/scripts/test.sh
```

Then run the exact PHP 7.4/8.4 container matrix and real WordPress 7.0 fixture:

```bash
bash compiler/wordpress/scripts/test-php-matrix.sh
bash compiler/wordpress/scripts/test-wordpress.sh
```

ADR-005 defines the public/private emission contract. Publication remains
blocked by ADR-020 and SDK-002.
