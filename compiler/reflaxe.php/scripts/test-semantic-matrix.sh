#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
fixture_root="${package_root}/test/semantic-matrix"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/reflaxe-php-semantics.XXXXXX")"
trap 'rm -rf "${temporary_root}"' EXIT

python3 "${package_root}/scripts/semantic-matrix.py" validate
python3 "${package_root}/scripts/semantic-matrix.py" self-test

compile_fixture() {
	local output_root="$1"
	(
		cd "${package_root}"
		haxe test/semantic-matrix/build.hxml -D "reflaxe_php_output=${output_root}"
	)
}

first_output="${temporary_root}/first"
second_output="${temporary_root}/second"
compile_fixture "${first_output}"
compile_fixture "${second_output}"
diff -ru "${first_output}" "${second_output}"
expected_php_count=0
while IFS= read -r expected_php; do
	relative_php="${expected_php#${fixture_root}/expected/}"
	cmp "${expected_php}" "${first_output}/${relative_php}"
	expected_php_count=$((expected_php_count + 1))
done < <(find "${fixture_root}/expected" -type f -name '*.php' | sort)
generated_php_count="$(find "${first_output}" -type f -name '*.php' | wc -l | tr -d ' ')"
test "${generated_php_count}" = "${expected_php_count}"

(
	cd "${package_root}"
	haxe -cp test/semantic-matrix/src --run semantics.Main
) >"${temporary_root}/haxe.stdout"
cmp "${fixture_root}/expected.stdout" "${temporary_root}/haxe.stdout"

while IFS= read -r generated_php; do
	php -l "${generated_php}" >>"${temporary_root}/php-lint.stdout" 2>>"${temporary_root}/php-lint.stderr"
done < <(find "${first_output}" -type f -name '*.php' | sort)
test ! -s "${temporary_root}/php-lint.stderr"
php -d error_reporting=-1 -d display_errors=1 "${first_output}/bootstrap.php" \
	>"${temporary_root}/php.stdout" 2>"${temporary_root}/php.stderr"
test ! -s "${temporary_root}/php.stderr"
cmp "${fixture_root}/expected.stdout" "${temporary_root}/php.stdout"
cmp "${temporary_root}/haxe.stdout" "${temporary_root}/php.stdout"

php -d error_reporting=-1 -d display_errors=1 -r '
require $argv[1];
try {
	ReflaxePhpStringRuntime::length("\xFF");
	echo "invalid-utf8:accepted\n";
} catch (RuntimeException $error) {
	echo $error->getMessage() === "reflaxe.php String runtime received invalid UTF-8"
		? "invalid-utf8:rejected\n"
		: "invalid-utf8:wrong-error\n";
}
' "${first_output}/runtime/ReflaxePhpStringRuntime.php" \
	>"${temporary_root}/invalid-utf8.stdout" 2>"${temporary_root}/invalid-utf8.stderr"
test ! -s "${temporary_root}/invalid-utf8.stderr"
test "$(<"${temporary_root}/invalid-utf8.stdout")" = "invalid-utf8:rejected"

python3 "${package_root}/scripts/verify-semantic-matrix.py" \
	"${fixture_root}/src" \
	"${first_output}"

assert_compile_negative() {
	local fixture="$1"
	local expected_diagnostic="$2"
	local negative_output="${temporary_root}/negative-${fixture}"
	local stock_stdout="${temporary_root}/stock-negative-${fixture}.stdout"
	local stock_stderr="${temporary_root}/stock-negative-${fixture}.stderr"
	local negative_diagnostic
	local negative_status
	if ! (
		cd "${package_root}"
		haxe -cp "test/semantic-matrix/negative/${fixture}/src" --run semantics.Main
	) >"${stock_stdout}" 2>"${stock_stderr}"; then
		printf '%s\n' "$(<"${stock_stderr}")" >&2
		echo "semantic negative fixture is not valid under stock Haxe: ${fixture}" >&2
		exit 1
	fi
	if [[ -s "${stock_stderr}" ]]; then
		printf '%s\n' "$(<"${stock_stderr}")" >&2
		echo "semantic negative fixture wrote stock-Haxe stderr: ${fixture}" >&2
		exit 1
	fi
	set +e
	negative_diagnostic="$(
		cd "${package_root}"
		haxe "test/semantic-matrix/negative/${fixture}/build.hxml" \
			-D "reflaxe_php_output=${negative_output}" 2>&1
	)"
	negative_status=$?
	set -e
	if (( negative_status == 0 )); then
		echo "semantic negative fixture unexpectedly compiled: ${fixture}" >&2
		exit 1
	fi
	if [[ "${negative_diagnostic}" != *"${expected_diagnostic}"* ]]; then
		printf '%s\n' "${negative_diagnostic}" >&2
		echo "semantic negative fixture lost its source diagnostic: ${fixture}" >&2
		exit 1
	fi
	if [[ -d "${negative_output}" ]] && find "${negative_output}" -type f -print -quit | grep -q .; then
		echo "semantic negative fixture emitted partial output: ${fixture}" >&2
		exit 1
	fi
}

assert_compile_negative "optional-parameter" "reflaxe.php supports only required parameters without defaults"
assert_compile_negative "non-int-signature" "reflaxe.php supports only Void, Int, Bool, String, and Null<String> method returns"
assert_compile_negative "foreign-static-call" "reflaxe.php supports only source-owned static Int calls"
assert_compile_negative "do-while" "reflaxe.php does not yet support do-while loops"
assert_compile_negative "compound-assignment" "reflaxe.php does not yet support compound assignment"
assert_compile_negative "dynamic-array-index" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
assert_compile_negative "out-of-bounds-array-index" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
assert_compile_negative "unsupported-array-length" "reflaxe.php Array<Int> length requires a compiler-owned non-null Array<Int> local"
assert_compile_negative "array-push-return" "reflaxe.php Array<Int>.push return values are not yet admitted"
assert_compile_negative "array-push-branch" "reflaxe.php Array<Int>.push is admitted only as a direct straight-line statement"
assert_compile_negative "dynamic-array-write" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
assert_compile_negative "out-of-bounds-array-write" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
assert_compile_negative "array-write-branch" "reflaxe.php Array<Int> indexed assignment is admitted only as a direct straight-line statement"
assert_compile_negative "array-pop-return" "reflaxe.php Array<Int>.pop return values are not yet admitted"
assert_compile_negative "array-pop-empty" "reflaxe.php Array<Int>.pop requires a compiler-proven non-empty Array<Int> local"
assert_compile_negative "array-pop-branch" "reflaxe.php Array<Int>.pop is admitted only as a direct straight-line statement"
assert_compile_negative "array-pop-removed-index" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
assert_compile_negative "string-coercion" "reflaxe.php String concatenation accepts only String operands; implicit coercion is not admitted"
assert_compile_negative "null-string-call" "reflaxe.php supports only String literals, String locals, exact String concatenation, and source-owned static String calls without coercion"
assert_compile_negative "null-string-predicate-call" "reflaxe.php supports only String literals, String locals, exact String concatenation, and source-owned static String calls without coercion"
assert_compile_negative "nullable-string-ordering" "reflaxe.php supports only Bool literals, Bool locals, logical negation, lazy Bool conjunction/disjunction, and source-owned static Bool calls"
assert_compile_negative "foreign-string-call" "reflaxe.php supports only source-owned static String calls in the admitted semantic slice"
assert_compile_negative "null-bool-call" "reflaxe.php supports only Bool literals, Bool locals, logical negation, lazy Bool conjunction/disjunction, and source-owned static Bool calls"
assert_compile_negative "bool-null-equality" "reflaxe.php equality requires exact Bool operands, exact Int operands for !=, or an exact Null<String> local compared with null"
assert_compile_negative "foreign-bool-call" "reflaxe.php supports only source-owned static Bool calls in the admitted semantic slice"
assert_compile_negative "mutable-instance-field" "reflaxe.php instance fields must be constructor-initialized and immutable after construction"
assert_compile_negative "inherited-instance-layout" "reflaxe.php instance layout does not yet support inheritance or interfaces"
assert_compile_negative "instance-field-initializer" "reflaxe.php instance fields do not yet support declaration initializers"
assert_compile_negative "multiple-closure-parameters" "reflaxe.php supports only required unary String closures with read-only String captures"
assert_compile_negative "non-string-closure-capture" "reflaxe.php supports only required unary String closures with read-only String captures"
assert_compile_negative "nested-string-closure" "reflaxe.php supports only required unary String closures with read-only String captures"
assert_compile_negative "mutable-string-capture" "reflaxe.php supports assignment only to Int variables or proven Array<Int> indices in the admitted semantic slice"
assert_compile_negative "non-haxe-exception-catch" "reflaxe.php supports exactly one haxe.Exception catch"
assert_compile_negative "non-immediate-exception-throw" "reflaxe.php exception try blocks require one immediate haxe.Exception throw"
assert_compile_negative "catch-local-name-collision" "reflaxe.php requires unique method-local PHP names across Haxe lexical scopes"
assert_compile_negative "nullable-int-local" "reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings"
assert_compile_negative "mutable-nullable-string" "reflaxe.php supports assignment only to Int variables or proven Array<Int> indices in the admitted semantic slice"
assert_compile_negative "nullable-int-return" "reflaxe.php supports only Void, Int, Bool, String, and Null<String> method returns in the admitted semantic slice"
assert_compile_negative "multiple-nullable-string-return-parameters" "reflaxe.php nullable String returns require exactly one required Null<String> parameter"
assert_compile_negative "float-subtraction" "reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings"
assert_compile_negative "float-multiplication" "reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings"
assert_compile_negative "float-ordering" "reflaxe.php supports only Bool literals, Bool locals, logical negation, lazy Bool conjunction/disjunction, and source-owned static Bool calls"
assert_compile_negative "float-inequality" "reflaxe.php equality requires exact Bool operands, exact Int operands for !=, or an exact Null<String> local compared with null"
assert_compile_negative "float-negation" "reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings"
assert_compile_negative "zero-int-remainder" "reflaxe.php Int remainder requires exact Int operands and a compiler-proven nonzero divisor"
assert_compile_negative "float-remainder" "reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings"
assert_compile_negative "runtime-divisor-int-division" "reflaxe.php Std.int division requires exact Int operands and a compiler-proven nonzero divisor"
assert_compile_negative "zero-int-division" "reflaxe.php Std.int division requires exact Int operands and a compiler-proven nonzero divisor"
assert_compile_negative "overflow-int-division" "reflaxe.php constant Int division must produce a signed 32-bit result"
assert_compile_negative "float-int-division" "reflaxe.php Std.int division requires exact Int operands and a compiler-proven nonzero divisor"
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" "${fixture_root}"

echo "reflaxe.php numeric/local/control-flow/function-call/while/array/string/bool/instance-layout/closure/exception/null/runtime semantic slices passed"
