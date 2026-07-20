#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
playwright_image="mcr.microsoft.com/playwright@sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d"
plugin_root="${1:-}"
plan_path="${2:-}"
tooling_root="${3:-}"
evidence_root="${4:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk064}"

if [[ ! -d "${plugin_root}" || ! -f "${plan_path}" || ! -d "${tooling_root}" || ! -d "${evidence_root}" ]]; then
  echo "usage: $0 <generated-plugin-root> <asset-plan.json> <tooling-root> <evidence-root>" >&2
  exit 2
fi
if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
  exit 2
fi
for command_name in docker python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-064 real data-store lane requires ${command_name}" >&2
    exit 1
  fi
done
docker info >/dev/null
docker compose version >/dev/null

IFS='|' read -r plugin_slug plugin_name sidebar_name supported_post_type store_key < <(
  python3 - "${plan_path}" <<'PY'
import json
import sys

plan = json.load(open(sys.argv[1], encoding="utf-8"))
print("|".join([
    plan["plugin"]["slug"],
    plan["editor"]["pluginName"],
    plan["editor"]["sidebarName"],
    plan["editor"]["supportedPostType"],
    plan["dataStore"]["key"],
]))
PY
)
for identity in "${plugin_slug}" "${plugin_name}" "${sidebar_name}"; do
  if [[ ! "${identity}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "unsafe generated data-store identity: ${identity}" >&2
    exit 2
  fi
done
if [[ ! "${store_key}" =~ ^[a-z][a-z0-9-]+(/[a-z][a-z0-9-]+)+$ ]] \
  || [[ "${supported_post_type}" != "post" ]] \
  || [[ ! -f "${plugin_root}/${plugin_slug}.php" ]]; then
  echo "generated data-store plugin shape is invalid" >&2
  exit 2
fi

wordpress_service="wordpress-mysql"
compose=(
  docker compose
  --project-name "${project_name}"
  --file "${compose_file}"
  --profile mysql
)

cleanup() {
  "${compose[@]}" down --volumes --remove-orphans >&2
}
trap cleanup EXIT

python3 "${repository_root}/scripts/docker/check-image-lock.py" >&2
cleanup
"${compose[@]}" pull mysql "${wordpress_service}" >&2
python3 "${repository_root}/scripts/wordpress/verify-distribution.py" >&2
"${compose[@]}" up --detach --wait --wait-timeout 180 mysql "${wordpress_service}" >&2

distribution_ready=false
for ((attempt = 1; attempt <= 90; attempt++)); do
  if "${compose[@]}" exec --no-TTY "${wordpress_service}" test -f /var/www/html/wp-includes/version.php; then
    distribution_ready=true
    break
  fi
  sleep 1
done
if [[ "${distribution_ready}" != "true" ]]; then
  echo "WordPress distribution did not finish materializing" >&2
  exit 1
fi

install_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" php /opt/wordpresshx/install.php)"
python3 -c '
import json, sys
payload = json.load(sys.stdin)
if payload != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"unexpected install result: {payload!r}")
' <<<"${install_json}"

"${compose[@]}" cp "${plugin_root}" "${wordpress_service}:/var/www/html/wp-content/plugins/${plugin_slug}" >&2
"${compose[@]}" cp "${package_root}/test/data-store-runtime/setup.php" "${wordpress_service}:/opt/wordpresshx/setup-data-store.php" >&2
setup_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" php /opt/wordpresshx/setup-data-store.php "${plugin_slug}")"
IFS='|' read -r post_id page_id < <(
  python3 - "${setup_json}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("check") != "wordpresshx-sdk064-data-store-setup-v1":
    raise SystemExit(f"unexpected setup identity: {payload!r}")
if payload.get("pluginActive") is not True or payload.get("wordpressVersion") != "7.0":
    raise SystemExit(f"unexpected data-store runtime setup: {payload!r}")
print(f"{payload['postId']}|{payload['pageId']}")
PY
)

network_name="${project_name}_default"
docker run --rm --network "${network_name}" --ipc=host \
  --mount "type=bind,src=${tooling_root},dst=/tooling,readonly" \
  --mount "type=bind,src=${evidence_root},dst=/evidence" \
  -w /tooling "${playwright_image}" \
  node run-data-store-playwright.mjs \
    http://wordpress-mysql "${post_id}" "${page_id}" "${plugin_name}" \
    /evidence/todo-data-store.png

test -s "${evidence_root}/todo-data-store.png"
test -s "${evidence_root}/todo-data-store.png.json"
cleanup
trap - EXIT
echo "SDK-064 real WordPress data-store lane passed"
