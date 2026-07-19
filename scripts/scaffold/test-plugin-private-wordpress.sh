#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
first_dir="${1:-}"
first_slug="${2:-}"
first_bootstrap="${3:-}"
first_bridge="${4:-}"
first_private="${5:-}"
second_dir="${6:-}"
second_slug="${7:-}"
second_bootstrap="${8:-}"
second_bridge="${9:-}"
second_private="${10:-}"
expected_title="${11:-}"
project_name="wordpresshx-sdk024-plugin-$$"

for plugin_dir in "${first_dir}" "${second_dir}"; do
  if [[ ! -d "${plugin_dir}" ]] || [[ -L "${plugin_dir}" ]]; then
    echo "private plugin fixture must be a real directory" >&2
    exit 2
  fi
done
first_dir="$(cd "${first_dir}" && pwd -P)"
second_dir="$(cd "${second_dir}" && pwd -P)"
python3 - \
  "${first_slug}" "${first_bootstrap}" "${first_bridge}" "${first_private}" \
  "${second_slug}" "${second_bootstrap}" "${second_bridge}" "${second_private}" \
  "${expected_title}" <<'PY'
import re
import sys

values = sys.argv[1:]
first_slug, first_bootstrap, first_bridge, first_private = values[:4]
second_slug, second_bootstrap, second_bridge, second_private = values[4:8]
expected = values[8]
slug_pattern = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
class_pattern = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\\[A-Za-z_][A-Za-z0-9_]*)+")
for slug in (first_slug, second_slug):
    if slug_pattern.fullmatch(slug) is None:
        raise SystemExit("invalid private plugin slug")
for class_name in (first_bootstrap, first_bridge, first_private, second_bootstrap, second_bridge, second_private):
    if class_pattern.fullmatch(class_name) is None:
        raise SystemExit("invalid private plugin class")
if not expected or any(character in expected for character in "\r\n\x00"):
    raise SystemExit("invalid expected private title")
PY
if [[ ! -f "${first_dir}/${first_slug}.php" ]] || [[ ! -f "${second_dir}/${second_slug}.php" ]]; then
  echo "generated private plugin root is missing" >&2
  exit 2
fi
for command_name in docker python3; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "private plugin WordPress gate requires ${command_name}" >&2
    exit 1
  }
done
docker info >/dev/null
docker compose version >/dev/null

compose=(
  docker compose
  --project-name "${project_name}"
  --file "${compose_file}"
  --profile mariadb
)

cleanup() {
  "${compose[@]}" down --volumes --remove-orphans >&2 || true
}
trap cleanup EXIT

python3 "${repository_root}/scripts/docker/check-image-lock.py" >&2
cleanup
"${compose[@]}" pull mariadb wordpress-mariadb >&2
python3 "${repository_root}/scripts/wordpress/verify-distribution.py" >&2
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
"${compose[@]}" cp "${first_dir}" "wordpress-mariadb:/var/www/html/wp-content/plugins/${first_slug}" >&2
"${compose[@]}" cp "${second_dir}" "wordpress-mariadb:/var/www/html/wp-content/plugins/${second_slug}" >&2
"${compose[@]}" cp "${repository_root}/compiler/wordpress/runtime/activate-plugin.php" \
  wordpress-mariadb:/opt/wordpresshx/activate-plugin.php >&2
"${compose[@]}" cp "${repository_root}/scripts/scaffold/plugin-private-wordpress.php" \
  wordpress-mariadb:/opt/wordpresshx/plugin-private-wordpress.php >&2

first_activation="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/activate-plugin.php "${first_slug}/${first_slug}.php" "${first_bootstrap}")"
second_activation="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/activate-plugin.php "${second_slug}/${second_slug}.php" "${second_bootstrap}")"
probe_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/plugin-private-wordpress.php \
  "${first_slug}/${first_slug}.php" "${second_slug}/${second_slug}.php" \
  "${first_bootstrap}" "${second_bootstrap}" "${first_bridge}" "${second_bridge}" \
  "${first_private}" "${second_private}")"
health_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php /opt/wordpresshx/health.php)"

result="$(python3 - "${expected_title}" "${install_json}" "${first_activation}" "${second_activation}" "${probe_json}" "${health_json}" <<'PY'
import json
import sys

expected, install_source, first_source, second_source, probe_source, health_source = sys.argv[1:]
install = json.loads(install_source)
first = json.loads(first_source)
second = json.loads(second_source)
probe = json.loads(probe_source)
health = json.loads(health_source)
if install != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"unexpected clean install: {install!r}")
for activation in (first, second):
    if activation.get("error") is not None or activation.get("outputBytes") != 0:
        raise SystemExit(f"private plugin activation failed: {activation!r}")
    if activation.get("active") is not True or activation.get("booted") is not True:
        raise SystemExit(f"private plugin did not remain active and booted: {activation!r}")
if not all(probe.get(key) is True for key in ("firstBooted", "secondBooted", "firstPrivateLoaded", "secondPrivateLoaded")):
    raise SystemExit(f"private plugin coexistence failed: {probe!r}")
signature = {"parameters": ["string", "int"], "return": "string"}
if probe.get("firstSignature") != signature or probe.get("secondSignature") != signature:
    raise SystemExit(f"private plugin public ABI differed: {probe!r}")
if probe.get("filteredTitle") != expected:
    raise SystemExit(f"private plugin behavior differed: {probe!r}")
if probe.get("wordpressVersion") != "7.0" or health.get("wordpressVersion") != "7.0":
    raise SystemExit(f"unexpected WordPress runtime: {probe!r} {health!r}")
if set(probe.get("active", {}).values()) != {True}:
    raise SystemExit(f"private plugins were not both active: {probe!r}")
print(json.dumps({
    "check": "wordpresshx-sdk024-private-wordpress-v1",
    "filteredTitle": probe["filteredTitle"],
    "outcome": "passed",
    "wordpress": "7.0",
}, sort_keys=True, separators=(",", ":")))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
