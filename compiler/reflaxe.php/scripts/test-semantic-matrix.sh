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
cmp "${first_output}/main.php" "${second_output}/main.php"
cmp "${first_output}/main.php.haxe-map.json" "${second_output}/main.php.haxe-map.json"
cmp "${fixture_root}/expected/main.php" "${first_output}/main.php"

(
	cd "${package_root}"
	haxe -cp test/semantic-matrix/src --run semantics.Main
) >"${temporary_root}/haxe.stdout"
cmp "${fixture_root}/expected.stdout" "${temporary_root}/haxe.stdout"

php -l "${first_output}/main.php" >"${temporary_root}/php-lint.stdout" 2>"${temporary_root}/php-lint.stderr"
test ! -s "${temporary_root}/php-lint.stderr"
php -d error_reporting=-1 -d display_errors=1 "${first_output}/main.php" \
	>"${temporary_root}/php.stdout" 2>"${temporary_root}/php.stderr"
test ! -s "${temporary_root}/php.stderr"
cmp "${fixture_root}/expected.stdout" "${temporary_root}/php.stdout"
cmp "${temporary_root}/haxe.stdout" "${temporary_root}/php.stdout"

python3 "${package_root}/scripts/verify-semantic-matrix.py" \
	"${fixture_root}/src/semantics/Main.hx" \
	"${first_output}/main.php" \
	"${first_output}/main.php.haxe-map.json"
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" "${fixture_root}"

echo "reflaxe.php numeric/local/control-flow semantic slice passed"
