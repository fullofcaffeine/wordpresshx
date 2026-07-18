#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${package_root}"

haxe_version="$(haxe --version)"
if [[ "${haxe_version}" != "4.3.7" ]]; then
  echo "WordPress PHP profile requires Haxe 4.3.7; found ${haxe_version}" >&2
  exit 1
fi

php -r 'if (PHP_VERSION_ID < 70400) { fwrite(STDERR, "PHP 7.4 or newer is required\n"); exit(1); }'
haxelib run formatter --check -s src -s test
haxe test.hxml

find build/acme-books -type f -name '*.php' -print0 \
  | sort -z \
  | xargs -0 -n 1 php -l

if profile_scan="$(grep -R -n -E 'RawPhp[A-Za-z0-9_]*\(|PhpRaw[A-Za-z0-9_]*\(|PhpSegment\(|untyped[[:space:]]+__php__|wordpresshx-port' src 2>&1)"; then
  printf '%s\n' "${profile_scan}" >&2
  echo "raw scaffold or source-port coupling detected in the WordPress PHP profile" >&2
  exit 1
else
  profile_scan_status=$?
  if (( profile_scan_status != 1 )); then
    printf '%s\n' "${profile_scan}" >&2
    echo "WordPress PHP profile source scan failed" >&2
    exit 1
  fi
fi

guard_output="$(php build/acme-books/acme-books.php)"
if [[ -n "${guard_output}" ]]; then
  echo "plugin root produced output outside WordPress: ${guard_output}" >&2
  exit 1
fi

native_output="$(php runtime/native-caller.php build/acme-books/acme-books.php)"
expected_output='{"booted":true,"class":"Acme\\Books\\Bootstrap","methods":["boot","isBooted"],"outputBytes":0}'
if [[ "${native_output}" != "${expected_output}" ]]; then
  echo "unexpected native PHP caller output: ${native_output}" >&2
  exit 1
fi

echo "WordPress PHP profile local fixture passed"
