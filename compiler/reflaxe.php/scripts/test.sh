#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${package_root}"

haxe_version="$(haxe --version)"
if [[ "${haxe_version}" != "4.3.7" ]]; then
  echo "reflaxe.php requires Haxe 4.3.7 for this evidence gate; found ${haxe_version}" >&2
  exit 1
fi

php -r 'if (PHP_VERSION_ID < 70400) { fwrite(STDERR, "PHP 7.4 or newer is required\n"); exit(1); }'
haxelib run formatter --check -s src -s test
haxe test.hxml
php -l build/generic-printer-fixture.php

actual_output="$(php build/generic-printer-fixture.php)"
expected_output='{"total":14,"count":4,"error":"RuntimeException","label":"generic"}'
if [[ "${actual_output}" != "${expected_output}" ]]; then
  echo "unexpected PHP runtime output: ${actual_output}" >&2
  exit 1
fi

if rg -n -i 'wordpress|gutenberg|wphx|@:wp\.|wordpresshx-port|compiler/wordpress|packages/' src test test.hxml; then
  echo "WordPress or SDK coupling detected in the generic compiler package" >&2
  exit 1
fi

echo "reflaxe.php PHP runtime fixture passed"
