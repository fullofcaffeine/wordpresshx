#!/usr/bin/env python3
"""Validate ADR-002's immutable identities and fail-closed selection rules."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = ROOT / "profiles" / "decision-lock.json"


class PolicyError(ValueError):
    pass


def require_profile(
    policy: dict[str, object],
    selections: list[str],
    required_availability: list[set[str]],
    *,
    ci: bool,
) -> str:
    if ci and not selections:
        raise PolicyError("CI requires an explicit compatibility profile")
    if len(selections) != 1:
        raise PolicyError("each artifact requires exactly one compatibility profile")

    selected = selections[0]
    profiles = policy["profiles"]
    if not isinstance(profiles, dict) or selected not in profiles:
        raise PolicyError(f"unknown compatibility profile: {selected}")
    for available_in in required_availability:
        if selected not in available_in:
            raise PolicyError(f"required capability is unavailable in {selected}")
    return selected


def expect_rejected(run, label: str) -> None:
    try:
        run()
    except PolicyError:
        return
    raise AssertionError(f"negative profile fixture did not fail closed: {label}")


def main() -> None:
    policy = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    profiles = policy["profiles"]
    selection = policy["selectionPolicy"]

    assert policy["schemaVersion"] == 1
    assert policy["decision"] == "ADR-002"
    assert policy["status"] == "accepted-architecture"
    assert policy["claim"] == "not-tested"
    assert policy["catalogContractStatus"] == (
        "schema-v1-implemented-catalog-generation-pending"
    )

    assert set(profiles) == {"wp70-release", "gutenberg-forward-23.4"}
    assert profiles["wp70-release"]["catalogRevision"] == "wp70-release/catalog-v1"
    assert (
        profiles["wp70-release"]["wordpress"]["commit"]
        == "26b68024931348d267b70e2a29910e1320d0094f"
    )
    assert (
        profiles["wp70-release"]["embeddedGutenberg"]["commit"]
        == "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd"
    )
    assert (
        profiles["gutenberg-forward-23.4"]["catalogRevision"]
        == "gutenberg-forward-23.4/catalog-v1"
    )
    assert (
        profiles["gutenberg-forward-23.4"]["gutenberg"]["commit"]
        == "98a796c8780c480ef7bcfe03c42302d9564d785c"
    )
    assert profiles["gutenberg-forward-23.4"]["gutenberg"]["tag"] == "v23.4.0"

    assert selection["profilesArePeers"] is True
    assert selection["profileInheritance"] is False
    assert selection["exactlyOneCompatibilityTargetPerArtifact"] is True
    assert selection["combinedTargetAllowedDuringMvp"] is False
    assert selection["ciRequiresExplicitSelection"] is True
    assert selection["generatedProjectPersistsSelection"] is True
    assert selection["runtimeDetectionSatisfiesCompileTimeRequirements"] is False

    both = {"wp70-release", "gutenberg-forward-23.4"}
    vanilla_only = {"wp70-release"}
    forward_only = {"gutenberg-forward-23.4"}
    assert require_profile(policy, ["wp70-release"], [both, vanilla_only], ci=True) == "wp70-release"
    assert (
        require_profile(
            policy,
            ["gutenberg-forward-23.4"],
            [both, forward_only],
            ci=True,
        )
        == "gutenberg-forward-23.4"
    )

    expect_rejected(lambda: require_profile(policy, [], [both], ci=True), "implicit CI selection")
    expect_rejected(
        lambda: require_profile(
            policy,
            ["wp70-release", "gutenberg-forward-23.4"],
            [both],
            ci=True,
        ),
        "mixed compatibility target",
    )
    expect_rejected(
        lambda: require_profile(policy, ["wp70-release"], [forward_only], ci=True),
        "forward capability in vanilla artifact",
    )
    expect_rejected(
        lambda: require_profile(
            policy,
            ["gutenberg-forward-23.4"],
            [vanilla_only],
            ci=True,
        ),
        "vanilla capability inferred for forward profile",
    )
    expect_rejected(
        lambda: require_profile(policy, ["wordpress-latest"], [both], ci=True),
        "unknown or floating profile",
    )

    print("ADR-002 exact-profile decision lock passed")


if __name__ == "__main__":
    main()
