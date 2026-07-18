#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="build/acme-books/acme-books.php"
adapter_fixture="build/acme-books-adapters/acme-books-adapters.php"
adapter_class_file="build/acme-books-adapters/includes/PublicAdapters.php"
expected_output='{"booted":true,"class":"Acme\\Books\\Bootstrap","methods":["boot","isBooted"],"outputBytes":0}'
adapter_expected_output='{"class":"Acme\\BooksAdapters\\PublicAdapters","initialized":true,"labels":["seed","added"],"methods":["appendLabel","filterTitle","isInitialized","normalizeTitle","onInit","registerBlocks","registerRestRoutes","renderSummary","restBook","restPermission"],"normalize":"NATIVE CALLER","outputBytes":0,"parameters":{"labelType":"string","labelsByReference":true},"privateMethods":["bookPayload","normalizeTitleImpl"]}'

if [[ ! -f "${package_root}/${fixture}" ]]; then
  echo "missing generated WordPress PHP fixture; run scripts/test.sh first" >&2
  exit 1
fi
if [[ ! -f "${package_root}/${adapter_fixture}" || ! -f "${package_root}/${adapter_class_file}" ]]; then
  echo "missing generated WordPress adapter fixture; run scripts/test.sh first" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the exact WordPress PHP matrix" >&2
  exit 1
fi
docker info >/dev/null

php74_image="docker.io/library/php@sha256:620a6b9f4d4feef2210026172570465e9d0c1de79766418d3affd09190a7fda5"
php84_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"

run_fixture() {
  local label="$1"
  local expected_version="$2"
  local image="$3"
  local version
  local output

  version="$(docker run --rm --network none "${image}" php -r 'echo PHP_VERSION;')"
  if [[ "${version}" != "${expected_version}" ]]; then
    echo "${label} version mismatch: expected ${expected_version}, found ${version}" >&2
    exit 1
  fi

  docker run --rm --network none \
    --mount "type=bind,src=${package_root},dst=/work,readonly" \
    -w /work "${image}" sh -euc \
    "find build/acme-books build/acme-books-adapters -type f -name '*.php' -print0 | sort -z | xargs -0 -n 1 php -l"
  output="$(docker run --rm --network none \
    --mount "type=bind,src=${package_root},dst=/work,readonly" \
    -w /work "${image}" php "${fixture}")"
  if [[ -n "${output}" ]]; then
    echo "${label} direct-access guard produced output: ${output}" >&2
    exit 1
  fi
  output="$(docker run --rm --network none \
    --mount "type=bind,src=${package_root},dst=/work,readonly" \
    -w /work "${image}" php "${adapter_fixture}")"
  if [[ -n "${output}" ]]; then
    echo "${label} adapter direct-access guard produced output: ${output}" >&2
    exit 1
  fi
  output="$(docker run --rm --network none \
    --mount "type=bind,src=${package_root},dst=/work,readonly" \
    -w /work "${image}" php runtime/native-caller.php "${fixture}")"
  if [[ "${output}" != "${expected_output}" ]]; then
    echo "${label} native caller mismatch: ${output}" >&2
    exit 1
  fi
  output="$(docker run --rm --network none \
    --mount "type=bind,src=${package_root},dst=/work,readonly" \
    -w /work "${image}" php runtime/native-adapter-caller.php "${adapter_class_file}")"
  if [[ "${output}" != "${adapter_expected_output}" ]]; then
    echo "${label} native adapter caller mismatch: ${output}" >&2
    exit 1
  fi
  echo "${label} ${version} WordPress public PHP lint/native-callers passed"
}

run_fixture "php74" "7.4.33" "${php74_image}"
run_fixture "php84" "8.4.7" "${php84_image}"
