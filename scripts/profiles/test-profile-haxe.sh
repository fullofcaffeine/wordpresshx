#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
package_root="${repository_root}/packages/core"

if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-012 Haxe contract gate requires Haxe 4.3.7" >&2
  exit 1
fi

haxelib run formatter --check \
  -s "${package_root}/src" \
  -s "${package_root}/test" \
  -s "${package_root}/test-positive" \
  -s "${package_root}/test-negative"

python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" --self-test
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" "${package_root}"

(
  cd "${package_root}"
  haxe test.hxml
)

haxe \
  -cp "${package_root}/src" \
  -cp "${package_root}/test-positive/profile_gate" \
  -main Main \
  -D wordpress_hx_profile=gutenberg-forward-23.4 \
  --interp

expect_compile_failure() {
  local label="$1"
  local expected="$2"
  shift 2
  local output
  output="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-sdk012-haxe.XXXXXX")"
  if haxe "$@" >"${output}" 2>&1; then
    echo "negative Haxe fixture unexpectedly compiled: ${label}" >&2
    rm -f "${output}"
    exit 1
  fi
  if ! grep -F -- "${expected}" "${output}" >/dev/null; then
    echo "negative Haxe fixture failed for the wrong reason: ${label}" >&2
    sed -n '1,100p' "${output}" >&2
    rm -f "${output}"
    exit 1
  fi
  rm -f "${output}"
}

expect_compile_failure \
  "forward capability under wp70-release" \
  "WPX1204" \
  -cp "${package_root}/src" \
  -cp "${package_root}/test-negative/profile_gate_wp70" \
  -main Main \
  -D wordpress_hx_profile=wp70-release \
  --interp

expect_compile_failure \
  "implicit profile selection" \
  "WPX1200" \
  -cp "${package_root}/src" \
  -cp "${package_root}/test-negative/profile_gate_implicit" \
  -main Main \
  --interp

expect_compile_failure \
  "request-scoped result used as compile-time authority" \
  "RuntimeCapability<Int> should be wordpress.hx.core.profile.CompileTimeCapability" \
  -cp "${package_root}/src" \
  -cp "${package_root}/test-negative/runtime_as_compile_time" \
  -main Main \
  --interp

expect_compile_failure \
  "unknown classification string" \
  "String should be wordpress.hx.core.profile.ApiClassification" \
  -cp "${package_root}/src" \
  -cp "${package_root}/test-negative/unknown_classification" \
  -main Main \
  --interp

echo "SDK-012 Haxe profile contract and compile-fail fixtures passed"
