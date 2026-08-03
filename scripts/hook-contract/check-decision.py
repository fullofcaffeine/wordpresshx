#!/usr/bin/env python3
"""Validate ADR-010's typed WordPress hook-contract decision."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
DECISION_PATH = ROOT / "manifests" / "hook-contract-decision.json"
ADR_PATH = ROOT / "docs" / "adr" / "010-hook-contract-model.md"


class DecisionError(RuntimeError):
    pass


def read_json(path: Path, label: str) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DecisionError(f"{label}: {error}") from error
    if not isinstance(value, dict):
        raise DecisionError(f"{label}: expected object")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise DecisionError(message)


def exact_keys(value: dict[str, object], expected: set[str], label: str) -> None:
    actual = set(value)
    require(
        actual == expected,
        f"{label}: keys differ; missing={sorted(expected - actual)}, "
        f"unknown={sorted(actual - expected)}",
    )


def object_value(
    value: dict[str, object], key: str, label: str
) -> dict[str, object]:
    nested = value.get(key)
    require(isinstance(nested, dict), f"{label}.{key}: expected object")
    return nested


def string_list(value: object, label: str) -> list[str]:
    require(isinstance(value, list), f"{label}: expected array")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{label}: expected non-empty strings",
    )
    return list(value)


def validate_source(decision: dict[str, object]) -> None:
    source = object_value(decision, "sourceAuthority", "decision")
    exact_keys(
        source,
        {"sourceLock", "wordpressCommit", "wordpressTree", "files"},
        "sourceAuthority",
    )
    lock = read_json(ROOT / str(source["sourceLock"]), "WordPress source lock")
    wordpress = object_value(lock, "wordpressSource", "source lock")
    require(
        source.get("wordpressCommit") == wordpress.get("commit"),
        "WordPress commit differs from exact profile lock",
    )
    require(
        source.get("wordpressTree") == wordpress.get("tree"),
        "WordPress tree differs from exact profile lock",
    )
    expected_files = {
        "src/wp-includes/class-wp-hook.php": (
            "cd6860c0f81f2401709debb4a40f4704ef249748",
            "a66fe7372af72876fc702e50943f9a2a8dff4ed7394163e07491b80a06e27f1d",
        ),
        "src/wp-includes/plugin.php": (
            "0ca495b6f76d44986ae3725973b525aa65fffe32",
            "2e06902ae7d65d7dad37cbafd8e8feff83e4aeeff3a7839885ce7fe4f0c94d68",
        ),
    }
    files = source.get("files")
    require(isinstance(files, list), "sourceAuthority.files must be an array")
    observed_files: dict[str, tuple[object, object]] = {}
    for raw in files:
        require(isinstance(raw, dict), "sourceAuthority.files entry must be object")
        exact_keys(raw, {"path", "blob", "sha256"}, "source file")
        observed_files[str(raw["path"])] = (raw["blob"], raw["sha256"])
    require(observed_files == expected_files, "exact WordPress hook sources changed")

    catalog = read_json(
        ROOT / "generated" / "wp70-release" / "catalog-v1" / "catalog.json",
        "wp70 catalog",
    )
    catalog_body = catalog.get("catalog")
    require(isinstance(catalog_body, dict), "wp70 catalog body is invalid")
    capabilities = catalog_body.get("capabilities")
    require(isinstance(capabilities, list), "wp70 capability inventory is invalid")
    add_functions = {
        item.get("capabilityId"): item
        for item in capabilities
        if isinstance(item, dict)
        and item.get("capabilityId")
        in ("wordpress.php.function.add_action", "wordpress.php.function.add_filter")
    }
    require(len(add_functions) == 2, "profile lost native hook registration functions")
    for capability in add_functions.values():
        provenance = capability.get("provenance")
        require(
            isinstance(provenance, list)
            and len(provenance) == 1
            and isinstance(provenance[0], dict)
            and provenance[0].get("sourceDigest")
            == expected_files["src/wp-includes/plugin.php"][1],
            "catalog registration provenance differs from pinned plugin.php",
        )


def validate_decision(decision: dict[str, object]) -> None:
    exact_keys(
        decision,
        {
            "schemaVersion",
            "decision",
            "bead",
            "status",
            "profileId",
            "sourceAuthority",
            "hookReferences",
            "acceptedArguments",
            "priority",
            "callbackIdentity",
            "customAndDynamicHooks",
            "nativeEmission",
            "implementation",
            "behaviorFirstEvidence",
            "claims",
        },
        "decision",
    )
    require(decision.get("schemaVersion") == 1, "decision schema changed")
    require(decision.get("decision") == "ADR-010", "decision identity changed")
    require(decision.get("bead") == "wordpresshx-adr-010", "Bead changed")
    require(
        decision.get("status") == "proposed-pending-independent-review",
        "decision status changed without reviewed authority",
    )
    require(decision.get("profileId") == "wp70-release", "profile changed")
    validate_source(decision)

    references = object_value(decision, "hookReferences", "decision")
    exact_keys(
        references,
        {
            "builtInAuthority",
            "actionType",
            "filterType",
            "actionReturn",
            "filterReturn",
            "filterValuePosition",
            "orderedArguments",
            "maximumArgumentsFromContract",
            "allHookStatus",
        },
        "hookReferences",
    )
    require(references.get("actionReturn") == "Void", "actions must return Void")
    require(
        references.get("filterReturn") == "same-filtered-value-type"
        and references.get("filterValuePosition") == 0,
        "filter value/return contract changed",
    )
    require(
        references.get("orderedArguments") is True
        and references.get("maximumArgumentsFromContract") is True,
        "hook argument contract weakened",
    )
    require(
        references.get("allHookStatus")
        == "withheld-pending-variadic-name-first-contract",
        "the special all hook was admitted without its contract",
    )

    accepted = object_value(decision, "acceptedArguments", "decision")
    exact_keys(
        accepted,
        {
            "default",
            "actionMinimum",
            "filterMinimum",
            "greaterThanContractMaximum",
            "smallerThanCallbackArity",
            "truncation",
            "nativeZeroArgumentBehavior",
        },
        "acceptedArguments",
    )
    require(
        accepted.get("default") == "infer-exact-callback-arity",
        "accepted_args is no longer inferred",
    )
    require(
        accepted.get("actionMinimum") == 0 and accepted.get("filterMinimum") == 1,
        "action/filter minimum arity changed",
    )
    require(
        accepted.get("truncation")
        == "explicit-prefix-only-and-preserves-ordered-types",
        "truncation contract weakened",
    )

    priority = object_value(decision, "priority", "decision")
    exact_keys(
        priority,
        {
            "haxeType",
            "representation",
            "domain",
            "presets",
            "presetBoundaryClaim",
            "lowerExecutesEarlier",
            "samePriority",
            "changedPriorityRemoval",
        },
        "priority",
    )
    require(
        priority.get("representation") == "abstract-over-signed-Haxe-Int"
        and priority.get("domain") == "open-signed-int-not-enum",
        "priority became closed or unsigned",
    )
    require(
        priority.get("presets") == {"Earliest": -100, "Default": 10, "Late": 100},
        "priority presets changed",
    )
    require(priority.get("presetBoundaryClaim") is False, "preset became a false bound")
    require(
        priority.get("lowerExecutesEarlier") is True
        and priority.get("samePriority") == "registration-order",
        "native priority ordering changed",
    )

    identity = object_value(decision, "callbackIdentity", "decision")
    exact_keys(
        identity,
        {
            "removableForms",
            "removalKey",
            "acceptedArgumentsInRemovalKey",
            "removalResult",
            "anonymousPolicy",
            "subscriptionOwnsExactRegistration",
        },
        "callbackIdentity",
    )
    require(
        string_list(identity.get("removalKey"), "callbackIdentity.removalKey")
        == ["hook-name", "callback-identity", "registration-priority"],
        "native removal key changed",
    )
    require(
        identity.get("acceptedArgumentsInRemovalKey") is False
        and identity.get("removalResult") == "Bool",
        "removal semantics changed",
    )
    require(
        identity.get("anonymousPolicy") == "PermanentListener-without-removal-api",
        "anonymous callback removability was overstated",
    )

    custom = object_value(decision, "customAndDynamicHooks", "decision")
    exact_keys(
        custom,
        {
            "projectContract",
            "thirdPartyContract",
            "dynamicNames",
            "arbitraryRuntimeConcatenation",
            "requiredProvenance",
        },
        "customAndDynamicHooks",
    )
    require(
        custom.get("arbitraryRuntimeConcatenation") is False
        and custom.get("dynamicNames") == "generated-typed-pattern-constructor",
        "dynamic hooks gained an arbitrary-string path",
    )
    require(
        custom.get("thirdPartyContract") == "ADR-015-adoption-bundle",
        "third-party authority changed",
    )
    require(
        set(string_list(custom.get("requiredProvenance"), "requiredProvenance"))
        == {
            "owner",
            "contract-version",
            "contract-digest",
            "kind",
            "ordered-argument-types",
            "return-type",
            "maximum-arguments",
            "source-or-declaration-span",
        },
        "custom hook provenance weakened",
    )

    emission = object_value(decision, "nativeEmission", "decision")
    exact_keys(
        emission,
        {
            "registrationFunctions",
            "removalFunctions",
            "literalOrTypedPatternName",
            "samePriorityOrderMustBeExplicitPlanData",
            "publicCallbackShape",
        },
        "nativeEmission",
    )
    require(
        emission.get("registrationFunctions") == ["add_action", "add_filter"]
        and emission.get("removalFunctions") == ["remove_action", "remove_filter"],
        "native hook functions changed",
    )
    require(
        emission.get("samePriorityOrderMustBeExplicitPlanData") is True,
        "same-priority order was delegated to incidental sorting",
    )

    implementation = object_value(decision, "implementation", "decision")
    exact_keys(implementation, {"implemented", "pendingBead", "pending"}, "implementation")
    require(
        implementation.get("pendingBead") == "wordpresshx-sdk-050",
        "implementation owner changed",
    )
    pending = set(string_list(implementation.get("pending"), "implementation.pending"))
    require(
        {
            "stable-subscription-and-native-removal",
            "explicit-same-priority-registration-order",
            "real-order-accepted-args-and-removal-runtime-matrix",
        }
        <= pending,
        "material hook work was marked implemented without proof",
    )

    behavior = object_value(decision, "behaviorFirstEvidence", "decision")
    exact_keys(
        behavior,
        {"redState", "oracle", "focusedOwner", "verticalOwner", "verticalStatus"},
        "behaviorFirstEvidence",
    )
    red = object_value(behavior, "redState", "behaviorFirstEvidence")
    exact_keys(
        red,
        {"baseCommit", "overlayFixture", "commandOwner", "exitCode", "diagnostic"},
        "redState",
    )
    require(
        red.get("baseCommit") == "48df6023f85ffa6de4c1554ae52776ec8b9046be"
        and red.get("exitCode") == 1
        and red.get("diagnostic") == "WPHX4017: hook priority cannot be negative",
        "red-state identity changed",
    )
    require(
        (ROOT / str(red["overlayFixture"])).is_file(),
        "red-state overlay fixture is missing",
    )
    require(
        behavior.get("oracle") == "pinned-WordPress-7.0-WP_Hook-priority-sorting"
        and behavior.get("verticalStatus") == "pending",
        "behavior evidence overstates the vertical",
    )

    claims = object_value(decision, "claims", "decision")
    exact_keys(
        claims,
        {
            "architectureDecision",
            "signedPriorityCollection",
            "actionFilterFixture",
            "removalAndTieOrdering",
            "broadWordPressHookCompatibility",
            "publication",
            "productionSupport",
        },
        "claims",
    )
    require(
        claims
        == {
            "architectureDecision": "pending-independent-review",
            "signedPriorityCollection": "compile-tested-local",
            "actionFilterFixture": "bounded-runtime-tested-historical-sdk-023",
            "removalAndTieOrdering": "not-tested-sdk-050",
            "broadWordPressHookCompatibility": "not-tested",
            "publication": "unsupported",
            "productionSupport": "not-tested",
        },
        "hook claims changed or broadened",
    )


def validate_repository() -> None:
    decision = read_json(DECISION_PATH, "hook decision lock")
    validate_decision(decision)

    adr = ADR_PATH.read_text(encoding="utf-8")
    require("- Status: proposed" in adr[:500], "ADR-010 is not proposed")
    for heading in (
        "## Context",
        "## Decision",
        "## Rationale",
        "## Alternatives considered",
        "## Consequences",
        "## Evidence and commands",
        "## Migration, rollback, and supersession",
        "## Follow-up beads",
    ):
        require(heading in adr, f"ADR-010 lacks {heading}")
    for required in (
        "ActionHook<Args>",
        "FilterHook<Value, ExtraArgs>",
        "PermanentListener",
        "remove_action",
        "remove_filter",
        "Same-priority callbacks execute in registration",
        "independent content-addressed compatibility review",
    ):
        require(required in adr, f"ADR-010 lacks {required}")

    v1 = read_json(
        ROOT / "schemas" / "semantic-nodes" / "hook.schema.json", "hook schema v1"
    )
    v2 = read_json(
        ROOT / "schemas" / "semantic-nodes" / "hook-v2.schema.json", "hook schema v2"
    )
    properties_v1 = v1.get("properties")
    properties_v2 = v2.get("properties")
    require(isinstance(properties_v1, dict), "hook schema v1 properties invalid")
    require(isinstance(properties_v2, dict), "hook schema v2 properties invalid")
    priority_v1 = properties_v1.get("priority")
    priority_v2 = properties_v2.get("priority")
    require(
        v1.get("$id") == "wordpress-hx.semantic-node.wordpress.hook.v1"
        and isinstance(priority_v1, dict)
        and priority_v1.get("minimum") == 0,
        "historical hook schema v1 changed",
    )
    require(
        v2.get("$id") == "wordpress-hx.semantic-node.wordpress.hook.v2"
        and priority_v2 == {"type": "integer"},
        "hook schema v2 does not admit the signed integer domain",
    )
    require(
        properties_v2.get("acceptedArgs") == {"type": "integer", "minimum": 0},
        "hook schema v2 weakened acceptedArgs",
    )

    collector = (
        ROOT
        / "packages"
        / "build"
        / "src"
        / "wordpress"
        / "hx"
        / "build"
        / "_internal"
        / "SemanticCollector.hx"
    ).read_text(encoding="utf-8")
    require(
        "wordpress-hx.semantic-node.wordpress.hook.v2" in collector,
        "collector does not emit hook schema v2",
    )
    require(
        "WPHX4017" not in collector and "priority cannot be negative" not in collector,
        "collector still rejects negative hook priority",
    )
    fixture = (
        ROOT
        / "fixtures"
        / "semantic-collector"
        / "src"
        / "fixtures"
        / "semanticcollector"
        / "SignedPriorityFixture.hx"
    ).read_text(encoding="utf-8")
    require("priority: -20" in fixture, "signed-priority fixture lost its vector")


def expect_failure(label: str, mutation: Callable[[dict[str, object]], None]) -> None:
    changed = copy.deepcopy(read_json(DECISION_PATH, "hook decision lock"))
    mutation(changed)
    try:
        validate_decision(changed)
    except DecisionError:
        return
    raise AssertionError(f"hook decision mutation unexpectedly passed: {label}")


def self_test() -> None:
    expect_failure(
        "action return",
        lambda value: object_value(value, "hookReferences", "decision").update(
            {"actionReturn": "Bool"}
        ),
    )
    expect_failure(
        "closed priority",
        lambda value: object_value(value, "priority", "decision").update(
            {"domain": "closed-enum"}
        ),
    )
    expect_failure(
        "acceptedArgs in removal key",
        lambda value: object_value(value, "callbackIdentity", "decision")[
            "removalKey"
        ].append("accepted-arguments"),
    )
    expect_failure(
        "arbitrary dynamic names",
        lambda value: object_value(value, "customAndDynamicHooks", "decision").update(
            {"arbitraryRuntimeConcatenation": True}
        ),
    )
    expect_failure(
        "missing tie order work",
        lambda value: object_value(value, "implementation", "decision")[
            "pending"
        ].remove("explicit-same-priority-registration-order"),
    )
    expect_failure(
        "publication",
        lambda value: object_value(value, "claims", "decision").update(
            {"publication": "supported"}
        ),
    )
    expect_failure(
        "source commit",
        lambda value: object_value(value, "sourceAuthority", "decision").update(
            {"wordpressCommit": "0" * 40}
        ),
    )
    print("ADR-010 hook decision self-test passed: 7 fail-closed mutations")


if __name__ == "__main__":
    validate_repository()
    self_test()
    print("ADR-010 proposed hook contract decision passed")
