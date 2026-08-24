#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(cd "${package_root}/../.." && pwd)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
packages="${package_root}/build/lifecycle/packages"
runtime_root="${package_root}/build/lifecycle/runtime"
floor_lock="${package_root}/lifecycle-runtime.lock.json"
lane="${1:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk051}"

floor_lane=false
case "${lane}" in
  mysql)
    database_service="mysql"
    wordpress_service="wordpress-mysql"
    compose_profile="mysql"
    ;;
  mariadb)
    database_service="mariadb"
    wordpress_service="wordpress-mariadb"
    compose_profile="mariadb"
    ;;
  mysql-php74)
    database_service="mysql"
    wordpress_service=""
    compose_profile="mysql"
    floor_lane=true
    ;;
  *)
    echo "usage: $0 <mysql|mariadb|mysql-php74>" >&2
    exit 2
    ;;
esac
if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
  exit 2
fi
for archive in acme-lifecycle-v1.zip acme-lifecycle-v3.zip acme-lifecycle-mu-v3.zip; do
  if [[ ! -f "${packages}/${archive}" ]]; then
    echo "missing lifecycle package: ${archive}; run scripts/test.sh first" >&2
    exit 2
  fi
done
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the SDK-051 WordPress lifecycle fixture" >&2
  exit 1
fi
docker info >/dev/null
docker compose version >/dev/null

rm -rf -- "${runtime_root}"
mkdir -p "${runtime_root}/v1" "${runtime_root}/v3" "${runtime_root}/mu-v3"
python3 -m zipfile -e "${packages}/acme-lifecycle-v1.zip" "${runtime_root}/v1"
python3 -m zipfile -e "${packages}/acme-lifecycle-v3.zip" "${runtime_root}/v3"
python3 -m zipfile -e "${packages}/acme-lifecycle-mu-v3.zip" "${runtime_root}/mu-v3"

compose=(
  docker compose
  --project-name "${project_name}"
  --file "${compose_file}"
  --profile "${compose_profile}"
)
floor_container="${project_name}-wordpress74"
floor_volume="${project_name}-wordpress74-data"

cleanup() {
  if [[ "${floor_lane}" == "true" ]]; then
    docker rm -f -- "${floor_container}" >/dev/null 2>&1 || true
    docker volume rm -f -- "${floor_volume}" >/dev/null 2>&1 || true
  fi
  "${compose[@]}" down --volumes --remove-orphans >&2
}
trap cleanup EXIT

runtime_exec() {
  if [[ "${floor_lane}" == "true" ]]; then
    docker exec "${floor_container}" "$@"
  else
    "${compose[@]}" exec --no-TTY "${wordpress_service}" "$@"
  fi
}

runtime_copy() {
  local source="$1"
  local destination="$2"
  if [[ "${floor_lane}" == "true" ]]; then
    docker cp "${source}" "${floor_container}:${destination}"
  else
    "${compose[@]}" cp "${source}" "${wordpress_service}:${destination}"
  fi
}

python3 "${repository_root}/scripts/docker/check-image-lock.py" >&2
python3 "${package_root}/scripts/verify-lifecycle-runtime-lock.py" >&2
cleanup

if [[ "${floor_lane}" == "true" ]]; then
  "${compose[@]}" pull "${database_service}" >&2
  "${compose[@]}" up --detach --wait --wait-timeout 180 "${database_service}" >&2
  floor_image="$(jq -er '.image.reference' "${floor_lock}")"
  docker pull "${floor_image}" >&2
  docker volume create "${floor_volume}" >/dev/null
  docker run --detach \
    --name "${floor_container}" \
    --network "${project_name}_default" \
    --env WORDPRESS_DB_HOST=mysql:3306 \
    --env WORDPRESS_DB_NAME=wordpresshx \
    --env WORDPRESS_DB_USER=wordpresshx \
    --env WORDPRESS_DB_PASSWORD=wordpresshx-test-only \
    --env WORDPRESS_DEBUG=1 \
    --mount "type=volume,src=${floor_volume},dst=/var/www/html" \
    --mount "type=bind,src=${repository_root}/docker/wordpress/install.php,dst=/opt/wordpresshx/install.php,readonly" \
    "${floor_image}" >/dev/null
  config_ready=false
  for ((attempt = 1; attempt <= 90; attempt++)); do
    if runtime_exec test -f /var/www/html/wp-config.php; then
      config_ready=true
      break
    fi
    sleep 1
  done
  if [[ "${config_ready}" != "true" ]]; then
    echo "PHP-floor WordPress container did not create wp-config.php" >&2
    exit 1
  fi
  floor_source_json="$(python3 "${package_root}/scripts/prepare-wordpress-floor.py")"
  floor_source="$(jq -er '.path' <<<"${floor_source_json}")"
  runtime_exec cp -f -- /var/www/html/wp-config.php /tmp/wordpresshx-wp-config.php
  runtime_exec find /var/www/html -mindepth 1 -maxdepth 1 -exec rm -rf -- '{}' +
  runtime_exec cp -f -- /tmp/wordpresshx-wp-config.php /var/www/html/wp-config.php
  runtime_copy "${floor_source}/." /var/www/html >&2
  runtime_copy "${package_root}/runtime/verify-mounted-wordpress.php" /opt/wordpresshx/verify-mounted-wordpress.php >&2
  floor_distribution="$(runtime_exec php /opt/wordpresshx/verify-mounted-wordpress.php \
    7.0 7.4.33 3951 fc90e36ee34bb3bb50147222c3b281d4fcc06a3837b3aaca5516a13e3b1ec857)"
  wordpress_image="${floor_image}"
  php_version="$(jq -er '.phpVersion' <<<"${floor_distribution}")"
else
  "${compose[@]}" pull "${database_service}" "${wordpress_service}" >&2
  python3 "${repository_root}/scripts/wordpress/verify-distribution.py" >&2
  "${compose[@]}" up --detach --wait --wait-timeout 180 \
    "${database_service}" "${wordpress_service}" >&2
  distribution_ready=false
  for ((attempt = 1; attempt <= 90; attempt++)); do
    if runtime_exec test -f /var/www/html/wp-includes/version.php; then
      distribution_ready=true
      break
    fi
    sleep 1
  done
  if [[ "${distribution_ready}" != "true" ]]; then
    echo "WordPress distribution did not finish materializing" >&2
    exit 1
  fi
  wordpress_image="$(jq -er '.images.wordpress70Php84.reference' "${repository_root}/docker/images.lock.json")"
  php_version="$(runtime_exec php -r 'echo PHP_VERSION;')"
fi

install_json="$(runtime_exec php /opt/wordpresshx/install.php)"
python3 -c '
import json, sys
payload = json.load(sys.stdin)
if payload != {"freshInstall": True, "installed": True, "seed": "sdk-090"}:
    raise SystemExit(f"unexpected install result: {payload!r}")
' <<<"${install_json}"

runtime_copy "${package_root}/runtime/lifecycle-command.php" /opt/wordpresshx/lifecycle-command.php >&2
runtime_copy "${package_root}/runtime/lifecycle-state.php" /opt/wordpresshx/lifecycle-state.php >&2
runtime_copy "${runtime_root}/v1/acme-lifecycle" /var/www/html/wp-content/plugins/acme-lifecycle >&2

plugin="acme-lifecycle/acme-lifecycle.php"
activate_v1="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php activate "${plugin}")"
probe_v1="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php probe "${plugin}")"
deactivate_v1="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php deactivate "${plugin}")"
reactivate_v1="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php activate "${plugin}")"
probe_reactivated_v1="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php probe "${plugin}")"

runtime_exec rm -rf -- /var/www/html/wp-content/plugins/acme-lifecycle >&2
runtime_copy "${runtime_root}/v3/acme-lifecycle" /var/www/html/wp-content/plugins/acme-lifecycle >&2

set +e
failed_upgrade_output="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php fail-load-v3 "${plugin}" 2>&1)"
failed_upgrade_status=$?
set -e
if (( failed_upgrade_status == 0 )) || [[ "${failed_upgrade_output}" != *"intentional lifecycle migration failure at schema 3"* ]]; then
  echo "version-3 lifecycle migration did not fail at the intended checkpoint" >&2
  printf '%s\n' "${failed_upgrade_output}" >&2
  exit 1
fi

checkpoint_state="$(runtime_exec php /opt/wordpresshx/lifecycle-state.php acme_lifecycle)"
probe_v3="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php probe "${plugin}")"
deactivate_v3="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php deactivate "${plugin}")"
uninstall_v3="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php uninstall "${plugin}")"
uninstalled_state="$(runtime_exec php /opt/wordpresshx/lifecycle-state.php acme_lifecycle)"

runtime_exec mkdir -p -- /var/www/html/wp-content/mu-plugins >&2
runtime_copy "${runtime_root}/mu-v3/acme-lifecycle-mu.php" /var/www/html/wp-content/mu-plugins/acme-lifecycle-mu.php >&2
runtime_copy "${runtime_root}/mu-v3/acme-lifecycle-mu" /var/www/html/wp-content/mu-plugins/acme-lifecycle-mu >&2
mu_probe="$(runtime_exec php /opt/wordpresshx/lifecycle-command.php mu-probe acme-lifecycle-mu.php)"
runtime_exec rm -rf -- /var/www/html/wp-content/mu-plugins/acme-lifecycle-mu \
  /var/www/html/wp-content/mu-plugins/acme-lifecycle-mu.php >&2
mu_removed_state="$(runtime_exec php /opt/wordpresshx/lifecycle-state.php acme_lifecycle_mu)"

result="$(python3 - "${lane}" "${repository_root}/docker/images.lock.json" "${wordpress_image}" "${php_version}" \
  "${activate_v1}" "${probe_v1}" "${deactivate_v1}" "${reactivate_v1}" \
  "${probe_reactivated_v1}" "${checkpoint_state}" "${probe_v3}" "${deactivate_v3}" \
  "${uninstall_v3}" "${uninstalled_state}" "${mu_probe}" "${mu_removed_state}" <<'PY'
import json
import sys

(
    lane,
    lock_path,
    wordpress_image,
    php_version,
    activate_v1,
    probe_v1,
    deactivate_v1,
    reactivate_v1,
    probe_reactivated_v1,
    checkpoint_state,
    probe_v3,
    deactivate_v3,
    uninstall_v3,
    uninstalled_state,
    mu_probe,
    mu_removed_state,
) = sys.argv[1:]

values = {
    name: json.loads(value)
    for name, value in {
        "activateV1": activate_v1,
        "probeV1": probe_v1,
        "deactivateV1": deactivate_v1,
        "reactivateV1": reactivate_v1,
        "probeReactivatedV1": probe_reactivated_v1,
        "checkpointState": checkpoint_state,
        "probeV3": probe_v3,
        "deactivateV3": deactivate_v3,
        "uninstallV3": uninstall_v3,
        "uninstalledState": uninstalled_state,
        "muProbe": mu_probe,
        "muRemovedState": mu_removed_state,
    }.items()
}

if values["activateV1"] != {"active": True, "outputBytes": 0}:
    raise SystemExit(f"v1 activation differed: {values['activateV1']!r}")
expected_v1 = {
    "active": True,
    "classLoaded": True,
    "hooks": {"activation": True, "deactivation": True, "upgrade": True},
    "migrationRuns": [1, None, None],
    "schemaVersion": 1,
}
if values["probeV1"] != expected_v1 or values["probeReactivatedV1"] != expected_v1:
    raise SystemExit(f"v1 idempotency differed: {values!r}")
if values["deactivateV1"] != {"active": False} or values["reactivateV1"] != {"active": True, "outputBytes": 0}:
    raise SystemExit(f"v1 deactivate/reactivate differed: {values!r}")
if values["checkpointState"] != {"migrationRuns": [1, 1, None], "schemaVersion": 2}:
    raise SystemExit(f"failed migration checkpoint differed: {values['checkpointState']!r}")
expected_v3 = {
    "active": True,
    "classLoaded": True,
    "hooks": {"activation": True, "deactivation": True, "upgrade": True},
    "migrationRuns": [1, 1, 1],
    "schemaVersion": 3,
}
if values["probeV3"] != expected_v3:
    raise SystemExit(f"retry completion differed: {values['probeV3']!r}")
if values["deactivateV3"] != {"active": False} or values["uninstallV3"] != {"uninstalled": True}:
    raise SystemExit(f"v3 native uninstall path differed: {values!r}")
if values["uninstalledState"] != {"migrationRuns": [None, None, None], "schemaVersion": None}:
    raise SystemExit(f"declared uninstall data survived: {values['uninstalledState']!r}")
expected_mu = {
    "active": None,
    "classLoaded": True,
    "hooks": {"activation": False, "deactivation": False, "upgrade": True},
    "migrationRuns": [1, 1, 1],
    "schemaVersion": 3,
}
if values["muProbe"] != expected_mu:
    raise SystemExit(f"mu-plugin lifecycle differed: {values['muProbe']!r}")
if values["muRemovedState"] != {"migrationRuns": [1, 1, 1], "schemaVersion": 3}:
    raise SystemExit(f"mu-plugin retained-data policy differed: {values['muRemovedState']!r}")

images = json.load(open(lock_path, encoding="utf-8"))["images"]
database_key = "mariadb" if lane == "mariadb" else "mysql"
print(json.dumps({
    "check": "wordpresshx-sdk051-lifecycle-lane-v1",
    "databaseImage": images[database_key]["reference"],
    "databaseLane": lane,
    "phpVersion": php_version,
    "standardPlugin": {
        "activationIdempotency": "passed",
        "deactivationReactivation": "passed",
        "failedUpgradeCheckpoint": 2,
        "retryTarget": 3,
        "uninstallDeclaredOptions": "deleted",
    },
    "mustUsePlugin": {
        "activationHooks": "absent",
        "normalLoadUpgradeTarget": 3,
        "removalPolicy": "retained-data",
        "uninstallFile": "absent",
    },
    "wordpressImage": wordpress_image,
}, indent=2, sort_keys=True))
PY
)"

cleanup
trap - EXIT
printf '%s\n' "${result}"
