#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(cd "${package_root}/../.." && pwd)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
playwright_image="mcr.microsoft.com/playwright@sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d"

for command_name in diff docker haxe haxelib lix node npm python3 realpath; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-034 browser source-correlation gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-034 browser source-correlation gate requires host Haxe 4.3.7" >&2
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
  echo "SDK-034 gate requires Lix package 15.12.4 (CLI 15.12.2) and its Haxe shim" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-034 gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi
docker info >/dev/null

python3 "${package_root}/scripts/verify-dependency-lock.py"
python3 "${repository_root}/scripts/docker/check-image-lock.py"
(
  cd "${package_root}"
  lix --silent download
)
haxelib run formatter --check \
  -s "${package_root}/src" \
  -s "${package_root}/test/browser-source-correlation/src"

haxe_install_root="$(dirname "$(haxelib config)")"
haxe_library_cache="${haxe_install_root}/haxe_libraries"
genes_root="${haxe_library_cache}/genes-ts/1.36.3/github/c59ecb361fd91418584487c2138bae8d3d3a3961/src"
haxe_stdlib_root="${haxe_install_root}/versions/4.3.7/std"
if [[ ! -f "${genes_root}/genes/Register.hx" ]] \
  || [[ ! -f "${haxe_stdlib_root}/StdTypes.hx" ]]; then
  echo "SDK-034 gate could not resolve its exact Lix Genes/Haxe source roots" >&2
  echo "expected Genes root: ${genes_root}" >&2
  echo "expected Haxe standard-library root: ${haxe_stdlib_root}" >&2
  exit 1
fi

temporary_parent="${package_root}/.sdk034-tmp"
mkdir -p "${temporary_parent}"
generated_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-generated.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-tooling.XXXXXX")"
evidence_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-evidence.XXXXXX")"
evidence_replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-evidence-replay.XXXXXX")"
extract_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-extract.XXXXXX")"
browser_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-browser.XXXXXX")"
mutation_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-mutations.XXXXXX")"
cli_replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk034-cli-replay.XXXXXX")"
cleanup() {
  for temporary_root in \
    "${cli_replay_root}" \
    "${mutation_root}" \
    "${browser_root}" \
    "${extract_root}" \
    "${evidence_replay_root}" \
    "${evidence_root}" \
    "${tooling_root}" \
    "${replay_root}" \
    "${generated_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk034-*) rm -rf -- "${temporary_root}" || true ;;
      *) echo "refusing to remove unexpected SDK-034 temporary path: ${temporary_root}" >&2 ;;
    esac
  done
  rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

generate_genes() {
  local output_root="$1"
  (
    cd "${package_root}"
    "${lix_haxe}" profiles/browser-correlation.hxml -js "${output_root}/index.ts"
  )
}
generate_genes "${generated_root}"
generate_genes "${replay_root}"
diff -ru "${generated_root}" "${replay_root}"

rm -rf -- "${package_root}/build"
mkdir -p "${package_root}/build" "${cli_replay_root}/build"
(
  cd "${package_root}"
  "${lix_haxe}" profiles/classic.hxml -js build/index.js
  "${lix_haxe}" profiles/classic.hxml -js "${cli_replay_root}/build/index.js"
)
python3 "${package_root}/scripts/add-node-shebang.py" "${package_root}/build/index.js"
python3 "${package_root}/scripts/add-node-shebang.py" "${cli_replay_root}/build/index.js"
diff -ru "${package_root}/build" "${cli_replay_root}/build"

for tooling_file in package.json package-lock.json build.mjs runtime.mjs; do
  cp -f "${package_root}/browser-tooling/${tooling_file}" "${tooling_root}/${tooling_file}"
done
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e npm_config_cache=/tmp/npm-cache \
  --mount "type=bind,src=${generated_root},dst=/generated" \
  --mount "type=bind,src=${replay_root},dst=/replay" \
  --mount "type=bind,src=${tooling_root},dst=/tooling" \
  -w /tooling "${node_image}" sh -eu -c '
    test "$(node --version)" = "v22.17.0"
    test "$(npm --version)" = "10.9.2"
    npm ci --ignore-scripts --no-audit --no-fund
    node build.mjs /generated /generated/bundles
    node build.mjs /replay /replay/bundles
  '
diff -ru "${generated_root}/bundles" "${replay_root}/bundles"

python3 "${package_root}/scripts/package-browser-source-correlation.py" \
  --generated-root "${generated_root}" \
  --bundle-root "${generated_root}/bundles" \
  --output-root "${evidence_root}" \
  --genes-root "${genes_root}" \
  --haxe-stdlib-root "${haxe_stdlib_root}" \
  --extract-root "${extract_root}"
python3 "${package_root}/scripts/package-browser-source-correlation.py" \
  --generated-root "${replay_root}" \
  --bundle-root "${replay_root}/bundles" \
  --output-root "${evidence_replay_root}" \
  --genes-root "${genes_root}" \
  --haxe-stdlib-root "${haxe_stdlib_root}"
diff -ru "${evidence_root}" "${evidence_replay_root}"

docker run --rm --network none --ipc=host \
  --mount "type=bind,src=${tooling_root},dst=/tooling,readonly" \
  --mount "type=bind,src=${extract_root},dst=/evidence,readonly" \
  --mount "type=bind,src=${browser_root},dst=/browser" \
  -w /tooling "${playwright_image}" \
  node runtime.mjs /evidence /browser

trace_cli() {
  docker run --rm --network none \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${genes_root},dst=/genes,readonly" \
    --mount "type=bind,src=${haxe_stdlib_root},dst=/haxe-stdlib,readonly" \
    --mount "type=bind,src=${extract_root},dst=/evidence,readonly" \
    --mount "type=bind,src=${browser_root},dst=/browser" \
    --mount "type=bind,src=${mutation_root},dst=/mutations" \
    -w /repo "${node_image}" \
    node /repo/packages/cli/build/index.js "$@"
}

for mode in development production two-stage; do
  trace_cli trace browser "/browser/${mode}.stack" \
    --index /evidence/source-index.json \
    --source-root project=/repo \
    --source-root genes=/genes \
    --source-root haxe-stdlib=/haxe-stdlib \
    --format json >"${browser_root}/${mode}.json"
  trace_cli trace browser "/browser/${mode}.stack" \
    --index /evidence/source-index.json \
    --source-root project=/repo \
    --source-root genes=/genes \
    --source-root haxe-stdlib=/haxe-stdlib \
    --format json >"${browser_root}/${mode}.json.replay"
  cmp "${browser_root}/${mode}.json" "${browser_root}/${mode}.json.replay"
  trace_cli trace browser "/browser/${mode}.stack" \
    --index /evidence/source-index.json \
    --source-root project=/repo \
    --source-root genes=/genes \
    --source-root haxe-stdlib=/haxe-stdlib \
    --format text >"${browser_root}/${mode}.text"
done
python3 "${package_root}/scripts/verify-browser-source-correlation.py" \
  "${evidence_root}" "${browser_root}"

if [[ -n "${SDK034_EVIDENCE_OUTPUT:-}" ]]; then
  mkdir -p -- "${SDK034_EVIDENCE_OUTPUT}"
  inspect_root="$(cd "${SDK034_EVIDENCE_OUTPUT}" && pwd -P)"
  case "${inspect_root}" in
    /|"${repository_root}"|"${package_root}")
      echo "refusing unsafe SDK034_EVIDENCE_OUTPUT: ${inspect_root}" >&2
      exit 1
      ;;
  esac
  first_inspect_entry="$(find "${inspect_root}" -mindepth 1 -maxdepth 1 -print -quit)"
  if [[ -n "${first_inspect_entry}" ]]; then
    echo "refusing non-empty SDK034_EVIDENCE_OUTPUT: ${inspect_root}" >&2
    exit 1
  fi
  cp -rf "${evidence_root}" "${inspect_root}/evidence"
  cp -rf "${browser_root}" "${inspect_root}/browser"
  echo "SDK-034 inspectable evidence written to ${inspect_root}"
fi

python3 "${package_root}/scripts/create-browser-trace-mutations.py" \
  "${extract_root}" "${mutation_root}" "${repository_root}"

expect_exit() {
  local expected="$1"
  local label="$2"
  shift 2
  set +e
  trace_cli "$@" \
    >"${browser_root}/negative-${label}.out" \
    2>"${browser_root}/negative-${label}.err"
  local result=$?
  set -e
  if (( result != expected )); then
    echo "SDK-034 negative ${label} exited ${result}, expected ${expected}" >&2
    sed -n '1,120p' "${browser_root}/negative-${label}.err" >&2
    exit 1
  fi
}

for mutation in \
  stale-runtime \
  stale-map \
  stale-generated \
  absolute-map-source \
  escaping-map-source \
  invalid-vlq \
  sources-content \
  wrong-map-file \
  unknown-map-field \
  unknown-index-field \
  absolute-index-path \
  dishonest-continuity; do
  expect_exit 3 "${mutation}" \
    trace browser /browser/production.stack \
    --index "/mutations/${mutation}/source-index.json" --format json
done
for mutation in ambiguous-correlation ambiguous-file-path; do
  expect_exit 4 "${mutation}" \
    trace browser /browser/production.stack \
    --index "/mutations/${mutation}/source-index.json" --format json
done
expect_exit 3 stale-source \
  trace browser /browser/production.stack \
  --index /evidence/source-index.json \
  --source-root project=/mutations/mutated-project --format json

for label in basename unknown missing-column; do
  trace_cli trace browser "/mutations/stacks/${label}.stack" \
    --index /evidence/source-index.json --format json \
    >"${browser_root}/unmapped-${label}.json"
done
python3 - "${browser_root}" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "basename": "unmapped-no-layer",
    "unknown": "unmapped-no-layer",
    "missing-column": "native-unmapped",
}
for label, status in expected.items():
    result = json.loads((root / f"unmapped-{label}.json").read_text())
    if [frame["status"] for frame in result["frames"]] != [status]:
        raise SystemExit(f"{label}: exact-path/column fallback policy changed")
PY

expect_exit 2 out-of-range \
  trace browser /mutations/stacks/out-of-range.stack \
  --index /evidence/source-index.json --format json
expect_exit 2 empty-stack \
  trace browser /mutations/stacks/empty.stack \
  --index /evidence/source-index.json --format json
expect_exit 2 missing-index \
  trace browser /browser/production.stack \
  --index /evidence/missing.json --format json
expect_exit 2 unknown-source-root \
  trace browser /browser/production.stack \
  --index /evidence/source-index.json \
  --source-root unknown=/repo --format json
expect_exit 2 invalid-format \
  trace browser /browser/production.stack \
  --index /evidence/source-index.json --format yaml

echo "WordPressHx SDK-034 browser source-map composition and trace gate passed"
