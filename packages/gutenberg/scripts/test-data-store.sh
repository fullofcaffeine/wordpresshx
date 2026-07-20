#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
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

for command_name in docker git haxe haxelib lix node npm python3 rg; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-064 data-store gate requires ${command_name}" >&2
    exit 1
  fi
done
docker info >/dev/null

lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]]; then
  echo "SDK-064 gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-064 gate requires Lix-scoped Haxe 4.3.7" >&2
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

python3 "${package_root}/scripts/verify-dependency-lock.py" --metadata-only
python3 "${package_root}/scripts/verify-editor-profile.py" --metadata-only
python3 "${package_root}/scripts/verify-data-store-profile.py"
(
  cd "${package_root}"
  lix --silent download
)
if [[ ! -f "${haxe_stdlib_root}/StdTypes.hx" ]] \
  || [[ ! -f "${genes_root}/genes/Register.hx" ]]; then
  echo "SDK-064 gate could not resolve the exact Lix source roots" >&2
  exit 1
fi

(
  cd "${repository_root}"
  haxelib run formatter --check \
    -s "${package_root}/src/wordpress/hx/gutenberg/data" \
    -s "${package_root}/test/data-store-fixture/src" \
    -s "${package_root}/test/data-store-unit/src" \
    -s "${package_root}/test-negative-data-store"
)

if rg -n --glob '*.hx' \
  '\b(Dynamic|Any|cast|Reflect|untyped)\b' \
  "${package_root}/src/wordpress/hx/gutenberg/data" \
  "${package_root}/test/data-store-fixture/src" \
  "${package_root}/test/data-store-unit/src" \
  "${package_root}/test-negative-data-store"; then
  echo "SDK-064 Haxe source contains a forbidden weak-type construct" >&2
  exit 1
fi

temporary_parent="${package_root}/.sdk064-tmp"
mkdir -p "${temporary_parent}"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk064-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk064-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk064-tooling.XXXXXX")"
evidence_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk064-evidence.XXXXXX")"

cleanup() {
  for temporary_root in "${evidence_root}" "${tooling_root}" "${replay_root}" "${build_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk064-*) rm -rf -- "${temporary_root}" || true ;;
      *) echo "refusing to remove unexpected SDK-064 path: ${temporary_root}" >&2 ;;
    esac
  done
  rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

generate_root() {
  local output_root="$1"
  (
    cd "${package_root}"
    "${lix_haxe}" profiles/data-store-strict.hxml -js "${output_root}/editor.tsx"
    "${lix_haxe}" profiles/data-store-unit.hxml -js "${output_root}/unit.js"
  )
  cp -f "${package_root}/editor-tooling/package.json" "${output_root}/package.json"
}

generate_root "${build_root}"
generate_root "${replay_root}"
cmp "${build_root}/unit.js" "${replay_root}/unit.js"
node "${build_root}/unit.js"
node "${replay_root}/unit.js"

expect_compile_failure() {
  local label="$1"
  local expected_diagnostic="$2"
  local output="${tooling_root}/negative-${label}.txt"
  if (
    cd "${package_root}"
    "${lix_haxe}" \
      profiles/hxx-common.hxml \
      -D wordpress_hx_browser_hxx_catalog=data-store \
      -cp "test-negative-data-store/${label}" \
      -main Main \
      -js "${tooling_root}/negative-${label}/editor.tsx"
  ) >"${output}" 2>&1; then
    echo "negative data-store fixture unexpectedly compiled: ${label}" >&2
    exit 1
  fi
  if ! grep -F -- "${expected_diagnostic}" "${output}" >/dev/null \
    || ! grep -F -- "test-negative-data-store/${label}/Main.hx" "${output}" >/dev/null; then
    echo "negative data-store fixture failed for the wrong reason: ${label}" >&2
    sed -n '1,140p' "${output}" >&2
    exit 1
  fi
}

expect_compile_failure invalid_store_key "WPX6401"
expect_compile_failure missing_action_type "WPX6405"
expect_compile_failure reducer_state_mismatch "WPX6403"
expect_compile_failure wrong_action "String should be _Main.CounterAction"

cp -f "${package_root}/editor-tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/editor-tooling/package-lock.json" "${tooling_root}/package-lock.json"
cp -f "${package_root}/build-tooling/webpack.config.cjs" "${tooling_root}/webpack.config.cjs"
cp -f "${package_root}/scripts/verify-data-store.mjs" "${tooling_root}/verify-data-store.mjs"
cp -f "${package_root}/scripts/run-data-store-playwright.mjs" "${tooling_root}/run-data-store-playwright.mjs"

container_build_root="/repo/packages/gutenberg/.sdk064-tmp/$(basename "${build_root}")"
container_replay_root="/repo/packages/gutenberg/.sdk064-tmp/$(basename "${replay_root}")"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --tmpfs /tmp:rw,exec,nosuid,nodev \
  -e npm_config_cache=/tmp/npm-cache \
  --mount "type=bind,src=${lix_haxe_root},dst=/haxe,readonly" \
  --mount "type=bind,src=${haxe_library_cache},dst=${haxe_library_cache},readonly" \
  --mount "type=bind,src=${haxe_stdlib_root},dst=${haxe_stdlib_root},readonly" \
  -v "${repository_root}:/repo:ro" \
  -v "${build_root}:${container_build_root}" \
  -v "${replay_root}:${container_replay_root}" \
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
          start editor.tsx --no-watch \
          --config /tooling/webpack.config.cjs \
          --output-path build/development
        node /tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js \
          build editor.tsx \
          --config /tooling/webpack.config.cjs \
          --output-path build/production
      )
    done
    node /tooling/verify-data-store.mjs \
      /repo/packages/gutenberg "$1" "$2" /tooling
  ' _ "${container_build_root}" "${container_replay_root}"

for generated_root in "${build_root}" "${replay_root}"; do
  python3 "${package_root}/scripts/emit-data-store-plugin.py" \
    --plan "${generated_root}/asset-plan.json" \
    --bundle-root "${generated_root}/build/production" \
    --output-root "${generated_root}/wordpress-plugin"
done
diff -ru "${build_root}/wordpress-plugin" "${replay_root}/wordpress-plugin"

for image in "${php74_image}" "${php84_image}"; do
  docker run --rm --network none \
    --mount "type=bind,src=${build_root}/wordpress-plugin,dst=/plugin,readonly" \
    "${image}" php -l /plugin/wordpresshx-sdk064-data-store.php
done

visual_output=""
if [[ -n "${SDK064_VISUAL_OUTPUT:-}" ]]; then
  mkdir -p -- "${SDK064_VISUAL_OUTPUT}"
  visual_output="$(cd "${SDK064_VISUAL_OUTPUT}" && pwd -P)"
  case "${visual_output}" in
    /|"${repository_root}"|"${package_root}")
      echo "refusing unsafe SDK064_VISUAL_OUTPUT: ${visual_output}" >&2
      exit 1
      ;;
  esac
  rm -rf -- "${visual_output}/wordpress-plugin"
  cp -rf "${build_root}/wordpress-plugin" "${visual_output}/wordpress-plugin"
  cp -f "${build_root}/asset-plan.json" "${visual_output}/asset-plan.json"
fi

if [[ "${skip_wordpress}" != "true" ]]; then
  bash "${package_root}/scripts/run-wordpress-data-store-lane.sh" \
    "${build_root}/wordpress-plugin" \
    "${build_root}/asset-plan.json" \
    "${tooling_root}" \
    "${evidence_root}"
fi

if [[ -n "${visual_output}" ]]; then
  if [[ -s "${evidence_root}/todo-data-store.png" ]]; then
    cp -f "${evidence_root}/todo-data-store.png" "${visual_output}/todo-data-store.png"
    cp -f "${evidence_root}/todo-data-store.png.json" "${visual_output}/todo-data-store.png.json"
  fi
  echo "SDK-064 data-store evidence written to ${visual_output}"
fi

echo "SDK-064 typed WordPress data-store gate passed"
