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

DEPENDENCY_SCRIPT_PATH = Path(__file__).with_name("package-installed-haxelib.py")
DEPENDENCY_SPEC = importlib.util.spec_from_file_location(
    "reflaxe_php_installed_haxelib_packager", DEPENDENCY_SCRIPT_PATH
)
if DEPENDENCY_SPEC is None or DEPENDENCY_SPEC.loader is None:
    raise RuntimeError("could not load installed Haxelib packager")
DEPENDENCY_PACKAGER = importlib.util.module_from_spec(DEPENDENCY_SPEC)
DEPENDENCY_SPEC.loader.exec_module(DEPENDENCY_PACKAGER)


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

    def test_unsafe_dependency_name_is_rejected(self) -> None:
        for name in ("../fixture", "fixture/name", "fixture name"):
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory(prefix="reflaxe-php-package-builder-") as temporary:
                    root = Path(temporary)
                    self.write_metadata(root, {name: "1.2.3"})
                    with self.assertRaisesRegex(BUILDER.PackageFailure, "dependency name"):
                        BUILDER.validate_metadata(root)

    def test_machine_local_release_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="reflaxe-php-package-builder-") as temporary:
            root = Path(temporary)
            input_path = root / "README.md"
            input_path.write_text("/" + "Users/example/private/compiler", encoding="utf-8")
            with self.assertRaisesRegex(BUILDER.PackageFailure, "machine-local path"):
                BUILDER.validate_portable_inputs(root, [input_path])

    def test_complete_license_is_a_required_package_document(self) -> None:
        self.assertIn("COPYING", BUILDER.PACKAGE_DOCUMENTS)
        copying = SCRIPT_PATH.parent.parent / "COPYING"
        self.assertEqual(
            BUILDER.sha256_bytes(copying.read_bytes()),
            "edaef632cbb643e4e7a221717a6c441a4c1a7c918e6e4d56debc3d8739b233f6",
        )

    def write_dependency_metadata(
        self, root: Path, name: str, version: str, dependencies: dict[str, str]
    ) -> None:
        (root / "haxelib.json").write_text(
            json.dumps(
                {
                    "name": name,
                    "version": version,
                    "dependencies": dependencies,
                }
            ),
            encoding="utf-8",
        )

    def test_installed_dependency_archive_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory(prefix="reflaxe-php-dependency-seed-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            self.write_dependency_metadata(source, "fixture", "1.2.3", {})
            (source / "Fixture.hx").write_text("class Fixture {}\n", encoding="utf-8")
            first = root / "first.zip"
            second = root / "second.zip"

            DEPENDENCY_PACKAGER.package(source, first, "fixture", "1.2.3")
            DEPENDENCY_PACKAGER.package(source, second, "fixture", "1.2.3")

            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_installed_dependency_identity_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="reflaxe-php-dependency-seed-") as temporary:
            source = Path(temporary)
            self.write_dependency_metadata(source, "fixture", "1.2.4", {})
            with self.assertRaisesRegex(
                DEPENDENCY_PACKAGER.DependencyPackageFailure, "identity does not match"
            ):
                DEPENDENCY_PACKAGER.validate_source(source, "fixture", "1.2.3")

    def test_transitive_dependency_seed_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="reflaxe-php-dependency-seed-") as temporary:
            source = Path(temporary)
            self.write_dependency_metadata(source, "fixture", "1.2.3", {"other": "2.0.0"})
            with self.assertRaisesRegex(
                DEPENDENCY_PACKAGER.DependencyPackageFailure,
                "transitive dependencies",
            ):
                DEPENDENCY_PACKAGER.validate_source(source, "fixture", "1.2.3")


if __name__ == "__main__":
    unittest.main()
