#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
generated_root="${1:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk060}"

if [[ ! -f "${generated_root}/block-generation-manifest.json" ]]; then
  echo "usage: $0 <generated-block-root>" >&2
  exit 2
fi
if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
  exit 2
fi
for command_name in docker python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-060 WordPress block lane requires ${command_name}" >&2
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

plugin_slug="wordpresshx-sdk060-blocks"
container_root="/var/www/html/wp-content/plugins/${plugin_slug}"
"${compose[@]}" cp "${generated_root}" \
  "${wordpress_service}:${container_root}" >&2
"${compose[@]}" cp \
  "${package_root}/test/block-metadata-runtime/native-wordpress-oracle.php" \
  "${wordpress_service}:/opt/wordpresshx/native-wordpress-oracle.php" >&2

probe_json="$("${compose[@]}" exec --no-TTY "${wordpress_service}" \
  php /opt/wordpresshx/native-wordpress-oracle.php "${container_root}")"

result="$(python3 - "${repository_root}/docker/images.lock.json" \
  "${probe_json}" <<'PY'
import json
import sys

image_lock_path, probe_json = sys.argv[1:]
images = json.load(open(image_lock_path, encoding="utf-8"))["images"]
probe = json.loads(probe_json)
if probe.get("check") != "wordpresshx-sdk060-native-block-metadata-v1":
    raise SystemExit(f"unexpected SDK-060 probe: {probe!r}")
if probe.get("wordpressVersion") != "7.0" or probe.get("phpVersion") != "8.4.23":
    raise SystemExit(f"runtime identity drifted: {probe!r}")
if probe.get("profileId") != "wp70-release" or probe.get("dynamicRendered") is not True:
    raise SystemExit(f"profile or dynamic render proof drifted: {probe!r}")
blocks = probe.get("registeredBlocks", {})
if set(blocks) != {"wordpresshx/book-grid", "wordpresshx/callout"}:
    raise SystemExit(f"native registry contents drifted: {probe!r}")
expected_attributes = {
    "wordpresshx/book-grid": ["count", "showCover"],
    "wordpresshx/callout": ["message", "tone"],
}
core_attributes = ["lock", "metadata"]
for block_name, declared_attributes in expected_attributes.items():
    block = blocks[block_name]
    if block["declaredAttributeNames"] != declared_attributes:
        raise SystemExit(f"declared attributes drifted: {probe!r}")
    if block["coreInjectedAttributeNames"] != core_attributes:
        raise SystemExit(f"WordPress core attributes drifted: {probe!r}")
    if block["runtimeAttributeNames"] != declared_attributes + core_attributes:
        raise SystemExit(f"runtime attributes drifted: {probe!r}")
if blocks["wordpresshx/book-grid"]["hasRenderCallback"] is not True:
    raise SystemExit(f"dynamic callback is absent: {probe!r}")
if blocks["wordpresshx/callout"]["hasRenderCallback"] is not False:
    raise SystemExit(f"static block gained a callback: {probe!r}")
if any(block["apiVersion"] != 3 for block in blocks.values()):
    raise SystemExit(f"native API version drifted: {probe!r}")
print(json.dumps({
    "check": "wordpresshx-sdk060-real-wordpress-registration-v1",
    "databaseImage": images["mysql"]["reference"],
    "dynamicRendered": True,
    "outcome": "passed",
    "profileId": "wp70-release",
    "registeredBlocks": sorted(blocks),
    "wordpressImage": images["wordpress70Php84"]["reference"],
    "wordpressVersion": "7.0",
}, indent=2, sort_keys=True))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
