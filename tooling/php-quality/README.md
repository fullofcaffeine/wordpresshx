# Generated-PHP quality toolchain

This directory is the exact, build-only SDK-026 tool graph for generated PHP.
Application projects do not own or maintain a Composer manifest, PHPCS ruleset,
PHPStan configuration, WordPress stubs, or invocation script. The Haxe CLI
embeds the policy bytes, verifies the installed copy beside its executable,
stages the complete in-memory plugin privately, and runs this gate before the
ownership transaction can publish anything.

`composer.lock` pins the complete ten-package graph. `toolchain.json` pins
Composer 2.10.2 by artifact SHA-256, PHP 7.4.33 as the syntax floor, PHP 8.4.7
as the primary lane, WordPress stubs 7.0.0, PHPCS 3.13.5, WPCS 3.4.0,
PHPCompatibilityWP 2.1.8, and PHPStan 2.2.5. `install.sh` verifies the Composer
PHAR before installing, validates the lock, audits advisories, and lints the
runner.

The closed policy is:

- every PHP file: syntax lint and duplicate class/function detection;
- public native PHP: formatter stability, WordPress Core/Extra and security
  sniffs, PHP 7.4 compatibility, and PHPStan level 6 with exact WordPress 7.0
  stubs;
- private stock-Haxe PHP: PHP 7.4 compatibility, PHPStan level 0, an
  authoritative declaration-matching classmap, and a real autoload probe;
- every success: deterministic scalar receipt with exact policy, lock, stub,
  file-count, classmap, and analysis-level identities.

Generated-code exceptions are versioned in `toolchain.json` and implemented by
the three narrow rulesets. The private compiler lane receives no automatic
formatting or WordPress style rules because changing compiler-owned runtime
bytes would invalidate its evidence. It still receives all correctness,
compatibility, symbol, classmap, and autoload checks. The public lane excludes
only stable Haxe-visible naming, generalized printer layout, and fixed
fail-closed loader diagnostics; input, output, SQL, nonce, capability, escaping,
and other security diagnostics remain blocking.

Install and exercise the policy from the repository root:

```bash
bash scripts/php-quality/install.sh
bash scripts/php-quality/test-production.sh
```

The production test runs the three native compiler fixtures twice and then
proves fail-closed syntax, formatter, WPCS security, PHPStan, and duplicate
symbol mutations. The scaffold production gate additionally proves Haxe CLI
policy-tamper rejection, no-write `check` and dry-run behavior, public/private
report ownership, private classmap rejection, exact PHP 7.4/8.4 execution, and
clean WordPress 7.0 activation.

`vendor/` and `.cache/` are ephemeral and ignored. No Composer or analyzer
package is included in a generated plugin, deterministic plugin ZIP, or runtime
dependency graph.
