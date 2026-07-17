# Test suites

Tests are layered so each compatibility claim names its actual boundary. Mocks and compiler fixtures may make development faster, but they cannot replace installed WordPress, PHP-floor, browser, or final-package evidence.

The first real WordPress layer is SDK-090:

```bash
bash scripts/wordpress/test-harness.sh
```

It runs fresh WordPress 7.0 installations against exact MySQL and MariaDB images, verifies real SQL and HTTP behavior, and tears down every named volume. It intentionally contains no WordPressHx SDK source mount, generated plugin, theme, browser test, or package shortcut. Later server, block, HXX/theme, browser, and ZIP gates install their staged artifacts into this vanilla base rather than replacing it.
