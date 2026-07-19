#!/usr/bin/env python3
"""Focused fail-closed tests for release input and dependency validation."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.dont_write_bytecode = True
SCRIPT_PATH = Path(__file__).with_name("build-package.py")
SPEC = importlib.util.spec_from_file_location("reflaxe_php_package_builder", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("could not load reflaxe.php package builder")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class PackageBuilderTest(unittest.TestCase):
    def write_metadata(self, root: Path, dependencies: dict[str, str]) -> Path:
        path = root / "haxelib.json"
        path.write_text(
            json.dumps(
                {
                    "name": "reflaxe.php",
                    "version": "0.0.0",
                    "dependencies": dependencies,
                }
            ),
            encoding="utf-8",
        )
        return path

    def test_exact_dependency_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory(prefix="reflaxe-php-package-builder-") as temporary:
            root = Path(temporary)
            self.write_metadata(root, {"fixture": "1.2.3"})
            metadata = BUILDER.validate_metadata(root)
            self.assertEqual(metadata["dependencies"], {"fixture": "1.2.3"})

    def test_floating_dependency_is_rejected(self) -> None:
        for version in ("dev", "^1.2.3", "../fixture", "git:main"):
            with self.subTest(version=version):
                with tempfile.TemporaryDirectory(prefix="reflaxe-php-package-builder-") as temporary:
                    root = Path(temporary)
                    self.write_metadata(root, {"fixture": version})
                    with self.assertRaisesRegex(BUILDER.PackageFailure, "exact version"):
                        BUILDER.validate_metadata(root)

    def test_machine_local_release_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="reflaxe-php-package-builder-") as temporary:
            root = Path(temporary)
            input_path = root / "README.md"
            input_path.write_text("/" + "Users/example/private/compiler", encoding="utf-8")
            with self.assertRaisesRegex(BUILDER.PackageFailure, "machine-local path"):
                BUILDER.validate_portable_inputs(root, [input_path])


if __name__ == "__main__":
    unittest.main()
