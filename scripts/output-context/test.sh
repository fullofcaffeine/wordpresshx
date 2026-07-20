#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture_root="${repository_root}/fixtures/output-context"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-adr012-gate.XXXXXX")"
cleanup() {
	case "${test_root}" in
		"${temporary_parent}"/wordpresshx-adr012-gate.*) rm -rf -- "${test_root}" ;;
		*) echo "refusing to remove unexpected ADR-012 test path" >&2 ;;
	esac
}
trap cleanup EXIT

for command_name in cmp docker grep haxelib lix node python3; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "ADR-012 output-context gate requires ${command_name}" >&2
		exit 1
	fi
done

python3 "${repository_root}/scripts/output-context/validate-architecture.py"

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
	echo "ADR-012 output-context gate requires PHP 8.4.7 locally or through the pinned container" >&2
	exit 1
fi

lix_bin_dir="$(cd "$(dirname "$(command -v lix)")" && pwd -P)"
scoped_haxe="${lix_bin_dir}/haxe"
if [[ ! -x "${scoped_haxe}" ]]; then
	echo "ADR-012 output-context gate requires the Lix Haxe shim" >&2
	echo "Run: lix install haxe 4.3.7 --global" >&2
	exit 1
fi
if [[ "$("${scoped_haxe}" --version)" != "4.3.7" ]]; then
	echo "ADR-012 output-context gate requires Haxe 4.3.7" >&2
	exit 1
fi

node_command="$(command -v node)"
if [[ "$("${node_command}" --version)" != "v22.17.0" ]]; then
	nvm_node="${NVM_DIR:-}/versions/node/v22.17.0/bin/node"
	if [[ -x "${nvm_node}" ]] && [[ "$("${nvm_node}" --version)" == "v22.17.0" ]]; then
		node_command="${nvm_node}"
	else
		echo "ADR-012 output-context gate requires Node 22.17.0" >&2
		exit 1
	fi
fi

typescript_root="${repository_root}/packages/gutenberg/build-tooling"
typescript_command="${typescript_root}/node_modules/.bin/tsc"
if [[ ! -x "${typescript_command}" ]]; then
	echo "ADR-012 output-context gate requires the pinned Gutenberg build-tooling install" >&2
	echo "Run: npm --prefix packages/gutenberg/build-tooling ci" >&2
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
	echo "ADR-012 Haxe prototype contains a forbidden weak-type construct" >&2
	exit 1
fi

main_class="Main"
"${scoped_haxe}" \
	-cp "${fixture_root}/src" \
	-cp "${fixture_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.output.prototype", Strict)' \
	--interp >"${test_root}/interp.txt"

(
	cd "${repository_root}/packages/cli"
	"${scoped_haxe}" \
		-cp ../../fixtures/output-context/src \
		-cp ../../fixtures/output-context/test \
		-main "${main_class}" \
		--macro 'nullSafety("wordpress.hx.output.prototype", Strict)' \
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
	--macro 'nullSafety("wordpress.hx.output.prototype", Strict)' \
	--php "${test_root}/php"
if [[ "${php_mode}" == "local" ]]; then
	php "${test_root}/php/index.php" >"${test_root}/php.txt"
else
	docker run --rm --network none \
		--mount "type=bind,src=${test_root},dst=/work,readonly" \
		-w /work "${php_image}" php php/index.php >"${test_root}/php.txt"
fi

expected="${fixture_root}/expected/context-plan.txt"
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
		--macro 'nullSafety("wordpress.hx.output.prototype", Strict)' \
		--interp >"${diagnostic}" 2>&1; then
		echo "negative output-context fixture ${fixture} compiled successfully" >&2
		exit 1
	fi
	for expected_fragment in "$@"; do
		if ! grep --fixed-strings --quiet -- "${expected_fragment}" "${diagnostic}"; then
			echo "negative output-context fixture ${fixture} omitted diagnostic: ${expected_fragment}" >&2
			sed -n '1,80p' "${diagnostic}" >&2
			exit 1
		fi
	done
}

assert_compile_failure text_as_attribute \
	'HtmlText should be wordpress.hx.output.prototype.HtmlAttribute'
assert_compile_failure url_as_text \
	'HtmlUrl should be wordpress.hx.output.prototype.HtmlText'
assert_compile_failure json_as_script \
	'JsonDocument<String> should be wordpress.hx.output.prototype.HtmlScriptData'
assert_compile_failure plain_as_rich_html \
	'String should be wordpress.hx.output.prototype.KsesHtml'
assert_compile_failure direct_terminal_construction \
	'Cannot access private constructor of wordpress.hx.output.prototype.HtmlText'
assert_compile_failure kses_as_compiler_markup \
	'KsesHtml<wordpress.hx.output.prototype.PostContentPolicy> should be wordpress.hx.output.prototype.CompilerMarkup'
assert_compile_failure css_from_string \
	'String should be Array<wordpress.hx.output.prototype.CssDeclaration>'
assert_compile_failure script_as_rest \
	'HtmlScriptData<String> should be wordpress.hx.output.prototype.JsonDocument'

browser_json="$("${node_command}" "${fixture_root}/runtime/browser.mjs" "${typescript_root}")"
python3 - "${browser_json}" <<'PY'
import json
import sys

result = json.loads(sys.argv[1])
if result.get("check") != "wordpresshx-adr012-browser-output-context-v1":
    raise SystemExit(f"ADR-012 browser proof identity differed: {result!r}")
for field in ("textEscaped", "attributeEscaped", "textareaEscaped"):
    if result.get(field) is not True:
        raise SystemExit(f"ADR-012 browser proof failed {field}: {result!r}")
if result.get("unsafeHtmlApiUsed") is not False:
    raise SystemExit(f"ADR-012 browser proof used an unsafe HTML API: {result!r}")
if "<script" in result.get("markup", "").lower():
    raise SystemExit(f"ADR-012 browser markup retained executable input: {result!r}")
if "</script" in result.get("scriptData", "").lower():
    raise SystemExit(f"ADR-012 browser script data retained a closing tag: {result!r}")
print("ADR-012 React output-context proof passed")
PY

if grep --fixed-strings --quiet -- 'dangerouslySetInnerHTML' "${fixture_root}/runtime/browser.mjs"; then
	echo "ADR-012 browser proof contains an unsafe HTML insertion" >&2
	exit 1
fi

bash "${repository_root}/scripts/output-context/test-wordpress.sh"

echo "ADR-012 output-context prototype passed on Haxe, Genes/Node, PHP, React SSR, and WordPress 7.0"
