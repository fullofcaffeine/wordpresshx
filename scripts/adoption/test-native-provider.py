#!/usr/bin/env python3
"""Exercise captured ADR-015 facades, providers, and Haxe target adapters."""

from __future__ import annotations

import base64
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONTENT_ROOT = Path("generated/adoption/acme-calendar")
BUNDLE_PATH = CONTENT_ROOT / "adoption.bundle.json"


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


@dataclass(frozen=True)
class VerifiedBundle:
    digest: str
    members: dict[str, bytes]

    def content(self, relative: str) -> bytes:
        value = self.members.get(relative)
        if value is None:
            raise AssertionError(f"verified bundle omits {relative}")
        return value


def verify_bundle(stage: Path) -> VerifiedBundle:
    bundle_path = stage / BUNDLE_PATH
    bundle_bytes = bundle_path.read_bytes()
    bundle = json.loads(bundle_bytes)
    if bundle_bytes != canonical(bundle) + b"\n":
        raise AssertionError("bundle root is not canonical")
    digest = bundle.pop("bundleDigest")
    if digest != sha256(canonical(bundle)):
        raise AssertionError("bundle root digest is stale")
    bundle["bundleDigest"] = digest
    members: dict[str, bytes] = {}
    roles: set[str] = set()
    for record in bundle["members"]:
        relative = record["path"]
        if relative in members or record["role"] in roles:
            raise AssertionError("bundle paths and semantic roles must be unique")
        path = stage / relative
        data = path.read_bytes()
        if len(data) != record["sizeBytes"] or sha256(data) != record["sha256"]:
            raise AssertionError(f"bundle member is stale: {relative}")
        members[relative] = data
        roles.add(record["role"])
    expected_roles = {
        "capability",
        "contract",
        "haxe-facade",
        "provider-artifact",
        "review",
    }
    if roles != expected_roles:
        raise AssertionError("bundle semantic role set is incomplete")
    for relative in (
        f"{CONTENT_ROOT.as_posix()}/browser/acme-calendar-facade.mjs",
        f"{CONTENT_ROOT.as_posix()}/php/acme-calendar-facade.php",
    ):
        members[relative] = (stage / relative).read_bytes()
    manifest_bytes = (stage / "generated/_GeneratedFiles.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    manifest_digest = manifest.pop("manifestDigest")
    if manifest_digest != sha256(canonical(manifest)):
        raise AssertionError("ownership manifest self digest is stale")
    owned = {
        value["path"]: (value["contentSha256"], value["sizeBytes"])
        for value in manifest["files"]
    }
    expected_owned = {
        relative: (sha256(data), len(data)) for relative, data in members.items()
    }
    expected_owned[BUNDLE_PATH.as_posix()] = (sha256(bundle_bytes), len(bundle_bytes))
    if owned != expected_owned:
        raise AssertionError("ownership manifest does not own the bundle and every member")
    return VerifiedBundle(digest, members)


PHP_PROBE = r'''
$facadeBytes = base64_decode($argv[1], true);
if (!is_string($facadeBytes) || !str_starts_with($facadeBytes, '<?php')) {
    throw new RuntimeException('invalid captured facade');
}
eval(substr($facadeBytes, 5));
$plugin = $argv[2];
$bundleFile = $argv[3];
$scenario = $argv[4];
$swapBytes = $argv[5] === '-' ? null : base64_decode($argv[5], true);
try {
    $provider = WordPressHxAcmeCalendarFacade::open($plugin, $bundleFile);
    if ($scenario === 'provider-swap') {
        if (!is_string($swapBytes)) {
            throw new RuntimeException('missing swap bytes');
        }
        file_put_contents($plugin, $swapBytes);
    }
    $limit = $scenario === 'provider-error' ? -1 : 2;
    $titles = WordPressHxAcmeCalendarFacade::listEventTitles($provider, $limit);
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
const { writeFileSync } = await import("node:fs");
const path = await import("node:path");
const facadeBytes = Buffer.from(process.argv[1], "base64");
const facade = await import(`data:text/javascript;base64,${facadeBytes.toString("base64")}`);
const root = process.argv[2];
const generation = process.argv[3];
const bundleFile = process.argv[4];
const scenario = process.argv[5];
const swapBytes = process.argv[6] === "-" ? null : Buffer.from(process.argv[6], "base64");
try {
  const provider = await facade.openExactProvider(root, generation, bundleFile);
  if (scenario === "provider-swap") {
    writeFileSync(path.join(root, "index.js"), swapBytes);
  }
  const count = scenario === "provider-error" ? -1 : 3;
  const label = provider.formatLabel(count);
  const badge = provider.renderBadge({ count, label });
  process.stdout.write(JSON.stringify({ outcome: "available", label, badge }) + "\n");
} catch (failure) {
  process.stdout.write(JSON.stringify({ outcome: "unavailable", message: failure.message }) + "\n");
}
'''


PHP_HAXE_PROBE = r'''
$facadeBytes = base64_decode($argv[1], true);
if (!is_string($facadeBytes) || !str_starts_with($facadeBytes, '<?php')) {
    throw new RuntimeException('invalid captured facade');
}
eval(substr($facadeBytes, 5));
require $argv[2];
'''


JS_HAXE_PROBE = r'''
const facadeBytes = Buffer.from(process.argv[1], "base64");
globalThis.WordPressHxAcmeCalendarFacade = await import(
  `data:text/javascript;base64,${facadeBytes.toString("base64")}`
);
await import(process.argv[2]);
'''


def php_command(
    php_mode: str,
    php_runtime: str,
    test_root: Path,
    arguments: list[str],
    environment: dict[str, str],
) -> list[str]:
    if php_mode == "local":
        return [php_runtime, *arguments]
    mount_roots = (ROOT, test_root)
    if any("," in str(root) for root in mount_roots):
        raise AssertionError("PHP container mount path contains a comma")
    return [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        *[
            value
            for name in (
                "WORDPRESSHX_ADOPTION_POISON_SENTINEL",
                "WORDPRESSHX_ADOPTION_PROVIDER_PATH",
                "WORDPRESSHX_ADOPTION_BUNDLE_PATH",
            )
            if name in environment
            for value in ("--env", name)
        ],
        "--mount",
        f"type=bind,source={ROOT},target={ROOT},readonly",
        "--mount",
        f"type=bind,source={test_root},target={test_root}",
        "--workdir",
        str(ROOT),
        php_runtime,
        "php",
        *arguments,
    ]


def php_case(
    php_mode: str,
    php_runtime: str,
    test_root: Path,
    facade_bytes: bytes,
    plugin: Path,
    bundle_file: Path,
    scenario: str,
    sentinel: Path,
    swap_bytes: bytes | None = None,
) -> dict[str, object]:
    environment = os.environ.copy()
    environment["WORDPRESSHX_ADOPTION_POISON_SENTINEL"] = str(sentinel)
    arguments = [
        "-r",
        PHP_PROBE,
        base64.b64encode(facade_bytes).decode("ascii"),
        str(plugin),
        str(bundle_file),
        scenario,
        "-" if swap_bytes is None else base64.b64encode(swap_bytes).decode("ascii"),
    ]
    result = checked_run(
        php_command(php_mode, php_runtime, test_root, arguments, environment),
        environment,
    )
    return json.loads(result.stdout)


def js_case(
    node: str,
    facade_bytes: bytes,
    provider: Path,
    generation: str,
    bundle_file: Path,
    scenario: str,
    sentinel: Path,
    swap_bytes: bytes | None = None,
) -> dict[str, object]:
    environment = os.environ.copy()
    environment["WORDPRESSHX_ADOPTION_POISON_SENTINEL"] = str(sentinel)
    result = checked_run(
        [
            node,
            "--input-type=module",
            "--eval",
            JS_PROBE,
            base64.b64encode(facade_bytes).decode("ascii"),
            str(provider),
            generation,
            str(bundle_file),
            scenario,
            "-" if swap_bytes is None else base64.b64encode(swap_bytes).decode("ascii"),
        ],
        environment,
    )
    return json.loads(result.stdout)


def replace_exact(data: bytes, old: str, new: str) -> bytes:
    text = data.decode("utf-8")
    if text.count(old) < 1:
        raise AssertionError("captured facade replacement target is absent")
    return text.replace(old, new).encode("utf-8")


def self_consistent_bundle_spoof(source: Path, destination: Path) -> None:
    bundle = json.loads(source.read_text(encoding="utf-8"))
    contract = next(
        member for member in bundle["members"] if member["role"] == "contract"
    )
    contract["sha256"] = "0" * 64
    bundle.pop("bundleDigest")
    bundle["bundleDigest"] = sha256(canonical(bundle))
    destination.write_bytes(canonical(bundle) + b"\n")


def copy_browser_provider(destination: Path) -> None:
    destination.mkdir()
    for name in ("index.js", "package-metadata.json"):
        shutil.copyfile(INPUT_ROOT / name, destination / name)
    shutil.copyfile(destination / "package-metadata.json", destination / "package.json")


INPUT_ROOT = ROOT / "fixtures/adoption-contract/inputs"


def main() -> None:
    if len(sys.argv) != 8:
        raise SystemExit(
            "usage: test-native-provider.py <stage> <work> <php-mode> "
            "<php-runtime> <node> <haxe-php-index> <haxe-js-index>"
        )
    stage = Path(sys.argv[1]).resolve()
    work = Path(sys.argv[2]).resolve()
    test_root = Path(os.path.commonpath((stage, work))).resolve()
    if test_root == Path(test_root.anchor):
        raise AssertionError("native-provider stage and work need a bounded shared root")
    work.mkdir(parents=True, exist_ok=False)
    php_mode = sys.argv[3]
    php_runtime = sys.argv[4]
    node = sys.argv[5]
    haxe_php_index = Path(sys.argv[6]).resolve()
    haxe_js_index = Path(sys.argv[7]).resolve()
    verified = verify_bundle(stage)
    bundle_file = stage / BUNDLE_PATH
    php_relative = f"{CONTENT_ROOT.as_posix()}/php/acme-calendar-facade.php"
    js_relative = f"{CONTENT_ROOT.as_posix()}/browser/acme-calendar-facade.mjs"
    php_facade = verified.content(php_relative)
    js_facade = verified.content(js_relative)
    plugin = INPUT_ROOT / "plugin.php"

    facade_swap_stage = work / "facade-swap-stage"
    shutil.copytree(stage, facade_swap_stage)
    captured_swap = verify_bundle(facade_swap_stage)
    facade_swap_bundle_file = facade_swap_stage / BUNDLE_PATH
    (facade_swap_stage / php_relative).write_text("<?php echo 'PWNED';\n", encoding="utf-8")
    (facade_swap_stage / js_relative).write_text("throw new Error('PWNED');\n", encoding="utf-8")

    php_sentinel = work / "php-provider-executed"
    outcome = php_case(
        php_mode,
        php_runtime,
        test_root,
        captured_swap.content(php_relative),
        plugin,
        facade_swap_bundle_file,
        "success",
        php_sentinel,
    )
    if outcome != {
        "outcome": "available",
        "titles": ["Provider event one", "Provider event two"],
    } or php_sentinel.read_text(encoding="utf-8") != "provider code executed":
        raise AssertionError(f"captured PHP facade success mismatch: {outcome}")
    failure = php_case(
        php_mode,
        php_runtime,
        test_root,
        php_facade,
        plugin,
        bundle_file,
        "provider-error",
        php_sentinel,
    )
    if failure != {
        "outcome": "unavailable",
        "message": "provider-call-failed",
        "previous": "InvalidArgumentException",
    }:
        raise AssertionError(f"PHP provider exception mismatch: {failure}")
    absent = php_case(
        php_mode,
        php_runtime,
        test_root,
        php_facade,
        work / "missing.php",
        bundle_file,
        "absence",
        php_sentinel,
    )
    if absent["message"] != "provider-absent":
        raise AssertionError(f"PHP required absence failed open: {absent}")

    wrong_bundle = work / "wrong-bundle.json"
    wrong_bundle.write_bytes(bundle_file.read_bytes() + b"\n")
    before_wrong_bundle = php_sentinel.read_bytes()
    rejected_bundle = php_case(
        php_mode,
        php_runtime,
        test_root,
        php_facade,
        plugin,
        wrong_bundle,
        "wrong-content-bundle",
        php_sentinel,
    )
    if (
        rejected_bundle["message"] != "wrong-content-bundle"
        or php_sentinel.read_bytes() != before_wrong_bundle
    ):
        raise AssertionError(f"PHP accepted caller-spoofed content identity: {rejected_bundle}")

    spoofed_bundle = work / "self-consistent-spoofed-bundle.json"
    self_consistent_bundle_spoof(bundle_file, spoofed_bundle)
    before_spoofed_bundle = php_sentinel.read_bytes()
    rejected_spoof = php_case(
        php_mode,
        php_runtime,
        test_root,
        php_facade,
        plugin,
        spoofed_bundle,
        "self-consistent-content-spoof",
        php_sentinel,
    )
    if (
        rejected_spoof["message"] != "wrong-content-bundle"
        or php_sentinel.read_bytes() != before_spoofed_bundle
    ):
        raise AssertionError(
            f"PHP accepted a self-consistent content identity spoof: {rejected_spoof}"
        )

    wrong_plugin = work / "wrong-plugin.php"
    wrong_plugin.write_bytes(plugin.read_bytes() + b"\n")
    before_wrong = php_sentinel.read_bytes()
    wrong = php_case(
        php_mode,
        php_runtime,
        test_root,
        php_facade,
        wrong_plugin,
        bundle_file,
        "wrong-artifact",
        php_sentinel,
    )
    if wrong["message"] != "wrong-provider-artifact" or php_sentinel.read_bytes() != before_wrong:
        raise AssertionError(f"PHP wrong artifact executed or passed: {wrong}")

    wrong_version_plugin = work / "wrong-version-plugin.php"
    wrong_version_plugin.write_text(
        plugin.read_text(encoding="utf-8").replace("Version: 2.4.1", "Version: 2.4.2"),
        encoding="utf-8",
    )
    wrong_version_facade = replace_exact(
        php_facade,
        sha256(plugin.read_bytes()),
        sha256(wrong_version_plugin.read_bytes()),
    )
    wrong_version = php_case(
        php_mode,
        php_runtime,
        test_root,
        wrong_version_facade,
        wrong_version_plugin,
        bundle_file,
        "wrong-version",
        php_sentinel,
    )
    if wrong_version["message"] != "wrong-provider-version":
        raise AssertionError(f"PHP wrong version failed open: {wrong_version}")

    missing_symbol_plugin = work / "missing-symbol-plugin.php"
    missing_symbol_plugin.write_text(
        plugin.read_text(encoding="utf-8").replace(
            "function list_events(", "function missing_list_events(", 1
        ),
        encoding="utf-8",
    )
    missing_symbol_facade = replace_exact(
        php_facade,
        sha256(plugin.read_bytes()),
        sha256(missing_symbol_plugin.read_bytes()),
    )
    missing_symbol = php_case(
        php_mode,
        php_runtime,
        test_root,
        missing_symbol_facade,
        missing_symbol_plugin,
        bundle_file,
        "missing-symbol",
        work / "php-missing-symbol-executed",
    )
    if missing_symbol["message"] != "required-provider-symbol-missing":
        raise AssertionError(f"PHP missing symbol failed open: {missing_symbol}")

    swap_plugin = work / "swap-plugin.php"
    shutil.copyfile(plugin, swap_plugin)
    swapped = php_case(
        php_mode,
        php_runtime,
        test_root,
        php_facade,
        swap_plugin,
        bundle_file,
        "provider-swap",
        work / "php-swap-executed",
        b"<?php throw new RuntimeException('PWNED');\n",
    )
    if swapped.get("titles") != ["Provider event one", "Provider event two"]:
        raise AssertionError(f"PHP verified handle reopened swapped provider bytes: {swapped}")

    provider = work / "browser-provider"
    copy_browser_provider(provider)
    js_sentinel = work / "js-provider-executed"
    js_success = js_case(
        node,
        captured_swap.content(js_relative),
        provider,
        "one",
        facade_swap_bundle_file,
        "success",
        js_sentinel,
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
        raise AssertionError(f"captured browser facade success mismatch: {js_success}")
    js_error = js_case(
        node, js_facade, provider, "two", bundle_file, "provider-error", js_sentinel
    )
    if js_error != {"outcome": "unavailable", "message": "count must be non-negative"}:
        raise AssertionError(f"browser provider exception mismatch: {js_error}")
    missing_provider = work / "missing-browser-provider"
    missing_provider.mkdir()
    js_absent = js_case(
        node, js_facade, missing_provider, "three", bundle_file, "absence", js_sentinel
    )
    if js_absent != {"outcome": "unavailable", "message": "provider-absent"}:
        raise AssertionError(f"browser optional absence mismatch: {js_absent}")

    before_js_wrong_bundle = js_sentinel.read_bytes()
    js_rejected_bundle = js_case(
        node,
        js_facade,
        provider,
        "wrong-bundle",
        wrong_bundle,
        "wrong-content-bundle",
        js_sentinel,
    )
    if (
        js_rejected_bundle != {
            "outcome": "unavailable",
            "message": "wrong-content-bundle",
        }
        or js_sentinel.read_bytes() != before_js_wrong_bundle
    ):
        raise AssertionError(
            f"browser accepted caller-spoofed content identity: {js_rejected_bundle}"
        )
    before_js_spoof = js_sentinel.read_bytes()
    js_rejected_spoof = js_case(
        node,
        js_facade,
        provider,
        "self-consistent-bundle-spoof",
        spoofed_bundle,
        "self-consistent-content-spoof",
        js_sentinel,
    )
    if (
        js_rejected_spoof
        != {"outcome": "unavailable", "message": "wrong-content-bundle"}
        or js_sentinel.read_bytes() != before_js_spoof
    ):
        raise AssertionError(
            "browser accepted a self-consistent content identity spoof: "
            f"{js_rejected_spoof}"
        )

    wrong_version_provider = work / "wrong-version-browser-provider"
    copy_browser_provider(wrong_version_provider)
    package_path = wrong_version_provider / "package-metadata.json"
    old_package = package_path.read_bytes()
    package_path.write_text(
        package_path.read_text(encoding="utf-8").replace('"2.4.1"', '"2.4.2"'),
        encoding="utf-8",
    )
    wrong_version_js_facade = replace_exact(
        js_facade, sha256(old_package), sha256(package_path.read_bytes())
    )
    js_wrong_version = js_case(
        node,
        wrong_version_js_facade,
        wrong_version_provider,
        "four",
        bundle_file,
        "wrong-version",
        js_sentinel,
    )
    if js_wrong_version["message"] != "wrong-provider-version":
        raise AssertionError(f"browser wrong version failed open: {js_wrong_version}")

    missing_symbol_provider = work / "missing-symbol-browser-provider"
    copy_browser_provider(missing_symbol_provider)
    missing_module = missing_symbol_provider / "index.js"
    old_module = missing_module.read_bytes()
    missing_module.write_text(
        missing_module.read_text(encoding="utf-8").replace(
            "export function formatCalendarLabel(",
            "export function missingFormatCalendarLabel(",
            1,
        ),
        encoding="utf-8",
    )
    missing_js_facade = replace_exact(
        js_facade, sha256(old_module), sha256(missing_module.read_bytes())
    )
    js_missing_symbol = js_case(
        node,
        missing_js_facade,
        missing_symbol_provider,
        "five",
        bundle_file,
        "missing-symbol",
        work / "js-missing-symbol-executed",
    )
    if js_missing_symbol["message"] != "required-provider-symbol-missing":
        raise AssertionError(f"browser missing symbol failed open: {js_missing_symbol}")

    wrong_provider = work / "wrong-browser-provider"
    copy_browser_provider(wrong_provider)
    before_js_wrong = js_sentinel.read_bytes()
    (wrong_provider / "index.js").write_bytes((wrong_provider / "index.js").read_bytes() + b"\n")
    js_wrong = js_case(
        node, js_facade, wrong_provider, "six", bundle_file, "wrong-artifact", js_sentinel
    )
    if js_wrong["message"] != "wrong-provider-artifact" or js_sentinel.read_bytes() != before_js_wrong:
        raise AssertionError(f"browser wrong artifact executed or passed: {js_wrong}")

    swap_provider = work / "swap-browser-provider"
    copy_browser_provider(swap_provider)
    js_swapped = js_case(
        node,
        js_facade,
        swap_provider,
        "seven",
        bundle_file,
        "provider-swap",
        work / "js-swap-executed",
        b'throw new Error("PWNED");\n',
    )
    if js_swapped.get("label") != "3 calendar events":
        raise AssertionError(f"browser verified handle imported swapped provider bytes: {js_swapped}")

    haxe_environment = os.environ.copy()
    haxe_php_sentinel = work / "haxe-php-provider-executed"
    haxe_environment["WORDPRESSHX_ADOPTION_POISON_SENTINEL"] = str(haxe_php_sentinel)
    haxe_environment["WORDPRESSHX_ADOPTION_PROVIDER_PATH"] = str(plugin)
    haxe_environment["WORDPRESSHX_ADOPTION_BUNDLE_PATH"] = str(bundle_file)
    php_haxe_arguments = [
        "-r",
        PHP_HAXE_PROBE,
        base64.b64encode(php_facade).decode("ascii"),
        str(haxe_php_index),
    ]
    php_haxe = checked_run(
        php_command(
            php_mode,
            php_runtime,
            test_root,
            php_haxe_arguments,
            haxe_environment,
        ),
        haxe_environment,
    )
    if (
        php_haxe.stdout != "haxe-php-native|Provider event one|Provider event two\n"
        or haxe_php_sentinel.read_text(encoding="utf-8") != "provider code executed"
    ):
        raise AssertionError(f"Haxe-to-PHP provider observer mismatch: {php_haxe.stdout}")

    haxe_js_sentinel = work / "haxe-js-provider-executed"
    haxe_environment["WORDPRESSHX_ADOPTION_POISON_SENTINEL"] = str(haxe_js_sentinel)
    haxe_environment["WORDPRESSHX_ADOPTION_PROVIDER_PATH"] = str(provider)
    haxe_environment["WORDPRESSHX_ADOPTION_GENERATION"] = "haxe-observer"
    js_haxe = checked_run(
        [
            node,
            "--input-type=module",
            "--eval",
            JS_HAXE_PROBE,
            base64.b64encode(js_facade).decode("ascii"),
            haxe_js_index.resolve().as_uri(),
        ],
        haxe_environment,
    )
    if (
        js_haxe.stdout != "haxe-js-native|opaque-object-observed\n"
        or haxe_js_sentinel.read_text(encoding="utf-8")
        != "browser provider code executed\n"
    ):
        raise AssertionError(f"Haxe-to-JavaScript provider observer mismatch: {js_haxe.stdout}")

    print(
        "ADR-015 captured facades, immutable provider handles, and Haxe PHP/JS observers passed"
    )


if __name__ == "__main__":
    main()
