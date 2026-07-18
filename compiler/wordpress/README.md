# WordPress PHP profile

This internal profile consumes the generic `compiler/reflaxe.php` IR and emits
WordPress-specific public PHP artifacts. The dependency is one-way:

```text
compiler/reflaxe.php <- compiler/wordpress
```

The first admitted SDK-022 slice owns typed plugin headers, the root-file
`ABSPATH` guard, deterministic autoload inclusion, and a stable namespaced
bootstrap class. Header values are structured profile data. Root/bootstrap PHP
is constructed from typed generic IR; no application raw-PHP string or stock
Haxe runtime enters the public artifact. The emitted JSON manifest is an
internal SDK-022 evidence record; it explicitly does not claim ADR-006 semantic
plan schema or ADR-007 transactional ownership.

This is not yet a Reflaxe driver, hook/REST/block adapter profile, lifecycle
implementation, private stock-Haxe package, HXX lowerer, or production-support
claim. Those surfaces remain dependency-gated.

Run the local generator/snapshot/native-caller gate:

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
