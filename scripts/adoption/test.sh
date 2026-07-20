#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture_root="${repository_root}/fixtures/adoption-contract"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-adr015-gate.XXXXXX")"
cleanup() {
	case "${test_root}" in
		"${temporary_parent}"/wordpresshx-adr015-gate.*) rm -rf -- "${test_root}" ;;
		*) echo "refusing to remove unexpected ADR-015 test path" >&2 ;;
	esac
}
trap cleanup EXIT

for command_name in cmp docker grep haxelib lix node python3; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "ADR-015 adoption-contract gate requires ${command_name}" >&2
		exit 1
	fi
done

python3 "${repository_root}/scripts/adoption/validate-architecture.py"

php_mode=""
php_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"
if command -v php >/dev/null 2>&1 && [[ "$(php -r 'echo PHP_VERSION;')" == "8.4.7" ]]; then
	php_mode="local"
else
	docker info >/dev/null
	if [[ "$(docker run --rm --network none "${php_image}" php -r 'echo PHP_VERSION;')" == "8.4.7" ]]; then
		php_mode="container"
	fi
fi
if [[ -z "${php_mode}" ]]; then
	echo "ADR-015 adoption-contract gate requires PHP 8.4.7 locally or through the pinned container" >&2
	exit 1
fi

lix_bin_dir="$(cd "$(dirname "$(command -v lix)")" && pwd -P)"
scoped_haxe="${lix_bin_dir}/haxe"
if [[ ! -x "${scoped_haxe}" ]] || [[ "$("${scoped_haxe}" --version)" != "4.3.7" ]]; then
	echo "ADR-015 adoption-contract gate requires the Lix Haxe 4.3.7 shim" >&2
	exit 1
fi

node_command="$(command -v node)"
if [[ "$("${node_command}" --version)" != "v22.17.0" ]]; then
	nvm_node="${NVM_DIR:-}/versions/node/v22.17.0/bin/node"
	if [[ -x "${nvm_node}" ]] && [[ "$("${nvm_node}" --version)" == "v22.17.0" ]]; then
		node_command="${nvm_node}"
	else
		echo "ADR-015 adoption-contract gate requires Node 22.17.0" >&2
		exit 1
	fi
fi

typescript_root="${repository_root}/packages/gutenberg/build-tooling"
typescript_command="${typescript_root}/node_modules/.bin/tsc"
if [[ ! -x "${typescript_command}" ]]; then
	echo "ADR-015 adoption-contract gate requires the pinned Gutenberg build-tooling install" >&2
	exit 1
fi

(
	cd "${repository_root}/packages/cli"
	lix --silent download
)

haxelib run formatter --check \
	-s "${fixture_root}/src" \
	-s "${fixture_root}/test" \
	-s "${fixture_root}/test-negative"

if grep --recursive --line-number --extended-regexp \
	--include='*.hx' \
	'(^|[^[:alnum:]_])(Dynamic|Any|Reflect|untyped|cast)([^[:alnum:]_]|$)' \
	"${fixture_root}/src" \
	"${fixture_root}/test" \
	"${fixture_root}/test-negative"; then
	echo "ADR-015 Haxe prototype contains a forbidden weak-type construct" >&2
	exit 1
fi

export WORDPRESSHX_ADOPTION_POISON_SENTINEL="${test_root}/provider-executed"
main_class="Main"
"${scoped_haxe}" \
	-cp "${fixture_root}/src" \
	-cp "${fixture_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
	--interp >"${test_root}/interp.txt"

(
	cd "${repository_root}/packages/cli"
	"${scoped_haxe}" \
		-cp ../../fixtures/adoption-contract/src \
		-cp ../../fixtures/adoption-contract/test \
		-main "${main_class}" \
		--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
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

"${scoped_haxe}" \
	-cp "${fixture_root}/src" \
	-cp "${fixture_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
	--php "${test_root}/php"
if [[ "${php_mode}" == "local" ]]; then
	php "${test_root}/php/index.php" >"${test_root}/php.txt"
else
	docker run --rm --network none \
		--mount "type=bind,src=${test_root},dst=/work,readonly" \
		-w /work "${php_image}" php php/index.php >"${test_root}/php.txt"
fi

expected="${fixture_root}/expected/capability-plan.txt"
cmp "${expected}" "${test_root}/interp.txt"
cmp "${expected}" "${test_root}/javascript.txt"
cmp "${expected}" "${test_root}/php.txt"

assert_compile_failure() {
	local fixture="$1"
	shift
	local diagnostic="${test_root}/${fixture}.diagnostic.txt"
	if "${scoped_haxe}" \
		-cp "${fixture_root}/src" \
		-cp "${fixture_root}/test-negative/${fixture}" \
		-main Main \
		--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
		--interp >"${diagnostic}" 2>&1; then
		echo "negative adoption fixture ${fixture} compiled successfully" >&2
		exit 1
	fi
	for expected_fragment in "$@"; do
		if ! grep --fixed-strings --quiet -- "${expected_fragment}" "${diagnostic}"; then
			echo "negative adoption fixture ${fixture} omitted diagnostic: ${expected_fragment}" >&2
			sed -n '1,80p' "${diagnostic}" >&2
			exit 1
		fi
	done
}

assert_compile_failure direct_token_construction \
	'Cannot access private constructor of wordpress.hx.adoption.prototype.CapabilityToken'
assert_compile_failure wrong_capability \
	'CalendarBadgeCapability should be wordpress.hx.adoption.prototype.CalendarReadCapability'
assert_compile_failure cross_request_scope \
	'FirstScope should be SecondScope'
assert_compile_failure omitted_binding \
	'Class<wordpress.hx.adoption.prototype.AcmeCalendarFacade> has no field magicLookup'

if [[ -e "${WORDPRESSHX_ADOPTION_POISON_SENTINEL}" ]]; then
	echo "ADR-015 default generation executed provider runtime code" >&2
	exit 1
fi

echo "ADR-015 adoption contract passed on Haxe, Genes/strict TypeScript/Node, and PHP without provider execution"
