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

for command_name in cmp cp diff docker grep haxelib lix node perl python3; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "ADR-015 adoption-contract gate requires ${command_name}" >&2
		exit 1
	fi
done

python3 "${repository_root}/scripts/adoption/refresh-evidence.py"
python3 "${repository_root}/scripts/adoption/validate-architecture.py"
python3 "${repository_root}/scripts/adoption/test-evidence.py"

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

export WORDPRESSHX_ADOPTION_POISON_SENTINEL="${test_root}/provider-executed"
generation_one="${test_root}/generation-one"
generation_two="${test_root}/generation-two"
python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${generation_one}"
python3 "${repository_root}/scripts/adoption/generate-fixture.py" --output "${generation_two}"
diff -ru "${generation_one}" "${generation_two}"
diff -ru "${fixture_root}/contract" "${generation_one}"
"${node_command}" "${repository_root}/scripts/adoption/test-json-schema.cjs"
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

typescript_root="${repository_root}/packages/gutenberg/build-tooling"
typescript_command="${typescript_root}/node_modules/.bin/tsc"
if [[ ! -x "${typescript_command}" ]]; then
	echo "ADR-015 adoption-contract gate requires the pinned Gutenberg build-tooling install" >&2
	exit 1
fi

(
	cd "${repository_root}/packages/cli"
	lix --silent download
	mkdir -p "${test_root}/ownership-runtime"
	"${scoped_haxe}" \
		-lib genes-ts \
		-lib hxnodejs \
		-cp src \
		-cp "${fixture_root}/test-ownership" \
		-main adoption.ownership.Main \
		-D js-es=6 \
		-D wordpresshx_ownership_fault_injection \
		-dce full \
		-js "${test_root}/ownership-runtime/index.js"
)
python3 "${repository_root}/scripts/adoption/test-ownership.py" \
	"${test_root}/ownership-runtime/index.js" \
	"${generation_one}" \
	"${test_root}/mutated-generation" \
	"${test_root}/ownership-work" \
	"${node_command}"

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
	-cp "${fixture_root}/src" \
	-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
	-cp "${fixture_root}/test-support" \
	-cp "${fixture_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
	--interp >"${test_root}/interp.txt"

(
	cd "${repository_root}/packages/cli"
	"${scoped_haxe}" \
			-cp ../../fixtures/adoption-contract/src \
			-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
			-cp ../../fixtures/adoption-contract/test-support \
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
	-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
	-cp "${fixture_root}/test-support" \
	-cp "${fixture_root}/test" \
	-main "${main_class}" \
	--macro 'nullSafety("wordpress.hx.adoption.prototype", Strict)' \
	--php "${test_root}/php"
if [[ "${php_mode}" == "local" ]]; then
	"${php_runtime}" "${test_root}/php/index.php" >"${test_root}/php.txt"
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
			-cp "${generation_one}/generated/adoption/acme-calendar/haxe" \
			-cp "${fixture_root}/test-support" \
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
	'wordpress.hx.adoption.prototype.PhpRequestScope should be wordpress.hx.adoption.prototype._Adoption.AuthorityKey'
assert_compile_failure wrong_capability \
	'wordpress.hx.adoption.prototype.generated.CalendarReadCapability should be wordpress.hx.adoption.prototype.generated.CalendarBadgeCapability'
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

if [[ -e "${WORDPRESSHX_ADOPTION_POISON_SENTINEL}" ]]; then
	echo "ADR-015 default generation executed provider runtime code" >&2
	exit 1
fi

observer_output="${WORDPRESSHX_ADOPTION_OBSERVER_OUTPUT:-${test_root}/local-observers.json}"
python3 - "${repository_root}" "${observer_output}" "${php_mode}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
output = Path(sys.argv[2])
execution_mode = sys.argv[3]
sys.path.insert(0, str(root / "scripts/adoption"))
from evidence_state import OBSERVER_IDS, current_content_root, observer_identities

identities = observer_identities(root)
record = {
    "contentRoot": current_content_root(root),
    "executionMode": execution_mode,
    "observedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "observers": [
        {"id": observer_id, "identitySha256": identities[observer_id], "outcome": "passed"}
        for observer_id in OBSERVER_IDS
    ],
}
output.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
PY
python3 "${repository_root}/scripts/adoption/record-evidence.py" \
	--mode "${php_mode}" \
	--observers "${observer_output}" \
	--output "${test_root}/recorded-local-receipt.json"

echo "ADR-015 adoption contract passed with static generation, immutable native-provider handles, and Haxe observers"
