#!/usr/bin/env python3
"""Generate and validate the bounded reflaxe.php qualification contract."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import NoReturn


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "manifests" / "reflaxe-php-qualification.json"
TOOLCHAIN_PATH = ROOT / "manifests" / "toolchain.lock.json"
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
CASE_PATTERN = re.compile(r"new\s+(Test[A-Za-z0-9_]+)\s*\(")
PINNED_AUTHORITY_FILES = [
    {
        "path": "README.md",
        "gitBlob": "b7ee7589db0227141c962c0d91ba6b0141f2409b",
        "sha256": "708b5a3386662e375c8bf90493687a764e9b7d251c500db854c8f76c570685ae",
    },
    {
        "path": "extra/LICENSE.txt",
        "gitBlob": "b4142af748da6420ab697e7485b105c8e6689486",
        "sha256": "f84691d619932ebfd4fa3568f8311f87ed4bf12e747e9aaa619a92cb1d2d359d",
    },
    {
        "path": "tests/unit/compile-each.hxml",
        "gitBlob": "aabb2eea52172b6f12ae072fdfd0c6a61224f0dd",
        "sha256": "7b97cd643c2fb5af847603da3f1ad464c8edd0f4d3b32fb77db994e2eca7e911",
    },
    {
        "path": "tests/unit/compile-php.hxml",
        "gitBlob": "84ab6768a246ccdfa0a92fb9917eb0aeeedbcc20",
        "sha256": "e746bc165fba324f582e70150b878a489e357ca6834ee03b692d39b07aa9cda5",
    },
    {
        "path": "tests/unit/src/unit/TestMain.hx",
        "gitBlob": "cb505fd0f7fa1e19da51164fc6e1827d7c9cc67a",
        "sha256": "0cd5d2832f8903649bf45138dd38dd8f4eeec2051c5446c4c1f98834335329dc",
    },
    {
        "path": "tests/unit/src/unit/UnitBuilder.hx",
        "gitBlob": "43c6e396c75e753d1f17a4e8c0b93eb3005d5006",
        "sha256": "905f81c59ffc21fb49b0a9f340db03381ed67980cd62ee6b58beffeae7af4fd3",
    },
    {
        "path": "tests/unit/src/unit/TestIssues.hx",
        "gitBlob": "f6dbea087e6847c1b5390e62b3a9c670388d7882",
        "sha256": "e15d323e384d190d355784053843eaabe040e4ab889fc0ae902d8d777659ec3a",
    },
]
PINNED_CANDIDATE_SETS = [
    {
        "candidateId": "unitstd",
        "root": "tests/unit/src/unitstd/",
        "selection": "recursive files ending .unit.hx",
        "count": 67,
        "pathBlobSha256": "a8f5688a650bfcd7120bac7a14b0fdedcc43640a5fa47336b2def656cac7463c",
    },
    {
        "candidateId": "issues",
        "root": "tests/unit/src/unit/issues/",
        "selection": "recursive Haxe source files",
        "count": 1112,
        "pathBlobSha256": "519199187a1e1a31e2e2da5e2c1e4a3352cb5717697dd131cb6b5f74bf59c85d",
    },
    {
        "candidateId": "hxcppIssues",
        "root": "tests/unit/src/unit/hxcpp_issues/",
        "selection": "recursive Haxe source files",
        "count": 8,
        "pathBlobSha256": "03d9ef4a512d8af5334bb6d4804070e65551f6985e792e9c0f23fc1b3c4a65e1",
    },
]
PINNED_TOP_LEVEL_COUNT = 50
PINNED_TOP_LEVEL_SHA256 = "34ef2443ed74d025f257bafe94adc7d40e5a5ee8a02d9d971b73eb408d29e1a4"


class QualificationError(RuntimeError):
    """A closed qualification invariant failed."""


def fail(message: str) -> NoReturn:
    raise QualificationError(message)


def load_json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        fail(f"{path.relative_to(ROOT)} must contain an object")
    return value


def require_dict(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        fail(f"{label} must be an object")
    return value


def require_list(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        fail(f"{label} must be an array")
    return value


def exact_keys(value: dict[str, object], expected: set[str], label: str) -> None:
    actual = set(value)
    if actual != expected:
        fail(f"{label} keys differ; missing={sorted(expected - actual)}, extra={sorted(actual - expected)}")


def strings(value: object, label: str, *, allow_empty: bool = False) -> list[str]:
    items = require_list(value, label)
    if not all(isinstance(item, str) and item for item in items):
        fail(f"{label} must contain non-empty strings")
    result = [item for item in items if isinstance(item, str)]
    if not allow_empty and not result:
        fail(f"{label} must not be empty")
    if len(result) != len(set(result)):
        fail(f"{label} contains duplicates")
    return result


def git(upstream: Path, *arguments: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(upstream), *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        fail(f"upstream Git command failed: {' '.join(arguments)}: {detail}")
    return result.stdout


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def inventory_digest(entries: list[tuple[str, str]]) -> str:
    transcript = "".join(f"{path}\t{blob}\n" for path, blob in sorted(entries))
    return sha256_bytes(transcript.encode("utf-8"))


def source_file(upstream: Path, commit: str, path: str) -> tuple[bytes, str]:
    content = git(upstream, "show", f"{commit}:{path}")
    blob = git(upstream, "rev-parse", f"{commit}:{path}").decode().strip()
    if not HEX_40.fullmatch(blob):
        fail(f"invalid Git blob identity for {path}")
    return content, blob


def discover_top_level_cases(source: bytes) -> list[dict[str, object]]:
    stack: list[str] = []
    cases: list[dict[str, object]] = []
    for line_number, raw_line in enumerate(source.decode("utf-8").splitlines(), start=1):
        stripped = raw_line.strip()
        if stripped.startswith("//"):
            continue
        inline = re.match(r"#if\s+(.+?)\s+(new\s+Test[A-Za-z0-9_]+\s*\(.*)#end", stripped)
        if inline:
            condition = inline.group(1).strip()
            match = CASE_PATTERN.search(inline.group(2))
            if match:
                cases.append({"name": match.group(1), "line": line_number, "guards": [condition]})
            continue
        if stripped.startswith("#if "):
            stack.append(stripped[4:].strip())
            continue
        if stripped.startswith("#elseif "):
            if not stack:
                fail("TestMain contains #elseif without #if")
            stack[-1] = stripped[8:].strip()
            continue
        if stripped == "#else":
            if not stack:
                fail("TestMain contains #else without #if")
            stack[-1] = f"else({stack[-1]})"
            continue
        if stripped == "#end":
            if not stack:
                fail("TestMain contains #end without #if")
            stack.pop()
            continue
        match = CASE_PATTERN.search(stripped)
        if match:
            cases.append({"name": match.group(1), "line": line_number, "guards": list(stack)})
    if stack:
        fail("TestMain contains an unterminated preprocessor condition")
    names = [str(item["name"]) for item in cases]
    if len(names) != len(set(names)):
        fail("TestMain case discovery produced duplicate names")
    return cases


def build_contract(upstream: Path) -> dict[str, object]:
    lock = load_json(TOOLCHAIN_PATH)
    compilers = require_dict(lock.get("compilers"), "toolchain.compilers")
    haxe = require_dict(compilers.get("haxe"), "toolchain.compilers.haxe")
    runtime_images = require_dict(lock.get("runtimeImages"), "toolchain.runtimeImages")
    php = require_dict(runtime_images.get("php"), "toolchain.runtimeImages.php")
    commit = str(haxe.get("commit"))
    tree = git(upstream, "rev-parse", f"{commit}^{{tree}}").decode().strip()
    if tree != haxe.get("tree"):
        fail(f"pinned Haxe tree mismatch: expected {haxe.get('tree')}, got {tree}")

    listing = git(
        upstream,
        "ls-tree",
        "-r",
        "--format=%(objectname)%x09%(path)",
        commit,
        "--",
        "tests/unit/src",
    ).decode("utf-8")
    all_entries: list[tuple[str, str]] = []
    for line in listing.splitlines():
        blob, path = line.split("\t", 1)
        if not HEX_40.fullmatch(blob):
            fail(f"invalid blob identity in upstream inventory: {path}")
        all_entries.append((path, blob))

    roots = [
        ("unitstd", "tests/unit/src/unitstd/", lambda path: path.endswith(".unit.hx")),
        ("issues", "tests/unit/src/unit/issues/", lambda path: path.endswith(".hx")),
        ("hxcppIssues", "tests/unit/src/unit/hxcpp_issues/", lambda path: path.endswith(".hx")),
    ]
    candidate_sets: list[dict[str, object]] = []
    for candidate_id, root, predicate in roots:
        entries = [(path, blob) for path, blob in all_entries if path.startswith(root) and predicate(path)]
        candidate_sets.append(
            {
                "candidateId": candidate_id,
                "root": root,
                "selection": "recursive files ending .unit.hx" if candidate_id == "unitstd" else "recursive Haxe source files",
                "count": len(entries),
                "pathBlobSha256": inventory_digest(entries),
            }
        )

    authority_paths = [
        "README.md",
        "extra/LICENSE.txt",
        "tests/unit/compile-each.hxml",
        "tests/unit/compile-php.hxml",
        "tests/unit/src/unit/TestMain.hx",
        "tests/unit/src/unit/UnitBuilder.hx",
        "tests/unit/src/unit/TestIssues.hx",
    ]
    authorities: list[dict[str, str]] = []
    authority_content: dict[str, bytes] = {}
    for path in authority_paths:
        content, blob = source_file(upstream, commit, path)
        authority_content[path] = content
        authorities.append({"path": path, "gitBlob": blob, "sha256": sha256_bytes(content)})

    top_level = discover_top_level_cases(authority_content["tests/unit/src/unit/TestMain.hx"])
    syntax_floor = require_dict(php.get("syntaxFloor"), "toolchain PHP syntaxFloor")
    primary_cli = require_dict(php.get("primaryCli"), "toolchain PHP primaryCli")
    return {
        "schemaVersion": 1,
        "contractId": "reflaxe-php-qualification-v1",
        "status": "candidate-inventory-locked-active-qualification-unproven",
        "authority": {
            "bead": "wordpresshx-reflaxe-php.1",
            "compilerSurface": "compiler-adapter",
            "driverBead": "wordpresshx-reflaxe-php.2",
            "executionBead": "wordpresshx-reflaxe-php.4",
            "publicClaimAllowed": False,
        },
        "upstreamHaxe": {
            "repository": haxe.get("repository"),
            "version": haxe.get("version"),
            "commit": commit,
            "tree": tree,
            "licenseConclusion": "pending-exact-suite-file-review",
            "suiteRoot": "tests/unit",
            "authorityFiles": authorities,
        },
        "candidateInventory": {
            "derivation": "git-tree-path-and-blob-identities-from-exact-commit",
            "candidateSets": candidate_sets,
            "topLevelRegistrations": top_level,
            "topLevelRegistrationSha256": sha256_bytes(
                json.dumps(top_level, sort_keys=True, separators=(",", ":")).encode("utf-8")
            ),
            "presenceIsPass": False,
        },
        "activeInventoryContract": {
            "available": False,
            "producer": "production-reflaxe-php-driver-after-preprocessing-macro-registration-and-target-defines",
            "requiredCaseDispositions": [
                "active-applicable",
                "adapted-with-provenance",
                "unsupported-owned",
                "target-inapplicable",
            ],
            "requiredObservationFields": [
                "sourceIdentity",
                "activeAssertionIdentity",
                "targetDefines",
                "capabilities",
                "compileCommand",
                "phpCheckCommand",
                "runtimeCommand",
                "outcome",
                "oracle",
            ],
            "inactiveOrDummyMayPass": False,
            "unownedSkipAllowed": False,
            "adaptationRequiresExactPatchAndRationale": True,
            "officialPhpSpecificCasePolicy": "manual-semantic-decision-not-automatic-custom-target-evidence",
        },
        "declaredProfiles": {
            "haxeVersion": haxe.get("version"),
            "haxeCommit": commit,
            "phpSyntaxFloor": {
                "version": syntax_floor.get("version"),
                "image": syntax_floor.get("reference"),
            },
            "phpPrimaryRuntime": {
                "version": primary_cli.get("version"),
                "image": primary_cli.get("reference"),
            },
            "driverAvailable": False,
            "runtimeStdlibMatrixAvailable": False,
        },
        "independentOracles": [
            "pinned-official-haxe-test-expectations-and-language-semantics",
            "manually-reviewed-minimal-php-expectations",
            "native-php-parser-and-runtime-observation",
        ],
        "surfaceIsolation": {
            "qualificationSurface": "compiler-adapter",
            "nonQualifyingSurfaces": [
                "wordpress-runtime-abi",
                "package-install",
                "gutenberg-browser",
                "migration-downstream",
            ],
            "crossSurfaceEvidenceMayAdvanceCompilerClaim": False,
            "compilerEvidenceMayAdvanceOtherClaims": False,
        },
        "workflow": {
            "scenarioFields": [
                "preconditions",
                "input",
                "actionOrCompilationPath",
                "observableResult",
                "errorOrEdgeBehavior",
                "owningSurface",
                "protectedClaim",
            ],
            "redEvidenceRequired": True,
            "tracerBeforeExpansion": True,
            "focusedAndRuntimeDoubleLock": True,
            "distinctHighRiskReviewRequired": True,
            "rings": ["R0", "R1", "R2", "R3", "R4", "R5"],
        },
        "sharedReflaxePolicy": {
            "suiteTransportLocal": True,
            "classificationLocal": True,
            "orchestrationLocal": True,
            "sharedFrameworkChangeRequiresTwoTargets": True,
        },
        "extraction": {
            "priority": "low",
            "currentHome": "compiler/reflaxe.php",
            "futureBead": "wordpresshx-reflaxe-php.5",
            "dependencyDirection": "compiler/reflaxe.php <- compiler/wordpress <- SDK",
        },
        "residualBeads": [
            "wordpresshx-reflaxe-php.2",
            "wordpresshx-reflaxe-php.3",
            "wordpresshx-reflaxe-php.4",
            "wordpresshx-reflaxe-php.5",
            "wordpresshx-reflaxe-php.6",
        ],
    }


def validate_contract(model: dict[str, object]) -> None:
    exact_keys(
        model,
        {
            "schemaVersion",
            "contractId",
            "status",
            "authority",
            "upstreamHaxe",
            "candidateInventory",
            "activeInventoryContract",
            "declaredProfiles",
            "independentOracles",
            "surfaceIsolation",
            "workflow",
            "sharedReflaxePolicy",
            "extraction",
            "residualBeads",
        },
        "contract",
    )
    if model.get("schemaVersion") != 1 or model.get("contractId") != "reflaxe-php-qualification-v1":
        fail("qualification contract identity changed")
    if model.get("status") != "candidate-inventory-locked-active-qualification-unproven":
        fail("qualification status overstates current evidence")

    lock = load_json(TOOLCHAIN_PATH)
    compilers = require_dict(lock.get("compilers"), "toolchain.compilers")
    haxe_lock = require_dict(compilers.get("haxe"), "toolchain.compilers.haxe")
    upstream = require_dict(model.get("upstreamHaxe"), "upstreamHaxe")
    exact_keys(
        upstream,
        {"repository", "version", "commit", "tree", "licenseConclusion", "suiteRoot", "authorityFiles"},
        "upstreamHaxe",
    )
    for field in ("repository", "version", "commit", "tree"):
        if upstream.get(field) != haxe_lock.get(field):
            fail(f"upstreamHaxe.{field} differs from the toolchain lock")
    if upstream.get("licenseConclusion") != "pending-exact-suite-file-review" or upstream.get("suiteRoot") != "tests/unit":
        fail("upstream Haxe license or suite root changed")
    authorities = require_list(upstream.get("authorityFiles"), "upstreamHaxe.authorityFiles")
    if len(authorities) != 7:
        fail("upstream authority file inventory changed")
    for index, raw in enumerate(authorities):
        item = require_dict(raw, f"authorityFiles[{index}]")
        exact_keys(item, {"path", "gitBlob", "sha256"}, f"authorityFiles[{index}]")
        if not isinstance(item.get("path"), str) or not item.get("path"):
            fail("authority file path is invalid")
        if not isinstance(item.get("gitBlob"), str) or not HEX_40.fullmatch(str(item.get("gitBlob"))):
            fail("authority file Git blob is invalid")
        if not isinstance(item.get("sha256"), str) or not HEX_64.fullmatch(str(item.get("sha256"))):
            fail("authority file SHA-256 is invalid")
    if authorities != PINNED_AUTHORITY_FILES:
        fail("upstream authority file identities differ from the pinned Haxe 4.3.7 source")

    authority = require_dict(model.get("authority"), "authority")
    exact_keys(authority, {"bead", "compilerSurface", "driverBead", "executionBead", "publicClaimAllowed"}, "authority")
    if authority != {
        "bead": "wordpresshx-reflaxe-php.1",
        "compilerSurface": "compiler-adapter",
        "driverBead": "wordpresshx-reflaxe-php.2",
        "executionBead": "wordpresshx-reflaxe-php.4",
        "publicClaimAllowed": False,
    }:
        fail("qualification authority changed")

    inventory = require_dict(model.get("candidateInventory"), "candidateInventory")
    exact_keys(
        inventory,
        {"derivation", "candidateSets", "topLevelRegistrations", "topLevelRegistrationSha256", "presenceIsPass"},
        "candidateInventory",
    )
    if inventory.get("derivation") != "git-tree-path-and-blob-identities-from-exact-commit":
        fail("candidate inventory is not source-derived")
    if inventory.get("presenceIsPass") is not False:
        fail("candidate presence is being counted as a pass")
    candidate_sets = require_list(inventory.get("candidateSets"), "candidateInventory.candidateSets")
    expected_ids = {"unitstd", "issues", "hxcppIssues"}
    actual_ids: set[str] = set()
    for index, raw in enumerate(candidate_sets):
        item = require_dict(raw, f"candidateSets[{index}]")
        exact_keys(item, {"candidateId", "root", "selection", "count", "pathBlobSha256"}, f"candidateSets[{index}]")
        candidate_id = item.get("candidateId")
        if not isinstance(candidate_id, str) or candidate_id in actual_ids:
            fail("candidate set identity is invalid")
        if not isinstance(item.get("count"), int) or int(item.get("count", 0)) <= 0:
            fail(f"candidate set {candidate_id} has no source-derived entries")
        if not isinstance(item.get("pathBlobSha256"), str) or not HEX_64.fullmatch(str(item.get("pathBlobSha256"))):
            fail(f"candidate set {candidate_id} digest is invalid")
        actual_ids.add(candidate_id)
    if actual_ids != expected_ids:
        fail("candidate set inventory changed")
    if candidate_sets != PINNED_CANDIDATE_SETS:
        fail("candidate set identities differ from the pinned Haxe 4.3.7 source")
    registrations = require_list(inventory.get("topLevelRegistrations"), "candidateInventory.topLevelRegistrations")
    if len(registrations) != PINNED_TOP_LEVEL_COUNT:
        fail("top-level registration inventory count changed")
    registration_bytes = json.dumps(registrations, sort_keys=True, separators=(",", ":")).encode("utf-8")
    if inventory.get("topLevelRegistrationSha256") != sha256_bytes(registration_bytes):
        fail("top-level registration digest mismatch")
    if inventory.get("topLevelRegistrationSha256") != PINNED_TOP_LEVEL_SHA256:
        fail("top-level registrations differ from the pinned Haxe 4.3.7 source")

    active = require_dict(model.get("activeInventoryContract"), "activeInventoryContract")
    exact_keys(
        active,
        {
            "available",
            "producer",
            "requiredCaseDispositions",
            "requiredObservationFields",
            "inactiveOrDummyMayPass",
            "unownedSkipAllowed",
            "adaptationRequiresExactPatchAndRationale",
            "officialPhpSpecificCasePolicy",
        },
        "activeInventoryContract",
    )
    if active.get("available") is not False:
        fail("active inventory is claimed before the production driver exists")
    required_dispositions = strings(active.get("requiredCaseDispositions"), "requiredCaseDispositions")
    if set(required_dispositions) != {
        "active-applicable",
        "adapted-with-provenance",
        "unsupported-owned",
        "target-inapplicable",
    }:
        fail("active case dispositions are not closed")
    strings(active.get("requiredObservationFields"), "requiredObservationFields")
    if active.get("inactiveOrDummyMayPass") is not False or active.get("unownedSkipAllowed") is not False:
        fail("inactive or unowned test evidence is admitted")
    if active.get("adaptationRequiresExactPatchAndRationale") is not True:
        fail("test adaptations lost provenance requirements")

    profiles = require_dict(model.get("declaredProfiles"), "declaredProfiles")
    exact_keys(
        profiles,
        {"haxeVersion", "haxeCommit", "phpSyntaxFloor", "phpPrimaryRuntime", "driverAvailable", "runtimeStdlibMatrixAvailable"},
        "declaredProfiles",
    )
    if profiles.get("haxeVersion") != haxe_lock.get("version") or profiles.get("haxeCommit") != haxe_lock.get("commit"):
        fail("declared Haxe profile differs from the lock")
    if profiles.get("driverAvailable") is not False or profiles.get("runtimeStdlibMatrixAvailable") is not False:
        fail("compiler implementation status is overstated")
    php_lock = require_dict(require_dict(lock.get("runtimeImages"), "runtimeImages").get("php"), "runtimeImages.php")
    for contract_key, lock_key in (("phpSyntaxFloor", "syntaxFloor"), ("phpPrimaryRuntime", "primaryCli")):
        declared = require_dict(profiles.get(contract_key), contract_key)
        locked = require_dict(php_lock.get(lock_key), lock_key)
        if declared != {"version": locked.get("version"), "image": locked.get("reference")}:
            fail(f"{contract_key} differs from the runtime lock")

    oracles = strings(model.get("independentOracles"), "independentOracles")
    if any("implementation-under-test" in oracle for oracle in oracles):
        fail("the implementation under test became its own oracle")
    isolation = require_dict(model.get("surfaceIsolation"), "surfaceIsolation")
    exact_keys(
        isolation,
        {"qualificationSurface", "nonQualifyingSurfaces", "crossSurfaceEvidenceMayAdvanceCompilerClaim", "compilerEvidenceMayAdvanceOtherClaims"},
        "surfaceIsolation",
    )
    if isolation.get("qualificationSurface") != "compiler-adapter":
        fail("official Haxe qualification escaped the compiler surface")
    if set(strings(isolation.get("nonQualifyingSurfaces"), "nonQualifyingSurfaces")) != {
        "wordpress-runtime-abi",
        "package-install",
        "gutenberg-browser",
        "migration-downstream",
    }:
        fail("non-qualifying surface inventory changed")
    if isolation.get("crossSurfaceEvidenceMayAdvanceCompilerClaim") is not False:
        fail("cross-surface evidence can advance the compiler claim")
    if isolation.get("compilerEvidenceMayAdvanceOtherClaims") is not False:
        fail("compiler evidence can advance another product claim")

    workflow = require_dict(model.get("workflow"), "workflow")
    exact_keys(
        workflow,
        {"scenarioFields", "redEvidenceRequired", "tracerBeforeExpansion", "focusedAndRuntimeDoubleLock", "distinctHighRiskReviewRequired", "rings"},
        "workflow",
    )
    if any(workflow.get(key) is not True for key in ("redEvidenceRequired", "tracerBeforeExpansion", "focusedAndRuntimeDoubleLock", "distinctHighRiskReviewRequired")):
        fail("behavior-first compiler workflow weakened")
    if strings(workflow.get("rings"), "workflow.rings") != ["R0", "R1", "R2", "R3", "R4", "R5"]:
        fail("R0-R5 ownership changed")
    strings(workflow.get("scenarioFields"), "workflow.scenarioFields")

    shared = require_dict(model.get("sharedReflaxePolicy"), "sharedReflaxePolicy")
    exact_keys(shared, {"suiteTransportLocal", "classificationLocal", "orchestrationLocal", "sharedFrameworkChangeRequiresTwoTargets"}, "sharedReflaxePolicy")
    if any(shared.get(key) is not True for key in shared):
        fail("repository-local qualification ownership weakened")
    extraction = require_dict(model.get("extraction"), "extraction")
    exact_keys(extraction, {"priority", "currentHome", "futureBead", "dependencyDirection"}, "extraction")
    if extraction != {
        "priority": "low",
        "currentHome": "compiler/reflaxe.php",
        "futureBead": "wordpresshx-reflaxe-php.5",
        "dependencyDirection": "compiler/reflaxe.php <- compiler/wordpress <- SDK",
    }:
        fail("compiler extraction priority or dependency direction changed")
    strings(model.get("residualBeads"), "residualBeads")


def canonical_bytes(model: dict[str, object]) -> bytes:
    return (json.dumps(model, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def verify_upstream(model: dict[str, object], upstream: Path) -> None:
    regenerated = build_contract(upstream)
    if canonical_bytes(model) != canonical_bytes(regenerated):
        fail("checked-in qualification contract differs from the pinned upstream source")


def self_test(model: dict[str, object]) -> None:
    mutations: list[tuple[str, object]] = []

    stale_pin = copy.deepcopy(model)
    require_dict(stale_pin["upstreamHaxe"], "upstreamHaxe")["commit"] = "0" * 40
    mutations.append(("stale upstream pin", stale_pin))

    changed_authority = copy.deepcopy(model)
    changed_authorities = require_list(
        require_dict(changed_authority["upstreamHaxe"], "upstreamHaxe")["authorityFiles"],
        "authorityFiles",
    )
    require_dict(changed_authorities[0], "authorityFiles[0]")["sha256"] = "0" * 64
    mutations.append(("changed authority file", changed_authority))

    changed_candidates = copy.deepcopy(model)
    changed_sets = require_list(
        require_dict(changed_candidates["candidateInventory"], "candidateInventory")["candidateSets"],
        "candidateSets",
    )
    require_dict(changed_sets[0], "candidateSets[0]")["count"] = 68
    mutations.append(("changed candidate inventory", changed_candidates))

    changed_registration = copy.deepcopy(model)
    changed_registration_inventory = require_dict(
        changed_registration["candidateInventory"], "candidateInventory"
    )
    changed_registrations = require_list(
        changed_registration_inventory["topLevelRegistrations"], "topLevelRegistrations"
    )
    require_dict(changed_registrations[0], "topLevelRegistrations[0]")["name"] = "TestInvented"
    changed_registration_inventory["topLevelRegistrationSha256"] = sha256_bytes(
        json.dumps(changed_registrations, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    mutations.append(("changed top-level registration", changed_registration))

    invented_pass = copy.deepcopy(model)
    require_dict(invented_pass["candidateInventory"], "candidateInventory")["presenceIsPass"] = True
    mutations.append(("candidate presence pass", invented_pass))

    active_without_driver = copy.deepcopy(model)
    require_dict(active_without_driver["activeInventoryContract"], "activeInventoryContract")["available"] = True
    mutations.append(("active inventory before driver", active_without_driver))

    unowned_skip = copy.deepcopy(model)
    require_dict(unowned_skip["activeInventoryContract"], "activeInventoryContract")["unownedSkipAllowed"] = True
    mutations.append(("unowned skip", unowned_skip))

    inactive_pass = copy.deepcopy(model)
    require_dict(inactive_pass["activeInventoryContract"], "activeInventoryContract")["inactiveOrDummyMayPass"] = True
    mutations.append(("inactive pass", inactive_pass))

    circular_oracle = copy.deepcopy(model)
    circular_oracle["independentOracles"] = ["implementation-under-test-generated-golden"]
    mutations.append(("circular oracle", circular_oracle))

    evidence_laundering = copy.deepcopy(model)
    require_dict(evidence_laundering["surfaceIsolation"], "surfaceIsolation")["crossSurfaceEvidenceMayAdvanceCompilerClaim"] = True
    mutations.append(("cross-surface evidence", evidence_laundering))

    extraction_now = copy.deepcopy(model)
    require_dict(extraction_now["extraction"], "extraction")["priority"] = "high"
    mutations.append(("premature extraction", extraction_now))

    accepted = 0
    for label, mutation in mutations:
        try:
            validate_contract(require_dict(mutation, label))
        except QualificationError:
            accepted += 1
        else:
            fail(f"self-test mutation was accepted: {label}")
    print(f"reflaxe.php qualification self-test passed: {accepted} fail-closed mutations")


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    generate = subparsers.add_parser("generate")
    generate.add_argument("--upstream", type=Path, required=True)
    validate = subparsers.add_parser("validate")
    validate.add_argument("--upstream", type=Path)
    subparsers.add_parser("self-test")
    arguments = parser.parse_args()
    try:
        if arguments.command == "generate":
            model = build_contract(arguments.upstream.resolve())
            validate_contract(model)
            CONTRACT_PATH.write_bytes(canonical_bytes(model))
            print(f"wrote {CONTRACT_PATH.relative_to(ROOT)}")
            return 0
        model = load_json(CONTRACT_PATH)
        validate_contract(model)
        if arguments.command == "validate":
            if arguments.upstream is not None:
                verify_upstream(model, arguments.upstream.resolve())
            print("reflaxe.php qualification contract passed")
            return 0
        self_test(model)
        return 0
    except (QualificationError, json.JSONDecodeError) as error:
        print(f"reflaxe.php qualification error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
