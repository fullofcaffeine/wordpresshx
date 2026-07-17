#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mysql_result="$(bash "${repository_root}/scripts/wordpress/run-harness.sh" mysql)"
mariadb_result="$(bash "${repository_root}/scripts/wordpress/run-harness.sh" mariadb)"

python3 - "${mysql_result}" "${mariadb_result}" <<'PY'
import json
import sys

results = [json.loads(value) for value in sys.argv[1:]]
if [result["databaseLane"] for result in results] != ["mysql", "mariadb"]:
    raise SystemExit("runtime matrix did not return the two exact lanes")
if not all(result["freshReset"] == "passed" for result in results):
    raise SystemExit("a runtime lane did not prove a fresh reset")
if not all(result["httpFrontend"] == "passed" for result in results):
    raise SystemExit("a runtime lane did not pass the HTTP frontend check")
if not all(result["install"]["freshInstall"] is True for result in results):
    raise SystemExit("a runtime lane reused an installed database")
print(json.dumps({
    "check": "wordpresshx-wordpress-runtime-matrix-v1",
    "lanes": results,
    "outcome": "passed",
}, indent=2, sort_keys=True))
PY
