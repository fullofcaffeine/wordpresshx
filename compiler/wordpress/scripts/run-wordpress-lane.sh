#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(cd "${package_root}/../.." && pwd)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
fixture_dir="${package_root}/build/acme-books"
lane="${1:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk022}"

if [[ "${lane}" != "mysql" && "${lane}" != "mariadb" ]]; then
  echo "usage: $0 <mysql|mariadb>" >&2
  exit 2
fi
if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
  exit 2
fi
if [[ ! -f "${fixture_dir}/acme-books.php" ]]; then
  echo "missing generated acme-books plugin fixture" >&2
  exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the SDK-022 WordPress fixture" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for the SDK-022 WordPress HTTP check" >&2
  exit 1
fi
docker info >/dev/null
docker compose version >/dev/null

database_service="${lane}"
wordpress_service="wordpress-${lane}"
compose=(
  docker compose
  --project-name "${project_name}"
  --file "${compose_file}"
  --profile "${lane}"
)

cleanup() {
  "${compose[@]}" down --volumes --remove-orphans >&2
}
trap cleanup EXIT

python3 "${repository_root}/scripts/docker/check-image-lock.py" >&2
cleanup
"${compose[@]}" pull "${database_service}" "${wordpress_service}" >&2
python3 "${repository_root}/scripts/wordpress/verify-distribution.py" >&2
"${compose[@]}" up --detach --wait --wait-timeout 180 \
  "${database_service}" "${wordpress_service}" >&2

distribution_ready=false
for ((attempt = 1; attempt <= 90; attempt++)); do
  if "${compose[@]}" exec --no-TTY "${wordpress_service}" \
    test -f /var/www/html/wp-includes/version.php; then
    distribution_ready=true
    break
  fi
  sleep 1
done
if [[ "${distribution_ready}" != "true" ]]; then
  echo "WordPress distribution did not finish materializing" >&2
  exit 1
fi

install_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/install.php)"
python3 -c '
import json, sys
payload = json.load(sys.stdin)
expected = {"freshInstall": True, "installed": True, "seed": "sdk-090"}
if payload != expected:
    raise SystemExit(f"unexpected install result: {payload!r}")
' <<<"${install_json}"

"${compose[@]}" cp "${fixture_dir}" \
  "${wordpress_service}:/var/www/html/wp-content/plugins/acme-books" >&2
"${compose[@]}" cp "${package_root}/runtime/activate-plugin.php" \
  "${wordpress_service}:/opt/wordpresshx/activate-plugin.php" >&2
"${compose[@]}" cp "${package_root}/runtime/probe-plugin.php" \
  "${wordpress_service}:/opt/wordpresshx/probe-plugin.php" >&2

activation_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/activate-plugin.php \
  acme-books/acme-books.php 'Acme\Books\Bootstrap')"
probe_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/probe-plugin.php \
  acme-books/acme-books.php 'Acme\Books\Bootstrap')"
health_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/health.php)"

published_port="$("${compose[@]}" port "${wordpress_service}" 80)"
host_port="${published_port##*:}"
if [[ ! "${host_port}" =~ ^[0-9]+$ ]]; then
  echo "cannot determine published WordPress port from: ${published_port}" >&2
  exit 1
fi
http_body="$(curl --fail --silent --show-error --max-time 20 \
  --header 'Host: wordpresshx.test' "http://127.0.0.1:${host_port}/")"
if [[ "${http_body}" != *"WordPressHx SDK Harness"* ]]; then
  echo "WordPress frontend did not contain the seeded site title" >&2
  exit 1
fi

result="$(python3 - "${lane}" "${repository_root}/docker/images.lock.json" \
  "${install_json}" "${health_json}" "${activation_json}" "${probe_json}" <<'PY'
import json
import sys

lane, lock_path, install_json, health_json, activation_json, probe_json = sys.argv[1:]
images = json.load(open(lock_path, encoding="utf-8"))["images"]
database_key = "mysql" if lane == "mysql" else "mariadb"
print(json.dumps({
    "check": "wordpresshx-sdk022-wordpress-lane-v1",
    "databaseImage": images[database_key]["reference"],
    "databaseLane": lane,
    "freshReset": "passed",
    "httpFrontend": "passed",
    "install": json.loads(install_json),
    "pluginFixture": {
        "activation": json.loads(activation_json),
        "freshRequestProbe": json.loads(probe_json),
    },
    "runtime": json.loads(health_json),
    "wordpressImage": images["wordpress70Php84"]["reference"],
}, indent=2, sort_keys=True))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
