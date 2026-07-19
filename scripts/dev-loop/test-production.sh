#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
package_root="${repository_root}/packages/cli"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk044-gate.XXXXXX")"
cleanup() {
  case "${test_root}" in
    "${temporary_parent}"/wordpresshx-sdk044-gate.*) rm -rf -- "${test_root}" ;;
    *) echo "refusing to remove unexpected SDK-044 test path" >&2 ;;
  esac
}
trap cleanup EXIT

for command_name in docker haxe haxelib lix node python3 realpath rg; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-044 production development-loop gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-044 production development-loop gate requires host Haxe 4.3.7" >&2
  exit 1
fi
docker info >/dev/null
docker compose version >/dev/null

lix_command="$(command -v lix)"
lix_haxe="$(cd "$(dirname "${lix_command}")" && pwd -P)/haxe"
if [[ ! -x "${lix_haxe}" ]] || [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-044 production development-loop gate requires the exact Lix-scoped Haxe shim" >&2
  exit 1
fi
(
  cd "${package_root}"
  lix --silent download
)
haxelib run formatter --check -s "${package_root}/src"

strict_haxe_paths=(
  "${package_root}/src/wordpresshx/cli/closedjson"
  "${package_root}/src/wordpresshx/cli/project/DevEngine.hx"
  "${package_root}/src/wordpresshx/cli/project/development"
)
if rg -n '\b(Dynamic|Any|cast|Reflect|untyped)\b' "${strict_haxe_paths[@]}"; then
  echo "SDK-044 service runtime must remain strictly typed" >&2
  exit 1
fi

mkdir -p "${test_root}/runtime-a" "${test_root}/runtime-b"
(
  cd "${package_root}"
  "${lix_haxe}" profiles/wphx.hxml -js "${test_root}/runtime-a/index.js"
  "${lix_haxe}" profiles/wphx.hxml -js "${test_root}/runtime-b/index.js"
)
python3 "${package_root}/scripts/add-node-shebang.py" "${test_root}/runtime-a/index.js"
python3 "${package_root}/scripts/add-node-shebang.py" "${test_root}/runtime-b/index.js"
diff -ru "${test_root}/runtime-a" "${test_root}/runtime-b"

docker run --rm --network none \
  docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0 \
  node --version | grep -Fx 'v22.17.0' >/dev/null

python3 "${repository_root}/scripts/dev-loop/test-production.py" "${test_root}/runtime-a"
