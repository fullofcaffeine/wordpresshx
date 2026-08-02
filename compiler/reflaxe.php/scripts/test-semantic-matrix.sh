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

python3 "${package_root}/scripts/verify-semantic-matrix.py" \
	"${fixture_root}/src" \
	"${first_output}"

assert_compile_negative() {
	local fixture="$1"
	local expected_diagnostic="$2"
	local negative_output="${temporary_root}/negative-${fixture}"
	local negative_diagnostic
	local negative_status
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
assert_compile_negative "non-int-signature" "reflaxe.php supports only Void and Int method returns"
assert_compile_negative "foreign-static-call" "reflaxe.php supports only source-owned static Int calls"
assert_compile_negative "do-while" "reflaxe.php does not yet support do-while loops"
assert_compile_negative "compound-assignment" "reflaxe.php does not yet support compound assignment"
assert_compile_negative "dynamic-array-index" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
assert_compile_negative "out-of-bounds-array-index" "reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant"
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" "${fixture_root}"

echo "reflaxe.php numeric/local/control-flow/function-call/while/array semantic slices passed"
