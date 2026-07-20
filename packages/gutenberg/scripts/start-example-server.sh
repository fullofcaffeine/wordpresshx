#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
example="${1:-}"
operation="${2:-start}"

case "${example}" in
  editor-sidebar)
    sdk="063"
    project_name="wordpresshx-example-editor-sidebar"
    preview_root="${package_root}/sdk063-preview"
    setup_source="${package_root}/test/editor-plugin-runtime/setup.php"
    setup_check="wordpresshx-sdk063-editor-setup-v1"
    ;;
  todo-data-store-lab)
    sdk="064"
    project_name="wordpresshx-example-todo-data-store-lab"
    preview_root="${package_root}/sdk064-preview"
    setup_source="${package_root}/test/data-store-runtime/setup.php"
    setup_check="wordpresshx-sdk064-data-store-setup-v1"
    ;;
  *)
    echo "usage: $0 <editor-sidebar|todo-data-store-lab> [start|stop]" >&2
    exit 2
    ;;
esac

if [[ "${operation}" != "start" && "${operation}" != "stop" ]]; then
  echo "usage: $0 <editor-sidebar|todo-data-store-lab> [start|stop]" >&2
  exit 2
fi
for command_name in docker git python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "example server requires ${command_name}" >&2
    exit 1
  fi
done
docker info >/dev/null
docker compose version >/dev/null

wordpress_service="wordpress-mysql"
compose=(
  docker compose
  --project-name "${project_name}"
  --file "${compose_file}"
  --profile mysql
)

if [[ "${operation}" == "stop" ]]; then
  "${compose[@]}" down --volumes --remove-orphans
  echo "Stopped ${example} and removed its isolated database volume."
  exit 0
fi

if [[ ! -f "${preview_root}/asset-plan.json" || ! -d "${preview_root}/wordpress-plugin" ]]; then
  echo "Building the ${example} plugin from Haxe for the first time..."
  if [[ "${sdk}" == "063" ]]; then
    SDK063_VISUAL_OUTPUT="${preview_root}" \
      bash "${package_root}/scripts/test-editor-plugin.sh" --skip-wordpress
  else
    SDK064_VISUAL_OUTPUT="${preview_root}" \
      bash "${package_root}/scripts/test-data-store.sh" --skip-wordpress
  fi
fi

IFS='|' read -r plugin_slug plugin_file < <(
  python3 - "${preview_root}/asset-plan.json" <<'PY'
import json
import pathlib
import re
import sys

plan = json.load(open(sys.argv[1], encoding="utf-8"))
slug = plan["plugin"]["slug"]
if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug) is None:
    raise SystemExit("unsafe plugin slug")
plugin_file = pathlib.Path(sys.argv[1]).parent / "wordpress-plugin" / f"{slug}.php"
if not plugin_file.is_file():
    raise SystemExit("generated plugin entry is absent")
print(f"{slug}|{plugin_file}")
PY
)
if [[ ! -f "${plugin_file}" ]]; then
  echo "generated plugin entry is absent: ${plugin_file}" >&2
  exit 1
fi

cleanup_on_error=true
cleanup() {
  if [[ "${cleanup_on_error}" == "true" ]]; then
    "${compose[@]}" down --volumes --remove-orphans >&2 || true
  fi
}
trap cleanup EXIT

python3 "${repository_root}/scripts/docker/check-image-lock.py"
"${compose[@]}" down --volumes --remove-orphans
"${compose[@]}" pull mysql "${wordpress_service}"
python3 "${repository_root}/scripts/wordpress/verify-distribution.py"
"${compose[@]}" up --detach --wait --wait-timeout 180 mysql "${wordpress_service}"

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

"${compose[@]}" cp "${preview_root}/wordpress-plugin" "${wordpress_service}:/var/www/html/wp-content/plugins/${plugin_slug}"
"${compose[@]}" cp "${setup_source}" "${wordpress_service}:/opt/wordpresshx/setup-example.php"
setup_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" php /opt/wordpresshx/setup-example.php "${plugin_slug}")"
post_id="$(python3 - "${setup_json}" "${setup_check}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("check") != sys.argv[2]:
    raise SystemExit(f"unexpected example setup: {payload!r}")
if payload.get("pluginActive") is not True or payload.get("wordpressVersion") != "7.0":
    raise SystemExit(f"unexpected example runtime: {payload!r}")
print(payload["postId"])
PY
)"

host_binding="$("${compose[@]}" port "${wordpress_service}" 80)"
host_port="${host_binding##*:}"
if [[ ! "${host_port}" =~ ^[1-9][0-9]{0,4}$ ]] || (( host_port > 65535 )); then
  echo "unable to resolve the local WordPress port: ${host_binding}" >&2
  exit 1
fi
origin="http://127.0.0.1:${host_port}"
"${compose[@]}" cp "${package_root}/test/demo-runtime/set-url.php" "${wordpress_service}:/opt/wordpresshx/set-url.php"
url_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" php /opt/wordpresshx/set-url.php "${origin}")"
python3 - "${url_json}" "${origin}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = {
    "check": "wordpresshx-example-public-url-v1",
    "home": sys.argv[2],
    "siteurl": sys.argv[2],
}
if payload != expected:
    raise SystemExit(f"unexpected public URL result: {payload!r}")
PY

cleanup_on_error=false
trap - EXIT
echo
echo "${example} is ready:"
echo "  ${origin}/wp-admin/post.php?post=${post_id}&action=edit"
echo "  username: wordpresshx_admin"
echo "  password: wordpresshx-test-only"
echo
echo "Open the editor Options menu and choose the example sidebar."
echo "Stop it with: bash packages/gutenberg/scripts/start-example-server.sh ${example} stop"
