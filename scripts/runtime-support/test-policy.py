#!/usr/bin/env python3
"""Exercise ADR-018's policy validator with fail-closed mutations."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "scripts/runtime-support/check-policy.py"
FILES = (
    "manifests/runtime-support-packaging.json",
    "manifests/php-emission-policy.json",
    "manifests/toolchain.lock.json",
    "docs/adr/018-runtime-support-packaging.md",
    "fixtures/runtime-support-packaging/README.md",
    "fixtures/runtime-support-packaging/src/fixture/privateimpl/Main.hx",
    "scripts/runtime-support/build-fixtures.py",
)
POLICY = Path("manifests/runtime-support-packaging.json")
ADR = Path("docs/adr/018-runtime-support-packaging.md")
HAXE = Path("fixtures/runtime-support-packaging/src/fixture/privateimpl/Main.hx")


def make_fixture(destination: Path) -> None:
    for relative_source in FILES:
        relative = Path(relative_source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)


def read_policy(root: Path) -> dict[str, Any]:
    return json.loads((root / POLICY).read_text(encoding="utf-8"))


def write_policy(root: Path, policy: dict[str, Any]) -> None:
    (root / POLICY).write_text(
        json.dumps(policy, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def mutate_policy(root: Path, change: Callable[[dict[str, Any]], None]) -> None:
    policy = read_policy(root)
    change(policy)
    write_policy(root, policy)


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
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr018-policy-") as raw:
        fixture = Path(raw)
        make_fixture(fixture)
        mutate(fixture)
        result = run(fixture)
        transcript = result.stdout + result.stderr
        if result.returncode == 0:
            raise AssertionError(f"negative policy fixture passed: {label}")
        if expected not in transcript:
            raise AssertionError(
                f"negative policy fixture {label!r} missed {expected!r}:\n{transcript}"
            )


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr018-policy-") as raw:
        fixture = Path(raw)
        make_fixture(fixture)
        positive = run(fixture)
        if positive.returncode != 0:
            raise AssertionError(positive.stdout + positive.stderr)

    expect_rejected(
        "user runtime config required",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["authoring"].__setitem__(
                "userAuthoredRuntimeConfigRequired", True
            ),
        ),
        "Haxe common path cannot require userAuthoredRuntimeConfigRequired",
    )
    expect_rejected(
        "shared runtime admitted",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["mvpPackage"].__setitem__(
                "sharedSiteRuntimeAllowed", True
            ),
        ),
        "shared site runtime is forbidden for MVP",
    )
    expect_rejected(
        "content-churning namespace",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["namespace"].__setitem__(
                "contentOrVersionIncluded", True
            ),
        ),
        "ordinary edits cannot churn the private namespace",
    )
    expect_rejected(
        "stock front packaged",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["autoload"].__setitem__(
                "stockFrontControllerPackaged", True
            ),
        ),
        "stock Haxe front cannot be packaged",
    )
    expect_rejected(
        "process include path enabled",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["autoload"].__setitem__(
                "processIncludePathMutation", True
            ),
        ),
        "autoload must not enable processIncludePathMutation",
    )
    expect_rejected(
        "runtime Composer graph smuggled in",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["composer"].__setitem__(
                "mvpRuntimeGraph", "composer-lock"
            ),
        ),
        "MVP runtime Composer graph must remain absent",
    )
    expect_rejected(
        "vendor directories mistaken for isolation",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["composer"].__setitem__(
                "separateVendorDirectoriesCountAsIsolation", True
            ),
        ),
        "separate vendor directories cannot be mistaken",
    )
    expect_rejected(
        "private name exposed in ABI",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["publicBoundary"].__setitem__(
                "privateNamesAllowedInPublicAbi", True
            ),
        ),
        "private support names cannot leak into public ABI",
    )
    expect_rejected(
        "private callback registered",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["publicBoundary"].__setitem__(
                "privateCallbacksRegisteredWithWordPress", True
            ),
        ),
        "private callbacks cannot be registered with WordPress",
    )
    expect_rejected(
        "global polyfill conflict allowed to boot",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["globalSymbols"].__setitem__(
                "differentHashDisposition", "continue-private-boot"
            ),
        ),
        "incompatible global polyfills must reject private boot with WPHX5201",
    )
    expect_rejected(
        "package ceiling widened",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["budgets"].__setitem__(
                "serverOnlyStarterGeneratedPhpRuntimeMaxBytes", 819200
            ),
        ),
        "PRD 400 KiB generated PHP/runtime ceiling changed",
    )
    expect_rejected(
        "shared runtime bypasses ADR",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["futureSharedRuntime"].__setitem__(
                "requiresSupersedingAdr", False
            ),
        ),
        "shared runtime requires a superseding ADR",
    )
    expect_rejected(
        "publication pre-authorized",
        lambda root: mutate_policy(
            root,
            lambda policy: policy["evidence"].__setitem__(
                "publicationAuthorized", True
            ),
        ),
        "ADR-018 cannot authorize publication",
    )
    expect_rejected(
        "ADR status regressed",
        lambda root: (root / ADR).write_text(
            (root / ADR)
            .read_text(encoding="utf-8")
            .replace("- Status: accepted", "- Status: proposed", 1),
            encoding="utf-8",
        ),
        "ADR-018 is missing required decision text: - Status: accepted",
    )
    expect_rejected(
        "weak Haxe token added",
        lambda root: (root / HAXE).write_text(
            (root / HAXE).read_text(encoding="utf-8")
            + "\nclass WeakBoundary { final value:Dynamic; }\n",
            encoding="utf-8",
        ),
        "strict Haxe private fixture contains forbidden token: Dynamic",
    )
    expect_rejected(
        "manual retention ceremony added",
        lambda root: (root / HAXE).write_text(
            (root / HAXE)
            .read_text(encoding="utf-8")
            .replace("class Main", "@:keep\nclass Main", 1),
            encoding="utf-8",
        ),
        "fixture author must not manually retain the private entry",
    )
    expect_rejected(
        "Composer manifest added to fixture",
        lambda root: (
            (root / "fixtures/runtime-support-packaging/composer.json").write_text(
                "{}\n", encoding="utf-8"
            )
        ),
        "MVP runtime-support fixture contains forbidden Composer artifact",
    )

    print("ADR-018 runtime-support policy tests passed (1 positive, 17 negative)")


if __name__ == "__main__":
    main()
