#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
subject_commit="0e01ab5e18fe023e43f2d45e1052bdccef658f05"
fixture="fixtures/output-context/test-negative/json_plan_success/Main.hx"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
proof_root="$(mktemp -d "${temporary_parent}/wordpresshx-json-red.XXXXXX")"
subject_tree="${proof_root}/subject"
current_log="${proof_root}/current.log"
subject_log="${proof_root}/subject.log"

cleanup() {
	if [[ -d "${subject_tree}" ]]; then
		git -C "${repository_root}" worktree remove --force "${subject_tree}"
	fi
	case "${proof_root}" in
		"${temporary_parent}"/wordpresshx-json-red.*) rm -rf -- "${proof_root}" ;;
		*) echo "refusing to remove unexpected JSON red-proof path" >&2 ;;
	esac
}
trap cleanup EXIT

for command_name in cp git haxe mkdir sed; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "JSON red proof requires ${command_name}" >&2
		exit 1
	fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
	echo "JSON red proof requires Haxe 4.3.7" >&2
	exit 1
fi

git -C "${repository_root}" worktree add --detach "${subject_tree}" "${subject_commit}" >/dev/null
mkdir -p "${subject_tree}/$(dirname "${fixture}")"
cp -f "${repository_root}/${fixture}" "${subject_tree}/${fixture}"

compile_fixture() {
	local source_root="$1"
	(
		cd "${source_root}"
		haxe \
			-cp fixtures/output-context/src \
			-cp fixtures/output-context/test-negative/json_plan_success \
			-cp packages/contracts/src \
			-main Main \
			--macro 'nullSafety("wordpress.hx.output.prototype", Strict)' \
			--interp
	)
}

set +e
compile_fixture "${repository_root}" >"${current_log}" 2>&1
current_exit=$?
compile_fixture "${subject_tree}" >"${subject_log}" 2>&1
subject_exit=$?
set -e

if [[ "${subject_exit}" -ne 0 ]]; then
	echo "reviewed subject no longer reproduces the public raw-success bypass" >&2
	sed -n '1,20p' "${subject_log}" >&2
	exit 1
fi
if [[ "${current_exit}" -eq 0 ]]; then
	echo "current tree still permits public raw-success construction" >&2
	exit 1
fi
if ! grep --fixed-strings --quiet \
	'Class<wordpress.hx.output.prototype.JsonPlan> has no field success' \
	"${current_log}"; then
	echo "current tree failed for an unexpected reason" >&2
	sed -n '1,20p' "${current_log}" >&2
	exit 1
fi

printf 'JSON_PLAN_RED_PROOF subject=%s subjectExit=%s currentExit=%s\n' \
	"${subject_commit}" "${subject_exit}" "${current_exit}"
sed -n '1p' "${current_log}"
