#!/usr/bin/env python3
"""Validate the provisional ADR-020 inventory and fail-closed publication state."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


PUBLICATION_BLOCKED_MESSAGE = (
    "PUBLICATION BLOCKED: ADR-020 remains proposed and no repository-wide "
    "license grant exists; qualified review, owner approval, resolved "
    "inventory findings, and artifact notices are required."
)

SHA1 = re.compile(r"[0-9a-f]{40}")
SHA256 = re.compile(r"[0-9a-f]{64}")

EXPECTED_COMPONENT_IDS = [
    "actions-checkout-4.2.2",
    "beads-1.0.4",
    "docker-test-image-set",
    "genes-ts-1.33.0",
    "gitleaks-8.30.0",
    "gutenberg-23.4.0",
    "gutenberg-wp70-embedded",
    "haxe-4.3.7-compiler",
    "haxe-4.3.7-stdlib",
    "haxe-formatter-1.18.0",
    "helder-set-0.3.1",
    "html-entities-1.0.0",
    "krdlab-setup-haxe-2.1.0",
    "lix-15.12.4",
    "reflaxe-php-port-origin",
    "repository-original-work",
    "tink-anon-0.7.0",
    "tink-core-2.1.1",
    "tink-hxx-0.25.1",
    "tink-macro-0.23.0",
    "tink-parse-0.4.1",
    "wordpress-7.0",
]

EXPECTED_FINDING_IDS = [
    "derived-catalog-treatment-pending",
    "generated-runtime-boundary-not-inventoried",
    "haxelib-artifacts-missing-license-text",
    "lix-license-metadata-text-conflict",
    "root-original-work-no-license-grant",
    "tink-anon-license-metadata-text-conflict",
    "tink-hxx-license-metadata-text-conflict",
    "tink-parse-no-source-license-file",
]

EXPECTED_BLOCKERS = [
    "artifact-notice-generation-not-implemented",
    "contributor-rights-confirmation",
    "derived-contract-and-catalog-review",
    "generated-output-runtime-boundary-review",
    "hxx-and-lix-license-metadata-resolution",
    "qualified-license-review",
    "root-license-grant",
]

EXPECTED_ARTIFACT_CLASSES = [
    "build-ci-tools",
    "derived-profile-and-contract-data",
    "documentation-and-requirements",
    "examples-scaffolds-and-templates",
    "generated-application-output",
    "generated-runtime-support-and-boilerplate",
    "generic-php-compiler",
    "public-cli",
    "public-sdk-haxelib",
    "repository-operations-files",
    "wordpress-plugin-theme-site-artifacts",
]


class Audit:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[str] = []

    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def keys(self, value: Any, expected: set[str], context: str) -> None:
        if not isinstance(value, dict):
            self.errors.append(f"{context}: expected object")
            return
        actual = set(value)
        if actual != expected:
            self.errors.append(
                f"{context}: closed keys differ; expected {sorted(expected)}, "
                f"found {sorted(actual)}"
            )

    def read_json(self, path: Path, context: str) -> dict[str, Any]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            self.errors.append(f"{context}: cannot read valid JSON: {error}")
            return {}
        if not isinstance(value, dict):
            self.errors.append(f"{context}: top level must be an object")
            return {}
        return value

    def read_text(self, relative: str) -> str:
        path = self.root / relative
        try:
            return path.read_text(encoding="utf-8")
        except OSError as error:
            self.errors.append(f"{relative}: cannot read: {error}")
            return ""


def validate_policy(audit: Audit, policy: dict[str, Any]) -> None:
    audit.keys(
        policy,
        {
            "schemaVersion",
            "policyId",
            "decision",
            "status",
            "legalAdvice",
            "publication",
            "qualifiedReview",
            "candidateRecommendation",
            "artifactClasses",
            "outputPolicy",
            "noticePolicy",
            "changeControl",
            "claims",
        },
        "policy",
    )
    audit.check(policy.get("schemaVersion") == 1, "policy.schemaVersion must be 1")
    audit.check(
        policy.get("policyId") == "wordpresshx-licensing-provisional-v1",
        "policy.policyId must identify the provisional v1 policy",
    )
    audit.check(policy.get("decision") == "ADR-020", "policy.decision must be ADR-020")
    audit.check(
        policy.get("status") == "provisional-no-license-grant",
        "policy.status must remain provisional-no-license-grant before acceptance",
    )
    audit.check(policy.get("legalAdvice") is False, "policy.legalAdvice must be false")

    publication = policy.get("publication", {})
    audit.keys(
        publication,
        {
            "allowed",
            "registryPublicationAllowed",
            "releaseArchivePublicationAllowed",
            "wordpressDirectorySubmissionAllowed",
            "promotedPublicDownloadAllowed",
            "localEvidenceBuildAllowed",
            "gateExitCode",
            "blockingConditions",
        },
        "policy.publication",
    )
    for field in (
        "allowed",
        "registryPublicationAllowed",
        "releaseArchivePublicationAllowed",
        "wordpressDirectorySubmissionAllowed",
        "promotedPublicDownloadAllowed",
    ):
        audit.check(publication.get(field) is False, f"publication.{field} must be false")
    audit.check(
        publication.get("localEvidenceBuildAllowed") is True,
        "publication.localEvidenceBuildAllowed must be true",
    )
    audit.check(publication.get("gateExitCode") == 3, "publication.gateExitCode must be 3")
    audit.check(
        publication.get("blockingConditions") == EXPECTED_BLOCKERS,
        "publication.blockingConditions must be the complete sorted provisional set",
    )

    review = policy.get("qualifiedReview", {})
    audit.keys(
        review,
        {
            "required",
            "status",
            "reviewer",
            "qualification",
            "reviewedAt",
            "ownerApproval",
            "scope",
        },
        "policy.qualifiedReview",
    )
    audit.check(review.get("required") is True, "qualifiedReview.required must be true")
    audit.check(review.get("status") == "pending", "qualifiedReview.status must be pending")
    for field in ("reviewer", "qualification", "reviewedAt", "ownerApproval"):
        audit.check(review.get(field) is None, f"qualifiedReview.{field} must remain null")
    review_scope = review.get("scope")
    audit.check(
        isinstance(review_scope, list)
        and review_scope == sorted(review_scope)
        and len(review_scope) == 6,
        "qualifiedReview.scope must contain six sorted review areas",
    )

    recommendation = policy.get("candidateRecommendation", {})
    audit.keys(
        recommendation,
        {
            "notFinal",
            "repositoryOriginalWork",
            "publicSdkHaxelib",
            "publicCli",
            "genericPhpCompiler",
            "documentationExamplesScaffoldsTemplates",
            "derivedWordPressGutenbergCatalogs",
            "defaultGeneratedWordPressPackage",
            "generatedApplicationOutput",
            "reason",
        },
        "policy.candidateRecommendation",
    )
    audit.check(recommendation.get("notFinal") is True, "candidate must remain notFinal")
    for field in (
        "repositoryOriginalWork",
        "publicSdkHaxelib",
        "publicCli",
        "genericPhpCompiler",
        "documentationExamplesScaffoldsTemplates",
        "defaultGeneratedWordPressPackage",
    ):
        audit.check(
            recommendation.get(field) == "GPL-2.0-or-later",
            f"candidateRecommendation.{field} must be GPL-2.0-or-later",
        )
    audit.check(
        recommendation.get("generatedApplicationOutput")
        == "origin-sensitive-no-automatic-relicense",
        "generated output must remain origin-sensitive",
    )

    artifact_classes = policy.get("artifactClasses")
    audit.check(isinstance(artifact_classes, list), "artifactClasses must be an array")
    if isinstance(artifact_classes, list):
        for index, item in enumerate(artifact_classes):
            audit.keys(
                item,
                {
                    "id",
                    "currentPresence",
                    "candidateLicense",
                    "distribution",
                    "outputRule",
                    "noticeRule",
                    "status",
                },
                f"artifactClasses[{index}]",
            )
        audit.check(
            [item.get("id") for item in artifact_classes if isinstance(item, dict)]
            == EXPECTED_ARTIFACT_CLASSES,
            "artifactClasses must be the complete sorted closed set",
        )

    output_policy = policy.get("outputPolicy", {})
    audit.keys(
        output_policy,
        {
            "compilerLicenseAutomaticallyAppliesToAllOutput",
            "userInputCopyrightAutomaticallyTransferred",
            "copiedRuntimeOrBoilerplateMayCarrySourceLicense",
            "generatedManifestMustClassifyOrigins",
            "generatedManifestOrigins",
            "rawLicenseOverrideAllowed",
            "projectOwnerResponsibleForFinalPackage",
            "wordPressOrgCompatibilityReviewRequired",
        },
        "policy.outputPolicy",
    )
    audit.check(
        output_policy.get("compilerLicenseAutomaticallyAppliesToAllOutput") is False,
        "compiler license cannot automatically classify all output",
    )
    audit.check(
        output_policy.get("userInputCopyrightAutomaticallyTransferred") is False,
        "user input copyright cannot be automatically transferred",
    )
    audit.check(
        output_policy.get("copiedRuntimeOrBoilerplateMayCarrySourceLicense") is True,
        "copied runtime/boilerplate origin must remain visible",
    )
    audit.check(
        output_policy.get("generatedManifestMustClassifyOrigins") is True,
        "generated manifests must classify origins",
    )
    audit.check(
        output_policy.get("generatedManifestOrigins")
        == [
            "compiler-emitted-original-boilerplate",
            "third-party-or-upstream-derived",
            "toolchain-runtime-or-standard-library",
            "user-authored-or-user-configured",
        ],
        "generatedManifestOrigins must be the complete sorted closed set",
    )
    audit.check(
        output_policy.get("rawLicenseOverrideAllowed") is False,
        "raw license overrides must be disabled",
    )

    notice_policy = policy.get("noticePolicy", {})
    audit.keys(
        notice_policy,
        {
            "fullApplicableLicenseTextsRequiredInFinalArtifact",
            "copyrightNoticesPreserved",
            "componentVersionAndSourceRequired",
            "sbomRequired",
            "provenanceRequired",
            "licenseMetadataConflictFailsPublication",
            "missingLicenseEvidenceFailsPublication",
            "buildOnlyToolNoticeInRuntimeArtifact",
            "trademarkRightsGranted",
        },
        "policy.noticePolicy",
    )
    for field in (
        "fullApplicableLicenseTextsRequiredInFinalArtifact",
        "copyrightNoticesPreserved",
        "componentVersionAndSourceRequired",
        "sbomRequired",
        "provenanceRequired",
        "licenseMetadataConflictFailsPublication",
        "missingLicenseEvidenceFailsPublication",
    ):
        audit.check(notice_policy.get(field) is True, f"noticePolicy.{field} must be true")
    audit.check(
        notice_policy.get("trademarkRightsGranted") is False,
        "noticePolicy.trademarkRightsGranted must be false",
    )

    change_control = policy.get("changeControl", {})
    audit.keys(
        change_control,
        {
            "newDependencyRequiresInventoryEntry",
            "newCopiedSourceRequiresFileLevelProvenance",
            "newGeneratedRuntimeRequiresOutputBoundaryReview",
            "newPublicManifestRequiresPublicationGate",
            "silentLicenseConclusionUpgradeAllowed",
            "acceptanceRequiresAdrStatus",
            "acceptanceRequiresQualifiedReviewer",
            "acceptanceRequiresOwnerApproval",
        },
        "policy.changeControl",
    )
    for field in (
        "newDependencyRequiresInventoryEntry",
        "newCopiedSourceRequiresFileLevelProvenance",
        "newGeneratedRuntimeRequiresOutputBoundaryReview",
        "newPublicManifestRequiresPublicationGate",
        "acceptanceRequiresQualifiedReviewer",
        "acceptanceRequiresOwnerApproval",
    ):
        audit.check(change_control.get(field) is True, f"changeControl.{field} must be true")
    audit.check(
        change_control.get("silentLicenseConclusionUpgradeAllowed") is False,
        "silent license conclusion upgrades must be disabled",
    )
    audit.check(
        change_control.get("acceptanceRequiresAdrStatus") == "accepted",
        "acceptance must require accepted ADR status",
    )

    claims = policy.get("claims", {})
    audit.keys(
        claims,
        {
            "repositoryLicenseGrant",
            "candidatePolicy",
            "componentInventory",
            "generatedOutputGuidance",
            "qualifiedReview",
            "publicPackagePublication",
            "productionSupport",
        },
        "policy.claims",
    )
    expected_claims = {
        "repositoryLicenseGrant": "not-granted",
        "candidatePolicy": "proposed",
        "componentInventory": "inventoried",
        "generatedOutputGuidance": "provisional",
        "qualifiedReview": "not-tested",
        "publicPackagePublication": "unsupported",
        "productionSupport": "not-tested",
    }
    audit.check(claims == expected_claims, "policy.claims must remain exactly provisional")


def validate_components(audit: Audit, inventory: dict[str, Any]) -> dict[str, dict[str, Any]]:
    audit.keys(
        inventory,
        {"schemaVersion", "inventoryId", "status", "scope", "components", "unresolvedFindings"},
        "components inventory",
    )
    audit.check(inventory.get("schemaVersion") == 1, "components.schemaVersion must be 1")
    audit.check(
        inventory.get("inventoryId") == "wordpresshx-third-party-and-origin-audit-v1",
        "components.inventoryId must identify audit v1",
    )
    audit.check(
        inventory.get("status") == "provisional-qualified-review-required",
        "components.status must remain provisional-qualified-review-required",
    )

    components = inventory.get("components")
    audit.check(isinstance(components, list), "components.components must be an array")
    component_map: dict[str, dict[str, Any]] = {}
    if isinstance(components, list):
        for index, component in enumerate(components):
            context = f"components[{index}]"
            audit.keys(
                component,
                {
                    "id",
                    "name",
                    "version",
                    "role",
                    "repository",
                    "commit",
                    "tree",
                    "artifact",
                    "distribution",
                    "declaredLicense",
                    "licenseEvidence",
                    "licenseConclusion",
                    "noticeStatus",
                    "reviewStatus",
                    "notes",
                },
                context,
            )
            if not isinstance(component, dict):
                continue
            component_id = component.get("id")
            audit.check(isinstance(component_id, str), f"{context}.id must be a string")
            if isinstance(component_id, str):
                audit.check(component_id not in component_map, f"duplicate component id {component_id}")
                component_map[component_id] = component
            for field in ("commit", "tree"):
                value = component.get(field)
                audit.check(
                    value is None or (isinstance(value, str) and SHA1.fullmatch(value) is not None),
                    f"{context}.{field} must be null or a lowercase Git SHA-1",
                )
            artifact = component.get("artifact")
            if artifact is not None:
                audit.keys(artifact, {"name", "url", "sha256"}, f"{context}.artifact")
                if isinstance(artifact, dict):
                    audit.check(
                        isinstance(artifact.get("sha256"), str)
                        and SHA256.fullmatch(artifact["sha256"]) is not None,
                        f"{context}.artifact.sha256 must be lowercase SHA-256",
                    )
            distribution = component.get("distribution", {})
            audit.keys(
                distribution,
                {"sourceCopiedIntoRepository", "bundledInCurrentPublicArtifact", "plannedTreatment"},
                f"{context}.distribution",
            )
            if isinstance(distribution, dict):
                audit.check(
                    isinstance(distribution.get("sourceCopiedIntoRepository"), bool),
                    f"{context}.distribution.sourceCopiedIntoRepository must be boolean",
                )
                audit.check(
                    distribution.get("bundledInCurrentPublicArtifact") is False,
                    f"{context}: no component may claim a current public artifact",
                )
            evidence = component.get("licenseEvidence")
            audit.check(
                isinstance(evidence, list) and len(evidence) > 0,
                f"{context}.licenseEvidence must be a non-empty array",
            )
            if isinstance(evidence, list):
                for evidence_index, item in enumerate(evidence):
                    evidence_context = f"{context}.licenseEvidence[{evidence_index}]"
                    audit.keys(
                        item,
                        {"kind", "locator", "blob", "sha256", "observation"},
                        evidence_context,
                    )
                    if isinstance(item, dict):
                        blob = item.get("blob")
                        sha256 = item.get("sha256")
                        audit.check(
                            blob is None
                            or (isinstance(blob, str) and SHA1.fullmatch(blob) is not None),
                            f"{evidence_context}.blob must be null or a lowercase Git SHA-1",
                        )
                        audit.check(
                            sha256 is None
                            or (isinstance(sha256, str) and SHA256.fullmatch(sha256) is not None),
                            f"{evidence_context}.sha256 must be null or lowercase SHA-256",
                        )
            audit.check(
                component.get("reviewStatus") == "pending-qualified-review",
                f"{context}.reviewStatus must remain pending-qualified-review",
            )

        ids = [item.get("id") for item in components if isinstance(item, dict)]
        audit.check(ids == EXPECTED_COMPONENT_IDS, "component ids must be the complete sorted closed set")

    findings = inventory.get("unresolvedFindings")
    audit.check(isinstance(findings, list), "unresolvedFindings must be an array")
    if isinstance(findings, list):
        for index, finding in enumerate(findings):
            context = f"unresolvedFindings[{index}]"
            audit.keys(
                finding,
                {"id", "components", "blocksPublication", "resolutionRequired"},
                context,
            )
            if not isinstance(finding, dict):
                continue
            referenced = finding.get("components")
            audit.check(
                isinstance(referenced, list)
                and len(referenced) > 0
                and referenced == sorted(referenced),
                f"{context}.components must be a non-empty sorted array",
            )
            if isinstance(referenced, list):
                for component_id in referenced:
                    audit.check(
                        component_id in component_map,
                        f"{context} references unknown component {component_id}",
                    )
            audit.check(
                finding.get("blocksPublication") is True,
                f"{context}.blocksPublication must be true",
            )
        finding_ids = [item.get("id") for item in findings if isinstance(item, dict)]
        audit.check(
            finding_ids == EXPECTED_FINDING_IDS,
            "unresolved finding ids must be the complete sorted closed set",
        )

    if component_map:
        expected_conflicts = {
            "lix-15.12.4",
            "tink-anon-0.7.0",
            "tink-hxx-0.25.1",
        }
        actual_conflicts = {
            component_id
            for component_id, component in component_map.items()
            if component.get("licenseConclusion")
            == "conflict-pending-upstream-and-qualified-review"
        }
        audit.check(
            actual_conflicts == expected_conflicts,
            "license metadata/text conflicts must remain explicit and complete",
        )
        original = component_map.get("repository-original-work", {})
        audit.check(
            original.get("declaredLicense") == "LicenseRef-No-License-Grant"
            and original.get("licenseConclusion") == "no-license-grant-candidate-only",
            "repository-original-work must retain the no-license-grant conclusion",
        )
    return component_map


def check_equal(audit: Audit, actual: Any, expected: Any, context: str) -> None:
    audit.check(actual == expected, f"{context}: expected {expected!r}, found {actual!r}")


def validate_lock_bindings(audit: Audit, components: dict[str, dict[str, Any]]) -> None:
    upstream = audit.read_json(audit.root / "manifests/upstream.lock.json", "upstream lock")
    hxx = audit.read_json(audit.root / "packages/hxx/dependency-lock.json", "HXX dependency lock")
    provenance = audit.read_json(
        audit.root / "compiler/reflaxe.php/provenance.json", "PHP compiler provenance"
    )
    haxelib = audit.read_json(
        audit.root / "compiler/reflaxe.php/haxelib.json", "PHP compiler haxelib manifest"
    )
    images = audit.read_json(audit.root / "docker/images.lock.json", "Docker image lock")

    entries = upstream.get("entries", {}) if isinstance(upstream, dict) else {}
    genes = entries.get("genes-ts", {}) if isinstance(entries, dict) else {}
    genes_component = components.get("genes-ts-1.33.0", {})
    for field in ("version", "commit", "tree"):
        check_equal(audit, genes_component.get(field), genes.get(field), f"Genes {field} binding")
    genes_artifact = genes.get("releaseArtifact", {})
    component_artifact = genes_component.get("artifact", {})
    for field in ("url", "sha256"):
        check_equal(
            audit,
            component_artifact.get(field),
            genes_artifact.get(field),
            f"Genes artifact {field} binding",
        )

    wp = entries.get("wp70-release", {}).get("wordpressSource", {})
    wp_component = components.get("wordpress-7.0", {})
    for field in ("commit", "tree"):
        check_equal(audit, wp_component.get(field), wp.get(field), f"WordPress {field} binding")

    embedded = entries.get("wp70-release", {}).get("embeddedGutenberg", {})
    embedded_component = components.get("gutenberg-wp70-embedded", {})
    for field in ("commit", "tree"):
        check_equal(
            audit,
            embedded_component.get(field),
            embedded.get(field),
            f"embedded Gutenberg {field} binding",
        )

    forward = entries.get("gutenberg-forward-23.4", {})
    forward_source = forward.get("gutenbergSource", {})
    forward_component = components.get("gutenberg-23.4.0", {})
    for field in ("commit", "tree"):
        check_equal(
            audit,
            forward_component.get(field),
            forward_source.get(field),
            f"forward Gutenberg {field} binding",
        )
    for field in ("url", "sha256"):
        check_equal(
            audit,
            forward_component.get("artifact", {}).get(field),
            forward.get("releaseArtifact", {}).get(field),
            f"forward Gutenberg artifact {field} binding",
        )

    parser = hxx.get("parser", {})
    parser_component = components.get("tink-hxx-0.25.1", {})
    for field in ("version", "commit", "tree"):
        check_equal(audit, parser_component.get(field), parser.get(field), f"tink_hxx {field} binding")
    for field in ("url", "sha256"):
        check_equal(
            audit,
            parser_component.get("artifact", {}).get(field),
            parser.get("artifact", {}).get(field),
            f"tink_hxx artifact {field} binding",
        )

    dependency_ids = {
        "html-entities": "html-entities-1.0.0",
        "tink_anon": "tink-anon-0.7.0",
        "tink_core": "tink-core-2.1.1",
        "tink_macro": "tink-macro-0.23.0",
        "tink_parse": "tink-parse-0.4.1",
    }
    dependencies = hxx.get("dependencies", [])
    audit.check(
        isinstance(dependencies, list)
        and {item.get("name") for item in dependencies if isinstance(item, dict)}
        == set(dependency_ids),
        "HXX dependency closure must remain the exact five-component set",
    )
    if isinstance(dependencies, list):
        for dependency in dependencies:
            if not isinstance(dependency, dict) or dependency.get("name") not in dependency_ids:
                continue
            component = components.get(dependency_ids[dependency["name"]], {})
            check_equal(
                audit,
                component.get("version"),
                dependency.get("version"),
                f"{dependency['name']} version binding",
            )
            for field in ("commit", "tree"):
                if field in dependency:
                    check_equal(
                        audit,
                        component.get(field),
                        dependency.get(field),
                        f"{dependency['name']} {field} binding",
                    )
            if "sha256" in dependency:
                for component_field, dependency_field in (("url", "url"), ("sha256", "sha256")):
                    check_equal(
                        audit,
                        component.get("artifact", {}).get(component_field),
                        dependency.get(dependency_field),
                        f"{dependency['name']} artifact {component_field} binding",
                    )

    lix_component = components.get("lix-15.12.4", {})
    lix = hxx.get("toolchain", {}).get("lix", {})
    check_equal(audit, lix_component.get("version"), lix.get("version"), "Lix version binding")
    for field in ("url", "sha256"):
        check_equal(
            audit,
            lix_component.get("artifact", {}).get(field),
            lix.get("artifact", {}).get(field),
            f"Lix artifact {field} binding",
        )

    compiler_component = components.get("reflaxe-php-port-origin", {})
    origin = provenance.get("origin", {})
    for field in ("repository", "commit", "tree"):
        check_equal(
            audit,
            compiler_component.get(field),
            origin.get(field),
            f"PHP compiler origin {field} binding",
        )
    check_equal(
        audit,
        compiler_component.get("declaredLicense"),
        origin.get("license"),
        "PHP compiler origin license binding",
    )
    audit.check(haxelib.get("version") == "0.0.0", "reflaxe.php must remain internal version 0.0.0")
    audit.check(haxelib.get("license") == "GPL", "reflaxe.php haxelib license must remain GPL")
    audit.check(
        provenance.get("destination", {}).get("releaseEligible") is False,
        "reflaxe.php publication must remain ineligible",
    )

    image_map = images.get("images", {})
    audit.check(
        isinstance(image_map, dict)
        and sorted(image_map)
        == [
            "mariadb",
            "mysql",
            "node",
            "php74Floor",
            "php84Cli",
            "playwright",
            "wordpress70Php84",
        ],
        "Docker image inventory must remain the exact seven digest-pinned test inputs",
    )
    if isinstance(image_map, dict):
        for image_id, image in image_map.items():
            reference = image.get("reference") if isinstance(image, dict) else None
            audit.check(
                isinstance(reference, str) and "@sha256:" in reference,
                f"Docker image {image_id} must use a digest reference",
            )


def validate_repository_state(audit: Audit, components: dict[str, dict[str, Any]]) -> None:
    for name in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING", "COPYING.md", "COPYING.txt"):
        audit.check(not (audit.root / name).exists(), f"root {name} must be absent while review is pending")

    try:
        tracked_result = subprocess.run(
            ["git", "ls-files", "*haxelib.json", "package.json"],
            cwd=audit.root,
            check=True,
            text=True,
            capture_output=True,
        )
        tracked_manifests = [line for line in tracked_result.stdout.splitlines() if line]
        audit.check(
            tracked_manifests == ["compiler/reflaxe.php/haxelib.json"],
            "the only tracked publishable package manifest must be internal compiler/reflaxe.php/haxelib.json",
        )
    except (OSError, subprocess.CalledProcessError) as error:
        audit.errors.append(f"cannot enumerate tracked package manifests: {error}")

    workflow = audit.read_text(".github/workflows/repository.yml")
    checkout_pins = re.findall(r"uses:\s+actions/checkout@([^\s]+)", workflow)
    audit.check(
        len(checkout_pins) > 0
        and set(checkout_pins) == {components.get("actions-checkout-4.2.2", {}).get("commit")},
        "all checkout actions must use the inventoried exact commit",
    )
    setup_pins = re.findall(r"uses:\s+krdlab/setup-haxe@([^\s]+)", workflow)
    audit.check(
        setup_pins == [components.get("krdlab-setup-haxe-2.1.0", {}).get("commit")],
        "setup-haxe must use the inventoried exact commit once",
    )
    for fragment in (
        "haxe-version: 4.3.7",
        "haxelib install formatter 1.18.0 --quiet",
        "npm install --global lix@15.12.4",
    ):
        audit.check(fragment in workflow, f"repository workflow must retain exact tool pin: {fragment}")

    gitleaks = audit.read_text("scripts/ci/install-gitleaks.sh")
    audit.check(
        'readonly gitleaks_version="8.30.0"' in gitleaks
        and 'readonly gitleaks_sha256="79a3ab579b53f71efd634f3aaf7e04a0fa0cf206b7ed434638d1547a2470a66e"'
        in gitleaks,
        "Gitleaks version and artifact digest must match the inventory",
    )
    formatter = audit.read_text("scripts/lint/hx-format-guard.sh")
    audit.check(
        'readonly formatter_version="1.18.0"' in formatter,
        "Formatter version must match the inventory",
    )
    for hook_path in (".beads/hooks/pre-commit", ".beads/hooks/pre-push"):
        hook = audit.read_text(hook_path)
        audit.check(
            "# --- BEGIN BEADS INTEGRATION v1.0.4 ---" in hook
            and "# --- END BEADS INTEGRATION v1.0.4 ---" in hook,
            f"{hook_path} must retain the tracked Beads 1.0.4 managed section",
        )

    publish_patterns = {
        "Haxelib publication": re.compile(r"\bhaxelib\s+submit\b"),
        "npm publication": re.compile(r"\bnpm\s+publish\b"),
        "GitHub release creation": re.compile(r"\bgh\s+release\s+create\b"),
        "container publication": re.compile(r"\bdocker\s+push\b"),
    }
    scan_roots = [audit.root / ".github" / "workflows", audit.root / "scripts"]
    for scan_root in scan_roots:
        for path in sorted(scan_root.rglob("*")):
            if not path.is_file() or "scripts/licenses" in path.as_posix():
                continue
            if path.suffix not in {".yml", ".yaml", ".sh", ".py"}:
                continue
            try:
                source = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for label, pattern in publish_patterns.items():
                audit.check(
                    pattern.search(source) is None,
                    f"{label} command forbidden while publication is blocked: {path.relative_to(audit.root)}",
                )

    required_fragments = {
        "LICENSES/README.md": [
            "no repository-wide license grant",
            "publication assertion intentionally exits with status 3",
        ],
        "LICENSES/GENERATED_OUTPUT.md": [
            "User-authored or user-configured content",
            "Compiler-emitted original boilerplate",
            "Toolchain runtime or standard-library portions",
            "Third-party or upstream-derived portions",
            "return <main>...</main>",
        ],
        "LICENSES/THIRD_PARTY_NOTICES.md": [
            "**not** the final notice file",
            "Known blocking findings",
        ],
        "LICENSES/QUALIFIED_REVIEW.md": [
            "Review status: **pending**",
            "Qualified reviewer: **unassigned**",
            "Codex is not recorded as the qualified licensing reviewer",
        ],
        "docs/adr/020-licensing-and-generated-output.md": [
            "Status: proposed",
            "No root `LICENSE` is added",
            "wordpresshx-sdk-002",
        ],
    }
    for relative, fragments in required_fragments.items():
        text = audit.read_text(relative)
        for fragment in fragments:
            audit.check(fragment in text, f"{relative} must contain provisional fragment: {fragment}")


def validate_receipt(audit: Audit) -> None:
    receipt = audit.read_json(
        audit.root / "manifests/evidence/adr-020-license-audit-preparation.json",
        "ADR-020 preparation receipt",
    )
    audit.keys(
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "bead",
            "decision",
            "status",
            "subject",
            "audit",
            "validation",
            "publicationGate",
            "review",
            "implementation",
            "hostedWorkflow",
            "claims",
            "limitations",
        },
        "ADR-020 preparation receipt",
    )
    audit.check(receipt.get("schemaVersion") == 1, "ADR-020 receipt schemaVersion must be 1")
    audit.check(
        receipt.get("receiptId") == "ADR-020-LICENSE-AUDIT-PREPARATION",
        "ADR-020 receipt id must identify the preparation audit",
    )
    audit.check(receipt.get("bead") == "wordpresshx-adr-020", "ADR-020 receipt bead mismatch")
    audit.check(receipt.get("decision") == "ADR-020", "ADR-020 receipt decision mismatch")
    audit.check(
        receipt.get("status") == "prepared-review-pending",
        "ADR-020 receipt must remain prepared-review-pending",
    )

    subjects = receipt.get("subject", {})
    expected_subjects = [
        "adr",
        "components",
        "generatedOutput",
        "policy",
        "publicationGolden",
        "qualifiedReview",
        "thirdPartyNotices",
        "validator",
        "validatorTests",
    ]
    audit.check(
        isinstance(subjects, dict) and list(subjects) == expected_subjects,
        "ADR-020 receipt subjects must be the complete sorted closed set",
    )
    if isinstance(subjects, dict):
        for subject_id, subject in subjects.items():
            audit.keys(subject, {"path", "sha256"}, f"receipt.subject.{subject_id}")
            if not isinstance(subject, dict):
                continue
            path = subject.get("path")
            digest = subject.get("sha256")
            audit.check(
                isinstance(path, str) and len(path) > 0,
                f"receipt.subject.{subject_id}.path must be non-empty",
            )
            audit.check(
                isinstance(digest, str) and SHA256.fullmatch(digest) is not None,
                f"receipt.subject.{subject_id}.sha256 must be lowercase SHA-256",
            )
            if isinstance(path, str) and isinstance(digest, str):
                subject_path = audit.root / path
                try:
                    actual = hashlib.sha256(subject_path.read_bytes()).hexdigest()
                except OSError as error:
                    audit.errors.append(f"receipt subject {path} cannot be read: {error}")
                else:
                    audit.check(actual == digest, f"receipt subject digest mismatch: {path}")

    receipt_audit = receipt.get("audit", {})
    audit.keys(
        receipt_audit,
        {"componentCount", "unresolvedFindingCount", "conflictCount", "rootLicensePresent"},
        "receipt.audit",
    )
    audit.check(receipt_audit.get("componentCount") == 22, "receipt component count must be 22")
    audit.check(
        receipt_audit.get("unresolvedFindingCount") == 8,
        "receipt unresolved finding count must be 8",
    )
    audit.check(receipt_audit.get("conflictCount") == 3, "receipt conflict count must be 3")
    audit.check(receipt_audit.get("rootLicensePresent") is False, "receipt must record no root license")

    validation = receipt.get("validation", {})
    audit.keys(
        validation,
        {"command", "outcome", "positiveScenarioCount", "blockedGateCount", "negativeMutationCount"},
        "receipt.validation",
    )
    audit.check(
        validation
        == {
            "command": "python3 scripts/licenses/test-license-policy.py",
            "outcome": "passed",
            "positiveScenarioCount": 1,
            "blockedGateCount": 1,
            "negativeMutationCount": 8,
        },
        "receipt validation summary mismatch",
    )

    gate = receipt.get("publicationGate", {})
    audit.keys(
        gate,
        {"command", "expectedExitCode", "expectedMessage", "allowed"},
        "receipt.publicationGate",
    )
    audit.check(
        gate
        == {
            "command": "python3 scripts/licenses/check-license-policy.py --publication-gate",
            "expectedExitCode": 3,
            "expectedMessage": PUBLICATION_BLOCKED_MESSAGE,
            "allowed": False,
        },
        "receipt publication gate summary mismatch",
    )

    review = receipt.get("review", {})
    audit.keys(
        review,
        {"qualifiedReview", "reviewer", "ownerApproval", "adrAccepted", "sdk002Complete"},
        "receipt.review",
    )
    audit.check(
        review
        == {
            "qualifiedReview": "pending",
            "reviewer": None,
            "ownerApproval": None,
            "adrAccepted": False,
            "sdk002Complete": False,
        },
        "receipt review state must remain wholly pending",
    )

    implementation = receipt.get("implementation", {})
    audit.keys(implementation, {"baseCommit", "commit"}, "receipt.implementation")
    base_commit = implementation.get("baseCommit")
    implementation_commit = implementation.get("commit")
    audit.check(
        isinstance(base_commit, str) and SHA1.fullmatch(base_commit) is not None,
        "receipt implementation baseCommit must be an exact Git SHA-1",
    )
    audit.check(
        implementation_commit is None
        or (isinstance(implementation_commit, str) and SHA1.fullmatch(implementation_commit) is not None),
        "receipt implementation commit must be null or an exact Git SHA-1",
    )

    hosted = receipt.get("hostedWorkflow", {})
    audit.keys(
        hosted,
        {"workflow", "job", "required", "runId", "jobId", "commit", "status", "fullMatrixStatus"},
        "receipt.hostedWorkflow",
    )
    audit.check(hosted.get("workflow") == "repository.yml", "hosted workflow must be repository.yml")
    audit.check(hosted.get("job") == "license-policy", "hosted workflow job must be license-policy")
    audit.check(hosted.get("required") is True, "hosted workflow evidence must be required")
    hosted_status = hosted.get("status")
    audit.check(hosted_status in {"pending", "passed"}, "hosted workflow status must be pending or passed")
    if hosted_status == "pending":
        for field in ("runId", "jobId", "commit"):
            audit.check(hosted.get(field) is None, f"pending hosted workflow {field} must be null")
        audit.check(
            hosted.get("fullMatrixStatus") == "pending",
            "pending hosted workflow fullMatrixStatus must be pending",
        )
        audit.check(
            implementation_commit is None,
            "implementation commit must remain null while hosted evidence is pending",
        )
    elif hosted_status == "passed":
        audit.check(
            isinstance(hosted.get("runId"), int) and hosted["runId"] > 0,
            "passed hosted workflow runId must be positive",
        )
        audit.check(
            isinstance(hosted.get("jobId"), int) and hosted["jobId"] > 0,
            "passed hosted workflow jobId must be positive",
        )
        audit.check(
            isinstance(hosted.get("commit"), str) and SHA1.fullmatch(hosted["commit"]) is not None,
            "passed hosted workflow commit must be an exact Git SHA-1",
        )
        audit.check(
            hosted.get("fullMatrixStatus") == "passed",
            "passed hosted workflow fullMatrixStatus must be passed",
        )
        audit.check(
            implementation_commit == hosted.get("commit"),
            "implementation commit must equal the hosted workflow commit",
        )

    claims = receipt.get("claims", {})
    audit.keys(
        claims,
        {
            "componentInventory",
            "generatedOutputGuidance",
            "qualifiedReview",
            "repositoryLicenseGrant",
            "publicPublication",
            "productionSupport",
        },
        "receipt.claims",
    )
    audit.check(
        claims
        == {
            "componentInventory": "inventoried",
            "generatedOutputGuidance": "provisional",
            "qualifiedReview": "not-tested",
            "repositoryLicenseGrant": "not-granted",
            "publicPublication": "unsupported",
            "productionSupport": "not-tested",
        },
        "receipt claims must remain exactly bounded",
    )
    limitations = receipt.get("limitations")
    audit.check(
        isinstance(limitations, list)
        and limitations == sorted(limitations)
        and len(limitations) == 6,
        "receipt limitations must contain six sorted blockers",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    default_root = Path(__file__).resolve().parents[2]
    parser.add_argument("--root", type=Path, default=default_root)
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--components", type=Path)
    parser.add_argument("--publication-gate", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    policy_path = args.policy.resolve() if args.policy else root / "LICENSES/policy.json"
    components_path = (
        args.components.resolve() if args.components else root / "LICENSES/components.json"
    )
    audit = Audit(root)
    policy = audit.read_json(policy_path, "license policy")
    inventory = audit.read_json(components_path, "component inventory")
    if policy:
        validate_policy(audit, policy)
    if inventory:
        component_map = validate_components(audit, inventory)
    else:
        component_map = {}
    if component_map:
        validate_lock_bindings(audit, component_map)
        validate_repository_state(audit, component_map)
        validate_receipt(audit)

    if audit.errors:
        for error in audit.errors:
            print(f"license audit error: {error}", file=sys.stderr)
        return 1

    if args.publication_gate:
        print(PUBLICATION_BLOCKED_MESSAGE)
        return 3

    print(
        "license policy audit passed: provisional evidence is complete and "
        "publication remains blocked"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
