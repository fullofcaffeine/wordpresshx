#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"

for command_name in docker git haxe haxelib lix node npm python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-035 differential gate requires ${command_name}" >&2
    exit 1
  fi
done

lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
  echo "SDK-035 differential gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-035 differential gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi

python3 "${package_root}/scripts/verify-dependency-lock.py" --metadata-only
python3 "${package_root}/scripts/verify-hxx-profile.py" --metadata-only
python3 "${package_root}/scripts/verify-differential-profile.py"
(
  cd "${package_root}"
  lix --silent download
)

(
  cd "${repository_root}"
  haxelib run formatter --check \
    -s "${package_root}/src" \
    -s "${package_root}/test/differential-fixture/src"
)

temporary_parent="${package_root}/.sdk035-tmp"
mkdir -p "${temporary_parent}"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk035-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk035-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk035-tooling.XXXXXX")"
build_root="$(cd "${build_root}" && pwd -P)"
replay_root="$(cd "${replay_root}" && pwd -P)"
tooling_root="$(cd "${tooling_root}" && pwd -P)"

cleanup() {
  for temporary_root in "${tooling_root}" "${replay_root}" "${build_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk035-*) rm -rf -- "${temporary_root}" || true ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
  rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

generate_root() {
  local output_root="$1"
  mkdir -p "${output_root}/strict" "${output_root}/classic"
  (
    cd "${package_root}"
    "${lix_haxe}" \
      profiles/differential-strict.hxml \
      -js "${output_root}/strict/index.tsx" \
      -D "wordpress_hx_browser_export_manifest=${output_root}/strict/browser-exports.json"
    "${lix_haxe}" \
      profiles/differential-classic.hxml \
      -js "${output_root}/classic/index.js" \
      -D "wordpress_hx_browser_export_manifest=${output_root}/classic/browser-exports.json"
  )
  cp -f "${package_root}/test/differential-consumer/consumer.ts" \
    "${output_root}/strict/consumer.ts"
  cp -f "${package_root}/test/differential-consumer/consumer.ts" \
    "${output_root}/classic/consumer.ts"
}

generate_root "${build_root}"
generate_root "${replay_root}"

cp -f "${package_root}/hxx-tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/hxx-tooling/package-lock.json" \
  "${tooling_root}/package-lock.json"
cp -f "${package_root}/scripts/verify-differential.mjs" \
  "${tooling_root}/verify-differential.mjs"
cp -f "${package_root}/test/differential-runtime/run.mjs" \
  "${tooling_root}/run-differential.mjs"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e npm_config_cache=/tmp/npm-cache \
  -e "SDK035_CAPTURE=${SDK035_CAPTURE:-}" \
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
    for lane_root in /work/strict /work/classic /replay/strict /replay/classic; do
      ln -s /tooling/node_modules "${lane_root}/node_modules"
    done
    node ./verify-differential.mjs /repo/packages/gutenberg /work /replay
  '

echo "SDK-035 same-source Genes differential gate passed"
