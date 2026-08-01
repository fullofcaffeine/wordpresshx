# Test suites

Tests are layered so each compatibility claim names its actual boundary. Mocks and compiler fixtures may make development faster, but they cannot replace installed WordPress, PHP-floor, browser, or final-package evidence.

The checked owner map, five independent product-surface scorecards, R0-R5
feedback rings, example tiers, and conservative affected-test selector are
documented in [`docs/testing-strategy.md`](../docs/testing-strategy.md) and
`manifests/testing-strategy.json`. Validate them with:

```bash
python3 scripts/testing/strategy.py validate
python3 scripts/testing/strategy.py self-test
python3 scripts/testing/strategy.py select --base origin/main
```

Selection is deliberately observation-only. Unknown or cross-cutting paths
expand to the complete mapped portfolio, and the normal required workflows
remain the backstop. A green compiler test does not advance WordPress runtime,
package/install, Gutenberg/browser, or migration/downstream claims.

The first real WordPress layer is SDK-090:

```bash
bash scripts/wordpress/test-harness.sh
```

It runs fresh WordPress 7.0 installations against exact MySQL and MariaDB images, verifies real SQL and HTTP behavior, and tears down every named volume. It intentionally contains no WordPressHx SDK source mount, generated plugin, theme, browser test, or package shortcut. Later server, block, HXX/theme, browser, and ZIP gates install their staged artifacts into this vanilla base rather than replacing it.
