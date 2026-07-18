#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
plugin_root="${1:-}"
plan_path="${2:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk033}"

if [[ ! -d "${plugin_root}" || ! -f "${plan_path}" ]]; then
  echo "usage: $0 <generated-plugin-root> <asset-plan.json>" >&2
  exit 2
fi
if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
  exit 2
fi
for command_name in docker python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-033 WordPress asset lane requires ${command_name}" >&2
    exit 1
  fi
done
docker info >/dev/null
docker compose version >/dev/null

IFS='|' read -r plugin_slug script_handle text_domain expected_version < <(
  python3 - "${plan_path}" <<'PY'
import json
import sys

plan = json.load(open(sys.argv[1], encoding="utf-8"))
print("|".join([
    plan["plugin"]["slug"],
    plan["script"]["handle"],
    plan["translations"]["domain"],
    plan["script"]["productionVersion"],
]))
PY
)
for identity in "${plugin_slug}" "${script_handle}" "${text_domain}"; do
  if [[ ! "${identity}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "unsafe generated WordPress identity: ${identity}" >&2
    exit 2
  fi
done
if [[ ! "${expected_version}" =~ ^[0-9a-f]{20}$ ]]; then
  echo "unsafe generated asset version: ${expected_version}" >&2
  exit 2
fi
if [[ ! -f "${plugin_root}/${plugin_slug}.php" ]]; then
  echo "generated plugin entry is absent: ${plugin_slug}.php" >&2
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
"${compose[@]}" up --detach --wait --wait-timeout 180 \
  mysql "${wordpress_service}" >&2

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

"${compose[@]}" cp "${plugin_root}" \
  "${wordpress_service}:/var/www/html/wp-content/plugins/${plugin_slug}" >&2
"${compose[@]}" cp "${package_root}/test/assets-runtime/probe-assets.php" \
  "${wordpress_service}:/opt/wordpresshx/probe-assets.php" >&2

probe_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/probe-assets.php \
  "${plugin_slug}" "${script_handle}" "${text_domain}" "${expected_version}")"

result="$(python3 - "${plan_path}" "${repository_root}/docker/images.lock.json" \
  "${probe_json}" <<'PY'
import json
import sys

plan_path, image_lock_path, probe_json = sys.argv[1:]
plan = json.load(open(plan_path, encoding="utf-8"))
images = json.load(open(image_lock_path, encoding="utf-8"))["images"]
probe = json.loads(probe_json)
expected_asset = {
    "dependencies": plan["script"]["dependencies"],
    "version": plan["script"]["productionVersion"],
}
if probe.get("check") != "wordpresshx-sdk033-wordpress-assets-v1":
    raise SystemExit(f"unexpected SDK-033 probe: {probe!r}")
if probe.get("asset") != expected_asset:
    raise SystemExit(f"native asset registration drifted: {probe!r}")
if probe.get("wordpressVersion") != "7.0" or probe.get("phpVersion") != "8.4.23":
    raise SystemExit(f"runtime identity drifted: {probe!r}")
if probe.get("profileId") != "wp70-release":
    raise SystemExit(f"profile identity drifted: {probe!r}")
if probe.get("enqueue") != {
    "handle": plan["script"]["handle"],
    "queued": True,
    "registered": True,
    "scriptTagVersioned": True,
}:
    raise SystemExit(f"native enqueue proof drifted: {probe!r}")
if probe.get("translations") != {
    "domain": plan["translations"]["domain"],
    "loaded": True,
    "path": plan["translations"]["relativePath"],
    "printedBeforeScript": True,
}:
    raise SystemExit(f"native translation proof drifted: {probe!r}")
order = probe.get("dependencyOrder", {})
direct_and_final = order.get("directAndFinal", [])
if order.get("directBeforeFinal") is not True:
    raise SystemExit(f"dependency order failed: {probe!r}")
if not direct_and_final or direct_and_final[-1] != plan["script"]["handle"]:
    raise SystemExit(f"final handle is not last: {probe!r}")
if set(direct_and_final[:-1]) != set(plan["script"]["dependencies"]):
    raise SystemExit(f"direct handle order omitted a dependency: {probe!r}")
if order.get("resolvedHandleCount", 0) <= len(plan["script"]["dependencies"]):
    raise SystemExit(f"transitive dependency graph was not resolved: {probe!r}")
print(json.dumps({
    "check": "wordpresshx-sdk033-real-wordpress-assets-v1",
    "databaseImage": images["mysql"]["reference"],
    "databaseLane": "mysql",
    "dependencyOrder": direct_and_final,
    "outcome": "passed",
    "profileId": "wp70-release",
    "scriptHandle": plan["script"]["handle"],
    "translationDomain": plan["translations"]["domain"],
    "wordpressImage": images["wordpress70Php84"]["reference"],
    "wordpressVersion": "7.0",
}, indent=2, sort_keys=True))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
