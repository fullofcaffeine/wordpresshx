#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="${package_root}/build/acme-books"
adapter_fixture_dir="${package_root}/build/acme-books-adapters"
correlation_fixture_dir="${package_root}/build/source-correlation/production-plugin"

if [[ ! -f "${fixture_dir}/acme-books.php" ]]; then
  echo "missing generated WordPress plugin fixture; run scripts/test.sh first" >&2
  exit 1
fi
if [[ ! -f "${adapter_fixture_dir}/acme-books-adapters.php" ]]; then
  echo "missing generated WordPress adapter fixture; run scripts/test.sh first" >&2
  exit 1
fi
if [[ ! -f "${correlation_fixture_dir}/source-correlation.php" ]]; then
  echo "missing generated source-correlation fixture; run scripts/test.sh first" >&2
  exit 1
fi

mysql_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk023" \
  bash "${package_root}/scripts/run-wordpress-lane.sh" mysql)"
mariadb_result="$(WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-sdk023" \
  bash "${package_root}/scripts/run-wordpress-lane.sh" mariadb)"

python3 - "${mysql_result}" "${mariadb_result}" <<'PY'
import json
import sys

lanes = [json.loads(value) for value in sys.argv[1:]]
if [lane.get("databaseLane") for lane in lanes] != ["mysql", "mariadb"]:
    raise SystemExit("SDK-023 WordPress adapter fixture did not run both database lanes")
expected_header = {
    "Name": "Acme Books",
    "Version": "0.0.0",
    "RequiresWP": "7.0",
    "RequiresPHP": "7.4",
    "TextDomain": "acme-books",
    "DomainPath": "/languages",
}
expected_adapter_header = {
    "Name": "Acme Books Adapters",
    "Version": "0.0.0",
    "RequiresWP": "7.0",
    "RequiresPHP": "7.4",
    "TextDomain": "acme-books-adapters",
    "DomainPath": "/languages",
}
expected_correlation_header = {
    "Name": "Source Correlation",
    "Version": "0.0.0",
    "RequiresWP": "7.0",
    "RequiresPHP": "7.4",
    "TextDomain": "source-correlation",
    "DomainPath": "/languages",
}
expected_adapter_methods = [
    "appendLabel",
    "filterTitle",
    "isInitialized",
    "normalizeTitle",
    "onInit",
    "registerBlocks",
    "registerRestRoutes",
    "renderSummary",
    "restBook",
    "restPermission",
]
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
    adapter_fixture = lane.get("adapterFixture")
    if not isinstance(adapter_fixture, dict):
        raise SystemExit(f"missing adapter evidence for {lane.get('databaseLane')}")
    adapter_activation = adapter_fixture.get("activation", {})
    adapter_probe = adapter_fixture.get("freshRequestProbe", {})
    if adapter_activation.get("header") != expected_adapter_header:
        raise SystemExit(f"WordPress adapter header discovery differed: {adapter_activation!r}")
    if adapter_activation.get("error") is not None:
        raise SystemExit(f"WordPress adapter activation failed: {adapter_activation!r}")
    if adapter_activation.get("outputBytes") != 0:
        raise SystemExit(f"adapter produced output during activation: {adapter_activation!r}")
    if adapter_activation.get("active") is not True or adapter_activation.get("booted") is not True:
        raise SystemExit(f"adapter activation proof failed: {adapter_activation!r}")
    if adapter_probe.get("active") is not True:
        raise SystemExit(f"adapter was not active on a fresh request: {adapter_probe!r}")
    if adapter_probe.get("class") != "Acme\\BooksAdapters\\PublicAdapters":
        raise SystemExit(f"adapter class was not native-shaped: {adapter_probe!r}")
    if adapter_probe.get("methods") != expected_adapter_methods:
        raise SystemExit(f"adapter reflection differed: {adapter_probe!r}")
    hooks = adapter_probe.get("hooks", {})
    if hooks != {
        "filterPriority": 12,
        "filteredTitle": "TYPED TITLE",
        "initPriority": 9,
        "initialized": True,
    }:
        raise SystemExit(f"native action/filter behavior differed: {adapter_probe!r}")
    if adapter_probe.get("exports") != {
        "labels": ["runtime", "verified"],
        "normalizeTitle": "RUNTIME TITLE",
    }:
        raise SystemExit(f"native public exports differed: {adapter_probe!r}")
    block = adapter_probe.get("block", {})
    if block.get("registered") is not True:
        raise SystemExit(f"dynamic block was not registered: {adapter_probe!r}")
    if block.get("markup") != '<section class="acme-books-summary">Typed &amp; Safe</section>':
        raise SystemExit(f"dynamic block render differed: {adapter_probe!r}")
    rest = adapter_probe.get("rest", {})
    if rest.get("permission") is not True or rest.get("routeRegistered") is not True:
        raise SystemExit(f"REST permission/registration proof failed: {adapter_probe!r}")
    if rest.get("positive") != {"data": {"id": 7, "title": "Book 7"}, "status": 200}:
        raise SystemExit(f"positive REST response differed: {adapter_probe!r}")
    if rest.get("negative") != {"code": "acme_books_invalid_id", "status": 400}:
        raise SystemExit(f"negative REST error differed: {adapter_probe!r}")
    correlation_fixture = lane.get("sourceCorrelationFixture")
    if not isinstance(correlation_fixture, dict):
        raise SystemExit(
            f"missing source-correlation evidence for {lane.get('databaseLane')}"
        )
    correlation_activation = correlation_fixture.get("activation", {})
    correlation_probe = correlation_fixture.get("freshRequestProbe", {})
    if correlation_activation.get("header") != expected_correlation_header:
        raise SystemExit(
            f"source-correlation header discovery differed: {correlation_activation!r}"
        )
    if correlation_activation.get("error") is not None:
        raise SystemExit(
            f"source-correlation activation failed: {correlation_activation!r}"
        )
    if correlation_activation.get("outputBytes") != 0:
        raise SystemExit(
            f"source-correlation plugin emitted activation output: {correlation_activation!r}"
        )
    if correlation_activation.get("active") is not True or correlation_activation.get("booted") is not True:
        raise SystemExit(
            f"source-correlation activation proof failed: {correlation_activation!r}"
        )
    if correlation_probe.get("active") is not True:
        raise SystemExit(
            f"source-correlation plugin was not active: {correlation_probe!r}"
        )
    if correlation_probe.get("class") != "Fixture\\Correlation\\FailureCallbacks":
        raise SystemExit(
            f"source-correlation class differed: {correlation_probe!r}"
        )
    if correlation_probe.get("blockRegistered") is not True:
        raise SystemExit(
            f"source-correlation block was not registered: {correlation_probe!r}"
        )
    if correlation_probe.get("restRouteRegistered") is not True:
        raise SystemExit(
            f"source-correlation REST route was not registered: {correlation_probe!r}"
        )
    expected_messages = {
        "hook": "hook failure",
        "rest": "rest failure",
        "render": "render failure",
        "private": "private failure",
    }
    failures = correlation_probe.get("failures")
    if not isinstance(failures, dict) or set(failures) != set(expected_messages):
        raise SystemExit(
            f"source-correlation failure inventory differed: {correlation_probe!r}"
        )
    for mode, expected_message in expected_messages.items():
        failure = failures[mode]
        if failure.get("class") != "RuntimeException":
            raise SystemExit(f"{mode} exception class differed: {failure!r}")
        if failure.get("message") != expected_message or failure.get("mode") != mode:
            raise SystemExit(f"{mode} exception identity differed: {failure!r}")
        if failure.get("logicalFile") != "source-correlation/includes/FailureCallbacks.php":
            raise SystemExit(f"{mode} exception path differed: {failure!r}")
        if failure.get("nativeStackPreserved") is not True:
            raise SystemExit(f"{mode} native stack was not preserved: {failure!r}")
        if not isinstance(failure.get("throwLine"), int) or failure["throwLine"] < 1:
            raise SystemExit(f"{mode} throw line was invalid: {failure!r}")
        if not isinstance(failure.get("traceFrameCount"), int) or failure["traceFrameCount"] < 1:
            raise SystemExit(f"{mode} native trace had no frames: {failure!r}")
print(json.dumps({
    "adapterPlugin": "acme-books-adapters/acme-books-adapters.php",
    "check": "wordpresshx-sdk023-sdk025-wordpress-runtime-v1",
    "databaseLanes": [lane["databaseLane"] for lane in lanes],
    "outcome": "passed",
    "plugin": "acme-books/acme-books.php",
    "profileId": "wp70-release",
    "sourceCorrelationPlugin": "source-correlation/source-correlation.php",
    "sourceCorrelationModes": ["hook", "private", "render", "rest"],
    "wordpressVersion": "7.0",
}, indent=2, sort_keys=True))
PY
