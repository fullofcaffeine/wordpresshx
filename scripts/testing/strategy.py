#!/usr/bin/env python3
"""Validate and explain the WordPressHx behavior-first testing strategy."""

from __future__ import annotations

import argparse
import copy
import fnmatch
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STRATEGY_PATH = ROOT / "manifests" / "testing-strategy.json"
BASELINE_PATH = ROOT / "manifests" / "evidence" / "testing-strategy-baseline.json"
RED_PROOF_PATH = ROOT / "manifests" / "evidence" / "testing-strategy-json-red-proof.json"
REQUIRED_SURFACES = {
    "compiler-adapter",
    "wordpress-runtime-abi",
    "package-install",
    "gutenberg-browser",
    "migration-downstream",
}
REQUIRED_CONCLUSIONS = {
    "behavior-formulation",
    "tdd-red-state",
    "independent-oracle",
    "tracer-bullet",
    "lowest-faithful-double-lock",
    "portfolio-not-quota",
    "executable-examples",
    "r0-r5-feedback",
    "targeted-verification",
}
REQUIRED_RINGS = {f"R{index}" for index in range(6)}
REQUIRED_EXAMPLE_TIERS = {"flagship-application", "capability-showcase", "compile-only-snippet"}
EXPECTED_POST_HOSTED_JOBS = {
    "Repository bootstrap": {"repository", "haxe", "wordpress-runtime", "security", "generated-output-vcs"},
    "Output-context safety": {"output-context"},
    "Adoption-contract architecture": {"adoption-contract"},
    "Unsafe-boundary policy": {"unsafe-boundary-policy"},
    "Windows development service ownership": {"windows-dev-loop"},
}


class StrategyError(ValueError):
    pass


def strict_json(path: Path) -> dict[str, object]:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise StrategyError(f"{path.relative_to(ROOT)} contains duplicate key {key}")
            result[key] = value
        return result

    def reject_number(value: str) -> object:
        raise StrategyError(f"{path.relative_to(ROOT)} contains non-integer number {value}")

    try:
        loaded = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=pairs,
            parse_float=reject_number,
            parse_constant=reject_number,
        )
    except json.JSONDecodeError as error:
        raise StrategyError(f"{path.relative_to(ROOT)} is malformed: {error}") from error
    if not isinstance(loaded, dict):
        raise StrategyError("testing strategy root must be an object")
    return loaded


def require_dict(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise StrategyError(f"{label} must be an object")
    return value


def require_list(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        raise StrategyError(f"{label} must be an array")
    return value


def strings(value: object, label: str, *, allow_empty: bool = False) -> list[str]:
    entries = require_list(value, label)
    if not all(isinstance(entry, str) and entry for entry in entries):
        raise StrategyError(f"{label} must contain non-empty strings")
    result = [entry for entry in entries if isinstance(entry, str)]
    if not allow_empty and not result:
        raise StrategyError(f"{label} must not be empty")
    if len(result) != len(set(result)):
        raise StrategyError(f"{label} contains duplicates")
    return result


def exact_keys(value: dict[str, object], expected: set[str], label: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise StrategyError(f"{label} keys differ; missing={missing}, extra={extra}")


def relative_file(value: object, label: str) -> str:
    if not isinstance(value, str) or not value or value.startswith(("/", "\\")):
        raise StrategyError(f"{label} must be a repository-relative path")
    path = Path(value)
    if ".." in path.parts or not (ROOT / path).is_file():
        raise StrategyError(f"{label} does not resolve to a repository file: {value}")
    return value


def file_sha256(relative_path: str) -> str:
    return hashlib.sha256((ROOT / relative_path).read_bytes()).hexdigest()


def historical_validation_action(subject_available: bool, shallow_checkout: bool) -> str:
    if subject_available:
        return "validate-source-and-tree"
    if shallow_checkout:
        return "retain-receipt-identity-only"
    raise StrategyError("JSON red proof historical subject is absent from a complete checkout")


def validate_strategy(model: dict[str, object]) -> None:
    exact_keys(
        model,
        {
            "schemaVersion",
            "strategyId",
            "status",
            "reference",
            "authority",
            "audit",
            "surfaces",
            "testOwners",
            "rings",
            "examples",
            "representativeWorkflow",
            "selector",
            "flakePolicy",
            "claims",
        },
        "strategy",
    )
    if model.get("schemaVersion") != 1 or model.get("strategyId") != "wordpresshx-testing-v1":
        raise StrategyError("testing strategy identity changed")
    if model.get("status") != "adopted-selector-observation-only":
        raise StrategyError("testing strategy status changed")

    reference = require_dict(model.get("reference"), "reference")
    exact_keys(reference, {"version", "checksumsSha256", "sourceRole"}, "reference")
    if reference.get("version") != "2026-07-31-v3":
        raise StrategyError("consolidated testing reference version changed")
    if reference.get("sourceRole") != "design-reference-not-runtime-dependency":
        raise StrategyError("testing reference became a runtime dependency")

    authority = require_dict(model.get("authority"), "authority")
    exact_keys(
        authority,
        {
            "bead",
            "document",
            "selectionMode",
            "officialHaxeQualificationSurface",
            "publicClaimBroadeningAllowed",
            "releaseProof",
            "ratioPolicy",
        },
        "authority",
    )
    relative_file(authority.get("document"), "authority.document")
    if authority.get("selectionMode") != "observation-only":
        raise StrategyError("affected selection became authoritative without observation evidence")
    if authority.get("officialHaxeQualificationSurface") != "compiler-adapter":
        raise StrategyError("official Haxe qualification escaped the compiler surface")
    if authority.get("publicClaimBroadeningAllowed") is not False:
        raise StrategyError("testing strategy permits public claim broadening")
    if authority.get("releaseProof") != "blocked-no-release-command":
        raise StrategyError("testing strategy invented release proof")
    if authority.get("ratioPolicy") != "surface-portfolios-no-repository-quota":
        raise StrategyError("testing strategy introduced a repository-wide ratio quota")

    audit = require_list(model.get("audit"), "audit")
    audit_ids: set[str] = set()
    for index, raw in enumerate(audit):
        item = require_dict(raw, f"audit[{index}]")
        exact_keys(item, {"conclusionId", "disposition", "evidence", "increment"}, f"audit[{index}]")
        conclusion_id = item.get("conclusionId")
        if not isinstance(conclusion_id, str) or conclusion_id in audit_ids:
            raise StrategyError("audit conclusion identity is invalid")
        if item.get("disposition") not in {"satisfied", "partial", "absent", "inapplicable"}:
            raise StrategyError(f"audit conclusion {conclusion_id} has an invalid disposition")
        strings(item.get("evidence"), f"audit {conclusion_id} evidence")
        if not isinstance(item.get("increment"), str) or not item.get("increment"):
            raise StrategyError(f"audit conclusion {conclusion_id} needs an increment")
        audit_ids.add(conclusion_id)
    if audit_ids != REQUIRED_CONCLUSIONS:
        raise StrategyError("testing-strategy conclusion inventory is incomplete")

    surfaces = require_list(model.get("surfaces"), "surfaces")
    surface_ids: set[str] = set()
    owner_ids: set[str] = set()
    example_ids: set[str] = set()
    for index, raw in enumerate(surfaces):
        surface = require_dict(raw, f"surfaces[{index}]")
        exact_keys(
            surface,
            {
                "surfaceId",
                "name",
                "owner",
                "archetypes",
                "status",
                "claims",
                "authoredInputs",
                "producedOutputs",
                "supportedProfiles",
                "testedProfiles",
                "focusedOwners",
                "verticalIntegrationOwners",
                "realRuntimeOrSystemOwners",
                "browserE2eOwners",
                "examples",
                "upstreamOracleAndPin",
                "adaptations",
                "knownSkips",
                "quarantines",
                "selectorOwnership",
                "fullBackstopCommand",
                "releaseCommand",
                "lastCleanProofs",
                "unprovenOwners",
                "residualRisks",
            },
            f"surfaces[{index}]",
        )
        surface_id = surface.get("surfaceId")
        if not isinstance(surface_id, str) or surface_id in surface_ids:
            raise StrategyError("surface identity is invalid")
        if surface.get("status") not in {"experimental", "admitted-slice", "partial", "qualified", "release-claiming"}:
            raise StrategyError(f"surface {surface_id} has invalid status")
        for field in (
            "archetypes",
            "claims",
            "authoredInputs",
            "producedOutputs",
            "testedProfiles",
            "focusedOwners",
            "verticalIntegrationOwners",
            "upstreamOracleAndPin",
            "knownSkips",
            "selectorOwnership",
            "residualRisks",
        ):
            strings(surface.get(field), f"surface {surface_id} {field}")
        for field in ("supportedProfiles", "realRuntimeOrSystemOwners", "browserE2eOwners", "examples", "adaptations", "quarantines"):
            values = surface.get(field)
            if not isinstance(values, list):
                raise StrategyError(f"surface {surface_id} {field} must be an array")
            if not all(isinstance(value, str) and value for value in values):
                raise StrategyError(f"surface {surface_id} {field} has an invalid value")
        if not isinstance(surface.get("lastCleanProofs"), list) or not surface.get("lastCleanProofs"):
            raise StrategyError(f"surface {surface_id} needs at least one exact clean proof")
        strings(surface.get("unprovenOwners"), f"surface {surface_id} unprovenOwners", allow_empty=True)
        if surface.get("releaseCommand") is not None:
            raise StrategyError(f"surface {surface_id} exposes release proof while publication is blocked")
        owner_ids.update(strings(surface.get("focusedOwners"), f"surface {surface_id} focusedOwners"))
        owner_ids.update(strings(surface.get("verticalIntegrationOwners"), f"surface {surface_id} verticalIntegrationOwners"))
        owner_ids.update(surface.get("realRuntimeOrSystemOwners", []))
        owner_ids.update(surface.get("browserE2eOwners", []))
        example_ids.update(surface.get("examples", []))
        surface_ids.add(surface_id)
    if surface_ids != REQUIRED_SURFACES:
        raise StrategyError(f"surface inventory differs: {sorted(surface_ids)}")

    owners = require_list(model.get("testOwners"), "testOwners")
    owner_by_id: dict[str, dict[str, object]] = {}
    for index, raw in enumerate(owners):
        owner = require_dict(raw, f"testOwners[{index}]")
        exact_keys(
            owner,
            {
                "testId",
                "name",
                "surfaces",
                "layer",
                "rings",
                "command",
                "pathPatterns",
                "reverseDependencies",
                "alwaysRun",
                "oracle",
                "claimContribution",
            },
            f"testOwners[{index}]",
        )
        test_id = owner.get("testId")
        if not isinstance(test_id, str) or test_id in owner_by_id:
            raise StrategyError("test owner identity is invalid")
        test_surfaces = strings(owner.get("surfaces"), f"test owner {test_id} surfaces", allow_empty=True)
        if not set(test_surfaces) <= surface_ids:
            raise StrategyError(f"test owner {test_id} names an unknown surface")
        if owner.get("layer") not in {"static", "focused", "vertical", "system", "browser-e2e", "release"}:
            raise StrategyError(f"test owner {test_id} has an invalid layer")
        if not set(strings(owner.get("rings"), f"test owner {test_id} rings")) <= REQUIRED_RINGS:
            raise StrategyError(f"test owner {test_id} names an invalid ring")
        if not isinstance(owner.get("command"), str) or not owner.get("command"):
            raise StrategyError(f"test owner {test_id} needs a command")
        strings(owner.get("pathPatterns"), f"test owner {test_id} pathPatterns")
        if not isinstance(owner.get("alwaysRun"), bool):
            raise StrategyError(f"test owner {test_id} alwaysRun must be boolean")
        if not isinstance(owner.get("oracle"), str) or not owner.get("oracle"):
            raise StrategyError(f"test owner {test_id} needs an independent-oracle statement")
        if not isinstance(owner.get("claimContribution"), str) or not owner.get("claimContribution"):
            raise StrategyError(f"test owner {test_id} needs a claim contribution")
        owner_by_id[test_id] = owner
    if not owner_ids <= set(owner_by_id):
        raise StrategyError(f"surface references unknown test owners: {sorted(owner_ids - set(owner_by_id))}")
    for test_id, owner in owner_by_id.items():
        dependencies = strings(owner.get("reverseDependencies"), f"test owner {test_id} reverseDependencies", allow_empty=True)
        if not set(dependencies) <= set(owner_by_id):
            raise StrategyError(f"test owner {test_id} has unknown reverse dependencies")

    surface_by_id = {
        surface["surfaceId"]: surface
        for surface in surfaces
        if isinstance(surface, dict) and isinstance(surface.get("surfaceId"), str)
    }
    for surface_id, surface in surface_by_id.items():
        scorecard_owners: set[str] = set()
        for field in ("focusedOwners", "verticalIntegrationOwners", "realRuntimeOrSystemOwners", "browserE2eOwners"):
            scorecard_owners.update(strings(surface.get(field), f"surface {surface_id} {field}", allow_empty=True))
        declared_owners = {
            test_id
            for test_id, owner in owner_by_id.items()
            if surface_id in strings(owner.get("surfaces"), f"test owner {test_id} surfaces", allow_empty=True)
        }
        if scorecard_owners != declared_owners:
            raise StrategyError(
                f"surface {surface_id} owner attribution is not reciprocal; "
                f"scorecardOnly={sorted(scorecard_owners - declared_owners)}, "
                f"ownerOnly={sorted(declared_owners - scorecard_owners)}"
            )

        covered_owners: set[str] = set()
        for index, raw_proof in enumerate(require_list(surface.get("lastCleanProofs"), f"surface {surface_id} lastCleanProofs")):
            proof = require_dict(raw_proof, f"surface {surface_id} lastCleanProofs[{index}]")
            exact_keys(
                proof,
                {"workflow", "job", "runId", "jobId", "commit", "status", "evidence", "ownersCovered"},
                f"surface {surface_id} lastCleanProofs[{index}]",
            )
            for field in ("workflow", "job"):
                if not isinstance(proof.get(field), str) or not proof.get(field):
                    raise StrategyError(f"surface {surface_id} proof lacks {field}")
            for field in ("runId", "jobId"):
                value = proof.get(field)
                if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                    raise StrategyError(f"surface {surface_id} proof has invalid {field}")
            commit = proof.get("commit")
            if not isinstance(commit, str) or re.fullmatch(r"[0-9a-f]{40}", commit) is None:
                raise StrategyError(f"surface {surface_id} proof lacks an exact commit")
            if proof.get("status") != "passed":
                raise StrategyError(f"surface {surface_id} proof is not passed")
            relative_file(proof.get("evidence"), f"surface {surface_id} proof evidence")
            proof_owners = set(strings(proof.get("ownersCovered"), f"surface {surface_id} proof ownersCovered"))
            if not proof_owners <= scorecard_owners:
                raise StrategyError(f"surface {surface_id} proof launders another surface's owner")
            covered_owners.update(proof_owners)
        unproven_owners = set(strings(surface.get("unprovenOwners"), f"surface {surface_id} unprovenOwners", allow_empty=True))
        if covered_owners & unproven_owners:
            raise StrategyError(f"surface {surface_id} marks a proved owner unproven")
        if covered_owners | unproven_owners != scorecard_owners:
            raise StrategyError(f"surface {surface_id} proof coverage is incomplete")

    rings = require_list(model.get("rings"), "rings")
    ring_ids: set[str] = set()
    for index, raw in enumerate(rings):
        ring = require_dict(raw, f"rings[{index}]")
        exact_keys(ring, {"ringId", "role", "commands", "remoteWorkflows", "currentState", "budgetState"}, f"rings[{index}]")
        ring_id = ring.get("ringId")
        if not isinstance(ring_id, str) or ring_id in ring_ids:
            raise StrategyError("ring identity is invalid")
        strings(ring.get("commands"), f"ring {ring_id} commands")
        if not isinstance(ring.get("remoteWorkflows"), list):
            raise StrategyError(f"ring {ring_id} remoteWorkflows must be an array")
        ring_ids.add(ring_id)
    if ring_ids != REQUIRED_RINGS:
        raise StrategyError("R0-R5 inventory is incomplete")

    examples = require_list(model.get("examples"), "examples")
    declared_examples: set[str] = set()
    for index, raw in enumerate(examples):
        example = require_dict(raw, f"examples[{index}]")
        exact_keys(example, {"exampleId", "tier", "owner", "surfaces", "advertisedClaim", "testCommand", "interactiveCommand", "status"}, f"examples[{index}]")
        example_id = example.get("exampleId")
        if not isinstance(example_id, str) or example_id in declared_examples:
            raise StrategyError("example identity is invalid")
        if example.get("tier") not in REQUIRED_EXAMPLE_TIERS:
            raise StrategyError(f"example {example_id} has an invalid tier")
        relative_file(example.get("owner"), f"example {example_id} owner")
        if not set(strings(example.get("surfaces"), f"example {example_id} surfaces")) <= surface_ids:
            raise StrategyError(f"example {example_id} names an unknown surface")
        if example.get("status") != "executable-at-declared-tier":
            raise StrategyError(f"example {example_id} is not executable at its tier")
        declared_examples.add(example_id)
    if example_ids != declared_examples:
        raise StrategyError("surface/example scorecards disagree")

    workflow = require_dict(model.get("representativeWorkflow"), "representativeWorkflow")
    exact_keys(
        workflow,
        {
            "workflowId",
            "surfaces",
            "scenario",
            "redState",
            "oracle",
            "focusedOwner",
            "tracerBullet",
            "broaderProof",
            "reviewDisposition",
            "claimEffect",
        },
        "representativeWorkflow",
    )
    if not set(strings(workflow.get("surfaces"), "representativeWorkflow surfaces")) <= surface_ids:
        raise StrategyError("representative workflow names an unknown surface")
    scenario = require_dict(workflow.get("scenario"), "representativeWorkflow scenario")
    exact_keys(scenario, {"preconditions", "action", "observableResult", "errorOrEdge", "protectedClaim"}, "representativeWorkflow scenario")
    for field in scenario:
        if not isinstance(scenario[field], str) or not scenario[field]:
            raise StrategyError(f"representative workflow scenario lacks {field}")
    red = require_dict(workflow.get("redState"), "representativeWorkflow redState")
    exact_keys(
        red,
        {"subjectCommit", "controlledOverlayFixture", "command", "expectedFailure", "evidence", "independentReview"},
        "representativeWorkflow redState",
    )
    if not isinstance(red.get("subjectCommit"), str) or re.fullmatch(r"[0-9a-f]{40}", red["subjectCommit"]) is None:
        raise StrategyError("representative workflow red state lacks an exact subject commit")
    relative_file(red.get("controlledOverlayFixture"), "representativeWorkflow controlled overlay")
    for field in ("command", "expectedFailure"):
        if not isinstance(red.get(field), str) or not red.get(field):
            raise StrategyError(f"representative workflow red state lacks {field}")
    relative_file(red.get("evidence"), "representativeWorkflow redState evidence")
    relative_file(red.get("independentReview"), "representativeWorkflow independent review")
    oracle = require_dict(workflow.get("oracle"), "representativeWorkflow oracle")
    exact_keys(oracle, {"kind", "authority", "independence"}, "representativeWorkflow oracle")
    for field in oracle:
        if not isinstance(oracle[field], str) or not oracle[field]:
            raise StrategyError(f"representative workflow oracle lacks {field}")
    focused_owner = workflow.get("focusedOwner")
    if not isinstance(focused_owner, str) or focused_owner not in owner_by_id:
        raise StrategyError("representative workflow lacks a valid focused owner")
    tracer = require_dict(workflow.get("tracerBullet"), "representativeWorkflow tracerBullet")
    exact_keys(tracer, {"path", "observer", "status"}, "representativeWorkflow tracerBullet")
    for field in tracer:
        if not isinstance(tracer[field], str) or not tracer[field]:
            raise StrategyError(f"representative tracer bullet lacks {field}")
    if tracer.get("status") != "runtime-tested-bounded-prototype":
        raise StrategyError("representative tracer bullet status changed")
    if workflow.get("reviewDisposition") != "changes-repaired-pending-fresh-independent-rereview":
        raise StrategyError("representative high-risk review disposition changed")
    if workflow.get("claimEffect") != "unchanged-bounded-prototype-no-publication":
        raise StrategyError("representative workflow broadened a claim")
    if not isinstance(workflow.get("broaderProof"), str) or not workflow.get("broaderProof"):
        raise StrategyError("representative workflow lacks broader proof")

    selector = require_dict(model.get("selector"), "selector")
    exact_keys(selector, {"mode", "alwaysRunTestIds", "fullExpansionPatterns", "unknownPathPolicy", "backstop", "promotionRequirements"}, "selector")
    if selector.get("mode") != "observation-only" or selector.get("unknownPathPolicy") != "select-all":
        raise StrategyError("selector is not fail-safe observation-only")
    always_run = set(strings(selector.get("alwaysRunTestIds"), "selector alwaysRunTestIds"))
    if not always_run <= set(owner_by_id):
        raise StrategyError("selector references an unknown always-run owner")
    for test_id in always_run:
        if owner_by_id[test_id].get("alwaysRun") is not True:
            raise StrategyError(f"selector always-run owner {test_id} is not marked alwaysRun")
    strings(selector.get("fullExpansionPatterns"), "selector fullExpansionPatterns")
    if selector.get("backstop") != "all-current-primary-workflows-on-main":
        raise StrategyError("selector full backstop changed")
    strings(selector.get("promotionRequirements"), "selector promotionRequirements")

    flake = require_dict(model.get("flakePolicy"), "flakePolicy")
    exact_keys(flake, {"automaticRetry", "deterministicFailure", "quarantineRequiredFields", "currentQuarantines", "measurementState"}, "flakePolicy")
    if flake.get("automaticRetry") != "forbidden-for-deterministic-test-failures":
        raise StrategyError("flake policy permits deterministic retries")
    if flake.get("deterministicFailure") != "preserve-first-failure-and-exit-nonzero":
        raise StrategyError("flake policy hides the first deterministic failure")
    strings(flake.get("quarantineRequiredFields"), "flakePolicy quarantineRequiredFields")
    if flake.get("currentQuarantines") != []:
        raise StrategyError("unreviewed quarantines entered the strategy")

    claims = require_dict(model.get("claims"), "claims")
    exact_keys(claims, {"justified", "unchanged", "narrowed", "deferred"}, "claims")
    for field in claims:
        if not isinstance(claims[field], list) or not all(isinstance(value, str) and value for value in claims[field]):
            raise StrategyError(f"claims.{field} must contain strings")


def validate_red_proof(receipt: dict[str, object]) -> None:
    exact_keys(
        receipt,
        {"schemaVersion", "receiptId", "bead", "reproducedAt", "reviewedSubject", "controlledOverlay", "comparison", "reproduction", "independentReview", "claims"},
        "testing strategy JSON red proof",
    )
    if receipt.get("schemaVersion") != 1 or receipt.get("receiptId") != "TESTING-STRATEGY-JSON-RED-001":
        raise StrategyError("testing strategy JSON red proof identity changed")
    if receipt.get("bead") != "wordpresshx-sdk-plan.3.5":
        raise StrategyError("testing strategy JSON red proof lost its Bead authority")
    if not isinstance(receipt.get("reproducedAt"), str) or not receipt.get("reproducedAt"):
        raise StrategyError("testing strategy JSON red proof lacks a timestamp")

    subject = require_dict(receipt.get("reviewedSubject"), "JSON red proof reviewedSubject")
    exact_keys(subject, {"commit", "tree", "outputSinksSha256", "shallowHistoryDisposition"}, "JSON red proof reviewedSubject")
    for field in ("commit", "tree"):
        if not isinstance(subject.get(field), str) or re.fullmatch(r"[0-9a-f]{40}", subject[field]) is None:
            raise StrategyError(f"JSON red proof reviewedSubject lacks exact {field}")
    if subject.get("shallowHistoryDisposition") != "validate exact source and tree when present; in a shallow checkout retain receipt identity without claiming replay":
        raise StrategyError("JSON red proof shallow-history disposition changed")
    subject_available = subprocess.run(
        ["git", "cat-file", "-e", f"{subject['commit']}^{{commit}}"],
        cwd=ROOT,
        check=False,
        capture_output=True,
    ).returncode == 0
    shallow_checkout = subprocess.run(
        ["git", "rev-parse", "--is-shallow-repository"],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip() == "true"
    history_action = historical_validation_action(subject_available, shallow_checkout)
    if history_action == "validate-source-and-tree":
        historical = subprocess.run(
            ["git", "show", f"{subject['commit']}:fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout
        if hashlib.sha256(historical).hexdigest() != subject.get("outputSinksSha256"):
            raise StrategyError("JSON red proof historical source digest drifted")
        resolved_tree = subprocess.run(
            ["git", "rev-parse", f"{subject['commit']}^{{tree}}"],
            cwd=ROOT,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()
        if resolved_tree != subject.get("tree"):
            raise StrategyError("JSON red proof historical tree drifted")
    elif history_action != "retain-receipt-identity-only":
        raise StrategyError("JSON red proof historical validation reached an unknown action")

    overlay = require_dict(receipt.get("controlledOverlay"), "JSON red proof controlledOverlay")
    exact_keys(overlay, {"role", "path", "sha256"}, "JSON red proof controlledOverlay")
    overlay_path = relative_file(overlay.get("path"), "JSON red proof overlay path")
    if file_sha256(overlay_path) != overlay.get("sha256") or not isinstance(overlay.get("role"), str) or not overlay.get("role"):
        raise StrategyError("JSON red proof controlled overlay drifted")

    comparison = require_dict(receipt.get("comparison"), "JSON red proof comparison")
    exact_keys(comparison, {"baseCommit", "currentOutputSinksPath", "currentOutputSinksSha256"}, "JSON red proof comparison")
    if not isinstance(comparison.get("baseCommit"), str) or re.fullmatch(r"[0-9a-f]{40}", comparison["baseCommit"]) is None:
        raise StrategyError("JSON red proof comparison lacks an exact base commit")
    current_output = relative_file(comparison.get("currentOutputSinksPath"), "JSON red proof current output source")
    if file_sha256(current_output) != comparison.get("currentOutputSinksSha256"):
        raise StrategyError("JSON red proof current source digest drifted")

    reproduction = require_dict(receipt.get("reproduction"), "JSON red proof reproduction")
    exact_keys(reproduction, {"script", "scriptSha256", "command", "haxeVersion", "subjectExit", "subjectOutput", "subjectOutputSha256", "currentExit", "currentOutput", "currentOutputSha256", "currentDiagnostic", "interpretation"}, "JSON red proof reproduction")
    script = relative_file(reproduction.get("script"), "JSON red proof script")
    if file_sha256(script) != reproduction.get("scriptSha256"):
        raise StrategyError("JSON red proof script digest drifted")
    if reproduction.get("command") != f"bash {script}" or reproduction.get("haxeVersion") != "4.3.7":
        raise StrategyError("JSON red proof command or toolchain changed")
    if reproduction.get("subjectExit") != 0 or reproduction.get("currentExit") != 1:
        raise StrategyError("JSON red proof exit sensitivity changed")
    if not isinstance(reproduction.get("subjectOutput"), str) or hashlib.sha256(reproduction["subjectOutput"].encode("utf-8")).hexdigest() != reproduction.get("subjectOutputSha256"):
        raise StrategyError("JSON red proof subject output digest drifted")
    if not isinstance(reproduction.get("currentOutput"), str) or hashlib.sha256((reproduction["currentOutput"] + "\n").encode("utf-8")).hexdigest() != reproduction.get("currentOutputSha256"):
        raise StrategyError("JSON red proof current output digest drifted")
    for field in ("currentDiagnostic", "interpretation"):
        if not isinstance(reproduction.get(field), str) or not reproduction.get(field):
            raise StrategyError(f"JSON red proof lacks {field}")

    review = require_dict(receipt.get("independentReview"), "JSON red proof independentReview")
    exact_keys(review, {"path", "sha256", "role"}, "JSON red proof independentReview")
    review_path = relative_file(review.get("path"), "JSON red proof independent review path")
    if file_sha256(review_path) != review.get("sha256") or not isinstance(review.get("role"), str) or not review.get("role"):
        raise StrategyError("JSON red proof independent review drifted")
    claims = require_dict(receipt.get("claims"), "JSON red proof claims")
    exact_keys(claims, {"redSensitivity", "currentBoundary", "freshIndependentAcceptance", "publicationAuthorized"}, "JSON red proof claims")
    if claims.get("redSensitivity") != "reproduced" or claims.get("freshIndependentAcceptance") != "pending" or claims.get("publicationAuthorized") is not False:
        raise StrategyError("JSON red proof broadened its authority")


def validate_baseline(receipt: dict[str, object], model: dict[str, object]) -> None:
    exact_keys(
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "bead",
            "observedAt",
            "subject",
            "measurementSemantics",
            "localBefore",
            "hostedBefore",
            "hostedJobEvidence",
            "recentWorkflowHistory",
            "currentTopology",
            "postChange",
            "claims",
        },
        "testing strategy baseline",
    )
    if receipt.get("schemaVersion") != 1 or receipt.get("receiptId") != "TESTING-STRATEGY-BASELINE-001":
        raise StrategyError("testing strategy baseline identity changed")
    if receipt.get("bead") != "wordpresshx-sdk-plan.3.5":
        raise StrategyError("testing strategy baseline lost its Bead authority")
    if not isinstance(receipt.get("observedAt"), str) or not receipt.get("observedAt"):
        raise StrategyError("testing strategy baseline lacks a final observation timestamp")

    subject = require_dict(receipt.get("subject"), "testing strategy baseline subject")
    exact_keys(subject, {"commit", "strategyReferenceVersion", "strategyReferenceChecksumsSha256"}, "testing strategy baseline subject")
    commit = subject.get("commit")
    if not isinstance(commit, str) or re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise StrategyError("testing strategy baseline needs an exact commit")
    reference = require_dict(model.get("reference"), "reference")
    if subject.get("strategyReferenceVersion") != reference.get("version"):
        raise StrategyError("testing strategy baseline reference version drifted")
    if subject.get("strategyReferenceChecksumsSha256") != reference.get("checksumsSha256"):
        raise StrategyError("testing strategy baseline reference digest drifted")

    semantics = require_dict(receipt.get("measurementSemantics"), "testing strategy measurementSemantics")
    exact_keys(semantics, {"localSamples", "coldClaim", "warmClaim", "coldWarmDeferral", "percentileClaim", "hostedSamples", "comparisonUse"}, "testing strategy measurementSemantics")
    if semantics.get("coldClaim") is not False or semantics.get("warmClaim") is not False or semantics.get("percentileClaim") is not False:
        raise StrategyError("testing strategy baseline overstates timing semantics")
    for field in ("localSamples", "coldWarmDeferral", "hostedSamples", "comparisonUse"):
        if not isinstance(semantics.get(field), str) or not semantics.get(field):
            raise StrategyError(f"testing strategy measurementSemantics lacks {field}")

    local_before = require_list(receipt.get("localBefore"), "testing strategy localBefore")
    if {entry.get("ring") for entry in local_before if isinstance(entry, dict)} != {"R0", "R1", "R2", "R3"}:
        raise StrategyError("testing strategy local baseline ring inventory changed")
    for index, raw in enumerate(local_before):
        sample = require_dict(raw, f"testing strategy localBefore[{index}]")
        expected_keys = {"ring", "command", "firstMilliseconds", "repeatMilliseconds", "outcome", "uniqueEvidence"}
        if sample.get("ring") == "R3":
            expected_keys.add("blocker")
        exact_keys(sample, expected_keys, f"testing strategy localBefore[{index}]")
        for field in ("command", "outcome", "uniqueEvidence"):
            if not isinstance(sample.get(field), str) or not sample.get(field):
                raise StrategyError(f"testing strategy localBefore[{index}] lacks {field}")
        for field in ("firstMilliseconds", "repeatMilliseconds"):
            duration = sample.get(field)
            if duration is not None and (not isinstance(duration, int) or isinstance(duration, bool) or duration < 0):
                raise StrategyError(f"testing strategy localBefore[{index}] has invalid {field}")

    hosted_before = require_list(receipt.get("hostedBefore"), "testing strategy hostedBefore")
    if len(hosted_before) != 5:
        raise StrategyError("testing strategy hosted baseline must retain all five workflows")
    expected_workflows = {
        "Repository bootstrap",
        "Output-context safety",
        "Adoption-contract architecture",
        "Unsafe-boundary policy",
        "Windows development service ownership",
    }
    observed_workflows: set[str] = set()
    for index, raw in enumerate(hosted_before):
        sample = require_dict(raw, f"testing strategy hostedBefore[{index}]")
        exact_keys(sample, {"ring", "workflow", "runId", "jobId", "commit", "criticalPathSeconds", "uniqueEvidence", "outcome"}, f"testing strategy hostedBefore[{index}]")
        if sample.get("outcome") != "passed":
            raise StrategyError("testing strategy hosted baseline contains a non-passing authority")
        for field in ("runId", "jobId", "criticalPathSeconds"):
            value = sample.get(field)
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                raise StrategyError(f"testing strategy hosted baseline lacks exact {field}")
        if sample.get("commit") != commit:
            raise StrategyError("testing strategy hosted baseline subject commit drifted")
        for field in ("ring", "workflow", "uniqueEvidence"):
            if not isinstance(sample.get(field), str) or not sample.get(field):
                raise StrategyError(f"testing strategy hosted baseline lacks {field}")
        observed_workflows.add(sample["workflow"])
    if observed_workflows != expected_workflows:
        raise StrategyError("testing strategy hosted baseline workflow inventory is not distinct and complete")

    hosted_jobs = require_list(receipt.get("hostedJobEvidence"), "testing strategy hostedJobEvidence")
    authoritative_jobs: dict[tuple[str, str, int, int, str], dict[str, set[str]]] = {}
    for index, raw in enumerate(hosted_jobs):
        job = require_dict(raw, f"testing strategy hostedJobEvidence[{index}]")
        exact_keys(job, {"workflow", "job", "runId", "jobId", "commit", "surfaceCoverage", "outcome"}, f"testing strategy hostedJobEvidence[{index}]")
        if job.get("outcome") != "passed" or job.get("commit") != commit:
            raise StrategyError("testing strategy hosted job is not a passing exact-subject authority")
        for field in ("workflow", "job"):
            if not isinstance(job.get(field), str) or not job.get(field):
                raise StrategyError(f"testing strategy hosted job lacks {field}")
        for field in ("runId", "jobId"):
            value = job.get(field)
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                raise StrategyError(f"testing strategy hosted job lacks exact {field}")
        identity = (job["workflow"], job["job"], job["runId"], job["jobId"], job["commit"])
        if identity in authoritative_jobs:
            raise StrategyError("testing strategy hosted job evidence contains a duplicate")
        coverage_by_surface: dict[str, set[str]] = {}
        for coverage_index, raw_coverage in enumerate(require_list(job.get("surfaceCoverage"), f"testing strategy hostedJobEvidence[{index}] surfaceCoverage")):
            coverage = require_dict(raw_coverage, f"testing strategy hostedJobEvidence[{index}] surfaceCoverage[{coverage_index}]")
            exact_keys(coverage, {"surfaceId", "ownersCovered"}, f"testing strategy hostedJobEvidence[{index}] surfaceCoverage[{coverage_index}]")
            surface_id = coverage.get("surfaceId")
            if not isinstance(surface_id, str) or surface_id not in REQUIRED_SURFACES or surface_id in coverage_by_surface:
                raise StrategyError("testing strategy hosted job has invalid or duplicate surface coverage")
            owners_covered = set(strings(coverage.get("ownersCovered"), f"testing strategy hosted job {surface_id} ownersCovered"))
            coverage_by_surface[surface_id] = owners_covered
        authoritative_jobs[identity] = coverage_by_surface

    sdk090 = strict_json(ROOT / "manifests" / "evidence" / "sdk-090-wordpress-harness.json")
    sdk090_hosted = require_dict(sdk090.get("hostedWorkflow"), "SDK-090 hostedWorkflow")
    for surface in require_list(model.get("surfaces"), "surfaces"):
        scorecard = require_dict(surface, "surface")
        surface_id = scorecard.get("surfaceId")
        for raw_proof in require_list(scorecard.get("lastCleanProofs"), "surface lastCleanProofs"):
            proof = require_dict(raw_proof, "surface proof")
            identity = (proof["workflow"], proof["job"], proof["runId"], proof["jobId"], proof["commit"])
            proof_owners = set(strings(proof.get("ownersCovered"), "surface proof ownersCovered"))
            evidence = proof.get("evidence")
            if evidence == "manifests/evidence/testing-strategy-baseline.json":
                if identity not in authoritative_jobs:
                    raise StrategyError("surface proof identity is not bound by hosted job evidence")
                if authoritative_jobs[identity].get(surface_id) != proof_owners:
                    raise StrategyError("surface proof owner coverage is not bound to its exact hosted job")
            elif evidence == "manifests/evidence/sdk-090-wordpress-harness.json":
                expected = (
                    "Repository bootstrap",
                    sdk090_hosted.get("job"),
                    sdk090_hosted.get("runId"),
                    sdk090_hosted.get("jobId"),
                    sdk090_hosted.get("commit"),
                )
                if identity != expected or sdk090_hosted.get("status") != "passed":
                    raise StrategyError("surface proof identity is not bound by SDK-090 evidence")
                if surface_id != "wordpress-runtime-abi" or proof_owners != {"wordpress-runtime-harness"}:
                    raise StrategyError("SDK-090 proof owner coverage changed")
            else:
                raise StrategyError("surface proof names an unrecognized evidence authority")

    history = require_dict(receipt.get("recentWorkflowHistory"), "testing strategy recentWorkflowHistory")
    exact_keys(history, {"window", "repositoryBootstrap", "outputContext", "adoptionContract", "unsafeBoundary", "windowsDevelopment", "classification"}, "testing strategy recentWorkflowHistory")
    for field in ("window", "classification"):
        if not isinstance(history.get(field), str) or not history.get(field):
            raise StrategyError(f"testing strategy recentWorkflowHistory lacks {field}")
    for workflow_key in ("repositoryBootstrap", "outputContext", "adoptionContract", "unsafeBoundary", "windowsDevelopment"):
        counts = require_dict(history.get(workflow_key), f"testing strategy history {workflow_key}")
        exact_keys(counts, {"runs", "success", "failure", "rerunAttempts"}, f"testing strategy history {workflow_key}")
        for field in counts:
            value = counts[field]
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise StrategyError(f"testing strategy history {workflow_key} has invalid {field}")
        if counts["success"] + counts["failure"] != counts["runs"]:
            raise StrategyError(f"testing strategy history {workflow_key} counts do not reconcile")

    topology = require_dict(receipt.get("currentTopology"), "testing strategy currentTopology")
    exact_keys(topology, {"pullRequest", "main", "nightly", "release", "selector"}, "testing strategy currentTopology")
    for field in topology:
        if not isinstance(topology[field], str) or not topology[field]:
            raise StrategyError(f"testing strategy currentTopology lacks {field}")

    post_change = require_dict(receipt.get("postChange"), "testing strategy postChange")
    exact_keys(post_change, {"recordedAt", "measurementSubject", "localSamples", "hostedRuns", "hostedStatus", "claimCoverageChange", "maintenanceCostChange"}, "testing strategy postChange")
    if not isinstance(post_change.get("recordedAt"), str) or not post_change.get("recordedAt"):
        raise StrategyError("testing strategy postChange lacks a timestamp")
    measurement_subject = require_dict(post_change.get("measurementSubject"), "testing strategy measurementSubject")
    exact_keys(measurement_subject, {"baseCommit", "strategySha256", "validatorSha256", "repositoryGateSha256"}, "testing strategy measurementSubject")
    if measurement_subject.get("baseCommit") != commit:
        raise StrategyError("testing strategy post-change base commit drifted")
    for field, relative_path in (
        ("strategySha256", "manifests/testing-strategy.json"),
        ("validatorSha256", "scripts/testing/strategy.py"),
        ("repositoryGateSha256", "scripts/check-repository.sh"),
    ):
        if measurement_subject.get(field) != file_sha256(relative_path):
            raise StrategyError(f"testing strategy post-change subject digest drifted: {field}")

    local_samples = require_list(post_change.get("localSamples"), "testing strategy postChange localSamples")
    if {entry.get("ring") for entry in local_samples if isinstance(entry, dict)} != {"R0", "R1", "R2"}:
        raise StrategyError("testing strategy post-change local samples are missing")
    for index, raw in enumerate(local_samples):
        sample = require_dict(raw, f"testing strategy postChange localSamples[{index}]")
        exact_keys(sample, {"ring", "command", "firstMilliseconds", "repeatMilliseconds", "outcome", "comparison"}, f"testing strategy postChange localSamples[{index}]")
        for field in ("ring", "command", "outcome", "comparison"):
            if not isinstance(sample.get(field), str) or not sample.get(field):
                raise StrategyError(f"testing strategy postChange localSamples[{index}] lacks {field}")
        if sample.get("outcome") != "passed":
            raise StrategyError("testing strategy post-change local sample is not passed")
        for field in ("firstMilliseconds", "repeatMilliseconds"):
            value = sample.get(field)
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise StrategyError(f"testing strategy postChange localSamples[{index}] has invalid {field}")
    hosted_runs = require_list(post_change.get("hostedRuns"), "testing strategy postChange hostedRuns")
    if post_change.get("hostedStatus") not in {"pending-main-push", "passed"}:
        raise StrategyError("testing strategy post-change hosted status is invalid")
    if post_change.get("hostedStatus") == "pending-main-push" and hosted_runs != []:
        raise StrategyError("testing strategy post-change hosted evidence contradicts pending status")
    observed_hosted_workflows: set[str] = set()
    observed_hosted_run_ids: set[int] = set()
    observed_hosted_job_ids: set[int] = set()
    observed_hosted_commit: str | None = None
    for index, raw_run in enumerate(hosted_runs):
        hosted_run = require_dict(raw_run, f"testing strategy postChange hostedRuns[{index}]")
        exact_keys(hosted_run, {"workflow", "runId", "commit", "status", "jobs"}, f"testing strategy postChange hostedRuns[{index}]")
        workflow = hosted_run.get("workflow")
        if not isinstance(workflow, str) or workflow not in EXPECTED_POST_HOSTED_JOBS or workflow in observed_hosted_workflows:
            raise StrategyError("testing strategy post-change hosted workflow set is invalid")
        observed_hosted_workflows.add(workflow)
        run_id = hosted_run.get("runId")
        if not isinstance(run_id, int) or isinstance(run_id, bool) or run_id <= 0 or run_id in observed_hosted_run_ids:
            raise StrategyError("testing strategy post-change hosted run identity is invalid")
        observed_hosted_run_ids.add(run_id)
        hosted_commit = hosted_run.get("commit")
        if not isinstance(hosted_commit, str) or re.fullmatch(r"[0-9a-f]{40}", hosted_commit) is None:
            raise StrategyError("testing strategy post-change hosted commit is invalid")
        if observed_hosted_commit is None:
            observed_hosted_commit = hosted_commit
        elif observed_hosted_commit != hosted_commit:
            raise StrategyError("testing strategy post-change hosted runs mix subjects")
        if hosted_run.get("status") != "passed":
            raise StrategyError("testing strategy post-change hosted run is not passed")
        jobs = require_list(hosted_run.get("jobs"), f"testing strategy postChange hostedRuns[{index}] jobs")
        observed_job_names: set[str] = set()
        for job_index, raw_job in enumerate(jobs):
            job = require_dict(raw_job, f"testing strategy postChange hostedRuns[{index}] jobs[{job_index}]")
            exact_keys(job, {"name", "jobId", "durationMilliseconds", "status"}, f"testing strategy postChange hostedRuns[{index}] jobs[{job_index}]")
            name = job.get("name")
            if not isinstance(name, str) or not name or name in observed_job_names:
                raise StrategyError("testing strategy post-change hosted job name is invalid")
            observed_job_names.add(name)
            job_id = job.get("jobId")
            duration = job.get("durationMilliseconds")
            if not isinstance(job_id, int) or isinstance(job_id, bool) or job_id <= 0 or job_id in observed_hosted_job_ids:
                raise StrategyError("testing strategy post-change hosted job identity is invalid")
            observed_hosted_job_ids.add(job_id)
            if not isinstance(duration, int) or isinstance(duration, bool) or duration <= 0:
                raise StrategyError("testing strategy post-change hosted job duration is invalid")
            if job.get("status") != "passed":
                raise StrategyError("testing strategy post-change hosted job is not passed")
        if observed_job_names != EXPECTED_POST_HOSTED_JOBS[workflow]:
            raise StrategyError(f"testing strategy post-change hosted job coverage is incomplete for {workflow}")
    if post_change.get("hostedStatus") == "passed" and observed_hosted_workflows != set(EXPECTED_POST_HOSTED_JOBS):
        raise StrategyError("testing strategy post-change passed status lacks all five workflows")
    for field in ("claimCoverageChange", "maintenanceCostChange"):
        value = post_change.get(field)
        if not isinstance(value, str) or not value or value == "pending":
            raise StrategyError(f"testing strategy postChange {field} is incomplete")

    claims = require_dict(receipt.get("claims"), "testing strategy baseline claims")
    exact_keys(claims, {"timingBaseline", "flakeRate", "selectorMissRate", "publicCompatibility", "releaseReadiness"}, "testing strategy baseline claims")
    if claims.get("publicCompatibility") != "unchanged" or claims.get("releaseReadiness") != "blocked":
        raise StrategyError("testing strategy baseline broadened compatibility or release claims")
    if claims.get("timingBaseline") != "observed-single-samples" or claims.get("flakeRate") != "not-measured" or claims.get("selectorMissRate") != "not-measured":
        raise StrategyError("testing strategy baseline overstates timing, flake, or selector evidence")


def matches(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def select(model: dict[str, object], changed: list[str]) -> dict[str, object]:
    owners = {
        owner["testId"]: owner
        for owner in require_list(model.get("testOwners"), "testOwners")
        if isinstance(owner, dict) and isinstance(owner.get("testId"), str)
    }
    selector = require_dict(model.get("selector"), "selector")
    selected: dict[str, list[str]] = {}
    for test_id in strings(selector.get("alwaysRunTestIds"), "selector alwaysRunTestIds"):
        selected.setdefault(test_id, []).append("always-run-sentinel")

    normalized = sorted(set(path.strip().replace("\\", "/") for path in changed if path.strip()))
    fallback_reasons: list[str] = []
    if not normalized:
        fallback_reasons.append("no-changed-paths")
    for path in normalized:
        if path.startswith("/") or path == ".." or path.startswith("../") or "/../" in path:
            fallback_reasons.append(f"unsafe-path:{path}")
            continue
        if matches(path, strings(selector.get("fullExpansionPatterns"), "selector fullExpansionPatterns")):
            fallback_reasons.append(f"cross-cutting:{path}")
            continue
        matched = False
        for test_id, owner in owners.items():
            if matches(path, strings(owner.get("pathPatterns"), f"test owner {test_id} pathPatterns")):
                selected.setdefault(test_id, []).append(f"owns:{path}")
                matched = True
        if not matched:
            fallback_reasons.append(f"unknown-owner:{path}")

    if fallback_reasons:
        for test_id in owners:
            selected.setdefault(test_id, []).append("conservative-full-expansion")

    changed_selection = True
    while changed_selection:
        changed_selection = False
        for test_id in list(selected):
            owner = owners[test_id]
            for dependency in strings(owner.get("reverseDependencies"), f"test owner {test_id} reverseDependencies", allow_empty=True):
                if dependency not in selected:
                    selected[dependency] = [f"reverse-dependency-of:{test_id}"]
                    changed_selection = True

    omitted = sorted(set(owners) - set(selected))
    return {
        "schemaVersion": 1,
        "mode": selector.get("mode"),
        "changedPaths": normalized,
        "fallbackReasons": sorted(set(fallback_reasons)),
        "selected": [
            {
                "testId": test_id,
                "surfaces": owners[test_id].get("surfaces"),
                "rings": owners[test_id].get("rings"),
                "command": owners[test_id].get("command"),
                "reasons": sorted(set(reasons)),
            }
            for test_id, reasons in sorted(selected.items())
        ],
        "omitted": omitted,
        "authoritativeForSkipping": False,
        "backstop": selector.get("backstop"),
    }


def changed_from_base(base: str) -> list[str]:
    command = ["git", "diff", "--name-only", f"{base}...HEAD", "--"]
    result = subprocess.run(command, cwd=ROOT, check=True, text=True, capture_output=True)
    return [line for line in result.stdout.splitlines() if line]


def self_test(model: dict[str, object], baseline: dict[str, object]) -> None:
    all_ids = {
        owner["testId"]
        for owner in require_list(model.get("testOwners"), "testOwners")
        if isinstance(owner, dict)
    }
    unknown = select(model, ["unowned/new-surface.txt"])
    unknown_ids = {entry["testId"] for entry in unknown["selected"]}
    if unknown_ids != all_ids or not unknown["fallbackReasons"]:
        raise StrategyError("unknown path did not conservatively select all owners")
    strategy_change = select(model, ["manifests/testing-strategy.json"])
    strategy_ids = {entry["testId"] for entry in strategy_change["selected"]}
    if strategy_ids != all_ids:
        raise StrategyError("strategy change did not select the complete portfolio")
    compiler = select(model, ["compiler/reflaxe.php/src/reflaxe/php/Printer.hx"])
    compiler_ids = {entry["testId"] for entry in compiler["selected"]}
    required_compiler = {
        "testing-strategy-contract",
        "repository-bootstrap",
        "generic-php-focused",
        "ordinary-haxe-php-tracer",
        "generic-php-package",
        "wordpress-profile-focused",
        "wordpress-public-php-runtime",
    }
    if not required_compiler <= compiler_ids or compiler["fallbackReasons"]:
        raise StrategyError("compiler reverse-dependency selection is incomplete")
    gutenberg = select(model, ["packages/gutenberg/src/wordpress/hx/gutenberg/data/DataStore.hx"])
    gutenberg_ids = {entry["testId"] for entry in gutenberg["selected"]}
    required_gutenberg = {
        "testing-strategy-contract",
        "repository-bootstrap",
        "gutenberg-browser-profile",
        "todo-data-store-example",
    }
    if not required_gutenberg <= gutenberg_ids or gutenberg["fallbackReasons"]:
        raise StrategyError("Gutenberg semantic-owner selection is incomplete")
    development = select(model, ["packages/cli/src/wordpresshx/cli/project/development/RunningService.hx"])
    development_ids = {entry["testId"] for entry in development["selected"]}
    if "development-service-runtime" not in development_ids or development["fallbackReasons"]:
        raise StrategyError("development-service semantic ownership is missing")
    security = select(model, ["scripts/security/test-unsafe-boundary-policy.py"])
    security_ids = {entry["testId"] for entry in security["selected"]}
    if "unsafe-boundary-policy" not in security_ids or security["fallbackReasons"]:
        raise StrategyError("unsafe-boundary semantic ownership is missing")
    required_shared_wordpress = {
        "wordpress-runtime-harness",
        "wordpress-public-php-runtime",
        "output-context-vertical",
        "plugin-package-install",
        "editor-sidebar-example",
        "todo-data-store-example",
        "static-block-migration",
    }
    for shared_path in ("scripts/wordpress/verify-distribution.py", "docker/wordpress/compose.yml"):
        shared_wordpress = select(model, [shared_path])
        shared_wordpress_ids = {entry["testId"] for entry in shared_wordpress["selected"]}
        if not required_shared_wordpress <= shared_wordpress_ids or shared_wordpress["fallbackReasons"]:
            raise StrategyError(f"shared WordPress infrastructure fan-out is incomplete for {shared_path}")

    mutations: list[tuple[str, object]] = []
    missing_surface = copy.deepcopy(model)
    require_list(missing_surface.get("surfaces"), "mutation surfaces").pop()
    mutations.append(("missing-surface", missing_surface))
    release_laundering = copy.deepcopy(model)
    first_surface = require_dict(require_list(release_laundering.get("surfaces"), "mutation surfaces")[0], "mutation surface")
    first_surface["releaseCommand"] = "invented release proof"
    mutations.append(("release-laundering", release_laundering))
    authoritative_selector = copy.deepcopy(model)
    require_dict(authoritative_selector.get("selector"), "mutation selector")["mode"] = "authoritative"
    mutations.append(("premature-authoritative-selector", authoritative_selector))
    cross_surface_claim = copy.deepcopy(model)
    first_owner = require_dict(require_list(cross_surface_claim.get("testOwners"), "mutation owners")[0], "mutation owner")
    first_owner["surfaces"] = ["invented-surface"]
    mutations.append(("cross-surface-claim", cross_surface_claim))
    valid_surface_laundering = copy.deepcopy(model)
    laundering_owner = next(
        owner
        for owner in require_list(valid_surface_laundering.get("testOwners"), "mutation owners")
        if isinstance(owner, dict) and owner.get("testId") == "plugin-package-install"
    )
    require_dict(laundering_owner, "mutation laundering owner")["surfaces"] = ["package-install"]
    mutations.append(("valid-surface-laundering", valid_surface_laundering))
    empty_scenario = copy.deepcopy(model)
    scenario = require_dict(require_dict(empty_scenario.get("representativeWorkflow"), "mutation workflow").get("scenario"), "mutation scenario")
    scenario["observableResult"] = ""
    mutations.append(("empty-scenario", empty_scenario))
    for label, mutation in mutations:
        try:
            validate_strategy(require_dict(mutation, f"mutation {label}"))
        except StrategyError:
            continue
        raise StrategyError(f"testing strategy mutation passed unexpectedly: {label}")

    baseline_mutations: list[tuple[str, dict[str, object], dict[str, object]]] = []
    duplicate_workflow = copy.deepcopy(baseline)
    hosted = require_list(duplicate_workflow.get("hostedBefore"), "mutation hostedBefore")
    require_dict(hosted[1], "mutation hosted sample")["workflow"] = require_dict(hosted[0], "mutation hosted sample")["workflow"]
    baseline_mutations.append(("duplicate-hosted-workflow", duplicate_workflow, model))
    empty_post_samples = copy.deepcopy(baseline)
    require_dict(empty_post_samples.get("postChange"), "mutation postChange")["localSamples"] = [{}]
    baseline_mutations.append(("empty-post-sample", empty_post_samples, model))
    fabricated_proof_model = copy.deepcopy(model)
    fabricated_surface = require_dict(require_list(fabricated_proof_model.get("surfaces"), "mutation surfaces")[0], "mutation surface")
    fabricated_proof = require_dict(require_list(fabricated_surface.get("lastCleanProofs"), "mutation proofs")[0], "mutation proof")
    fabricated_proof["jobId"] = 1
    baseline_mutations.append(("fabricated-proof-identity", baseline, fabricated_proof_model))
    swapped_coverage_model = copy.deepcopy(model)
    swapped_surface = require_dict(require_list(swapped_coverage_model.get("surfaces"), "mutation surfaces")[0], "mutation surface")
    swapped_proofs = require_list(swapped_surface.get("lastCleanProofs"), "mutation proofs")
    first_coverage = require_dict(swapped_proofs[0], "mutation proof").get("ownersCovered")
    second_coverage = require_dict(swapped_proofs[1], "mutation proof").get("ownersCovered")
    require_dict(swapped_proofs[0], "mutation proof")["ownersCovered"] = second_coverage
    require_dict(swapped_proofs[1], "mutation proof")["ownersCovered"] = first_coverage
    baseline_mutations.append(("swapped-valid-job-owner-coverage", baseline, swapped_coverage_model))
    incomplete_post_hosted = copy.deepcopy(baseline)
    mutated_post = require_dict(incomplete_post_hosted.get("postChange"), "mutation postChange")
    mutated_hosted_runs = require_list(mutated_post.get("hostedRuns"), "mutation postChange hostedRuns")
    if mutated_hosted_runs:
        first_hosted_run = require_dict(mutated_hosted_runs[0], "mutation postChange hosted run")
        require_list(first_hosted_run.get("jobs"), "mutation postChange hosted jobs").pop()
    else:
        mutated_post["hostedStatus"] = "passed"
    baseline_mutations.append(("incomplete-post-hosted-evidence", incomplete_post_hosted, model))
    reused_cross_workflow_job = copy.deepcopy(baseline)
    reused_post = require_dict(reused_cross_workflow_job.get("postChange"), "mutation postChange")
    reused_post["hostedStatus"] = "passed"
    synthetic_runs: list[object] = []
    next_job_id = 1000
    for run_index, (workflow, job_names) in enumerate(EXPECTED_POST_HOSTED_JOBS.items()):
        synthetic_jobs: list[object] = []
        for job_name in sorted(job_names):
            synthetic_jobs.append({"name": job_name, "jobId": next_job_id, "durationMilliseconds": 1, "status": "passed"})
            next_job_id += 1
        synthetic_runs.append({"workflow": workflow, "runId": 2000 + run_index, "commit": "a" * 40, "status": "passed", "jobs": synthetic_jobs})
    first_run = require_dict(synthetic_runs[0], "mutation first hosted run")
    second_run = require_dict(synthetic_runs[1], "mutation second hosted run")
    reused_job_id = require_dict(require_list(first_run.get("jobs"), "mutation first hosted jobs")[0], "mutation first hosted job").get("jobId")
    require_dict(require_list(second_run.get("jobs"), "mutation second hosted jobs")[0], "mutation second hosted job")["jobId"] = reused_job_id
    reused_post["hostedRuns"] = synthetic_runs
    baseline_mutations.append(("reused-cross-workflow-job-identity", reused_cross_workflow_job, model))
    for label, mutated_baseline, mutated_model in baseline_mutations:
        try:
            validate_baseline(mutated_baseline, mutated_model)
        except StrategyError:
            continue
        raise StrategyError(f"testing strategy baseline mutation passed unexpectedly: {label}")

    if historical_validation_action(True, False) != "validate-source-and-tree":
        raise StrategyError("complete history did not validate the exact historical subject")
    if historical_validation_action(True, True) != "validate-source-and-tree":
        raise StrategyError("available history was skipped merely because the checkout is shallow")
    if historical_validation_action(False, True) != "retain-receipt-identity-only":
        raise StrategyError("missing shallow history did not retain bounded receipt identity")
    try:
        historical_validation_action(False, False)
    except StrategyError:
        pass
    else:
        raise StrategyError("complete history accepted a missing historical subject")

    print("testing strategy self-test passed: 7 selector classes, 6 strategy mutations, 6 evidence mutations, 4 history modes, conservative fallback, reverse dependencies")


def print_human(result: dict[str, object]) -> None:
    print(f"mode: {result['mode']} (never authoritative for skipping)")
    print("changed paths:")
    for path in result["changedPaths"]:
        print(f"  - {path}")
    if result["fallbackReasons"]:
        print("fallback:")
        for reason in result["fallbackReasons"]:
            print(f"  - {reason}")
    print("selected owners:")
    for entry in result["selected"]:
        print(f"  - {entry['testId']}: {', '.join(entry['reasons'])}")
        print(f"    command: {entry['command']}")
    print("omitted owners:")
    for test_id in result["omitted"]:
        print(f"  - {test_id}")
    print(f"full backstop: {result['backstop']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate")
    subparsers.add_parser("self-test")
    selection = subparsers.add_parser("select")
    source = selection.add_mutually_exclusive_group(required=True)
    source.add_argument("--changed", action="append", default=[])
    source.add_argument("--base")
    selection.add_argument("--json", action="store_true")
    arguments = parser.parse_args()

    try:
        model = strict_json(STRATEGY_PATH)
        baseline = strict_json(BASELINE_PATH)
        validate_strategy(model)
        validate_red_proof(strict_json(RED_PROOF_PATH))
        validate_baseline(baseline, model)
        if arguments.command == "validate":
            print("testing strategy passed: 5 independent surfaces, 6 rings, 2 executable examples, measured baseline")
        elif arguments.command == "self-test":
            self_test(model, baseline)
        else:
            changed = arguments.changed if arguments.base is None else changed_from_base(arguments.base)
            result = select(model, changed)
            if arguments.json:
                print(json.dumps(result, indent=2, sort_keys=True))
            else:
                print_human(result)
    except (StrategyError, subprocess.CalledProcessError) as error:
        print(f"testing strategy error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
