#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
playwright_image="mcr.microsoft.com/playwright@sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d"
php74_image="docker.io/library/php@sha256:620a6b9f4d4feef2210026172570465e9d0c1de79766418d3affd09190a7fda5"
php84_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"
skip_wordpress=false

if [[ "${1:-}" == "--skip-wordpress" ]]; then
  skip_wordpress=true
  shift
fi
if (( $# != 0 )); then
  echo "usage: $0 [--skip-wordpress]" >&2
  exit 2
fi

for command_name in docker git haxe haxelib lix node npm python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-033 asset gate requires ${command_name}" >&2
    exit 1
  fi
done
docker info >/dev/null

lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
  echo "SDK-033 asset gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-033 asset gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi
lix_haxe_root="$(
  node -e '
    const os = require("node:os");
    const path = require("node:path");
    process.stdout.write(
      process.env.HAXE_ROOT ||
      process.env.HAXESHIM_ROOT ||
      path.join(os.homedir(), "haxe")
    );
  '
)"
haxe_library_cache="$(
  node -e '
    const os = require("node:os");
    const path = require("node:path");
    const haxeRoot =
      process.env.HAXE_ROOT ||
      process.env.HAXESHIM_ROOT ||
      path.join(os.homedir(), "haxe");
    process.stdout.write(
      process.env.HAXESHIM_LIBCACHE ||
      process.env.HAXE_LIBCACHE ||
      path.join(haxeRoot, "haxe_libraries")
    );
  '
)"
genes_root="${haxe_library_cache}/genes-ts/1.36.3/github/c59ecb361fd91418584487c2138bae8d3d3a3961/src"
haxe_stdlib_root="${lix_haxe_root}/versions/4.3.7/std"
if [[ ! -f "${haxe_stdlib_root}/StdTypes.hx" ]] \
  || [[ ! -f "${genes_root}/genes/Register.hx" ]]; then
  echo "SDK-033 asset gate could not resolve the exact Lix Haxe source root" >&2
  echo "expected Haxe root: ${lix_haxe_root}" >&2
  echo "expected Genes root: ${genes_root}" >&2
  exit 1
fi

python3 "${package_root}/scripts/verify-dependency-lock.py" --metadata-only
python3 "${package_root}/scripts/verify-assets-profile.py"
(
  cd "${package_root}"
  lix --silent download
)
(
  cd "${repository_root}"
  haxelib run formatter --check \
    -s "${package_root}/src" \
    -s "${package_root}/test/assets-fixture/src"
)

temporary_parent="${package_root}/.sdk033-tmp"
mkdir -p "${temporary_parent}"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-tooling.XXXXXX")"
correlation_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-correlation.XXXXXX")"
correlation_replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-correlation-replay.XXXXXX")"
correlation_extract_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-correlation-extract.XXXXXX")"
correlation_browser_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-correlation-browser.XXXXXX")"
correlation_mutation_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-correlation-mutations.XXXXXX")"
cli_build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-cli.XXXXXX")"
cli_replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk033-cli-replay.XXXXXX")"

cleanup() {
  for temporary_root in \
    "${cli_replay_root}" \
    "${cli_build_root}" \
    "${correlation_mutation_root}" \
    "${correlation_browser_root}" \
    "${correlation_extract_root}" \
    "${correlation_replay_root}" \
    "${correlation_root}" \
    "${tooling_root}" \
    "${replay_root}" \
    "${build_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk033-*) rm -rf -- "${temporary_root}" || true ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
  rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

generate_root() {
  local output_root="$1"
  mkdir -p "${output_root}/src"
  (
    cd "${package_root}"
    "${lix_haxe}" \
      profiles/assets-strict.hxml \
      -D "wordpress_hx_browser_export_manifest=${output_root}/browser-exports.json" \
      -js "${output_root}/src/haxe.tsx"
  )
  cp -f \
    "${package_root}/test/assets-runtime/editor-entry.tsx" \
    "${output_root}/src/editor.tsx"
  cp -f "${package_root}/build-tooling/package.json" "${output_root}/package.json"
}

generate_root "${build_root}"
generate_root "${replay_root}"

cp -f "${package_root}/build-tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/build-tooling/package-lock.json" "${tooling_root}/package-lock.json"
cp -f "${package_root}/build-tooling/webpack.config.cjs" "${tooling_root}/webpack.config.cjs"
cp -f "${package_root}/scripts/verify-assets.mjs" "${tooling_root}/verify-assets.mjs"
cp -f \
  "${package_root}/scripts/run-source-correlation-browser.mjs" \
  "${tooling_root}/run-source-correlation-browser.mjs"

container_build_root="/repo/packages/gutenberg/.sdk033-tmp/$(basename "${build_root}")"
container_replay_root="/repo/packages/gutenberg/.sdk033-tmp/$(basename "${replay_root}")"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --tmpfs /tmp:rw,exec,nosuid,nodev \
  -e npm_config_cache=/tmp/npm-cache \
  --mount "type=bind,src=${lix_haxe_root},dst=/haxe,readonly" \
  -v "${repository_root}:/repo" \
  -v "${tooling_root}:/tooling" \
  -w /tooling \
  "${node_image}" \
  sh -eu -c '
    test "$(node --version)" = "v22.17.0"
    test "$(npm --version)" = "10.9.2"
    npm ci --ignore-scripts --no-audit --no-fund
    for root in "$1" "$2"; do
      ln -s /tooling/node_modules "${root}/node_modules"
      (
        cd "${root}"
        node /tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js \
          start src/editor.tsx --no-watch \
          --config /tooling/webpack.config.cjs \
          --output-path build/development
        node /tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js \
          build src/editor.tsx \
          --config /tooling/webpack.config.cjs \
          --output-path build/production
      )
    done
    node /tooling/verify-assets.mjs /repo/packages/gutenberg "$1" "$2" /tooling
  ' _ "${container_build_root}" "${container_replay_root}"

for generated_root in "${build_root}" "${replay_root}"; do
  python3 "${package_root}/scripts/emit-assets-plugin.py" \
    --plan "${generated_root}/asset-plan.json" \
    --bundle-root "${generated_root}/build/production" \
    --output-root "${generated_root}/wordpress-plugin"
done
diff -ru "${build_root}/wordpress-plugin" "${replay_root}/wordpress-plugin"

package_correlation() {
  local generated_root="$1"
  local output_root="$2"
  shift 2
  python3 "${package_root}/scripts/package-source-correlation.py" \
    --generated-root "${generated_root}" \
    --development-root "${generated_root}/build/development" \
    --production-root "${generated_root}/build/production" \
    --plugin-root "${generated_root}/wordpress-plugin" \
    --plan "${generated_root}/asset-plan.json" \
    --output-root "${output_root}" \
    --genes-root "${genes_root}" \
    --haxe-stdlib-root "${haxe_stdlib_root}" \
    "$@"
}

package_correlation \
  "${build_root}" "${correlation_root}" \
  --extract-root "${correlation_extract_root}"
package_correlation "${replay_root}" "${correlation_replay_root}"
diff -ru "${correlation_root}" "${correlation_replay_root}"

(
  cd "${repository_root}/packages/cli"
  lix --silent download
  "${lix_haxe}" profiles/classic.hxml -js "${cli_build_root}/index.js"
  "${lix_haxe}" profiles/classic.hxml -js "${cli_replay_root}/index.js"
)
diff -ru "${cli_build_root}" "${cli_replay_root}"

docker run --rm --network none --ipc=host \
  --mount "type=bind,src=${tooling_root},dst=/tooling,readonly" \
  --mount "type=bind,src=${correlation_extract_root},dst=/evidence,readonly" \
  --mount "type=bind,src=${correlation_browser_root},dst=/browser" \
  -w /tooling "${playwright_image}" \
  node run-source-correlation-browser.mjs /evidence /browser

trace_cli() {
  docker run --rm --network none \
    --mount "type=bind,src=${cli_build_root},dst=/cli,readonly" \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${genes_root},dst=/genes,readonly" \
    --mount "type=bind,src=${haxe_stdlib_root},dst=/haxe-stdlib,readonly" \
    --mount "type=bind,src=${correlation_extract_root},dst=/evidence,readonly" \
    --mount "type=bind,src=${correlation_browser_root},dst=/browser" \
    --mount "type=bind,src=${correlation_mutation_root},dst=/mutations" \
    -w /repo "${node_image}" \
    node /cli/index.js "$@"
}

for mode in development production; do
  trace_cli trace browser "/browser/${mode}.stack" \
    --index /evidence/source-index.json \
    --source-root project=/repo \
    --source-root genes=/genes \
    --source-root haxe-stdlib=/haxe-stdlib \
    --format json >"${correlation_browser_root}/${mode}.json"
  trace_cli trace browser "/browser/${mode}.stack" \
    --index /evidence/source-index.json \
    --source-root project=/repo \
    --source-root genes=/genes \
    --source-root haxe-stdlib=/haxe-stdlib \
    --format json >"${correlation_browser_root}/${mode}.json.replay"
  cmp \
    "${correlation_browser_root}/${mode}.json" \
    "${correlation_browser_root}/${mode}.json.replay"
  trace_cli trace browser "/browser/${mode}.stack" \
    --index /evidence/source-index.json \
    --source-root project=/repo \
    --source-root genes=/genes \
    --source-root haxe-stdlib=/haxe-stdlib \
    --format text >"${correlation_browser_root}/${mode}.text"
done

python3 "${package_root}/scripts/verify-source-correlation.py" \
  "${correlation_root}" \
  "${correlation_extract_root}" \
  "${correlation_browser_root}" \
  "${build_root}/asset-plan.json"

python3 "${package_root}/scripts/create-source-correlation-mutations.py" \
  "${correlation_extract_root}" \
  "${build_root}/wordpress-plugin" \
  "${correlation_mutation_root}" \
  "${repository_root}"

expect_trace_exit() {
  local expected="$1"
  local label="$2"
  shift 2
  set +e
  trace_cli "$@" \
    >"${correlation_browser_root}/negative-${label}.out" \
    2>"${correlation_browser_root}/negative-${label}.err"
  local result=$?
  set -e
  if (( result != expected )); then
    echo "G2.4 trace negative ${label} exited ${result}, expected ${expected}" >&2
    sed -n '1,120p' "${correlation_browser_root}/negative-${label}.err" >&2
    exit 1
  fi
}

for mutation in \
  stale-runtime \
  stale-map \
  absolute-map-source \
  sources-content \
  wrong-map-file \
  unknown-map-field \
  unknown-index-field \
  absolute-index-path; do
  expect_trace_exit 3 "${mutation}" \
    trace browser /browser/production.stack \
    --index "/mutations/${mutation}/source-index.json" --format json
done
expect_trace_exit 4 ambiguous-correlation \
  trace browser /browser/development.stack \
  --index /mutations/ambiguous-correlation/source-index.json --format json
expect_trace_exit 3 stale-source \
  trace browser /browser/production.stack \
  --index /evidence/source-index.json \
  --source-root project=/mutations/mutated-project \
  --source-root genes=/genes \
  --source-root haxe-stdlib=/haxe-stdlib \
  --format json

for label in basename unknown missing-column; do
  trace_cli trace browser "/mutations/stacks/${label}.stack" \
    --index /evidence/source-index.json --format json \
    >"${correlation_browser_root}/unmapped-${label}.json"
done
python3 - "${correlation_browser_root}" <<'PY'
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
        raise SystemExit(f"{label}: G2.4 exact-path/column policy changed")
PY
expect_trace_exit 2 out-of-range \
  trace browser /mutations/stacks/out-of-range.stack \
  --index /evidence/source-index.json --format json
expect_trace_exit 2 empty-stack \
  trace browser /mutations/stacks/empty.stack \
  --index /evidence/source-index.json --format json

expect_package_rejection() {
  local label="$1"
  local plugin_root="$2"
  local expected_message="$3"
  local rejected_root="${correlation_mutation_root}/rejected-${label}"
  set +e
  python3 "${package_root}/scripts/package-source-correlation.py" \
    --generated-root "${build_root}" \
    --development-root "${build_root}/build/development" \
    --production-root "${build_root}/build/production" \
    --plugin-root "${plugin_root}" \
    --plan "${build_root}/asset-plan.json" \
    --output-root "${rejected_root}" \
    --genes-root "${genes_root}" \
    --haxe-stdlib-root "${haxe_stdlib_root}" \
    >"${correlation_mutation_root}/${label}.out" \
    2>"${correlation_mutation_root}/${label}.err"
  local result=$?
  set -e
  if (( result == 0 )); then
    echo "G2.4 packager accepted ${label}" >&2
    exit 1
  fi
  if ! grep -Fq "${expected_message}" "${correlation_mutation_root}/${label}.err"; then
    echo "G2.4 packager rejected ${label} for the wrong reason" >&2
    sed -n '1,120p' "${correlation_mutation_root}/${label}.err" >&2
    exit 1
  fi
  if [[ -e "${rejected_root}/packages" ]]; then
    echo "G2.4 packager published a partial ${label} package" >&2
    exit 1
  fi
}

expect_package_rejection \
  secret-shaped-content \
  "${correlation_mutation_root}/secret-plugin" \
  "secret-shaped content leaked"
expect_package_rejection \
  machine-path-content \
  "${correlation_mutation_root}/path-plugin" \
  "machine path leaked"

invalid_plan_root="${build_root}/invalid-plans"
mkdir -p "${invalid_plan_root}"
python3 - "${build_root}/asset-plan.json" "${invalid_plan_root}" <<'PY'
import copy
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
output_root = Path(sys.argv[2])
plan = json.loads(source_path.read_text(encoding="utf-8"))

header_injection = copy.deepcopy(plan)
header_injection["plugin"]["name"] = "Invalid */ require 'payload.php'; /*"

cross_field_drift = copy.deepcopy(plan)
cross_field_drift["lanes"]["production"]["version"] = "0" * 20

for name, value in (
    ("header-injection", header_injection),
    ("cross-field-drift", cross_field_drift),
):
    (output_root / f"{name}.json").write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
PY
for invalid_plan in "${invalid_plan_root}"/*.json; do
  invalid_name="$(basename "${invalid_plan}" .json)"
  rejected_output="${build_root}/rejected-${invalid_name}"
  if python3 "${package_root}/scripts/emit-assets-plugin.py" \
    --plan "${invalid_plan}" \
    --bundle-root "${build_root}/build/production" \
    --output-root "${rejected_output}" \
    >"${invalid_plan_root}/${invalid_name}.log" 2>&1; then
    echo "asset emitter accepted invalid plan: ${invalid_name}" >&2
    exit 1
  fi
  if [[ -e "${rejected_output}" ]]; then
    echo "asset emitter published partial output for invalid plan: ${invalid_name}" >&2
    exit 1
  fi
done

plugin_slug="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["plugin"]["slug"])' "${build_root}/asset-plan.json")"
for image in "${php74_image}" "${php84_image}"; do
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "${build_root}/wordpress-plugin:/plugin:ro" \
    "${image}" \
    sh -eu -c '
      php -l "/plugin/$1.php"
      php -l /plugin/build/editor.asset.php
    ' _ "${plugin_slug}"
done

if [[ "${skip_wordpress}" == "false" ]]; then
  WORDPRESSHX_COMPOSE_PROJECT_NAME=wordpresshx-sdk033 \
    bash "${package_root}/scripts/run-wordpress-assets-lane.sh" \
      "${build_root}/wordpress-plugin" \
      "${build_root}/asset-plan.json"
fi

if [[ -n "${SDK033_ASSET_OUTPUT:-}" ]]; then
  mkdir -p -- "${SDK033_ASSET_OUTPUT}"
  output_root="$(cd "${SDK033_ASSET_OUTPUT}" && pwd -P)"
  case "${output_root}" in
    /|"${repository_root}"|"${package_root}")
      echo "refusing unsafe SDK033_ASSET_OUTPUT: ${output_root}" >&2
      exit 1
      ;;
  esac
  first_output_entry="$(
    find "${output_root}" -mindepth 1 -maxdepth 1 -print -quit
  )"
  if [[ -n "${first_output_entry}" ]]; then
    echo "refusing non-empty SDK033_ASSET_OUTPUT: ${output_root}" >&2
    exit 1
  fi
  cp -f "${build_root}/asset-plan.json" "${output_root}/asset-plan.json"
  cp -rf "${build_root}/wordpress-plugin" "${output_root}/wordpress-plugin"
  echo "SDK-033 inspectable assets written to ${output_root}"
fi

if [[ -n "${G24_SOURCE_CORRELATION_OUTPUT:-}" ]]; then
  mkdir -p -- "${G24_SOURCE_CORRELATION_OUTPUT}"
  output_root="$(cd "${G24_SOURCE_CORRELATION_OUTPUT}" && pwd -P)"
  case "${output_root}" in
    /|"${repository_root}"|"${package_root}")
      echo "refusing unsafe G24_SOURCE_CORRELATION_OUTPUT: ${output_root}" >&2
      exit 1
      ;;
  esac
  first_output_entry="$(
    find "${output_root}" -mindepth 1 -maxdepth 1 -print -quit
  )"
  if [[ -n "${first_output_entry}" ]]; then
    echo "refusing non-empty G24_SOURCE_CORRELATION_OUTPUT: ${output_root}" >&2
    exit 1
  fi
  cp -rf "${correlation_root}" "${output_root}/packages-and-index"
  cp -rf "${correlation_browser_root}" "${output_root}/browser"
  echo "G2.4 inspectable source-correlation evidence written to ${output_root}"
fi

echo "G2.4 official WordPress production source-correlation gate passed"
echo "SDK-033 official WordPress asset metadata and translation gate passed"
