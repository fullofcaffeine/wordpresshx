#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

for command_name in grep python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "semantic collector gate requires ${command_name}" >&2
    exit 1
  fi
done

unset REQUIRED_PUBLIC_VALUE SITE_LOCALE

test_root="$(mktemp -d)"
haxe_server_pid=""
cleanup() {
  if [[ -n "${haxe_server_pid}" ]]; then
    kill -TERM "${haxe_server_pid}" >/dev/null 2>&1 || true
    wait "${haxe_server_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "${test_root}"
}
trap cleanup EXIT INT TERM

haxe \
  -cp packages/build/src \
  -cp fixtures/semantic-collector/src \
  --macro "fixtures.semanticcollector.JsonBoundaryTest.run()" \
  --no-output

compile_fixture() {
  local output_root="$1"
  shift
  mkdir -p "${output_root}"
  local macro_call
  macro_call="wordpress.hx.build.SemanticPlan.install(\"fixtures/semantic-collector/config.json\",\"${output_root}/plan.json\",\"${output_root}/inputs.json\")"
  haxe "$@" \
    -cp packages/build/src \
    -cp fixtures/semantic-collector/src \
    -main fixtures.semanticcollector.ValidFixture \
    --macro "${macro_call}" \
    -js "${output_root}/runtime.js" \
    -dce full
}

compile_fixture "${test_root}/direct-a"
compile_fixture "${test_root}/direct-b"
cmp "${test_root}/direct-a/plan.json" "${test_root}/direct-b/plan.json"
cmp "${test_root}/direct-a/inputs.json" "${test_root}/direct-b/inputs.json"
cmp "${test_root}/direct-a/runtime.js" "${test_root}/direct-b/runtime.js"

python3 scripts/semantic-collector/test-contract.py \
  --plan "${test_root}/direct-a/plan.json" \
  --inputs "${test_root}/direct-a/inputs.json" \
  --runtime "${test_root}/direct-a/runtime.js"

server_port="$(python3 - <<'PY'
import socket
with socket.socket() as candidate:
    candidate.bind(("127.0.0.1", 0))
    print(candidate.getsockname()[1])
PY
)"
haxe --wait "${server_port}" >"${test_root}/haxe-server.log" 2>&1 &
haxe_server_pid="$!"
server_ready=0
for _ in $(seq 1 50); do
  if haxe --connect "${server_port}" -version >/dev/null 2>&1; then
    server_ready=1
    break
  fi
  sleep 0.1
done
if [[ "${server_ready}" -ne 1 ]]; then
  echo "semantic collector Haxe server did not become ready" >&2
  exit 1
fi
compile_fixture "${test_root}/server-a" --connect "${server_port}"
compile_fixture "${test_root}/server-b" --connect "${server_port}"
cmp "${test_root}/direct-a/plan.json" "${test_root}/server-a/plan.json"
cmp "${test_root}/direct-a/inputs.json" "${test_root}/server-a/inputs.json"
cmp "${test_root}/server-a/plan.json" "${test_root}/server-b/plan.json"
cmp "${test_root}/server-a/inputs.json" "${test_root}/server-b/inputs.json"

run_negative() {
  local mode="$1"
  local code="$2"
  local output_root="${test_root}/negative-${mode}"
  mkdir -p "${output_root}"
  local macro_call
  macro_call="wordpress.hx.build.SemanticPlan.install(\"fixtures/semantic-collector/config.json\",\"${output_root}/plan.json\",\"${output_root}/inputs.json\")"
  if haxe \
    -cp packages/build/src \
    -cp fixtures/semantic-collector/src \
    -main fixtures.semanticcollector.InvalidFixture \
    -D "${mode}" \
    --macro "${macro_call}" \
    -js "${output_root}/runtime.js" \
    -dce full >"${output_root}/compile.log" 2>&1; then
    echo "negative semantic collector mode unexpectedly passed: ${mode}" >&2
    exit 1
  fi
  if ! grep -F "${code}:" "${output_root}/compile.log" >/dev/null; then
    echo "negative semantic collector mode lacked ${code}: ${mode}" >&2
    sed -n '1,120p' "${output_root}/compile.log" >&2
    exit 1
  fi
  if [[ -e "${output_root}/plan.json" || -e "${output_root}/inputs.json" ]]; then
    echo "failed semantic collection published intermediate artifacts: ${mode}" >&2
    exit 1
  fi
}

run_negative duplicate_module WPHX4041
run_negative duplicate_hook WPHX4046
run_negative missing_module WPHX4045
run_negative missing_profile_capability WPHX4047
run_negative wrong_action_return WPHX4018
run_negative missing_filter_capability WPHX4047
run_negative wrong_filter_return WPHX4019
run_negative computed_identity WPHX4002
run_negative resource_traversal WPHX4024
run_negative missing_environment WPHX4044
run_negative duplicate_service WPHX4181
run_negative unknown_service_dependency WPHX4182
run_negative invalid_service_environment WPHX4187
run_negative invalid_service_port WPHX4191
run_negative invalid_service_readiness WPHX4195
run_negative unlocked_external_service WPHX4188
run_negative unadmitted_external_component WPHX4189
run_negative service_cycle WPHX4203

assert_no_pattern() {
  local description="$1"
  local pattern="$2"
  shift 2
  if grep -R -n -E "${pattern}" "$@"; then
    echo "${description}" >&2
    return 1
  else
    local scan_status="$?"
    if [[ "${scan_status}" -ne 1 ]]; then
      echo "${description}: scanner failed with status ${scan_status}" >&2
      return 1
    fi
  fi
}

assert_no_pattern \
  "semantic collector source contains a network-capable dependency" \
  '(sys\.net|haxe\.Http|curl|wget|Socket)' \
  packages/build/src

python3 scripts/lint/haxe-weak-type-guard.py --self-test
python3 scripts/lint/haxe-weak-type-guard.py packages/build/src

assert_no_pattern \
  "semantic collector leaked into runtime JavaScript" \
  '(wordpress[._]hx[._]build|SemanticCollector|ModuleDeclaration|HookDeclaration|BuildInputDeclaration)' \
  "${test_root}/direct-a/runtime.js"

echo "semantic collector source and runtime isolation scans passed"
echo "SEMANTIC_COLLECTOR_COMPILE_SUMMARY={\"directBuildCount\":2,\"jsonBoundaryVectorCount\":8,\"negativeCompileCount\":18,\"outcome\":\"passed\",\"serverBuildCount\":2}"
