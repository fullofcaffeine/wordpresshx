#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
lane="${1:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk090}"

if [[ "${lane}" != "mysql" && "${lane}" != "mariadb" ]]; then
  echo "usage: $0 <mysql|mariadb>" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the WordPress runtime harness" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for the WordPress HTTP check" >&2
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
  bash "${repository_root}/scripts/wordpress/reset-harness.sh" "${lane}" >&2
}
trap cleanup EXIT

python3 "${repository_root}/scripts/docker/check-image-lock.py" >&2
cleanup
"${compose[@]}" pull "${database_service}" "${wordpress_service}" >&2
python3 "${repository_root}/scripts/wordpress/verify-distribution.py" >&2
"${compose[@]}" up --detach --wait --wait-timeout 180 \
  "${database_service}" "${wordpress_service}" >&2

install_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/install.php)"
python3 -c '
import json, sys
payload = json.load(sys.stdin)
expected = {
    "freshInstall": True,
    "installed": True,
    "seed": "sdk-090",
}
if payload != expected:
    raise SystemExit(f"unexpected install result: {payload!r}")
' <<<"${install_json}"

health_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/health.php)"
python3 -c '
import json, sys
lane = sys.argv[1]
payload = json.load(sys.stdin)
expected = {
    "databaseQuery": 1,
    "installed": True,
    "phpVersion": "8.4.23",
    "profileId": "wp70-release",
    "seed": "sdk-090",
    "wordpressVersion": "7.0",
}
for key, value in expected.items():
    if payload.get(key) != value:
        raise SystemExit(f"unexpected {key}: {payload.get(key)!r}")
if lane == "mysql":
    if payload.get("databaseServerVersion") != "8.4.10":
        raise SystemExit(f"unexpected MySQL version: {payload!r}")
else:
    version = payload.get("databaseServerVersion", "")
    if not version.startswith("11.4.5-MariaDB"):
        raise SystemExit(f"unexpected MariaDB version: {payload!r}")
' "${lane}" <<<"${health_json}"

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
  "${install_json}" "${health_json}" <<'PY'
import json
import sys

lane, lock_path, install_json, health_json = sys.argv[1:]
lock = json.load(open(lock_path, encoding="utf-8"))
images = lock["images"]
database_key = "mysql" if lane == "mysql" else "mariadb"
print(json.dumps({
    "check": "wordpresshx-wordpress-runtime-v1",
    "databaseImage": images[database_key]["reference"],
    "databaseLane": lane,
    "freshReset": "passed",
    "httpFrontend": "passed",
    "install": json.loads(install_json),
    "runtime": json.loads(health_json),
    "wordpressImage": images["wordpress70Php84"]["reference"],
}, indent=2, sort_keys=True))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
