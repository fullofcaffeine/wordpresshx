#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
package_root="${repository_root}/packages/cli"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk045-gate.XXXXXX")"
cleanup() {
  case "${test_root}" in
    "${temporary_parent}"/wordpresshx-sdk045-gate.*) rm -rf -- "${test_root}" ;;
    *) echo "refusing to remove unexpected SDK-045 test path" >&2 ;;
  esac
}
trap cleanup EXIT

for command_name in diff docker haxe haxelib lix node npm php python3 realpath; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-045 production scaffold gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-045 production scaffold gate requires host Haxe 4.3.7" >&2
  exit 1
fi
docker info >/dev/null

lix_command="$(command -v lix)"
lix_haxe="$(cd "$(dirname "${lix_command}")" && pwd -P)/haxe"
if [[ ! -x "${lix_haxe}" ]] || [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-045 production scaffold gate requires the exact Lix-scoped Haxe shim" >&2
  exit 1
fi
(
  cd "${package_root}"
  lix --silent download
)
haxelib run formatter --check -s "${package_root}/src" -s "${package_root}/project-api"

if ! python3 - \
	"${package_root}/project-api" \
	"${package_root}/src/wordpresshx/cli/scaffold" \
	"${package_root}/src/wordpresshx/cli/WphxMain.hx" \
	"${package_root}/src/wordpresshx/cli/project/CompilerRunner.hx" \
	"${package_root}/src/wordpresshx/cli/project/ProjectBuild.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginArtifactPermissions.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginBuildPublisher.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginCompilationRegistry.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginEmission.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginEmittedFile.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginEmitter.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginLockIdentity.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginLockReader.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginMacroInvocation.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginMacroRuntime.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginPlan.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginPlanReader.hx" \
	"${package_root}/src/wordpresshx/cli/project/PluginProjectBuild.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/DevelopmentPlan.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/DevelopmentPlanReader.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/DevelopmentPlugin.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/DevelopmentProject.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/ReadinessProbe.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/RunningService.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/WordPressBootstrapAdapter.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/WordPressProvider.hx" \
	"${package_root}/src/wordpresshx/cli/project/development/WordPressReloadAdapter.hx" <<'PY'
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
  echo "SDK-045 scaffold boundary must remain strictly typed" >&2
  exit 1
fi

mkdir -p "${test_root}/runtime-a" "${test_root}/runtime-b" "${test_root}/actual-parent"
(
  cd "${package_root}"
  "${lix_haxe}" profiles/wphx.hxml -js "${test_root}/runtime-a/index.js"
  "${lix_haxe}" profiles/wphx.hxml -js "${test_root}/runtime-b/index.js"
)
python3 "${package_root}/scripts/add-node-shebang.py" "${test_root}/runtime-a/index.js"
python3 "${package_root}/scripts/add-node-shebang.py" "${test_root}/runtime-b/index.js"
diff -ru "${test_root}/runtime-a" "${test_root}/runtime-b"

node "${test_root}/runtime-a/index.js" new site actual-site \
  --project "${test_root}/actual-parent" --json >/dev/null
(
  cd "${test_root}/actual-parent/actual-site"
  haxe .wphx/bootstrap/project.hxml
)

docker run --rm --network none \
  docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0 \
  node --version | grep -Fx 'v22.17.0' >/dev/null

python3 "${repository_root}/scripts/scaffold/test-production.py" "${test_root}/runtime-a"
python3 "${repository_root}/scripts/scaffold/test-plugin-production.py" "${test_root}/runtime-a"
echo "SDK-045 Haxe-first scaffold gate passed"
