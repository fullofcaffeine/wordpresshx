#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
profile_path="${package_root}/src/wordpress/hx/gutenberg/profile/wp70-release.block-metadata.json"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
skip_wordpress=false

if [[ "${1:-}" == "--skip-wordpress" ]]; then
  skip_wordpress=true
  shift
fi
if (( $# != 0 )); then
  echo "usage: $0 [--skip-wordpress]" >&2
  exit 2
fi

for command_name in git haxe haxelib lix node npm python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-061 static block gate requires ${command_name}" >&2
    exit 1
  fi
done

docker_ready=false
if command -v docker >/dev/null 2>&1 && python3 - <<'PY'
import subprocess
import sys

try:
    result = subprocess.run(
        ["docker", "info"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=10,
        check=False,
    )
except (OSError, subprocess.TimeoutExpired):
    raise SystemExit(1)
raise SystemExit(result.returncode)
PY
then
  docker_ready=true
fi

local_node_bin=""
if [[ "${docker_ready}" != "true" ]]; then
  if [[ "${skip_wordpress}" != "true" ]]; then
    echo "SDK-061 real WordPress proof requires a responsive Docker daemon" >&2
    exit 1
  fi
  node_home="$(node -p 'require("node:os").homedir()')"
  local_node_bin="$(dirname "$(command -v node)")"
  if [[ "$(PATH="${local_node_bin}:${PATH}" node --version)" != "v22.17.0" ]] \
    || [[ "$(PATH="${local_node_bin}:${PATH}" npm --version)" != "10.9.2" ]]; then
    local_node_bin="${NVM_DIR:-${node_home}/.nvm}/versions/node/v22.17.0/bin"
  fi
  if [[ ! -x "${local_node_bin}/node" ]] \
    || [[ "$(PATH="${local_node_bin}:${PATH}" node --version)" != "v22.17.0" ]] \
    || [[ "$(PATH="${local_node_bin}:${PATH}" npm --version)" != "10.9.2" ]]; then
    echo "SDK-061 local fallback requires Node 22.17.0 and npm 10.9.2" >&2
    exit 1
  fi
  if [[ ! -f "${package_root}/editor-tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js" ]] \
    || ! PATH="${local_node_bin}:${PATH}" npm \
      --prefix "${package_root}/editor-tooling" \
      ls --depth=0 --omit=optional >/dev/null; then
    echo "SDK-061 local fallback requires npm ci --ignore-scripts in packages/gutenberg/editor-tooling" >&2
    exit 1
  fi
fi

lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
  echo "SDK-061 requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-061 requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi
lix_haxe_root="$(node -e '
  const os = require("node:os");
  const path = require("node:path");
  process.stdout.write(
    process.env.HAXE_ROOT ||
    process.env.HAXESHIM_ROOT ||
    path.join(os.homedir(), "haxe")
  );
')"
haxe_stdlib_root="${lix_haxe_root}/versions/4.3.7/std"

python3 "${package_root}/scripts/verify-dependency-lock.py" --metadata-only
python3 "${package_root}/scripts/verify-static-block-profile.py"
(
  cd "${package_root}"
  lix --silent download
)
if [[ ! -f "${haxe_stdlib_root}/StdTypes.hx" ]]; then
  echo "SDK-061 could not resolve the exact Haxe standard library" >&2
  exit 1
fi

haxelib run formatter --check \
  -s "${package_root}/src/wordpress/hx/gutenberg/block" \
  -s "${package_root}/test/static-block-fixture/src" \
  -s "${package_root}/test-negative-static-block"

weak_type_guard="${repository_root}/scripts/lint/haxe-weak-type-guard.py"
python3 "${weak_type_guard}" --self-test
python3 "${weak_type_guard}" \
  "${repository_root}/packages/hxx/src" \
  "${package_root}/src" \
  "${package_root}/test/static-block-fixture/src" \
  "${package_root}/test-negative-static-block"

temporary_parent="${package_root}/.sdk061-tmp"
mkdir -p "${temporary_parent}"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk061-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk061-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk061-tooling.XXXXXX")"
evidence_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk061-evidence.XXXXXX")"
negative_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk061-negative.XXXXXX")"

cleanup() {
  for temporary_root in "${negative_root}" "${evidence_root}" "${tooling_root}" "${replay_root}" "${build_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk061-*) rm -rf -- "${temporary_root}" || true ;;
      *) echo "refusing unexpected SDK-061 temporary path: ${temporary_root}" >&2 ;;
    esac
  done
  rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

generate_browser() {
  local output_root="$1"
  (
    cd "${package_root}"
    "${lix_haxe}" profiles/static-block-strict.hxml \
      -D "wordpress_hx_static_block_plan=${output_root}/static-block-plan.json" \
      -js "${output_root}/editor.tsx"
  )
  cp -f "${package_root}/editor-tooling/package.json" "${output_root}/package.json"
  cp -f "${package_root}/test/static-block-runtime/setup.d.ts" "${output_root}/setup.d.ts"
}

generate_browser "${build_root}"
generate_browser "${replay_root}"

expect_compile_failure() {
  local fixture="$1"
  local diagnostic="$2"
  local output="${negative_root}/${fixture}.txt"
  local plan="${negative_root}/${fixture}.json"
  if (
    cd "${package_root}"
    "${lix_haxe}" \
      profiles/hxx-common.hxml \
      -cp ../build/src \
      -D wordpress_hx_browser_hxx_catalog=static-block \
      -cp "test-negative-static-block/${fixture}" \
      -cp test/static-block-fixture/src \
      -main Main \
      -D "wordpress_hx_static_block_plan=${plan}" \
      -js "${negative_root}/${fixture}.tsx"
  ) >"${output}" 2>&1; then
    echo "negative static block fixture unexpectedly compiled: ${fixture}" >&2
    exit 1
  fi
  if ! grep -F -- "${diagnostic}" "${output}" >/dev/null \
    || ! grep -F -- "test-negative-static-block/${fixture}/Main.hx" "${output}" >/dev/null; then
    echo "negative static block fixture failed for the wrong reason: ${fixture}" >&2
    sed -n '1,140p' "${output}" >&2
    exit 1
  fi
}

expect_compile_failure wrong_edit WPX6112
expect_compile_failure wrong_update_type WPX6103
expect_compile_failure save_update WPX6101
expect_compile_failure wrong_migrate WPX6116
expect_compile_failure missing_default WPX6105
expect_compile_failure spoof_deprecation WPX6114

cp -f "${package_root}/editor-tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/editor-tooling/package-lock.json" "${tooling_root}/package-lock.json"
cp -f "${package_root}/scripts/run-static-block-playwright.mjs" "${tooling_root}/run-static-block-playwright.mjs"

if [[ "${docker_ready}" == "true" ]]; then
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --tmpfs /tmp:rw,exec,nosuid,nodev \
    -e npm_config_cache=/tmp/npm-cache \
    -v "${repository_root}:/repo:ro" \
    -v "${build_root}:/work" \
    -v "${replay_root}:/replay" \
    -v "${tooling_root}:/tooling" \
    -w /tooling \
    "${node_image}" \
    sh -eu -c '
      test "$(node --version)" = "v22.17.0"
      test "$(npm --version)" = "10.9.2"
      npm ci --ignore-scripts --no-audit --no-fund
      for root in /work /replay; do
        ln -s /tooling/node_modules "${root}/node_modules"
        (
          cd "${root}"
          node /tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js \
            start editor.tsx --no-watch \
            --config /repo/packages/gutenberg/build-tooling/webpack.config.cjs \
            --output-path build/development
          node /tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js \
            build editor.tsx \
            --config /repo/packages/gutenberg/build-tooling/webpack.config.cjs \
            --output-path build/production
        )
      done
    '
else
  for output_root in "${build_root}" "${replay_root}"; do
    ln -s "${package_root}/editor-tooling/node_modules" "${output_root}/node_modules"
    (
      export PATH="${local_node_bin}:${PATH}"
      cd "${output_root}"
      node node_modules/@wordpress/scripts/bin/wp-scripts.js \
        start editor.tsx --no-watch \
        --config "${package_root}/build-tooling/webpack.config.cjs" \
        --output-path build/development
      node node_modules/@wordpress/scripts/bin/wp-scripts.js \
        build editor.tsx \
        --config "${package_root}/build-tooling/webpack.config.cjs" \
        --output-path build/production
    )
  done
fi

stage_plugin() {
  local output_root="$1"
  local plugin_root="${output_root}/wordpress-plugin"
  mkdir -p "${plugin_root}"
  python3 "${package_root}/scripts/emit-static-block-assets.py" \
    --bundle-root "${output_root}/build/production" \
    --css "${package_root}/test/static-block-fixture/callout.css" \
    --output-root "${plugin_root}" \
    --manifest "${output_root}/assets.manifest.json"
  (
    cd "${repository_root}"
    "${lix_haxe}" \
      -cp packages/build/src \
      -cp packages/gutenberg/src \
      -cp packages/gutenberg/test/static-block-fixture/src \
      -main sdk061.fixture.MetadataMain \
      --macro 'wordpress.hx.gutenberg.block.Block.install()' \
      -D "wordpress_hx_block_profile=${profile_path}" \
      -D "wordpress_hx_block_assets=${output_root}/assets.manifest.json" \
      -D "wordpress_hx_block_output=${plugin_root}" \
      --interp
  )
}

stage_plugin "${build_root}"
stage_plugin "${replay_root}"

if [[ "${docker_ready}" == "true" ]]; then
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --tmpfs /tmp:rw,exec,nosuid,nodev \
    -v "${repository_root}:/repo:ro" \
    -v "${build_root}:/work" \
    -v "${replay_root}:/replay" \
    -v "${tooling_root}:/tooling" \
    -v "${evidence_root}:/evidence" \
    -w /tooling \
    "${node_image}" \
    sh -eu -c '
      test "$(node --version)" = "v22.17.0"
      for root in /work /replay; do
        node /repo/packages/gutenberg/scripts/verify-static-block-runtime.mjs \
          "${root}" \
          "${root}/wordpress-plugin/blocks/callout/block.json" \
          "${root}/static-block-plan.json" \
          "${root}/serialization-evidence.json"
      done
      node /repo/packages/gutenberg/scripts/verify-static-block.mjs \
        /repo/packages/gutenberg \
        /work /replay \
        /work/wordpress-plugin /replay/wordpress-plugin \
        /evidence/static-block-evidence.json
    '
else
  (
    export PATH="${local_node_bin}:${PATH}"
    cd "${package_root}/editor-tooling"
    for output_root in "${build_root}" "${replay_root}"; do
      node "${package_root}/scripts/verify-static-block-runtime.mjs" \
        "${output_root}" \
        "${output_root}/wordpress-plugin/blocks/callout/block.json" \
        "${output_root}/static-block-plan.json" \
        "${output_root}/serialization-evidence.json"
    done
    node "${package_root}/scripts/verify-static-block.mjs" \
      "${package_root}" \
      "${build_root}" "${replay_root}" \
      "${build_root}/wordpress-plugin" "${replay_root}/wordpress-plugin" \
      "${evidence_root}/static-block-evidence.json"
  )
fi

if [[ "${skip_wordpress}" != "true" ]]; then
  "${package_root}/scripts/run-wordpress-static-block-lane.sh" \
    "${build_root}/wordpress-plugin" \
    "${tooling_root}" \
    "${evidence_root}"
fi

if [[ -n "${SDK061_EVIDENCE_OUTPUT:-}" ]]; then
  if [[ -e "${SDK061_EVIDENCE_OUTPUT}" ]]; then
    echo "SDK061_EVIDENCE_OUTPUT must not already exist" >&2
    exit 2
  fi
  mkdir -p "${SDK061_EVIDENCE_OUTPUT}"
  cp -f "${evidence_root}/static-block-evidence.json" "${SDK061_EVIDENCE_OUTPUT}/static-block-evidence.json"
  if [[ -f "${evidence_root}/wordpress-static-block.json" ]]; then
    cp -f "${evidence_root}/wordpress-static-block.json" "${SDK061_EVIDENCE_OUTPUT}/wordpress-static-block.json"
  fi
fi

echo "SDK-061 typed static block gate passed"
