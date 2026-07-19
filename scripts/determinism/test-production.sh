#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
package_root="${repository_root}/packages/cli"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk042-gate.XXXXXX")"
cleanup() {
  case "${test_root}" in
    "${temporary_parent}"/wordpresshx-sdk042-gate.*) rm -rf -- "${test_root}" ;;
    *) echo "refusing to remove unexpected SDK-042 test path" >&2 ;;
  esac
}
trap cleanup EXIT

for command_name in docker haxe haxelib lix node python3 realpath; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-042 deterministic build gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-042 deterministic build gate requires host Haxe 4.3.7" >&2
  exit 1
fi
docker info >/dev/null

lix_command="$(command -v lix)"
lix_haxe="$(cd "$(dirname "${lix_command}")" && pwd -P)/haxe"
if [[ ! -x "${lix_haxe}" ]] || [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-042 deterministic build gate requires the exact Lix-scoped Haxe shim" >&2
  exit 1
fi
(
  cd "${package_root}"
  lix --silent download
)
haxelib run formatter --check -s "${package_root}/src"

mkdir -p "${test_root}/runtime-a" "${test_root}/runtime-b"
(
  cd "${package_root}"
  "${lix_haxe}" profiles/wphx.hxml -js "${test_root}/runtime-a/index.js"
  "${lix_haxe}" profiles/wphx.hxml -js "${test_root}/runtime-b/index.js"
)
python3 "${package_root}/scripts/add-node-shebang.py" "${test_root}/runtime-a/index.js"
python3 "${package_root}/scripts/add-node-shebang.py" "${test_root}/runtime-b/index.js"
diff -ru "${test_root}/runtime-a" "${test_root}/runtime-b"

python3 "${repository_root}/scripts/determinism/test-production.py" "${test_root}/runtime-a"
