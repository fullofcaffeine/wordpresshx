#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(cd "${package_root}/../.." && pwd)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
php_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"

for command_name in docker haxe haxelib lix node python3 realpath; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "PHP trace CLI gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "PHP trace CLI gate requires host Haxe 4.3.7" >&2
  exit 1
fi

lix_command="$(command -v lix)"
lix_bin_dir="$(cd "$(dirname "${lix_command}")" && pwd -P)"
lix_package_path="$(cd "$(dirname "$(realpath "${lix_command}")")/.." && pwd -P)/package.json"
lix_haxe="${lix_bin_dir}/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
  echo "PHP trace CLI gate requires Lix package 15.12.4 (CLI 15.12.2) and its Haxe shim" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "PHP trace CLI gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi
docker info >/dev/null

python3 "${package_root}/scripts/verify-dependency-lock.py"
(
  cd "${package_root}"
  lix --silent download
)
haxelib run formatter --check -s "${package_root}/src"

bash "${repository_root}/compiler/wordpress/scripts/test.sh"

temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
evidence_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk025-evidence.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk025-replay.XXXXXX")"
cleanup() {
  for temporary_root in "${evidence_root}" "${replay_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk025-*) rm -rf -- "${temporary_root}" ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
}
trap cleanup EXIT

rm -rf -- "${package_root}/build"
mkdir -p "${package_root}/build" "${replay_root}/build"
(
  cd "${package_root}"
  "${lix_haxe}" profiles/classic.hxml -js build/index.js
  "${lix_haxe}" profiles/classic.hxml -js "${replay_root}/build/index.js"
)
python3 "${package_root}/scripts/add-node-shebang.py" "${package_root}/build/index.js"
python3 "${package_root}/scripts/add-node-shebang.py" "${replay_root}/build/index.js"
diff -ru "${package_root}/build" "${replay_root}/build"
if [[ "$(head -n 1 "${package_root}/build/index.js")" != '#!/usr/bin/env node' ]] \
  || [[ ! -x "${package_root}/build/index.js" ]]; then
  echo "Genes CLI entry is not an executable Node launcher" >&2
  exit 1
fi

mkdir -p "${evidence_root}/stacks" "${evidence_root}/outputs"
python3 "${repository_root}/compiler/wordpress/scripts/package-source-correlation.py" \
  --output-root "${evidence_root}/packages" \
  --extract-root "${evidence_root}/packaged/source-correlation"
python3 "${repository_root}/compiler/wordpress/scripts/package-source-correlation.py" \
  --output-root "${evidence_root}/packages-replay"
diff -ru "${evidence_root}/packages" "${evidence_root}/packages-replay"
docker run --rm --network none "${node_image}" node --version | grep -Fx 'v22.17.0' >/dev/null
for profile in development packaged-evidence; do
  if [[ "${profile}" == "development" ]]; then
    fixture="/repo/compiler/wordpress/build/source-correlation/development/includes/FailureCallbacks.php"
    index="/repo/compiler/wordpress/build/source-correlation/development/source-index.json"
  else
    fixture="/evidence/packaged/source-correlation/includes/FailureCallbacks.php"
    index="/evidence/packaged/source-correlation/source-index.json"
  fi
  for mode in hook rest render private; do
    stack="${evidence_root}/stacks/${profile}-${mode}.stack"
    set +e
    docker run --rm --network none \
      --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
      --mount "type=bind,src=${evidence_root},dst=/evidence" \
      -w /repo "${php_image}" php \
      /repo/compiler/wordpress/runtime/source-correlation-caller.php \
      "${fixture}" "${mode}" >"${stack}" 2>&1
    stack_status=$?
    set -e
    if (( stack_status != 17 )); then
      echo "${profile}/${mode} locked PHP fixture exited ${stack_status}, expected 17" >&2
      sed -n '1,120p' "${stack}" >&2
      exit 1
    fi

    output="${evidence_root}/outputs/${profile}-${mode}.json"
    docker run --rm --network none \
      --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
      --mount "type=bind,src=${evidence_root},dst=/evidence" \
      -w /repo "${node_image}" node /repo/packages/cli/build/index.js \
      trace php "/evidence/stacks/${profile}-${mode}.stack" \
      --index "${index}" --source-root project=/repo --format json >"${output}"
    docker run --rm --network none \
      --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
      --mount "type=bind,src=${evidence_root},dst=/evidence" \
      -w /repo "${node_image}" node /repo/packages/cli/build/index.js \
      trace php "/evidence/stacks/${profile}-${mode}.stack" \
      --index "${index}" --source-root project=/repo --format json >"${output}.replay"
    cmp "${output}" "${output}.replay"
  done
done

docker run --rm --network none \
  --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
  --mount "type=bind,src=${evidence_root},dst=/evidence" \
  -w /repo "${node_image}" node /repo/packages/cli/build/index.js \
  trace php /evidence/stacks/development-private.stack \
  --index /repo/compiler/wordpress/build/source-correlation/development/source-index.json \
  --source-root project=/repo --format text >"${evidence_root}/outputs/development-private.text"

printf '%s\n' 'RuntimeException: basename failure in FailureCallbacks.php:9' \
  >"${evidence_root}/stacks/basename.stack"
docker run --rm --network none \
  --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
  --mount "type=bind,src=${evidence_root},dst=/evidence" \
  -w /repo "${node_image}" node /repo/packages/cli/build/index.js \
  trace php /evidence/stacks/basename.stack \
  --index /repo/compiler/wordpress/build/source-correlation/development/source-index.json \
  --source-root project=/repo --format json >"${evidence_root}/outputs/basename.json"

python3 "${package_root}/scripts/verify-php-trace.py" "${evidence_root}"

python3 - "${evidence_root}" "${repository_root}/compiler/wordpress/build/source-correlation/development" <<'PY'
import copy
import hashlib
import json
import shutil
import sys
from pathlib import Path

evidence = Path(sys.argv[1])
source = Path(sys.argv[2])
mutations = evidence / "mutations"


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def clone(name):
    target = mutations / name
    shutil.copytree(source, target)
    return target


def refresh(root, map_document=None):
    index_path = root / "source-index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    if map_document is not None:
        map_path = root / "includes/FailureCallbacks.php.haxe-map.json"
        map_source = canonical(map_document) + "\n"
        map_path.write_text(map_source, encoding="utf-8")
        record = next(file for file in index["files"] if file["role"] == "source-map")
        record["sha256"] = hashlib.sha256(map_source.encode()).hexdigest()
        record["byteLength"] = len(map_source.encode())
    index["artifactSetSha256"] = hashlib.sha256(
        canonical(index["files"]).encode()
    ).hexdigest()
    index_path.write_text(canonical(index) + "\n", encoding="utf-8")


root = clone("stale-map")
with (root / "includes/FailureCallbacks.php.haxe-map.json").open("a", encoding="utf-8") as file:
    file.write(" ")

root = clone("dishonest-coordinate")
document = json.loads((root / "includes/FailureCallbacks.php.haxe-map.json").read_text())
document["mappings"][2]["origin"]["sourceSpan"]["start"]["columnUtf8"] += 1
refresh(root, document)

root = clone("ambiguous-anchor")
document = json.loads((root / "includes/FailureCallbacks.php.haxe-map.json").read_text())
document["traceAnchors"].append(copy.deepcopy(document["traceAnchors"][0]))
document["traceAnchors"].sort(key=lambda anchor: anchor["generatedLine"])
refresh(root, document)

root = clone("absolute-path")
index_path = root / "source-index.json"
index = json.loads(index_path.read_text())
next(file for file in index["files"] if file["role"] == "runtime")["path"] = "/tmp/FailureCallbacks.php"
index["artifactSetSha256"] = hashlib.sha256(canonical(index["files"]).encode()).hexdigest()
index_path.write_text(canonical(index) + "\n", encoding="utf-8")

root = clone("unknown-field")
index_path = root / "source-index.json"
index = json.loads(index_path.read_text())
index["lookupByBasename"] = True
index_path.write_text(canonical(index) + "\n", encoding="utf-8")

root = clone("stale-generated")
with (root / "includes/FailureCallbacks.php").open("a", encoding="utf-8") as file:
    file.write("// stale\n")
PY

expect_exit() {
  local expected="$1"
  local mutation="$2"
  set +e
  docker run --rm --network none \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${evidence_root},dst=/evidence" \
    -w /repo "${node_image}" node /repo/packages/cli/build/index.js \
    trace php /evidence/stacks/development-hook.stack \
    --index "/evidence/mutations/${mutation}/source-index.json" \
    --source-root project=/repo --format json \
    >"${evidence_root}/outputs/negative-${mutation}.out" \
    2>"${evidence_root}/outputs/negative-${mutation}.err"
  local status=$?
  set -e
  if (( status != expected )); then
    echo "${mutation} exited ${status}, expected ${expected}" >&2
    sed -n '1,120p' "${evidence_root}/outputs/negative-${mutation}.err" >&2
    exit 1
  fi
}

expect_exit 3 stale-map
expect_exit 3 dishonest-coordinate
expect_exit 4 ambiguous-anchor
expect_exit 3 absolute-path
expect_exit 3 unknown-field
expect_exit 3 stale-generated

expect_usage_exit() {
  local label="$1"
  shift
  set +e
  docker run --rm --network none \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${evidence_root},dst=/evidence" \
    -w /repo "${node_image}" node /repo/packages/cli/build/index.js "$@" \
    >"${evidence_root}/outputs/usage-${label}.out" \
    2>"${evidence_root}/outputs/usage-${label}.err"
  local result=$?
  set -e
  if (( result != 2 )); then
    echo "${label} exited ${result}, expected usage/stack-input exit 2" >&2
    sed -n '1,120p' "${evidence_root}/outputs/usage-${label}.err" >&2
    exit 1
  fi
}

: >"${evidence_root}/stacks/empty.stack"
printf '%s\n' \
  'RuntimeException: impossible line in /repo/compiler/wordpress/build/source-correlation/development/includes/FailureCallbacks.php:9999' \
  >"${evidence_root}/stacks/out-of-range.stack"
expect_usage_exit browser-not-admitted trace browser placeholder
expect_usage_exit invalid-source-root-id \
  trace php /evidence/stacks/development-hook.stack \
  --index /repo/compiler/wordpress/build/source-correlation/development/source-index.json \
  --source-root 'bad id=/repo' --format json
expect_usage_exit unknown-source-root-id \
  trace php /evidence/stacks/development-hook.stack \
  --index /repo/compiler/wordpress/build/source-correlation/development/source-index.json \
  --source-root unknown=/repo --format json
expect_usage_exit empty-stack \
  trace php /evidence/stacks/empty.stack \
  --index /repo/compiler/wordpress/build/source-correlation/development/source-index.json \
  --source-root project=/repo --format json
expect_usage_exit missing-index \
  trace php /evidence/stacks/development-hook.stack \
  --index /evidence/missing-index.json --source-root project=/repo --format json
expect_usage_exit out-of-range-frame \
  trace php /evidence/stacks/out-of-range.stack \
  --index /repo/compiler/wordpress/build/source-correlation/development/source-index.json \
  --source-root project=/repo --format json

mac_home_marker="/Us""ers/"
linux_home_marker="/ho""me/"
workspace_marker="workspace/co""de"
local_path_pattern="${mac_home_marker}|${linux_home_marker}|[A-Za-z]:\\\\|${workspace_marker}"
if grep -R -n -E "${local_path_pattern}" \
  "${repository_root}/compiler/wordpress/build/source-correlation/development/source-index.json" \
  "${repository_root}/compiler/wordpress/build/source-correlation/development/includes/FailureCallbacks.php.haxe-map.json" \
  "${repository_root}/compiler/wordpress/build/source-correlation/packaged-evidence/source-index.json" \
  "${repository_root}/compiler/wordpress/build/source-correlation/packaged-evidence/includes/FailureCallbacks.php.haxe-map.json"; then
  echo "source-correlation metadata leaked a machine path" >&2
  exit 1
fi

echo "WordPressHx Haxe/Genes PHP trace CLI passed"
