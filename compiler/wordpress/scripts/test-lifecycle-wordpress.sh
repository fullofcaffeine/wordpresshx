#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mysql_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk051-mysql" \
  bash "${package_root}/scripts/run-lifecycle-lane.sh" mysql)"
mariadb_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk051-mariadb" \
  bash "${package_root}/scripts/run-lifecycle-lane.sh" mariadb)"
floor_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk051-floor" \
  bash "${package_root}/scripts/run-lifecycle-lane.sh" mysql-php74)"

python3 - "${mysql_result}" "${mariadb_result}" "${floor_result}" <<'PY'
import json
import sys

lanes = [json.loads(value) for value in sys.argv[1:]]
if [lane.get("databaseLane") for lane in lanes] != ["mysql", "mariadb", "mysql-php74"]:
    raise SystemExit("SDK-051 lifecycle fixture did not run primary and PHP-floor lanes")
if [lane.get("phpVersion") for lane in lanes] != ["8.4.23", "8.4.23", "7.4.33"]:
    raise SystemExit(f"SDK-051 lifecycle PHP matrix differed: {lanes!r}")
for lane in lanes:
    if lane.get("check") != "wordpresshx-sdk051-lifecycle-lane-v1":
        raise SystemExit(f"unexpected lifecycle lane identity: {lane!r}")
    if lane.get("standardPlugin") != {
        "activationIdempotency": "passed",
        "deactivationReactivation": "passed",
        "failedUpgradeCheckpoint": 2,
        "retryTarget": 3,
        "uninstallDeclaredOptions": "deleted",
    }:
        raise SystemExit(f"standard lifecycle evidence differed: {lane!r}")
    if lane.get("mustUsePlugin") != {
        "activationHooks": "absent",
        "normalLoadUpgradeTarget": 3,
        "removalPolicy": "retained-data",
        "uninstallFile": "absent",
    }:
        raise SystemExit(f"mu-plugin lifecycle evidence differed: {lane!r}")

print("SDK-051 WordPress 7.0 lifecycle passed on PHP 7.4/8.4 with MySQL and MariaDB")
PY
