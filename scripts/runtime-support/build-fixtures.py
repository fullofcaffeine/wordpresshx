#!/usr/bin/env python3
"""Build ADR-018's temporary dependency-closed WordPress plugin fixtures."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "fixtures/runtime-support-packaging/src"
HAXE_MAIN = "fixture.privateimpl.Main"
PREFIX_SCHEMA = "wordpress-hx.private-runtime.v1"
PREFIX_PATTERN = re.compile(r"^wphx_internal\.p[0-9a-f]{24}$")
PHP_CLASS_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\\[A-Za-z_][A-Za-z0-9_]*)*$")
PHP_FUNCTION_PATTERN = re.compile(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
POLYFILL_COMPATIBILITY_CONSTANT = "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256"
ADMITTED_POLYFILL_SHA256 = "80f6c2172d93b501328e2c4fa131b81a186ff850e6a437e9068f9e842a6b3237"
POLYFILL_FUNCTIONS = ("mb_chr", "mb_ord", "mb_scrub", "str_starts_with")


@dataclass(frozen=True)
class Variant:
    key: str
    slug: str
    project_id: str
    module_id: str
    display_name: str
    version: str
    public_namespace: str
    define: str
    expected_marker: str


VARIANTS = (
    Variant(
        key="alpha",
        slug="runtime-alpha",
        project_id="runtime-alpha",
        module_id="plugin",
        display_name="Runtime Alpha",
        version="1.0.0",
        public_namespace="RuntimeAlpha",
        define="runtime_alpha",
        expected_marker="alpha-v1",
    ),
    Variant(
        key="beta",
        slug="runtime-beta",
        project_id="runtime-beta",
        module_id="plugin",
        display_name="Runtime Beta",
        version="2.0.0",
        public_namespace="RuntimeBeta",
        define="runtime_beta",
        expected_marker="beta-v2",
    ),
)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(file_path: Path) -> str:
    return sha256_bytes(file_path.read_bytes())


def canonical_json(value: object) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
        separators=(",", ": "),
    ) + "\n"


def write_text(file_path: Path, source: str) -> None:
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(source, encoding="utf-8", newline="\n")
    file_path.chmod(0o644)


def relative_files(root: Path) -> list[Path]:
    return sorted(
        (candidate.relative_to(root) for candidate in root.rglob("*") if candidate.is_file()),
        key=lambda candidate: candidate.as_posix(),
    )


def tree_inventory(root: Path) -> list[dict[str, object]]:
    return [
        {
            "bytes": (root / relative).stat().st_size,
            "path": relative.as_posix(),
            "sha256": sha256_file(root / relative),
        }
        for relative in relative_files(root)
    ]


def tree_digest(root: Path) -> str:
    digest = hashlib.sha256()
    for entry in tree_inventory(root):
        path_bytes = str(entry["path"]).encode("utf-8")
        digest.update(len(path_bytes).to_bytes(8, "big"))
        digest.update(path_bytes)
        digest.update(bytes.fromhex(str(entry["sha256"])))
    return digest.hexdigest()


def compare_trees(left: Path, right: Path, label: str) -> None:
    left_inventory = tree_inventory(left)
    right_inventory = tree_inventory(right)
    if left_inventory != right_inventory:
        raise RuntimeError(f"{label} was not byte-identical across clean builds")


def prefix_identity(variant: Variant) -> tuple[str, str]:
    identity = (
        PREFIX_SCHEMA.encode("utf-8")
        + b"\0"
        + variant.project_id.encode("utf-8")
        + b"\0"
        + variant.module_id.encode("utf-8")
    )
    digest = sha256_bytes(identity)
    prefix = "wphx_internal.p" + digest[:24]
    if PREFIX_PATTERN.fullmatch(prefix) is None:
        raise RuntimeError(f"derived invalid private prefix: {prefix}")
    return prefix, digest


def run(command: list[str], *, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
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
        transcript = result.stdout + result.stderr
        raise RuntimeError(f"command failed ({result.returncode}): {' '.join(command)}\n{transcript}")
    return result


def require_haxe() -> None:
    version = run(["haxe", "--version"]).stdout.strip()
    if version != "4.3.7":
        raise RuntimeError(f"ADR-018 fixture requires Haxe 4.3.7; found {version}")


def compile_stock(variant: Variant, destination: Path, prefix: str) -> None:
    command = [
        "haxe",
        "-cp",
        str(SOURCE_ROOT),
        "-main",
        HAXE_MAIN,
        "-php",
        str(destination),
        "-D",
        variant.define,
        "-D",
        f"php-prefix={prefix}",
        "-D",
        "php-front=stock-front.php",
        "-D",
        "php-lib=runtime",
        "-D",
        "real-position",
        "-dce",
        "full",
        "--macro",
        "keep('fixture.privateimpl.Main')",
    ]
    run(command)
    front = destination / "stock-front.php"
    runtime = destination / "runtime"
    if not front.is_file() or not runtime.is_dir():
        raise RuntimeError("stock Haxe PHP output omitted its expected front/runtime split")
    front_source = front.read_text(encoding="utf-8")
    for required in ("set_include_path", "stream_resolve_include_path", "spl_autoload_register"):
        if required not in front_source:
            raise RuntimeError(f"stock front probe no longer contains expected ownership hazard: {required}")
    source_root_bytes = str(ROOT).encode("utf-8")
    for relative in relative_files(destination):
        if source_root_bytes in (destination / relative).read_bytes():
            raise RuntimeError(f"stock output leaked the checkout path: {relative.as_posix()}")


def php_classmap(runtime_root: Path, prefix: str) -> tuple[dict[str, str], Path, str]:
    expected_root = Path(*prefix.split("."))
    classmap: dict[str, str] = {}
    polyfill_path: Path | None = None
    for relative in relative_files(runtime_root):
        if relative.suffix != ".php":
            raise RuntimeError(f"unexpected non-PHP private runtime file: {relative.as_posix()}")
        if relative.name == "_polyfills.php":
            if polyfill_path is not None:
                raise RuntimeError("private runtime emitted more than one stock-Haxe polyfill file")
            polyfill_path = relative
            continue
        if tuple(relative.parts[: len(expected_root.parts)]) != expected_root.parts:
            raise RuntimeError(f"private runtime file escaped its prefix: {relative.as_posix()}")
        class_name = "\\".join(relative.with_suffix("").parts)
        if PHP_CLASS_PATTERN.fullmatch(class_name) is None:
            raise RuntimeError(f"invalid private PHP class identity: {class_name}")
        if class_name in classmap:
            raise RuntimeError(f"duplicate private PHP class identity: {class_name}")
        classmap[class_name] = relative.as_posix()
    if polyfill_path is None:
        raise RuntimeError("private runtime omitted the stock-Haxe polyfill file")
    if not classmap:
        raise RuntimeError("private runtime class map is empty")
    polyfill_file = runtime_root / polyfill_path
    polyfill_digest = sha256_file(polyfill_file)
    if polyfill_digest != ADMITTED_POLYFILL_SHA256:
        raise RuntimeError(f"stock-Haxe polyfill digest is not admitted: {polyfill_digest}")
    declared_functions = tuple(PHP_FUNCTION_PATTERN.findall(polyfill_file.read_text(encoding="utf-8")))
    if declared_functions != POLYFILL_FUNCTIONS:
        raise RuntimeError(f"stock-Haxe global polyfill inventory changed: {declared_functions!r}")
    return dict(sorted(classmap.items())), polyfill_path, polyfill_digest


def php_single_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def classmap_source(classmap: dict[str, str]) -> str:
    lines = ["<?php", "", "declare(strict_types=1);", "", "return array("]
    for class_name, relative in classmap.items():
        lines.append(
            "    '"
            + php_single_quote(class_name)
            + "' => __DIR__ . '/runtime/"
            + php_single_quote(relative)
            + "',"
        )
    lines.extend((");", ""))
    return "\n".join(lines)


def autoload_source(polyfill_digest: str, polyfill_relative: Path) -> str:
    function_lines = "\n".join(
        f"    '{php_single_quote(function_name)}'," for function_name in POLYFILL_FUNCTIONS
    )
    owned_polyfill = (
        "../private/wordpresshx/runtime/" + php_single_quote(polyfill_relative.as_posix())
    )
    return f"""<?php

declare(strict_types=1);

$polyfillSha256 = '{polyfill_digest}';
$ownedPolyfill = __DIR__ . '/{owned_polyfill}';
$ownedPolyfillSha256 = is_file($ownedPolyfill)
    ? hash_file('sha256', $ownedPolyfill)
    : false;
if ($ownedPolyfillSha256 !== $polyfillSha256) {{
    error_log('WPHX5201 WordPressHx private runtime rejected its global polyfill file.');
    return false;
}}

if (defined('{POLYFILL_COMPATIBILITY_CONSTANT}')) {{
    $activePolyfillSha256 = constant('{POLYFILL_COMPATIBILITY_CONSTANT}');
    if ($activePolyfillSha256 !== $polyfillSha256) {{
        error_log('WPHX5201 WordPressHx private runtime rejected an incompatible global polyfill marker.');
        return false;
    }}
}}

$polyfillFunctions = array(
{function_lines}
);
foreach ($polyfillFunctions as $polyfillFunction) {{
    if (!function_exists($polyfillFunction)) {{
        continue;
    }}
    $reflection = new ReflectionFunction($polyfillFunction);
    if ($reflection->isInternal()) {{
        continue;
    }}
    $declaringFile = $reflection->getFileName();
    $declaringSha256 = is_string($declaringFile) && is_file($declaringFile)
        ? hash_file('sha256', $declaringFile)
        : false;
    if ($declaringSha256 !== $polyfillSha256) {{
        error_log(
            'WPHX5201 WordPressHx private runtime rejected incompatible global function '
            . $polyfillFunction
            . '.'
        );
        return false;
    }}
}}

if (!defined('{POLYFILL_COMPATIBILITY_CONSTANT}')) {{
    define('{POLYFILL_COMPATIBILITY_CONSTANT}', $polyfillSha256);
}}

$classMap = require __DIR__ . '/../private/wordpresshx/classmap.php';

spl_autoload_register(
    static function (string $className) use ($classMap): void {{
        if (isset($classMap[$className])) {{
            require_once $classMap[$className];
        }}
    }},
    true,
    false
);

require_once __DIR__ . '/PrivateBridge.php';
require_once __DIR__ . '/Bootstrap.php';

return true;
"""


def bridge_source(variant: Variant, private_class: str) -> str:
    return f"""<?php

declare(strict_types=1);

namespace {variant.public_namespace};

final class PrivateBridge
{{
    public static function filterTitle(string $title, int $postId): string
    {{
        if ($postId < 0) {{
            return $title;
        }}
        return (string) \\{private_class}::decorate($title);
    }}
}}
"""


def bootstrap_source(variant: Variant) -> str:
    return f"""<?php

declare(strict_types=1);

namespace {variant.public_namespace};

final class Bootstrap
{{
    private static bool $booted = false;

    public static function boot(): void
    {{
        if (self::$booted) {{
            return;
        }}
        self::$booted = true;
        \\add_filter('the_title', array(PrivateBridge::class, 'filterTitle'), 10, 2);
    }}

    public static function isBooted(): bool
    {{
        return self::$booted;
    }}
}}
"""


def plugin_root_source(variant: Variant) -> str:
    return f"""<?php
/**
 * Plugin Name: {variant.display_name}
 * Description: ADR-018 dependency-closed runtime packaging fixture.
 * Version: {variant.version}
 * Requires at least: 7.0
 * Requires PHP: 7.4
 * Author: WordPressHx SDK fixture
 * License: LicenseRef-WordPressHx-Review-Pending
 * Text Domain: {variant.slug}
 * Domain Path: /languages
 */

if (!defined('ABSPATH')) {{
    return;
}}

$autoloadStatus = require_once __DIR__ . '/includes/autoload.php';
if ($autoloadStatus !== true || !class_exists(\\{variant.public_namespace}\\Bootstrap::class, false)) {{
    return;
}}
\\{variant.public_namespace}\\Bootstrap::boot();
"""


def copy_runtime(source: Path, destination: Path) -> None:
    if destination.exists() or destination.is_symlink():
        raise RuntimeError(f"private runtime destination already exists: {destination}")
    shutil.copytree(source, destination, symlinks=False)
    for directory in sorted((candidate for candidate in destination.rglob("*") if candidate.is_dir())):
        directory.chmod(0o755)
    destination.chmod(0o755)
    for file_path in sorted((candidate for candidate in destination.rglob("*") if candidate.is_file())):
        file_path.chmod(0o644)


def build_variant(variant: Variant, output_root: Path) -> dict[str, object]:
    prefix, derivation_digest = prefix_identity(variant)
    private_class = prefix.replace(".", "\\") + "\\fixture\\privateimpl\\Main"
    with tempfile.TemporaryDirectory(prefix=f"wordpresshx-adr018-{variant.key}-") as raw:
        temporary = Path(raw)
        first = temporary / "first"
        second = temporary / "second"
        compile_stock(variant, first, prefix)
        compile_stock(variant, second, prefix)
        compare_trees(first, second, f"{variant.key} stock-Haxe output")

        plugin_root = output_root / variant.slug
        plugin_root.mkdir(parents=True, exist_ok=False)
        private_root = plugin_root / "private/wordpresshx"
        runtime_root = private_root / "runtime"
        copy_runtime(first / "runtime", runtime_root)
        classmap, polyfill_relative, polyfill_digest = php_classmap(runtime_root, prefix)
        write_text(private_root / "classmap.php", classmap_source(classmap))
        write_text(
            plugin_root / "includes/autoload.php",
            autoload_source(polyfill_digest, polyfill_relative),
        )
        write_text(plugin_root / "includes/PrivateBridge.php", bridge_source(variant, private_class))
        write_text(plugin_root / "includes/Bootstrap.php", bootstrap_source(variant))
        write_text(plugin_root / f"{variant.slug}.php", plugin_root_source(variant))

        runtime_entries = []
        for relative in relative_files(runtime_root):
            runtime_file = runtime_root / relative
            reason = (
                "stock-haxe-guarded-global-polyfill"
                if relative.name == "_polyfills.php"
                else "stock-haxe-private-dependency-closure"
            )
            runtime_entries.append(
                {
                    "bytes": runtime_file.stat().st_size,
                    "path": (Path("private/wordpresshx/runtime") / relative).as_posix(),
                    "reason": reason,
                    "sha256": sha256_file(runtime_file),
                }
            )

        classmap_file = private_root / "classmap.php"
        private_php_files = [
            private_root / relative
            for relative in relative_files(plugin_root / "private/wordpresshx")
            if relative.suffix == ".php"
        ]
        private_php_bytes = sum(file_path.stat().st_size for file_path in private_php_files)
        manifest = {
            "schema": "wordpress-hx.private-runtime-manifest.v1",
            "projectId": variant.project_id,
            "moduleId": variant.module_id,
            "packageVersion": variant.version,
            "privateNamespace": {
                "canonicalSchema": PREFIX_SCHEMA,
                "derivationSha256": derivation_digest,
                "digestBitsRetained": 96,
                "haxeDefine": "php-prefix",
                "value": prefix,
            },
            "compiler": {
                "haxeVersion": "4.3.7",
                "target": "php",
                "dce": "full-with-derived-private-entry-retention",
                "positionMode": "real-position-no-machine-local-comments",
            },
            "stockFrontController": {
                "packaged": False,
                "reason": "process-global-include-path-and-unbounded-resolver",
                "sha256": sha256_file(first / "stock-front.php"),
            },
            "autoload": {
                "classCount": len(classmap),
                "classmapPath": "private/wordpresshx/classmap.php",
                "classmapSha256": sha256_file(classmap_file),
                "mechanism": "package-local-authoritative-classmap",
                "processIncludePathMutation": False,
                "rootPath": "includes/autoload.php",
            },
            "globalPolyfill": {
                "compatibilityConstant": POLYFILL_COMPATIBILITY_CONSTANT,
                "differentHashDisposition": "reject-private-boot-WPHX5201",
                "functions": list(POLYFILL_FUNCTIONS),
                "nativeInternalFunctionAllowed": True,
                "ownedFileVerifiedBeforePrivateBoot": True,
                "path": (Path("private/wordpresshx/runtime") / polyfill_relative).as_posix(),
                "sameExactDeclaringFileHashAllowed": True,
                "sha256": polyfill_digest,
            },
            "composer": {
                "manifestPath": None,
                "lockPath": None,
                "runtimePackages": [],
                "status": "absent-no-runtime-dependencies",
                "vendorPath": None,
            },
            "privateClosure": {
                "entryClass": private_class,
                "files": runtime_entries,
                "privatePhpBytes": private_php_bytes,
                "privatePhpFileCount": len(private_php_files),
            },
            "publicBoundary": {
                "adapterClass": variant.public_namespace + "\\PrivateBridge",
                "adapterMethod": "filterTitle(string,int):string",
                "privateNamesAllowedInPublicAbi": False,
                "wordPressCallback": variant.public_namespace + "\\PrivateBridge::filterTitle",
            },
            "evidence": {
                "architectureReceipt": "ADR-018-RUNTIME-SUPPORT-PACKAGING",
                "productionIntegration": "not-tested-by-this-manifest",
            },
        }
        write_text(private_root / "runtime-manifest.v1.json", canonical_json(manifest))

    php_files = [plugin_root / relative for relative in relative_files(plugin_root) if relative.suffix == ".php"]
    package_php_bytes = sum(file_path.stat().st_size for file_path in php_files)
    if private_php_bytes > 163840:
        raise RuntimeError(
            f"{variant.key} private PHP closure exceeded ADR-018's 160 KiB review threshold: {private_php_bytes}"
        )
    if package_php_bytes > 409600:
        raise RuntimeError(
            f"{variant.key} generated PHP exceeded the PRD 400 KiB starter ceiling: {package_php_bytes}"
        )
    for forbidden in ("composer.json", "composer.lock", "vendor"):
        if any(relative.name == forbidden for relative in plugin_root.rglob("*")):
            raise RuntimeError(f"{variant.key} unexpectedly emitted runtime Composer input: {forbidden}")
    return {
        "classmapEntries": len(classmap),
        "packagePhpBytes": package_php_bytes,
        "packagePhpFileCount": len(php_files),
        "packageTreeSha256": tree_digest(plugin_root),
        "globalPolyfillSha256": polyfill_digest,
        "prefix": prefix,
        "prefixDerivationSha256": derivation_digest,
        "privateClass": private_class,
        "privatePhpBytes": private_php_bytes,
        "privatePhpFileCount": len(private_php_files),
        "projectId": variant.project_id,
        "moduleId": variant.module_id,
        "slug": variant.slug,
        "version": variant.version,
        "expectedMarker": variant.expected_marker,
        "publicBootstrapClass": variant.public_namespace + "\\Bootstrap",
        "publicBridgeClass": variant.public_namespace + "\\PrivateBridge",
    }


def prepare_output(output_root: Path) -> None:
    if output_root.is_symlink():
        raise RuntimeError(f"fixture output cannot be a link: {output_root}")
    if output_root.exists():
        if not output_root.is_dir():
            raise RuntimeError(f"fixture output must be a directory: {output_root}")
        if any(output_root.iterdir()):
            raise RuntimeError(f"fixture output must be empty: {output_root}")
    else:
        output_root.mkdir(parents=True)
    output_root.chmod(0o755)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output_root = args.output.resolve()
    prepare_output(output_root)
    require_haxe()
    results = [build_variant(variant, output_root) for variant in VARIANTS]
    prefixes = {str(result["prefix"]).lower() for result in results}
    if len(prefixes) != len(results):
        raise RuntimeError("derived private runtime prefixes collided")
    write_text(
        output_root / "build-summary.json",
        canonical_json(
            {
                "schema": "wordpress-hx.adr018-fixture-build.v1",
                "haxeVersion": "4.3.7",
                "runtimeComposerGraph": "absent-no-runtime-dependencies",
                "stockFrontControllersPackaged": False,
                "variants": results,
            }
        ),
    )
    print(canonical_json(json.loads((output_root / "build-summary.json").read_text(encoding="utf-8"))), end="")


if __name__ == "__main__":
    main()
