#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture_workspace="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-adr018-php.XXXXXX")"

cleanup() {
  rm -rf -- "${fixture_workspace}"
}
trap cleanup EXIT

for command_name in docker haxe python3; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "ADR-018 exact PHP matrix requires ${command_name}" >&2
    exit 1
  }
done
docker info >/dev/null

cd "${repository_root}"
python3 scripts/docker/check-image-lock.py >/dev/null
python3 scripts/runtime-support/build-fixtures.py \
  --output "${fixture_workspace}/packages" \
  >"${fixture_workspace}/build.json"

alpha_private="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["variants"][0]["privateClass"])' \
  "${fixture_workspace}/packages/build-summary.json")"
beta_private="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["variants"][1]["privateClass"])' \
  "${fixture_workspace}/packages/build-summary.json")"

php74_image="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["images"]["php74Floor"]["reference"])' \
  docker/images.lock.json)"
php84_image="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["images"]["php84Cli"]["reference"])' \
  docker/images.lock.json)"

run_lane() {
  local label="$1"
  local expected_version="$2"
  local image="$3"
  local actual_version
  local probe_json
  local cold_json
  local conflict_json
  local conflict_stderr

  actual_version="$(docker run --rm --network none "${image}" php -r 'echo PHP_VERSION;')"
  if [[ "${actual_version}" != "${expected_version}" ]]; then
    echo "${label} version mismatch: expected ${expected_version}, found ${actual_version}" >&2
    exit 1
  fi

  docker run --rm --network none \
    --mount "type=bind,src=${fixture_workspace}/packages,dst=/packages,readonly" \
    "${image}" sh -euc \
    "find /packages/runtime-alpha /packages/runtime-beta -type f -name '*.php' -print0 | sort -z | xargs -0 -n 1 php -l >/dev/null"

  probe_json="$(docker run --rm --network none \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${fixture_workspace}/packages,dst=/packages,readonly" \
    "${image}" php /repo/fixtures/runtime-support-packaging/runtime/cli-probe.php \
    /packages/runtime-alpha/runtime-alpha.php \
    /packages/runtime-beta/runtime-beta.php \
    "${alpha_private}" "${beta_private}")"
  python3 - "${probe_json}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected_signature = {"parameters": ["string", "int"], "return": "string"}
for key in ("alphaSignature", "betaSignature"):
    if payload.get(key) != expected_signature:
        raise SystemExit(f"exact PHP public signature differed: {payload!r}")
for key in ("alphaBooted", "betaBooted", "alphaPrivateLoaded", "betaPrivateLoaded", "prefixesDistinct"):
    if payload.get(key) is not True:
        raise SystemExit(f"exact PHP coexistence flag failed: {payload!r}")
if payload.get("filteredTitle") != "seed:alpha-v1:beta-v2":
    raise SystemExit(f"exact PHP private behavior differed: {payload!r}")
if payload.get("filterCount") != 2 or payload.get("outputBytes") != 0:
    raise SystemExit(f"exact PHP duplicate/output behavior differed: {payload!r}")
PY

  conflict_stderr="${fixture_workspace}/${label}-conflict.stderr"
  conflict_json="$(docker run --rm --network none \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${fixture_workspace}/packages,dst=/packages,readonly" \
    "${image}" php /repo/fixtures/runtime-support-packaging/runtime/conflict-probe.php \
    /packages/runtime-alpha/runtime-alpha.php 'RuntimeAlpha\Bootstrap' \
    2>"${conflict_stderr}")"
  python3 - "${conflict_json}" "${conflict_stderr}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = {"bootstrapLoaded": False, "filterCount": 0, "outputBytes": 0}
if payload != expected:
    raise SystemExit(f"exact PHP global-polyfill conflict behavior differed: {payload!r}")
if "WPHX5201" not in open(sys.argv[2], encoding="utf-8").read():
    raise SystemExit("exact PHP global-polyfill conflict omitted WPHX5201")
PY

  cold_json="$(docker run --rm --network none \
    --mount "type=bind,src=${repository_root},dst=/repo,readonly" \
    --mount "type=bind,src=${fixture_workspace}/packages,dst=/packages,readonly" \
    "${image}" php -d opcache.enable_cli=0 \
    /repo/fixtures/runtime-support-packaging/runtime/cold-boot.php \
    /packages/runtime-alpha/runtime-alpha.php 'RuntimeAlpha\PrivateBridge')"
  python3 - "${cold_json}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("result") != "seed:alpha-v1":
    raise SystemExit(f"exact PHP cold boot behavior differed: {payload!r}")
elapsed = payload.get("elapsedNanoseconds")
if not isinstance(elapsed, int) or elapsed < 1:
    raise SystemExit(f"exact PHP cold boot duration was invalid: {payload!r}")
PY

  python3 - "${label}" "${actual_version}" "${probe_json}" "${cold_json}" "${conflict_json}" <<'PY'
import json
import sys

label, version, probe, cold, conflict = sys.argv[1:]
print(json.dumps({
    "coldBoot": json.loads(cold),
    "coexistence": json.loads(probe),
    "globalPolyfillConflict": json.loads(conflict),
    "label": label,
    "phpVersion": version,
}, sort_keys=True, separators=(",", ":")))
PY
}

run_lane "php74" "7.4.33" "${php74_image}"
run_lane "php84" "8.4.7" "${php84_image}"
