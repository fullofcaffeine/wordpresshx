#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
cd "${package_root}"

haxe_version="$(haxe --version)"
if [[ "${haxe_version}" != "4.3.7" ]]; then
  echo "reflaxe.php requires Haxe 4.3.7 for this evidence gate; found ${haxe_version}" >&2
  exit 1
fi

php -r 'if (PHP_VERSION_ID < 70400) { fwrite(STDERR, "PHP 7.4 or newer is required\n"); exit(1); }'
haxelib run formatter --check -s src -s test
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" --self-test
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" "${package_root}"
haxe test.hxml
php -l build/generic-printer-fixture.php
php -l build/source-correlation-fixture.php

actual_output="$(php build/generic-printer-fixture.php)"
expected_output='{"total":14,"count":4,"error":"RuntimeException","label":"generic"}'
if [[ "${actual_output}" != "${expected_output}" ]]; then
  echo "unexpected PHP runtime output: ${actual_output}" >&2
  exit 1
fi

set +e
correlation_output="$(php build/source-correlation-fixture.php 2>&1)"
correlation_status=$?
set -e
if (( correlation_status == 0 )); then
  echo "source-correlation fixture did not throw as expected" >&2
  exit 1
fi
if [[ "${correlation_output}" != *"RuntimeException: mapped café failure: generic"* ]] \
  || [[ "${correlation_output}" != *"source-correlation-fixture.php:"* ]]; then
  printf '%s\n' "${correlation_output}" >&2
  echo "source-correlation fixture did not preserve its native PHP failure" >&2
  exit 1
fi

if isolation_scan_output="$(
  grep -R -n -i -E \
    'wordpress|gutenberg|wphx|@:wp\.|wordpresshx-port|compiler/wordpress|packages/' \
    src test test.hxml 2>&1
)"; then
  printf '%s\n' "${isolation_scan_output}"
  echo "WordPress or SDK coupling detected in the generic compiler package" >&2
  exit 1
else
  isolation_scan_status=$?
  if (( isolation_scan_status != 1 )); then
    printf '%s\n' "${isolation_scan_output}" >&2
    echo "generic compiler isolation scan failed" >&2
    exit 1
  fi
fi

echo "reflaxe.php PHP runtime fixture passed"
