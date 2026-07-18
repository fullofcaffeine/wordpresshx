#!/usr/bin/env python3
"""Positive and fail-closed mutation tests for the ADR-020 policy gate."""

from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "scripts/licenses/check-license-policy.py"
POLICY_PATH = ROOT / "LICENSES/policy.json"
COMPONENTS_PATH = ROOT / "LICENSES/components.json"
GOLDEN_PATH = ROOT / "fixtures/licenses/expected/publication-blocked.txt"


def load_checker_module() -> Any:
    spec = importlib.util.spec_from_file_location("wordpresshx_license_checker", CHECKER)
    if spec is None or spec.loader is None:
        raise AssertionError("cannot load license policy checker module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_checker(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(CHECKER), "--root", str(ROOT), *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def run_mutation(
    name: str,
    policy: dict[str, Any],
    components: dict[str, Any],
    mutate: Callable[[dict[str, Any], dict[str, Any]], None],
) -> None:
    mutated_policy = copy.deepcopy(policy)
    mutated_components = copy.deepcopy(components)
    mutate(mutated_policy, mutated_components)
    with tempfile.TemporaryDirectory(prefix=f"wordpresshx-license-{name}-") as temporary:
        temp_root = Path(temporary)
        policy_path = temp_root / "policy.json"
        components_path = temp_root / "components.json"
        policy_path.write_text(
            json.dumps(mutated_policy, indent=2, sort_keys=False) + "\n",
            encoding="utf-8",
        )
        components_path.write_text(
            json.dumps(mutated_components, indent=2, sort_keys=False) + "\n",
            encoding="utf-8",
        )
        result = run_checker(
            "--policy",
            str(policy_path),
            "--components",
            str(components_path),
        )
    expect(result.returncode == 1, f"mutation {name} unexpectedly passed: {result.stdout}")
    expect("license audit error:" in result.stderr, f"mutation {name} lacked an audit error")


def main() -> int:
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    components = json.loads(COMPONENTS_PATH.read_text(encoding="utf-8"))
    checker = load_checker_module()

    expected_setup_commit = next(
        component["commit"]
        for component in components["components"]
        if component["id"] == "krdlab-setup-haxe-2.1.0"
    )
    duplicate_exact_workflow = "\n".join(
        [
            f"uses: krdlab/setup-haxe@{expected_setup_commit}",
            f"uses: krdlab/setup-haxe@{expected_setup_commit} # repeated exact use",
        ]
    )
    expect(
        checker.every_action_use_is_exact(
            duplicate_exact_workflow, "krdlab/setup-haxe", expected_setup_commit
        ),
        "repeated exact action pins must pass",
    )
    expect(
        not checker.every_action_use_is_exact(
            duplicate_exact_workflow + "\nuses: krdlab/setup-haxe@" + ("0" * 40),
            "krdlab/setup-haxe",
            expected_setup_commit,
        ),
        "one mismatched action pin among exact duplicates must fail",
    )
    expect(
        not checker.every_action_use_is_exact("", "krdlab/setup-haxe", expected_setup_commit),
        "an absent required action must fail",
    )

    normal = run_checker()
    expect(normal.returncode == 0, f"ordinary policy validation failed:\n{normal.stderr}")
    expect(
        "publication remains blocked" in normal.stdout,
        "ordinary validation did not state the blocked result",
    )

    publication = run_checker("--publication-gate")
    expected_publication = GOLDEN_PATH.read_text(encoding="utf-8")
    expect(publication.returncode == 3, "publication gate must exit with status 3")
    expect(publication.stderr == "", f"publication gate wrote unexpected stderr: {publication.stderr}")
    expect(
        publication.stdout == expected_publication,
        "publication gate output differs from the committed golden",
    )

    run_mutation(
        "enable-publication",
        policy,
        components,
        lambda candidate, _inventory: candidate["publication"].__setitem__("allowed", True),
    )
    run_mutation(
        "invent-reviewer",
        policy,
        components,
        lambda candidate, _inventory: candidate["qualifiedReview"].__setitem__(
            "reviewer", "Unverified Reviewer"
        ),
    )
    run_mutation(
        "accept-with-blockers",
        policy,
        components,
        lambda candidate, _inventory: candidate.__setitem__("status", "accepted"),
    )
    run_mutation(
        "remove-component",
        policy,
        components,
        lambda _candidate, inventory: inventory["components"].pop(),
    )
    run_mutation(
        "hide-finding",
        policy,
        components,
        lambda _candidate, inventory: inventory["unresolvedFindings"].pop(),
    )
    run_mutation(
        "upgrade-conflict-silently",
        policy,
        components,
        lambda _candidate, inventory: next(
            item for item in inventory["components"] if item["id"] == "tink-hxx-0.25.1"
        ).__setitem__("licenseConclusion", "verified-declaration-pending-qualified-review"),
    )
    run_mutation(
        "unsorted-components",
        policy,
        components,
        lambda _candidate, inventory: inventory["components"].reverse(),
    )
    run_mutation(
        "raw-output-override",
        policy,
        components,
        lambda candidate, _inventory: candidate["outputPolicy"].__setitem__(
            "rawLicenseOverrideAllowed", True
        ),
    )

    print(
        "license policy tests passed: 1 positive, 1 blocked gate, "
        "8 policy mutations, 3 action-pin cases"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
