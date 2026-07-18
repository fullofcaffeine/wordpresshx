#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"

for command_name in docker git haxe haxelib lix node npm python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-031 browser gate requires ${command_name}" >&2
    exit 1
  fi
done

lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]]; then
  echo "SDK-031 browser gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-031 browser gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi

python3 "${package_root}/scripts/verify-dependency-lock.py"

(
  cd "${package_root}"
  lix --silent download
)

(
  cd "${repository_root}"
  haxelib run formatter --check \
    -s "${package_root}/src" \
    -s "${package_root}/test/fixture/src" \
    -s "${package_root}/test-negative"
)

temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk031-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk031-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk031-tooling.XXXXXX")"

cleanup() {
  for temporary_root in "${build_root}" "${replay_root}" "${tooling_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk031-*) rm -rf -- "${temporary_root}" ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
}
trap cleanup EXIT

copy_runtime() {
  local lane_root="$1"
  local runtime_root="${lane_root}/src-gen/sdk031/fixture/runtime"
  mkdir -p "${runtime_root}"
  cp -f "${package_root}/test/runtime/setup.js" "${runtime_root}/setup.js"
  cp -f "${package_root}/test/runtime/setup.d.ts" "${runtime_root}/setup.d.ts"
  cp -f "${package_root}/test/runtime/signals.js" "${runtime_root}/signals.js"
  cp -f "${package_root}/test/runtime/signals.d.ts" "${runtime_root}/signals.d.ts"
  cp -f "${package_root}/test/consumer/consumer.ts" "${lane_root}/consumer.ts"
}

generate_root() {
  local output_root="$1"
  mkdir -p \
    "${output_root}/strict/src-gen" \
    "${output_root}/classic/src-gen" \
    "${output_root}/default"
  (
    cd "${package_root}"
    "${lix_haxe}" \
      profiles/strict.hxml \
      -js "${output_root}/strict/src-gen/index.ts" \
      -D "wordpress_hx_browser_export_manifest=${output_root}/strict/browser-exports.json"
    "${lix_haxe}" \
      profiles/classic.hxml \
      -js "${output_root}/classic/src-gen/index.js" \
      -D "wordpress_hx_browser_export_manifest=${output_root}/classic/browser-exports.json"
    "${lix_haxe}" \
      profiles/default-dce.hxml \
      -js "${output_root}/default/index.js"
  )
  copy_runtime "${output_root}/strict"
  copy_runtime "${output_root}/classic"
}

generate_root "${build_root}"
generate_root "${replay_root}"

expect_compile_failure() {
  local label="$1"
  local expected_diagnostic="$2"
  shift 2
  local output="${tooling_root}/negative-${label}.txt"
  if (cd "${package_root}" && "${lix_haxe}" "$@") >"${output}" 2>&1; then
    echo "negative browser fixture unexpectedly compiled: ${label}" >&2
    exit 1
  fi
  if ! grep -F -- "${expected_diagnostic}" "${output}" >/dev/null; then
    echo "negative browser fixture failed for the wrong reason: ${label}" >&2
    sed -n '1,120p' "${output}" >&2
    exit 1
  fi
}

expect_compile_failure \
  "invalid-export-id" \
  "WPX3100" \
  -cp src \
  -cp test-negative/invalid_export_id \
  -main Main \
  -D wordpress_hx_profile=wp70-release \
  -js "${tooling_root}/invalid-export-id.js"
expect_compile_failure \
  "invalid-capability" \
  "WPX3102" \
  -cp src \
  -cp test-negative/invalid_capability \
  -main Main \
  -D wordpress_hx_profile=wp70-release \
  -js "${tooling_root}/invalid-capability.js"
expect_compile_failure \
  "missing-profile" \
  "WPX3101" \
  -cp src \
  -cp test/fixture/src \
  -main sdk031.fixture.BrowserApi \
  -js "${tooling_root}/missing-profile.js"
expect_compile_failure \
  "missing-export-manifest" \
  "WPX3106" \
  profiles/strict.hxml \
  -js "${tooling_root}/missing-export-manifest/index.ts"

cp -f "${package_root}/tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/tooling/package-lock.json" "${tooling_root}/package-lock.json"
cp -f \
  "${package_root}/scripts/verify-browser-profile.mjs" \
  "${tooling_root}/verify-browser-profile.mjs"

docker run --rm \
  --user "$(id -u):$(id -g)" \
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
    node ./verify-browser-profile.mjs /repo/packages/gutenberg /work /replay
  '

echo "SDK-031 strict Genes browser profile passed"
