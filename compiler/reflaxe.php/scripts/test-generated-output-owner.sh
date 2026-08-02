#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/reflaxe-php-output-owner.XXXXXX")"
trap 'rm -rf "${temporary_root}"' EXIT

compile_semantic() {
	local output_root="$1"
	(
		cd "${package_root}"
		haxe test/semantic-matrix/build.hxml -D "reflaxe_php_output=${output_root}"
	)
}

compile_tracer() {
	local output_root="$1"
	(
		cd "${package_root}"
		haxe test/compiler-tracer/build.hxml -D "reflaxe_php_output=${output_root}"
	)
}

transition_root="${temporary_root}/transition"
compile_semantic "${transition_root}"
cp -f "${package_root}/test/semantic-matrix/expected.stdout" "${transition_root}/user-owned.txt"
compile_tracer "${transition_root}"
test -f "${transition_root}/modules/6_tracer/4_Main/4_Main.php"
test ! -e "${transition_root}/modules/9_semantics/10_Calculator/10_Calculator.php"
test ! -e "${transition_root}/modules/9_semantics/4_Main/4_Main.php"
cmp "${package_root}/test/semantic-matrix/expected.stdout" "${transition_root}/user-owned.txt"

owned_module="${transition_root}/modules/6_tracer/4_Main/4_Main.php"
cp -f "${package_root}/test/semantic-matrix/expected.stdout" "${owned_module}"
set +e
modified_diagnostic="$(compile_tracer "${transition_root}" 2>&1)"
modified_exit=$?
set -e
if (( modified_exit == 0 )) || [[ "${modified_diagnostic}" != *"reflaxe.php owned file was modified: modules/6_tracer/4_Main/4_Main.php"* ]]; then
	printf '%s\n' "${modified_diagnostic}" >&2
	echo "modified generated output did not fail closed" >&2
	exit 1
fi
cmp "${package_root}/test/semantic-matrix/expected.stdout" "${owned_module}"

collision_root="${temporary_root}/collision"
mkdir -p "${collision_root}"
cp -f "${package_root}/test/semantic-matrix/expected.stdout" "${collision_root}/bootstrap.php"
set +e
collision_diagnostic="$(compile_tracer "${collision_root}" 2>&1)"
collision_exit=$?
set -e
if (( collision_exit == 0 )) || [[ "${collision_diagnostic}" != *"reflaxe.php refuses to overwrite an unowned file: bootstrap.php"* ]]; then
	printf '%s\n' "${collision_diagnostic}" >&2
	echo "unowned output collision did not fail closed" >&2
	exit 1
fi
cmp "${package_root}/test/semantic-matrix/expected.stdout" "${collision_root}/bootstrap.php"

malformed_root="${temporary_root}/malformed"
mkdir -p "${malformed_root}"
cp -f "${package_root}/test/semantic-matrix/expected.stdout" "${malformed_root}/.reflaxe.php-owned-files.v1"
set +e
malformed_diagnostic="$(compile_tracer "${malformed_root}" 2>&1)"
malformed_exit=$?
set -e
if (( malformed_exit == 0 )) || [[ "${malformed_diagnostic}" != *"reflaxe.php ownership manifest is malformed"* ]]; then
	printf '%s\n' "${malformed_diagnostic}" >&2
	echo "malformed ownership manifest did not fail closed" >&2
	exit 1
fi

echo "reflaxe.php generated-output ownership transitions passed"
