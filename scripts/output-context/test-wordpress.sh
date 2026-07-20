#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
project_name="wordpresshx-adr012-$$"
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

for command_name in docker python3; do
	command -v "${command_name}" >/dev/null 2>&1 || {
		echo "ADR-012 WordPress output-context proof requires ${command_name}" >&2
		exit 1
	}
done
docker info >/dev/null
docker compose version >/dev/null

cd "${repository_root}"
python3 scripts/docker/check-image-lock.py >/dev/null
cleanup
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
"${compose[@]}" cp "${repository_root}/fixtures/output-context/runtime/wordpress-probe.php" \
	wordpress-mariadb:/opt/wordpresshx/output-context-probe.php >&2
probe_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php /opt/wordpresshx/output-context-probe.php)"

python3 - "${repository_root}/docker/images.lock.json" "${install_json}" "${probe_json}" <<'PY'
import json
import sys

lock_path, install_source, probe_source = sys.argv[1:]
images = json.load(open(lock_path, encoding="utf-8"))["images"]
install = json.loads(install_source)
probe = json.loads(probe_source)

if install != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"ADR-012 clean install differed: {install!r}")
if probe.get("check") != "wordpresshx-adr012-wordpress-output-context-v1":
    raise SystemExit(f"ADR-012 probe identity differed: {probe!r}")
if probe.get("wordpressVersion") != "7.0":
    raise SystemExit(f"ADR-012 WordPress version differed: {probe!r}")

payload_markers = ("<script", "javascript:")
for field in ("text", "attribute", "textarea", "blockMarkup", "adminNotice"):
    value = probe.get(field)
    if not isinstance(value, str):
        raise SystemExit(f"ADR-012 {field} is not a string: {value!r}")
    lowered = value.lower()
    if any(marker in lowered for marker in payload_markers):
        raise SystemExit(f"ADR-012 {field} retained executable markup: {value!r}")

if "&lt;script&gt;" not in probe["text"] or "&amp;" not in probe["text"]:
    raise SystemExit(f"ADR-012 text escaping differed: {probe['text']!r}")
if "&quot;" not in probe["attribute"] or "&lt;unsafe&gt;" not in probe["attribute"]:
    raise SystemExit(f"ADR-012 attribute escaping differed: {probe['attribute']!r}")
if '"' in probe["attribute"] or "<" in probe["attribute"] or ">" in probe["attribute"]:
    raise SystemExit(f"ADR-012 attribute retained a grammar-breaking byte: {probe['attribute']!r}")
if "&lt;/textarea&gt;" not in probe["textarea"]:
    raise SystemExit(f"ADR-012 textarea escaping differed: {probe['textarea']!r}")

urls = probe.get("url")
if not isinstance(urls, dict):
    raise SystemExit(f"ADR-012 URL result missing: {probe!r}")
if urls.get("javascript") != "":
    raise SystemExit(f"ADR-012 unsafe URL survived: {urls!r}")
if urls.get("https") != "https://example.test/todos/7?a=1&#038;b=2":
    raise SystemExit(f"ADR-012 HTTPS URL escaping differed: {urls!r}")
if urls.get("relative") != "/todos/7?mode=edit&#038;from=hxx":
    raise SystemExit(f"ADR-012 relative URL escaping differed: {urls!r}")

rich = probe.get("richHtml")
if not isinstance(rich, dict) or set(rich) != {"post", "data", "custom"}:
    raise SystemExit(f"ADR-012 rich HTML policies differed: {rich!r}")
for policy, value in rich.items():
    lowered = value.lower()
    if "<script" in lowered or "onmouseover=" in lowered or "javascript:" in lowered:
        raise SystemExit(f"ADR-012 {policy} policy retained executable markup: {value!r}")
if "<strong>kept</strong>" not in rich["post"]:
    raise SystemExit(f"ADR-012 post policy removed admitted markup: {rich['post']!r}")

script_json = probe.get("scriptJson")
if not isinstance(script_json, str) or "</script" in script_json.lower():
    raise SystemExit(f"ADR-012 script JSON retained a closing tag: {script_json!r}")
for escape in ("\\u003C", "\\u003E", "\\u0026", "\\u0022", "\\u0027"):
    if escape not in script_json:
        raise SystemExit(f"ADR-012 script JSON omitted {escape}: {script_json!r}")

if not probe["blockMarkup"].startswith('<section class="output-context-proof">'):
    raise SystemExit(f"ADR-012 block result was not native markup: {probe['blockMarkup']!r}")
if "<strong>Notice</strong>" not in probe["adminNotice"]:
    raise SystemExit(f"ADR-012 admin policy removed admitted markup: {probe['adminNotice']!r}")

rest = probe.get("rest")
if not isinstance(rest, dict) or rest.get("status") != 200:
    raise SystemExit(f"ADR-012 REST result differed: {rest!r}")
data = rest.get("data")
if not isinstance(data, dict) or data.get("kind") != "data-not-markup":
    raise SystemExit(f"ADR-012 REST data contract differed: {rest!r}")
if data.get("title") != '<script>alert("xss")</script><strong data-note="&quot;">kept</strong>&"\'':
    raise SystemExit(f"ADR-012 REST data was silently mutated: {rest!r}")
if "</script" in rest.get("encoded", "").lower():
    raise SystemExit(f"ADR-012 REST JSON retained a closing tag: {rest!r}")

print(json.dumps({
    "admin": "wp_admin_notice-wp_kses_post",
    "block": "native-dynamic-render-callback",
    "check": "wordpresshx-adr012-wordpress-output-context-v1",
    "databaseImage": images["mariadb"]["reference"],
    "outcome": "passed",
    "rest": "WP_REST_Response-plus-contextual-encoding",
    "wordpressImage": images["wordpress70Php84"]["reference"],
    "wordpressVersion": probe["wordpressVersion"],
}, indent=2, sort_keys=True))
PY

cleanup
trap - EXIT
