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

for command_name in docker haxe haxelib lix node npm php python3 realpath; do
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
haxelib run formatter --check -s "${package_root}/dev-reload-client/src"

strict_haxe_paths=(
	"${package_root}/dev-reload-client/src"
  "${package_root}/src/wordpresshx/cli/closedjson"
  "${package_root}/src/wordpresshx/cli/project/DevEngine.hx"
  "${package_root}/src/wordpresshx/cli/project/development"
)
if ! python3 - "${strict_haxe_paths[@]}" <<'PY'
import re
import sys
from pathlib import Path

forbidden = re.compile(r"\b(?:Dynamic|Any|cast|Reflect|untyped)\b")
violations = []
for raw_path in sys.argv[1:]:
    source_path = Path(raw_path)
    candidates = [source_path] if source_path.is_file() else sorted(source_path.rglob("*.hx"))
    for candidate in candidates:
        for line_number, line in enumerate(candidate.read_text(encoding="utf-8").splitlines(), 1):
            if forbidden.search(line):
                violations.append(f"{candidate}:{line_number}:{line}")
if violations:
    print("\n".join(violations))
    raise SystemExit(1)
PY
then
	echo "SDK-044 service runtime must remain strictly typed" >&2
	exit 1
fi

reload_build_a="${test_root}/reload-build-a"
reload_build_b="${test_root}/reload-build-b"
reload_tooling="${test_root}/reload-tooling"
mkdir -p "${reload_build_a}" "${reload_build_b}" "${reload_tooling}"
(
	cd "${package_root}"
	"${lix_haxe}" profiles/development-reload-client.hxml -js "${reload_build_a}/development-reload-client.js"
	"${lix_haxe}" profiles/development-reload-client.hxml -js "${reload_build_b}/development-reload-client.js"
)
diff -ru "${reload_build_a}" "${reload_build_b}"
cp -f "${package_root}/browser-tooling/package.json" "${reload_tooling}/package.json"
cp -f "${package_root}/browser-tooling/package-lock.json" "${reload_tooling}/package-lock.json"
cp -f "${repository_root}/scripts/dev-loop/test-browser-reload.mjs" "${reload_tooling}/test-browser-reload.mjs"
docker run --rm \
	--user "$(id -u):$(id -g)" \
	-e npm_config_cache=/tmp/npm-cache \
	--mount "type=bind,src=${reload_build_a},dst=/generated-a,readonly" \
	--mount "type=bind,src=${reload_build_b},dst=/generated-b,readonly" \
	--mount "type=bind,src=${reload_tooling},dst=/tooling" \
	-w /tooling \
	docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0 \
	sh -eu -c '
		npm ci --ignore-scripts --no-audit --no-fund
		for generated in /generated-a /generated-b; do
			node_modules/.bin/esbuild "${generated}/development-reload-client.js" \
				--bundle --format=iife --platform=browser --target=es2022 \
				--minify --charset=utf8 --legal-comments=none \
				--outfile="/tooling/$(basename "${generated}").js"
		done
	'
cmp "${reload_tooling}/generated-a.js" "${reload_tooling}/generated-b.js"
cmp "${reload_tooling}/generated-a.js" "${package_root}/assets/development-reload-client.js"

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

python3 "${repository_root}/scripts/dev-loop/test-production.py" "${test_root}/runtime-a" "${reload_tooling}"
