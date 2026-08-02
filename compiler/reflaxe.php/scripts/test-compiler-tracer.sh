#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
tracer_root="${package_root}/test/compiler-tracer"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/reflaxe-php-tracer.XXXXXX")"
trap 'rm -rf "${temporary_root}"' EXIT

compile_tracer() {
	local output_root="$1"
	(
		cd "${package_root}"
		haxe test/compiler-tracer/build.hxml -D "reflaxe_php_output=${output_root}"
	)
}

first_output="${temporary_root}/first"
second_output="${temporary_root}/second"
compile_tracer "${first_output}"
compile_tracer "${second_output}"

diff -ru "${first_output}" "${second_output}"
expected_php_count=0
while IFS= read -r expected_php; do
	relative_php="${expected_php#${tracer_root}/expected/}"
	cmp "${expected_php}" "${first_output}/${relative_php}"
	expected_php_count=$((expected_php_count + 1))
done < <(find "${tracer_root}/expected" -type f -name '*.php' | sort)
generated_php_count="$(find "${first_output}" -type f -name '*.php' | wc -l | tr -d ' ')"
test "${generated_php_count}" = "${expected_php_count}"
while IFS= read -r generated_php; do
	php -l "${generated_php}" >/dev/null
done < <(find "${first_output}" -type f -name '*.php' | sort)
php -d error_reporting=-1 -d display_errors=1 "${first_output}/bootstrap.php" >"${temporary_root}/actual.stdout" 2>"${temporary_root}/actual.stderr"
test ! -s "${temporary_root}/actual.stderr"
cmp "${tracer_root}/expected.stdout" "${temporary_root}/actual.stdout"
python3 "${package_root}/scripts/verify-compiler-tracer.py" \
	"${tracer_root}/src/tracer/Main.hx" \
	"${first_output}"

if rg -n 'reflaxe\.php\.(ir|compiler)' "${tracer_root}/src"; then
	echo "ordinary-Haxe tracer imports compiler implementation or PHP IR" >&2
	exit 1
fi
if find "${tracer_root}/src" -type f -name '*.php' -print -quit | grep -q .; then
	echo "ordinary-Haxe tracer contains handwritten PHP" >&2
	exit 1
fi

negative_output="${temporary_root}/negative"
set +e
negative_diagnostic="$(
	cd "${package_root}"
	haxe test/compiler-tracer/negative/unsupported-value/build.hxml \
		-D "reflaxe_php_output=${negative_output}" 2>&1
)"
negative_status=$?
set -e
if (( negative_status == 0 )); then
	echo "unsupported typed AST unexpectedly compiled" >&2
	exit 1
fi
if [[ "${negative_diagnostic}" != *"reflaxe.php supports only String literals, String locals, and exact String concatenation without coercion"* ]]; then
	printf '%s\n' "${negative_diagnostic}" >&2
	echo "unsupported typed AST did not preserve its source diagnostic" >&2
	exit 1
fi
if [[ -d "${negative_output}" ]] && find "${negative_output}" -type f -print -quit | grep -q .; then
	echo "unsupported typed AST emitted partial output" >&2
	exit 1
fi

assert_profile_negative() {
	local fixture="$1"
	local expected_diagnostic="$2"
	local profile_output="${temporary_root}/profile-${fixture}"
	local profile_diagnostic
	local profile_exit
	set +e
	if [[ "${fixture}" == "missing" ]]; then
		profile_diagnostic="$(
			cd "${package_root}"
			haxe test/compiler-tracer/negative/missing-profile/build.hxml -D "reflaxe_php_output=${profile_output}" 2>&1
		)"
	else
		profile_diagnostic="$(
			cd "${package_root}"
			haxe test/compiler-tracer/build.hxml -D reflaxe_php_profile=php-latest -D "reflaxe_php_output=${profile_output}" 2>&1
		)"
	fi
	profile_exit=$?
	set -e
	if (( profile_exit == 0 )) || [[ "${profile_diagnostic}" != *"${expected_diagnostic}"* ]]; then
		printf '%s\n' "${profile_diagnostic}" >&2
		echo "PHP profile negative fixture did not fail closed: ${fixture}" >&2
		exit 1
	fi
	if [[ -d "${profile_output}" ]] && find "${profile_output}" -type f -print -quit | grep -q .; then
		echo "PHP profile negative fixture emitted partial output: ${fixture}" >&2
		exit 1
	fi
}

assert_profile_negative "missing" "reflaxe.php requires -D reflaxe_php_profile=<exact profile ID>"
assert_profile_negative "invalid" "Unsupported reflaxe.php target profile: php-latest"

python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" \
	"${package_root}/src/reflaxe/php/compiler" \
	"${tracer_root}"

echo "reflaxe.php ordinary-Haxe compiler tracer passed"
