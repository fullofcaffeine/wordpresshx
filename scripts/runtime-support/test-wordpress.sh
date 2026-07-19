#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
fixture_workspace="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-adr018-wordpress.XXXXXX")"
project_name="wordpresshx-adr018-$$"
compose=(
  docker compose
  --project-name "${project_name}"
  --file "${compose_file}"
  --profile mariadb
)

compose_down() {
  "${compose[@]}" down --volumes --remove-orphans >&2 || true
}

cleanup() {
  compose_down
  rm -rf -- "${fixture_workspace}"
}
trap cleanup EXIT

for command_name in docker haxe python3; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "ADR-018 WordPress proof requires ${command_name}" >&2
    exit 1
  }
done
docker info >/dev/null
docker compose version >/dev/null

cd "${repository_root}"
python3 scripts/docker/check-image-lock.py >/dev/null
python3 scripts/runtime-support/build-fixtures.py \
  --output "${fixture_workspace}/packages" \
  >"${fixture_workspace}/build.json"

summary="${fixture_workspace}/packages/build-summary.json"
alpha_private="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["variants"][0]["privateClass"])' "${summary}")"
beta_private="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["variants"][1]["privateClass"])' "${summary}")"

compose_down
"${compose[@]}" pull mariadb wordpress-mariadb >&2
python3 scripts/wordpress/verify-distribution.py >/dev/null
"${compose[@]}" up --detach --wait --wait-timeout 180 mariadb wordpress-mariadb >&2

distribution_ready=false
for ((attempt = 1; attempt <= 90; attempt++)); do
  if "${compose[@]}" exec --no-TTY wordpress-mariadb test -f /var/www/html/wp-includes/version.php; then
    distribution_ready=true
    break
  fi
  sleep 1
done
if [[ "${distribution_ready}" != true ]]; then
  echo "WordPress distribution did not finish materializing" >&2
  exit 1
fi

install_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php /opt/wordpresshx/install.php)"
"${compose[@]}" cp "${fixture_workspace}/packages/runtime-alpha" \
  wordpress-mariadb:/var/www/html/wp-content/plugins/runtime-alpha >&2
"${compose[@]}" cp "${fixture_workspace}/packages/runtime-beta" \
  wordpress-mariadb:/var/www/html/wp-content/plugins/runtime-beta >&2
"${compose[@]}" cp "${repository_root}/compiler/wordpress/runtime/activate-plugin.php" \
  wordpress-mariadb:/opt/wordpresshx/activate-plugin.php >&2
"${compose[@]}" cp "${repository_root}/fixtures/runtime-support-packaging/runtime/wordpress-probe.php" \
  wordpress-mariadb:/opt/wordpresshx/runtime-support-probe.php >&2

alpha_activation="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/activate-plugin.php runtime-alpha/runtime-alpha.php 'RuntimeAlpha\Bootstrap')"
beta_activation="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/activate-plugin.php runtime-beta/runtime-beta.php 'RuntimeBeta\Bootstrap')"
probe_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/runtime-support-probe.php \
  runtime-alpha/runtime-alpha.php runtime-beta/runtime-beta.php \
  "${alpha_private}" "${beta_private}")"
health_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php /opt/wordpresshx/health.php)"

result="$(python3 - "${repository_root}/docker/images.lock.json" \
  "${install_json}" "${alpha_activation}" "${beta_activation}" "${probe_json}" "${health_json}" <<'PY'
import json
import sys

lock_file, install_source, alpha_source, beta_source, probe_source, health_source = sys.argv[1:]
images = json.load(open(lock_file, encoding="utf-8"))["images"]
install = json.loads(install_source)
alpha = json.loads(alpha_source)
beta = json.loads(beta_source)
probe = json.loads(probe_source)
health = json.loads(health_source)

if install != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"ADR-018 clean install differed: {install!r}")
expected_headers = {
    "alpha": {
        "Name": "Runtime Alpha",
        "Version": "1.0.0",
        "RequiresWP": "7.0",
        "RequiresPHP": "7.4",
        "TextDomain": "runtime-alpha",
        "DomainPath": "/languages",
    },
    "beta": {
        "Name": "Runtime Beta",
        "Version": "2.0.0",
        "RequiresWP": "7.0",
        "RequiresPHP": "7.4",
        "TextDomain": "runtime-beta",
        "DomainPath": "/languages",
    },
}
for label, activation in (("alpha", alpha), ("beta", beta)):
    if activation.get("header") != expected_headers[label]:
        raise SystemExit(f"ADR-018 {label} header differed: {activation!r}")
    if activation.get("error") is not None or activation.get("outputBytes") != 0:
        raise SystemExit(f"ADR-018 {label} activation failed: {activation!r}")
    if activation.get("active") is not True or activation.get("booted") is not True:
        raise SystemExit(f"ADR-018 {label} did not activate and boot: {activation!r}")

if probe.get("active") != {
    "runtime-alpha/runtime-alpha.php": True,
    "runtime-beta/runtime-beta.php": True,
}:
    raise SystemExit(f"ADR-018 active plugin inventory differed: {probe!r}")
for key in ("alphaBooted", "betaBooted", "alphaPrivateLoaded", "betaPrivateLoaded"):
    if probe.get(key) is not True:
        raise SystemExit(f"ADR-018 WordPress coexistence flag failed: {probe!r}")
expected_signature = {"parameters": ["string", "int"], "return": "string"}
for key in ("alphaSignature", "betaSignature"):
    if probe.get(key) != expected_signature:
        raise SystemExit(f"ADR-018 WordPress public signature differed: {probe!r}")
if probe.get("filteredTitle") != "seed:alpha-v1:beta-v2":
    raise SystemExit(f"ADR-018 WordPress private behavior differed: {probe!r}")
if probe.get("wordpressVersion") != "7.0" or health.get("wordpressVersion") != "7.0":
    raise SystemExit(f"ADR-018 WordPress version differed: {probe!r} {health!r}")

print(json.dumps({
    "activation": {"alpha": alpha, "beta": beta},
    "check": "wordpresshx-adr018-runtime-support-wordpress-v1",
    "databaseImage": images["mariadb"]["reference"],
    "install": install,
    "outcome": "passed",
    "probe": probe,
    "wordpressImage": images["wordpress70Php84"]["reference"],
}, indent=2, sort_keys=True))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
