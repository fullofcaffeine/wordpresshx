#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
package_root="${repository_root}/packages/contracts"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-adr009-gate.XXXXXX")"
cleanup() {
  case "${test_root}" in
    "${temporary_parent}"/wordpresshx-adr009-gate.*) rm -rf -- "${test_root}" ;;
    *) echo "refusing to remove unexpected ADR-009 test path" >&2 ;;
  esac
}
trap cleanup EXIT

for command_name in cmp haxe haxelib lix node python3 rg; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ADR-009 schema authority gate requires ${command_name}" >&2
    exit 1
  fi
done

if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "ADR-009 schema authority gate requires Haxe 4.3.7" >&2
  exit 1
fi

php_mode=""
php_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"
if command -v php >/dev/null 2>&1 && [[ "$(php -r 'echo PHP_VERSION;')" == "8.4.7" ]]; then
	php_mode="local"
elif command -v docker >/dev/null 2>&1; then
	docker info >/dev/null
	if [[ "$(docker run --rm --network none "${php_image}" php -r 'echo PHP_VERSION;')" == "8.4.7" ]]; then
		php_mode="container"
	fi
fi
if [[ -z "${php_mode}" ]]; then
	echo "ADR-009 schema authority gate requires primary PHP 8.4.7 locally or through the pinned container" >&2
	exit 1
fi

node_command="$(command -v node)"
if [[ "$("${node_command}" --version)" != "v22.17.0" ]]; then
  nvm_node="${NVM_DIR:-}/versions/node/v22.17.0/bin/node"
  if [[ -x "${nvm_node}" ]] && [[ "$("${nvm_node}" --version)" == "v22.17.0" ]]; then
    node_command="${nvm_node}"
  else
    echo "ADR-009 schema authority gate requires Node 22.17.0" >&2
    exit 1
  fi
fi

typescript_root="${repository_root}/packages/gutenberg/build-tooling"
typescript_command="${typescript_root}/node_modules/.bin/tsc"
if [[ ! -x "${typescript_command}" ]]; then
  echo "ADR-009 schema authority gate requires the pinned Gutenberg build-tooling install" >&2
  echo "Run: npm --prefix packages/gutenberg/build-tooling ci" >&2
  exit 1
fi
if [[ "$("${node_command}" -p 'require(process.argv[1]).version' "${typescript_root}/node_modules/typescript/package.json")" != "5.9.3" ]]; then
  echo "ADR-009 schema authority gate requires TypeScript 5.9.3" >&2
  exit 1
fi

python3 "${repository_root}/packages/cli/scripts/verify-dependency-lock.py"
python3 "${repository_root}/scripts/contracts/validate-schema-authority.py"
(
	cd "${repository_root}/packages/cli"
	lix --silent download
)

haxelib run formatter --check \
  -s "${package_root}/src" \
  -s "${package_root}/test" \
  -s "${package_root}/test-negative"

if rg --line-number \
  --glob '*.hx' \
  '\b(Dynamic|Any|Reflect|untyped|cast)\b' \
  "${package_root}/src" \
  "${package_root}/test" \
  "${package_root}/test-negative"; then
  echo "ADR-009 schema authority Haxe contains a forbidden weak-type construct" >&2
  exit 1
fi

main_class="wordpress.hx.contracts.tests.SchemaAuthorityTest"
haxe \
	-cp "${package_root}/src" \
	-cp "${package_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.contracts", Strict)' \
	--interp >"${test_root}/interp.txt"

(
  cd "${repository_root}/packages/cli"
  haxe \
    -cp ../contracts/src \
		-cp ../contracts/test \
		-main "${main_class}" \
		--macro 'nullSafety("wordpress.hx.contracts", Strict)' \
		-lib genes-ts \
    -lib hxnodejs \
    -D genes.ts \
    -D js-es=6 \
    -dce full \
    -js "${test_root}/genes/index.ts"
)
"${typescript_command}" \
  --strict \
  --target ES2022 \
  --module NodeNext \
  --moduleResolution NodeNext \
  --rootDir "${test_root}/genes" \
  --outDir "${test_root}/javascript" \
  --skipLibCheck \
  --types node \
  --typeRoots "${typescript_root}/node_modules/@types" \
  --pretty false \
  "${test_root}/genes/index.ts"
"${node_command}" "${test_root}/javascript/index.js" >"${test_root}/javascript.txt"

haxe \
  -cp "${package_root}/src" \
	-cp "${package_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.contracts", Strict)' \
	--php "${test_root}/php"
if [[ "${php_mode}" == "local" ]]; then
	php "${test_root}/php/index.php" >"${test_root}/php.txt"
else
	docker run --rm --network none \
		--mount "type=bind,src=${test_root},dst=/work,readonly" \
		-w /work "${php_image}" php php/index.php >"${test_root}/php.txt"
fi

expected="${repository_root}/fixtures/schema-codec/expected/cross-target.txt"
cmp "${expected}" "${test_root}/interp.txt"
cmp "${expected}" "${test_root}/javascript.txt"
cmp "${expected}" "${test_root}/php.txt"

assert_compile_failure() {
  local fixture="$1"
  local fixture_main="$2"
  shift 2
  local diagnostic="${test_root}/${fixture}.diagnostic.txt"
	if haxe \
		-cp "${package_root}/src" \
		-cp "${package_root}/test-negative/${fixture}" \
		-main "${fixture_main}" \
		--macro 'nullSafety("wordpress.hx.contracts", Strict)' \
		--interp >"${diagnostic}" 2>&1; then
    echo "negative fixture ${fixture} compiled successfully" >&2
    exit 1
  fi
  for expected_fragment in "$@"; do
    if ! rg --fixed-strings --quiet "${expected_fragment}" "${diagnostic}"; then
      echo "negative fixture ${fixture} omitted diagnostic: ${expected_fragment}" >&2
      sed -n '1,80p' "${diagnostic}" >&2
      exit 1
    fi
  done
}

assert_compile_failure \
  domain_mismatch \
  Main \
  'Int should be String' \
  'ContractCodec<Int>' \
  'ContractCodec<String>'
assert_compile_failure \
	null_is_missing \
	Main \
	'NullableValue' \
	'Presence<String>'
assert_compile_failure \
	raw_null \
	wordpress.hx.contracts.negative.RawNullMain \
	'Null safety: Cannot assign nullable value here.'
assert_compile_failure \
	frozen_default_mutation \
	wordpress.hx.contracts.negative.FrozenDefaultMutationMain \
	'FrozenList<wordpress.hx.contracts.schema.FrozenWireValue> has no field push'

echo "ADR-009 typed schema/codec authority gate passed on Haxe interp, Genes/TypeScript/Node 22.17.0, and PHP 8.4.7"
