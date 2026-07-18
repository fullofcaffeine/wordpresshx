#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"

for command_name in docker git haxe haxelib lix node npm python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-032 HXX gate requires ${command_name}" >&2
    exit 1
  fi
done

lix_binary="$(command -v lix)"
lix_haxe="$(command -v haxe)"
lix_install_root="$(cd "$(dirname "$(realpath "${lix_binary}")")/.." && pwd)"
if [[ ! -f "${lix_install_root}/package.json" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_install_root}/package.json")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(realpath "${lix_haxe}")" != "${lix_install_root}/bin/haxeshim.js" ]]; then
  echo "SDK-032 HXX gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-032 HXX gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi

python3 "${package_root}/scripts/verify-dependency-lock.py" --metadata-only
python3 "${package_root}/scripts/verify-hxx-profile.py"
(
  cd "${package_root}"
  lix --silent download
)

(
  cd "${repository_root}"
  haxelib run formatter --check \
    -s "${package_root}/src" \
    -s "${package_root}/test/hxx-fixture/src" \
    -s "${package_root}/test-negative-hxx" \
    -s "${repository_root}/packages/hxx/src"
)

temporary_parent="${package_root}/.sdk032-tmp"
mkdir -p "${temporary_parent}"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk032-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk032-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk032-tooling.XXXXXX")"

cleanup() {
	for temporary_root in "${tooling_root}" "${replay_root}" "${build_root}"; do
		case "${temporary_root}" in
			"${temporary_parent}"/wordpresshx-sdk032-*) rm -rf -- "${temporary_root}" || true ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
  rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

generate_root() {
  local output_root="$1"
  (
    cd "${package_root}"
    "${lix_haxe}" profiles/hxx-strict.hxml -js "${output_root}/index.tsx"
  )
}

generate_root "${build_root}"
generate_root "${replay_root}"

expect_compile_failure() {
  local label="$1"
  local expected_diagnostic="$2"
  local output="${tooling_root}/negative-${label}.txt"
  if (
    cd "${package_root}"
    "${lix_haxe}" \
      profiles/hxx-common.hxml \
      -cp "test-negative-hxx/${label}" \
      -main Main \
      -js "${tooling_root}/negative-${label}/index.tsx"
  ) >"${output}" 2>&1; then
    echo "negative HXX fixture unexpectedly compiled: ${label}" >&2
    exit 1
  fi
  if ! grep -F -- "${expected_diagnostic}" "${output}" >/dev/null \
    || ! grep -F -- "test-negative-hxx/${label}/Main.hx" "${output}" >/dev/null; then
    echo "negative HXX fixture failed for the wrong reason: ${label}" >&2
    sed -n '1,140p' "${output}" >&2
    exit 1
  fi
}

expect_compile_failure "missing_notice_children" "WPX3215"
expect_compile_failure "open_spread" "WPX3218"
expect_compile_failure "unknown_prop" "WPX3226"
expect_compile_failure "unsupported_switch" "WPX3213"
expect_compile_failure "wrong_event" "ReactMouseEvent<"
expect_compile_failure "wrong_ref" "String should be wordpress.hx.gutenberg.react.HtmlButtonElement"

cp -f "${package_root}/hxx-tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/hxx-tooling/package-lock.json" "${tooling_root}/package-lock.json"
cp -f "${package_root}/scripts/verify-hxx.mjs" "${tooling_root}/verify-hxx.mjs"
cp -f "${package_root}/test/hxx-runtime/runtime-entry.tsx" "${tooling_root}/runtime-entry.tsx"
cp -f "${package_root}/test/hxx-runtime/visual-entry.tsx" "${tooling_root}/visual-entry.tsx"

container_build_root="/repo/packages/gutenberg/.sdk032-tmp/$(basename "${build_root}")"
container_replay_root="/repo/packages/gutenberg/.sdk032-tmp/$(basename "${replay_root}")"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e npm_config_cache=/tmp/npm-cache \
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
    node ./verify-hxx.mjs /repo/packages/gutenberg "$1" "$2"
  ' _ "${container_build_root}" "${container_replay_root}"

if [[ -n "${SDK032_VISUAL_OUTPUT:-}" ]]; then
  mkdir -p -- "${SDK032_VISUAL_OUTPUT}"
  visual_output="$(cd "${SDK032_VISUAL_OUTPUT}" && pwd -P)"
  case "${visual_output}" in
    /|"${repository_root}"|"${package_root}")
      echo "refusing unsafe SDK032_VISUAL_OUTPUT: ${visual_output}" >&2
      exit 1
      ;;
  esac
  cp -f "${package_root}/test/hxx-runtime/index.html" "${visual_output}/index.html"
  cp -f "${build_root}/runtime/visual/proof.js" "${visual_output}/proof.js"
  cp -f "${build_root}/runtime/visual/proof.js.map" "${visual_output}/proof.js.map"
  cp -f "${build_root}/runtime/visual/proof.css" "${visual_output}/proof.css"
  cp -f "${build_root}/runtime/visual/proof.css.map" "${visual_output}/proof.css.map"
  echo "SDK-032 visual fixture written to ${visual_output}"
fi

echo "SDK-032 typed React/Gutenberg HXX gate passed"
