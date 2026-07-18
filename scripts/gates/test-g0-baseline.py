#!/usr/bin/env python3
"""Exercise the G0 baseline validator and representative fail-closed mutations."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = Path("scripts/gates/check-g0-baseline.py")


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(root / VALIDATOR), "--root", str(root)],
        cwd=root,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def copy_repository(destination: Path) -> None:
    ignored = shutil.ignore_patterns(
        ".beads",
        ".git",
        ".haxelib",
        ".lix",
        "__pycache__",
        "build",
        "node_modules",
    )
    shutil.copytree(ROOT, destination, ignore=ignored)


def mutate_json(root: Path, relative: str, mutate: Callable[[dict], None]) -> None:
    path = root / relative
    value = json.loads(path.read_text(encoding="utf-8"))
    mutate(value)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def negative_case(
    name: str,
    mutate: Callable[[Path], None],
    expected_error: str,
) -> None:
    with tempfile.TemporaryDirectory(prefix=f"wordpresshx-g0-{name}-") as temporary:
        root = Path(temporary) / "repo"
        copy_repository(root)
        mutate(root)
        result = run(root)
        if result.returncode == 0:
            raise AssertionError(f"{name}: validator unexpectedly passed")
        if expected_error not in result.stderr:
            raise AssertionError(
                f"{name}: missing diagnostic {expected_error!r}\n{result.stderr}"
            )


def main() -> int:
    positive = run(ROOT)
    if positive.returncode != 0:
        raise AssertionError(f"positive G0 validation failed\n{positive.stderr}")

    negative_case(
        "floating-haxe",
        lambda root: mutate_json(
            root,
            "manifests/toolchain.lock.json",
            lambda value: value["compilers"]["haxe"].__setitem__("version", "latest"),
        ),
        "Haxe compiler must be exactly 4.3.7",
    )
    negative_case(
        "tag-only-node",
        lambda root: mutate_json(
            root,
            "manifests/toolchain.lock.json",
            lambda value: value["runtimeImages"]["node"].__setitem__(
                "reference", "docker.io/library/node:22.17.0-bookworm-slim"
            ),
        ),
        "Node must use the reviewed digest reference",
    )
    negative_case(
        "implicit-composer",
        lambda root: mutate_json(
            root,
            "manifests/toolchain.lock.json",
            lambda value: value["dependencyGraphs"]["composer"].__setitem__(
                "status", "active-without-lock"
            ),
        ),
        "Composer graph must be explicitly inactive at G0",
    )

    def add_unlocked_npm_graph(root: Path) -> None:
        path = root / "fixtures/unlocked-npm/package.json"
        path.parent.mkdir(parents=True)
        path.write_text('{"private": true}\n', encoding="utf-8")

    negative_case(
        "unlocked-npm-graph",
        add_unlocked_npm_graph,
        "unlocked package.json found",
    )
    negative_case(
        "missing-decision",
        lambda root: mutate_json(
            root,
            "manifests/evidence/g0-product-baseline.json",
            lambda value: value["acceptance"]["acceptedDecisions"].remove("ADR-003"),
        ),
        "G0 accepted-decision set changed",
    )

    def add_port_coupling(root: Path) -> None:
        path = root / "compiler/reflaxe.php/src/reflaxe/php/Coupled.hx"
        path.write_text(
            "package reflaxe.php;\nimport wphx.compiler.php.WphxPhpCompiler;\n",
            encoding="utf-8",
        )

    negative_case(
        "port-coupling",
        add_port_coupling,
        "full-port coupling pattern 'wphx.compiler'",
    )
    def invent_hosted_proof(root: Path) -> None:
        def mutate(value: dict) -> None:
            invented_commit = "0" * 40
            value["status"] = "verified"
            value["claims"]["g0ProductAuthorityAndBaseline"] = "verified"
            value["implementation"]["commit"] = invented_commit
            value["hostedWorkflow"] = {
                "workflow": "repository.yml",
                "runId": None,
                "commit": invented_commit,
                "status": "passed",
                "fullMatrixStatus": "passed",
                "jobCount": 10,
            }

        mutate_json(root, "manifests/evidence/g0-product-baseline.json", mutate)

    negative_case(
        "invented-hosted-proof",
        invent_hosted_proof,
        "verified G0 receipt needs a hosted run ID",
    )
    negative_case(
        "publication-bypass",
        lambda root: mutate_json(
            root,
            "manifests/evidence/g0-product-baseline.json",
            lambda value: value["publicationBoundary"].__setitem__(
                "publicPackagePublicationAuthorized", True
            ),
        ),
        "G0 licensing/publication boundary changed",
    )

    print("G0 baseline tests passed: 1 positive and 8 fail-closed mutations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
