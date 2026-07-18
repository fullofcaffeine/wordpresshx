#!/usr/bin/env python3
"""Exercise ADR-005's policy validator with positive and negative fixtures."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "scripts/php/check-emission-policy.py"
MANIFEST = "manifests/php-emission-policy.json"
ADR = "docs/adr/005-public-versus-private-php-emission.md"


def make_fixture(destination: Path) -> None:
    for relative in (MANIFEST, ADR):
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)
    generic = destination / "compiler/reflaxe.php/src/reflaxe/php/Neutral.hx"
    generic.parent.mkdir(parents=True, exist_ok=True)
    generic.write_text(
        "package reflaxe.php;\n\nclass Neutral {}\n", encoding="utf-8"
    )


def read_policy(root: Path) -> dict[str, Any]:
    return json.loads((root / MANIFEST).read_text(encoding="utf-8"))


def write_policy(root: Path, policy: dict[str, Any]) -> None:
    (root / MANIFEST).write_text(
        json.dumps(policy, indent=2, sort_keys=False) + "\n", encoding="utf-8"
    )


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(CHECKER), "--root", str(root)],
        check=False,
        capture_output=True,
        text=True,
    )


def expect_rejected(
    label: str,
    mutate: Callable[[Path], None],
    expected: str,
) -> None:
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr005-") as raw:
        fixture = Path(raw)
        make_fixture(fixture)
        mutate(fixture)
        result = run(fixture)
        transcript = result.stdout + result.stderr
        if result.returncode == 0:
            raise AssertionError(f"negative fixture passed: {label}")
        if expected not in transcript:
            raise AssertionError(
                f"negative fixture {label!r} missed {expected!r}:\n{transcript}"
            )


def mutate_policy(root: Path, change: Callable[[dict[str, Any]], None]) -> None:
    policy = read_policy(root)
    change(policy)
    write_policy(root, policy)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr005-") as raw:
        fixture = Path(raw)
        make_fixture(fixture)
        positive = run(fixture)
        if positive.returncode != 0:
            raise AssertionError(positive.stdout + positive.stderr)

    expect_rejected(
        "stock Haxe enters public lane",
        lambda root: mutate_policy(
            root,
            lambda value: value["publicNativeLane"].__setitem__(
                "stockHaxePhpAllowed", True
            ),
        ),
        "public native lane cannot use stock Haxe PHP",
    )
    expect_rejected(
        "template boundary omitted",
        lambda root: mutate_policy(
            root,
            lambda value: value["publicNativeLane"]["inventory"].remove(
                "theme-admin-and-mixed-php-html-templates"
            ),
        ),
        "public boundary inventory differs",
    )
    expect_rejected(
        "unknown classification defaults private",
        lambda root: mutate_policy(
            root,
            lambda value: value["classification"].__setitem__(
                "unknownDisposition", "private-stock-haxe"
            ),
        ),
        "unknown boundary classification must reject",
    )
    expect_rejected(
        "hook callback admitted privately",
        lambda root: mutate_policy(
            root,
            lambda value: value["privateStockHaxeLane"]["forbiddenUses"].remove(
                "hook-or-lifecycle-callback"
            ),
        ),
        "private forbidden-use inventory differs",
    )
    expect_rejected(
        "adapter defers native conversion",
        lambda root: mutate_policy(
            root,
            lambda value: value["adapterContract"].__setitem__(
                "immediateNativeConversionRequired", False
            ),
        ),
        "adapter must convert native values immediately",
    )
    expect_rejected(
        "HXX ships a runtime parser",
        lambda root: mutate_policy(
            root,
            lambda value: value["serverHxx"].__setitem__(
                "runtimeParserOrVdomShipped", True
            ),
        ),
        "server HXX cannot ship a parser or VDOM runtime",
    )
    expect_rejected(
        "architecture pre-claims runtime evidence",
        lambda root: mutate_policy(
            root,
            lambda value: value["requiredG1Evidence"][0].__setitem__(
                "status", "runtime-tested"
            ),
        ),
        "ADR acceptance cannot pre-advance G1 evidence",
    )
    expect_rejected(
        "private lane prematurely guaranteed",
        lambda root: mutate_policy(
            root,
            lambda value: value["privateStockHaxeLane"].__setitem__(
                "guaranteedAfter1_0", True
            ),
        ),
        "private stock-Haxe lane cannot be guaranteed after 1.0 yet",
    )
    expect_rejected(
        "publication bypass",
        lambda root: mutate_policy(
            root,
            lambda value: value["releaseBoundary"].__setitem__(
                "publicationAuthorized", True
            ),
        ),
        "publication must remain blocked",
    )
    expect_rejected(
        "ADR status regresses",
        lambda root: (root / ADR).write_text(
            (root / ADR)
            .read_text(encoding="utf-8")
            .replace("- Status: accepted", "- Status: proposed", 1),
            encoding="utf-8",
        ),
        "ADR-005 must be accepted",
    )
    expect_rejected(
        "generic compiler gains WordPress coupling",
        lambda root: (
            root / "compiler/reflaxe.php/src/reflaxe/php/Coupled.hx"
        ).write_text(
            "package reflaxe.php;\nclass Coupled { "
            "static final hook = 'wordpress_init'; }\n",
            encoding="utf-8",
        ),
        "generic compiler contains WordPress/profile coupling",
    )

    print("ADR-005 PHP emission policy tests passed (1 positive, 11 negative)")


if __name__ == "__main__":
    main()
