#!/usr/bin/env python3
"""Validate ADR-018's runtime-support packaging decision lock."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


MANIFEST = Path("manifests/runtime-support-packaging.json")
ADR = Path("docs/adr/018-runtime-support-packaging.md")
PHP_POLICY = Path("manifests/php-emission-policy.json")
TOOLCHAIN = Path("manifests/toolchain.lock.json")
FIXTURE_SOURCE = Path(
    "fixtures/runtime-support-packaging/src/fixture/privateimpl/Main.hx"
)
FIXTURE_README = Path("fixtures/runtime-support-packaging/README.md")
BUILDER = Path("scripts/runtime-support/build-fixtures.py")
FORBIDDEN_HAXE = re.compile(r"\b(?:Dynamic|Any|cast|Reflect|untyped)\b")


class Audit:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[str] = []

    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def read_text(self, relative: Path, label: str) -> str:
        file_path = self.root / relative
        if not file_path.is_file() or file_path.is_symlink():
            self.errors.append(f"missing real {label}: {relative.as_posix()}")
            return ""
        try:
            return file_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            self.errors.append(f"cannot read {label}: {error}")
            return ""

    def read_json(self, relative: Path, label: str) -> dict[str, Any]:
        source = self.read_text(relative, label)
        if source == "":
            return {}
        try:
            value = json.loads(source)
        except json.JSONDecodeError as error:
            self.errors.append(f"invalid {label} JSON: {error}")
            return {}
        if not isinstance(value, dict):
            self.errors.append(f"{label} must be a JSON object")
            return {}
        return value

    def exact_keys(self, value: Any, expected: set[str], label: str) -> None:
        if not isinstance(value, dict):
            self.errors.append(f"{label} must be an object")
            return
        actual = set(value)
        if actual != expected:
            self.errors.append(
                f"{label} keys differ: expected {sorted(expected)}, found {sorted(actual)}"
            )

    def exact_list(self, value: Any, expected: list[str], label: str) -> None:
        if value != expected:
            self.errors.append(f"{label} differs")

    def finish(self) -> None:
        if self.errors:
            for error in self.errors:
                print(f"runtime-support policy error: {error}", file=sys.stderr)
            raise SystemExit(1)


def object_value(value: dict[str, Any], key: str) -> dict[str, Any]:
    child = value.get(key)
    return child if isinstance(child, dict) else {}


def validate(root: Path) -> None:
    audit = Audit(root)
    policy = audit.read_json(MANIFEST, "ADR-018 decision lock")
    audit.exact_keys(
        policy,
        {
            "schemaVersion",
            "decision",
            "status",
            "profile",
            "authoring",
            "mvpPackage",
            "namespace",
            "autoload",
            "composer",
            "publicBoundary",
            "globalSymbols",
            "requiredInventory",
            "budgets",
            "futureSharedRuntime",
            "stopConditions",
            "evidence",
        },
        "ADR-018 decision lock",
    )
    audit.check(policy.get("schemaVersion") == 1, "ADR-018 schema version must be 1")
    audit.check(policy.get("decision") == "ADR-018", "decision identity must be ADR-018")
    audit.check(
        policy.get("status") == "accepted-architecture-with-executable-prototype",
        "ADR-018 architecture status must remain accepted with executable prototype",
    )
    audit.check(policy.get("profile") == "wp70-release", "ADR-018 exact profile changed")

    authoring = object_value(policy, "authoring")
    audit.exact_keys(
        authoring,
        {
            "commonPath",
            "runtimeNeedAuthority",
            "projectAndModuleIdentityAuthority",
            "userAuthoredRuntimeConfigRequired",
            "userAuthoredPhpRequired",
            "userAuthoredComposerRequired",
            "unknownRuntimeNeedDisposition",
        },
        "Haxe authoring policy",
    )
    audit.check(authoring.get("commonPath") == "typed-haxe-only", "common path must be typed Haxe only")
    audit.check(
        authoring.get("runtimeNeedAuthority") == "typed-transitive-private-closure",
        "private runtime needs must come from the typed transitive closure",
    )
    audit.check(
        authoring.get("projectAndModuleIdentityAuthority") == "semantic-plan",
        "semantic plan must own private package identity",
    )
    for field in (
        "userAuthoredRuntimeConfigRequired",
        "userAuthoredPhpRequired",
        "userAuthoredComposerRequired",
    ):
        audit.check(authoring.get(field) is False, f"Haxe common path cannot require {field}")
    audit.check(
        authoring.get("unknownRuntimeNeedDisposition") == "reject-before-publication",
        "unknown runtime needs must reject before publication",
    )

    package = object_value(policy, "mvpPackage")
    audit.exact_keys(
        package,
        {
            "scope",
            "dependencyClosure",
            "sharedSiteRuntimeAllowed",
            "serverHaxeNodeOrComposerRequired",
            "emptyRuntimeEmitted",
            "privateRoot",
            "runtimeRoot",
            "classmapPath",
            "inventoryPath",
            "rootAutoloadPath",
            "ownership",
        },
        "MVP package policy",
    )
    audit.check(
        package.get("scope") == "one-native-wordpress-deployable",
        "private support must be scoped to one native WordPress deployable",
    )
    audit.check(package.get("sharedSiteRuntimeAllowed") is False, "shared site runtime is forbidden for MVP")
    audit.check(
        package.get("serverHaxeNodeOrComposerRequired") is False,
        "production server cannot require Haxe, Node, or Composer",
    )
    audit.check(package.get("emptyRuntimeEmitted") is False, "empty private runtimes cannot be emitted")
    audit.check(package.get("privateRoot") == "private/wordpresshx", "private root changed")
    audit.check(
        package.get("rootAutoloadPath") == "includes/autoload.php",
        "root must include one deterministic autoload boundary",
    )
    audit.check(
        package.get("ownership") == "same-manifest-last-transaction-as-public-artifact",
        "private support must use the public artifact ownership transaction",
    )

    namespace = object_value(policy, "namespace")
    audit.exact_keys(
        namespace,
        {
            "schema",
            "identityFields",
            "canonicalInput",
            "digest",
            "digestBitsRetained",
            "prefixPattern",
            "haxeDefine",
            "userConfigurable",
            "contentOrVersionIncluded",
            "workspaceCollisionDisposition",
            "duplicateLogicalModuleDisposition",
            "sameRootReinclude",
            "sameLogicalPluginConcurrentVersions",
        },
        "private namespace policy",
    )
    audit.exact_list(namespace.get("identityFields"), ["projectId", "moduleId"], "namespace identity fields")
    audit.check(namespace.get("digest") == "sha256", "private prefix digest must be SHA-256")
    audit.check(namespace.get("digestBitsRetained") == 96, "private prefix must retain 96 digest bits")
    audit.check(
        namespace.get("prefixPattern") == "wphx_internal.p[0-9a-f]{24}",
        "private prefix pattern changed",
    )
    audit.check(namespace.get("haxeDefine") == "php-prefix", "stock PHP prefix define changed")
    audit.check(namespace.get("userConfigurable") is False, "users cannot configure the private prefix")
    audit.check(
        namespace.get("contentOrVersionIncluded") is False,
        "ordinary edits cannot churn the private namespace",
    )
    audit.check(
        namespace.get("workspaceCollisionDisposition") == "reject-plan",
        "namespace collision must reject the plan",
    )
    audit.check(
        namespace.get("sameRootReinclude") == "idempotent-non-fatal",
        "same-root reinclude must stay idempotent",
    )

    autoload = object_value(policy, "autoload")
    audit.exact_keys(
        autoload,
        {
            "stockFrontControllerPackaged",
            "stockFrontControllerReason",
            "defaultMechanism",
            "exactFullyQualifiedNamesOnly",
            "directoryScanning",
            "networkAccess",
            "processIncludePathMutation",
            "unboundedNamespaceResolver",
            "prependBeforeHostAutoloaders",
            "otherPluginLookup",
            "deterministicOrderAndHashes",
        },
        "autoload policy",
    )
    audit.check(autoload.get("stockFrontControllerPackaged") is False, "stock Haxe front cannot be packaged")
    audit.check(
        autoload.get("defaultMechanism") == "generated-package-local-authoritative-classmap",
        "default private autoload must be an authoritative package-local class map",
    )
    for field in (
        "directoryScanning",
        "networkAccess",
        "processIncludePathMutation",
        "unboundedNamespaceResolver",
        "prependBeforeHostAutoloaders",
        "otherPluginLookup",
    ):
        audit.check(autoload.get(field) is False, f"autoload must not enable {field}")
    audit.check(autoload.get("exactFullyQualifiedNamesOnly") is True, "autoload must use exact FQCNs")
    audit.check(autoload.get("deterministicOrderAndHashes") is True, "class map must be deterministic and hashed")

    composer = object_value(policy, "composer")
    audit.exact_keys(
        composer,
        {
            "mvpRuntimeGraph",
            "buildAndAnalysisUse",
            "serverInstallRequired",
            "runtimeDependencyAdmission",
            "futureRequirements",
            "separateVendorDirectoriesCountAsIsolation",
        },
        "Composer policy",
    )
    audit.check(
        composer.get("mvpRuntimeGraph") == "absent-no-runtime-dependencies",
        "MVP runtime Composer graph must remain absent",
    )
    audit.check(composer.get("serverInstallRequired") is False, "server Composer install is forbidden")
    audit.check(
        composer.get("runtimeDependencyAdmission") == "unsupported-until-dedicated-follow-up",
        "runtime Composer packages cannot be admitted implicitly",
    )
    audit.check(
        composer.get("separateVendorDirectoriesCountAsIsolation") is False,
        "separate vendor directories cannot be mistaken for PHP symbol isolation",
    )
    audit.exact_list(
        composer.get("futureRequirements"),
        [
            "typed-haxe-declaration-and-explicit-networked-lock-command",
            "exact-composer-tool-and-lock",
            "offline-build-check-and-dev-consumption",
            "bundled-production-files-and-optimized-authoritative-autoload",
            "package-specific-symbol-isolation-or-proven-global-abi",
            "public-abi-internal-type-scan",
            "artifact-derived-sbom-licenses-notices-and-byte-origins",
            "two-plugin-version-skew-install-update-rollback-and-native-caller-evidence",
        ],
        "future Composer admission requirements",
    )

    public = object_value(policy, "publicBoundary")
    audit.check(public.get("wordPressEntries") == "public-native-adapters-only", "WordPress entries must be public native")
    audit.check(public.get("privateNamesAllowedInMethodBodies") is True, "adapter bodies must be allowed to call private logic")
    audit.check(public.get("privateNamesAllowedInPublicAbi") is False, "private support names cannot leak into public ABI")
    audit.check(public.get("privateCallbacksRegisteredWithWordPress") is False, "private callbacks cannot be registered with WordPress")
    audit.check(public.get("nativeConversionAtAdapter") is True, "native conversion must occur at the adapter")
    audit.exact_list(
        public.get("reflectionScan"),
        [
            "parameters",
            "returns",
            "properties",
            "parents",
            "interfaces",
            "traits",
            "attributes",
            "constants",
            "default-values",
            "throws-contract",
            "names",
        ],
        "public reflection scan",
    )

    globals_policy = object_value(policy, "globalSymbols")
    audit.exact_keys(
        globals_policy,
        {
            "defaultAllowed",
            "stockPolyfillException",
            "admissionByAnalogyAllowed",
            "compatibilityConstant",
            "nativeInternalFunctionAllowed",
            "sameExactDeclaringFileHashAllowed",
            "differentHashDisposition",
        },
        "global symbol policy",
    )
    audit.check(globals_policy.get("defaultAllowed") is False, "unprefixed global support symbols must default to rejection")
    audit.check(
        globals_policy.get("stockPolyfillException") == "exact-inventoried-guarded-matrix-tested-only",
        "stock polyfill exception must remain exact and evidence-bound",
    )
    audit.check(globals_policy.get("admissionByAnalogyAllowed") is False, "global symbols cannot be admitted by analogy")
    audit.check(
        globals_policy.get("compatibilityConstant") == "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256",
        "global polyfill compatibility marker changed",
    )
    audit.check(
        globals_policy.get("nativeInternalFunctionAllowed") is True,
        "native/internal compatible polyfill functions must remain admissible",
    )
    audit.check(
        globals_policy.get("sameExactDeclaringFileHashAllowed") is True,
        "byte-identical declared polyfill functions must remain admissible",
    )
    audit.check(
        globals_policy.get("differentHashDisposition") == "reject-private-boot-WPHX5201",
        "incompatible global polyfills must reject private boot with WPHX5201",
    )

    audit.exact_list(
        policy.get("requiredInventory"),
        [
            "project-module-and-prefix-derivation",
            "exact-compiler-and-runtime-identities",
            "private-roots-and-transitive-dependency-reasons",
            "generated-files-symbols-global-polyfills-and-hashes",
            "authoritative-classmap-and-initialization-order",
            "public-private-adapter-edges-and-conversions",
            "php-file-count-and-compressed-uncompressed-bytes",
            "isolated-cold-boot-samples-and-wordpress-request-evidence",
            "duplicate-include-and-two-plugin-version-skew-results",
            "global-polyfill-compatibility-and-mismatch-rejection",
            "source-correlation-license-sbom-syntax-static-ownership-and-install-receipts",
        ],
        "private runtime inventory",
    )

    budgets = object_value(policy, "budgets")
    audit.check(
        budgets.get("serverOnlyStarterGeneratedPhpRuntimeMaxBytes") == 409600,
        "PRD 400 KiB generated PHP/runtime ceiling changed",
    )
    audit.check(
        budgets.get("prototypePrivateClosureReviewMaxBytes") == 163840,
        "prototype private closure review threshold changed",
    )
    audit.check(
        budgets.get("prototypeIsolatedOpcacheDisabledColdBootP50MaxMilliseconds") == 20,
        "prototype cold-boot review threshold changed",
    )
    audit.check(
        budgets.get("thresholdKind") == "stop-and-review-not-production-support",
        "prototype thresholds cannot become production support claims",
    )
    audit.check(budgets.get("durableWarmWordPressBudgetOwner") == "wordpresshx-g8", "G8 must own durable warm budgets")
    audit.check(budgets.get("productionPerformanceClaim") == "not-tested", "production performance must remain not-tested")

    shared = object_value(policy, "futureSharedRuntime")
    audit.check(shared.get("currentDisposition") == "forbidden", "shared runtime must remain forbidden")
    audit.check(shared.get("requiresSupersedingAdr") is True, "shared runtime requires a superseding ADR")
    audit.check(shared.get("singleMicrobenchmarkSufficient") is False, "one microbenchmark cannot justify a shared runtime")
    audit.check(shared.get("rollback") == "per-deployable-dependency-closed-support", "shared-runtime rollback changed")

    evidence = object_value(policy, "evidence")
    audit.check(evidence.get("architectureAccepted") is True, "ADR-018 architecture must be accepted")
    audit.check(evidence.get("runtimeComposerDependencies") == "unsupported", "runtime Composer support cannot be pre-claimed")
    audit.check(evidence.get("sharedRuntime") == "forbidden", "shared runtime evidence cannot be pre-claimed")
    audit.check(evidence.get("productionSupport") == "not-tested", "production support must remain not-tested")
    audit.check(evidence.get("publicationAuthorized") is False, "ADR-018 cannot authorize publication")

    adr = audit.read_text(ADR, "ADR-018")
    for required in (
        "- Status: accepted",
        "The routine Haxe author writes no runtime-support configuration.",
        "The stock-Haxe-generated PHP front file is a build intermediate and is never",
        "Composer is conditional and absent from the MVP private lane",
        "A site-wide or central Composer WordPressHx runtime is forbidden for the MVP.",
        "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256",
        "`WPHX5201`",
        "No production support",
    ):
        audit.check(required in adr, f"ADR-018 is missing required decision text: {required}")

    php_policy = audit.read_json(PHP_POLICY, "ADR-005 PHP emission policy")
    private_lane = object_value(php_policy, "privateStockHaxeLane")
    audit.check(
        private_lane.get("packageScope") == "one-namespaced-dependency-closed-plugin-or-theme",
        "ADR-005 no longer agrees with per-deployable private support",
    )
    audit.check(private_lane.get("sharedSiteRuntimeAllowed") is False, "ADR-005 cannot admit a shared runtime")
    migration = object_value(php_policy, "migrationPolicy")
    audit.check(
        migration.get("budgetOwner") == "ADR-018-and-G8-after-G1-measurement",
        "ADR-005 runtime budget authority changed",
    )

    toolchain = audit.read_json(TOOLCHAIN, "toolchain lock")
    graphs = object_value(toolchain, "dependencyGraphs")
    toolchain_composer = object_value(graphs, "composer")
    audit.check(
        toolchain_composer.get("status") == "not-active-in-g0",
        "ADR-018 cannot silently activate the Composer graph",
    )
    audit.check(toolchain_composer.get("manifestPaths") == [], "toolchain Composer manifests must remain empty")
    audit.check(toolchain_composer.get("lockPaths") == [], "toolchain Composer locks must remain empty")
    audit.check(toolchain_composer.get("activePackages") == [], "toolchain Composer packages must remain empty")

    haxe_source = audit.read_text(FIXTURE_SOURCE, "strict Haxe private fixture")
    forbidden = FORBIDDEN_HAXE.search(haxe_source)
    audit.check(forbidden is None, f"strict Haxe private fixture contains forbidden token: {forbidden.group(0) if forbidden else ''}")
    audit.check("@:keep" not in haxe_source, "fixture author must not manually retain the private entry")
    for required in ("public static function decorate(value:String):String", "runtime_alpha", "runtime_beta"):
        audit.check(required in haxe_source, f"strict Haxe private fixture is missing: {required}")

    fixture_readme = audit.read_text(FIXTURE_README, "runtime-support fixture README")
    audit.check("only maintained private application" in fixture_readme, "fixture must identify Haxe as private application authority")
    builder = audit.read_text(BUILDER, "runtime-support fixture builder")
    for required in (
        "keep('fixture.privateimpl.Main')",
        "php-prefix=",
        "real-position",
        "package-local-authoritative-classmap",
        "absent-no-runtime-dependencies",
        "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256",
        "WPHX5201",
    ):
        audit.check(required in builder, f"fixture builder is missing contract marker: {required}")

    fixture_root = root / "fixtures/runtime-support-packaging"
    if fixture_root.is_dir():
        for candidate in fixture_root.rglob("*"):
            if candidate.name in {"composer.json", "composer.lock", "vendor"}:
                audit.errors.append(
                    f"MVP runtime-support fixture contains forbidden Composer artifact: {candidate.relative_to(root).as_posix()}"
                )

    audit.finish()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    validate(args.root.resolve())
    print("ADR-018 runtime-support packaging policy passed")


if __name__ == "__main__":
    main()
