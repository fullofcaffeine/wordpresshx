#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
plugin_dir="${1:-}"
slug="${2:-}"
bootstrap_class="${3:-}"
expected_name="${4:-}"
expected_version="${5:-}"
project_name="wordpresshx-sdk045-plugin-$$"

if [[ ! -d "${plugin_dir}" ]] || [[ -L "${plugin_dir}" ]]; then
  echo "plugin fixture must be a real directory" >&2
  exit 2
fi
plugin_dir="$(cd "${plugin_dir}" && pwd -P)"
python3 - "${slug}" "${bootstrap_class}" "${expected_name}" "${expected_version}" <<'PY'
import re
import sys

slug, bootstrap, name, version = sys.argv[1:]
if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug):
    raise SystemExit("invalid plugin slug")
if not re.fullmatch(r"[A-Z_][A-Za-z0-9_]*(?:\\[A-Z_][A-Za-z0-9_]*)*\\Bootstrap", bootstrap):
    raise SystemExit("invalid bootstrap class")
if not name or any(character in name for character in "\r\n\x00"):
    raise SystemExit("invalid expected plugin name")
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", version):
    raise SystemExit("invalid expected plugin version")
PY
if [[ ! -f "${plugin_dir}/${slug}.php" ]]; then
  echo "generated plugin root is missing" >&2
  exit 2
fi
for command_name in docker python3; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "plugin WordPress gate requires ${command_name}" >&2
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
  "${compose[@]}" down --volumes --remove-orphans >&2
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
"${compose[@]}" cp "${plugin_dir}" "wordpress-mariadb:/var/www/html/wp-content/plugins/${slug}" >&2
"${compose[@]}" cp "${repository_root}/compiler/wordpress/runtime/activate-plugin.php" \
  wordpress-mariadb:/opt/wordpresshx/activate-plugin.php >&2
"${compose[@]}" cp "${repository_root}/compiler/wordpress/runtime/probe-plugin.php" \
  wordpress-mariadb:/opt/wordpresshx/probe-plugin.php >&2

activation_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/activate-plugin.php "${slug}/${slug}.php" "${bootstrap_class}")"
probe_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php \
  /opt/wordpresshx/probe-plugin.php "${slug}/${slug}.php" "${bootstrap_class}")"
health_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php /opt/wordpresshx/health.php)"

result="$(python3 - "${slug}" "${bootstrap_class}" "${expected_name}" "${expected_version}" \
  "${install_json}" "${activation_json}" "${probe_json}" "${health_json}" <<'PY'
import json
import sys

slug, bootstrap, expected_name, expected_version, install_source, activation_source, probe_source, health_source = sys.argv[1:]
install = json.loads(install_source)
activation = json.loads(activation_source)
probe = json.loads(probe_source)
health = json.loads(health_source)
if install != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"unexpected clean install: {install!r}")
if health.get("wordpressVersion") != "7.0":
    raise SystemExit(f"unexpected WordPress runtime: {health!r}")
expected_header = {
    "Name": expected_name,
    "Version": expected_version,
    "RequiresWP": "7.0",
    "RequiresPHP": "7.4",
    "TextDomain": slug,
    "DomainPath": "/languages",
}
if activation.get("header") != expected_header:
    raise SystemExit(f"generated header discovery differed: {activation!r}")
if activation.get("error") is not None or activation.get("outputBytes") != 0:
    raise SystemExit(f"generated plugin activation failed: {activation!r}")
for document in (activation, probe):
    if document.get("active") is not True or document.get("booted") is not True:
        raise SystemExit(f"generated plugin did not remain active and booted: {document!r}")
if probe.get("class") != bootstrap or probe.get("methods") != ["boot", "isBooted"]:
    raise SystemExit(f"generated bootstrap reflection differed: {probe!r}")
if probe.get("bootstrapFile") != f"{slug}/includes/Bootstrap.php":
    raise SystemExit(f"generated bootstrap path differed: {probe!r}")
print(json.dumps({
    "check": "wordpresshx-sdk045-plugin-wordpress-v1",
    "database": "mariadb",
    "plugin": f"{slug}/{slug}.php",
    "profile": "wp70-release",
    "wordpress": "7.0",
    "outcome": "passed",
}, sort_keys=True, separators=(",", ":")))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
