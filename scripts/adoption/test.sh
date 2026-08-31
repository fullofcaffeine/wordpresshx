#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture_root="${repository_root}/fixtures/adoption-contract"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-adr015-gate.XXXXXX")"
observer_parts="${test_root}/observer-parts"
mkdir -p "${observer_parts}"
mark_observer() {
	python3 - "${repository_root}" "${observer_parts}/$1.json" "$1" <<'PY'
import json, sys
from pathlib import Path
root, output, observer_id = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
sys.path.insert(0, str(root / "scripts/adoption"))
from evidence_state import current_content_root, evidence_subject_sha256, observer_identities
output.write_text(json.dumps({
    "contentRoot": current_content_root(root),
    "evidenceSubjectSha256": evidence_subject_sha256(root),
    "id": observer_id,
    "identitySha256": observer_identities(root)[observer_id],
    "outcome": "passed",
}, sort_keys=True) + "\n", encoding="utf-8")
PY
}
cleanup() {
	case "${test_root}" in
		"${temporary_parent}"/wordpresshx-adr015-gate.*) rm -rf -- "${test_root}" ;;
		*) echo "refusing to remove unexpected ADR-015 test path" >&2 ;;
	esac
}
trap cleanup EXIT

for command_name in cmp cp diff docker grep haxelib lix node perl python3; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "ADR-015 adoption-contract gate requires ${command_name}" >&2
		exit 1
	fi
done

python3 - "${repository_root}/manifests/adoption-contract-toolchain.lock.json" <<'PY'
import json
import platform
import sys
from pathlib import Path

lock = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
python = lock.get("python") if isinstance(lock, dict) else None
if not isinstance(python, dict):
    raise SystemExit("ADR-015 Python lock omits its runtime")
expected = (python.get("implementation"), python.get("version"))
actual = (platform.python_implementation(), platform.python_version())
if actual != expected:
    raise SystemExit(
        "ADR-015 adoption-contract gate requires "
        f"{expected[0]} {expected[1]}, found {actual[0]} {actual[1]}"
    )
PY

python3 "${repository_root}/scripts/adoption/refresh-evidence.py"
python3 "${repository_root}/scripts/adoption/validate-architecture.py"
python3 "${repository_root}/scripts/adoption/test-evidence.py"
mark_observer mutation

php_mode=""
php_runtime=""
php_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"
force_container_php="${WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP:-0}"
if [[ "${force_container_php}" != "0" && "${force_container_php}" != "1" ]]; then
	echo "WORDPRESSHX_ADOPTION_FORCE_CONTAINER_PHP must be 0 or 1" >&2
	exit 1
fi
if [[ "${force_container_php}" == "0" ]] && command -v php >/dev/null 2>&1 && \
	[[ "$(php -r 'echo PHP_VERSION;')" == "8.4.7" ]]; then
	php_mode="local"
	php_runtime="$(command -v php)"
else
	docker info >/dev/null
	if [[ "$(docker run --rm --network none "${php_image}" php -r 'echo PHP_VERSION;')" == "8.4.7" ]]; then
		php_mode="container"
		php_runtime="${php_image}"
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

export WORDPRESSHX_ADOPTION_POISON_SENTINEL="${test_root}/provider-executed"
generation_one="${test_root}/generation-one"
generation_two="${test_root}/generation-two"
python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${generation_one}"
python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${generation_two}"
diff -ru "${generation_one}" "${generation_two}"
diff -ru "${fixture_root}/contract" "${generation_one}"
"${node_command}" "${repository_root}/scripts/adoption/test-json-schema.cjs"
"${node_command}" "${repository_root}/scripts/adoption/observe-javascript-source.cjs" \
	"${fixture_root}/inputs" "${generation_one}" >"${test_root}/javascript-source-observer.json"
mark_observer schema
if [[ -e "${WORDPRESSHX_ADOPTION_POISON_SENTINEL}" ]]; then
	echo "ADR-015 static generator executed provider runtime code" >&2
	exit 1
fi
mutated_inputs="${test_root}/mutated-inputs"
mkdir -p "${mutated_inputs}"
cp -rf "${fixture_root}/inputs/." "${mutated_inputs}/"
perl -pi -e 's/2\.4\.1/2.4.2/g' \
	"${mutated_inputs}/package-metadata.json" \
	"${mutated_inputs}/plugin.php"
WORDPRESSHX_ADOPTION_INPUT_ROOT="${mutated_inputs}" \
	python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${test_root}/mutated-generation"
if cmp -s "${generation_one}/acme-calendar.contract.json" "${test_root}/mutated-generation/acme-calendar.contract.json"; then
	echo "ADR-015 generator ignored an exact provider version/artifact change" >&2
	exit 1
fi
python3 - "${test_root}/mutated-generation/acme-calendar.contract.json" <<'PY'
import json
import sys
from pathlib import Path

contract = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert contract["provider"]["version"] == "2.4.2"
assert contract["provider"]["artifactUrl"].endswith("acme-calendar.2.4.2.zip")
PY

return_inputs="${test_root}/typescript-return-only-drift-inputs"
mkdir -p "${return_inputs}"
cp -rf "${fixture_root}/inputs/." "${return_inputs}/"
perl -pi -e 's/CalendarBadge\(props: CalendarBadgeProps\): object/CalendarBadge(props: CalendarBadgeProps): number/' \
	"${return_inputs}/index.d.ts"
WORDPRESSHX_ADOPTION_INPUT_ROOT="${return_inputs}" \
	python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${test_root}/typescript-return-only-drift-generation"
grep -F 'public function renderBadge(props:CalendarBadgeProps):Float;' \
	"${test_root}/typescript-return-only-drift-generation/generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx" >/dev/null

assert_generation_failure() {
	local name="$1"
	local expected_fragment="$2"
	local inputs="${test_root}/${name}-inputs"
	shift 2
	mkdir -p "${inputs}"
	cp -rf "${fixture_root}/inputs/." "${inputs}/"
	"$@" "${inputs}"
	if WORDPRESSHX_ADOPTION_INPUT_ROOT="${inputs}" \
		python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${test_root}/${name}-generation" \
		>"${test_root}/${name}.stdout" 2>"${test_root}/${name}.stderr"; then
		echo "ADR-015 generator accepted ${name}" >&2
		exit 1
	fi
	grep -F -- "${expected_fragment}" "${test_root}/${name}.stderr" >/dev/null
}

mutate_runtime_php_parameter() {
	perl -pi -e 's/function list_events\(int \$limit\)/function list_events(string \$limit)/' "$1/plugin.php"
}
assert_generation_failure runtime-php-parameter-drift \
	'lower-precedence runtime declaration conflicts with required binding: Acme\Calendar\list_events' \
	mutate_runtime_php_parameter

mutate_runtime_js_destructuring() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge({ count })/' "$1/index.js"
}
assert_generation_failure runtime-js-destructuring \
	'unsupported JavaScript runtime parameter syntax: { count }' \
	mutate_runtime_js_destructuring

mutate_runtime_js_rest() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(...props)/' "$1/index.js"
}
assert_generation_failure runtime-js-rest \
	'unsupported JavaScript runtime parameter syntax: ...props' \
	mutate_runtime_js_rest

mutate_runtime_js_default() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(props = {})/' "$1/index.js"
}
assert_generation_failure runtime-js-default \
	'unsupported JavaScript runtime parameter syntax: props = {}' \
	mutate_runtime_js_default

mutate_runtime_js_reserved() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(await)/' "$1/index.js"
}
assert_generation_failure runtime-js-reserved \
	'unsupported JavaScript runtime parameter identifier: await' \
	mutate_runtime_js_reserved

mutate_runtime_js_let() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(let)/' "$1/index.js"
}
assert_generation_failure runtime-js-let \
	'unsupported JavaScript runtime parameter identifier: let' \
	mutate_runtime_js_let

mutate_runtime_js_eval() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(eval)/' "$1/index.js"
}
assert_generation_failure runtime-js-eval \
	'unsupported JavaScript runtime parameter identifier: eval' \
	mutate_runtime_js_eval

mutate_runtime_js_arguments() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(arguments)/' "$1/index.js"
}
assert_generation_failure runtime-js-arguments \
	'unsupported JavaScript runtime parameter identifier: arguments' \
	mutate_runtime_js_arguments

mutate_runtime_js_if() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(if)/' "$1/index.js"
}
assert_generation_failure runtime-js-if \
	'unsupported JavaScript runtime parameter identifier: if' \
	mutate_runtime_js_if

mutate_runtime_js_duplicate() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(props, props)/' "$1/index.js"
}
assert_generation_failure runtime-js-duplicate \
	'duplicate JavaScript runtime parameter identifier: props' \
	mutate_runtime_js_duplicate

mutate_runtime_js_async() {
	perl -pi -e 's/export function formatCalendarLabel/export async function formatCalendarLabel/' "$1/index.js"
}
assert_generation_failure runtime-js-async \
	'unsupported JavaScript runtime export modifier: async' \
	mutate_runtime_js_async

mutate_runtime_js_generator() {
	perl -pi -e 's/export function formatCalendarLabel/export function* formatCalendarLabel/' "$1/index.js"
}
assert_generation_failure runtime-js-generator \
	'unsupported JavaScript runtime generator export' \
	mutate_runtime_js_generator

mutate_runtime_js_default_export() {
	perl -pi -e 's/export function formatCalendarLabel/export default function formatCalendarLabel/' "$1/index.js"
}
assert_generation_failure runtime-js-default-export \
	'unsupported JavaScript runtime export modifier: default' \
	mutate_runtime_js_default_export

mutate_runtime_js_comment_decoy_async() {
	perl -0pi -e 's/export function formatCalendarLabel\(count\) \{/\/\*\nexport function formatCalendarLabel(count) {\n\*\/\nPromise.prototype.toJSON = function () { return "3 calendar events"; };\nexport async function formatCalendarLabel(count) {/' "$1/index.js"
}
assert_generation_failure runtime-js-comment-decoy-async \
	'unsupported JavaScript runtime export modifier: async' \
	mutate_runtime_js_comment_decoy_async

assert_javascript_observer_failure() {
	local name="$1"
	local expected_fragment="$2"
	local inputs="${test_root}/observer-${name}-inputs"
	shift 2
	mkdir -p "${inputs}"
	cp -rf "${fixture_root}/inputs/." "${inputs}/"
	"$@" "${inputs}"
	if "${node_command}" "${repository_root}/scripts/adoption/observe-javascript-source.cjs" \
		"${inputs}" "${generation_one}" >"${test_root}/observer-${name}.stdout" 2>"${test_root}/observer-${name}.stderr"; then
		echo "independent JavaScript observer accepted ${name}" >&2
		exit 1
	fi
	grep -F -- "${expected_fragment}" "${test_root}/observer-${name}.stderr" >/dev/null
}

mutate_observer_js_comment() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(\/\* hidden \*\/ props)/' "$1/index.js"
}
assert_javascript_observer_failure comments-around-formal \
	'comments or unsupported tokens surround parameter props' \
	mutate_observer_js_comment
assert_javascript_observer_failure duplicate-formal \
	'duplicate parameter props' \
	mutate_runtime_js_duplicate
assert_javascript_observer_failure destructured-formal \
	'unsupported parameter form in CalendarBadge' \
	mutate_runtime_js_destructuring
assert_javascript_observer_failure rest-formal \
	'unsupported parameter form in CalendarBadge' \
	mutate_runtime_js_rest
assert_javascript_observer_failure default-formal \
	'unsupported parameter form in CalendarBadge' \
	mutate_runtime_js_default
assert_javascript_observer_failure reserved-formal \
	'unsupported parameter identifier await' \
	mutate_runtime_js_reserved
assert_javascript_observer_failure let-formal \
	'unsupported parameter identifier let' \
	mutate_runtime_js_let
assert_javascript_observer_failure eval-formal \
	'unsupported parameter identifier eval' \
	mutate_runtime_js_eval
assert_javascript_observer_failure arguments-formal \
	'unsupported parameter identifier arguments' \
	mutate_runtime_js_arguments
assert_javascript_observer_failure if-formal \
	'module syntax is invalid' \
	mutate_runtime_js_if
assert_javascript_observer_failure async-export \
	'exported functions must be named, non-default, synchronous, and non-generator declarations' \
	mutate_runtime_js_async
assert_javascript_observer_failure generator-export \
	'exported functions must be named, non-default, synchronous, and non-generator declarations' \
	mutate_runtime_js_generator
assert_javascript_observer_failure default-export \
	'exported functions must be named, non-default, synchronous, and non-generator declarations' \
	mutate_runtime_js_default_export
assert_javascript_observer_failure comment-decoy-async \
	'exported functions must be named, non-default, synchronous, and non-generator declarations' \
	mutate_runtime_js_comment_decoy_async

interface_inputs="${test_root}/typescript-interface-only-drift-inputs"
mkdir -p "${interface_inputs}"
cp -rf "${fixture_root}/inputs/." "${interface_inputs}/"
perl -pi -e 's/readonly count: number/readonly count: string/' "${interface_inputs}/index.d.ts"
WORDPRESSHX_ADOPTION_INPUT_ROOT="${interface_inputs}" \
	python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${test_root}/typescript-interface-only-drift-generation"
python3 - "${test_root}/typescript-interface-only-drift-generation" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
contract = json.loads((root / "acme-calendar.contract.json").read_text(encoding="utf-8"))
badge = next(value for value in contract["bindings"] if value["id"] == "js.calendar.badge")
fields = badge["parameters"][0]["type"]["fields"]
assert next(value for value in fields if value["name"] == "count")["type"] == {"kind": "string"}
haxe = root / "generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx"
assert "public final count:String;" in haxe.read_text(encoding="utf-8")
PY

mutate_php_docblock() {
	perl -pi -e 's/\@return list<Event>/\@return list<string>/' "$1/provider-stubs.php"
}
assert_generation_failure php-docblock-only-drift \
	'lower-precedence runtime declaration conflicts with required binding: Acme\Calendar\list_events' \
	mutate_php_docblock

remove_javascript_runtime_export() {
	perl -pi -e 's/export function CalendarBadge/function CalendarBadge/' "$1/index.js"
}
assert_generation_failure missing-javascript-runtime-export \
	'JavaScript runtime exports omit declared symbol: @acme/calendar.CalendarBadge' \
	remove_javascript_runtime_export

mutate_javascript_runtime_arity() {
	perl -pi -e 's/function CalendarBadge\(props\)/function CalendarBadge(props, extra)/' "$1/index.js"
}
assert_generation_failure javascript-runtime-arity-drift \
	'JavaScript runtime export shape conflicts with declaration: @acme/calendar.CalendarBadge' \
	mutate_javascript_runtime_arity

generated_haxe="${generation_one}/generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx"
grep -F 'public final count:Float;' "${generated_haxe}" >/dev/null
grep -F 'extern class GeneratedJavascriptObject {}' "${generated_haxe}" >/dev/null
if grep --line-number --extended-regexp \
	'GeneratedCalendarBadgeResult|final kind:String' "${generated_haxe}"; then
	echo "ADR-015 generated Haxe surface strengthened an opaque JavaScript object" >&2
	exit 1
fi
if grep --line-number --extended-regexp \
	'expected_(abi|signatures)|expected_signatures' \
	"${repository_root}/scripts/adoption/generate-fixture.py" \
	"${repository_root}/scripts/adoption/validate-architecture.py"; then
	echo "ADR-015 generator or validator retains parallel hard-coded ABI truth" >&2
	exit 1
fi

(
	cd "${repository_root}/packages/cli"
	lix --silent download
	mkdir -p "${test_root}/ownership-runtime-current" "${test_root}/ownership-runtime-updated"
	"${scoped_haxe}" \
		-lib genes-ts \
		-lib hxnodejs \
		-cp src \
		-cp "${fixture_root}/test-ownership" \
		-resource "${generation_one}/acme-calendar.expected-stage.json@adoption-stage" \
		-main adoption.ownership.Main \
		-D js-es=6 \
		-D wordpresshx_ownership_fault_injection \
		-dce full \
		-js "${test_root}/ownership-runtime-current/index.js"
	"${scoped_haxe}" \
		-lib genes-ts \
		-lib hxnodejs \
		-cp src \
		-cp "${fixture_root}/test-ownership" \
		-resource "${test_root}/mutated-generation/acme-calendar.expected-stage.json@adoption-stage" \
		-main adoption.ownership.Main \
		-D js-es=6 \
		-D wordpresshx_ownership_fault_injection \
		-dce full \
		-js "${test_root}/ownership-runtime-updated/index.js"
)
python3 "${repository_root}/scripts/adoption/test-ownership.py" \
	"${test_root}/ownership-runtime-current/index.js" \
	"${test_root}/ownership-runtime-updated/index.js" \
	"${generation_one}" \
	"${test_root}/mutated-generation" \
	"${test_root}/ownership-work" \
	"${node_command}"
mark_observer ownership

native_php_root="${test_root}/haxe-native-php"
native_js_index="${test_root}/haxe-native-js/index.js"
mkdir -p "${native_php_root}" "$(dirname "${native_js_index}")"
"${scoped_haxe}" \
	-cp "${fixture_root}/src" \
	-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
	-cp "${fixture_root}/test-native" \
	-main NativeMain \
	--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
	--php "${native_php_root}"
(
	cd "${repository_root}/packages/cli"
	"${scoped_haxe}" \
		-cp "${fixture_root}/src" \
		-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
		-cp "${fixture_root}/test-native" \
		-main NativeMain \
		--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
		-lib hxnodejs \
		-D js-es=6 \
		-dce full \
		-js "${native_js_index}"
)
python3 "${repository_root}/scripts/adoption/test-native-provider.py" \
	"${generation_one}" \
	"${test_root}/native-provider" \
	"${php_mode}" \
	"${php_runtime}" \
	"${node_command}" \
	"${native_php_root}/index.php" \
	"${native_js_index}"
mark_observer native

haxelib run formatter --check \
	-s "${fixture_root}/src" \
	-s "${fixture_root}/test-support" \
	-s "${fixture_root}/test" \
	-s "${fixture_root}/test-native" \
	-s "${fixture_root}/test-negative" \
	-s "${fixture_root}/test-ownership"

if grep --recursive --line-number --extended-regexp \
	--include='*.hx' \
	'(^|[^[:alnum:]_])(Dynamic|Any|Reflect|untyped|cast)([^[:alnum:]_]|$)' \
	"${fixture_root}/src" \
	"${fixture_root}/test-support" \
	"${fixture_root}/test" \
	"${fixture_root}/test-native" \
	"${fixture_root}/test-negative" \
	"${fixture_root}/test-ownership"; then
	echo "ADR-015 Haxe prototype contains a forbidden weak-type construct" >&2
	exit 1
fi

main_class="Main"
"${scoped_haxe}" \
	-cp "${fixture_root}/test-support" \
	-cp "${fixture_root}/test" \
	-main "${main_class}" \
	--interp >"${test_root}/interp.txt"

expected="${fixture_root}/expected/capability-plan.txt"
cmp "${expected}" "${test_root}/interp.txt"

assert_compile_failure() {
	local fixture="$1"
	shift
	local diagnostic="${test_root}/${fixture}.diagnostic.txt"
	if "${scoped_haxe}" \
			-cp "${fixture_root}/src" \
			-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
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

assert_hostile_define_failure() {
	local target="$1"
	local diagnostic="${test_root}/hostile-define-${target}.diagnostic.txt"
	local output_args=()
	case "${target}" in
		interp) output_args=(--interp) ;;
		php) output_args=(--php "${test_root}/hostile-define-php") ;;
		javascript) output_args=(-js "${test_root}/hostile-define.js") ;;
		*) echo "unknown hostile-define target ${target}" >&2; exit 1 ;;
	esac
	if "${scoped_haxe}" \
		-cp "${fixture_root}/src" \
		-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
		-cp "${fixture_root}/test-negative/hostile_define" \
		-main Main \
		-D adoption_contract_test \
		--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
		"${output_args[@]}" >"${diagnostic}" 2>&1; then
		echo "hostile adoption_contract_test define exposed product minting on ${target}" >&2
		exit 1
	fi
	grep -F -- 'Class<wordpress.hx.adoption.prototype.Adoption> has no field FixtureTargetAdapter' "${diagnostic}" >/dev/null
}

assert_hostile_define_failure interp
assert_hostile_define_failure php
assert_hostile_define_failure javascript

assert_access_metadata_failure() {
	local target="$1"
	local diagnostic="${test_root}/access-metadata-${target}.diagnostic.txt"
	local output_args=()
	case "${target}" in
		interp) output_args=(--interp) ;;
		php) output_args=(--php "${test_root}/access-metadata-php") ;;
		javascript) output_args=(-js "${test_root}/access-metadata.js") ;;
		*) echo "unknown access-metadata target ${target}" >&2; exit 1 ;;
	esac
	if "${scoped_haxe}" \
		-cp "${fixture_root}/src" \
		-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
		-cp "${fixture_root}/test-negative/access_metadata" \
		-main Main \
		--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
		"${output_args[@]}" >"${diagnostic}" 2>&1; then
		echo "Haxe access metadata exposed the private authority subtype on ${target}" >&2
		exit 1
	fi
	grep -F -- 'Importing private declarations from a module is not allowed' "${diagnostic}" >/dev/null
}

assert_access_metadata_failure interp
assert_access_metadata_failure php
assert_access_metadata_failure javascript

assert_compile_failure direct_token_construction \
	'wordpress.hx.adoption.prototype.PhpRequestScope should be wordpress.hx.adoption.prototype._Adoption.AuthorityKey'
assert_compile_failure wrong_capability \
	'wordpress.hx.adoption.prototype.CalendarReadCapability should be wordpress.hx.adoption.prototype.CalendarBadgeCapability'
assert_compile_failure cross_request_scope \
	'wordpress.hx.adoption.prototype.PhpRequestScope should be wordpress.hx.adoption.prototype.BrowserModuleScope'
assert_compile_failure omitted_binding \
	'Class<wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar> has no field magicLookup'
assert_compile_failure observation_forgery \
	'String should be wordpress.hx.adoption.prototype._Adoption.AuthorityKey'
assert_compile_failure scope_forgery \
	'Not enough arguments, expected key:wordpress.hx.adoption.prototype._Adoption.AuthorityKey'
assert_compile_failure authority_core_spoof \
	'Not enough arguments, expected key:wordpress.hx.adoption.prototype._Adoption.AuthorityKey' \
	'String should be wordpress.hx.adoption.prototype._Adoption.AuthorityKey'

friend_diagnostic="${test_root}/friend-path-spoof.diagnostic.txt"
if "${scoped_haxe}" \
		-cp "${fixture_root}/src" \
		-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
		-cp "${fixture_root}/test-negative/friend_path_spoof" \
		-main Main \
		--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
		--interp >"${friend_diagnostic}" 2>&1; then
	echo "exact legacy TargetProbe friend path spoof compiled successfully" >&2
	exit 1
fi
for expected_fragment in \
	'Not enough arguments, expected key:wordpress.hx.adoption.prototype._Adoption.AuthorityKey' \
	'String should be wordpress.hx.adoption.prototype._Adoption.AuthorityKey'; do
	if ! grep --fixed-strings --quiet -- "${expected_fragment}" "${friend_diagnostic}"; then
		echo "exact legacy TargetProbe friend path spoof omitted diagnostic: ${expected_fragment}" >&2
		sed -n '1,80p' "${friend_diagnostic}" >&2
		exit 1
	fi
done
mark_observer haxe

if [[ -e "${WORDPRESSHX_ADOPTION_POISON_SENTINEL}" ]]; then
	echo "ADR-015 default generation executed provider runtime code" >&2
	exit 1
fi

observer_output="${WORDPRESSHX_ADOPTION_OBSERVER_OUTPUT:-${test_root}/local-observers.json}"
python3 - "${repository_root}" "${observer_parts}" "${observer_output}" "${php_mode}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
parts = Path(sys.argv[2])
output = Path(sys.argv[3])
execution_mode = sys.argv[4]
sys.path.insert(0, str(root / "scripts/adoption"))
from evidence_state import OBSERVER_IDS, current_content_root, evidence_subject_sha256, observer_identities, python_runtime_identity

identities = observer_identities(root)
observers = [json.loads((parts / f"{observer_id}.json").read_text(encoding="utf-8")) for observer_id in OBSERVER_IDS]
if any(value["contentRoot"] != current_content_root(root) for value in observers):
    raise SystemExit("observer receipts used different content roots")
if any(value["evidenceSubjectSha256"] != evidence_subject_sha256(root) for value in observers):
    raise SystemExit("observer receipts used different evidence subjects")
for value in observers:
    value.pop("contentRoot")
    value.pop("evidenceSubjectSha256")
record = {
    "contentRoot": current_content_root(root),
    "evidenceSubjectSha256": evidence_subject_sha256(root),
    "executionMode": execution_mode,
    "observedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "pythonRuntime": python_runtime_identity(root),
    "observers": observers,
}
output.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
PY
python3 "${repository_root}/scripts/adoption/record-evidence.py" \
	--mode "${php_mode}" \
	--observers "${observer_output}" \
	--output "${test_root}/recorded-local-receipt.json"

echo "ADR-015 adoption contract passed with static generation, immutable native-provider handles, and Haxe observers"
