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
python3 ../../scripts/lint/haxe-weak-type-guard.py --self-test
python3 ../../scripts/lint/haxe-weak-type-guard.py src test
rm -rf -- build/source-correlation
haxe test.hxml

find build/acme-books build/acme-books-adapters build/source-correlation -type f -name '*.php' -print0 \
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

adapter_guard_output="$(php build/acme-books-adapters/acme-books-adapters.php)"
if [[ -n "${adapter_guard_output}" ]]; then
  echo "adapter plugin root produced output outside WordPress: ${adapter_guard_output}" >&2
  exit 1
fi

native_output="$(php runtime/native-caller.php build/acme-books/acme-books.php)"
expected_output='{"booted":true,"class":"Acme\\Books\\Bootstrap","methods":["boot","isBooted"],"outputBytes":0}'
if [[ "${native_output}" != "${expected_output}" ]]; then
  echo "unexpected native PHP caller output: ${native_output}" >&2
  exit 1
fi

adapter_native_output="$(php runtime/native-adapter-caller.php build/acme-books-adapters/includes/PublicAdapters.php)"
adapter_expected_output='{"class":"Acme\\BooksAdapters\\PublicAdapters","initialized":true,"labels":["seed","added"],"methods":["appendLabel","filterTitle","isInitialized","normalizeTitle","onInit","registerBlocks","registerRestRoutes","renderSummary","restBook","restPermission"],"normalize":"NATIVE CALLER","outputBytes":0,"parameters":{"labelType":"string","labelsByReference":true},"privateMethods":["bookPayload","normalizeTitleImpl"]}'
if [[ "${adapter_native_output}" != "${adapter_expected_output}" ]]; then
  echo "unexpected native PHP adapter caller output: ${adapter_native_output}" >&2
  exit 1
fi

for correlation_profile in development packaged-evidence; do
  correlation_file="build/source-correlation/${correlation_profile}/includes/FailureCallbacks.php"
  correlation_stack_root="build/source-correlation/${correlation_profile}/stacks"
  mkdir -p "${correlation_stack_root}"
  for mode in hook rest render private; do
    set +e
    php runtime/source-correlation-caller.php "${correlation_file}" "${mode}" \
      >"${correlation_stack_root}/${mode}.stack" 2>&1
    correlation_status=$?
    set -e
    if (( correlation_status != 17 )); then
      echo "${correlation_profile}/${mode} source-correlation fixture exited ${correlation_status}, expected 17" >&2
      sed -n '1,120p' "${correlation_stack_root}/${mode}.stack" >&2
      exit 1
    fi
    if ! grep -F -- "${mode} failure" "${correlation_stack_root}/${mode}.stack" >/dev/null \
      || ! grep -F -- "FailureCallbacks.php" "${correlation_stack_root}/${mode}.stack" >/dev/null; then
      echo "${correlation_profile}/${mode} source-correlation fixture did not preserve its native stack" >&2
      sed -n '1,120p' "${correlation_stack_root}/${mode}.stack" >&2
      exit 1
    fi
  done
done

if find build/source-correlation/production-plugin -type f \
  \( -name '*.map' -o -name '*.map.json' -o -name '*source-index*' -o -name '*.hx' \) -print -quit | grep -q .; then
  echo "default production plugin retained source-correlation data" >&2
  exit 1
fi

python3 ../../scripts/source-correlation/validate-sdk025.py

echo "WordPress PHP profile and native adapter local fixtures passed"
