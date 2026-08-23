#!/usr/bin/env python3
"""Exercise the generated ADR-015 bundle and its native PHP/JS facades."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def checked_run(
    command: list[str],
    environment: dict[str, str],
    expected: int = 0,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != expected:
        raise AssertionError(
            f"command exited {result.returncode}, expected {expected}\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )
    return result


def verify_bundle(stage: Path) -> dict[str, object]:
    bundle_path = stage / "acme-calendar.bundle.json"
    bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
    digest = bundle.pop("bundleDigest")
    if digest != sha256(canonical(bundle)):
        raise AssertionError("bundle root digest is stale")
    bundle["bundleDigest"] = digest
    records = bundle["records"]
    for name in ("contract", "capability", "review", "ownership"):
        record = records[name]
        path = stage / record["path"]
        if not path.is_file() or sha256(path.read_bytes()) != record["sha256"]:
            raise AssertionError(f"bundle record {name} is stale")
    owned = {
        item["path"]: (item["contentSha256"], item["sizeBytes"])
        for item in json.loads(
            (stage / records["ownership"]["path"]).read_text(encoding="utf-8")
        )["files"]
    }
    generated = {
        item["path"]: (item["sha256"], item["sizeBytes"])
        for item in bundle["generatedFiles"]
    }
    if generated != owned:
        raise AssertionError("bundle and ownership file sets differ")
    for relative, (digest, size) in generated.items():
        path = stage / relative
        if not path.is_file():
            raise AssertionError(f"bundle file is absent: {relative}")
        data = path.read_bytes()
        if len(data) != size or sha256(data) != digest:
            raise AssertionError(f"bundle file is stale: {relative}")
    return bundle


PHP_PROBE = r'''
require $argv[1];
$plugin = $argv[2];
$scenario = $argv[3];
try {
    $limit = $scenario === 'provider-error' ? -1 : 2;
    $titles = \WordPressHx\Adoption\AcmeCalendar\Facade::listEventTitles($plugin, $limit);
    echo json_encode(['outcome' => 'available', 'titles' => $titles], JSON_THROW_ON_ERROR), "\n";
} catch (Throwable $failure) {
    $previous = $failure->getPrevious();
    echo json_encode([
        'outcome' => 'unavailable',
        'message' => $failure->getMessage(),
        'previous' => $previous === null ? null : get_class($previous),
    ], JSON_THROW_ON_ERROR), "\n";
}
'''


JS_PROBE = r'''
const { loadExactProvider } = await import(process.argv[1]);
const root = process.argv[2];
const generation = process.argv[3];
const scenario = process.argv[4];
try {
  const facade = await loadExactProvider(root, generation);
  const count = scenario === "provider-error" ? -1 : 3;
  const label = facade.formatLabel(count);
  const badge = facade.renderBadge({ count, label });
  process.stdout.write(JSON.stringify({ outcome: "available", label, badge }) + "\n");
} catch (failure) {
  process.stdout.write(JSON.stringify({ outcome: "unavailable", message: failure.message }) + "\n");
}
'''


def php_case(
    php: str,
    facade: Path,
    plugin: Path,
    scenario: str,
    sentinel: Path,
) -> dict[str, object]:
    environment = os.environ.copy()
    environment["WORDPRESSHX_ADOPTION_POISON_SENTINEL"] = str(sentinel)
    result = checked_run(
        [php, "-r", PHP_PROBE, str(facade), str(plugin), scenario], environment
    )
    return json.loads(result.stdout)


def js_case(
    node: str,
    facade: Path,
    provider: Path,
    generation: str,
    scenario: str,
    sentinel: Path,
) -> dict[str, object]:
    environment = os.environ.copy()
    environment["WORDPRESSHX_ADOPTION_POISON_SENTINEL"] = str(sentinel)
    result = checked_run(
        [
            node,
            "--input-type=module",
            "--eval",
            JS_PROBE,
            str(facade.resolve().as_uri()),
            str(provider),
            generation,
            scenario,
        ],
        environment,
    )
    return json.loads(result.stdout)


def replace_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise AssertionError(f"expected one replacement in {path.name}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit("usage: test-native-provider.py <stage> <work> <php> <node>")
    stage = Path(sys.argv[1]).resolve()
    work = Path(sys.argv[2]).resolve()
    work.mkdir(parents=True, exist_ok=False)
    php = sys.argv[3]
    node = sys.argv[4]
    bundle = verify_bundle(stage)
    contract = json.loads(
        (stage / bundle["records"]["contract"]["path"]).read_text(encoding="utf-8")
    )
    if contract["provider"]["artifactSha256"] != bundle["provider"]["artifactSha256"]:
        raise AssertionError("runtime consumer did not verify the bundle provider root")

    php_facade = stage / "generated/adoption/acme-calendar/php/acme-calendar-facade.php"
    browser_facade = stage / "generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs"
    plugin = ROOT / "fixtures/adoption-contract/inputs/plugin.php"
    php_sentinel = work / "php-provider-executed"
    outcome = php_case(php, php_facade, plugin, "success", php_sentinel)
    if outcome != {
        "outcome": "available",
        "titles": ["Provider event one", "Provider event two"],
    } or php_sentinel.read_text(encoding="utf-8") != "provider code executed":
        raise AssertionError(f"PHP native provider success mismatch: {outcome}")
    failure = php_case(php, php_facade, plugin, "provider-error", php_sentinel)
    if failure != {
        "outcome": "unavailable",
        "message": "provider-call-failed",
        "previous": "InvalidArgumentException",
    }:
        raise AssertionError(f"PHP provider exception mismatch: {failure}")
    absent = php_case(php, php_facade, work / "missing.php", "absence", php_sentinel)
    if absent["message"] != "provider-absent":
        raise AssertionError(f"PHP required absence failed open: {absent}")

    wrong_plugin = work / "wrong-plugin.php"
    wrong_plugin.write_bytes(plugin.read_bytes() + b"\n")
    before_wrong = php_sentinel.read_bytes()
    wrong = php_case(php, php_facade, wrong_plugin, "wrong-artifact", php_sentinel)
    if wrong["message"] != "wrong-provider-artifact" or php_sentinel.read_bytes() != before_wrong:
        raise AssertionError(f"PHP wrong artifact executed or passed: {wrong}")

    wrong_version_facade = work / "wrong-version-facade.php"
    wrong_version_facade.write_bytes(php_facade.read_bytes())
    replace_exact(
        wrong_version_facade,
        "private const VERSION = '2.4.1';",
        "private const VERSION = '2.4.2';",
    )
    before_wrong_version = php_sentinel.read_bytes()
    wrong_version = php_case(
        php, wrong_version_facade, plugin, "wrong-version", php_sentinel
    )
    if (
        wrong_version["message"] != "wrong-provider-version"
        or php_sentinel.read_bytes() != before_wrong_version
    ):
        raise AssertionError(f"PHP wrong version executed or passed: {wrong_version}")

    missing_symbol_plugin = work / "missing-symbol-plugin.php"
    missing_symbol_plugin.write_text(
        plugin.read_text(encoding="utf-8").replace(
            "function list_events(", "function missing_list_events(", 1
        ),
        encoding="utf-8",
    )
    missing_symbol_facade = work / "missing-symbol-facade.php"
    missing_symbol_facade.write_bytes(php_facade.read_bytes())
    replace_exact(
        missing_symbol_facade,
        hashlib.sha256(plugin.read_bytes()).hexdigest(),
        hashlib.sha256(missing_symbol_plugin.read_bytes()).hexdigest(),
    )
    missing_symbol = php_case(
        php,
        missing_symbol_facade,
        missing_symbol_plugin,
        "missing-symbol",
        work / "php-missing-symbol-executed",
    )
    if missing_symbol["message"] != "required-provider-symbol-missing":
        raise AssertionError(f"PHP missing symbol failed open: {missing_symbol}")

    provider = work / "browser-provider"
    provider.mkdir()
    for name in ("index.js", "package-metadata.json"):
        shutil.copyfile(ROOT / "fixtures/adoption-contract/inputs" / name, provider / name)
    shutil.copyfile(provider / "package-metadata.json", provider / "package.json")
    js_sentinel = work / "js-provider-executed"
    js_success = js_case(
        node, browser_facade, provider, "one", "success", js_sentinel
    )
    if js_success != {
        "outcome": "available",
        "label": "3 calendar events",
        "badge": {
            "kind": "acme-calendar-badge",
            "count": 3,
            "label": "3 calendar events",
        },
    } or js_sentinel.read_text(encoding="utf-8") != "browser provider code executed\n":
        raise AssertionError(f"browser native provider success mismatch: {js_success}")
    js_error = js_case(
        node, browser_facade, provider, "two", "provider-error", js_sentinel
    )
    if js_error != {"outcome": "unavailable", "message": "count must be non-negative"}:
        raise AssertionError(f"browser provider exception mismatch: {js_error}")
    missing_provider = work / "missing-browser-provider"
    missing_provider.mkdir()
    js_absent = js_case(
        node, browser_facade, missing_provider, "three", "absence", js_sentinel
    )
    if js_absent != {"outcome": "unavailable", "message": "provider-absent"}:
        raise AssertionError(f"browser optional absence mismatch: {js_absent}")

    wrong_version_browser_facade = work / "wrong-version-browser-facade.mjs"
    wrong_version_browser_facade.write_bytes(browser_facade.read_bytes())
    replace_exact(
        wrong_version_browser_facade,
        'version: "2.4.1",',
        'version: "2.4.2",',
    )
    before_js_wrong_version = js_sentinel.read_bytes()
    js_wrong_version = js_case(
        node,
        wrong_version_browser_facade,
        provider,
        "four",
        "wrong-version",
        js_sentinel,
    )
    if (
        js_wrong_version["message"] != "wrong-provider-version"
        or js_sentinel.read_bytes() != before_js_wrong_version
    ):
        raise AssertionError(
            f"browser wrong version executed or passed: {js_wrong_version}"
        )

    missing_symbol_provider = work / "missing-symbol-browser-provider"
    shutil.copytree(provider, missing_symbol_provider)
    missing_symbol_module = missing_symbol_provider / "index.js"
    missing_symbol_module.write_text(
        missing_symbol_module.read_text(encoding="utf-8").replace(
            "export function formatCalendarLabel(",
            "export function missingFormatCalendarLabel(",
            1,
        ),
        encoding="utf-8",
    )
    missing_symbol_browser_facade = work / "missing-symbol-browser-facade.mjs"
    missing_symbol_browser_facade.write_bytes(browser_facade.read_bytes())
    replace_exact(
        missing_symbol_browser_facade,
        hashlib.sha256((provider / "index.js").read_bytes()).hexdigest(),
        hashlib.sha256(missing_symbol_module.read_bytes()).hexdigest(),
    )
    js_missing_symbol = js_case(
        node,
        missing_symbol_browser_facade,
        missing_symbol_provider,
        "five",
        "missing-symbol",
        work / "js-missing-symbol-executed",
    )
    if js_missing_symbol["message"] != "required-provider-symbol-missing":
        raise AssertionError(f"browser missing symbol failed open: {js_missing_symbol}")

    before_js_wrong = js_sentinel.read_bytes()
    (provider / "index.js").write_bytes((provider / "index.js").read_bytes() + b"\n")
    js_wrong = js_case(
        node, browser_facade, provider, "six", "wrong-artifact", js_sentinel
    )
    if js_wrong["message"] != "wrong-provider-artifact" or js_sentinel.read_bytes() != before_js_wrong:
        raise AssertionError(f"browser wrong artifact executed or passed: {js_wrong}")

    print("ADR-015 bundle root and generated PHP/JS native provider facades passed")


if __name__ == "__main__":
    main()
