#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
playwright_image="mcr.microsoft.com/playwright@sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d"
plugin_root="${1:-}"
tooling_root="${2:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk055}"

if [[ ! -d "${plugin_root}" || ! -d "${tooling_root}" ]]; then
	echo "usage: $0 <generated-plugin-root> <tooling-root>" >&2
	exit 2
fi
if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
	echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
	exit 2
fi
for command_name in docker python3; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "SDK-055 WordPress lane requires ${command_name}" >&2
		exit 1
	fi
done
docker info >/dev/null
docker compose version >/dev/null

plugin_slug="wordpresshx-sdk055"
script_handle="wordpresshx-sdk055-messages"
text_domain="wordpresshx-sdk055"
wordpress_service="wordpress-mysql"
wordpress_url="http://${wordpress_service}"
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
"${compose[@]}" cp "${package_root}/test/i18n-runtime/setup.php" "${wordpress_service}:/opt/wordpresshx/setup-i18n.php" >&2
"${compose[@]}" cp "${package_root}/test/i18n-runtime/probe.php" "${wordpress_service}:/opt/wordpresshx/probe-i18n.php" >&2
setup_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" php /opt/wordpresshx/setup-i18n.php "${plugin_slug}" "${wordpress_url}")"
post_id="$(python3 - "${setup_json}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("check") != "wordpresshx-sdk055-setup-v1":
    raise SystemExit(f"unexpected SDK-055 setup identity: {payload!r}")
if (
    payload.get("locale") != "es_MX"
    or payload.get("pluginActive") is not True
    or payload.get("homeUrl") != "http://wordpress-mysql"
):
    raise SystemExit(f"unexpected SDK-055 setup result: {payload!r}")
if payload.get("wordpressVersion") != "7.0":
    raise SystemExit(f"unexpected WordPress version: {payload!r}")
print(payload["postId"])
PY
)"

for mode in frontend editor; do
	probe_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" php /opt/wordpresshx/probe-i18n.php "${mode}" "${script_handle}" "${text_domain}")"
	python3 - "${mode}" "${probe_json}" <<'PY'
import json
import sys

mode, raw = sys.argv[1:]
payload = json.loads(raw)
expected_hook = "enqueue_block_editor_assets" if mode == "editor" else "wp_enqueue_scripts"
if payload.get("check") != "wordpresshx-sdk055-wordpress-i18n-v1":
    raise SystemExit(f"unexpected SDK-055 probe identity: {payload!r}")
if payload.get("mode") != mode or payload.get("hook") != expected_hook:
    raise SystemExit(f"unexpected SDK-055 hook result: {payload!r}")
if payload.get("locale") != "es_MX" or payload.get("wordpressVersion") != "7.0":
    raise SystemExit(f"unexpected SDK-055 runtime identity: {payload!r}")
if payload.get("translationScriptBytes", 0) <= 0:
    raise SystemExit(f"SDK-055 locale data was empty: {payload!r}")
print(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False))
PY
done

network_name="${project_name}_default"
docker run --rm --network "${network_name}" --ipc=host \
	--mount "type=bind,src=${tooling_root},dst=/tooling,readonly" \
	-w /tooling "${playwright_image}" \
	node run-i18n-playwright.mjs "${wordpress_url}" "${post_id}"

cleanup
trap - EXIT
echo "SDK-055 real WordPress server, editor, and frontend locale lane passed"
