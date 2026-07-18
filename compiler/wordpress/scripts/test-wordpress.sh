#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="${package_root}/build/acme-books"

if [[ ! -f "${fixture_dir}/acme-books.php" ]]; then
  echo "missing generated WordPress plugin fixture; run scripts/test.sh first" >&2
  exit 1
fi

mysql_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk022" \
  bash "${package_root}/scripts/run-wordpress-lane.sh" mysql)"
mariadb_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk022" \
  bash "${package_root}/scripts/run-wordpress-lane.sh" mariadb)"

python3 - "${mysql_result}" "${mariadb_result}" <<'PY'
import json
import sys

lanes = [json.loads(value) for value in sys.argv[1:]]
if [lane.get("databaseLane") for lane in lanes] != ["mysql", "mariadb"]:
    raise SystemExit("SDK-022 WordPress fixture did not run both database lanes")
expected_header = {
    "Name": "Acme Books",
    "Version": "0.0.0",
    "RequiresWP": "7.0",
    "RequiresPHP": "7.4",
    "TextDomain": "acme-books",
    "DomainPath": "/languages",
}
for lane in lanes:
    fixture = lane.get("pluginFixture")
    if not isinstance(fixture, dict):
        raise SystemExit(f"missing plugin evidence for {lane.get('databaseLane')}")
    activation = fixture.get("activation", {})
    probe = fixture.get("freshRequestProbe", {})
    if activation.get("header") != expected_header:
        raise SystemExit(f"WordPress header discovery differed: {activation!r}")
    if activation.get("error") is not None:
        raise SystemExit(f"WordPress activation failed: {activation!r}")
    if activation.get("outputBytes") != 0:
        raise SystemExit(f"plugin produced output during activation: {activation!r}")
    for field in ("active", "booted"):
        if activation.get(field) is not True or probe.get(field) is not True:
            raise SystemExit(f"plugin {field} proof failed: {fixture!r}")
    if probe.get("class") != "Acme\\Books\\Bootstrap":
        raise SystemExit(f"bootstrap class was not native-shaped: {probe!r}")
    if probe.get("methods") != ["boot", "isBooted"]:
        raise SystemExit(f"bootstrap reflection differed: {probe!r}")
    if probe.get("bootstrapFile") != "acme-books/includes/Bootstrap.php":
        raise SystemExit(f"bootstrap file path differed: {probe!r}")
print(json.dumps({
    "check": "wordpresshx-sdk022-wordpress-plugin-v1",
    "databaseLanes": [lane["databaseLane"] for lane in lanes],
    "outcome": "passed",
    "plugin": "acme-books/acme-books.php",
    "profileId": "wp70-release",
    "wordpressVersion": "7.0",
}, indent=2, sort_keys=True))
PY
