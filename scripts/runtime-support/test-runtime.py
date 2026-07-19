#!/usr/bin/env python3
"""Validate ADR-018's generated private-runtime fixture packages."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import statistics
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CLI_PROBE = ROOT / "fixtures/runtime-support-packaging/runtime/cli-probe.php"
COLD_BOOT = ROOT / "fixtures/runtime-support-packaging/runtime/cold-boot.php"
CONFLICT_PROBE = ROOT / "fixtures/runtime-support-packaging/runtime/conflict-probe.php"
PREFIX = re.compile(r"^wphx_internal\.p[0-9a-f]{24}$")
ADMITTED_POLYFILL_SHA256 = "80f6c2172d93b501328e2c4fa131b81a186ff850e6a437e9068f9e842a6b3237"


def sha256_file(file_path: Path) -> str:
    return hashlib.sha256(file_path.read_bytes()).hexdigest()


def tree_inventory(root: Path) -> list[dict[str, object]]:
    result = []
    for candidate in sorted(
        (entry for entry in root.rglob("*") if entry.is_file()),
        key=lambda entry: entry.relative_to(root).as_posix(),
    ):
        result.append(
            {
                "bytes": candidate.stat().st_size,
                "path": candidate.relative_to(root).as_posix(),
                "sha256": sha256_file(candidate),
            }
        )
    return result


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        env={
            "HOME": os.environ.get("HOME", ""),
            "PATH": os.environ.get("PATH", ""),
            "TMPDIR": os.environ.get("TMPDIR", "/tmp"),
        },
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(command)}\n"
            + result.stdout
            + result.stderr
        )
    return result


def read_json(file_path: Path) -> dict[str, Any]:
    value = json.loads(file_path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {file_path}")
    return value


def load_classmap(file_path: Path) -> dict[str, str]:
    source = """
$map = require $argv[1];
ksort($map, SORT_STRING);
echo json_encode($map, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
"""
    value = json.loads(run(["php", "-r", source, str(file_path)]).stdout)
    if not isinstance(value, dict) or not all(
        isinstance(key, str) and isinstance(item, str) for key, item in value.items()
    ):
        raise RuntimeError(f"class map was not a string map: {file_path}")
    return value


def validate_package(build_root: Path, summary: dict[str, Any]) -> None:
    slug = str(summary["slug"])
    package = build_root / slug
    if not package.is_dir() or package.is_symlink():
        raise RuntimeError(f"missing real package directory: {slug}")
    prefix = str(summary["prefix"])
    if PREFIX.fullmatch(prefix) is None:
        raise RuntimeError(f"invalid derived private prefix: {prefix}")
    private_root = package / "private/wordpresshx"
    manifest = read_json(private_root / "runtime-manifest.v1.json")
    if manifest.get("schema") != "wordpress-hx.private-runtime-manifest.v1":
        raise RuntimeError(f"{slug} private runtime manifest schema differed")
    namespace = manifest.get("privateNamespace")
    if not isinstance(namespace, dict) or namespace.get("value") != prefix:
        raise RuntimeError(f"{slug} private namespace manifest differed")
    if namespace.get("derivationSha256") != summary.get("prefixDerivationSha256"):
        raise RuntimeError(f"{slug} private namespace derivation digest differed")
    front = manifest.get("stockFrontController")
    if not isinstance(front, dict) or front.get("packaged") is not False:
        raise RuntimeError(f"{slug} packaged the stock Haxe front")
    composer = manifest.get("composer")
    expected_composer = {
        "manifestPath": None,
        "lockPath": None,
        "runtimePackages": [],
        "status": "absent-no-runtime-dependencies",
        "vendorPath": None,
    }
    if composer != expected_composer:
        raise RuntimeError(f"{slug} runtime Composer graph differed: {composer!r}")
    expected_polyfill_path = (
        "private/wordpresshx/runtime/"
        + prefix.replace(".", "/")
        + "/php/_polyfills.php"
    )
    expected_polyfill = {
        "compatibilityConstant": "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256",
        "differentHashDisposition": "reject-private-boot-WPHX5201",
        "functions": ["mb_chr", "mb_ord", "mb_scrub", "str_starts_with"],
        "nativeInternalFunctionAllowed": True,
        "ownedFileVerifiedBeforePrivateBoot": True,
        "path": expected_polyfill_path,
        "sameExactDeclaringFileHashAllowed": True,
        "sha256": ADMITTED_POLYFILL_SHA256,
    }
    if manifest.get("globalPolyfill") != expected_polyfill:
        raise RuntimeError(f"{slug} global polyfill contract differed")
    if summary.get("globalPolyfillSha256") != ADMITTED_POLYFILL_SHA256:
        raise RuntimeError(f"{slug} global polyfill summary digest differed")
    polyfill_file = package / expected_polyfill_path
    if not polyfill_file.is_file() or polyfill_file.is_symlink():
        raise RuntimeError(f"{slug} global polyfill file is missing or linked")
    if sha256_file(polyfill_file) != ADMITTED_POLYFILL_SHA256:
        raise RuntimeError(f"{slug} packaged global polyfill digest differed")
    for candidate in package.rglob("*"):
        if candidate.is_symlink():
            raise RuntimeError(f"{slug} package contains a link: {candidate.relative_to(package)}")
        if candidate.name in {"stock-front.php", "composer.json", "composer.lock", "vendor"}:
            raise RuntimeError(f"{slug} package contains forbidden artifact: {candidate.relative_to(package)}")
        if candidate.is_file():
            source = candidate.read_bytes()
            for forbidden in (b"set_include_path", b"stream_resolve_include_path"):
                if forbidden in source:
                    raise RuntimeError(f"{slug} package retained process-global loader code: {forbidden.decode()}")
            if str(ROOT).encode("utf-8") in source:
                raise RuntimeError(f"{slug} package leaked the checkout path: {candidate.relative_to(package)}")

    classmap_path = private_root / "classmap.php"
    classmap = load_classmap(classmap_path)
    if len(classmap) != summary.get("classmapEntries"):
        raise RuntimeError(f"{slug} class map entry count differed")
    php_prefix = prefix.replace(".", "\\") + "\\"
    for class_name, absolute_file in classmap.items():
        if not class_name.startswith(php_prefix):
            raise RuntimeError(f"{slug} class map key escaped prefix: {class_name}")
        class_file = Path(absolute_file)
        if not class_file.is_file() or class_file.is_symlink():
            raise RuntimeError(f"{slug} class map target is missing or linked: {class_name}")
        try:
            class_file.relative_to(private_root / "runtime")
        except ValueError as error:
            raise RuntimeError(f"{slug} class map target escaped runtime root: {class_name}") from error

    closure = manifest.get("privateClosure")
    if not isinstance(closure, dict):
        raise RuntimeError(f"{slug} private closure inventory is missing")
    files = closure.get("files")
    if not isinstance(files, list) or not files:
        raise RuntimeError(f"{slug} private file inventory is empty")
    for entry in files:
        if not isinstance(entry, dict):
            raise RuntimeError(f"{slug} private file inventory contains a non-object")
        relative = Path(str(entry.get("path", "")))
        runtime_file = package / relative
        if not runtime_file.is_file() or runtime_file.is_symlink():
            raise RuntimeError(f"{slug} inventoried private file is missing: {relative}")
        if entry.get("sha256") != sha256_file(runtime_file):
            raise RuntimeError(f"{slug} private file digest differed: {relative}")
        if entry.get("bytes") != runtime_file.stat().st_size:
            raise RuntimeError(f"{slug} private file byte count differed: {relative}")
    if closure.get("privatePhpBytes") != summary.get("privatePhpBytes"):
        raise RuntimeError(f"{slug} private PHP byte count differed")
    if int(summary["privatePhpBytes"]) > 163840:
        raise RuntimeError(f"{slug} private PHP exceeded the 160 KiB review threshold")
    if int(summary["packagePhpBytes"]) > 409600:
        raise RuntimeError(f"{slug} package PHP exceeded the 400 KiB product ceiling")

    public_files = (
        package / f"{slug}.php",
        package / "includes/autoload.php",
        package / "includes/Bootstrap.php",
        package / "includes/PrivateBridge.php",
    )
    for public_file in public_files:
        run(["php", "-l", str(public_file)])
    for private_file in sorted(package.rglob("*.php")):
        run(["php", "-l", str(private_file)])


def cold_boot(
    package_root: Path,
    bridge_class: str,
    expected_result: str,
) -> dict[str, object]:
    samples = []
    for _ in range(25):
        output = run(
            [
                "php",
                "-d",
                "opcache.enable_cli=0",
                str(COLD_BOOT),
                str(package_root),
                bridge_class,
            ]
        ).stdout
        payload = json.loads(output)
        if not isinstance(payload, dict) or payload.get("result") != expected_result:
            raise RuntimeError(f"cold boot returned unexpected behavior: {payload!r}")
        elapsed = payload.get("elapsedNanoseconds")
        if not isinstance(elapsed, int) or elapsed < 1:
            raise RuntimeError(f"cold boot returned invalid duration: {payload!r}")
        samples.append(elapsed)
    ordered = sorted(samples)
    p50_ns = int(statistics.median(ordered))
    p95_ns = ordered[int((len(ordered) - 1) * 0.95)]
    if p50_ns > 20_000_000:
        raise RuntimeError(
            f"isolated opcache-disabled cold boot exceeded 20 ms p50: {p50_ns / 1_000_000:.3f} ms"
        )
    return {
        "maxNanoseconds": max(ordered),
        "minNanoseconds": min(ordered),
        "p50Nanoseconds": p50_ns,
        "p95Nanoseconds": p95_ns,
        "sampleCount": len(ordered),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--first", required=True, type=Path)
    parser.add_argument("--second", required=True, type=Path)
    args = parser.parse_args()
    first = args.first.resolve()
    second = args.second.resolve()
    if tree_inventory(first) != tree_inventory(second):
        raise RuntimeError("ADR-018 package fixture was not byte-identical across fresh roots")
    first_summary = read_json(first / "build-summary.json")
    second_summary = read_json(second / "build-summary.json")
    if first_summary != second_summary:
        raise RuntimeError("ADR-018 build summary differed across fresh roots")
    variants = first_summary.get("variants")
    if not isinstance(variants, list) or len(variants) != 2:
        raise RuntimeError("ADR-018 build summary must contain two variants")
    for variant in variants:
        if not isinstance(variant, dict):
            raise RuntimeError("ADR-018 variant summary must be an object")
        validate_package(first, variant)

    alpha = variants[0]
    beta = variants[1]
    if alpha.get("globalPolyfillSha256") != beta.get("globalPolyfillSha256"):
        raise RuntimeError("coexisting variants did not share an exact global polyfill contract")
    cli_output = run(
        [
            "php",
            str(CLI_PROBE),
            str(first / str(alpha["slug"]) / f"{alpha['slug']}.php"),
            str(first / str(beta["slug"]) / f"{beta['slug']}.php"),
            str(alpha["privateClass"]),
            str(beta["privateClass"]),
        ]
    ).stdout
    cli = json.loads(cli_output)
    expected_signature = {"parameters": ["string", "int"], "return": "string"}
    expected_cli = {
        "alphaBooted": True,
        "alphaPrivateClass": alpha["privateClass"],
        "alphaPrivateLoaded": True,
        "alphaSignature": expected_signature,
        "betaBooted": True,
        "betaPrivateClass": beta["privateClass"],
        "betaPrivateLoaded": True,
        "betaSignature": expected_signature,
        "filteredTitle": "seed:alpha-v1:beta-v2",
        "filterCount": 2,
        "outputBytes": 0,
        "prefixesDistinct": True,
    }
    if cli != expected_cli:
        raise RuntimeError(f"ordinary PHP coexistence probe differed: {cli!r}")

    conflict_result = run(
        [
            "php",
            str(CONFLICT_PROBE),
            str(first / str(alpha["slug"]) / f"{alpha['slug']}.php"),
            str(alpha["publicBootstrapClass"]),
        ]
    )
    conflict = json.loads(conflict_result.stdout)
    expected_conflict = {
        "bootstrapLoaded": False,
        "filterCount": 0,
        "outputBytes": 0,
    }
    if conflict != expected_conflict:
        raise RuntimeError(f"global polyfill conflict probe differed: {conflict!r}")
    if "WPHX5201" not in conflict_result.stderr:
        raise RuntimeError("global polyfill conflict omitted WPHX5201 diagnostic")

    cold_boots = {
        str(variant["slug"]): cold_boot(
            first / str(variant["slug"]) / f"{variant['slug']}.php",
            str(variant["publicBridgeClass"]),
            "seed:" + str(variant["expectedMarker"]),
        )
        for variant in variants
    }
    php_version = run(["php", "-r", "echo PHP_VERSION;"]).stdout
    result = {
        "buildsByteIdentical": True,
        "check": "wordpresshx-adr018-runtime-support-local-v1",
        "coldBoot": cold_boots,
        "composerRuntimeGraph": "absent-no-runtime-dependencies",
        "duplicateSameRoot": "idempotent",
        "globalPolyfillMismatch": "rejected-before-private-boot-WPHX5201",
        "haxeVersion": first_summary.get("haxeVersion"),
        "phpVersion": php_version,
        "publicAbiReflection": "native-string-int-to-string",
        "stockFrontControllersPackaged": False,
        "twoPluginVersionSkew": "passed",
        "variants": variants,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
