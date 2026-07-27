#!/usr/bin/env python3
"""Determinism, completeness, and fail-closed tests for the build inventory."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "scripts/licenses/generate-build-input-inventory.py"
INVENTORY = ROOT / "LICENSES/inventory/build-inputs.json"
SBOM = ROOT / "LICENSES/sbom/build-inputs.spdx.json"


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def run(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(GENERATOR), "--root", str(ROOT), *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def tracked_sources() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    fixed = {
        "docker/images.lock.json",
        "fixtures/generated-output-vcs/project/wordpress-hx.fixture-lock.json",
        "manifests/toolchain.lock.json",
        "manifests/upstream.lock.json",
        "profiles/classification-decision-lock.json",
        "profiles/decision-lock.json",
        "tooling/beads/history-reader.lock.json",
    }
    basenames = {
        "composer.lock",
        "dependency-lock.json",
        "haxelib.json",
        "npm-lock.json",
        "package-lock.json",
        "project.lock.json",
        "source.lock.json",
    }
    paths = [
        value.decode("utf-8")
        for value in result.stdout.split(b"\0")
        if value
    ]
    return sorted(
        relative
        for relative in paths
        if relative in fixed or Path(relative).name in basenames
    )


def main() -> int:
    current = run()
    expect(current.returncode == 0, current.stderr)

    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))
    sbom = json.loads(SBOM.read_text(encoding="utf-8"))
    sources = [value["path"] for value in inventory["sources"]]
    expect(sources == tracked_sources(), "inventory source discovery is incomplete")
    expect(
        inventory["summary"]["sourceCount"] == len(sources),
        "source summary differs",
    )
    expect(
        inventory["summary"]["uniqueComponentCount"]
        == len(inventory["components"])
        == len(sbom["packages"]),
        "inventory and SPDX component counts differ",
    )
    expect(
        len(sbom["relationships"]) == len(sbom["packages"]),
        "every SPDX package must be described",
    )

    unresolved = {
        value["id"]
        for value in inventory["components"]
        if value["licenseEvidenceStatus"]
        == "missing-license-declaration-publication-blocked"
    }
    expect(
        unresolved == set(inventory["unresolvedLicenseEvidence"]),
        "unresolved license evidence summary differs",
    )
    expect(
        unresolved == set(),
        "every lock metadata gap must bind exact component evidence",
    )
    conflicts = {
        value["id"]
        for value in inventory["components"]
        if value["licenseEvidenceStatus"]
        == "multiple-declarations-require-artifact-review"
    }
    expect(
        len(conflicts) >= 3,
        "metadata/text conflicts must remain explicit for independent review",
    )

    genes_versions = {
        value["version"]
        for value in inventory["components"]
        if value["name"] == "genes-ts"
    }
    expect(
        {"1.33.0", "1.38.0"}.issubset(genes_versions),
        "inventory must expose both baseline and active Genes identities",
    )

    with tempfile.TemporaryDirectory(prefix="wordpresshx-build-inputs-") as temporary:
        first_inventory = Path(temporary) / "first.json"
        first_sbom = Path(temporary) / "first.spdx.json"
        second_inventory = Path(temporary) / "second.json"
        second_sbom = Path(temporary) / "second.spdx.json"
        first = run(
            "--write",
            "--inventory",
            str(first_inventory),
            "--sbom",
            str(first_sbom),
        )
        second = run(
            "--write",
            "--inventory",
            str(second_inventory),
            "--sbom",
            str(second_sbom),
        )
        expect(first.returncode == 0, first.stderr)
        expect(second.returncode == 0, second.stderr)
        expect(
            first_inventory.read_bytes() == second_inventory.read_bytes(),
            "two inventory generations differ",
        )
        expect(
            first_sbom.read_bytes() == second_sbom.read_bytes(),
            "two SPDX generations differ",
        )

        mutated = json.loads(first_inventory.read_text(encoding="utf-8"))
        mutated["sources"].pop()
        first_inventory.write_text(
            json.dumps(mutated, indent=2) + "\n",
            encoding="utf-8",
        )
        rejected = run(
            "--inventory",
            str(first_inventory),
            "--sbom",
            str(first_sbom),
        )
        expect(rejected.returncode == 1, "omitted source mutation passed")
        expect("stale" in rejected.stderr, "omitted source mutation lacked stale error")

        portable_root = Path(temporary) / "portable"
        portable_inventory = portable_root / "LICENSES/inventory/build-inputs.json"
        portable_sbom = portable_root / "LICENSES/sbom/build-inputs.spdx.json"
        portable_inventory.parent.mkdir(parents=True)
        portable_sbom.parent.mkdir(parents=True)
        shutil.copy2(INVENTORY, portable_inventory)
        shutil.copy2(SBOM, portable_sbom)
        shutil.copytree(ROOT / "LICENSES", portable_root / "LICENSES", dirs_exist_ok=True)
        for source in sources:
            target = portable_root / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
        portable = subprocess.run(
            [
                sys.executable,
                str(GENERATOR),
                "--root",
                str(portable_root),
            ],
            cwd=portable_root,
            text=True,
            capture_output=True,
            check=False,
        )
        expect(
            portable.returncode == 0,
            "portable no-.git inventory replay failed:\n"
            + portable.stdout
            + portable.stderr,
        )

    print(
        "build-input inventory tests passed: tracked completeness, deterministic "
        "SPDX, portable replay, active/baseline identity exposure, and omission "
        "rejection"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
