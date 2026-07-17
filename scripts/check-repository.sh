#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  .gitleaks.toml
  .github/workflows/repository.yml
  .beads/hooks/pre-commit
  .beads/hooks/pre-push
  AGENTS.md
  README.md
  GOVERNANCE.md
  CONTRIBUTING.md
  SECURITY.md
  SUPPORT.md
  CHANGELOG.md
  LICENSES/README.md
  wordpress-hx-sdk-product-requirements.md
  docs/README.md
  docs/adr/README.md
  docs/adr/001-product-and-repository-boundary.md
  docs/adr/002-exact-compatibility-profiles.md
  docs/adr/003-package-topology-and-lockstep-versioning.md
  docs/adr/004-generic-php-compiler-home.md
  docs/adr/008-profile-generation-and-api-classification.md
  docs/adr/011-hxx-parser-and-lowering-architecture.md
  docs/architecture/browser-compiler.md
  docs/architecture/haxe-first-site-authoring.md
  docs/architecture/php-compiler.md
  docs/architecture/repository-layout.md
  docs/product/README.md
  docs/release/README.md
  packages/README.md
  packages/core/README.md
  packages/core/test.hxml
  packages/core/src/wordpress/hx/core/profile/AdministrativeResult.hx
  packages/core/src/wordpress/hx/core/profile/ApiClassification.hx
  packages/core/src/wordpress/hx/core/profile/CapabilityId.hx
  packages/core/src/wordpress/hx/core/profile/CatalogDigest.hx
  packages/core/src/wordpress/hx/core/profile/CatalogRevision.hx
  packages/core/src/wordpress/hx/core/profile/CompileTimeCapability.hx
  packages/core/src/wordpress/hx/core/profile/EvidenceStatus.hx
  packages/core/src/wordpress/hx/core/profile/ProfileContractError.hx
  packages/core/src/wordpress/hx/core/profile/ProfileGate.hx
  packages/core/src/wordpress/hx/core/profile/ProfileId.hx
  packages/core/src/wordpress/hx/core/profile/RuntimeCapability.hx
  packages/core/src/wordpress/hx/core/profile/RuntimeRequestScope.hx
  packages/core/test/wordpress/hx/core/profile/tests/ProfileContractTest.hx
  packages/core/test-negative/profile_gate_implicit/Main.hx
  packages/core/test-negative/profile_gate_wp70/Main.hx
  packages/core/test-negative/runtime_as_compile_time/Main.hx
  packages/core/test-negative/unknown_classification/Main.hx
  packages/core/test-positive/profile_gate/Main.hx
  packages/hxx/.haxerc
  packages/hxx/README.md
  packages/hxx/dependency-lock.json
  packages/hxx/haxe_libraries/html-entities.hxml
  packages/hxx/haxe_libraries/tink_anon.hxml
  packages/hxx/haxe_libraries/tink_core.hxml
  packages/hxx/haxe_libraries/tink_hxx.hxml
  packages/hxx/haxe_libraries/tink_macro.hxml
  packages/hxx/haxe_libraries/tink_parse.hxml
  packages/hxx/scripts/test.sh
  packages/hxx/scripts/verify-dependency-lock.py
  packages/hxx/scripts/verify-snapshots.py
  packages/hxx/src/wordpress/hx/hxx/_internal/HxxParserAdapter.hx
  packages/hxx/src/wordpress/hx/hxx/prototype/BrowserHxx.hx
  packages/hxx/src/wordpress/hx/hxx/prototype/BrowserSnapshot.hx
  packages/hxx/src/wordpress/hx/hxx/prototype/ServerHxx.hx
  packages/hxx/src/wordpress/hx/hxx/prototype/ServerSnapshot.hx
  packages/hxx/test/expected/browser.json
  packages/hxx/test/expected/server.json
  packages/hxx/test-negative/malformed_markup/Main.hx
  packages/hxx/test-negative/duplicate_slot/Main.hx
  packages/hxx/test-negative/missing_prop/Main.hx
  packages/hxx/test-negative/missing_slot/Main.hx
  packages/hxx/test-negative/open_spread/Main.hx
  packages/hxx/test-negative/optional_spread_missing_prop/Main.hx
  packages/hxx/test-negative/target_mismatch/Main.hx
  packages/hxx/test-negative/unknown_prop/Main.hx
  packages/hxx/test-negative/wrong_child_spread/Main.hx
  packages/hxx/test-negative/wrong_prop_type/Main.hx
  packages/hxx/test-positive/browser/Main.hx
  packages/hxx/test-positive/server/Main.hx
  packages/hxx/test-positive/spread_override/Main.hx
  compiler/README.md
  profiles/README.md
  profiles/catalog-selection.json
  profiles/classification-decision-lock.json
  profiles/decision-lock.json
  profiles/gutenberg-forward-23.4/README.md
  profiles/gutenberg-forward-23.4/source.lock.json
  profiles/wp70-release/README.md
  profiles/wp70-release/source.lock.json
  generated/gutenberg-forward-23.4/catalog-v1/catalog.json
  generated/gutenberg-forward-23.4/catalog-v1/generation-report.json
  generated/gutenberg-forward-23.4/catalog-v1/omissions.json
  generated/wp70-release/catalog-v1/catalog.json
  generated/wp70-release/catalog-v1/generation-report.json
  generated/wp70-release/catalog-v1/omissions.json
  schemas/README.md
  schemas/profile.schema.json
  tools/README.md
  examples/README.md
  fixtures/README.md
  fixtures/profiles/README.md
  fixtures/profiles/valid/gutenberg-forward-23.4.json
  fixtures/profiles/valid/wp70-release.json
  test/README.md
  docker/README.md
  docker/images.lock.json
  docker/wordpress/compose.yml
  docker/wordpress/health.php
  docker/wordpress/install.php
  manifests/README.md
  manifests/hxx-architecture.json
  manifests/package-topology.json
  manifests/upstream.lock.json
  manifests/evidence/sdk-004-canonical-repository.json
  manifests/evidence/sdk-010-wp70-release.json
  manifests/evidence/sdk-011-gutenberg-forward-23.4.json
  manifests/evidence/sdk-012-profile-schema.json
  manifests/evidence/sdk-013-profile-generator.json
  manifests/evidence/sdk-090-wordpress-harness.json
  manifests/evidence/sdk-030-genes-ts-v1.33.0.json
  manifests/evidence/sdk-020-reflaxe-php-bootstrap.json
  manifests/evidence/sdk-021-php-ir-printer.json
  manifests/evidence/sdk-080-hxx-parser-prototype.json
  compiler/reflaxe.php/haxelib.json
  compiler/reflaxe.php/provenance.json
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpArrayEntry.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpClass.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpClassKind.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpClosureCapture.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpDeclaration.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpExpr.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpFile.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpFunction.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpIdentifier.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpMethod.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpParameter.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpProperty.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpQualifiedName.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpSourceRange.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpStmt.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpType.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpVisibility.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpPrinter.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpRenderedDeclaration.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpRenderedFile.hx
  compiler/reflaxe.php/test/reflaxe/php/tests/PrinterTest.hx
  compiler/reflaxe.php/scripts/test-php-matrix.sh
  compiler/reflaxe.php/scripts/test.sh
  scripts/beads/push-safe.sh
  scripts/ci/check-security-tooling.sh
  scripts/ci/install-gitleaks.sh
  scripts/docker/check-image-lock.py
  scripts/hooks/install.sh
  scripts/hooks/pre-commit
  scripts/hooks/pre-push
  scripts/hooks/test.sh
  scripts/lint/hx-format-guard.sh
  scripts/lint/local-path-guard-staged.sh
  scripts/lint/whitespace-guard.sh
  scripts/profiles/check-decision-lock.py
  scripts/profiles/check-classification-decision.py
  scripts/profiles/check-profile-isolation.py
  scripts/profiles/check-generated-catalogs.py
  scripts/profiles/generate-catalogs.py
  scripts/profiles/test-catalog-generator.sh
  scripts/profiles/test-profile-haxe.sh
  scripts/profiles/validate-profile-schema.py
  scripts/profiles/verify-gutenberg-forward-23-4.py
  scripts/profiles/verify-wp70-release.py
  scripts/security/run-beads-gitleaks.sh
  scripts/security/run-gitleaks.sh
  scripts/security/run-local-path-audit.sh
  scripts/wordpress/reset-harness.sh
  scripts/wordpress/run-harness.sh
  scripts/wordpress/test-harness.sh
  scripts/wordpress/verify-distribution.py
)

missing=0
for path in "${required_files[@]}"; do
  if [[ ! -s "${path}" ]]; then
    echo "missing or empty required bootstrap file: ${path}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 1
fi

for path in "${required_files[@]}"; do
  if ! git ls-files --error-unmatch -- "${path}" >/dev/null 2>&1; then
    echo "required bootstrap file is not tracked: ${path}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 1
fi

python3 - <<'PY'
import hashlib
import json
import re
from pathlib import Path

lock = json.loads(Path("manifests/upstream.lock.json").read_text(encoding="utf-8"))
receipt = json.loads(
    Path("manifests/evidence/sdk-030-genes-ts-v1.33.0.json").read_text(
        encoding="utf-8"
    )
)
repository_receipt = json.loads(
    Path("manifests/evidence/sdk-004-canonical-repository.json").read_text(
        encoding="utf-8"
    )
)
php_provenance = json.loads(
    Path("compiler/reflaxe.php/provenance.json").read_text(encoding="utf-8")
)
php_receipt = json.loads(
    Path("manifests/evidence/sdk-020-reflaxe-php-bootstrap.json").read_text(
        encoding="utf-8"
    )
)
php_ir_receipt = json.loads(
    Path("manifests/evidence/sdk-021-php-ir-printer.json").read_text(
        encoding="utf-8"
    )
)
haxelib = json.loads(
    Path("compiler/reflaxe.php/haxelib.json").read_text(encoding="utf-8")
)
adr = Path("docs/adr/001-product-and-repository-boundary.md").read_text(
    encoding="utf-8"
)
profile_adr = Path("docs/adr/002-exact-compatibility-profiles.md").read_text(
    encoding="utf-8"
)
classification_adr = Path(
    "docs/adr/008-profile-generation-and-api-classification.md"
).read_text(encoding="utf-8")
profile_lock = json.loads(
    Path("profiles/decision-lock.json").read_text(encoding="utf-8")
)
classification_lock_path = Path("profiles/classification-decision-lock.json")
classification_lock = json.loads(
    classification_lock_path.read_text(encoding="utf-8")
)
wp_source_lock_path = Path("profiles/wp70-release/source.lock.json")
wp_source_lock = json.loads(wp_source_lock_path.read_text(encoding="utf-8"))
wp_receipt = json.loads(
    Path("manifests/evidence/sdk-010-wp70-release.json").read_text(
        encoding="utf-8"
    )
)
forward_source_lock_path = Path(
    "profiles/gutenberg-forward-23.4/source.lock.json"
)
forward_source_lock = json.loads(
    forward_source_lock_path.read_text(encoding="utf-8")
)
forward_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-011-gutenberg-forward-23.4.json"
    ).read_text(encoding="utf-8")
)
profile_schema_path = Path("schemas/profile.schema.json")
profile_schema = json.loads(profile_schema_path.read_text(encoding="utf-8"))
sdk012_receipt = json.loads(
    Path("manifests/evidence/sdk-012-profile-schema.json").read_text(
        encoding="utf-8"
    )
)
sdk013_receipt = json.loads(
    Path("manifests/evidence/sdk-013-profile-generator.json").read_text(
        encoding="utf-8"
    )
)
image_lock = json.loads(
    Path("docker/images.lock.json").read_text(encoding="utf-8")
)
package_topology = json.loads(
    Path("manifests/package-topology.json").read_text(encoding="utf-8")
)
hxx_architecture = json.loads(
    Path("manifests/hxx-architecture.json").read_text(encoding="utf-8")
)
hxx_dependency_lock_path = Path("packages/hxx/dependency-lock.json")
hxx_dependency_lock = json.loads(
    hxx_dependency_lock_path.read_text(encoding="utf-8")
)
hxx_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-080-hxx-parser-prototype.json"
    ).read_text(encoding="utf-8")
)
sdk090_receipt = json.loads(
    Path("manifests/evidence/sdk-090-wordpress-harness.json").read_text(
        encoding="utf-8"
    )
)
readme = Path("README.md").read_text(encoding="utf-8")

entry = lock["entries"]["genes-ts"]
subject = receipt["subject"]
sha1 = re.compile(r"[0-9a-f]{40}\Z")
sha256 = re.compile(r"[0-9a-f]{64}\Z")

assert package_topology["schemaVersion"] == 1
assert package_topology["decision"] == "ADR-003"
assert package_topology["status"] == "accepted-architecture"
assert package_topology["claim"] == "not-published"
assert package_topology["publicationAuthorized"] is False
assert package_topology["repositoryModel"] == "monorepo"
release_unit = package_topology["releaseUnit"]
assert release_unit["versionPolicy"] == (
    "one-lockstep-sdk-version-through-1.x"
)
assert release_unit["mixedPublicArtifactVersionsSupported"] is False
assert {
    (artifact["id"], artifact["ecosystem"])
    for artifact in release_unit["publicArtifacts"]
} == {
    ("wordpress-hx", "haxelib"),
    ("@wordpress-hx/cli", "npm"),
}

source_modules = {
    module["id"]: module for module in package_topology["sourceModules"]
}
assert set(source_modules) == {
    "core",
    "profiles",
    "contracts",
    "hxx",
    "server",
    "gutenberg",
    "build",
    "testing",
    "interop-php",
    "interop-js",
    "cli",
}
assert all(
    module["directPublication"] is False
    for module_id, module in source_modules.items()
    if module_id != "cli"
)
assert source_modules["cli"]["publicationArtifact"] == "@wordpress-hx/cli"
assert source_modules["core"]["dependsOn"] == []
assert set(source_modules["server"]["dependsOn"]) == {
    "core",
    "profiles",
    "contracts",
    "hxx",
}
assert set(source_modules["gutenberg"]["dependsOn"]) == {
    "core",
    "profiles",
    "contracts",
    "hxx",
}
assert "build" not in source_modules["server"]["dependsOn"]
assert "build" not in source_modules["gutenberg"]["dependsOn"]
assert "testing" not in {
    dependency
    for module_id, module in source_modules.items()
    if module_id != "testing"
    for dependency in module["dependsOn"]
}

visiting = set()
visited = set()


def visit_source_module(module_id):
    assert module_id in source_modules
    assert module_id not in visiting, f"package topology cycle at {module_id}"
    if module_id in visited:
        return
    visiting.add(module_id)
    for dependency in source_modules[module_id]["dependsOn"]:
        visit_source_module(dependency)
    visiting.remove(module_id)
    visited.add(module_id)


for source_module_id in source_modules:
    visit_source_module(source_module_id)

workspace_components = {
    component["id"]: component
    for component in package_topology["workspaceComponents"]
}
assert workspace_components["reflaxe.php"]["sdkVersioned"] is False
assert workspace_components["reflaxe.php"]["classification"] == (
    "private-generic-compiler"
)
genes_input = next(
    item
    for item in package_topology["externalInputs"]
    if item["id"] == "genes-ts"
)
assert genes_input["authority"] == "external-public-release"
assert genes_input["repositoryRelativePathAllowedInRelease"] is False
independent_admission = package_topology["independentVersioningAdmission"]
assert independent_admission["earliestReview"] == "post-1.0"
assert independent_admission["requiresSupersedingAdr"] is True
assert len(independent_admission["criteria"]) == 6
assert independent_admission[
    "widerFamilySharedContractRequiresTwoRealConsumers"
] is True

assert hxx_architecture["schemaVersion"] == 1
assert hxx_architecture["decision"] == "ADR-011"
assert hxx_architecture["status"] == "accepted-architecture"
assert hxx_architecture["claim"] == "parser-adapter-prototype-tested"
assert hxx_architecture["authoring"]["primarySyntax"] == (
    "haxe-4-inline-markup"
)
assert hxx_architecture["authoring"]["happyPathRequiresEscapeHatch"] is False
hxx_parser = hxx_architecture["parser"]
assert hxx_parser["policy"] == "pinned-public-compile-time-dependency"
assert hxx_parser["package"] == "tink_hxx"
assert hxx_parser["selectedVersion"] == hxx_parser["tag"] == "0.25.1"
assert hxx_parser["tagObjectType"] == "commit"
assert hxx_parser["commit"] == (
    "75ef63c78851fcd7c1846d74959cbd4cea0b4ced"
)
assert hxx_parser["tree"] == (
    "ef1ae3be1574e745c7877f5567d9b76ea36dca47"
)
assert sha1.fullmatch(hxx_parser["commit"])
assert sha1.fullmatch(hxx_parser["tree"])
assert hxx_parser["publicTinkTypesExposed"] is False
assert hxx_parser["releaseArtifactAndTransitivesResolved"] is True
assert hxx_parser["resolutionOwner"] == "wordpresshx-sdk-080"
assert hxx_parser["dependencyLock"] == hxx_dependency_lock_path.as_posix()
assert hxx_parser["releaseArtifact"]["sha256"] == (
    "0b6f2d925c8fb854732f67e293d268d0e51cfa0f69b12ebfc9bb16c4f71baa1e"
)
assert sha256.fullmatch(hxx_parser["releaseArtifact"]["sha256"])
assert hxx_parser["resolvedTransitiveCount"] == 5
assert hxx_parser["forkPolicy"] == "no-fork-without-superseding-adr"
assert [lowerer["id"] for lowerer in hxx_architecture["lowerers"]] == [
    "server",
    "browser",
]
assert all(
    lowerer["nodeTypeSharedWithOtherTargets"] is False
    for lowerer in hxx_architecture["lowerers"]
)
server_lowerer = hxx_architecture["lowerers"][0]
assert server_lowerer["genericCompilerOwner"] == "compiler/reflaxe.php"
assert server_lowerer["wordpressExtensionOwner"] == (
    "compiler/wordpress-and-sdk-server-hxx"
)
php_markup = hxx_architecture["phpMarkupOwnership"]
assert php_markup["genericOwner"] == "compiler/reflaxe.php"
assert php_markup["genericImportsWordpressSdk"] is False
assert php_markup["browserCompilerOwner"] == "genes-ts"
assert php_markup["handwrittenMixedPhpMarkupRequiredOnHappyPath"] is False
assert hxx_architecture["escapeHatchOrder"] == [
    "typed-facade-or-component",
    "checked-existing-native-template-or-component",
    "typed-external-contract",
    "policy-produced-trusted-fragment",
    "waivered-unsafe-raw-target-segment",
]
assert hxx_architecture["densityPolicy"]["staticMarkupStaysStatic"] is True
assert hxx_architecture["densityPolicy"]["unusedAbstractionsEmitted"] is False
assert set(hxx_architecture["prohibitedRuntime"]) == {
    "hxx-parser",
    "tink-hxx-implementation",
    "coconut-runtime",
    "virtual-dom",
    "generic-component-registry",
    "template-resolver",
    "wordpress-request-dispatcher",
}
prototype_evidence = hxx_architecture["prototypeEvidence"]
assert prototype_evidence["receiptId"] == hxx_receipt["receiptId"]
assert prototype_evidence["dependencyLock"] == (
    hxx_dependency_lock_path.as_posix()
)
assert prototype_evidence["serverResultType"] != prototype_evidence[
    "browserResultType"
]
assert prototype_evidence["relativeSourceSpansTested"] is True
assert prototype_evidence["normalHaxeExpressionTypingTested"] is True
assert prototype_evidence[
    "propsChildrenSlotsAndClosedSpreadsTested"
] is True
assert prototype_evidence["targetLeakageNegativeTested"] is True
assert prototype_evidence["prohibitedRuntimeLeakScanPassed"] is True
assert prototype_evidence["nativeLoweringImplemented"] is False

assert hxx_dependency_lock["schemaVersion"] == 1
assert hxx_dependency_lock["status"] == "resolved-sdk-080"
assert hxx_dependency_lock["toolchain"] == {
    "haxe": "4.3.7",
    "lix": "15.12.2",
}
assert hxx_dependency_lock["parser"]["name"] == "tink_hxx"
assert hxx_dependency_lock["parser"]["version"] == "0.25.1"
assert hxx_dependency_lock["parser"]["commit"] == hxx_parser["commit"]
assert hxx_dependency_lock["parser"]["tree"] == hxx_parser["tree"]
assert hxx_dependency_lock["parser"]["artifact"]["sha256"] == (
    hxx_parser["releaseArtifact"]["sha256"]
)
assert len(hxx_dependency_lock["dependencies"]) == 5
assert [
    dependency["name"] for dependency in hxx_dependency_lock["dependencies"]
] == sorted(
    dependency["name"] for dependency in hxx_dependency_lock["dependencies"]
)
assert all(
    dependency["sourceKind"] in {"haxelib", "git"}
    for dependency in hxx_dependency_lock["dependencies"]
)
assert hxx_dependency_lock["policy"] == {
    "compileTimeOnly": True,
    "floatingVersionsAllowed": False,
    "haxelibDevAllowed": False,
    "repositoryRelativeDependencyAllowed": False,
}

hxx_entry = lock["entries"]["tink-hxx-parser"]
assert hxx_entry["packageIdentity"] == "haxelib:tink_hxx@0.25.1"
assert hxx_entry["commit"] == hxx_parser["commit"]
assert hxx_entry["tree"] == hxx_parser["tree"]
assert hxx_entry["releaseArtifact"]["sha256"] == (
    hxx_parser["releaseArtifact"]["sha256"]
)
assert hxx_entry["dependencyLock"]["path"] == (
    hxx_dependency_lock_path.as_posix()
)
assert hxx_entry["dependencyLock"]["sha256"] == hashlib.sha256(
    hxx_dependency_lock_path.read_bytes()
).hexdigest()
assert hxx_entry["compileTimeOnly"] is True
assert hxx_entry["publicTinkTypesExposed"] is False
assert hxx_entry["runtimeDistributionAllowed"] is False

assert hxx_receipt["schemaVersion"] == 1
assert hxx_receipt["receiptId"] == "SDK-080-HXX-PARSER-PROTOTYPE"
assert hxx_receipt["receiptId"] in hxx_entry["testReceiptIds"]
assert hxx_receipt["bead"] == "wordpresshx-sdk-080"
assert hxx_receipt["subject"]["dependencyLock"]["sha256"] == (
    hxx_entry["dependencyLock"]["sha256"]
)
for receipt_subject in (
    hxx_receipt["subject"]["adapter"],
    hxx_receipt["subject"]["expectedSnapshots"]["server"],
    hxx_receipt["subject"]["expectedSnapshots"]["browser"],
):
    subject_path = Path(receipt_subject["path"])
    assert hashlib.sha256(subject_path.read_bytes()).hexdigest() == (
        receipt_subject["sha256"]
    )
for verifier_name in ("dependencyVerifier", "snapshotVerifier"):
    verifier = hxx_receipt["localVerification"][verifier_name]
    verifier_path = Path(verifier["path"])
    assert hashlib.sha256(verifier_path.read_bytes()).hexdigest() == (
        verifier["sha256"]
    )
    compile(
        verifier_path.read_text(encoding="utf-8"),
        verifier_path.as_posix(),
        "exec",
    )
assert hxx_receipt["localVerification"]["gate"]["outcome"] == "passed"
assert hxx_receipt["prototype"]["generatorApiUsed"] is False
assert hxx_receipt["prototype"]["publicTinkTypesExposed"] is False
assert hxx_receipt["prototype"]["runtimeParserUsed"] is False
assert hxx_receipt["prototype"]["sourceCorrelation"]["outcome"] == (
    "passed"
)
assert hxx_receipt["prototype"]["targetResults"][
    "sharedRuntimeNodeType"
] is False
assert hxx_receipt["localVerification"]["generatedArtifacts"][
    "parserCoconutVdomRegistryResolverLeakScan"
] == "passed"
assert hxx_receipt["localVerification"]["compileFailureDiagnostics"][
    "fixtureCount"
] == 10
assert hxx_receipt["localVerification"]["compileFailureDiagnostics"][
    "positiveWarningFixtureCount"
] == 1
assert hxx_receipt["fullPortReferenceReview"][
    "codeOrFixtureBytesCopied"
] is False
assert hxx_receipt["changeDecision"]["tinkHxxSourceChanged"] is False
assert hxx_receipt["changeDecision"]["tinkHxxForkCreated"] is False
assert hxx_receipt["changeDecision"]["genesSourceChanged"] is False
assert hxx_receipt["claims"]["nativePhpMarkupLowering"] == "not-tested"
assert hxx_receipt["claims"]["genesBrowserLowering"] == "not-tested"

server_snapshot = json.loads(
    Path("packages/hxx/test/expected/server.json").read_text(encoding="utf-8")
)
browser_snapshot = json.loads(
    Path("packages/hxx/test/expected/browser.json").read_text(encoding="utf-8")
)
assert server_snapshot["target"] == "server"
assert browser_snapshot["target"] == "browser"
assert server_snapshot["semanticDigest"] == browser_snapshot[
    "semanticDigest"
] == prototype_evidence["sharedSemanticDigest"]
assert server_snapshot["rootSpan"] == browser_snapshot["rootSpan"]
assert server_snapshot["entries"] == browser_snapshot["entries"]
assert all(
    0
    <= entry["span"]["start"]
    < entry["span"]["end"]
    <= server_snapshot["rootSpan"]["end"]
    for entry in server_snapshot["entries"]
)

hxx_adapter = Path(prototype_evidence["adapter"]).read_text(encoding="utf-8")
assert "tink.hxx.Parser" in hxx_adapter
assert "tink.hxx.Generator" not in hxx_adapter
assert "coconut" not in hxx_adapter.lower()
for public_hxx_source in Path("packages/hxx/src/wordpress/hx/hxx/prototype").glob(
    "*.hx"
):
    assert "tink.hxx" not in public_hxx_source.read_text(encoding="utf-8")
for scoped_hxml in Path("packages/hxx/haxe_libraries").glob("*.hxml"):
    scoped_content = scoped_hxml.read_text(encoding="utf-8")
    assert "=dev" not in scoped_content
    assert "../" not in scoped_content

assert lock["schemaVersion"] == 1
assert lock["lockStatus"] == "partial"
assert receipt["schemaVersion"] == 1
assert receipt["receiptId"] in entry["testReceiptIds"]
assert entry["version"] == subject["version"] == "1.33.0"
assert entry["releaseTag"] == subject["releaseTag"] == "v1.33.0"
assert entry["commit"] == subject["commit"]
assert entry["tree"] == subject["tree"]
assert sha1.fullmatch(entry["commit"])
assert sha1.fullmatch(entry["tree"])
assert entry["releaseArtifact"]["sha256"] == subject["releaseArtifact"]["sha256"]
assert sha256.fullmatch(entry["releaseArtifact"]["sha256"])
assert receipt["localVerification"]["releaseGate"]["outcome"] == "passed"
assert receipt["changeDecision"]["genesSourceChanged"] is False
assert receipt["changeDecision"]["upstreamPullRequest"] is None

assert php_provenance["schemaVersion"] == 1
assert php_provenance["component"] == "reflaxe.php"
assert sha1.fullmatch(php_provenance["origin"]["commit"])
assert sha1.fullmatch(php_provenance["origin"]["tree"])
assert php_provenance["destination"]["releaseEligible"] is False
assert php_provenance["destination"]["repository"] == repository_receipt["repository"]["url"]
assert php_provenance["review"]["publicationAuthorized"] is False
assert haxelib["name"] == "reflaxe.php"
assert haxelib["version"] == "0.0.0"
assert haxelib["license"] == "GPL"
assert haxelib["url"] == "https://github.com/fullofcaffeine/wordpresshx"
assert php_receipt["schemaVersion"] == 1
assert php_receipt["receiptId"] == "SDK-020-REFLAXE-PHP-BOOTSTRAP"
assert php_receipt["subject"]["canonicalRepositoryUrl"] == haxelib["url"]
assert php_receipt["subject"]["repositoryUrlFollowup"] is None
assert php_receipt["subject"]["originCommit"] == php_provenance["origin"]["commit"]
assert php_receipt["subject"]["originTree"] == php_provenance["origin"]["tree"]
assert php_receipt["localVerification"]["packageTest"]["outcome"] == "passed"
assert php_receipt["localVerification"]["php84"]["runtimeOutcome"] == "passed"
assert php_receipt["localVerification"]["php74"]["outcome"] == "not-tested"
assert php_receipt["claims"]["wordpressSupport"] == "not-tested"
assert php_ir_receipt["schemaVersion"] == 1
assert php_ir_receipt["receiptId"] == "SDK-021-PHP-IR-PRINTER"
assert php_ir_receipt["bead"] == "wordpresshx-sdk-021"
assert php_ir_receipt["subject"]["package"] == haxelib["name"]
assert php_ir_receipt["subject"]["version"] == haxelib["version"]
assert php_ir_receipt["verification"]["packageTest"]["outcome"] == "passed"
assert php_ir_receipt["verification"]["exactPhpMatrix"]["php74Lint"] == "passed"
assert php_ir_receipt["verification"]["exactPhpMatrix"]["php74Runtime"] == "passed"
assert php_ir_receipt["verification"]["exactPhpMatrix"]["php84Lint"] == "passed"
assert php_ir_receipt["verification"]["exactPhpMatrix"]["php84Runtime"] == "passed"
assert php_ir_receipt["implementation"]["determinism"]["rawPhpNodeAvailable"] is False
assert php_ir_receipt["implementation"]["sourceCorrelationFoundation"]["sourceRangesImmutable"] is True
assert php_ir_receipt["boundary"]["wordpressProfileImported"] is False
assert php_ir_receipt["boundary"]["reflaxeDriverImplemented"] is False
assert php_ir_receipt["claims"]["php74"] == "runtime-tested"
assert php_ir_receipt["claims"]["php84"] == "runtime-tested"
assert any(
    continuation.get("bead") == "wordpresshx-sdk-021"
    for continuation in php_provenance["continuations"]
)

assert repository_receipt["schemaVersion"] == 1
assert repository_receipt["receiptId"] == "SDK-004-CANONICAL-REPOSITORY"
assert repository_receipt["bead"] == "wordpresshx-sdk-004"
assert repository_receipt["repository"]["nameWithOwner"] == "fullofcaffeine/wordpresshx"
assert repository_receipt["repository"]["url"] == haxelib["url"]
assert repository_receipt["repository"]["visibility"] == "public"
assert repository_receipt["repository"]["defaultBranch"] == "main"
assert sha1.fullmatch(repository_receipt["repository"]["initialPublishedCommit"])
assert repository_receipt["transport"]["gitRemote"] == "origin"
assert repository_receipt["transport"]["beadsRemote"] == "origin"
assert repository_receipt["transport"]["beadsUrl"] == "git+ssh://git@github.com/fullofcaffeine/wordpresshx.git"
assert repository_receipt["transport"]["beadsRef"] == "refs/dolt/data"
assert repository_receipt["transport"]["httpsAttempt"]["outcome"] == "failed"
assert repository_receipt["prePublicationSecurity"]["gitHistoryOutcome"] == "passed"
assert repository_receipt["prePublicationSecurity"]["decodedBeadsOutcome"] == "passed"
assert sha1.fullmatch(repository_receipt["remoteVerification"]["gitCommit"])
assert sha1.fullmatch(repository_receipt["remoteVerification"]["doltRefCommit"])
assert repository_receipt["remoteVerification"]["hostedCiOutcome"] == "passed"
assert repository_receipt["remoteVerification"]["githubSecretScanning"] == "enabled"
assert repository_receipt["remoteVerification"]["githubPushProtection"] == "enabled"
assert repository_receipt["claims"]["packagePublicationAuthorized"] is False

package_root = Path("compiler/reflaxe.php")
package_files = sorted(
    (
        path
        for path in package_root.rglob("*")
        if path.is_file() and "build" not in path.relative_to(package_root).parts
    ),
    key=lambda path: path.as_posix(),
)
package_digest_input = bytearray()
for path in package_files:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    package_digest_input.extend(f"{digest}  {path.as_posix()}\n".encode())
package_digest = hashlib.sha256(package_digest_input).hexdigest()
assert package_digest == php_ir_receipt["subject"]["packageContentSha256"]

generic_haxe_files = list((package_root / "src").rglob("*.hx")) + list(
    (package_root / "test").rglob("*.hx")
)
for path in generic_haxe_files:
    content = path.read_text(encoding="utf-8").lower()
    for forbidden in (
        "wordpress",
        "gutenberg",
        "wphx",
        "@:wp.",
        "wordpresshx-port",
        "compiler/wordpress",
    ):
        assert forbidden not in content, f"generic compiler coupling in {path}: {forbidden}"
assert "PhpRawBlock" not in "\n".join(
    path.read_text(encoding="utf-8") for path in generic_haxe_files
)

for status in (
    "inventoried",
    "typed",
    "generated",
    "runtime-tested",
    "production-supported",
    "not-tested",
    "failed",
    "not-applicable",
    "unsupported",
    "withdrawn",
):
    assert f"`{status}`" in adr

for claim_field in ("wp70-release", "gutenberg-forward-23.4", "WordPressHx"):
    assert claim_field in adr
    assert claim_field in readme

assert profile_lock["schemaVersion"] == 1
assert profile_lock["decision"] == "ADR-002"
assert profile_lock["status"] == "accepted-architecture"
assert profile_lock["claim"] == "not-tested"
assert profile_lock["catalogContractStatus"] == (
    "schema-v1-generated-catalog-v1-sdk-013"
)
assert set(profile_lock["profiles"]) == {
    "wp70-release",
    "gutenberg-forward-23.4",
}
assert profile_lock["profiles"]["wp70-release"]["catalogRevision"] == (
    "wp70-release/catalog-v1"
)
assert profile_lock["profiles"]["wp70-release"]["wordpress"]["commit"] == (
    "26b68024931348d267b70e2a29910e1320d0094f"
)
assert profile_lock["profiles"]["wp70-release"]["embeddedGutenberg"][
    "commit"
] == "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd"
assert profile_lock["profiles"]["gutenberg-forward-23.4"]["catalogRevision"] == (
    "gutenberg-forward-23.4/catalog-v1"
)
assert profile_lock["profiles"]["gutenberg-forward-23.4"]["gutenberg"][
    "commit"
] == "98a796c8780c480ef7bcfe03c42302d9564d785c"
assert profile_lock["selectionPolicy"]["profilesArePeers"] is True
assert profile_lock["selectionPolicy"]["profileInheritance"] is False
assert profile_lock["selectionPolicy"][
    "exactlyOneCompatibilityTargetPerArtifact"
] is True
assert profile_lock["selectionPolicy"]["combinedTargetAllowedDuringMvp"] is False
assert profile_lock["selectionPolicy"]["ciRequiresExplicitSelection"] is True
assert profile_lock["selectionPolicy"][
    "runtimeDetectionSatisfiesCompileTimeRequirements"
] is False
for exact_identity in (
    "wp70-release",
    "wp70-release/catalog-v1",
    "gutenberg-forward-23.4",
    "gutenberg-forward-23.4/catalog-v1",
):
    assert exact_identity in profile_adr

assert classification_lock["schemaVersion"] == 1
assert classification_lock["decision"] == "ADR-008"
assert classification_lock["status"] == "accepted-architecture"
assert classification_lock["claim"] == "not-tested"
assert classification_lock["schemaImplementationStatus"] == (
    "implemented-sdk-012"
)
assert classification_lock["generatorImplementationStatus"] == (
    "implemented-sdk-013"
)
classification_vocabulary = classification_lock["machineVocabulary"]
assert set(classification_vocabulary["apiClassifications"]) == {
    "public",
    "experimental",
    "private",
    "unsafe",
    "deprecated",
}
assert classification_vocabulary["serializedClassificationAliases"] == []
assert classification_vocabulary["evidenceStates"] == [
    "inventoried",
    "typed",
    "generated",
    "runtime-tested",
    "production-supported",
]
assert classification_vocabulary["serializedEvidenceAliases"] == []
assert set(classification_vocabulary["administrativeResults"]) == {
    "not-tested",
    "failed",
    "not-applicable",
    "unsupported",
    "withdrawn",
}
assert classification_lock["promotionPolicy"]["contiguous"] is True
assert classification_lock["promotionPolicy"][
    "attainedHistoryImmutable"
] is True
assert classification_lock["evidenceAuthority"]["precedenceModel"] == (
    "question-scoped-not-global"
)
assert classification_lock["evidenceAuthority"]["ambiguousContract"] == (
    "omit-and-report"
)
assert classification_lock["evidenceAuthority"][
    "broadDynamicFallbackAllowed"
] is False
assert classification_lock["capabilityTokenPolicy"][
    "compileTimeAvailability"
]["serializable"] is True
assert classification_lock["capabilityTokenPolicy"][
    "runtimeCapabilityResult"
]["serializableAsBuildAuthority"] is False
assert classification_lock["capabilityTokenPolicy"][
    "runtimeCapabilityResult"
]["mayChangeSelectedProfile"] is False
assert classification_lock["correctionPolicy"][
    "replacementRequiresNewCatalogDigest"
] is True
assert classification_lock["correctionPolicy"][
    "invalidatedDownstreamEvidenceMayBeCopied"
] is False
assert classification_lock["correctionPolicy"][
    "mutableLatestIsAuthority"
] is False
known_classification_fixture = classification_lock["knownInventoryFixture"]
assert known_classification_fixture["capabilityId"] == (
    "gutenberg.package.@wordpress/content-types"
)
assert known_classification_fixture["availableIn"] == [
    "gutenberg-forward-23.4"
]
assert known_classification_fixture["classification"] == "experimental"
assert known_classification_fixture["evidenceStatus"] == "inventoried"
assert known_classification_fixture["runtimeClaim"] == "not-tested"
assert known_classification_fixture["productionClaim"] == "not-tested"
for term in (
    "question-specific",
    "precise-or-omitted",
    "compile-time capability token",
    "request-scoped",
    "correctionOf",
):
    assert term in classification_adr
classification_checker_path = Path(
    "scripts/profiles/check-classification-decision.py"
)
compile(
    classification_checker_path.read_text(encoding="utf-8"),
    classification_checker_path.as_posix(),
    "exec",
)

wp_entry = lock["entries"]["wp70-release"]
wp_profile = profile_lock["profiles"]["wp70-release"]
assert wp_source_lock["schemaVersion"] == 1
assert wp_source_lock["profileId"] == wp_entry["profileId"] == "wp70-release"
assert wp_source_lock["catalogRevision"] == wp_entry["catalogRevision"] == (
    wp_profile["catalogRevision"]
)
assert wp_source_lock["sourceVerificationStatus"] == "passed"
assert wp_source_lock["capabilityEvidenceStatus"] == "inventoried"
assert wp_source_lock["runtimeCompatibilityStatus"] == "not-tested"
assert wp_source_lock["productionSupportStatus"] == "not-tested"
assert wp_entry["sourceLock"]["path"] == wp_source_lock_path.as_posix()
assert hashlib.sha256(wp_source_lock_path.read_bytes()).hexdigest() == (
    wp_entry["sourceLock"]["sha256"]
)
assert (
    wp_source_lock["wordpressSource"]["commit"]
    == wp_entry["wordpressSource"]["commit"]
    == wp_profile["wordpress"]["commit"]
)
assert wp_source_lock["wordpressSource"]["tree"] == (
    wp_entry["wordpressSource"]["tree"]
)
assert (
    wp_source_lock["embeddedGutenberg"]["commit"]
    == wp_entry["embeddedGutenberg"]["commit"]
    == wp_profile["embeddedGutenberg"]["commit"]
)
assert wp_source_lock["embeddedGutenberg"]["tree"] == (
    wp_entry["embeddedGutenberg"]["tree"]
)
assert wp_source_lock["distribution"]["contentTreeSha256"] == (
    wp_entry["distributionContentTreeSha256"]
)
assert wp_receipt["schemaVersion"] == 1
assert wp_receipt["receiptId"] == "SDK-010-WP70-RELEASE-SOURCE"
assert wp_receipt["receiptId"] in wp_entry["testReceiptIds"]
assert wp_receipt["bead"] == "wordpresshx-sdk-010"
assert wp_receipt["subject"]["sourceLockSha256"] == (
    wp_entry["sourceLock"]["sha256"]
)
verifier_path = Path(wp_receipt["subject"]["verifierPath"])
assert hashlib.sha256(verifier_path.read_bytes()).hexdigest() == (
    wp_receipt["subject"]["verifierSha256"]
)
compile(verifier_path.read_text(encoding="utf-8"), verifier_path.as_posix(), "exec")
assert wp_receipt["sourceVerification"]["wordpress"]["outcome"] == "passed"
assert wp_receipt["sourceVerification"]["committerDateComparison"] == (
    "parsed ISO-8601 instant normalized to UTC"
)
assert wp_receipt["sourceVerification"]["embeddedGutenberg"]["outcome"] == (
    "passed"
)
assert wp_receipt["distributionVerification"]["outcome"] == "passed"
assert wp_receipt["distributionVerification"][
    "tarZipFileTreesByteIdentical"
] is True
assert wp_receipt["distributionVerification"]["contentTreeSha256"] == (
    wp_source_lock["distribution"]["contentTreeSha256"]
)
assert wp_receipt["hostedWorkflow"]["job"] == "wp70-source"
assert wp_receipt["hostedWorkflow"]["freshSourceFetch"] is True
assert wp_receipt["hostedWorkflow"]["freshArtifactDownload"] is True
assert wp_receipt["hostedWorkflow"]["required"] is True
assert wp_receipt["claims"]["sourceAndDistributionIdentity"] == "inventoried"
for unproven_claim in (
    "capabilityCatalog",
    "wordpressInstallation",
    "wordpressRuntimeCompatibility",
    "browserCompatibility",
    "productionSupport",
):
    assert wp_receipt["claims"][unproven_claim] == "not-tested"

forward_entry = lock["entries"]["gutenberg-forward-23.4"]
forward_profile = profile_lock["profiles"]["gutenberg-forward-23.4"]
assert forward_source_lock["schemaVersion"] == 1
assert forward_source_lock["profileId"] == forward_entry["profileId"] == (
    "gutenberg-forward-23.4"
)
assert forward_source_lock["catalogRevision"] == forward_entry[
    "catalogRevision"
] == forward_profile["catalogRevision"]
for identity_field in (
    "packageIdentity",
    "generatedNamespace",
    "generatedArtifactRoot",
):
    assert forward_source_lock[identity_field] == forward_entry[identity_field]
assert forward_source_lock["sourceVerificationStatus"] == "passed"
assert forward_source_lock["capabilityEvidenceStatus"] == "inventoried"
assert forward_source_lock["runtimeCompatibilityStatus"] == "not-tested"
assert forward_source_lock["wordpress70CompatibilityStatus"] == "forbidden"
assert forward_source_lock["productionSupportStatus"] == "not-tested"
assert forward_source_lock["supportStatus"] == "experimental"
assert forward_source_lock["releaseChannel"] == "preview-or-experimental"
assert forward_source_lock["prohibitions"]["distributionClaim"] is None
assert forward_source_lock["prohibitions"][
    "wordpress70CompatibilityClaim"
] == "forbidden"
assert forward_source_lock["prohibitions"]["mixedProfileImports"] == (
    "forbidden"
)
assert forward_source_lock["prohibitions"]["wp70ArtifactLeakage"] == (
    "forbidden"
)
assert forward_entry["sourceLock"]["path"] == (
    forward_source_lock_path.as_posix()
)
assert hashlib.sha256(forward_source_lock_path.read_bytes()).hexdigest() == (
    forward_entry["sourceLock"]["sha256"]
)
assert forward_source_lock["gutenbergSource"]["commit"] == forward_entry[
    "gutenbergSource"
]["commit"] == forward_profile["gutenberg"]["commit"]
assert forward_source_lock["gutenbergSource"]["tree"] == forward_entry[
    "gutenbergSource"
]["tree"]
assert forward_source_lock["gutenbergSource"]["tag"] == forward_entry[
    "gutenbergSource"
]["tag"] == forward_profile["gutenberg"]["tag"]
assert forward_source_lock["gutenbergSource"]["tagKind"] == "lightweight"
assert forward_source_lock["gutenbergSource"]["tagObjectType"] == "commit"
assert forward_source_lock["releaseDistribution"]["artifact"]["sha256"] == (
    forward_entry["releaseArtifact"]["sha256"]
)
assert forward_source_lock["releaseDistribution"][
    "contentTreeSha256"
] == forward_entry["distributionContentTreeSha256"]
assert forward_receipt["schemaVersion"] == 1
assert forward_receipt["receiptId"] == (
    "SDK-011-GUTENBERG-FORWARD-23.4"
)
assert forward_receipt["receiptId"] in forward_entry["testReceiptIds"]
assert forward_receipt["bead"] == "wordpresshx-sdk-011"
assert forward_receipt["subject"]["sourceLockSha256"] == forward_entry[
    "sourceLock"
]["sha256"]
for receipt_path_field, receipt_sha_field in (
    ("verifierPath", "verifierSha256"),
    ("isolationVerifierPath", "isolationVerifierSha256"),
):
    receipt_path = Path(forward_receipt["subject"][receipt_path_field])
    assert hashlib.sha256(receipt_path.read_bytes()).hexdigest() == (
        forward_receipt["subject"][receipt_sha_field]
    )
    compile(
        receipt_path.read_text(encoding="utf-8"),
        receipt_path.as_posix(),
        "exec",
    )
assert forward_receipt["sourceVerification"]["gutenberg"]["outcome"] == (
    "passed"
)
assert forward_receipt["sourceVerification"][
    "committerDateComparison"
] == "parsed ISO-8601 instant normalized to UTC"
assert forward_receipt["releaseVerification"]["outcome"] == "passed"
assert forward_receipt["releaseVerification"]["contentTreeSha256"] == (
    forward_source_lock["releaseDistribution"]["contentTreeSha256"]
)
assert forward_receipt["isolationVerification"]["outcome"] == "passed"
assert forward_receipt["hostedWorkflow"]["job"] == (
    "gutenberg-forward-source"
)
assert forward_receipt["hostedWorkflow"]["freshSourceFetch"] is True
assert forward_receipt["hostedWorkflow"]["freshArtifactDownload"] is True
assert forward_receipt["hostedWorkflow"]["required"] is True
assert forward_receipt["claims"]["sourceAndReleaseIdentity"] == (
    "inventoried"
)
assert forward_receipt["claims"]["forwardCapabilityInventory"] == (
    "inventoried"
)
assert forward_receipt["claims"]["forwardSupport"] == "experimental"
assert forward_receipt["claims"]["releaseChannel"] == (
    "preview-or-experimental"
)
assert forward_receipt["claims"]["wordpress70Compatibility"] == (
    "forbidden"
)
for unproven_claim in (
    "wordpressInstallation",
    "wordpressRuntimeCompatibility",
    "browserCompatibility",
    "productionSupport",
):
    assert forward_receipt["claims"][unproven_claim] == "not-tested"

assert profile_schema["$schema"] == (
    "https://json-schema.org/draft/2020-12/schema"
)
assert profile_schema["properties"]["schemaVersion"]["const"] == 1
schema_classifications = profile_schema["$defs"]["capability"][
    "properties"
]["classification"]["enum"]
schema_evidence_states = profile_schema["$defs"]["capability"][
    "properties"
]["evidenceStatus"]["enum"]
schema_administrative_results = profile_schema["$defs"][
    "administrativeResult"
]["properties"]["result"]["enum"]
assert schema_classifications == list(
    classification_lock["machineVocabulary"]["apiClassifications"]
)
assert schema_evidence_states == classification_lock["machineVocabulary"][
    "evidenceStates"
]
assert schema_administrative_results == classification_lock[
    "machineVocabulary"
]["administrativeResults"]

assert sdk012_receipt["schemaVersion"] == 1
assert sdk012_receipt["receiptId"] == "SDK-012-PROFILE-SCHEMA"
assert sdk012_receipt["bead"] == "wordpresshx-sdk-012"
sdk012_subject = sdk012_receipt["subject"]
assert sdk012_subject["profileSchemaPath"] == profile_schema_path.as_posix()
assert sdk012_subject["profileSchemaVersion"] == 1
assert hashlib.sha256(profile_schema_path.read_bytes()).hexdigest() == (
    sdk012_subject["profileSchemaSha256"]
)
assert hashlib.sha256(classification_lock_path.read_bytes()).hexdigest() == (
    sdk012_subject["classificationDecisionLockSha256"]
)
profile_lock_path = Path("profiles/decision-lock.json")
assert hashlib.sha256(profile_lock_path.read_bytes()).hexdigest() == (
    sdk012_subject["profileDecisionLockSha256"]
)
for path_field, digest_field in (
    ("validatorPath", "validatorSha256"),
    ("scriptPath", "scriptSha256"),
):
    section = (
        sdk012_receipt["schemaValidation"]
        if path_field == "validatorPath"
        else sdk012_receipt["haxeValidation"]
    )
    evidence_path = Path(section[path_field])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == section[
        digest_field
    ]
    if evidence_path.suffix == ".py":
        compile(
            evidence_path.read_text(encoding="utf-8"),
            evidence_path.as_posix(),
            "exec",
        )

core_root = Path(sdk012_subject["haxeContractRoot"])
core_files = sorted(
    (path for path in core_root.rglob("*") if path.is_file()),
    key=lambda path: path.as_posix(),
)
core_digest_input = bytearray()
for path in core_files:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    core_digest_input.extend(f"{digest}  {path.as_posix()}\n".encode())
assert len(core_files) == sdk012_subject["haxeContractFileCount"] == 20
assert hashlib.sha256(core_digest_input).hexdigest() == sdk012_subject[
    "haxeContractContentSha256"
]
assert not (core_root / "haxelib.json").exists()

fixture_by_profile = {
    fixture["profileId"]: fixture
    for fixture in sdk012_receipt["exactFixtures"]
}
assert set(fixture_by_profile) == {
    "wp70-release",
    "gutenberg-forward-23.4",
}
for profile_id, receipt_fixture in fixture_by_profile.items():
    fixture_path = Path(receipt_fixture["path"])
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    assert hashlib.sha256(fixture_path.read_bytes()).hexdigest() == (
        receipt_fixture["fileSha256"]
    )
    assert fixture["schemaVersion"] == 1
    assert fixture["catalog"]["profileId"] == profile_id
    assert fixture["catalog"]["catalogRevision"] == receipt_fixture[
        "catalogRevision"
    ]
    assert fixture["catalogDigest"] == receipt_fixture["catalogDigest"]
    assert fixture["generator"]["sourceDigest"] == sdk012_subject[
        "profileSchemaSha256"
    ]
    assert receipt_fixture["capabilityEvidence"] == "inventoried"
    assert receipt_fixture["outcome"] == "passed"

assert sdk012_receipt["schemaValidation"]["validFixtureCount"] == 2
assert sdk012_receipt["schemaValidation"]["negativeFixtureCount"] == 9
assert sdk012_receipt["schemaValidation"]["outcome"] == "passed"
assert sdk012_receipt["haxeValidation"]["haxeVersion"] == "4.3.7"
assert sdk012_receipt["haxeValidation"]["formattedHaxeFileCount"] == 18
assert sdk012_receipt["haxeValidation"]["outcome"] == "passed"
assert sdk012_receipt["capabilityAuthority"]["compileTimeAvailability"][
    "serializableManifestValue"
] is True
runtime_authority = sdk012_receipt["capabilityAuthority"][
    "runtimeCapability"
]
assert runtime_authority["requestScoped"] is True
assert runtime_authority["assignableToCompileTimeAuthority"] is False
assert runtime_authority["presentInProfileJsonSchema"] is False
assert sdk012_receipt["boundary"]["haxelibPublicationAuthorized"] is False
assert sdk012_receipt["boundary"]["catalogGeneratorImplemented"] is False
assert sdk012_receipt["claims"]["profileSchema"] == "generated"
assert sdk012_receipt["claims"]["haxeProfileContract"] == (
    "runtime-tested"
)
assert sdk012_receipt["claims"]["wp70CapabilityCatalog"] == "inventoried"
assert sdk012_receipt["claims"]["forwardCapabilityCatalog"] == (
    "inventoried"
)
for unproven_claim in (
    "wordpressRuntimeCompatibility",
    "browserCompatibility",
    "productionSupport",
):
    assert sdk012_receipt["claims"][unproven_claim] == "not-tested"

assert sdk013_receipt["schemaVersion"] == 1
assert sdk013_receipt["receiptId"] == "SDK-013-PROFILE-GENERATOR"
assert sdk013_receipt["bead"] == "wordpresshx-sdk-013"
sdk013_subject = sdk013_receipt["subject"]
for path_field, digest_field in (
    ("generatorPath", "generatorSha256"),
    ("checkerPath", "checkerSha256"),
    ("testPath", "testSha256"),
    ("selectionPath", "selectionSha256"),
    ("profileSchemaPath", "profileSchemaSha256"),
):
    evidence_path = Path(sdk013_subject[path_field])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == (
        sdk013_subject[digest_field]
    )
assert sdk013_subject["generatorIdentity"] == (
    "wordpresshx-exact-profile-generator"
)
assert sdk013_subject["generatorVersion"] == "1"
assert sdk013_receipt["generation"]["sourceReadMode"] == (
    "git-show-exact-commit-and-path"
)
assert sdk013_receipt["generation"]["upstreamApplicationCodeExecuted"] is False
assert sdk013_receipt["generation"]["doubleRunByteEquality"] == "passed"
assert sdk013_receipt["generation"]["committedTreeEquality"] == "passed"
assert sdk013_receipt["generation"]["failedGenerationPublishesNothing"] is True
assert sdk013_receipt["generation"]["outcome"] == "passed"
sdk013_profiles = {
    profile["profileId"]: profile for profile in sdk013_receipt["profiles"]
}
assert set(sdk013_profiles) == {
    "wp70-release",
    "gutenberg-forward-23.4",
}
assert sdk013_profiles["wp70-release"]["catalog"]["capabilityCount"] == 28
assert sdk013_profiles["gutenberg-forward-23.4"]["catalog"][
    "capabilityCount"
] == 5
assert sdk013_profiles["gutenberg-forward-23.4"][
    "wordpress70Compatibility"
] == "forbidden"
for profile in sdk013_profiles.values():
    for section_name in ("catalog", "omissions", "generationReport"):
        section = profile[section_name]
        path = Path(section["path"])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == section[
            "fileSha256"
        ]
    assert profile["catalog"]["evidenceStatus"] == "inventoried"
    assert profile["omissions"]["omissionCount"] == 2
assert sdk013_receipt["negativeEvidence"]["wrongRepositoryMissingExactCommit"] == (
    "rejected"
)
assert sdk013_receipt["negativeEvidence"]["partialOutputAfterFailure"] == (
    "absent"
)
assert sdk013_receipt["negativeEvidence"]["dynamicHookGuessed"] is False
assert sdk013_receipt["negativeEvidence"]["privateApiPublished"] is False
assert sdk013_receipt["negativeEvidence"]["contentTypesLeakedIntoWp70"] is False
assert sdk013_receipt["hostedWorkflow"]["job"] == "profile-generator"
assert sdk013_receipt["hostedWorkflow"]["required"] is True
assert sdk013_receipt["claims"]["generatorImplementation"] == "generated"
assert sdk013_receipt["claims"]["wp70CapabilityCatalog"] == "inventoried"
assert sdk013_receipt["claims"]["forwardCapabilityCatalog"] == "inventoried"
for unproven_claim in (
    "typedContracts",
    "wordpressRuntimeCompatibility",
    "browserCompatibility",
    "packageCompatibility",
    "productionSupport",
):
    assert sdk013_receipt["claims"][unproven_claim] == "not-tested"

assert image_lock["schemaVersion"] == 1
assert set(image_lock["images"]) == {
    "mariadb",
    "mysql",
    "node",
    "php74Floor",
    "php84Cli",
    "playwright",
    "wordpress70Php84",
}
for image_key in (
    "mariadb",
    "mysql",
    "php74Floor",
    "php84Cli",
    "wordpress70Php84",
):
    assert image_lock["images"][image_key]["evidenceStatus"] == (
        "runtime-tested"
    )
for image_key in ("node", "playwright"):
    assert image_lock["images"][image_key]["evidenceStatus"] == (
        "inventoried"
    )

assert sdk090_receipt["schemaVersion"] == 1
assert sdk090_receipt["receiptId"] == "SDK-090-WORDPRESS-HARNESS"
assert sdk090_receipt["bead"] == "wordpresshx-sdk-090"
sdk090_subject = sdk090_receipt["subject"]
for path_field, digest_field in (
    ("imageLockPath", "imageLockSha256"),
    ("composePath", "composeSha256"),
    ("installPath", "installSha256"),
    ("healthPath", "healthSha256"),
    ("lockCheckerPath", "lockCheckerSha256"),
    ("distributionVerifierPath", "distributionVerifierSha256"),
    ("resetPath", "resetSha256"),
    ("runnerPath", "runnerSha256"),
    ("matrixPath", "matrixSha256"),
):
    evidence_path = Path(sdk090_subject[path_field])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == (
        sdk090_subject[digest_field]
    )

wordpress_image = image_lock["images"]["wordpress70Php84"]
distribution_evidence = sdk090_receipt["wordpressDistribution"]
assert distribution_evidence["imageReference"] == wordpress_image["reference"]
assert distribution_evidence["wordpressVersion"] == "7.0"
assert distribution_evidence["phpVersion"] == "8.4.23"
assert distribution_evidence["officialFileCount"] == (
    wp_source_lock["distribution"]["contentFileCount"]
)
assert distribution_evidence["officialTreeSha256"] == (
    wp_source_lock["distribution"]["contentTreeSha256"]
)
assert distribution_evidence["allowedImageExtras"] == (
    wordpress_image["distribution"]["allowedImageExtras"]
)
assert distribution_evidence["containerNetwork"] == "none"
assert distribution_evidence["outcome"] == "passed"

runtime_evidence = sdk090_receipt["runtimeMatrix"]
assert runtime_evidence["wordpressImageReference"] == wordpress_image[
    "reference"
]
assert runtime_evidence["sdkSourceMounted"] is False
assert runtime_evidence["outcome"] == "passed"
runtime_lanes = {lane["database"]: lane for lane in runtime_evidence["lanes"]}
assert set(runtime_lanes) == {"mysql", "mariadb"}
for lane_name, expected_version in (
    ("mysql", "8.4.10"),
    ("mariadb", "11.4.5-MariaDB-ubu2404"),
):
    lane = runtime_lanes[lane_name]
    assert lane["imageReference"] == image_lock["images"][lane_name][
        "reference"
    ]
    assert lane["serverVersion"] == expected_version
    for check in (
        "freshInstall",
        "databaseQuery",
        "httpFrontend",
        "volumeResetBeforeAndAfter",
    ):
        assert lane[check] == "passed"

assert sdk090_receipt["matrixBoundaries"]["node22170"] == "inventoried"
assert sdk090_receipt["matrixBoundaries"]["playwright1580"] == "inventoried"
assert sdk090_receipt["matrixBoundaries"]["sdkPluginOrThemeInstalled"] is False
assert sdk090_receipt["hostedWorkflow"]["job"] == "wordpress-runtime"
assert sdk090_receipt["hostedWorkflow"]["runId"] == 29605790579
assert sdk090_receipt["hostedWorkflow"]["jobId"] == 87968572776
assert sha1.fullmatch(sdk090_receipt["hostedWorkflow"]["commit"])
assert sdk090_receipt["hostedWorkflow"]["status"] == "passed"
assert sdk090_receipt["hostedWorkflow"]["required"] is True
for claim in (
    "exactWordPressImageDistribution",
    "vanillaWordPressInstallation",
    "mysqlLane",
    "mariadbLane",
):
    assert sdk090_receipt["claims"][claim] == "runtime-tested"
for claim in (
    "sdkRuntimeCompatibility",
    "browserCompatibility",
    "pluginOrThemePackageCompatibility",
    "productionSupport",
):
    assert sdk090_receipt["claims"][claim] == "not-tested"
PY

python3 scripts/profiles/check-decision-lock.py
python3 scripts/profiles/check-classification-decision.py
python3 scripts/profiles/check-profile-isolation.py
python3 scripts/profiles/validate-profile-schema.py
python3 scripts/profiles/check-generated-catalogs.py
python3 scripts/docker/check-image-lock.py

forbidden_dependency_pattern='\.\./wordpresshx-port|wordpresshx-port/(src|compiler|packages)|haxelib[[:space:]]+dev[^[:cntrl:]]*wordpresshx-port'
scan_output="$(mktemp)"
trap 'rm -f "${scan_output}"' EXIT
if git grep -nE "${forbidden_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!docs/**' ':!wordpress-hx-sdk-product-requirements.md' \
  > "${scan_output}" 2>/dev/null; then
  echo "direct dependency on wordpresshx-port internals detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

floating_genes_dependency_pattern='(file:|link:)[^[:cntrl:]]*\.\./genes|haxelib[[:space:]]+dev[[:space:]]+genes([^[:alnum:]_.-]|$)|(^|[[:space:]])-cp[[:space:]]+\.\./genes([^[:alnum:]_.-]|$)'
if git grep -nE "${floating_genes_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!manifests/evidence/**' \
  > "${scan_output}" 2>/dev/null; then
  echo "floating dependency on the sibling genes checkout detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

floating_reflaxe_dependency_pattern='haxelib[[:space:]]+dev[[:space:]]+reflaxe([^[:alnum:]_.-]|$)|(^|[[:space:]])-cp[[:space:]]+\.\./haxe\.compilerdev\.reference/reflaxe([^[:alnum:]_.-]|$)'
if git grep -nE "${floating_reflaxe_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!manifests/evidence/**' ':!compiler/reflaxe.php/provenance.json' \
  > "${scan_output}" 2>/dev/null; then
  echo "floating dependency on a sibling Reflaxe checkout detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

git diff --check HEAD

bash scripts/ci/check-security-tooling.sh

echo "repository bootstrap checks passed"
