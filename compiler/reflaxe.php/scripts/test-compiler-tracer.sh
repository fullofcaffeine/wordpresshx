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

cmp "${first_output}/main.php" "${second_output}/main.php"
cmp "${first_output}/main.php.haxe-map.json" "${second_output}/main.php.haxe-map.json"
cmp "${tracer_root}/expected/main.php" "${first_output}/main.php"
php -l "${first_output}/main.php" >/dev/null
php "${first_output}/main.php" >"${temporary_root}/actual.stdout"
cmp "${tracer_root}/expected.stdout" "${temporary_root}/actual.stdout"
python3 "${package_root}/scripts/verify-compiler-tracer.py" \
	"${tracer_root}/src/tracer/Main.hx" \
	"${first_output}/main.php" \
	"${first_output}/main.php.haxe-map.json"

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
if [[ "${negative_diagnostic}" != *"reflaxe.php tracer supports only string literal values"* ]]; then
	printf '%s\n' "${negative_diagnostic}" >&2
	echo "unsupported typed AST did not preserve its source diagnostic" >&2
	exit 1
fi
if [[ -e "${negative_output}/main.php" || -e "${negative_output}/main.php.haxe-map.json" ]]; then
	echo "unsupported typed AST emitted partial output" >&2
	exit 1
fi

python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" \
	"${package_root}/src/reflaxe/php/compiler" \
	"${tracer_root}"

echo "reflaxe.php ordinary-Haxe compiler tracer passed"
