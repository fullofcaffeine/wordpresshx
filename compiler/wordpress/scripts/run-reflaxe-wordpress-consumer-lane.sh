#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compiler_root="${repository_root}/compiler/reflaxe.php"
compose_file="${repository_root}/docker/wordpress/compose.yml"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-reflaxe-wordpress.XXXXXX")"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-reflaxe-consumer}"
plugin="wordpresshx-reflaxe-module-proof/wordpresshx-reflaxe-module-proof.php"

if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
	echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
	exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
	echo "Docker is required for the reflaxe.php WordPress consumer proof" >&2
	exit 1
fi
docker info >/dev/null
docker compose version >/dev/null

compose=(
	docker compose
	--project-name "${project_name}"
	--file "${compose_file}"
	--profile mysql
)

cleanup() {
	"${compose[@]}" down --volumes --remove-orphans >&2
	rm -rf -- "${temporary_root}"
}
trap cleanup EXIT

graph_root="${temporary_root}/graph"
package_output="${temporary_root}/package"
(
	cd "${compiler_root}"
	haxe ../wordpress/test/reflaxe-wordpress-consumer/build.hxml \
		-D "reflaxe_php_output=${graph_root}"
)
python3 "${package_root}/scripts/package-reflaxe-module-graph.py" \
	--graph-root "${graph_root}" \
	--output-root "${package_output}"
python3 - "${package_output}/wordpresshx-reflaxe-module-proof.zip" "${temporary_root}/extracted" <<'PY'
import sys
import zipfile
from pathlib import Path, PurePosixPath

archive_path = Path(sys.argv[1])
output_root = Path(sys.argv[2])
with zipfile.ZipFile(archive_path) as archive:
    for info in archive.infolist():
        relative = PurePosixPath(info.filename)
        if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
            raise SystemExit(f"unsafe package entry: {info.filename}")
        destination = output_root.joinpath(*relative.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(archive.read(info))
PY

python3 "${repository_root}/scripts/docker/check-image-lock.py" >&2
"${compose[@]}" down --volumes --remove-orphans >&2
"${compose[@]}" pull mysql wordpress-mysql >&2
python3 "${repository_root}/scripts/wordpress/verify-distribution.py" >&2
"${compose[@]}" up --detach --wait --wait-timeout 180 mysql wordpress-mysql >&2

distribution_ready=false
for ((attempt = 1; attempt <= 90; attempt++)); do
	if "${compose[@]}" exec --no-TTY wordpress-mysql \
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

install_json="$("${compose[@]}" exec --no-TTY wordpress-mysql \
	php -d error_reporting=-1 -d display_errors=1 /opt/wordpresshx/install.php)"
python3 -c '
import json, sys
payload = json.load(sys.stdin)
expected = {"freshInstall": True, "installed": True, "seed": "sdk-090"}
if payload != expected:
    raise SystemExit(f"unexpected install result: {payload!r}")
' <<<"${install_json}"

"${compose[@]}" cp \
	"${temporary_root}/extracted/wordpresshx-reflaxe-module-proof" \
	"wordpress-mysql:/var/www/html/wp-content/plugins/wordpresshx-reflaxe-module-proof" >&2
for observer in activate probe remove; do
	"${compose[@]}" cp \
		"${package_root}/runtime/${observer}-reflaxe-consumer.php" \
		"wordpress-mysql:/opt/wordpresshx/${observer}-reflaxe-consumer.php" >&2
done

activation_json="$("${compose[@]}" exec --no-TTY wordpress-mysql \
	php -d error_reporting=-1 -d display_errors=1 \
	/opt/wordpresshx/activate-reflaxe-consumer.php "${plugin}")"
probe_json="$("${compose[@]}" exec --no-TTY wordpress-mysql \
	php -d error_reporting=-1 -d display_errors=1 \
	/opt/wordpresshx/probe-reflaxe-consumer.php "${plugin}")"
health_json="$("${compose[@]}" exec --no-TTY wordpress-mysql \
	php -d error_reporting=-1 -d display_errors=1 /opt/wordpresshx/health.php)"
removal_json="$("${compose[@]}" exec --no-TTY wordpress-mysql \
	php -d error_reporting=-1 -d display_errors=1 \
	/opt/wordpresshx/remove-reflaxe-consumer.php "${plugin}")"

python3 - \
	"${repository_root}/docker/images.lock.json" \
	"${install_json}" \
	"${activation_json}" \
	"${probe_json}" \
	"${health_json}" \
	"${removal_json}" <<'PY'
import json
import sys

lock_path, install_raw, activation_raw, probe_raw, health_raw, removal_raw = sys.argv[1:]
images = json.load(open(lock_path, encoding="utf-8"))["images"]
install = json.loads(install_raw)
activation = json.loads(activation_raw)
probe = json.loads(probe_raw)
health = json.loads(health_raw)
removal = json.loads(removal_raw)

expected_header = {
    "Name": "WordPressHx reflaxe.php module graph proof",
    "RequiresPHP": "7.4",
    "RequiresWP": "7.0",
    "Version": "0.0.0",
}
if activation != {
    "active": True,
    "error": None,
    "header": expected_header,
    "option": "ordinary-haxe",
    "outputBytes": 0,
    "plugin": "wordpresshx-reflaxe-module-proof/wordpresshx-reflaxe-module-proof.php",
}:
    raise SystemExit(f"unexpected activation observation: {activation!r}")
if probe != {
    "active": True,
    "nativeFunctionPresent": True,
    "option": "ordinary-haxe",
    "plugin": "wordpresshx-reflaxe-module-proof/wordpresshx-reflaxe-module-proof.php",
}:
    raise SystemExit(f"unexpected fresh-request observation: {probe!r}")
if health.get("wordpressVersion") != "7.0" or health.get("profileId") != "wp70-release":
    raise SystemExit(f"unexpected WordPress runtime identity: {health!r}")
if removal != {
    "deleteResult": True,
    "error": None,
    "inactive": True,
    "pluginDirectoryPresent": False,
    "pluginFilePresent": False,
}:
    raise SystemExit(f"unexpected removal observation: {removal!r}")

print(json.dumps({
    "check": "wordpresshx-reflaxe-wordpress-consumer-v1",
    "compilerAdapterScorecard": {
        "applicationBackendIr": False,
        "applicationPhp": False,
        "generatedNativeCall": "update_option",
        "outcome": "passed",
    },
    "packageInstallScorecard": {
        "activation": activation,
        "cleanFreshInstall": install,
        "outcome": "passed",
        "removal": removal,
    },
    "wordpressRuntimeAbiScorecard": {
        "freshRequest": probe,
        "outcome": "passed",
        "publicAbiExportClaimed": False,
        "runtime": health,
    },
    "databaseImage": images["mysql"]["reference"],
    "wordpressImage": images["wordpress70Php84"]["reference"],
}, indent=2, sort_keys=True))
PY

cleanup
trap - EXIT
