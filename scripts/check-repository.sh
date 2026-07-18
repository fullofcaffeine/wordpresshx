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
  LICENSES/policy.json
  LICENSES/components.json
  LICENSES/GENERATED_OUTPUT.md
  LICENSES/THIRD_PARTY_NOTICES.md
  LICENSES/QUALIFIED_REVIEW.md
  wordpress-hx-sdk-product-requirements.md
  docs/README.md
  docs/adr/README.md
  docs/adr/001-product-and-repository-boundary.md
  docs/adr/002-exact-compatibility-profiles.md
  docs/adr/003-package-topology-and-lockstep-versioning.md
  docs/adr/004-generic-php-compiler-home.md
  docs/adr/005-public-versus-private-php-emission.md
  docs/adr/008-profile-generation-and-api-classification.md
  docs/adr/011-hxx-parser-and-lowering-architecture.md
  docs/adr/013-genes-ts-output-and-wordpress-build-integration.md
  docs/adr/014-source-maps-and-php-trace-correlation.md
  docs/adr/020-licensing-and-generated-output.md
  docs/adr/021-release-and-support-policy.md
  docs/gates/README.md
  docs/gates/g0-product-authority-and-baseline.md
  docs/architecture/browser-compiler.md
  docs/architecture/haxe-first-site-authoring.md
  docs/architecture/php-compiler.md
  docs/architecture/repository-layout.md
  docs/product/README.md
  docs/release/README.md
  docs/release/release-checklist.md
  docs/release/rollback-checklist.md
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
  packages/hxx/scripts/hash-generated-php.py
  packages/hxx/scripts/test.sh
  packages/hxx/scripts/verify-dependency-lock.py
  packages/hxx/scripts/verify-snapshots.py
  packages/hxx/src/wordpress/hx/hxx/_internal/HxxParserAdapter.hx
  packages/hxx/src/wordpress/hx/hxx/_internal/HxxSyntax.hx
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
  packages/gutenberg/.haxerc
  packages/gutenberg/README.md
  packages/gutenberg/dependency-lock.json
  packages/gutenberg/haxe_libraries/genes-ts.hxml
  packages/gutenberg/haxe_libraries/html-entities.hxml
  packages/gutenberg/haxe_libraries/helder.set.hxml
  packages/gutenberg/haxe_libraries/tink_anon.hxml
  packages/gutenberg/haxe_libraries/tink_core.hxml
  packages/gutenberg/haxe_libraries/tink_hxx.hxml
  packages/gutenberg/haxe_libraries/tink_macro.hxml
  packages/gutenberg/haxe_libraries/tink_parse.hxml
  packages/gutenberg/hxx-tooling/package-lock.json
  packages/gutenberg/hxx-tooling/package.json
  packages/gutenberg/build-tooling/package-lock.json
  packages/gutenberg/build-tooling/package.json
  packages/gutenberg/build-tooling/webpack.config.cjs
  packages/gutenberg/profiles/assets-strict.hxml
  packages/gutenberg/profiles/classic.hxml
  packages/gutenberg/profiles/default-dce.hxml
  packages/gutenberg/profiles/hxx-common.hxml
  packages/gutenberg/profiles/hxx-strict.hxml
  packages/gutenberg/profiles/strict.hxml
  packages/gutenberg/scripts/test-hxx.sh
  packages/gutenberg/scripts/test-assets.sh
  packages/gutenberg/scripts/test.sh
  packages/gutenberg/scripts/emit-assets-plugin.py
  packages/gutenberg/scripts/run-wordpress-assets-lane.sh
  packages/gutenberg/scripts/verify-assets-profile.py
  packages/gutenberg/scripts/verify-assets.mjs
  packages/gutenberg/scripts/verify-browser-profile.mjs
  packages/gutenberg/scripts/verify-dependency-lock.py
  packages/gutenberg/scripts/verify-hxx-profile.py
  packages/gutenberg/scripts/verify-hxx.mjs
  packages/gutenberg/src/wordpress/hx/gutenberg/browser/BrowserExport.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/browser/BrowserNode.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/Button.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/ButtonProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/Notice.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/NoticeProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/html/HtmlProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/hxx/BrowserHxx.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/hxx/_internal/BrowserHxxLowerer.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/hxx/_internal/BrowserHxxProfile.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/i18n/I18n.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/profile/wp70-release.browser-assets.json
  packages/gutenberg/src/wordpress/hx/gutenberg/profile/wp70-release.browser-hxx.json
  packages/gutenberg/src/wordpress/hx/gutenberg/react/DomTypes.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/react/Hooks.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/react/ReactTypes.hx
  packages/gutenberg/test-negative/invalid_capability/Main.hx
  packages/gutenberg/test-negative/invalid_export_id/Main.hx
  packages/gutenberg/test-negative-hxx/missing_notice_children/Main.hx
  packages/gutenberg/test-negative-hxx/open_spread/Main.hx
  packages/gutenberg/test-negative-hxx/unknown_prop/Main.hx
  packages/gutenberg/test-negative-hxx/unsupported_switch/Main.hx
  packages/gutenberg/test-negative-hxx/wrong_event/Main.hx
  packages/gutenberg/test-negative-hxx/wrong_ref/Main.hx
  packages/gutenberg/test/consumer/consumer.ts
  packages/gutenberg/test/consumer/ordinary-consumer.mjs
  packages/gutenberg/test/expected/browser-profile.json
  packages/gutenberg/test/fixture/src/sdk031/fixture/BrowserApi.hx
  packages/gutenberg/test/fixture/src/sdk031/fixture/Main.hx
  packages/gutenberg/test/fixture/src/sdk031/fixture/RuntimeSignals.hx
  packages/gutenberg/test/hxx-fixture/src/sdk032/fixture/Main.hx
  packages/gutenberg/test/hxx-fixture/src/sdk032/fixture/ProofStyles.hx
  packages/gutenberg/test/hxx-runtime/index.html
  packages/gutenberg/test/hxx-runtime/runtime-entry.tsx
  packages/gutenberg/test/hxx-runtime/visual-entry.tsx
  packages/gutenberg/test/assets-fixture/src/sdk033/fixture/EditorPanel.hx
  packages/gutenberg/test/assets-fixture/src/sdk033/fixture/Main.hx
  packages/gutenberg/test/assets-runtime/editor-entry.tsx
  packages/gutenberg/test/assets-runtime/entry-plan.json
  packages/gutenberg/test/assets-runtime/probe-assets.php
  packages/gutenberg/test/runtime/setup.d.ts
  packages/gutenberg/test/runtime/setup.js
  packages/gutenberg/test/runtime/signals.d.ts
  packages/gutenberg/test/runtime/signals.js
  packages/gutenberg/tooling/package-lock.json
  packages/gutenberg/tooling/package.json
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
  schemas/profile-diff.schema.json
  schemas/php-haxe-map.schema.json
  schemas/source-correlation-index.schema.json
  scripts/source-correlation/validate-contracts.py
  tools/README.md
  examples/README.md
  fixtures/README.md
  fixtures/profiles/README.md
  fixtures/profiles/valid/gutenberg-forward-23.4.json
  fixtures/profiles/valid/wp70-release.json
  fixtures/profile-diffs/README.md
  fixtures/profile-diffs/expected/correction.json
  fixtures/profile-diffs/expected/correction.txt
  fixtures/profile-diffs/expected/upstream.json
  fixtures/profile-diffs/expected/upstream.txt
  fixtures/release-governance/README.md
  fixtures/release-governance/scenarios.json
  fixtures/release-governance/expected/rehearsal.json
  fixtures/licenses/README.md
  fixtures/licenses/expected/publication-blocked.txt
  fixtures/source-correlation/README.md
  fixtures/source-correlation/source-index.valid.json
  fixtures/source-correlation/source/project/src/fixture/Failure.hx
  fixtures/source-correlation/artifacts/plugin/includes/failure.php
  fixtures/source-correlation/artifacts/plugin/includes/failure.php.haxe-map.json
  fixtures/source-correlation/artifacts/browser/composed.js
  fixtures/source-correlation/artifacts/browser/composed.js.map
  fixtures/source-correlation/artifacts/browser/two-stage.js
  fixtures/source-correlation/artifacts/browser/two-stage.js.map
  fixtures/source-correlation/artifacts/browser/two-stage.ts
  fixtures/source-correlation/artifacts/browser/two-stage.ts.map
  test/README.md
  docker/README.md
  docker/images.lock.json
  docker/wordpress/compose.yml
  docker/wordpress/health.php
  docker/wordpress/install.php
  manifests/README.md
  manifests/browser-build-architecture.json
  manifests/hxx-architecture.json
  manifests/source-correlation-architecture.json
  manifests/package-topology.json
  manifests/php-emission-policy.json
  manifests/release-support-policy.json
  manifests/toolchain.lock.json
  manifests/upstream.lock.json
  manifests/evidence/g0-product-baseline.json
  manifests/evidence/sdk-003-release-governance.json
  manifests/evidence/adr-020-license-audit-preparation.json
  manifests/evidence/ci-checkout-node24.json
  manifests/evidence/sdk-004-canonical-repository.json
  manifests/evidence/sdk-010-wp70-release.json
  manifests/evidence/sdk-011-gutenberg-forward-23.4.json
  manifests/evidence/sdk-012-profile-schema.json
  manifests/evidence/sdk-013-profile-generator.json
  manifests/evidence/sdk-014-profile-diff.json
  manifests/evidence/sdk-090-wordpress-harness.json
  manifests/evidence/sdk-030-genes-ts-v1.33.0.json
  manifests/evidence/sdk-031-strict-browser-profile.json
  manifests/evidence/sdk-032-react-gutenberg-hxx.json
  manifests/evidence/sdk-033-wordpress-asset-metadata.json
  manifests/evidence/sdk-020-reflaxe-php-bootstrap.json
  manifests/evidence/sdk-021-php-ir-printer.json
  manifests/evidence/sdk-022-wordpress-public-php-profile.json
  manifests/evidence/sdk-023-wordpress-public-php-adapters.json
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
  compiler/wordpress/README.md
  compiler/wordpress/runtime/activate-plugin.php
  compiler/wordpress/runtime/native-adapter-caller.php
  compiler/wordpress/runtime/native-caller.php
  compiler/wordpress/runtime/probe-adapters.php
  compiler/wordpress/runtime/probe-plugin.php
  compiler/wordpress/scripts/run-wordpress-lane.sh
  compiler/wordpress/scripts/test-php-matrix.sh
  compiler/wordpress/scripts/test-wordpress.sh
  compiler/wordpress/scripts/test.sh
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/PluginBootstrapPlan.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/PluginHeader.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressBlockRegistration.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressHookKind.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressHookRegistration.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPhpPrinter.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPluginArtifact.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPluginFile.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPublicAdapterArtifact.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPublicAdapterFile.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPublicAdapterPlan.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPublicExport.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressRestMethod.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressRestRouteRegistration.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/Wp70PhpProfile.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/Wp70PublicAdapterProfile.hx
  compiler/wordpress/test.hxml
  compiler/wordpress/test/expected/acme-books-adapters/acme-books-adapters.php.txt
  compiler/wordpress/test/expected/acme-books-adapters/includes/Bootstrap.php.txt
  compiler/wordpress/test/expected/acme-books-adapters/includes/PublicAdapters.php.txt
  compiler/wordpress/test/expected/acme-books-adapters/includes/autoload.php.txt
  compiler/wordpress/test/expected/acme-books-adapters/includes/register-adapters.php.txt
  compiler/wordpress/test/expected/acme-books-adapters/wordpresshx-public-php-adapters.v1.json
  compiler/wordpress/test/expected/acme-books/acme-books.php.txt
  compiler/wordpress/test/expected/acme-books/includes/Bootstrap.php.txt
  compiler/wordpress/test/expected/acme-books/includes/autoload.php.txt
  compiler/wordpress/test/expected/acme-books/wordpresshx-public-php-artifact.v1.json
  compiler/wordpress/test/fixtures/AcmeBooksAdapters.hx
  compiler/wordpress/test/fixtures/AcmeBooksPlugin.hx
  compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/WordPressPhpProfileTest.hx
  compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/WordPressPublicAdapterTest.hx
  scripts/beads/push-safe.sh
  scripts/gates/check-g0-baseline.py
  scripts/gates/test-g0-baseline.py
  scripts/ci/check-checkout-action.py
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
  scripts/profiles/diff-catalogs.py
  scripts/profiles/generate-catalogs.py
  scripts/profiles/test-catalog-generator.sh
  scripts/profiles/test-profile-diff.py
  scripts/profiles/test-profile-haxe.sh
  scripts/profiles/validate-profile-schema.py
  scripts/release/test-governance.py
  scripts/licenses/check-license-policy.py
  scripts/licenses/test-license-policy.py
  scripts/php/check-emission-policy.py
  scripts/php/test-emission-policy.py
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
import subprocess
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
wordpress_php_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-022-wordpress-public-php-profile.json"
    ).read_text(encoding="utf-8")
)
wordpress_adapter_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-023-wordpress-public-php-adapters.json"
    ).read_text(encoding="utf-8")
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
profile_diff_schema_path = Path("schemas/profile-diff.schema.json")
profile_diff_schema = json.loads(
    profile_diff_schema_path.read_text(encoding="utf-8")
)
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
sdk014_receipt = json.loads(
    Path("manifests/evidence/sdk-014-profile-diff.json").read_text(
        encoding="utf-8"
    )
)
release_policy_path = Path("manifests/release-support-policy.json")
release_policy = json.loads(
    release_policy_path.read_text(encoding="utf-8")
)
sdk003_receipt = json.loads(
    Path("manifests/evidence/sdk-003-release-governance.json").read_text(
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
browser_architecture = json.loads(
    Path("manifests/browser-build-architecture.json").read_text(
        encoding="utf-8"
    )
)
source_correlation_architecture = json.loads(
    Path("manifests/source-correlation-architecture.json").read_text(
        encoding="utf-8"
    )
)
gutenberg_dependency_lock_path = Path("packages/gutenberg/dependency-lock.json")
gutenberg_dependency_lock = json.loads(
    gutenberg_dependency_lock_path.read_text(encoding="utf-8")
)
gutenberg_expected_path = Path(
    "packages/gutenberg/test/expected/browser-profile.json"
)
gutenberg_expected = json.loads(
    gutenberg_expected_path.read_text(encoding="utf-8")
)
sdk031_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-031-strict-browser-profile.json"
    ).read_text(encoding="utf-8")
)
sdk032_profile_path = Path(
    "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
    "wp70-release.browser-hxx.json"
)
sdk032_profile = json.loads(sdk032_profile_path.read_text(encoding="utf-8"))
sdk032_tooling_manifest_path = Path(
    "packages/gutenberg/hxx-tooling/package.json"
)
sdk032_tooling_lock_path = Path(
    "packages/gutenberg/hxx-tooling/package-lock.json"
)
sdk032_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-032-react-gutenberg-hxx.json"
    ).read_text(encoding="utf-8")
)
sdk033_profile_path = Path(
    "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
    "wp70-release.browser-assets.json"
)
sdk033_profile = json.loads(sdk033_profile_path.read_text(encoding="utf-8"))
sdk033_tooling_manifest_path = Path(
    "packages/gutenberg/build-tooling/package.json"
)
sdk033_tooling_lock_path = Path(
    "packages/gutenberg/build-tooling/package-lock.json"
)
sdk033_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-033-wordpress-asset-metadata.json"
    ).read_text(encoding="utf-8")
)
toolchain_lock = json.loads(
    Path("manifests/toolchain.lock.json").read_text(encoding="utf-8")
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


def verify_historical_package(subject, implementation_commit):
    package_root = Path(subject["path"])
    package_digest_input = bytearray()
    package_files = subject["packageFiles"]
    assert isinstance(package_files, list)
    assert package_files
    package_paths = []
    for package_file in package_files:
        assert set(package_file) == {"path", "sha256"}
        assert sha256.fullmatch(package_file["sha256"])
        package_path = Path(package_file["path"])
        relative_package_path = package_path.relative_to(package_root)
        assert ".." not in relative_package_path.parts
        assert "build" not in relative_package_path.parts
        package_paths.append(package_file["path"])
        package_digest_input.extend(
            f"{package_file['sha256']}  {package_file['path']}\n".encode()
        )
    assert package_paths == sorted(set(package_paths))
    assert hashlib.sha256(package_digest_input).hexdigest() == (
        subject["packageContentSha256"]
    )

    assert sha1.fullmatch(implementation_commit)
    historical_commit_available = subprocess.run(
        ["git", "cat-file", "-e", f"{implementation_commit}^{{commit}}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0
    if historical_commit_available:
        historical_paths = subprocess.run(
            [
                "git",
                "ls-tree",
                "-r",
                "--name-only",
                implementation_commit,
                "--",
                package_root.as_posix(),
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        historical_paths = sorted(
            path
            for path in historical_paths
            if "build" not in Path(path).relative_to(package_root).parts
        )
        assert historical_paths == package_paths
        for package_file in package_files:
            content = subprocess.run(
                [
                    "git",
                    "show",
                    f"{implementation_commit}:{package_file['path']}",
                ],
                check=True,
                capture_output=True,
            ).stdout
            assert hashlib.sha256(content).hexdigest() == (
                package_file["sha256"]
            )
    return package_files

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
assert hxx_dependency_lock["toolchain"]["haxe"] == "4.3.7"
assert hxx_dependency_lock["toolchain"]["lix"]["version"] == "15.12.4"
assert hxx_dependency_lock["toolchain"]["lix"]["reportedCliVersion"] == "15.12.2"
assert sha256.fullmatch(
    hxx_dependency_lock["toolchain"]["lix"]["artifact"]["sha256"]
)
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
    hxx_receipt["subject"]["neutralSyntax"],
    hxx_receipt["subject"]["expectedSnapshots"]["server"],
    hxx_receipt["subject"]["expectedSnapshots"]["browser"],
):
    subject_path = Path(receipt_subject["path"])
    assert hashlib.sha256(subject_path.read_bytes()).hexdigest() == (
        receipt_subject["sha256"]
    )
for verifier_name in (
    "dependencyVerifier",
    "snapshotVerifier",
    "generatedPhpHasher",
):
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
server_artifact = hxx_receipt["localVerification"]["generatedArtifacts"]["server"]
assert server_artifact["fileCount"] == 16
assert server_artifact["rawSizeBytesLocalMacosArm64"] == 106249
assert server_artifact["rawSizePolicyMaximumBytes"] == 120000
assert server_artifact["normalizedSizeBytes"] == 90153
assert server_artifact["normalizedStdlibSourceMarkerCount"] == 503
assert server_artifact["normalizedContentTreeSha256"] == (
    "a45feae15916d41161ca667a336954a196239445c88443282523c06f45173822"
)
assert hxx_receipt["localVerification"]["generatedPhpHasher"][
    "otherAbsoluteSourceMarkers"
] == "fail-closed"
assert hxx_receipt["hostedVerification"]["status"] == "passed"
assert hxx_receipt["hostedVerification"]["runId"] == 29612843555
assert hxx_receipt["hostedVerification"]["jobId"] == 87991247932
assert hxx_receipt["hostedVerification"]["commit"] == (
    "a979dcd60de9b5cdd355fd810192d6abf30c15f3"
)
assert hxx_receipt["hostedVerification"]["required"] is True
assert hxx_receipt["hostedVerification"]["serverEvidence"] == {
    "fileCount": 16,
    "rawSizeBytes": 101722,
    "normalizedSizeBytes": 90153,
    "normalizedStdlibSourceMarkerCount": 503,
    "normalizedContentTreeSha256": (
        "a45feae15916d41161ca667a336954a196239445c88443282523c06f45173822"
    ),
}
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

assert source_correlation_architecture["schemaVersion"] == 1
assert source_correlation_architecture["decision"] == "ADR-014"
assert source_correlation_architecture["status"] == "accepted-architecture"
assert source_correlation_architecture["acceptedAt"] == "2026-07-18"
assert source_correlation_architecture["claim"] == (
    "schemas-and-contract-fixtures-only"
)
source_contract = source_correlation_architecture["publicContract"]
assert source_contract["phpMapFormat"] == (
    "wordpresshx.php-haxe-range-map.v1"
)
assert source_contract["sourceIndexFormat"] == (
    "wordpresshx.source-correlation-index.v1"
)
assert source_contract["lookupBehaviorIsPublicApi"] is True

php_map_schema = json.loads(
    Path(source_contract["phpMapSchema"]).read_text(encoding="utf-8")
)
source_index_schema = json.loads(
    Path(source_contract["sourceIndexSchema"]).read_text(encoding="utf-8")
)
assert php_map_schema["$schema"] == (
    "https://json-schema.org/draft/2020-12/schema"
)
assert source_index_schema["$schema"] == php_map_schema["$schema"]
assert php_map_schema["properties"]["schemaVersion"]["const"] == 1
assert source_index_schema["properties"]["schemaVersion"]["const"] == 1
assert php_map_schema["properties"]["format"]["const"] == (
    source_contract["phpMapFormat"]
)
assert source_index_schema["properties"]["format"]["const"] == (
    source_contract["sourceIndexFormat"]
)

source_coordinates = source_correlation_architecture["coordinates"]
assert source_coordinates == {
    "authoritativeUnit": "utf-8-bytes",
    "range": "half-open",
    "lineBase": 1,
    "columnBase": 0,
    "columnUnit": "utf-8-bytes",
    "redundantCoordinatesValidatedAgainstBytes": True,
    "generatedContentSha256Required": True,
    "generatedByteLengthRequired": True,
    "generatedLineCountRequired": True,
    "sourceContentSha256Required": True,
}
source_paths = source_correlation_architecture["paths"]
for forbidden_path_policy in (
    "absolutePathsAllowed",
    "drivePathsAllowed",
    "backslashesAllowed",
    "traversalSegmentsAllowed",
    "basenameFallbackAllowed",
    "nearestFileGuessAllowed",
):
    assert source_paths[forbidden_path_policy] is False
assert source_paths["machinePathLeakCountAllowed"] == 0

php_source_maps = source_correlation_architecture["php"]
assert php_source_maps["owner"] == "compiler/reflaxe.php"
assert php_source_maps["wordPressSemanticPlanOwner"] == "sdk-build-layer"
assert php_source_maps["nestedRangesAllowed"] is True
assert php_source_maps["crossingRangesAllowed"] is False
assert php_source_maps["exactByteLookup"]["nearestMappingFallback"] is False
assert php_source_maps["nativeStackLineLookup"] == {
    "source": "unique-emitter-runtime-line-trace-anchor",
    "missingAnchor": "unmapped-no-anchor",
    "duplicateAnchor": "invalid-map",
    "nearestMappingFallback": False,
    "confidenceLabel": "mapped-trace-anchor",
}
assert php_source_maps["nativeFramesPreserved"] is True
assert php_source_maps["standardBrowserSourceMapClaim"] is False

browser_source_maps = source_correlation_architecture["browser"]
assert browser_source_maps["layerFormat"] == "Source Map v3"
assert browser_source_maps["haxeToGeneratedSourceOwner"] == "genes-ts"
assert set(browser_source_maps["strategies"]) == {
    "browser-composed-v3",
    "browser-two-stage-v3",
    "unavailable",
}
composition_admission = browser_source_maps["compositionAdmission"]
assert composition_admission["developmentThrowRequired"] is True
assert composition_admission["minifiedProductionThrowRequired"] is True
assert composition_admission["sameExpectedHaxeTokenRequired"] is True
assert composition_admission["silentPartialCompositionAllowed"] is False
assert browser_source_maps["fallback"]["strategy"] == (
    "browser-two-stage-v3"
)
assert browser_source_maps["fallback"]["bothLayersRetained"] is True

source_index_contract = source_correlation_architecture["sourceIndex"]
assert source_index_contract["owner"] == "sdk-build-layer"
assert source_index_contract["mapAndGeneratedContentBoundBySha256"] is True
assert source_index_contract["browserIntermediateContinuityRequired"] is True
assert source_index_contract["unavailableStrategyIsFirstClass"] is True
assert source_index_contract["lookupByCompleteFileIdentityOnly"] is True

source_retention = source_correlation_architecture["retention"]
default_production = source_retention["defaultProductionInstallArtifact"]
for forbidden_production_content in (
    "mapsIncluded",
    "sourceIndexIncluded",
    "sourceContentIncluded",
    "inlineSourceMapsIncluded",
    "developmentHandlerIncluded",
):
    assert default_production[forbidden_production_content] is False
assert default_production["readableNativePhpRequired"] is True
debug_companion = source_retention["debugCompanion"]
assert debug_companion["separateFromInstallArtifact"] is True
assert debug_companion["boundToExactProductionArtifactHashes"] is True
assert debug_companion["defaultSourceContentPolicy"] == "omitted"
assert debug_companion["allowlistedSourceContentRequiresSecretScan"] is True
assert debug_companion["allowlistedSourceContentRequiresLicenseReview"] is True
assert debug_companion["allowlistedSourceContentRequiresPathScan"] is True

trace_cli = source_correlation_architecture["traceCli"]
assert trace_cli["binary"] == "wphx-sdk"
assert trace_cli["commands"] == ["trace php", "trace browser"]
assert trace_cli["offlineByDefault"] is True
assert trace_cli["networkLookupAllowed"] is False
assert trace_cli["integrityValidationBeforeLookup"] is True
assert trace_cli["validUnmappedFramesAreErrors"] is False
assert trace_cli["invalidOrTamperedArtifactsFail"] is True
assert trace_cli["ambiguousLookupFails"] is True
assert trace_cli["nativeFrameTextPreserved"] is True
assert trace_cli["exitCodes"] == {
    "processed": 0,
    "usageOrStackInput": 2,
    "integrityOrSchema": 3,
    "ambiguousContract": 4,
}

development_handler = source_correlation_architecture[
    "wordpressDevelopmentHandler"
]
assert development_handler["default"] == "disabled"
assert development_handler["augmentsLogs"] is True
assert development_handler["suppressesNativeFrames"] is False
assert development_handler["replacesWordpressRecoveryBehavior"] is False
assert development_handler["changesHttpResponse"] is False
assert development_handler["includedInProduction"] is False

source_evidence = source_correlation_architecture["currentEvidence"]
assert source_evidence["php"]["declarationRangeFoundationReceiptId"] == (
    php_ir_receipt["receiptId"]
)
assert source_evidence["php"]["serializedMapRuntime"] == "not-tested"
assert source_evidence["php"]["traceCli"] == "not-implemented"
assert source_evidence["browser"]["genesCommit"] == (
    gutenberg_dependency_lock["compiler"]["commit"]
)
assert source_evidence["browser"]["boundedEsbuildCompositionReceiptId"] == (
    sdk032_receipt["receiptId"]
)
assert source_evidence["browser"]["officialWordpressScriptsLaneReceiptId"] == (
    sdk033_receipt["receiptId"]
)
assert source_evidence["browser"]["officialWordpressScriptsCorrelation"] == (
    "not-tested"
)
assert source_evidence["productionSupport"] == "not-tested"
assert source_evidence["publicationAuthorized"] is False

reference_review = source_correlation_architecture["referenceReview"]
assert {reference["repository"] for reference in reference_review} == {
    "https://github.com/fullofcaffeine/reflaxe.rust",
    "https://github.com/fullofcaffeine/genes-ts",
    "https://github.com/fullofcaffeine/reflaxe.elixir",
    "https://github.com/fullofcaffeine/reflaxe.ruby",
    "https://github.com/fullofcaffeine/hxhx",
    "https://github.com/fullofcaffeine/reflaxe.go",
    "https://github.com/fullofcaffeine/wordpresshx-port",
}
for reference in reference_review:
    assert sha1.fullmatch(reference["commit"])
    assert sha1.fullmatch(reference["tree"])
    assert reference["copiedCode"] is False
    assert reference["paths"]
    for reviewed_path in reference["paths"]:
        assert reviewed_path["path"]
        assert sha1.fullmatch(reviewed_path["blob"])

assert set(source_correlation_architecture["followUpBeads"]) == {
    "wordpresshx-sdk-025",
    "wordpresshx-sdk-034",
    "wordpresshx-adr-019",
}
assert len(source_correlation_architecture["stopConditions"]) == 5

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

assert browser_architecture["schemaVersion"] == 1
assert browser_architecture["decision"] == "ADR-013"
assert browser_architecture["status"] == "accepted-architecture"
assert browser_architecture["acceptedAt"] == "2026-07-18"
browser_profile = browser_architecture["profile"]
assert browser_profile["id"] == wp_source_lock["profileId"] == "wp70-release"
assert browser_profile["catalogRevision"] == wp_source_lock["catalogRevision"]
assert browser_profile["wordpressCommit"] == (
    wp_source_lock["wordpressSource"]["commit"]
)
assert browser_profile["embeddedGutenbergCommit"] == (
    wp_source_lock["embeddedGutenberg"]["commit"]
)

browser_compiler = browser_architecture["compiler"]
assert browser_compiler["name"] == "genes-ts"
assert browser_compiler["version"] == entry["version"]
assert browser_compiler["tag"] == entry["releaseTag"]
assert browser_compiler["commit"] == entry["commit"]
assert browser_compiler["tree"] == entry["tree"]
assert browser_compiler["artifactSha256"] == (
    entry["releaseArtifact"]["sha256"]
)
assert browser_compiler["receiptId"] == receipt["receiptId"]
assert browser_compiler["authorityCheckout"] == "../genes"
assert browser_compiler["mutableSiblingBuildInputAllowed"] is False
assert browser_compiler["wordpressSpecificCompilerBranchesAllowed"] is False
assert browser_compiler["upstreamChangePolicy"] == (
    "generic-fixture-isolated-worktree-full-regression-pr-then-new-immutable-sdk-pin"
)

browser_toolchains = browser_architecture["toolchains"]
assert browser_toolchains["haxe"]["version"] == "4.3.7"
project_toolchain = browser_toolchains["sdkProject"]
assert project_toolchain["node"] == {
    "version": "22.17.0",
    "image": image_lock["images"]["node"]["reference"],
    "observedVersion": "v22.17.0",
    "evidenceStatus": "exact-image-version-probed",
}
assert image_lock["images"]["node"]["tag"] == (
    "docker.io/library/node:22.17.0-bookworm-slim"
)
assert project_toolchain["packageManager"] == {
    "name": "npm",
    "version": "10.9.2",
    "lockfile": "package-lock.json",
    "lockfileVersion": 3,
    "installCommand": "npm ci",
    "rangesAllowedForGeneratedDirectDependencies": False,
}
assert project_toolchain["typescript"]["package"] == "typescript"
assert project_toolchain["typescript"]["version"] == "5.9.3"
assert project_toolchain["typescript"]["selectionAuthority"] == (
    "wp70-release-embedded-gutenberg-root-package"
)
assert project_toolchain["typescript"]["evidenceStatus"] == (
    "verified-sdk-031-strict-runtime"
)
genes_verification = browser_toolchains["genesReleaseVerification"]
assert genes_verification["nodeLocalExact"] == (
    receipt["toolchains"]["nodeLocalExact"]
)
assert genes_verification["nodeUpstreamLanes"] == (
    receipt["toolchains"]["nodeUpstreamLanes"]
)
assert genes_verification["packageManager"] == "yarn@1.22.22"
assert genes_verification["typescriptGeneratedOutputMatrix"] == [
    receipt["toolchains"]["typescript"]["legacyFloor"],
    receipt["toolchains"]["typescript"]["apiBridge"],
    receipt["toolchains"]["typescript"]["current"],
]
assert genes_verification["typescriptProgramApiEngine"] == (
    receipt["toolchains"]["typescript"]["programApiEngine"]
)
assert genes_verification["consumerProjectAuthority"] is False

wordpress_browser_build = browser_architecture["wordpressBuild"]
assert wordpress_browser_build["defaultAdapter"]["package"] == (
    "@wordpress/scripts"
)
assert wordpress_browser_build["defaultAdapter"]["version"] == "31.5.0"
assert wordpress_browser_build["dependencyExtraction"]["package"] == (
    "@wordpress/dependency-extraction-webpack-plugin"
)
assert wordpress_browser_build["dependencyExtraction"]["version"] == "6.40.0"
assert wordpress_browser_build["dependencyExtraction"][
    "defaultConfigurationFirst"
] is True
assert wordpress_browser_build["dependencyExtraction"][
    "manualAssetPhpEditingAllowed"
] is False
assert wordpress_browser_build["dependencyExtraction"][
    "finalBundleIsAuthority"
] is True
assert wordpress_browser_build["dependencyExtraction"][
    "externalizedReportRequired"
] is True
assert wordpress_browser_build["scriptModuleDefault"] is False
assert wordpress_browser_build["sourceGlobalsAllowed"] is False

source_output = browser_architecture["sourceOutput"]
primary_output = source_output["primary"]
assert primary_output["status"] == "primary-development-and-production-input"
assert primary_output["extensions"] == [".ts", ".tsx"]
assert primary_output["genesDefines"] == [
    "genes.ts",
    "genes.ts.no_extension",
    "genes.library",
    "js-es=6",
]
assert primary_output["moduleFormat"] == "split-esm"
assert primary_output["markup"] == {
    "authoring": "haxe-inline-hxx",
    "tsxSelection": "tsx-extension-for-markup-bearing-entry",
    "jsxRuntime": "react-jsx-automatic",
    "jsxRuntimeRequest": "react/jsx-runtime",
    "wordpressHandle": "react-jsx-runtime",
}
assert primary_output["typecheck"] == {
    "noEmit": True,
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": True,
    "strictNullChecks": True,
    "exactOptionalPropertyTypes": True,
    "noUncheckedIndexedAccess": True,
    "verbatimModuleSyntax": True,
    "skipLibCheck": False,
    "jsx": "react-jsx",
}
assert primary_output["weakTypePolicy"] == (
    "no-unexplained-any-or-unknown-in-user-or-public-export-surfaces"
)

classic_output = source_output["classicDifferential"]
assert classic_output["status"] == (
    "representative-differential-not-default-production-fallback"
)
assert classic_output["extensions"] == [".js", ".d.ts"]
assert classic_output["genesDefines"] == [
    "dts",
    "genes.library",
    "genes.no_extension",
    "genes.react.inline_markup",
    "js-es=6",
]
assert classic_output["forbiddenDefine"] == "genes.ts"
assert classic_output["comparison"] == (
    "observable-runtime-and-public-contract-not-textual-output"
)
assert classic_output["coveragePolicy"] == (
    "bounded-explicit-corpus-no-universal-mode-switch-claim"
)

browser_imports = browser_architecture["imports"]
assert browser_imports["sourcePolicy"] == "normal-esm-package-specifiers"
assert browser_imports["profileApprovalRequired"] is True
assert browser_imports["sideEffectImportsPreserved"] is True
assert browser_imports[
    "developmentProductionSemanticImportsIdentical"
] is True
assert browser_imports[
    "compilerOwnedWordpressNameRewritesAllowed"
] is False
catalog_path = Path("generated/wp70-release/catalog-v1/catalog.json")
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
catalog_capability_ids = {
    capability["capabilityId"]
    for capability in catalog["catalog"]["capabilities"]
}
for package_mapping in browser_imports["selectedMappings"]:
    assert package_mapping["packageCapability"] in catalog_capability_ids
    assert package_mapping["handleCapability"] in catalog_capability_ids
    assert package_mapping["handle"] == (
        "wp-" + package_mapping["request"].removeprefix("@wordpress/")
    )
assert browser_imports["reactMappings"] == [
    {
        "request": "react",
        "handle": "react",
        "packageCapability": None,
        "handleCapability": "wordpress.script-handle.react",
    },
    {
        "request": "react-dom",
        "handle": "react-dom",
        "packageCapability": None,
        "handleCapability": "wordpress.script-handle.react-dom",
    },
    {
        "request": "react/jsx-runtime",
        "handle": "react-jsx-runtime",
        "packageCapability": None,
        "handleCapability": "wordpress.script-handle.react-jsx-runtime",
    },
]
for react_mapping in browser_imports["reactMappings"]:
    assert react_mapping["handleCapability"] in catalog_capability_ids

public_exports = browser_architecture["publicExports"]
assert public_exports["sourceOfTruth"] == (
    "versioned-browser-entry-and-export-semantic-plan"
)
assert public_exports["retention"] == {
    "genesRootMetadata": "@:genes.library",
    "genesDefine": "genes.library",
    "typingRoot": "macro-include-of-declared-public-namespace",
    "classicDeclarationsRequired": True,
    "globalDceDisableAllowed": False,
    "scatteredUnmanifestedKeepAllowed": False,
}
assert public_exports["manifestFields"] == [
    "stableExportId",
    "haxeSource",
    "generatedModule",
    "exportName",
    "typeIdentity",
    "retentionRule",
    "profileCapabilityRefs",
    "sourceSpan",
]
assert "ordinary-javascript-import-and-call" in public_exports["verification"]

browser_dce = browser_architecture["deadCodeElimination"]
assert browser_dce["production"] == "full"
assert browser_dce["publicGraphRetained"] is True
assert browser_dce["privateUnreachableCodeRetained"] is False
assert browser_dce["sideEffectRootsDeclared"] is True
asset_metadata = browser_architecture["assetMetadata"]
assert asset_metadata["status"] == (
    "verified-sdk-033-final-bundle-and-real-wordpress"
)
assert asset_metadata["producer"] == (
    "@wordpress/dependency-extraction-webpack-plugin"
)
assert asset_metadata["versionComesFromFinalBundleToolOutput"] is True
assert asset_metadata["manualPreBundleVersionAllowed"] is False
assert asset_metadata["deterministicCleanReplayRequired"] is True
assert asset_metadata["translationAttachmentValidatedAgainstFinalHandle"] is True
assert browser_architecture["evidence"]["wordpressBundleAndAssetParity"] == (
    "verified-by-sdk-033-wordpress-asset-metadata"
)

for source_authority in browser_architecture["provenance"].values():
    for source_file in source_authority:
        assert sha1.fullmatch(source_file["blob"])
        assert sha256.fullmatch(source_file["sha256"])
assert browser_architecture["evidence"]["architectureAccepted"] is True
assert browser_architecture["evidence"]["genesReleaseGatePassed"] is True
assert browser_architecture["evidence"]["browserSdkCompatibility"] == (
    "not-tested"
)
assert browser_architecture["evidence"]["productionSupport"] == "not-tested"
assert browser_architecture["evidence"]["publicationAuthorized"] is False
assert set(browser_architecture["stopConditions"]) == {
    "strict-tsx-requires-routine-unexplained-any-or-unknown",
    "profile-approved-imports-cannot-produce-profile-correct-final-handles",
    "public-exports-cannot-survive-production-dce-with-bounded-retention",
    "classic-differential-has-unexplained-observable-divergence",
    "wordpress-specific-compiler-branch-would-be-required",
}

assert sdk031_receipt["schemaVersion"] == 1
assert sdk031_receipt["receiptId"] == "SDK-031-STRICT-BROWSER-PROFILE"
assert sdk031_receipt["bead"] == "wordpresshx-sdk-031"
assert sdk031_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
sdk031_subject = sdk031_receipt["subject"]
assert sdk031_subject["package"] == "packages/gutenberg"
assert sdk031_subject["profileId"] == browser_profile["id"]
for locked_subject in (
    sdk031_subject["dependencyLock"],
    sdk031_subject["exportDirective"],
    sdk031_subject["expectedArtifacts"],
):
    locked_path = Path(locked_subject["path"])
    assert hashlib.sha256(locked_path.read_bytes()).hexdigest() == (
        locked_subject["sha256"]
    )
assert sdk031_subject["dependencyLock"]["path"] == (
    gutenberg_dependency_lock_path.as_posix()
)
assert sdk031_subject["expectedArtifacts"]["path"] == (
    gutenberg_expected_path.as_posix()
)

sdk031_compiler = sdk031_subject["compiler"]
locked_compiler = gutenberg_dependency_lock["compiler"]
for compiler_field in ("name", "version", "tag", "commit", "tree"):
    assert sdk031_compiler[compiler_field] == locked_compiler[compiler_field]
assert sdk031_compiler["releaseArtifact"] == locked_compiler["releaseArtifact"]
assert sdk031_compiler["commit"] != browser_compiler["commit"]
assert sha1.fullmatch(sdk031_compiler["commit"])
assert sha1.fullmatch(sdk031_compiler["tree"])
assert sha256.fullmatch(sdk031_compiler["releaseArtifact"]["sha256"])

sdk031_admission = sdk031_receipt["compilerAdmission"]
locked_admission = locked_compiler["admission"]
assert sdk031_admission["baseline"]["receiptId"] == receipt["receiptId"]
for baseline_field in ("version", "commit", "tree"):
    assert sdk031_admission["baseline"][baseline_field] == (
        locked_admission["baseline"][baseline_field]
    )
assert sdk031_admission["baseline"]["commit"] == browser_compiler["commit"]
assert sdk031_admission["finding"]["wordpressSymbolsInReduction"] is False
assert sdk031_admission["finding"]["wordpressSpecificCompilerBranch"] is False
assert sdk031_admission["finding"]["mutableSiblingBuildInput"] is False
sdk031_change = sdk031_admission["change"]
assert sdk031_change["pullRequest"]["number"] == (
    locked_admission["change"]["pullRequest"]["number"]
)
assert sdk031_change["pullRequest"]["url"] == (
    locked_admission["change"]["pullRequest"]["url"]
)
assert sdk031_change["pullRequest"]["headCommit"] == (
    locked_admission["change"]["fixCommit"]
)
assert sdk031_change["pullRequest"]["headTree"] == (
    locked_admission["change"]["fixTree"]
)
assert sdk031_change["pullRequest"]["mergeCommit"] == (
    locked_admission["change"]["mergeCommit"]
)
assert sdk031_change["releaseLineage"][-1] == sdk031_compiler["commit"]

sdk031_local = sdk031_receipt["localVerification"]
assert sdk031_local["gate"]["outcome"] == "passed"
assert sdk031_local["gate"]["secondCleanCompileMatched"] is True
for verifier in sdk031_local["verifiers"].values():
    verifier_path = Path(verifier["path"])
    assert hashlib.sha256(verifier_path.read_bytes()).hexdigest() == (
        verifier["sha256"]
    )
assert sdk031_local["generatedArtifacts"]["treeSha256"] == (
    gutenberg_expected["artifacts"]["generatedTreeSha256"]
)
assert sdk031_local["generatedArtifacts"]["strictBundle"] == (
    gutenberg_expected["artifacts"]["strictBundle"]
)
assert sdk031_local["generatedArtifacts"]["classicBundle"] == (
    gutenberg_expected["artifacts"]["classicBundle"]
)
assert sdk031_local["strictProfile"]["authoredPublicAny"] == 0
assert sdk031_local["strictProfile"]["authoredPublicUnknown"] == 0
assert sdk031_local["strictProfile"]["unexplainedWeakTypeDelta"] == 0
assert all(
    result == "passed"
    for result in (
        sdk031_local["behavior"]["strictClassicPublicContractParity"],
        sdk031_local["behavior"]["sideEffectImport"],
        sdk031_local["behavior"]["liveEsmBinding"],
        sdk031_local["behavior"]["ordinaryJavascriptConsumer"],
        sdk031_local["behavior"]["runtimeTranscriptParity"],
    )
)
assert sdk031_local["harnessPortability"]["genesSymlinkTraversalGuardRelaxed"] is False

sdk031_repository_hosted = sdk031_receipt["repositoryHostedVerification"]
assert sdk031_repository_hosted["workflow"] == "Repository bootstrap"
assert sdk031_repository_hosted["discardedAttempts"] == [
    {
        "runId": 29634010485,
        "commit": "24f32ca12a76c7e95ad8a715051f20728da7c004",
        "outcome": "failed-before-sdk031-compile",
        "reason": (
            "the gate invoked setup-haxe instead of the Lix shim after scoped "
            "dependencies were downloaded; all other hosted jobs passed"
        ),
    }
]
if sdk031_receipt["status"] == "implemented-hosted-pending":
    assert sdk031_repository_hosted["runId"] is None
    assert sdk031_repository_hosted["commit"] is None
    assert sdk031_repository_hosted["status"] == "pending"
    assert sdk031_repository_hosted["haxeJob"] == "pending"
    assert sdk031_receipt["claims"]["deterministicGeneratedOutput"] == (
        "locally-tested"
    )
else:
    assert isinstance(sdk031_repository_hosted["runId"], int)
    assert sdk031_repository_hosted["runId"] > 0
    assert sdk031_repository_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk031_repository_hosted['runId']}"
    )
    assert sha1.fullmatch(sdk031_repository_hosted["commit"])
    assert sdk031_repository_hosted["status"] == "passed"
    assert sdk031_repository_hosted["jobCount"] == 10
    assert sdk031_repository_hosted["allJobsPassed"] is True
    assert sdk031_repository_hosted["haxeJob"] == "passed"
    assert sdk031_repository_hosted["haxeJobId"] == 88053343606
    assert sdk031_repository_hosted["haxeJobUrl"] == (
        sdk031_repository_hosted["url"]
        + f"/job/{sdk031_repository_hosted['haxeJobId']}"
    )
    assert sdk031_repository_hosted["hostedArtifactHashesMatched"] is True
    assert sdk031_receipt["claims"]["deterministicGeneratedOutput"] == (
        "hosted-runtime-tested"
    )
assert sdk031_receipt["claims"]["reactGutenbergHxx"] == "not-tested"
assert sdk031_receipt["claims"]["wordpressBrowserRuntime"] == "not-tested"
assert sdk031_receipt["claims"]["productionSupport"] == "not-tested"

assert sdk032_receipt["schemaVersion"] == 1
assert sdk032_receipt["receiptId"] == "SDK-032-REACT-GUTENBERG-HXX"
assert sdk032_receipt["bead"] == "wordpresshx-sdk-032"
assert sdk032_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
sdk032_subject = sdk032_receipt["subject"]
assert sdk032_subject["package"] == "packages/gutenberg"
assert sdk032_subject["profileId"] == "wp70-release"
for locked_subject in sdk032_subject.values():
    if not isinstance(locked_subject, dict) or "path" not in locked_subject:
        continue
    locked_path = Path(locked_subject["path"])
    assert hashlib.sha256(locked_path.read_bytes()).hexdigest() == (
        locked_subject["sha256"]
    )
assert sdk032_subject["profile"]["path"] == sdk032_profile_path.as_posix()
assert sdk032_profile["schemaVersion"] == 1
assert sdk032_profile["profileId"] == "wp70-release"
assert sdk032_profile["catalogRevision"] == "wp70-release/catalog-v1"
assert sdk032_profile["provider"]["wordpressCommit"] == (
    wp_source_lock["wordpressSource"]["commit"]
)
assert sdk032_profile["provider"]["gutenbergCommit"] == (
    wp_source_lock["embeddedGutenberg"]["commit"]
)
assert sdk032_profile["provider"]["gutenbergTree"] == (
    wp_source_lock["embeddedGutenberg"]["tree"]
)
assert sdk032_profile["policy"] == {
    "rawJsxAllowed": False,
    "browserHxxRuntimeAllowed": False,
    "openAttributeSpreadsAllowed": False,
    "profileGeneratedOrCurated": "curated-exact-source-and-published-types",
}
assert [component["tag"] for component in sdk032_profile["components"]] == [
    "Button",
    "Notice",
]
assert sdk032_profile["hooks"] == [
    "createContext",
    "useContext",
    "useEffect",
    "useRef",
    "useState",
]

sdk032_inputs = sdk032_receipt["immutableInputs"]
for compiler_field in ("name", "version", "tag", "commit", "tree"):
    assert sdk032_inputs["compiler"][compiler_field] == (
        locked_compiler[compiler_field]
    )
assert sdk032_inputs["compiler"]["releaseArtifactSha256"] == (
    locked_compiler["releaseArtifact"]["sha256"]
)
assert sdk032_inputs["parser"]["commit"] == hxx_parser["commit"]
assert sdk032_inputs["parser"]["tree"] == hxx_parser["tree"]
assert sdk032_inputs["provider"]["dependencyLockBlob"] == (
    sdk032_profile["provider"]["dependencyLock"]["blob"]
)
assert sdk032_inputs["provider"]["dependencyLockSha256"] == (
    sdk032_profile["provider"]["dependencyLock"]["sha256"]
)
for npm_subject, npm_path in (
    (sdk032_inputs["npm"]["manifest"], sdk032_tooling_manifest_path),
    (sdk032_inputs["npm"]["lock"], sdk032_tooling_lock_path),
):
    assert npm_subject["path"] == npm_path.as_posix()
    assert hashlib.sha256(npm_path.read_bytes()).hexdigest() == (
        npm_subject["sha256"]
    )

sdk032_graph = next(
    graph
    for graph in toolchain_lock["dependencyGraphs"]["npm"]["externalGraphs"]
    if graph["id"] == "sdk-032-react-gutenberg-hxx-verification-graph"
)
assert sdk032_graph["receiptId"] == sdk032_receipt["receiptId"]
assert sdk032_graph["profilePath"] == sdk032_profile_path.as_posix()
assert sdk032_graph["profileSha256"] == hashlib.sha256(
    sdk032_profile_path.read_bytes()
).hexdigest()
assert sdk032_graph["manifestPath"] == sdk032_tooling_manifest_path.as_posix()
assert sdk032_graph["manifestSha256"] == hashlib.sha256(
    sdk032_tooling_manifest_path.read_bytes()
).hexdigest()
assert sdk032_graph["lockPath"] == sdk032_tooling_lock_path.as_posix()
assert sdk032_graph["lockSha256"] == hashlib.sha256(
    sdk032_tooling_lock_path.read_bytes()
).hexdigest()
sdk032_tooling_manifest = json.loads(
    sdk032_tooling_manifest_path.read_text(encoding="utf-8")
)
assert set(sdk032_graph["directPackages"]) == {
    f"{name}@{version}"
    for name, version in sdk032_tooling_manifest["devDependencies"].items()
}
assert sdk032_graph["runtimeImage"] == image_lock["images"]["node"]["reference"]
assert sdk032_graph["buildInputOnly"] is True
assert sdk032_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
assert sdk032_receipt["receiptId"] in hxx_entry["testReceiptIds"]
assert hxx_receipt["subject"]["neutralSyntax"]["introducedByReceipt"] == (
    sdk032_receipt["receiptId"]
)

sdk032_exact = sdk032_receipt["exactProfileVerification"]
sdk032_profile_verifier = Path(sdk032_exact["verifier"]["path"])
assert hashlib.sha256(sdk032_profile_verifier.read_bytes()).hexdigest() == (
    sdk032_exact["verifier"]["sha256"]
)
compile(
    sdk032_profile_verifier.read_text(encoding="utf-8"),
    sdk032_profile_verifier.as_posix(),
    "exec",
)
assert sdk032_exact["immutableGutenbergBlobCount"] == 5
assert sdk032_exact["outcome"] == "passed"

sdk032_local = sdk032_receipt["localVerification"]
assert sdk032_local["gate"]["outcome"] == "passed"
assert sdk032_local["gate"]["secondCleanCompileMatched"] is True
assert sdk032_local["gate"]["secondVisualBundleMatched"] is True
for verifier in sdk032_local["verifiers"].values():
    verifier_path = Path(verifier["path"])
    assert hashlib.sha256(verifier_path.read_bytes()).hexdigest() == (
        verifier["sha256"]
    )
assert sha256.fullmatch(sdk032_local["generatedArtifacts"]["treeSha256"])
assert sha256.fullmatch(sdk032_local["generatedArtifacts"]["mainTsxSha256"])
assert sdk032_local["generatedArtifacts"]["undeclaredReactGlobal"] is False
assert sdk032_local["generatedArtifacts"]["parserOrMarkerLeakScan"] == "passed"
assert sdk032_local["typechecks"]["publicWeakTypes"] == []
assert sdk032_local["typechecks"]["internalWeakInventory"] == [
    "Main.App:tmp:any[]",
    "Main.ProofCheckRow:tmp1:any[]",
    "Main.ProofCheckRow:tmp:any[]",
]
assert sdk032_local["typechecks"]["generatedSource"][
    "exactOptionalPropertyTypes"
] is True
assert sdk032_local["typechecks"]["providerDeclarations"]["skipLibCheck"] is False
assert all(
    result == "passed"
    for result in sdk032_local["runtime"].values()
    if isinstance(result, str)
)
assert sdk032_local["runtime"]["consoleErrors"] == 0
assert sdk032_local["accessibility"]["controlledRuntime"][
    "seriousOrCriticalViolationsExcludingUnavailableJsdomColorContrast"
] == 0
assert sdk032_local["accessibility"]["browserReview"][
    "initialSeriousOrCriticalViolations"
] == 0
assert sdk032_local["accessibility"]["browserReview"][
    "acceptedStateSeriousOrCriticalViolations"
] == 0
assert sdk032_local["browserVisualReview"]["mobile"][
    "documentScrollWidth"
] == sdk032_local["browserVisualReview"]["mobile"]["documentClientWidth"]
assert sdk032_local["sourceMaps"]["machinePathLeaks"] == 0

sdk032_hosted = sdk032_receipt["repositoryHostedVerification"]
assert sdk032_hosted["workflow"] == "Repository bootstrap"
assert sdk032_hosted["required"] is True
assert len(sdk032_hosted["attempts"]) >= 2
sdk032_failed_attempt = sdk032_hosted["attempts"][0]
assert sdk032_failed_attempt["runId"] == 29637826116
assert sdk032_failed_attempt["url"] == (
    "https://github.com/fullofcaffeine/wordpresshx/actions/runs/29637826116"
)
assert sha1.fullmatch(sdk032_failed_attempt["commit"])
assert sdk032_failed_attempt["haxeJobId"] == 88063151337
assert sdk032_failed_attempt["status"] == "failed"
assert sdk032_failed_attempt["failedStep"] == (
    "Test typed React and Gutenberg HXX"
)
sdk032_transient_attempt = sdk032_hosted["attempts"][1]
assert sdk032_transient_attempt["runId"] == 29637982843
assert sdk032_transient_attempt["attempt"] == 1
assert sdk032_transient_attempt["commit"] == (
    "49b21ae54a699bd50f2afeca7c9e3bbc69af235c"
)
assert sdk032_transient_attempt["haxeJobId"] == 88063565710
assert sdk032_transient_attempt["status"] == "failed"
assert sdk032_transient_attempt["failedStep"] == (
    "Install exact scoped HXX toolchain"
)
if sdk032_receipt["status"] == "implemented-hosted-pending":
    assert sdk032_hosted["status"] == "pending-rerun-after-lix-global-root-fix"
    assert browser_architecture["evidence"]["gutenbergHxxFixture"] == (
        "implemented-by-sdk-032-hosted-verification-pending"
    )
else:
    assert sdk032_hosted["status"] == "passed"
    assert isinstance(sdk032_hosted["runId"], int)
    assert sdk032_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk032_hosted['runId']}"
    )
    assert sha1.fullmatch(sdk032_hosted["commit"])
    assert sdk032_hosted["attempt"] == 2
    assert sdk032_hosted["jobCount"] == 10
    assert sdk032_hosted["allJobsPassed"] is True
    assert sdk032_hosted["haxeJob"] == "passed"
    assert sdk032_hosted["haxeJobId"] == 88063705086
    assert sdk032_hosted["haxeJobUrl"] == (
        sdk032_hosted["url"] + f"/job/{sdk032_hosted['haxeJobId']}"
    )
    assert sdk032_hosted["sdk032Step"] == "passed"
    assert sdk032_hosted["hostedArtifactHashesMatched"] is True
    assert browser_architecture["evidence"]["gutenbergHxxFixture"] == (
        "verified-by-sdk-032-react-gutenberg-hxx"
    )
assert browser_architecture["evidence"]["sdkStrictFixture"] == (
    "verified-by-sdk-031-strict-browser-profile"
)
assert sdk032_receipt["changeDecision"]["genesSourceChanged"] is False
assert sdk032_receipt["changeDecision"]["genesPullRequest"] is None
assert sdk032_receipt["changeDecision"]["tinkHxxSourceChanged"] is False
assert sdk032_receipt["claims"]["reactGutenbergHxx"] == (
    "controlled-runtime-tested"
)
assert sdk032_receipt["claims"]["realWordPressEditorRuntime"] == "not-tested"
assert sdk032_receipt["claims"]["productionSupport"] == "not-tested"

assert sdk033_receipt["schemaVersion"] == 1
assert sdk033_receipt["receiptId"] == "SDK-033-WORDPRESS-ASSET-METADATA"
assert sdk033_receipt["bead"] == "wordpresshx-sdk-033"
assert sdk033_receipt["subject"]["package"] == "packages/gutenberg"
for sdk033_subject_name, sdk033_subject in sdk033_receipt["subject"].items():
    if sdk033_subject_name == "package":
        continue
    sdk033_subject_path = Path(sdk033_subject["path"])
    assert hashlib.sha256(sdk033_subject_path.read_bytes()).hexdigest() == (
        sdk033_subject["sha256"]
    )
assert sdk033_receipt["provider"]["profileId"] == sdk033_profile["profileId"]
assert sdk033_receipt["provider"]["catalogRevision"] == (
    sdk033_profile["catalogRevision"]
)
assert sdk033_receipt["provider"]["catalogDigest"] == catalog["catalogDigest"]
assert sdk033_receipt["provider"]["catalogFileSha256"] == hashlib.sha256(
    catalog_path.read_bytes()
).hexdigest()
assert sdk033_receipt["provider"]["mappingSource"] == (
    sdk033_profile["mappingSource"]
)
assert sdk033_receipt["toolchain"]["genes"]["version"] == (
    gutenberg_dependency_lock["compiler"]["version"]
)
assert sdk033_receipt["toolchain"]["node"]["image"] == (
    image_lock["images"]["node"]["reference"]
)
assert sdk033_receipt["toolchain"]["integrityLockedPackageCount"] == (
    len(json.loads(sdk033_tooling_lock_path.read_text(encoding="utf-8"))["packages"])
    - 1
)
sdk033_graph = next(
    graph
    for graph in toolchain_lock["dependencyGraphs"]["npm"]["externalGraphs"]
    if graph["id"] == "sdk-033-wordpress-assets-verification-graph"
)
assert sdk033_graph["receiptId"] == sdk033_receipt["receiptId"]
assert sdk033_graph["profilePath"] == sdk033_profile_path.as_posix()
assert sdk033_graph["profileSha256"] == hashlib.sha256(
    sdk033_profile_path.read_bytes()
).hexdigest()
assert sdk033_graph["manifestPath"] == sdk033_tooling_manifest_path.as_posix()
assert sdk033_graph["manifestSha256"] == hashlib.sha256(
    sdk033_tooling_manifest_path.read_bytes()
).hexdigest()
assert sdk033_graph["lockPath"] == sdk033_tooling_lock_path.as_posix()
assert sdk033_graph["lockSha256"] == hashlib.sha256(
    sdk033_tooling_lock_path.read_bytes()
).hexdigest()
sdk033_tooling_manifest = json.loads(
    sdk033_tooling_manifest_path.read_text(encoding="utf-8")
)
assert set(sdk033_graph["directPackages"]) == {
    f"{name}@{version}"
    for name, version in sdk033_tooling_manifest["devDependencies"].items()
}
assert sdk033_graph["lifecycleScriptsAllowed"] is False
assert sdk033_graph["advisoryFollowUp"] == "wordpresshx-g2.3"
assert sdk033_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
sdk033_evolution = sdk033_receipt["catalogEvolution"]
assert sdk033_evolution["sourceCommitChanged"] is False
assert sdk033_evolution["previousCapabilityCount"] == 28
assert sdk033_evolution["capabilityCount"] == 31
assert set(sdk033_evolution["addedCapabilities"]) == {
    "wordpress.script-handle.react",
    "wordpress.script-handle.react-dom",
    "wordpress.script-handle.react-jsx-runtime",
}
assert all(
    capability in catalog_capability_ids
    for capability in sdk033_evolution["addedCapabilities"]
)
sdk033_compilation = sdk033_receipt["compilation"]
assert sdk033_compilation["authoringSurface"] == "haxe-hxx"
assert sdk033_compilation["ordinaryReturnMarkup"] is True
assert sdk033_compilation["companionApplicationTsxAuthoredByDeveloper"] is False
assert sdk033_compilation["sourceImports"] == [
    "@wordpress/components",
    "@wordpress/element",
    "@wordpress/i18n",
]
sdk033_adapter = sdk033_receipt["adapter"]
assert sdk033_adapter["officialDefaultConfigurationLoaded"] is True
assert sdk033_adapter["officialDependencyPluginInstanceCount"] == 1
assert sdk033_adapter["officialDependencyPluginReplacementCount"] == 1
assert sdk033_adapter["replacementOptionDelta"] == {
    "externalizedReport": True
}
assert sdk033_adapter["officialBabelLoaderMatchCount"] == 1
assert sdk033_adapter["genesSourceChanged"] is False
assert sdk033_adapter["manualMappingDuplicated"] is False
sdk033_builds = sdk033_receipt["builds"]
assert sdk033_builds["externalizedRequests"] == [
    "@wordpress/components",
    "@wordpress/element",
    "@wordpress/i18n",
    "react/jsx-runtime",
]
assert sdk033_builds["finalDependencies"] == [
    "react-jsx-runtime",
    "wp-components",
    "wp-element",
    "wp-i18n",
]
assert sdk033_builds["dependencySetParity"] == "passed"
assert sdk033_builds["assetVersionDerivedFromFinalBundleBytes"] is True
for sdk033_lane in ("development", "production"):
    assert sdk033_builds[sdk033_lane]["outcome"] == "passed"
    assert sha256.fullmatch(sdk033_builds[sdk033_lane]["bundleSha256"])
    assert re.fullmatch(
        r"[0-9a-f]{20}", sdk033_builds[sdk033_lane]["version"]
    )
assert sdk033_receipt["nativeEmission"]["officialAssetPhpCopiedUnchanged"] is True
assert sdk033_receipt["nativeEmission"]["manualAssetPhpEditingAllowed"] is False
assert sdk033_receipt["nativeEmission"]["php74Syntax"] == "passed"
assert sdk033_receipt["nativeEmission"]["php84Syntax"] == "passed"
sdk033_runtime = sdk033_receipt["wordpressRuntime"]
assert sdk033_runtime["wordpressVersion"] == "7.0"
assert sdk033_runtime["wordpressImage"] == (
    image_lock["images"]["wordpress70Php84"]["reference"]
)
assert sdk033_runtime["databaseImage"] == image_lock["images"]["mysql"][
    "reference"
]
assert sdk033_runtime["allDirectDependenciesBeforeFinal"] is True
assert sdk033_runtime["registeredVersionMatchesAsset"] is True
assert sdk033_runtime["translationJsonLoaded"] is True
assert sdk033_runtime["translationsPrintedBeforeFinalScript"] is True
sdk033_security = sdk033_receipt["security"]
assert sdk033_security["directPackageSourceAndLicenseCheck"] == "passed"
assert sdk033_security["audit"]["counts"] == {
    "info": 0,
    "low": 1,
    "moderate": 23,
    "high": 12,
    "critical": 0,
    "total": 36,
}
assert sdk033_security["audit"]["auditFixApplied"] is False
assert sdk033_security["audit"]["deterministicGateDependsOnLiveRegistryAudit"] is False
assert sdk033_security["audit"]["followUpBead"] == "wordpresshx-g2.3"
assert sdk033_security["mitigations"]["npmLifecycleScriptsAllowed"] is False
assert sdk033_security["mitigations"]["nodeModulesShipped"] is False
assert sdk033_security["mitigations"]["publicationAuthorized"] is False
assert all(
    result == "passed"
    for result in sdk033_receipt["reproducibility"].values()
)
assert sdk033_receipt["changeDecision"]["genesSourceChanged"] is False
assert sdk033_receipt["changeDecision"]["genesPullRequest"] is None
sdk033_hosted = sdk033_receipt["hostedVerification"]
assert sdk033_hosted["workflow"] == "repository.yml"
assert sdk033_hosted["job"] == "wordpress-runtime"
assert sdk033_hosted["required"] is True
if sdk033_receipt["status"] == "implemented-hosted-pending":
    assert sdk033_receipt["implementation"]["commit"] is None
    assert sdk033_hosted["status"] == "pending-first-push"
    assert sdk033_hosted["sdk033Step"] == "pending"
    assert sdk033_hosted["fullMatrixStatus"] == "pending"
else:
    assert sdk033_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk033_receipt["implementation"]["commit"])
    assert sdk033_hosted["commit"] == sdk033_receipt["implementation"]["commit"]
    assert isinstance(sdk033_hosted["runId"], int)
    assert isinstance(sdk033_hosted["jobId"], int)
    assert sdk033_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk033_hosted['runId']}"
    )
    assert sdk033_hosted["jobUrl"] == (
        sdk033_hosted["url"] + f"/job/{sdk033_hosted['jobId']}"
    )
    assert sdk033_hosted["attempt"] == 1
    assert sdk033_hosted["status"] == "passed"
    assert sdk033_hosted["sdk033Step"] == "passed"
    assert sdk033_hosted["generatedTreeSha256"] == (
        sdk033_compilation["generatedTreeSha256"]
    )
    assert sdk033_hosted["productionBundleSha256"] == (
        sdk033_builds["production"]["bundleSha256"]
    )
    assert sdk033_hosted["hostedArtifactHashesMatched"] is True
    assert sdk033_hosted["jobCount"] == 10
    assert sdk033_hosted["allJobsPassed"] is True
    assert sdk033_hosted["fullMatrixStatus"] == "passed"
assert browser_architecture["evidence"]["wordpressBundleAndAssetParity"] == (
    "verified-by-sdk-033-wordpress-asset-metadata"
)
assert sdk033_receipt["claims"]["officialDependencyExtraction"] == (
    "runtime-tested"
)
assert sdk033_receipt["claims"]["translationAttachment"] == "runtime-tested"
assert sdk033_receipt["claims"]["scriptModules"] == "not-tested"
assert sdk033_receipt["claims"]["publicPackagePublication"] == "blocked"
assert sdk033_receipt["claims"]["productionSupport"] == "not-tested"

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

assert wordpress_php_receipt["schemaVersion"] == 1
assert wordpress_php_receipt["receiptId"] == (
    "SDK-022-WORDPRESS-PUBLIC-PHP-PROFILE"
)
assert wordpress_php_receipt["bead"] == "wordpresshx-sdk-022"
assert wordpress_php_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
wordpress_subject = wordpress_php_receipt["subject"]
assert wordpress_subject["profile"] == "wp70-release"
assert wordpress_subject["genericCompilerReceiptId"] == (
    php_ir_receipt["receiptId"]
)
receipt_commit = wordpress_php_receipt["implementation"][
    "implementationCommit"
]
verify_historical_package(wordpress_subject, receipt_commit)
for subject_id in ("emissionPolicy", "artifactManifestSnapshot"):
    evidence = wordpress_subject[subject_id]
    evidence_path = Path(evidence["path"])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == (
        evidence["sha256"]
    )
wordpress_artifact_manifest = json.loads(
    Path(
        wordpress_subject["artifactManifestSnapshot"]["path"]
    ).read_text(encoding="utf-8")
)
assert wordpress_artifact_manifest["profileId"] == "wp70-release"
assert wordpress_artifact_manifest["classification"] == "public-native"
assert wordpress_artifact_manifest["boundary"]["rawPhpSegments"] == 0
assert wordpress_artifact_manifest["boundary"]["stockHaxePhpFiles"] == 0
assert wordpress_artifact_manifest["boundary"]["runtimeHxxDependency"] is False
assert wordpress_artifact_manifest["boundary"]["buildTimeServerDependency"] is False
assert wordpress_artifact_manifest["claims"]["publicationAuthorized"] is False

wordpress_generated_files = {
    artifact["path"]: artifact
    for artifact in wordpress_php_receipt["generatedArtifacts"]
}
assert set(wordpress_generated_files) == {
    "acme-books.php",
    "includes/Bootstrap.php",
    "includes/autoload.php",
}
assert {
    artifact["role"] for artifact in wordpress_generated_files.values()
} == {"plugin-root", "bootstrap", "autoload"}
manifest_files = {
    artifact["path"]: artifact
    for artifact in wordpress_artifact_manifest["files"]
}
assert set(manifest_files) == set(wordpress_generated_files)
for path, artifact in wordpress_generated_files.items():
    snapshot = Path(artifact["snapshotPath"]).read_bytes()
    digest = hashlib.sha256(snapshot).hexdigest()
    assert digest == artifact["sha256"] == manifest_files[path]["sha256"]
    assert len(snapshot) == artifact["bytes"] == manifest_files[path]["bytes"]
    assert len(snapshot.splitlines()) == artifact["lines"]

wordpress_implementation = wordpress_php_receipt["implementation"]
assert wordpress_implementation["haxeSourceAndTestFileCount"] == 8
assert wordpress_implementation["input"] == {
    "language": "Haxe",
    "path": "compiler/wordpress/test/fixtures/AcmeBooksPlugin.hx",
    "handwrittenPhpApplicationSource": False,
}
assert wordpress_implementation["classification"] == "public-native"
assert wordpress_implementation["semanticClassification"] == "file-symbol-edge"
assert wordpress_implementation["generatedFileCount"] == 3
assert wordpress_implementation["stableBootstrapClass"] == (
    "Acme\\Books\\Bootstrap"
)
assert wordpress_implementation["stableBootstrapMethods"] == [
    "boot",
    "isBooted",
]
for field in (
    "deterministicRepeatedEmission",
):
    assert wordpress_implementation[field] is True
for field in ("rawPhpSegments", "stockHaxePhpFiles"):
    assert wordpress_implementation[field] == 0
for field in ("runtimeHxxDependency", "buildTimeServerDependency"):
    assert wordpress_implementation[field] is False

wordpress_toolchain = wordpress_php_receipt["toolchain"]
assert wordpress_toolchain["haxe"] == "4.3.7"
assert wordpress_toolchain["formatter"] == "1.18.0"
for receipt_key, image_key in (
    ("php74", "php74Floor"),
    ("php84", "php84Cli"),
    ("wordpress", "wordpress70Php84"),
    ("mysql", "mysql"),
    ("mariadb", "mariadb"),
):
    assert wordpress_toolchain[receipt_key]["reference"] == (
        image_lock["images"][image_key]["reference"]
    )

wordpress_verification = wordpress_php_receipt["verification"]
assert wordpress_verification["localProfile"]["outcome"] == "passed"
php_matrix = wordpress_verification["exactPhpMatrix"]
assert php_matrix["containerNetwork"] == "none"
for field in (
    "php74Lint",
    "php74NativeCaller",
    "php84Lint",
    "php84NativeCaller",
):
    assert php_matrix[field] == "passed"
for field in ("php74DirectGuard", "php84DirectGuard"):
    assert php_matrix[field] == "passed-zero-output"
wordpress_matrix = wordpress_verification["wordpressMatrix"]
assert wordpress_matrix["wordpressVersion"] == "7.0"
assert wordpress_matrix["activationError"] is None
assert wordpress_matrix["activationOutputBytes"] == 0
assert wordpress_matrix["activeAfterFreshRequest"] is True
assert wordpress_matrix["bootstrapClassBootedAfterFreshRequest"] is True
assert wordpress_matrix["outcome"] == "passed"
assert [lane["database"] for lane in wordpress_matrix["lanes"]] == [
    "mysql",
    "mariadb",
]
for lane in wordpress_matrix["lanes"]:
    for field in (
        "freshInstall",
        "activation",
        "freshRequestProbe",
        "volumeResetBeforeAndAfter",
    ):
        assert lane[field] == "passed"
readability = wordpress_verification["readability"]
assert readability["trackedNativeSnapshots"] is True
assert readability["totalPhpBytes"] == 786
assert readability["totalPhpLines"] == 43
assert readability["rootHeaderWithinNativeScanWindow"] is True
assert readability["ordinaryPhpSymbolsVisible"] is True
assert readability["automatedRawScaffoldReview"] == "passed"
assert readability["independentWordpressPhpReviewer"] == "pending-g1"

wordpress_hosted = wordpress_php_receipt["hostedWorkflow"]
assert wordpress_hosted["path"] == ".github/workflows/repository.yml"
assert [job["name"] for job in wordpress_hosted["requiredJobs"]] == [
    "haxe",
    "wordpress-runtime",
]
if wordpress_php_receipt["status"] == "implemented-hosted-pending":
    assert wordpress_implementation["implementationCommit"] is None
    for field in ("runId", "commit"):
        assert wordpress_hosted[field] is None
    assert wordpress_hosted["status"] == "pending"
    assert wordpress_hosted["fullMatrixStatus"] == "pending"
    for job in wordpress_hosted["requiredJobs"]:
        assert job["jobId"] is None
        assert job["status"] == "pending"
else:
    assert sha1.fullmatch(wordpress_implementation["implementationCommit"])
    assert wordpress_implementation["implementationCommit"] == (
        wordpress_hosted["commit"]
    )
    assert isinstance(wordpress_hosted["runId"], int)
    assert wordpress_hosted["runId"] > 0
    assert sha1.fullmatch(wordpress_hosted["commit"])
    assert wordpress_hosted["status"] == "passed"
    assert wordpress_hosted["fullMatrixStatus"] == "passed"
    for job in wordpress_hosted["requiredJobs"]:
        assert isinstance(job["jobId"], int) and job["jobId"] > 0
        assert job["status"] == "passed"

assert wordpress_php_receipt["claims"] == {
    "structuredPluginHeaders": "snapshot-tested",
    "nativePhp74Bootstrap": "runtime-tested",
    "nativePhp84Bootstrap": "runtime-tested",
    "wordpress70DiscoveryActivation": "runtime-tested",
    "mysqlLane": "runtime-tested",
    "mariadbLane": "runtime-tested",
    "wpcsAndStaticAnalysis": "not-tested-sdk-026",
    "independentReadabilityReview": "not-tested-g1",
    "publication": "unsupported",
    "productionSupport": "not-tested",
}
assert wordpress_php_receipt["limitations"] == sorted(
    wordpress_php_receipt["limitations"]
)

assert wordpress_adapter_receipt["schemaVersion"] == 1
assert wordpress_adapter_receipt["receiptId"] == (
    "SDK-023-WORDPRESS-PUBLIC-PHP-ADAPTERS"
)
assert wordpress_adapter_receipt["bead"] == "wordpresshx-sdk-023"
assert wordpress_adapter_receipt["status"] == "verified"
adapter_subject = wordpress_adapter_receipt["subject"]
assert adapter_subject["profile"] == "wp70-release"
assert adapter_subject["genericCompilerReceiptId"] == (
    php_ir_receipt["receiptId"]
)
assert adapter_subject["bootstrapReceiptId"] == (
    wordpress_php_receipt["receiptId"]
)
adapter_implementation = wordpress_adapter_receipt["implementation"]
adapter_commit = adapter_implementation["implementationCommit"]
adapter_package_files = verify_historical_package(
    adapter_subject,
    adapter_commit,
)
assert len(adapter_package_files) == 41
adapter_package_digests = {
    package_file["path"]: package_file["sha256"]
    for package_file in adapter_package_files
}
for subject_id in ("emissionPolicy", "artifactManifestSnapshot"):
    evidence = adapter_subject[subject_id]
    evidence_path = Path(evidence["path"])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == (
        evidence["sha256"]
    )
assert adapter_subject["emissionPolicy"] == {
    "path": "manifests/php-emission-policy.json",
    "sha256": wordpress_subject["emissionPolicy"]["sha256"],
}

adapter_manifest = json.loads(
    Path(
        adapter_subject["artifactManifestSnapshot"]["path"]
    ).read_text(encoding="utf-8")
)
assert adapter_manifest["schemaVersion"] == 1
assert adapter_manifest["manifestId"] == (
    "wordpresshx-public-php-adapters-v1"
)
assert adapter_manifest["profileId"] == "wp70-release"
assert adapter_manifest["classification"] == "public-native"
assert adapter_manifest["plugin"] == {
    "rootPath": "acme-books-adapters.php",
    "adapterPath": "includes/PublicAdapters.php",
    "slug": "acme-books-adapters",
    "registrationPath": "includes/register-adapters.php",
    "adapterClass": "\\Acme\\BooksAdapters\\PublicAdapters",
}
assert adapter_manifest["boundary"] == {
    "rawPhpSegments": 0,
    "privateImplementationMethods": 2,
    "semanticPlanSchema": "not-implemented-adr-006",
    "runtimeHxxDependency": False,
    "ownershipTransaction": "not-implemented-adr-007",
    "semanticPlanClassification": "file-symbol-edge",
    "stockHaxePhpFiles": 0,
    "buildTimeServerDependency": False,
}
assert [hook["kind"] for hook in adapter_manifest["hooks"]] == [
    "action",
    "filter",
]
assert [hook["acceptedArgs"] for hook in adapter_manifest["hooks"]] == [
    0,
    2,
]
assert len(adapter_manifest["restRoutes"]) == 1
assert adapter_manifest["restRoutes"][0]["permissionCallback"] == (
    "\\Acme\\BooksAdapters\\PublicAdapters::restPermission"
)
assert len(adapter_manifest["blocks"]) == 1
assert len(adapter_manifest["publicExports"]) == 3

adapter_generated_files = {
    artifact["path"]: artifact
    for artifact in wordpress_adapter_receipt["generatedArtifacts"]
}
assert set(adapter_generated_files) == {
    "acme-books-adapters.php",
    "includes/Bootstrap.php",
    "includes/PublicAdapters.php",
    "includes/autoload.php",
    "includes/register-adapters.php",
}
assert {
    artifact["role"] for artifact in adapter_generated_files.values()
} == {
    "plugin-root",
    "bootstrap",
    "adapter-class",
    "autoload",
    "registrations",
}
adapter_manifest_files = {
    artifact["path"]: artifact
    for artifact in adapter_manifest["files"]
}
assert set(adapter_manifest_files) == set(adapter_generated_files)
for path, artifact in adapter_generated_files.items():
    snapshot_path = Path(artifact["snapshotPath"])
    snapshot = snapshot_path.read_bytes()
    digest = hashlib.sha256(snapshot).hexdigest()
    assert digest == artifact["sha256"]
    assert digest == adapter_manifest_files[path]["sha256"]
    assert digest == adapter_package_digests[artifact["snapshotPath"]]
    assert len(snapshot) == artifact["bytes"]
    assert len(snapshot) == adapter_manifest_files[path]["bytes"]
    assert len(snapshot.splitlines()) == artifact["lines"]

assert adapter_implementation["primaryFeatureCommit"] == (
    wordpress_adapter_receipt["hostedWorkflow"]["precedingFailure"][
        "commit"
    ]
)
assert sha1.fullmatch(adapter_implementation["primaryFeatureCommit"])
assert adapter_implementation["haxeSourceAndTestFileCount"] == 20
adapter_owned_haxe_files = adapter_implementation["sdk023OwnedHaxeFiles"]
assert len(adapter_owned_haxe_files) == 12
assert adapter_owned_haxe_files == sorted(set(adapter_owned_haxe_files))
for path in adapter_owned_haxe_files:
    assert path.endswith(".hx")
    assert path in adapter_package_digests
assert adapter_implementation["input"] == {
    "language": "Haxe",
    "path": "compiler/wordpress/test/fixtures/AcmeBooksAdapters.hx",
    "handwrittenPhpApplicationSource": False,
}
assert adapter_implementation["classification"] == "public-native"
assert adapter_implementation["semanticClassification"] == "file-symbol-edge"
assert adapter_implementation["generatedFileCount"] == 5
assert adapter_implementation["stableAdapterClass"] == (
    "Acme\\BooksAdapters\\PublicAdapters"
)
assert adapter_implementation["publicMethods"] == [
    "appendLabel",
    "filterTitle",
    "isInitialized",
    "normalizeTitle",
    "onInit",
    "registerBlocks",
    "registerRestRoutes",
    "renderSummary",
    "restBook",
    "restPermission",
]
assert adapter_implementation["privateMethods"] == [
    "bookPayload",
    "normalizeTitleImpl",
]
assert adapter_implementation["registrations"] == {
    "actions": 3,
    "filters": 1,
    "restRoutes": 1,
    "dynamicBlocks": 1,
    "namedPublicExports": 3,
}
assert adapter_implementation["deterministicRepeatedEmission"] is True
for field in ("rawPhpSegments", "stockHaxePhpFiles"):
    assert adapter_implementation[field] == 0
for field in ("runtimeHxxDependency", "buildTimeServerDependency"):
    assert adapter_implementation[field] is False

adapter_toolchain = wordpress_adapter_receipt["toolchain"]
assert adapter_toolchain["haxe"] == "4.3.7"
assert adapter_toolchain["formatter"] == "1.18.0"
for receipt_key, image_key in (
    ("php74", "php74Floor"),
    ("php84", "php84Cli"),
    ("wordpress", "wordpress70Php84"),
    ("mysql", "mysql"),
    ("mariadb", "mariadb"),
):
    assert adapter_toolchain[receipt_key]["reference"] == (
        image_lock["images"][image_key]["reference"]
    )

adapter_verification = wordpress_adapter_receipt["verification"]
assert adapter_verification["localProfile"]["outcome"] == "passed"
adapter_php_matrix = adapter_verification["exactPhpMatrix"]
assert adapter_php_matrix["containerNetwork"] == "none"
for field in (
    "php74Lint",
    "php74NativeCallers",
    "php84Lint",
    "php84NativeCallers",
):
    assert adapter_php_matrix[field] == "passed"
for field in ("php74DirectGuards", "php84DirectGuards"):
    assert adapter_php_matrix[field] == "passed-zero-output"
adapter_wordpress_matrix = adapter_verification["wordpressMatrix"]
assert adapter_wordpress_matrix["wordpressVersion"] == "7.0"
assert adapter_wordpress_matrix["activationError"] is None
assert adapter_wordpress_matrix["activationOutputBytes"] == 0
assert adapter_wordpress_matrix["activeAfterFreshRequest"] is True
assert adapter_wordpress_matrix["actionFilter"] == {
    "initPriority": 9,
    "filterPriority": 12,
    "result": "TYPED TITLE",
}
assert adapter_wordpress_matrix["rest"] == {
    "permission": True,
    "routeRegistered": True,
    "positiveStatus": 200,
    "positivePayload": {"id": 7, "title": "Book 7"},
    "negativeStatus": 400,
    "negativeCode": "acme_books_invalid_id",
}
assert adapter_wordpress_matrix["dynamicBlock"] == {
    "registered": True,
    "markup": (
        '<section class="acme-books-summary">Typed &amp; Safe</section>'
    ),
}
assert adapter_wordpress_matrix["publicExports"] == {
    "byReferenceMutation": "passed",
    "normalizeTitle": "RUNTIME TITLE",
}
assert [
    lane["database"] for lane in adapter_wordpress_matrix["lanes"]
] == ["mysql", "mariadb"]
for lane in adapter_wordpress_matrix["lanes"]:
    for field in (
        "freshInstall",
        "activation",
        "freshRequestProbe",
        "volumeResetBeforeAndAfter",
    ):
        assert lane[field] == "passed"
assert adapter_wordpress_matrix["outcome"] == "passed"
assert adapter_verification["depthOneRepositoryCheckout"] == {
    "historicalCommitAvailable": False,
    "selfContainedReceiptAggregate": "passed",
    "command": "bash scripts/check-repository.sh",
    "outcome": "passed",
}
for result in adapter_verification["regressions"].values():
    assert result == "passed"
adapter_readability = adapter_verification["readability"]
assert adapter_readability["trackedNativeSnapshots"] is True
assert adapter_readability["totalPhpBytes"] == sum(
    artifact["bytes"] for artifact in adapter_generated_files.values()
)
assert adapter_readability["totalPhpLines"] == sum(
    artifact["lines"] for artifact in adapter_generated_files.values()
)
assert adapter_readability["totalPhpBytes"] == 3488
assert adapter_readability["totalPhpLines"] == 130
assert adapter_readability["adapterClassBytes"] == 2126
assert adapter_readability["adapterClassLines"] == 77
assert adapter_readability["ordinaryPhpSymbolsVisible"] is True
assert adapter_readability["automatedRawScaffoldReview"] == "passed"
assert adapter_readability["independentWordpressPhpReviewer"] == (
    "pending-g1"
)

adapter_hosted = wordpress_adapter_receipt["hostedWorkflow"]
assert adapter_hosted["path"] == ".github/workflows/repository.yml"
assert adapter_hosted["runId"] == 29628012835
assert adapter_hosted["commit"] == adapter_commit
assert adapter_hosted["status"] == "passed"
assert adapter_hosted["fullMatrixStatus"] == "passed"
assert adapter_hosted["jobCount"] == 10
assert [job["name"] for job in adapter_hosted["requiredJobs"]] == [
    "repository",
    "haxe",
    "wordpress-runtime",
    "security",
]
for job in adapter_hosted["requiredJobs"]:
    assert isinstance(job["jobId"], int) and job["jobId"] > 0
    assert job["status"] == "passed"
preceding_failure = adapter_hosted["precedingFailure"]
assert preceding_failure["runId"] == 29627785837
assert preceding_failure["failedJob"]["name"] == "repository"
assert preceding_failure["failedJob"]["jobId"] == 88035464684
for job in preceding_failure["implementationJobs"].values():
    assert isinstance(job["jobId"], int) and job["jobId"] > 0
    assert job["status"] == "passed"

adapter_provenance = wordpress_adapter_receipt["designProvenance"]
assert len(adapter_provenance) == 2
for reference in adapter_provenance:
    assert reference["repository"].startswith("https://github.com/")
    assert sha1.fullmatch(reference["commit"])
    assert "no code copied" in reference["use"]
    if "path" in reference:
        assert sha1.fullmatch(reference["blob"])
    else:
        for source in reference["paths"]:
            assert sha1.fullmatch(source["blob"])

assert wordpress_adapter_receipt["claims"] == {
    "nativeActionFilterAdapters": "runtime-tested",
    "nativeRestAdapterAndPermission": "runtime-tested",
    "nativeDynamicBlockRender": "runtime-tested",
    "stablePublicPhpExports": "runtime-tested",
    "nativePhp74Adapters": "runtime-tested",
    "nativePhp84Adapters": "runtime-tested",
    "wordpress70DiscoveryActivation": "runtime-tested",
    "mysqlLane": "runtime-tested",
    "mariadbLane": "runtime-tested",
    "wpcsAndStaticAnalysis": "not-tested-sdk-026",
    "independentReadabilityReview": "not-tested-g1",
    "publication": "unsupported",
    "productionSupport": "not-tested",
}
assert wordpress_adapter_receipt["limitations"] == sorted(
    wordpress_adapter_receipt["limitations"]
)

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
assert sdk012_receipt["schemaValidation"]["negativeFixtureCount"] == 14
assert sdk012_receipt["schemaValidation"]["outcome"] == "passed"
schema_contract = sdk012_receipt["schemaImplementation"]
assert schema_contract["reviewedContractPayloadAllowedAtInventoried"] is False
assert schema_contract["reviewedContractPayloadRequiredFromTyped"] is True
assert schema_contract["heuristicSignaturePublicationAllowed"] is False
assert schema_contract["canonicalContractMetadataRequired"] is True
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
assert sdk013_profiles["wp70-release"]["catalog"]["capabilityCount"] == 31
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
sdk013_evolution = sdk013_receipt["postReceiptEvolution"]
assert sdk013_evolution["receiptId"] == "SDK-033-WORDPRESS-ASSET-METADATA"
assert sdk013_evolution["wordpressSourceCommitChanged"] is False
assert sdk013_evolution["catalogRevisionChanged"] is False
assert sdk013_evolution["classificationOrEvidenceStatusChanged"] is False
assert sdk013_evolution["generatorReplay"] == "passed"
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

assert profile_diff_schema["properties"]["schemaVersion"]["const"] == 1
assert profile_diff_schema["properties"]["reportKind"]["const"] == (
    "wordpresshx-exact-profile-diff"
)
assert sdk014_receipt["schemaVersion"] == 1
assert sdk014_receipt["receiptId"] == "SDK-014-PROFILE-DIFF"
assert sdk014_receipt["bead"] == "wordpresshx-sdk-014"
sdk014_subject = sdk014_receipt["subject"]
for path_field, digest_field in (
    ("diffPath", "diffSha256"),
    ("testPath", "testSha256"),
    ("profileSchemaPath", "profileSchemaSha256"),
    ("profileValidatorPath", "profileValidatorSha256"),
    ("diffSchemaPath", "diffSchemaSha256"),
):
    evidence_path = Path(sdk014_subject[path_field])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == (
        sdk014_subject[digest_field]
    )
assert sdk014_subject["profileSchemaPath"] == profile_schema_path.as_posix()
assert sdk014_subject["diffSchemaPath"] == profile_diff_schema_path.as_posix()

sdk014_implementation = sdk014_receipt["implementation"]
assert sdk014_implementation["inputMode"] == (
    "read-only-exact-validated-catalogs"
)
assert sdk014_implementation["outputModes"] == [
    "actionable-human",
    "deterministic-json",
]
assert sdk014_implementation["comparisonAuthorities"] == [
    "identical",
    "upstream-profile-change",
    "sdk-catalog-correction",
]
assert sdk014_implementation["sameUpstreamUnrecordedDrift"] == "rejected"
assert sdk014_implementation["mixedCorrectionAndUpstreamAuthority"] == (
    "rejected"
)
assert sdk014_implementation["sourceRewritePerformed"] is False
assert sdk014_implementation["rangeSupportInferred"] is False
assert sdk014_implementation["breakingChangeAutoAccepted"] is False

contract_extension = sdk014_receipt["profileContractExtension"]
assert contract_extension["minimumEvidenceForContract"] == "typed"
assert contract_extension["inventoryContractPublication"] == "rejected"
assert contract_extension["heuristicSignaturePublication"] == "rejected"
assert contract_extension["signatureReceiptMustMatchTypedReview"] is True
assert contract_extension["metadataValueEncoding"] == "canonical-json-string"

sdk014_goldens = {
    golden["comparison"]: golden for golden in sdk014_receipt["goldens"]
}
assert set(sdk014_goldens) == {
    "upstream-profile-change",
    "sdk-catalog-correction",
}
for comparison, golden in sdk014_goldens.items():
    for path_field, digest_field in (
        ("jsonPath", "jsonSha256"),
        ("humanPath", "humanSha256"),
    ):
        golden_path = Path(golden[path_field])
        assert hashlib.sha256(golden_path.read_bytes()).hexdigest() == golden[
            digest_field
        ]
    report = json.loads(Path(golden["jsonPath"]).read_text(encoding="utf-8"))
    assert report["comparison"]["authority"] == comparison
    assert report["reportDigest"] == golden["reportDigest"]
    report_material = {
        key: value
        for key, value in report.items()
        if key not in {"reportDigestAlgorithm", "reportDigest"}
    }
    serialized_report = json.dumps(
        report_material,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    assert hashlib.sha256(serialized_report).hexdigest() == report[
        "reportDigest"
    ]
    assert report["policy"] == {
        "scope": "exact-validated-catalogs-only",
        "rangeSupport": "not-inferred",
        "sourceRewrite": "not-performed",
        "decision": "advisory-review-required",
    }
    assert golden["outcome"] == "passed"
assert sdk014_goldens["sdk-catalog-correction"][
    "consumerContractImpact"
] == "breaking"

sdk014_tests = sdk014_receipt["testEvidence"]
assert sdk014_tests["command"] == (
    "python3 scripts/profiles/test-profile-diff.py"
)
assert sdk014_tests["exactComparisonPairCount"] == 2
assert sdk014_tests["jsonGoldenCount"] == 2
assert sdk014_tests["humanGoldenCount"] == 2
assert sdk014_tests["negativeFixtureCount"] == 4
assert set(sdk014_tests["reportedFacets"]) == {
    "addition",
    "removal",
    "signature",
    "classification",
    "handle",
    "metadata",
    "dependencies",
}
assert sdk014_tests["jsonSchemaValidation"] == "passed"
assert sdk014_tests["doubleRunByteEquality"] == "passed"
assert sdk014_tests["syntheticTargetProfileIsCompatibilityEvidence"] is False
assert sdk014_tests["outcome"] == "passed"
assert sdk014_receipt["hostedWorkflow"]["job"] == "profile-diff"
assert sdk014_receipt["hostedWorkflow"]["runId"] == 29615026581
assert sdk014_receipt["hostedWorkflow"]["jobId"] == 87998119640
assert sha1.fullmatch(sdk014_receipt["hostedWorkflow"]["commit"])
assert sdk014_receipt["hostedWorkflow"]["status"] == "passed"
assert sdk014_receipt["hostedWorkflow"]["required"] is True
assert sdk014_receipt["claims"]["profileDiffImplementation"] == "generated"
assert sdk014_receipt["claims"]["versionRangeSupport"] == "unsupported"
for unproven_claim in (
    "wordpressRuntimeCompatibility",
    "browserCompatibility",
    "productionSupport",
):
    assert sdk014_receipt["claims"][unproven_claim] == "not-tested"

assert release_policy["schemaVersion"] == 1
assert release_policy["policyId"] == "wordpresshx-release-support-v1"
assert release_policy["decision"] == "ADR-021"
assert release_policy["status"] == "accepted-policy-not-release-ready"
assert release_policy["currentState"]["supportedVersions"] == []
assert release_policy["currentState"]["publicationAllowed"] is False
assert release_policy["currentState"]["stableReleaseAllowed"] is False
assert release_policy["supportTerm"]["defaultDays"] == 180
assert release_policy["securityPolicy"]["numericResponseSlaPromised"] is False
assert release_policy["rollbackPolicy"]["tagOrArtifactOverwriteAllowed"] is False

assert sdk003_receipt["schemaVersion"] == 1
assert sdk003_receipt["receiptId"] == "SDK-003-RELEASE-GOVERNANCE"
assert sdk003_receipt["bead"] == "wordpresshx-sdk-003"
for evidence_subject in sdk003_receipt["subject"].values():
    evidence_path = Path(evidence_subject["path"])
    assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == (
        evidence_subject["sha256"]
    )
assert sdk003_receipt["subject"]["policy"]["path"] == (
    release_policy_path.as_posix()
)
sdk003_report = json.loads(
    Path(sdk003_receipt["subject"]["expectedReport"]["path"]).read_text(
        encoding="utf-8"
    )
)
assert sdk003_report["reportDigest"] == sdk003_receipt["rehearsal"][
    "reportDigest"
]
assert sdk003_report["simulationOnly"] is True
assert sdk003_receipt["implementation"]["supportedVersionCount"] == 0
assert sdk003_receipt["implementation"]["publicationAllowed"] is False
assert sdk003_receipt["implementation"]["defaultStableSupportDays"] == 180
assert sdk003_receipt["implementation"]["versionRangeInferenceAllowed"] is False
assert sdk003_receipt["implementation"]["numericResponseSlaPromised"] is False
assert sdk003_receipt["ownership"]["primary"] == "Marcelo Serpa"
assert sdk003_receipt["ownership"]["backupReleaseSecurity"] == "unassigned"
assert sdk003_receipt["ownership"]["automatedAgentAccountable"] is False
assert sdk003_receipt["securityObservation"]["privateReportingEnabled"] is False
assert sdk003_receipt["rehearsal"]["scenarioCount"] == 4
assert sdk003_receipt["rehearsal"]["simulationOnly"] is True
assert all(
    scenario["outcome"] == "passed"
    for scenario in sdk003_receipt["rehearsal"]["scenarios"]
)
assert sdk003_receipt["releaseBoundary"]["actualReleasePerformed"] is False
assert sdk003_receipt["releaseBoundary"]["registryCredentialsUsed"] is False
assert sdk003_receipt["hostedWorkflow"]["job"] == "release-governance"
assert sdk003_receipt["hostedWorkflow"]["runId"] == 29616315252
assert sdk003_receipt["hostedWorkflow"]["jobId"] == 88002094120
assert sdk003_receipt["hostedWorkflow"]["commit"] == (
    "ee8a2991d6ea1ad49d46708ca26da4e7e09c8dd5"
)
assert sdk003_receipt["hostedWorkflow"]["status"] == "passed"
assert sdk003_receipt["hostedWorkflow"]["fullMatrixStatus"] == "passed"
assert sdk003_receipt["hostedWorkflow"]["required"] is True
assert sdk003_receipt["claims"]["stableReleaseReadiness"] == "blocked"
assert sdk003_receipt["claims"]["supportedVersions"] == "none"
assert sdk003_receipt["claims"]["productionSupport"] == "not-tested"

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
python3 scripts/profiles/test-profile-diff.py
python3 scripts/release/test-governance.py
python3 scripts/licenses/test-license-policy.py
python3 scripts/php/test-emission-policy.py
python3 scripts/source-correlation/validate-contracts.py
python3 scripts/docker/check-image-lock.py
python3 scripts/gates/test-g0-baseline.py
python3 packages/gutenberg/scripts/verify-dependency-lock.py --metadata-only

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
