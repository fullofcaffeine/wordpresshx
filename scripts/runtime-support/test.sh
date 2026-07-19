#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture_workspace="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-adr018-local.XXXXXX")"

cleanup() {
  rm -rf -- "${fixture_workspace}"
}
trap cleanup EXIT

for command_name in haxe haxelib php python3; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "ADR-018 runtime-support proof requires ${command_name}" >&2
    exit 1
  }
done

haxe_version="$(haxe --version)"
if [[ "${haxe_version}" != "4.3.7" ]]; then
  echo "ADR-018 runtime-support proof requires Haxe 4.3.7; found ${haxe_version}" >&2
  exit 1
fi
php -r 'if (PHP_VERSION_ID < 70400) { fwrite(STDERR, "PHP 7.4 or newer is required\n"); exit(1); }'

cd "${repository_root}"
python3 scripts/runtime-support/test-policy.py
haxelib run formatter --check -s fixtures/runtime-support-packaging/src/fixture/privateimpl/Main.hx

mkdir -p "${fixture_workspace}/first" "${fixture_workspace}/second"
python3 scripts/runtime-support/build-fixtures.py \
  --output "${fixture_workspace}/first/packages" \
  >"${fixture_workspace}/first-build.json"
python3 scripts/runtime-support/build-fixtures.py \
  --output "${fixture_workspace}/second/packages" \
  >"${fixture_workspace}/second-build.json"

python3 scripts/runtime-support/test-runtime.py \
  --first "${fixture_workspace}/first/packages" \
  --second "${fixture_workspace}/second/packages"
