#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
fixture_root="${package_root}/test/native-global"
authored_root="${repository_root}/fixtures/reflaxe-php-native-global"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/reflaxe-php-native-global.XXXXXX")"
trap 'rm -rf -- "${temporary_root}"' EXIT

compile_fixture() {
	local output_root="$1"
	(
		cd "${package_root}"
		haxe test/native-global/build.hxml -D "reflaxe_php_output=${output_root}"
	)
}

first_output="${temporary_root}/first"
second_output="${temporary_root}/second"
compile_fixture "${first_output}"
compile_fixture "${second_output}"
diff -ru "${first_output}" "${second_output}"

cmp \
	"${fixture_root}/expected/modules/13_native_global/4_Main/4_Main.php" \
	"${first_output}/modules/13_native_global/4_Main/4_Main.php"
while IFS= read -r generated_php; do
	php -l "${generated_php}" >/dev/null
done < <(find "${first_output}" -type f -name '*.php' | sort)
php -d error_reporting=-1 -d display_errors=1 "${first_output}/bootstrap.php" \
	>"${temporary_root}/actual.stdout" 2>"${temporary_root}/actual.stderr"
test ! -s "${temporary_root}/actual.stderr"
cmp "${fixture_root}/expected.stdout" "${temporary_root}/actual.stdout"

assert_negative() {
	local fixture="$1"
	local expected="$2"
	local output_root="${temporary_root}/negative-${fixture}"
	local diagnostic
	local exit_code
	set +e
	diagnostic="$(
		cd "${package_root}"
		haxe "test/native-global/negative/${fixture}/build.hxml" \
			-D "reflaxe_php_output=${output_root}" 2>&1
	)"
	exit_code=$?
	set -e
	if (( exit_code == 0 )) || [[ "${diagnostic}" != *"${expected}"* ]]; then
		printf '%s\n' "${diagnostic}" >&2
		echo "typed native-global negative did not fail as expected: ${fixture}" >&2
		exit 1
	fi
	if [[ -d "${output_root}" ]] && find "${output_root}" -type f -print -quit | grep -q .; then
		echo "typed native-global negative emitted partial output: ${fixture}" >&2
		exit 1
	fi
}

assert_negative "missing-annotation" \
	"reflaxe.php tracer supports only Sys.println or a typed @:phpGlobalFunction extern call with admitted String arguments"
assert_negative "invalid-name" \
	"reflaxe.php @:phpGlobalFunction contains an invalid PHP function name"

if rg -n 'reflaxe\.php\.(ir|compiler)' "${authored_root}"; then
	echo "native-global consumer imports compiler implementation or PHP IR" >&2
	exit 1
fi
if find "${authored_root}" -type f -name '*.php' -print -quit | grep -q .; then
	echo "native-global consumer contains handwritten PHP" >&2
	exit 1
fi
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" \
	"${package_root}/src/reflaxe/php/compiler" \
	"${authored_root}"

echo "reflaxe.php typed native-global boundary passed"
