#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
plan_path="${1:-}"
if [[ -z "${plan_path}" || ! -f "${plan_path}" ]]; then
	echo "ADR-012 WordPress output-context proof requires the Haxe-generated plan path" >&2
	exit 1
fi
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
"${compose[@]}" cp "${plan_path}" \
	wordpress-mariadb:/opt/wordpresshx/output-context-plan.json >&2
probe_json="$("${compose[@]}" exec --no-TTY wordpress-mariadb php /opt/wordpresshx/output-context-probe.php)"

python3 - "${repository_root}/docker/images.lock.json" "${plan_path}" "${install_json}" "${probe_json}" <<'PY'
import hashlib
import json
import sys

lock_path, plan_path, install_source, probe_source = sys.argv[1:]
images = json.load(open(lock_path, encoding="utf-8"))["images"]
plan_bytes = open(plan_path, "rb").read()
plan = json.loads(plan_bytes)
install = json.loads(install_source)
probe = json.loads(probe_source)

if install != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"ADR-012 clean install differed: {install!r}")
if probe.get("check") != "wordpresshx-adr012-wordpress-output-context-v1":
    raise SystemExit(f"ADR-012 probe identity differed: {probe!r}")
if probe.get("wordpressVersion") != "7.0":
    raise SystemExit(f"ADR-012 WordPress version differed: {probe!r}")
if probe.get("planSha256") != hashlib.sha256(plan_bytes).hexdigest():
    raise SystemExit(f"ADR-012 WordPress did not consume the generated plan: {probe!r}")

payload_markers = ("<script", "javascript:")
for field in ("text", "attribute", "textarea", "blockMarkup", "adminNotice", "compilerMarkup"):
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
if urls.get("protocolRelative") != "" or urls.get("data") != "":
    raise SystemExit(f"ADR-012 rejected URL shape survived: {urls!r}")
if urls.get("https") != "https://example.test/path":
    raise SystemExit(f"ADR-012 HTTPS URL escaping differed: {urls!r}")
if urls.get("schemeCase") != "https://example.test/path":
    raise SystemExit(f"ADR-012 scheme-case URL escaping differed: {urls!r}")
if urls.get("relative") != "/todos/7?mode=edit&#038;from=hxx":
    raise SystemExit(f"ADR-012 relative URL escaping differed: {urls!r}")

rich = probe.get("richHtml")
if not isinstance(rich, dict) or set(rich) != {"post", "data", "custom", "customRestricted"}:
    raise SystemExit(f"ADR-012 rich HTML policies differed: {rich!r}")
for policy, value in rich.items():
    lowered = value.lower()
    if "<script" in lowered or "onmouseover=" in lowered or "javascript:" in lowered:
        raise SystemExit(f"ADR-012 {policy} policy retained executable markup: {value!r}")
if "<strong>kept</strong>" not in rich["post"]:
    raise SystemExit(f"ADR-012 post policy removed admitted markup: {rich['post']!r}")
if 'title="kept-title"' not in rich["custom"]:
    raise SystemExit(f"ADR-012 generated custom policy omitted its title attribute: {rich['custom']!r}")
if 'href="http://example.test"' not in rich["custom"]:
    raise SystemExit(f"ADR-012 generated custom policy omitted its HTTP protocol: {rich['custom']!r}")
if 'title=' in rich["customRestricted"] or 'href="http://example.test"' in rich["customRestricted"]:
    raise SystemExit(f"ADR-012 restricted policy mutation was not executed: {rich['customRestricted']!r}")
if 'href="//example.test"' not in rich["customRestricted"]:
    raise SystemExit(f"ADR-012 restricted policy did not retain exact native protocol filtering semantics: {rich['customRestricted']!r}")

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
if data.get("title") != json.loads(plan["restJson"]["encoded"])["title"]:
    raise SystemExit(f"ADR-012 REST data was silently mutated: {rest!r}")
if "</script" in rest.get("encoded", "").lower():
    raise SystemExit(f"ADR-012 REST JSON retained a closing tag: {rest!r}")
if probe.get("inlineStyle") != plan["inlineStyle"]:
    raise SystemExit(f"ADR-012 inline style lowering differed: {probe!r}")
if probe.get("stylesheet") != plan["stylesheet"]:
    raise SystemExit(f"ADR-012 stylesheet lowering differed: {probe!r}")
if probe.get("markupProvenance") != plan["markup"]:
    raise SystemExit(f"ADR-012 compiler-markup provenance differed: {probe!r}")
compiler_markup = probe.get("compilerMarkup", "")
if not compiler_markup.startswith('<article class="todo-card&quot; data-forged=&quot;true">'):
    raise SystemExit(f"ADR-012 generated compiler markup did not use contextual attribute lowering: {compiler_markup!r}")
if "&lt;script&gt;alert(&quot;markup&quot;)&lt;/script&gt;" not in compiler_markup:
    raise SystemExit(f"ADR-012 generated compiler markup did not use contextual text lowering: {compiler_markup!r}")
if 'href="https://example.test/todos/7?mode=edit&#038;from=hxx"' not in compiler_markup:
    raise SystemExit(f"ADR-012 generated compiler markup did not use contextual URL lowering: {compiler_markup!r}")

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
