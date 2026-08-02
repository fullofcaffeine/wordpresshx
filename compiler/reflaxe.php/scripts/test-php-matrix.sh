#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="build/generic-printer-fixture.php"
correlation_fixture="build/source-correlation-fixture.php"
semantic_fixture="build/exact-php-semantic-matrix"
expected_output='{"total":14,"count":4,"error":"RuntimeException","label":"generic"}'
semantic_expected_output="$(<"${package_root}/test/semantic-matrix/expected.stdout")"

if [[ ! -f "${package_root}/${fixture}" || ! -f "${package_root}/${correlation_fixture}" ]]; then
  echo "missing generated PHP fixture; run scripts/test.sh first" >&2
  exit 1
fi
rm -rf -- "${package_root}/${semantic_fixture}"
(
  cd "${package_root}"
  haxe test/semantic-matrix/build.hxml -D "reflaxe_php_output=${semantic_fixture}"
)

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the exact PHP runtime matrix" >&2
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

  docker run --rm --network none --mount "type=bind,src=${package_root},dst=/work,readonly" -w /work "${image}" php -l "${fixture}"
	docker run --rm --network none --mount "type=bind,src=${package_root},dst=/work,readonly" -w /work "${image}" php -l "${correlation_fixture}"
  docker run --rm --network none --mount "type=bind,src=${package_root},dst=/work,readonly" -w /work "${image}" sh -euc \
    "find '${semantic_fixture}' -type f -name '*.php' -print0 | sort -z | xargs -0 -n 1 php -l"
  output="$(docker run --rm --network none --mount "type=bind,src=${package_root},dst=/work,readonly" -w /work "${image}" php "${fixture}")"
  if [[ "${output}" != "${expected_output}" ]]; then
    echo "${label} runtime mismatch: ${output}" >&2
    exit 1
  fi
	set +e
	output="$(docker run --rm --network none --mount "type=bind,src=${package_root},dst=/work,readonly" -w /work "${image}" php "${correlation_fixture}" 2>&1)"
	local correlation_status=$?
	set -e
	if (( correlation_status == 0 )) || [[ "${output}" != *"RuntimeException: mapped café failure: generic"* ]]; then
		echo "${label} exact source-correlation failure fixture differed" >&2
		printf '%s\n' "${output}" >&2
		exit 1
	fi
  output="$(docker run --rm --network none \
    --mount "type=bind,src=${package_root},dst=/work,readonly" \
    -w /work "${image}" php -d error_reporting=-1 -d display_errors=stderr \
    "${semantic_fixture}/bootstrap.php" 2>&1)"
  if [[ "${output}" != "${semantic_expected_output}" ]]; then
    echo "${label} per-module semantic runtime mismatch or emitted stderr: ${output}" >&2
    exit 1
  fi
  echo "${label} ${version} lint/runtime fixture passed"
}

run_fixture "php74" "7.4.33" "${php74_image}"
run_fixture "php84" "8.4.7" "${php84_image}"
