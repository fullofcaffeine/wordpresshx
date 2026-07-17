#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"

if ! command -v lix >/dev/null 2>&1 \
  || ! command -v npm >/dev/null 2>&1 \
  || ! command -v node >/dev/null 2>&1; then
  echo "SDK-080 HXX gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]]; then
  echo "SDK-080 HXX gate requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
  exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-080 HXX gate requires Lix-scoped Haxe 4.3.7" >&2
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
    -s "${package_root}/test-positive" \
    -s "${package_root}/test-negative"
)

build_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-sdk080.XXXXXX")"
trap 'rm -rf "${build_root}"' EXIT

(
  cd "${package_root}"
  "${lix_haxe}" \
    -lib tink_hxx \
    -cp src \
    -cp test-positive/server \
    -main Main \
    -dce full \
    -php "${build_root}/server"
  "${lix_haxe}" \
    -lib tink_hxx \
    -cp src \
    -cp test-positive/browser \
    -main Main \
    -dce full \
    -js "${build_root}/browser.js"
)

php "${build_root}/server/index.php" >"${build_root}/server.json"
node "${build_root}/browser.js" >"${build_root}/browser.json"
python3 "${package_root}/scripts/verify-snapshots.py" \
  "${package_root}/test/expected/server.json" \
  "${package_root}/test/expected/browser.json" \
  "${build_root}/server.json" \
  "${build_root}/browser.json"

if leak_scan_output="$(
  grep -R -n -i -E \
    'tink[._/]hxx|coconut|virtual.?dom|component.?registry|template.?resolver' \
    "${build_root}/server" "${build_root}/browser.js" 2>&1
)"; then
  printf '%s\n' "${leak_scan_output}"
  echo "compile-time HXX/parser or prohibited UI runtime leaked into output" >&2
  exit 1
else
  leak_scan_status=$?
  if (( leak_scan_status != 1 )); then
    printf '%s\n' "${leak_scan_output}" >&2
    echo "compile-time HXX/parser runtime-leak scan failed" >&2
    exit 1
  fi
fi

browser_bytes="$(wc -c <"${build_root}/browser.js" | tr -d ' ')"
server_bytes="$(find "${build_root}/server" -type f -exec wc -c {} + | awk '{total += $1} END {print total}')"
browser_sha256="$(shasum -a 256 "${build_root}/browser.js" | awk '{print $1}')"
server_tree_sha256="$(
  cd "${build_root}/server"
  find . -type f | LC_ALL=C sort | while IFS= read -r file; do
    digest="$(shasum -a 256 "${file}" | awk '{print $1}')"
    relative="${file#./}"
    printf '%s  %s\n' "${digest}" "${relative}"
  done | shasum -a 256 | awk '{print $1}'
)"
if (( browser_bytes > 12000 )); then
  echo "SDK-080 browser evidence artifact exceeded 12000 bytes: ${browser_bytes}" >&2
  exit 1
fi
if (( server_bytes > 220000 )); then
  echo "SDK-080 server evidence artifact exceeded 220000 bytes: ${server_bytes}" >&2
  exit 1
fi
if [[ "${browser_sha256}" != "8c2f91f485ff1aa5a237bb8aebf4b92c62d3976fd4016ada960cb383444e8123" ]]; then
  echo "SDK-080 browser artifact snapshot changed: ${browser_sha256}" >&2
  exit 1
fi
if [[ "${server_tree_sha256}" != "750c7072758d3b7ab65536debd32f76c964427453cbd1ea3ac4b0e4b094c4770" ]]; then
  echo "SDK-080 server artifact tree snapshot changed: ${server_tree_sha256}" >&2
  exit 1
fi

spread_override_output="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-sdk080-override.XXXXXX")"
(
  cd "${package_root}"
  "${lix_haxe}" \
    -lib tink_hxx \
    -cp src \
    -cp test-positive/spread_override \
    -main Main \
    --interp
) >"${spread_override_output}" 2>&1
if ! grep -F -- "WPXHXX1107 explicit prop count overrides a spread value on <Panel>" "${spread_override_output}" >/dev/null; then
  echo "closed-spread override fixture did not emit the expected diagnostic" >&2
  sed -n '1,120p' "${spread_override_output}" >&2
  rm -f "${spread_override_output}"
  exit 1
fi
rm -f "${spread_override_output}"

expect_compile_failure() {
  local label="$1"
  local expected="$2"
  local fixture="$3"
  local output
  output="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-sdk080-negative.XXXXXX")"
  if (
    cd "${package_root}"
    "${lix_haxe}" \
      -lib tink_hxx \
      -cp src \
      -cp "test-negative/${fixture}" \
      -main Main \
      --interp
  ) >"${output}" 2>&1; then
    echo "negative HXX fixture unexpectedly compiled: ${label}" >&2
    rm -f "${output}"
    exit 1
  fi
  if ! grep -F -- "${expected}" "${output}" >/dev/null; then
    echo "negative HXX fixture failed for the wrong reason: ${label}" >&2
    sed -n '1,120p' "${output}" >&2
    rm -f "${output}"
    exit 1
  fi
  if ! grep -F -- "test-negative/${fixture}/Main.hx:" "${output}" >/dev/null; then
    echo "negative HXX diagnostic did not retain the fixture source position: ${label}" >&2
    sed -n '1,120p' "${output}" >&2
    rm -f "${output}"
    exit 1
  fi
  rm -f "${output}"
}

expect_compile_failure "wrong prop type" "WPXHXX1100" "wrong_prop_type"
expect_compile_failure "missing required prop" "WPXHXX1003" "missing_prop"
expect_compile_failure "unknown prop" "WPXHXX1105" "unknown_prop"
expect_compile_failure "open or dynamic spread" "WPXHXX1103" "open_spread"
expect_compile_failure \
  "optional spread does not satisfy required prop" \
  "WPXHXX1003" \
  "optional_spread_missing_prop"
expect_compile_failure "missing named slot" "WPXHXX1004" "missing_slot"
expect_compile_failure "duplicate named slot" "WPXHXX1006" "duplicate_slot"
expect_compile_failure \
  "wrong child spread element type" \
  "WPXHXX1200" \
  "wrong_child_spread"
expect_compile_failure "target mismatch" "WPXHXX1002" "target_mismatch"
expect_compile_failure \
  "malformed markup" \
  "found </main> but expected </span>" \
  "malformed_markup"

echo "SDK-080 typed compile-time HXX parser prototype passed"
