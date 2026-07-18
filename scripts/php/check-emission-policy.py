#!/usr/bin/env python3
"""Validate ADR-005's fail-closed public/private PHP emission boundary."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


PUBLIC_INVENTORY = {
    "plugin-and-mu-plugin-roots",
    "plugin-headers-guards-autoload-and-boot",
    "lifecycle-registration-and-callbacks",
    "hook-registration-and-callbacks",
    "rest-registration-permission-validation-and-endpoints",
    "dynamic-block-render-callbacks",
    "theme-admin-and-mixed-php-html-templates",
    "public-facade-functions-classes-and-includable-files",
    "wordpress-discovered-names-globals-and-side-effects",
    "public-to-private-adapters",
    "host-visible-stack-entrypoints",
}

PUBLIC_SHAPES = {
    "php74-compatible-syntax",
    "native-scalars-nullables-objects-arrays-iterables-callables",
    "native-indexed-and-associative-arrays",
    "native-callable-arrays-and-stable-callback-identity",
    "native-functions-methods-closures-namespaces-and-types",
    "native-parameter-and-return-references",
    "native-provider-objects-including-wp-error",
    "structured-conditional-declarations",
    "declared-top-level-statements-and-deterministic-includes",
    "readable-names-and-source-correlated-stack-entries",
    "direct-context-safe-mixed-php-html",
}

FORBIDDEN_PUBLIC_SHAPES = {
    "stock-haxe-boot-types",
    "haxe-collection-wrappers",
    "haxe-callable-wrappers",
    "haxe-reflection-registries",
    "anonymous-runtime-carriers",
    "mangled-private-implementation-names",
}

PRIVATE_ADMISSION = {
    "private-dependency-closed-closure",
    "no-direct-wordpress-or-non-haxe-php-entry",
    "all-entry-edges-use-public-native-adapter",
    "native-values-converted-immediately-at-adapter",
    "exact-runtime-file-symbol-helper-and-size-inventory",
    "php-matrix-source-correlation-conflict-and-determinism-pass",
    "package-local-namespaced-runtime",
}

PRIVATE_FORBIDDEN = {
    "plugin-or-theme-root",
    "template-file",
    "public-facade",
    "hook-or-lifecycle-callback",
    "rest-or-block-callback",
    "wordpress-discovered-name",
    "consumer-extension-point",
    "opaque-carrier-forwarding",
}

PRIVATE_AUDIT = {
    "exact-stock-haxe-compiler-and-runtime",
    "adapter-and-private-root-plan-ids",
    "private-files-symbols-and-content-hashes",
    "retained-runtime-helpers-and-dce-reasons",
    "all-boundary-conversions",
    "compressed-uncompressed-size-and-bootstrap-timing",
    "two-plugin-namespace-and-runtime-conflicts",
    "source-correlation-and-gate-receipts",
}

G1_EVIDENCE = {
    "php74-lint-and-php84-execution",
    "wpcs-and-selected-static-analysis",
    "native-array-callable-reference-wp-error-semantics",
    "wordpress70-install-activation-hooks-and-render",
    "public-reflection-snapshot",
    "ordinary-non-haxe-php-caller",
    "readable-source-correlated-stack-trace",
    "deterministic-private-runtime-size-and-bootstrap-audit",
    "two-plugin-runtime-conflict-fixture",
    "independent-wordpress-php-readability-review",
}

MIGRATION_OUTCOMES = {
    "supported-private-profile-with-budgets",
    "explicit-migration-only-profile",
    "removed-after-custom-lowering-migration",
}

SYMBOL_MIGRATION_TRIGGERS = {
    "becomes-host-visible",
    "needs-more-than-one-representation-preserving-adapter",
    "leaks-haxe-runtime-shape",
    "prevents-source-correlation",
    "fails-syntax-security-or-static-analysis",
    "creates-package-or-cross-plugin-conflict",
    "fails-measured-size-bootstrap-or-readability-budget",
}

LANE_REMOVAL_TRIGGERS = {
    "fixed-runtime-cost-dominates-representative-package",
    "cross-plugin-isolation-fails",
    "upstream-runtime-misses-supported-php-matrix",
    "security-maintenance-cannot-be-owned",
    "custom-compiler-covers-closure-with-simpler-packaging",
}

STOP_CONDITIONS = {
    "pervasive-raw-public-templates",
    "opaque-haxe-runtime-wrapper-leak",
    "php74-syntax-floor-failure",
    "non-native-public-abi-or-reflection",
    "unreadable-or-uncorrelated-public-stack-frames",
}

GENERIC_COUPLING = re.compile(
    r"wordpress|gutenberg|wphx|@:wp\.|compiler/wordpress|packages/",
    re.IGNORECASE,
)


class Audit:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[str] = []

    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def exact_keys(self, value: Any, expected: set[str], label: str) -> None:
        if not isinstance(value, dict):
            self.errors.append(f"{label} must be an object")
            return
        actual = set(value)
        if actual != expected:
            self.errors.append(
                f"{label} keys differ: expected {sorted(expected)}, "
                f"got {sorted(actual)}"
            )

    def exact_string_set(
        self, value: Any, expected: set[str], message: str
    ) -> None:
        if not isinstance(value, list) or not all(
            isinstance(item, str) for item in value
        ):
            self.errors.append(f"{message}: expected a string array")
            return
        if len(value) != len(set(value)) or set(value) != expected:
            self.errors.append(message)

    def read_json(self, relative: str) -> dict[str, Any]:
        path = self.root / relative
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            self.errors.append(f"cannot read {relative}: {error}")
            return {}
        if not isinstance(value, dict):
            self.errors.append(f"{relative} must contain a JSON object")
            return {}
        return value

    def read_text(self, relative: str) -> str:
        try:
            return (self.root / relative).read_text(encoding="utf-8")
        except OSError as error:
            self.errors.append(f"cannot read {relative}: {error}")
            return ""


def validate_manifest(audit: Audit, policy: dict[str, Any]) -> None:
    audit.exact_keys(
        policy,
        {
            "schemaVersion",
            "decision",
            "status",
            "claim",
            "profile",
            "classification",
            "publicNativeLane",
            "privateStockHaxeLane",
            "adapterContract",
            "serverHxx",
            "requiredG1Evidence",
            "migrationPolicy",
            "stopConditions",
            "releaseBoundary",
            "implementationOwners",
        },
        "PHP emission policy",
    )
    audit.check(policy.get("schemaVersion") == 1, "schemaVersion must be 1")
    audit.check(policy.get("decision") == "ADR-005", "decision must be ADR-005")
    audit.check(
        policy.get("status") == "accepted-architecture",
        "policy status must be accepted-architecture",
    )
    audit.check(
        policy.get("claim") == "not-tested",
        "ADR acceptance must not claim implementation evidence",
    )
    audit.check(
        policy.get("profile") == "wp70-release",
        "ADR-005 must remain scoped to wp70-release",
    )

    classification = policy.get("classification", {})
    audit.exact_keys(
        classification,
        {
            "authority",
            "haxeVisibilityIsAuthority",
            "unknownDisposition",
            "classes",
            "breakingChangeRule",
        },
        "classification policy",
    )
    audit.check(
        classification.get("authority") == "semantic-file-symbol-edge-plan",
        "boundary authority must be the semantic file/symbol/edge plan",
    )
    audit.check(
        classification.get("haxeVisibilityIsAuthority") is False,
        "Haxe visibility cannot classify PHP boundaries",
    )
    audit.check(
        classification.get("unknownDisposition") == "reject",
        "unknown boundary classification must reject",
    )
    audit.exact_string_set(
        classification.get("classes"),
        {"public-native", "private-stock-haxe"},
        "boundary classification vocabulary differs",
    )
    audit.check(
        classification.get("breakingChangeRule")
        == "released-public-native-to-private-is-breaking",
        "public-to-private migration must remain breaking",
    )

    public = policy.get("publicNativeLane", {})
    audit.exact_keys(
        public,
        {
            "owner",
            "emitter",
            "stockHaxePhpAllowed",
            "routineRawPhpAllowed",
            "haxeRuntimeShapeAllowedAtBoundary",
            "inventory",
            "requiredShapes",
            "forbiddenBoundaryShapes",
        },
        "public native lane",
    )
    audit.check(
        public.get("owner") == "compiler/wordpress",
        "WordPress profile must own public native emission",
    )
    audit.check(
        public.get("emitter") == "structured-php-ir-and-wordpress-profile",
        "public output must use structured PHP IR and the WordPress profile",
    )
    audit.check(
        public.get("stockHaxePhpAllowed") is False,
        "public native lane cannot use stock Haxe PHP",
    )
    audit.check(
        public.get("routineRawPhpAllowed") is False,
        "routine raw PHP cannot become public scaffolding",
    )
    audit.check(
        public.get("haxeRuntimeShapeAllowedAtBoundary") is False,
        "Haxe runtime shapes cannot cross the public boundary",
    )
    audit.exact_string_set(
        public.get("inventory"),
        PUBLIC_INVENTORY,
        "public boundary inventory differs",
    )
    audit.exact_string_set(
        public.get("requiredShapes"),
        PUBLIC_SHAPES,
        "required native PHP shape inventory differs",
    )
    audit.exact_string_set(
        public.get("forbiddenBoundaryShapes"),
        FORBIDDEN_PUBLIC_SHAPES,
        "forbidden public boundary shape inventory differs",
    )

    private = policy.get("privateStockHaxeLane", {})
    audit.exact_keys(
        private,
        {
            "owner",
            "disposition",
            "guaranteedAfter1_0",
            "packageScope",
            "sharedSiteRuntimeAllowed",
            "admission",
            "forbiddenUses",
            "auditInventory",
            "missingInventoryDisposition",
        },
        "private stock-Haxe lane",
    )
    audit.check(
        private.get("owner")
        == "stock-haxe-php-through-sdk-owned-native-adapters",
        "private stock-Haxe lane must be adapter-owned",
    )
    audit.check(
        private.get("disposition") == "provisional-0.x-migration-lane",
        "private lane disposition must remain provisional",
    )
    audit.check(
        private.get("guaranteedAfter1_0") is False,
        "private stock-Haxe lane cannot be guaranteed after 1.0 yet",
    )
    audit.check(
        private.get("packageScope")
        == "one-namespaced-dependency-closed-plugin-or-theme",
        "private lane must remain package-local and dependency-closed",
    )
    audit.check(
        private.get("sharedSiteRuntimeAllowed") is False,
        "shared site-wide Haxe runtime is not allowed",
    )
    audit.exact_string_set(
        private.get("admission"),
        PRIVATE_ADMISSION,
        "private admission inventory differs",
    )
    audit.exact_string_set(
        private.get("forbiddenUses"),
        PRIVATE_FORBIDDEN,
        "private forbidden-use inventory differs",
    )
    audit.exact_string_set(
        private.get("auditInventory"),
        PRIVATE_AUDIT,
        "private audit inventory differs",
    )
    audit.check(
        private.get("missingInventoryDisposition") == "reject-build",
        "missing private-lane inventory must reject the build",
    )

    adapter = policy.get("adapterContract", {})
    audit.exact_keys(
        adapter,
        {
            "adapterLane",
            "allPrivateEntriesRequireAdapter",
            "immediateNativeConversionRequired",
            "opaqueForwardingAllowed",
            "publicAbiStableAcrossPrivateMigration",
            "nonHaxeCallerIsRequiredAuthority",
        },
        "adapter contract",
    )
    audit.check(
        adapter.get("adapterLane") == "public-native",
        "every private adapter must itself be public-native",
    )
    audit.check(
        adapter.get("allPrivateEntriesRequireAdapter") is True,
        "all private entries must require an adapter",
    )
    audit.check(
        adapter.get("immediateNativeConversionRequired") is True,
        "adapter must convert native values immediately",
    )
    audit.check(
        adapter.get("opaqueForwardingAllowed") is False,
        "opaque adapter forwarding is forbidden",
    )
    audit.check(
        adapter.get("publicAbiStableAcrossPrivateMigration") is True,
        "private migration must preserve the public ABI",
    )
    audit.check(
        adapter.get("nonHaxeCallerIsRequiredAuthority") is True,
        "ordinary non-Haxe PHP caller evidence is mandatory",
    )

    hxx = policy.get("serverHxx", {})
    audit.exact_keys(
        hxx,
        {
            "routineAuthoring",
            "lowering",
            "runtimeParserOrVdomShipped",
            "stockHaxeTemplateRuntimeAllowed",
            "directMixedPhpHtmlOutputRequired",
        },
        "server HXX contract",
    )
    audit.check(
        hxx.get("routineAuthoring") == "return-inline-markup",
        "server HXX routine authoring must be direct-return inline markup",
    )
    audit.check(
        hxx.get("lowering")
        == "compile-time-generic-markup-ir-then-wordpress-public-native-lane",
        "server HXX must lower through generic markup IR and the public lane",
    )
    audit.check(
        hxx.get("runtimeParserOrVdomShipped") is False,
        "server HXX cannot ship a parser or VDOM runtime",
    )
    audit.check(
        hxx.get("stockHaxeTemplateRuntimeAllowed") is False,
        "server HXX cannot use a stock-Haxe template runtime",
    )
    audit.check(
        hxx.get("directMixedPhpHtmlOutputRequired") is True,
        "server HXX must produce direct mixed PHP/HTML",
    )

    evidence = policy.get("requiredG1Evidence")
    if not isinstance(evidence, list):
        audit.errors.append("requiredG1Evidence must be an array")
    else:
        ids: list[str] = []
        for index, item in enumerate(evidence):
            audit.exact_keys(item, {"id", "status"}, f"G1 evidence {index}")
            if isinstance(item, dict):
                evidence_id = item.get("id")
                if isinstance(evidence_id, str):
                    ids.append(evidence_id)
                audit.check(
                    item.get("status") == "not-tested",
                    "ADR acceptance cannot pre-advance G1 evidence",
                )
        audit.check(
            len(ids) == len(set(ids)) and set(ids) == G1_EVIDENCE,
            "required G1 evidence inventory differs",
        )

    migration = policy.get("migrationPolicy", {})
    audit.exact_keys(
        migration,
        {
            "decisionDeadline",
            "allowedOutcomes",
            "symbolMigrationTriggers",
            "laneRemovalReviewTriggers",
            "numericBudgetsApproved",
            "budgetOwner",
        },
        "migration policy",
    )
    audit.check(
        migration.get("decisionDeadline") == "before-g8-api-freeze",
        "private-lane retention decision is required before G8 API freeze",
    )
    audit.exact_string_set(
        migration.get("allowedOutcomes"),
        MIGRATION_OUTCOMES,
        "private-lane retention outcome inventory differs",
    )
    audit.exact_string_set(
        migration.get("symbolMigrationTriggers"),
        SYMBOL_MIGRATION_TRIGGERS,
        "symbol migration trigger inventory differs",
    )
    audit.exact_string_set(
        migration.get("laneRemovalReviewTriggers"),
        LANE_REMOVAL_TRIGGERS,
        "lane removal trigger inventory differs",
    )
    audit.check(
        migration.get("numericBudgetsApproved") is False,
        "numeric budgets require G1 measurement and ADR-018/G8 approval",
    )
    audit.check(
        migration.get("budgetOwner") == "ADR-018-and-G8-after-G1-measurement",
        "private-lane budget authority changed",
    )

    audit.exact_string_set(
        policy.get("stopConditions"),
        STOP_CONDITIONS,
        "PHP lane stop-condition inventory differs",
    )

    release = policy.get("releaseBoundary", {})
    audit.exact_keys(
        release,
        {"publicationAuthorized", "licensingBlockedBy", "productionSupport"},
        "release boundary",
    )
    audit.check(
        release.get("publicationAuthorized") is False,
        "publication must remain blocked",
    )
    audit.exact_string_set(
        release.get("licensingBlockedBy"),
        {"wordpresshx-adr-020", "wordpresshx-sdk-002"},
        "licensing blocker inventory differs",
    )
    audit.check(
        release.get("productionSupport") == "not-tested",
        "production support must remain not-tested",
    )

    owners = policy.get("implementationOwners", {})
    audit.exact_keys(
        owners,
        {
            "wordpressProfile",
            "semanticPlan",
            "hookContract",
            "sourceCorrelation",
            "serverHxx",
            "runtimePackaging",
            "feasibilityGate",
            "retentionDecision",
        },
        "implementation owners",
    )
    audit.check(
        owners
        == {
            "wordpressProfile": "wordpresshx-sdk-022",
            "semanticPlan": "wordpresshx-adr-006",
            "hookContract": "wordpresshx-adr-010",
            "sourceCorrelation": "wordpresshx-sdk-025",
            "serverHxx": "wordpresshx-sdk-081",
            "runtimePackaging": "wordpresshx-adr-018",
            "feasibilityGate": "wordpresshx-g1",
            "retentionDecision": "wordpresshx-g8",
        },
        "implementation owner mapping differs",
    )


def validate_adr(audit: Audit, adr: str) -> None:
    required = {
        "# ADR-005: Public versus private PHP emission": "ADR-005 title missing",
        "- Status: accepted": "ADR-005 must be accepted",
        "Classification is semantic and fail-closed": (
            "ADR-005 must document fail-closed semantic classification"
        ),
        "Public native lane inventory": "ADR-005 public inventory missing",
        "Private stock-Haxe lane": "ADR-005 private lane missing",
        "non-Haxe PHP caller": (
            "ADR-005 must require a non-Haxe PHP consumer"
        ),
        "Before the G8 API": (
            "ADR-005 must retain the pre-G8 private-lane decision"
        ),
        "return <main>": "ADR-005 must preserve direct-return HXX ergonomics",
        "Licensing and publication remain blocked": (
            "ADR-005 must preserve the publication blocker"
        ),
    }
    for token, message in required.items():
        audit.check(token in adr, message)


def validate_generic_compiler_isolation(audit: Audit) -> None:
    source_root = audit.root / "compiler/reflaxe.php/src"
    audit.check(source_root.is_dir(), "generic compiler source directory missing")
    if not source_root.is_dir():
        return
    for source in sorted(source_root.rglob("*.hx")):
        try:
            content = source.read_text(encoding="utf-8")
        except OSError as error:
            audit.errors.append(f"cannot read generic compiler source {source}: {error}")
            continue
        match = GENERIC_COUPLING.search(content)
        if match is not None:
            relative = source.relative_to(audit.root).as_posix()
            audit.errors.append(
                "generic compiler contains WordPress/profile coupling: "
                f"{relative}: {match.group(0)}"
            )


def validate(root: Path) -> list[str]:
    audit = Audit(root)
    policy = audit.read_json("manifests/php-emission-policy.json")
    adr = audit.read_text("docs/adr/005-public-versus-private-php-emission.md")
    validate_manifest(audit, policy)
    validate_adr(audit, adr)
    validate_generic_compiler_isolation(audit)
    return audit.errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="repository root to audit",
    )
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        for error in errors:
            print(f"PHP emission policy error: {error}", file=sys.stderr)
        return 1
    print("ADR-005 PHP emission policy passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
