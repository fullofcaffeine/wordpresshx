#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
profile_path="${package_root}/src/wordpress/hx/gutenberg/profile/wp70-release.block-metadata.json"
assets_path="${package_root}/test/block-metadata-fixture/assets.manifest.json"
fixture_assets="${package_root}/test/block-metadata-fixture/final-artifacts"
skip_wordpress=false

if [[ "${1:-}" == "--skip-wordpress" ]]; then
  skip_wordpress=true
  shift
fi
if [[ "$#" -ne 0 ]]; then
  echo "usage: $0 [--skip-wordpress]" >&2
  exit 2
fi

for command_name in diff git haxe haxelib python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-060 block metadata gate requires ${command_name}" >&2
    exit 1
  fi
done

haxelib run formatter --check \
  -s "${package_root}/src/wordpress/hx/gutenberg/block" \
  -s "${package_root}/test/block-metadata-fixture/src" \
  -s "${package_root}/test-negative-block"

temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk060-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk060-replay.XXXXXX")"
negative_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk060-negative.XXXXXX")"

cleanup() {
  for temporary_root in "${build_root}" "${replay_root}" "${negative_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk060-*) rm -rf -- "${temporary_root}" ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
}
trap cleanup EXIT

compile_fixture() {
  local output_root="$1"
  cp -rf "${fixture_assets}/." "${output_root}/"
  (
    cd "${repository_root}"
    haxe \
      -cp packages/build/src \
      -cp packages/gutenberg/src \
      -cp packages/gutenberg/test/block-metadata-fixture/src \
      -main sdk060.fixture.Main \
      --macro 'wordpress.hx.gutenberg.block.Block.install()' \
      -D "wordpress_hx_block_profile=${profile_path}" \
      -D "wordpress_hx_block_assets=${assets_path}" \
      -D "wordpress_hx_block_output=${output_root}" \
      --interp
  )
}

compile_fixture "${build_root}"
compile_fixture "${replay_root}"
diff -ru "${build_root}" "${replay_root}"

python3 "${package_root}/scripts/verify-block-metadata.py" \
  "${profile_path}" "${assets_path}" "${build_root}" "${replay_root}"

expect_compile_failure() {
  local fixture="$1"
  local diagnostic="$2"
  local output_root="${negative_root}/${fixture}"
  local output="${negative_root}/${fixture}.txt"
  mkdir -p "${output_root}"
  cp -rf "${fixture_assets}/." "${output_root}/"
  if (
    cd "${repository_root}"
    haxe \
      -cp packages/build/src \
      -cp packages/gutenberg/src \
      -cp packages/gutenberg/test/block-metadata-fixture/src \
      -cp "packages/gutenberg/test-negative-block/${fixture}" \
      -main Main \
      --macro 'wordpress.hx.gutenberg.block.Block.install()' \
      -D "wordpress_hx_block_profile=${profile_path}" \
      -D "wordpress_hx_block_assets=${assets_path}" \
      -D "wordpress_hx_block_output=${output_root}" \
      --interp
  ) >"${output}" 2>&1; then
    echo "negative block metadata fixture unexpectedly compiled: ${fixture}" >&2
    exit 1
  fi
  if ! grep -F -- "${diagnostic}" "${output}" >/dev/null; then
    echo "negative block metadata fixture failed for the wrong reason: ${fixture}" >&2
    sed -n '1,120p' "${output}" >&2
    exit 1
  fi
}

expect_compile_failure unknown_metadata WPX6020
expect_compile_failure forward_metadata WPX6021
expect_compile_failure wrong_default WPX6018
expect_compile_failure wrong_source WPX6012
expect_compile_failure wrong_role WPX6014
expect_compile_failure wrong_category WPX6027
expect_compile_failure missing_asset WPX6030
expect_compile_failure unknown_support WPX6029
expect_compile_failure api_version WPX6025

if [[ "${skip_wordpress}" != "true" ]]; then
  "${package_root}/scripts/run-wordpress-block-metadata-lane.sh" "${build_root}"
fi

if [[ -n "${SDK060_BLOCK_OUTPUT:-}" ]]; then
  if [[ -e "${SDK060_BLOCK_OUTPUT}" ]]; then
    echo "SDK060_BLOCK_OUTPUT must not already exist: ${SDK060_BLOCK_OUTPUT}" >&2
    exit 2
  fi
  cp -rf "${build_root}" "${SDK060_BLOCK_OUTPUT}"
fi

echo "SDK-060 typed block.json compiler passed"
