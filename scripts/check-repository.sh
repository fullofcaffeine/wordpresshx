#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  .gitleaks.toml
  .github/workflows/adoption-contract.yml
  .github/workflows/output-context.yml
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
  docs/adr/006-semantic-plan-and-emitter-contract.md
  docs/adr/007-generated-artifact-ownership.md
  docs/adr/008-profile-generation-and-api-classification.md
  docs/adr/009-schema-and-codec-authority.md
  docs/adr/011-hxx-parser-and-lowering-architecture.md
  docs/adr/012-output-context-safety.md
  docs/adr/013-genes-ts-output-and-wordpress-build-integration.md
  docs/adr/014-source-maps-and-php-trace-correlation.md
  docs/adr/015-interop-and-adoption-contract-format.md
  docs/adr/016-project-and-cli-configuration.md
  docs/adr/017-generated-output-version-control-policy.md
  docs/adr/020-licensing-and-generated-output.md
  docs/adr/021-release-and-support-policy.md
  docs/gates/README.md
  docs/gates/g0-product-authority-and-baseline.md
  docs/architecture/browser-compiler.md
  docs/architecture/build-and-dev-loop.md
  docs/architecture/haxe-first-site-authoring.md
  docs/architecture/php-compiler.md
  docs/architecture/repository-layout.md
  docs/php-source-correlation.md
  docs/product/README.md
  docs/release/README.md
  docs/release/release-checklist.md
  docs/release/rollback-checklist.md
  packages/README.md
  packages/contracts/README.md
  packages/contracts/test.hxml
  packages/contracts/src/wordpress/hx/contracts/CanonicalWireJson.hx
  packages/contracts/src/wordpress/hx/contracts/ContractCodec.hx
  packages/contracts/src/wordpress/hx/contracts/ContractError.hx
  packages/contracts/src/wordpress/hx/contracts/ContractRuleSet.hx
  packages/contracts/src/wordpress/hx/contracts/ContractValidator.hx
  packages/contracts/src/wordpress/hx/contracts/DecodeResult.hx
  packages/contracts/src/wordpress/hx/contracts/NoContractRules.hx
  packages/contracts/src/wordpress/hx/contracts/NullableValue.hx
  packages/contracts/src/wordpress/hx/contracts/Presence.hx
  packages/contracts/src/wordpress/hx/contracts/RuleEvaluation.hx
	packages/contracts/src/wordpress/hx/contracts/UnicodeScalarOrder.hx
  packages/contracts/src/wordpress/hx/contracts/WireKind.hx
  packages/contracts/src/wordpress/hx/contracts/WireValue.hx
  packages/contracts/src/wordpress/hx/contracts/schema/FieldDefault.hx
	packages/contracts/src/wordpress/hx/contracts/schema/FieldDefaults.hx
  packages/contracts/src/wordpress/hx/contracts/schema/FieldRequirement.hx
  packages/contracts/src/wordpress/hx/contracts/schema/FrozenList.hx
	packages/contracts/src/wordpress/hx/contracts/schema/FrozenWireField.hx
	packages/contracts/src/wordpress/hx/contracts/schema/FrozenWireValue.hx
	packages/contracts/src/wordpress/hx/contracts/schema/FrozenWireValueTools.hx
  packages/contracts/src/wordpress/hx/contracts/schema/MigrationRef.hx
  packages/contracts/src/wordpress/hx/contracts/schema/RuleId.hx
  packages/contracts/src/wordpress/hx/contracts/schema/RuleParity.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaCase.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaDocument.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaField.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaId.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaInvariant.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaJson.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaNode.hx
  packages/contracts/src/wordpress/hx/contracts/schema/SchemaRuleRef.hx
  packages/contracts/src/wordpress/hx/contracts/schema/UnknownFieldPolicy.hx
  packages/contracts/test/wordpress/hx/contracts/tests/SchemaAuthorityTest.hx
  packages/contracts/test-negative/domain_mismatch/Main.hx
  packages/contracts/test-negative/null_is_missing/Main.hx
	packages/contracts/test-negative/raw_null/wordpress/hx/contracts/negative/RawNullMain.hx
	packages/contracts/test-negative/frozen_default_mutation/wordpress/hx/contracts/negative/FrozenDefaultMutationMain.hx
  packages/cli/.haxerc
  packages/cli/.npmignore
  packages/cli/README.md
  packages/cli/dependency-lock.json
  packages/cli/haxe_libraries/genes-ts.hxml
  packages/cli/haxe_libraries/helder.set.hxml
  packages/cli/haxe_libraries/hxnodejs.hxml
  packages/cli/package-lock.json
  packages/cli/package.json
  packages/cli/browser-tooling/build.mjs
  packages/cli/browser-tooling/package-lock.json
  packages/cli/browser-tooling/package.json
  packages/cli/browser-tooling/runtime.mjs
  packages/cli/profiles/browser-correlation.hxml
  packages/cli/profiles/classic.hxml
  packages/cli/profiles/ownership-test.hxml
  packages/cli/profiles/wphx.hxml
  packages/cli/project-api/wordpresshx/WordPress.hx
  packages/cli/scripts/add-node-shebang.py
  packages/cli/scripts/create-browser-trace-mutations.py
  packages/cli/scripts/package-browser-source-correlation.py
  packages/cli/scripts/test-browser-source-correlation.sh
  packages/cli/scripts/test.sh
  packages/cli/scripts/verify-browser-source-correlation.py
  packages/cli/scripts/verify-dependency-lock.py
  packages/cli/scripts/verify-php-trace.py
  packages/cli/src/wordpresshx/cli/BrowserTraceEngine.hx
  packages/cli/src/wordpresshx/cli/CanonicalJson.hx
  packages/cli/src/wordpresshx/cli/CliArguments.hx
  packages/cli/src/wordpresshx/cli/CliEventStream.hx
  packages/cli/src/wordpresshx/cli/CliFailure.hx
  packages/cli/src/wordpresshx/cli/CliInvocation.hx
  packages/cli/src/wordpresshx/cli/Content.hx
  packages/cli/src/wordpresshx/cli/Contract.hx
  packages/cli/src/wordpresshx/cli/Main.hx
  packages/cli/src/wordpresshx/cli/NodeGlobals.hx
  packages/cli/src/wordpresshx/cli/PhpTraceEngine.hx
  packages/cli/src/wordpresshx/cli/SourceIndex.hx
  packages/cli/src/wordpresshx/cli/SourceMapV3.hx
  packages/cli/src/wordpresshx/cli/TraceCommand.hx
  packages/cli/src/wordpresshx/cli/TraceFailure.hx
  packages/cli/src/wordpresshx/cli/WphxMain.hx
  packages/cli/src/wordpresshx/cli/closedjson/JsonDocument.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputArguments.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputCommands.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputFile.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputGit.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputIgnore.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputLockIdentity.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputManifest.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputPolicy.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputProcess.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputProject.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputReceipt.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputRequest.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputRoot.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputTree.hx
  packages/cli/src/wordpresshx/cli/generatedoutput/GeneratedOutputWorkflow.hx
  packages/cli/src/wordpresshx/cli/ownership/ArtifactOwner.hx
  packages/cli/src/wordpresshx/cli/ownership/OwnershipContract.hx
  packages/cli/src/wordpresshx/cli/ownership/OwnershipFailure.hx
  packages/cli/src/wordpresshx/cli/ownership/OwnershipJson.hx
  packages/cli/src/wordpresshx/cli/ownership/OwnershipLayout.hx
  packages/cli/src/wordpresshx/cli/ownership/OwnershipResult.hx
  packages/cli/src/wordpresshx/cli/ownership/StageValidator.hx
  packages/cli/src/wordpresshx/cli/project/BuildPublisher.hx
  packages/cli/src/wordpresshx/cli/project/CompilerRunner.hx
  packages/cli/src/wordpresshx/cli/project/DeterministicZip.hx
  packages/cli/src/wordpresshx/cli/project/DeterministicZipEntry.hx
  packages/cli/src/wordpresshx/cli/project/DevEngine.hx
  packages/cli/src/wordpresshx/cli/project/Doctor.hx
  packages/cli/src/wordpresshx/cli/project/EffectiveInputs.hx
  packages/cli/src/wordpresshx/cli/project/Inspector.hx
  packages/cli/src/wordpresshx/cli/project/OwnershipPaths.hx
  packages/cli/src/wordpresshx/cli/project/OwnershipPreflight.hx
  packages/cli/src/wordpresshx/cli/project/PreparedArtifact.hx
  packages/cli/src/wordpresshx/cli/project/PreparedGeneration.hx
  packages/cli/src/wordpresshx/cli/project/PluginArtifactLane.hx
  packages/cli/src/wordpresshx/cli/project/PluginArtifactPermissions.hx
  packages/cli/src/wordpresshx/cli/project/PluginBuildPublisher.hx
  packages/cli/src/wordpresshx/cli/project/PluginCompilationRegistry.hx
  packages/cli/src/wordpresshx/cli/project/PluginEmission.hx
  packages/cli/src/wordpresshx/cli/project/PluginEmittedFile.hx
  packages/cli/src/wordpresshx/cli/project/PluginEmitter.hx
  packages/cli/src/wordpresshx/cli/project/PluginLockIdentity.hx
  packages/cli/src/wordpresshx/cli/project/PluginLockReader.hx
  packages/cli/src/wordpresshx/cli/project/PluginMacroInvocation.hx
  packages/cli/src/wordpresshx/cli/project/PluginMacroRuntime.hx
  packages/cli/src/wordpresshx/cli/project/PluginPlan.hx
  packages/cli/src/wordpresshx/cli/project/PluginPlanReader.hx
  packages/cli/src/wordpresshx/cli/project/PluginPhpQuality.hx
  packages/cli/src/wordpresshx/cli/project/PluginPhpQualityResult.hx
  packages/cli/src/wordpresshx/cli/project/PluginPrivatePhpProfile.hx
  packages/cli/src/wordpresshx/cli/project/PluginPrivateRuntime.hx
  packages/cli/src/wordpresshx/cli/project/PluginPrivateRuntimeCompiler.hx
  packages/cli/src/wordpresshx/cli/project/PluginPrivateRuntimeIdentity.hx
  packages/cli/src/wordpresshx/cli/project/PluginPrivateTitleFilter.hx
  packages/cli/src/wordpresshx/cli/project/PluginProjectBuild.hx
  packages/cli/src/wordpresshx/cli/project/ManagedCompiler.hx
  packages/cli/src/wordpresshx/cli/project/ProjectBuild.hx
  packages/cli/src/wordpresshx/cli/project/ProjectBuildResult.hx
  packages/cli/src/wordpresshx/cli/project/ProjectBootstrap.hx
  packages/cli/src/wordpresshx/cli/project/ProjectCommands.hx
  packages/cli/src/wordpresshx/cli/project/ProjectContext.hx
  packages/cli/src/wordpresshx/cli/project/ProjectContract.hx
  packages/cli/src/wordpresshx/cli/project/ProjectFiles.hx
  packages/cli/src/wordpresshx/cli/project/ProjectJson.hx
  packages/cli/src/wordpresshx/cli/project/ProjectLoader.hx
  packages/cli/src/wordpresshx/cli/project/ProjectOutputRoot.hx
  packages/cli/src/wordpresshx/cli/project/ProjectOwnershipPaths.hx
  packages/cli/src/wordpresshx/cli/project/ReproducibleBuild.hx
  packages/cli/src/wordpresshx/cli/project/ReproduciblePayload.hx
  packages/cli/src/wordpresshx/cli/project/ReproducibleProducts.hx
  packages/cli/src/wordpresshx/cli/project/WatchGraph.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldArguments.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldCommands.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldFile.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldIdentity.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldJson.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldMarker.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldPlan.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldProjection.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldPublisher.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldRenderer.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldRequest.hx
  packages/cli/src/wordpresshx/cli/scaffold/ScaffoldToolchain.hx
  packages/cli/test/ownership/src/sdk041/fixture/Main.hx
  packages/cli/test/browser-source-correlation/src/sdk034/fixture/Main.hx
  packages/cli/test/expected/browser-development.text
  packages/cli/test/expected/browser-production.text
  packages/cli/test/expected/browser-two-stage.text
  packages/cli/test/expected/private.text
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
  packages/gutenberg/editor-tooling/package-lock.json
  packages/gutenberg/editor-tooling/package.json
  packages/gutenberg/build-tooling/package-lock.json
  packages/gutenberg/build-tooling/package.json
  packages/gutenberg/build-tooling/webpack.config.cjs
  packages/gutenberg/profiles/assets-strict.hxml
  packages/gutenberg/profiles/classic.hxml
  packages/gutenberg/profiles/default-dce.hxml
  packages/gutenberg/profiles/differential-classic.hxml
  packages/gutenberg/profiles/differential-common.hxml
  packages/gutenberg/profiles/differential-strict.hxml
  packages/gutenberg/profiles/editor-plugin-strict.hxml
  packages/gutenberg/profiles/hxx-common.hxml
  packages/gutenberg/profiles/hxx-strict.hxml
  packages/gutenberg/profiles/static-block-strict.hxml
  packages/gutenberg/profiles/strict.hxml
  packages/gutenberg/scripts/test-hxx.sh
  packages/gutenberg/scripts/test-differential.sh
  packages/gutenberg/scripts/test-assets.sh
  packages/gutenberg/scripts/test-editor-plugin.sh
  packages/gutenberg/scripts/test-block-metadata.sh
  packages/gutenberg/scripts/test-static-block.sh
  packages/gutenberg/scripts/run-static-block-playwright.mjs
  packages/gutenberg/scripts/run-wordpress-static-block-lane.sh
  packages/gutenberg/scripts/verify-static-block-profile.py
  packages/gutenberg/scripts/verify-static-block-runtime.mjs
  packages/gutenberg/scripts/verify-static-block.mjs
  packages/gutenberg/scripts/run-wordpress-block-metadata-lane.sh
  packages/gutenberg/scripts/verify-block-metadata.py
  packages/gutenberg/scripts/test.sh
  packages/gutenberg/scripts/emit-assets-plugin.py
  packages/gutenberg/scripts/emit-editor-plugin.py
  packages/gutenberg/scripts/run-editor-playwright.mjs
  packages/gutenberg/scripts/run-wordpress-editor-lane.sh
  packages/gutenberg/scripts/run-wordpress-assets-lane.sh
  packages/gutenberg/scripts/verify-assets-profile.py
  packages/gutenberg/scripts/verify-assets.mjs
  packages/gutenberg/scripts/verify-browser-profile.mjs
  packages/gutenberg/scripts/verify-dependency-lock.py
  packages/gutenberg/scripts/verify-differential-profile.py
  packages/gutenberg/scripts/verify-differential.mjs
  packages/gutenberg/scripts/verify-editor-profile.py
  packages/gutenberg/scripts/verify-editor.mjs
  packages/gutenberg/scripts/verify-hxx-profile.py
  packages/gutenberg/scripts/verify-hxx.mjs
  packages/gutenberg/src/wordpress/hx/gutenberg/browser/BrowserExport.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/browser/BrowserNode.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/AttributeRole.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/AttributeSource.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/Block.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/BlockAlignment.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/BlockCategory.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/BlockElementProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/BlockProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/EditAttributes.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/EditProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/PlainText.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/PlainTextProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/SaveProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/StaticBlock.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockAttributeDeriver.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockBuilder.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockEmitter.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockInputs.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockJson.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockModel.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/block/_internal/BlockOptions.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/Button.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/ButtonProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/Notice.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/NoticeProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/PanelBody.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/PanelBodyProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/ToggleControl.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/components/ToggleControlProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/CurrentPost.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/EditorPlugins.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/PluginName.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/PluginSidebar.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/PluginSidebarMoreMenuItem.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/PluginSidebarMoreMenuItemProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/PluginSidebarProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/PostTypeName.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/editor/SidebarName.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/html/HtmlProps.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/hxx/BrowserHxx.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/hxx/_internal/BrowserHxxLowerer.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/hxx/_internal/BrowserHxxProfile.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/i18n/I18n.hx
  packages/gutenberg/src/wordpress/hx/gutenberg/profile/wp70-release.browser-assets.json
  packages/gutenberg/src/wordpress/hx/gutenberg/profile/wp70-release.block-metadata.json
  packages/gutenberg/src/wordpress/hx/gutenberg/profile/wp70-release.static-block.browser-hxx.json
  packages/gutenberg/src/wordpress/hx/gutenberg/profile/wp70-release.editor-plugin.browser-hxx.json
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
  packages/gutenberg/test-negative-editor/invalid_plugin_name/Main.hx
  packages/gutenberg/test-negative-editor/missing_sidebar_title/Main.hx
  packages/gutenberg/test-negative-editor/private_component/Main.hx
  packages/gutenberg/test-negative-editor/wrong_identity_kind/Main.hx
  packages/gutenberg/test/consumer/consumer.ts
  packages/gutenberg/test/consumer/ordinary-consumer.mjs
  packages/gutenberg/test/differential-consumer/consumer.ts
  packages/gutenberg/test/differential-fixture/src/sdk035/fixture/DifferentialApi.hx
  packages/gutenberg/test/differential-fixture/src/sdk035/fixture/Main.hx
  packages/gutenberg/test/differential-runtime/run.mjs
  packages/gutenberg/test/editor-plugin-fixture/src/sdk063/fixture/EditorStyles.hx
  packages/gutenberg/test/editor-plugin-fixture/src/sdk063/fixture/Main.hx
  packages/gutenberg/test/editor-plugin-runtime/setup.php
  packages/gutenberg/test/expected/browser-profile.json
  packages/gutenberg/test/expected/differential.json
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
  packages/gutenberg/test/block-metadata-fixture/README.md
  packages/gutenberg/test/block-metadata-fixture/assets.manifest.json
  packages/gutenberg/test/expected/block-metadata.json
  packages/gutenberg/test/block-metadata-fixture/src/sdk060/fixture/Main.hx
  packages/gutenberg/test/block-metadata-runtime/native-wordpress-oracle.php
  packages/gutenberg/test/static-block-fixture/README.md
  packages/gutenberg/test/static-block-fixture/src/sdk061/fixture/CalloutBlock.hx
  packages/gutenberg/test/static-block-fixture/src/sdk061/fixture/Main.hx
  packages/gutenberg/test/static-block-runtime/setup.php
  packages/gutenberg/test/static-block-runtime/wordpresshx-sdk061-static-block.php
  packages/gutenberg/test/expected/static-block.json
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
  schemas/contract-schema.schema.json
  schemas/profile.schema.json
  schemas/profile-diff.schema.json
  schemas/php-haxe-map.schema.json
  schemas/semantic-emission.schema.json
  schemas/semantic-nodes/hook.schema.json
  schemas/semantic-nodes/module.schema.json
  schemas/semantic-plan.schema.json
  schemas/semantic-collector-config.schema.json
  schemas/semantic-collector-inputs.schema.json
  schemas/generated-files.schema.json
  schemas/generated-output-vcs-project.schema.json
  schemas/generated-output-vcs-result.schema.json
  schemas/reproducible-build.schema.json
  schemas/ownership-transaction-journal.schema.json
  schemas/project.schema.json
  schemas/project-lock.schema.json
  schemas/scaffold-plan.schema.json
  schemas/effective-inputs.schema.json
  schemas/cli-event.schema.json
  schemas/source-correlation-index.schema.json
  schemas/adoption-contract.schema.json
  schemas/adoption-capability.schema.json
  schemas/adoption-review.schema.json
  scripts/source-correlation/validate-contracts.py
  scripts/source-correlation/validate-sdk025.py
  scripts/semantic-plan/test-contract.py
  scripts/semantic-plan/test.sh
  scripts/contracts/test-schema-authority.sh
  scripts/contracts/validate-schema-authority.py
  scripts/output-context/test-wordpress.sh
  scripts/output-context/test.sh
  scripts/output-context/validate-architecture.py
  scripts/adoption/test.sh
  scripts/adoption/validate-architecture.py
  scripts/semantic-collector/test-contract.py
  scripts/semantic-collector/test.sh
  scripts/generated-output-vcs/check-policy.py
  scripts/generated-output-vcs/test-production-integration.py
  scripts/generated-output-vcs/test-policy.py
  scripts/ownership/test-adr-contract.sh
  scripts/ownership/check-isolation.py
  scripts/ownership/test-emitted-isolation.py
  scripts/ownership/test-contract.py
  scripts/ownership/test-production.py
  scripts/ownership/test.sh
  scripts/determinism/compare-builds.py
  scripts/determinism/test-production.py
  scripts/determinism/test-production.sh
  scripts/dev-loop/test-production.py
  scripts/dev-loop/test-production.sh
  scripts/project-cli/test-contract.py
  scripts/project-cli/test-production.py
  scripts/project-cli/test-production.sh
  scripts/project-cli/test.sh
  scripts/scaffold/test-production.py
  scripts/scaffold/test-production.sh
  scripts/scaffold/plugin-native-caller.php
  scripts/scaffold/plugin-private-caller.php
  scripts/scaffold/plugin-private-cold-boot.php
  scripts/scaffold/plugin-private-conflict.php
  scripts/scaffold/plugin-private-wordpress.php
  scripts/scaffold/test-plugin-production.py
  scripts/scaffold/test-plugin-private-wordpress.sh
  scripts/scaffold/test-plugin-wordpress.sh
  scripts/runtime-support/build-fixtures.py
  scripts/runtime-support/check-policy.py
  scripts/runtime-support/test-policy.py
  scripts/runtime-support/test-runtime.py
  scripts/runtime-support/test-php-matrix.sh
  scripts/runtime-support/test-production.sh
  scripts/runtime-support/test-wordpress.sh
  scripts/runtime-support/test.sh
  tools/README.md
  examples/README.md
  fixtures/README.md
  fixtures/semantic-plan/README.md
  fixtures/semantic-plan/expected/acme-observatory.php.txt
  fixtures/semantic-plan/src/SemanticPlanFixture.hx
  fixtures/semantic-plan/valid/minimal-plugin.emission.json
  fixtures/semantic-plan/valid/minimal-plugin.json
  fixtures/semantic-collector/README.md
  fixtures/semantic-collector/assets/brand.txt
  fixtures/semantic-collector/config.json
  fixtures/semantic-collector/src/fixtures/semanticcollector/InvalidFixture.hx
  fixtures/semantic-collector/src/fixtures/semanticcollector/ValidFixture.hx
  fixtures/generated-output-vcs/README.md
  fixtures/generated-output-vcs/committed-output-policy.json
  fixtures/generated-output-vcs/project/.gitignore
  fixtures/generated-output-vcs/project/src/acme/site/Site.hx
  fixtures/generated-output-vcs/project/wordpress-hx.fixture-lock.json
  fixtures/ownership/README.md
  fixtures/ownership/artifacts/initial/acme-observatory.php.txt
  fixtures/ownership/artifacts/initial/stale.php.txt
  fixtures/ownership/artifacts/next/acme-observatory.php.txt
  fixtures/ownership/artifacts/next/theme.json.txt
  fixtures/ownership/valid/current.generated-files.json
  fixtures/ownership/valid/next.generated-files.json
  fixtures/ownership/valid/prepared.journal.json
  fixtures/project-cli/README.md
  fixtures/project-cli/project/.haxerc
  fixtures/project-cli/project/.wphx/bootstrap/project.hxml
  fixtures/project-cli/project/.wphx/project.lock.json
  fixtures/project-cli/project/assets/brand.txt
  fixtures/project-cli/project/npm-lock.json
  fixtures/project-cli/project/npm-manifest.json
  fixtures/project-cli/project/src/acme/site/Site.hx
  fixtures/project-cli/project/test/acme/site/SiteTest.hx
  fixtures/project-cli/project/wordpress-hx.json
  fixtures/project-cli/valid/build-dry-run.events.jsonl
  fixtures/project-cli/valid/dev.events.jsonl
  fixtures/project-cli/valid/effective-inputs.json
  fixtures/runtime-support-packaging/README.md
  fixtures/runtime-support-packaging/runtime/cli-probe.php
  fixtures/runtime-support-packaging/runtime/cold-boot.php
  fixtures/runtime-support-packaging/runtime/conflict-probe.php
  fixtures/runtime-support-packaging/runtime/wordpress-probe.php
  fixtures/runtime-support-packaging/src/fixture/privateimpl/Main.hx
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
  fixtures/schema-codec/expected/cross-target.txt
  fixtures/output-context/README.md
  fixtures/output-context/expected/context-plan.txt
  fixtures/output-context/runtime/browser.mjs
  fixtures/output-context/runtime/wordpress-probe.php
  fixtures/output-context/src/wordpress/hx/output/prototype/Output.hx
  fixtures/output-context/src/wordpress/hx/output/prototype/OutputSinks.hx
  fixtures/output-context/test/Main.hx
  fixtures/output-context/test-negative/css_from_string/Main.hx
  fixtures/output-context/test-negative/direct_terminal_construction/Main.hx
  fixtures/output-context/test-negative/json_as_script/Main.hx
  fixtures/output-context/test-negative/kses_as_compiler_markup/Main.hx
  fixtures/output-context/test-negative/plain_as_rich_html/Main.hx
  fixtures/output-context/test-negative/script_as_rest/Main.hx
  fixtures/output-context/test-negative/text_as_attribute/Main.hx
  fixtures/output-context/test-negative/url_as_text/Main.hx
  fixtures/adoption-contract/README.md
  fixtures/adoption-contract/contract/acme-calendar.capability.json
  fixtures/adoption-contract/contract/acme-calendar.contract.json
  fixtures/adoption-contract/contract/acme-calendar.review.json
  fixtures/adoption-contract/expected/capability-plan.txt
  fixtures/adoption-contract/inputs/generator.txt
  fixtures/adoption-contract/inputs/index.d.ts
  fixtures/adoption-contract/inputs/package-metadata.json
  fixtures/adoption-contract/inputs/plugin.php
  fixtures/adoption-contract/inputs/provider-stubs.php
  fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/AcmeCalendar.hx
  fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/Adoption.hx
  fixtures/adoption-contract/test/Main.hx
  fixtures/adoption-contract/test-negative/cross_request_scope/Main.hx
  fixtures/adoption-contract/test-negative/direct_token_construction/Main.hx
  fixtures/adoption-contract/test-negative/omitted_binding/Main.hx
  fixtures/adoption-contract/test-negative/wrong_capability/Main.hx
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
  manifests/semantic-plan-architecture.json
  manifests/schema-codec-architecture.json
  manifests/output-context-architecture.json
  manifests/adoption-contract-architecture.json
  manifests/semantic-collector-architecture.json
  manifests/generated-artifact-ownership.json
  manifests/generated-output-vcs-policy.json
  manifests/generated-output-vcs-implementation.json
  manifests/deterministic-build-implementation.json
  manifests/dev-loop-implementation.json
  manifests/plugin-development-implementation.json
  manifests/ownership-implementation.json
  manifests/project-cli-architecture.json
  manifests/project-cli-implementation.json
  manifests/plugin-scaffold-implementation.json
  manifests/php-quality-implementation.json
  manifests/private-runtime-implementation.json
  manifests/scaffold-implementation.json
  manifests/package-topology.json
  manifests/php-emission-policy.json
  manifests/runtime-support-packaging.json
  manifests/release-support-policy.json
  manifests/toolchain.lock.json
  manifests/upstream.lock.json
  manifests/evidence/g0-product-baseline.json
  manifests/evidence/sdk-003-release-governance.json
  manifests/evidence/adr-020-license-audit-preparation.json
  manifests/evidence/adr-006-semantic-plan-contract.json
	manifests/evidence/adr-009-schema-codec-authority.json
  manifests/evidence/adr-012-output-context-safety.json
  manifests/evidence/adr-015-interop-adoption-contract.json
  manifests/evidence/adr-018-runtime-support-packaging.json
  manifests/evidence/sdk-040-semantic-collector.json
  manifests/evidence/adr-007-generated-artifact-ownership.json
  manifests/evidence/adr-017-generated-output-vcs-policy.json
  manifests/evidence/sdk-041-ownership-transaction.json
  manifests/evidence/adr-016-project-cli-configuration.json
  manifests/evidence/sdk-043-project-cli.json
  manifests/evidence/sdk-044-dev-loop.json
  manifests/evidence/sdk-044-inferred-plugin-development.json
  manifests/evidence/sdk-045-scaffold.json
  manifests/evidence/sdk-045-plugin-scaffold.json
  manifests/evidence/sdk-045-generated-output-vcs.json
  manifests/evidence/sdk-042-deterministic-build.json
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
  manifests/evidence/sdk-034-browser-source-correlation.json
  manifests/evidence/sdk-035-classic-genes-differential.json
  manifests/evidence/sdk-063-editor-plugin-slotfill.json
  manifests/evidence/sdk-064-typed-data-store.json
  manifests/evidence/sdk-060-typed-block-metadata.json
  manifests/evidence/sdk-061-static-block.json
  manifests/evidence/g2.4-wordpress-scripts-source-correlation.json
  manifests/evidence/sdk-020-reflaxe-php-bootstrap.json
  manifests/evidence/sdk-021-php-ir-printer.json
  manifests/evidence/sdk-027-generic-php-compiler-readiness.json
  manifests/evidence/strict-haxe-migration.json
  manifests/evidence/sdk-022-wordpress-public-php-profile.json
  manifests/evidence/sdk-023-wordpress-public-php-adapters.json
  manifests/evidence/sdk-024-private-php-runtime.json
  manifests/evidence/sdk-025-php-source-correlation.json
  manifests/evidence/sdk-026-generated-php-quality.json
  manifests/evidence/sdk-080-hxx-parser-prototype.json
  packages/build/README.md
  packages/build/src/wordpress/hx/build/SemanticPlan.hx
  packages/build/src/wordpress/hx/build/_internal/CanonicalJson.hx
  packages/build/src/wordpress/hx/build/_internal/SemanticCollector.hx
  packages/build/src/wordpress/hx/build/semantic/BuildInput.hx
  packages/build/src/wordpress/hx/build/semantic/BuildInputDeclaration.hx
  packages/build/src/wordpress/hx/build/semantic/Hook.hx
  packages/build/src/wordpress/hx/build/semantic/HookDeclaration.hx
  packages/build/src/wordpress/hx/build/semantic/HookOptions.hx
  packages/build/src/wordpress/hx/build/semantic/Module.hx
  packages/build/src/wordpress/hx/build/semantic/ModuleDeclaration.hx
  packages/build/src/wordpress/hx/build/semantic/ModuleOptions.hx
  packages/build/src/wordpress/hx/build/semantic/PublicEnvironmentOptions.hx
  packages/build/src/wordpress/hx/build/semantic/ResourceOptions.hx
  docs/architecture/build-and-dev-loop.md
  compiler/reflaxe.php/CHANGELOG.md
  compiler/reflaxe.php/EXTRACTION.md
  compiler/reflaxe.php/haxelib.json
  compiler/reflaxe.php/provenance.json
  compiler/reflaxe.php/scripts/build-package.py
  compiler/reflaxe.php/scripts/test-package-builder.py
  compiler/reflaxe.php/scripts/test-package.sh
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpArrayEntry.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpClass.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpClassKind.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpClosureCapture.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpDeclaration.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpDocParameter.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpDocType.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpExpr.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpFile.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpFunction.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpIdentifier.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpMethod.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpMethodDoc.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpParameter.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpProperty.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpQualifiedName.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpSourceRange.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpSourceFile.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpSourceKind.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpSourcePosition.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpStableId.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpStmt.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpType.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpVisibility.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpPrinter.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpRenderedDeclaration.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpRenderedFile.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpRenderedMapping.hx
  compiler/reflaxe.php/src/reflaxe/php/map/PhpCanonicalJson.hx
  compiler/reflaxe.php/src/reflaxe/php/map/PhpRangeMapConfig.hx
  compiler/reflaxe.php/src/reflaxe/php/map/PhpRangeMapWriter.hx
  compiler/reflaxe.php/test/fixtures/SourceFixture.hx
  compiler/reflaxe.php/test/package-consumer/build.hxml
  compiler/reflaxe.php/test/package-consumer/expected.stdout
  compiler/reflaxe.php/test/package-consumer/src/Main.hx
  compiler/reflaxe.php/test/reflaxe/php/tests/PrinterTest.hx
  compiler/reflaxe.php/scripts/test-php-matrix.sh
  compiler/reflaxe.php/scripts/test.sh
  compiler/wordpress/README.md
  compiler/wordpress/runtime/activate-plugin.php
  compiler/wordpress/runtime/native-adapter-caller.php
  compiler/wordpress/runtime/native-caller.php
  compiler/wordpress/runtime/probe-adapters.php
  compiler/wordpress/runtime/probe-plugin.php
  compiler/wordpress/runtime/probe-source-correlation.php
  compiler/wordpress/runtime/source-correlation-caller.php
  compiler/wordpress/scripts/package-source-correlation.py
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
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPhpRangeMapWriter.hx
  compiler/wordpress/src/wordpress/hx/compiler/php/profile/WordPressPhpSourceIndexWriter.hx
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
  compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx
  compiler/wordpress/test/fixtures/SourceCorrelationFixture.hx
  compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/WordPressPhpProfileTest.hx
  compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/WordPressSourceCorrelationTest.hx
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
  scripts/php-quality/expose-runtime.sh
  scripts/php-quality/install.sh
  scripts/php-quality/test-production.sh
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
  tooling/php-quality/README.md
  tooling/php-quality/composer.json
  tooling/php-quality/composer.lock
  tooling/php-quality/phpcs-compat-private.xml
  tooling/php-quality/phpcs-compat.xml
  tooling/php-quality/phpcs-public.xml
  tooling/php-quality/phpstan-private.neon
  tooling/php-quality/phpstan-public.neon
  tooling/php-quality/run.php
  tooling/php-quality/toolchain.json
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
sdk025_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-025-php-source-correlation.json"
    ).read_text(encoding="utf-8")
)
php_quality_implementation = json.loads(
    Path("manifests/php-quality-implementation.json").read_text(encoding="utf-8")
)
sdk026_receipt = json.loads(
    Path("manifests/evidence/sdk-026-generated-php-quality.json").read_text(
        encoding="utf-8"
    )
)
sdk027_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-027-generic-php-compiler-readiness.json"
    ).read_text(encoding="utf-8")
)
strict_haxe_migration = json.loads(
    Path("manifests/evidence/strict-haxe-migration.json").read_text(
        encoding="utf-8"
    )
)
php_quality_toolchain = json.loads(
    Path("tooling/php-quality/toolchain.json").read_text(encoding="utf-8")
)
php_quality_composer_lock = json.loads(
    Path("tooling/php-quality/composer.lock").read_text(encoding="utf-8")
)
runtime_support_architecture = json.loads(
    Path("manifests/runtime-support-packaging.json").read_text(encoding="utf-8")
)
adr018_receipt = json.loads(
    Path(
        "manifests/evidence/adr-018-runtime-support-packaging.json"
    ).read_text(encoding="utf-8")
)
private_runtime_implementation = json.loads(
    Path("manifests/private-runtime-implementation.json").read_text(
        encoding="utf-8"
    )
)
sdk024_receipt = json.loads(
    Path("manifests/evidence/sdk-024-private-php-runtime.json").read_text(
        encoding="utf-8"
    )
)
sdk034_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-034-browser-source-correlation.json"
    ).read_text(encoding="utf-8")
)
g24_receipt = json.loads(
    Path(
        "manifests/evidence/g2.4-wordpress-scripts-source-correlation.json"
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
semantic_plan_architecture = json.loads(
    Path("manifests/semantic-plan-architecture.json").read_text(
        encoding="utf-8"
    )
)
semantic_plan_receipt = json.loads(
    Path("manifests/evidence/adr-006-semantic-plan-contract.json").read_text(
        encoding="utf-8"
    )
)
schema_codec_architecture = json.loads(
    Path("manifests/schema-codec-architecture.json").read_text(encoding="utf-8")
)
adr009_receipt = json.loads(
    Path("manifests/evidence/adr-009-schema-codec-authority.json").read_text(
        encoding="utf-8"
    )
)
output_context_architecture = json.loads(
    Path("manifests/output-context-architecture.json").read_text(
        encoding="utf-8"
    )
)
adr012_receipt = json.loads(
    Path("manifests/evidence/adr-012-output-context-safety.json").read_text(
        encoding="utf-8"
    )
)
adoption_architecture = json.loads(
    Path("manifests/adoption-contract-architecture.json").read_text(
        encoding="utf-8"
    )
)
adr015_receipt = json.loads(
    Path("manifests/evidence/adr-015-interop-adoption-contract.json").read_text(
        encoding="utf-8"
    )
)
semantic_collector_architecture = json.loads(
    Path("manifests/semantic-collector-architecture.json").read_text(
        encoding="utf-8"
    )
)
semantic_collector_receipt = json.loads(
    Path("manifests/evidence/sdk-040-semantic-collector.json").read_text(
        encoding="utf-8"
    )
)
ownership_architecture = json.loads(
    Path("manifests/generated-artifact-ownership.json").read_text(
        encoding="utf-8"
    )
)
ownership_receipt = json.loads(
    Path(
        "manifests/evidence/adr-007-generated-artifact-ownership.json"
    ).read_text(encoding="utf-8")
)
ownership_implementation = json.loads(
    Path("manifests/ownership-implementation.json").read_text(encoding="utf-8")
)
sdk041_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-041-ownership-transaction.json"
    ).read_text(encoding="utf-8")
)
project_cli_architecture = json.loads(
    Path("manifests/project-cli-architecture.json").read_text(encoding="utf-8")
)
project_cli_receipt = json.loads(
    Path(
        "manifests/evidence/adr-016-project-cli-configuration.json"
    ).read_text(encoding="utf-8")
)
project_cli_implementation = json.loads(
    Path("manifests/project-cli-implementation.json").read_text(
        encoding="utf-8"
    )
)
sdk043_receipt = json.loads(
    Path("manifests/evidence/sdk-043-project-cli.json").read_text(
        encoding="utf-8"
    )
)
dev_loop_implementation = json.loads(
    Path("manifests/dev-loop-implementation.json").read_text(
        encoding="utf-8"
    )
)
sdk044_receipt = json.loads(
    Path("manifests/evidence/sdk-044-dev-loop.json").read_text(
        encoding="utf-8"
    )
)
plugin_development_implementation = json.loads(
    Path("manifests/plugin-development-implementation.json").read_text(
        encoding="utf-8"
    )
)
sdk044_plugin_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-044-inferred-plugin-development.json"
    ).read_text(encoding="utf-8")
)
scaffold_implementation = json.loads(
    Path("manifests/scaffold-implementation.json").read_text(
        encoding="utf-8"
    )
)
plugin_scaffold_implementation = json.loads(
    Path("manifests/plugin-scaffold-implementation.json").read_text(
        encoding="utf-8"
    )
)
sdk045_receipt = json.loads(
    Path("manifests/evidence/sdk-045-scaffold.json").read_text(
        encoding="utf-8"
    )
)
sdk045_plugin_receipt = json.loads(
    Path("manifests/evidence/sdk-045-plugin-scaffold.json").read_text(
        encoding="utf-8"
    )
)
deterministic_build_implementation = json.loads(
    Path("manifests/deterministic-build-implementation.json").read_text(
        encoding="utf-8"
    )
)
sdk042_receipt = json.loads(
    Path("manifests/evidence/sdk-042-deterministic-build.json").read_text(
        encoding="utf-8"
    )
)
cli_dependency_lock = json.loads(
    Path("packages/cli/dependency-lock.json").read_text(encoding="utf-8")
)
sdk034_profile_path = Path("packages/cli/profiles/browser-correlation.hxml")
sdk034_tooling_manifest_path = Path(
    "packages/cli/browser-tooling/package.json"
)
sdk034_tooling_lock_path = Path(
    "packages/cli/browser-tooling/package-lock.json"
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
sdk035_expected_path = Path(
    "packages/gutenberg/test/expected/differential.json"
)
sdk035_expected = json.loads(
    sdk035_expected_path.read_text(encoding="utf-8")
)
sdk035_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-035-classic-genes-differential.json"
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
sdk060_profile_path = Path(
    "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
    "wp70-release.block-metadata.json"
)
sdk060_profile = json.loads(sdk060_profile_path.read_text(encoding="utf-8"))
sdk060_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-060-typed-block-metadata.json"
    ).read_text(encoding="utf-8")
)
sdk061_profile_path = Path(
    "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
    "wp70-release.static-block.browser-hxx.json"
)
sdk061_profile = json.loads(sdk061_profile_path.read_text(encoding="utf-8"))
sdk061_receipt = json.loads(
    Path("manifests/evidence/sdk-061-static-block.json").read_text(
        encoding="utf-8"
    )
)
sdk063_profile_path = Path(
    "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
    "wp70-release.editor-plugin.browser-hxx.json"
)
sdk063_profile = json.loads(sdk063_profile_path.read_text(encoding="utf-8"))
sdk063_tooling_manifest_path = Path(
    "packages/gutenberg/editor-tooling/package.json"
)
sdk063_tooling_lock_path = Path(
    "packages/gutenberg/editor-tooling/package-lock.json"
)
sdk063_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-063-editor-plugin-slotfill.json"
    ).read_text(encoding="utf-8")
)
sdk064_profile_path = Path(
    "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
    "wp70-release.data-store.browser-hxx.json"
)
sdk064_profile = json.loads(sdk064_profile_path.read_text(encoding="utf-8"))
sdk064_tooling_manifest_path = Path(
    "packages/gutenberg/editor-tooling/package.json"
)
sdk064_tooling_lock_path = Path(
    "packages/gutenberg/editor-tooling/package-lock.json"
)
sdk064_receipt = json.loads(
    Path(
        "manifests/evidence/sdk-064-typed-data-store.json"
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

assert runtime_support_architecture["schemaVersion"] == 1
assert runtime_support_architecture["decision"] == "ADR-018"
assert runtime_support_architecture["status"] == (
    "accepted-architecture-with-executable-prototype"
)
assert runtime_support_architecture["authoring"]["commonPath"] == (
    "typed-haxe-only"
)
assert runtime_support_architecture["authoring"][
    "userAuthoredRuntimeConfigRequired"
] is False
assert runtime_support_architecture["mvpPackage"][
    "sharedSiteRuntimeAllowed"
] is False
assert runtime_support_architecture["namespace"]["digestBitsRetained"] == 96
assert runtime_support_architecture["namespace"]["userConfigurable"] is False
assert runtime_support_architecture["autoload"][
    "stockFrontControllerPackaged"
] is False
assert runtime_support_architecture["autoload"][
    "processIncludePathMutation"
] is False
assert runtime_support_architecture["composer"]["mvpRuntimeGraph"] == (
    "absent-no-runtime-dependencies"
)
assert runtime_support_architecture["composer"][
    "separateVendorDirectoriesCountAsIsolation"
] is False
assert runtime_support_architecture["publicBoundary"][
    "privateNamesAllowedInPublicAbi"
] is False
assert runtime_support_architecture["globalSymbols"] == {
    "defaultAllowed": False,
    "stockPolyfillException": "exact-inventoried-guarded-matrix-tested-only",
    "admissionByAnalogyAllowed": False,
    "compatibilityConstant": "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256",
    "nativeInternalFunctionAllowed": True,
    "sameExactDeclaringFileHashAllowed": True,
    "differentHashDisposition": "reject-private-boot-WPHX5201",
}
assert runtime_support_architecture["budgets"][
    "serverOnlyStarterGeneratedPhpRuntimeMaxBytes"
] == 409600
assert runtime_support_architecture["budgets"][
    "prototypePrivateClosureReviewMaxBytes"
] == 163840
assert runtime_support_architecture["futureSharedRuntime"][
    "currentDisposition"
] == "forbidden"
assert runtime_support_architecture["evidence"]["productionSupport"] == (
    "not-tested"
)
assert runtime_support_architecture["evidence"]["publicationAuthorized"] is False

assert adr018_receipt["schemaVersion"] == 1
assert adr018_receipt["receiptId"] == "ADR-018-RUNTIME-SUPPORT-PACKAGING"
assert adr018_receipt["bead"] == "wordpresshx-adr-018"
assert adr018_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
for locked_subject in adr018_receipt["subject"].values():
    locked_path = Path(locked_subject["path"])
    assert hashlib.sha256(locked_path.read_bytes()).hexdigest() == (
        locked_subject["sha256"]
    )
adr018_verification = adr018_receipt["verification"]
assert adr018_verification["policyCases"] == {
    "positive": 1,
    "negative": 19,
    "outcome": "passed",
}
assert adr018_verification["determinism"] == {
    "freshBuildCount": 2,
    "byteIdentical": True,
}
assert len(adr018_verification["variants"]) == 2
assert {variant["slug"] for variant in adr018_verification["variants"]} == {
    "runtime-alpha",
    "runtime-beta",
}
for variant in adr018_verification["variants"]:
    assert variant["classmapEntries"] == 14
    assert variant["privatePhpFiles"] == 16
    assert variant["privatePhpBytes"] <= 163840
    assert variant["packagePhpBytes"] <= 409600
    assert variant["globalPolyfillSha256"] == (
        "80f6c2172d93b501328e2c4fa131b81a186ff850e6a437e9068f9e842a6b3237"
    )
    assert re.fullmatch(r"wphx_internal\.p[0-9a-f]{24}", variant["prefix"])
    assert sha256.fullmatch(variant["prefixDerivationSha256"])
    assert sha256.fullmatch(variant["packageTreeSha256"])
assert adr018_verification["localColdBoot"]["sampleCountPerVariant"] == 25
assert adr018_verification["localColdBoot"]["outcome"] == (
    "passed-not-production-claim"
)
assert [lane["version"] for lane in adr018_verification["phpMatrix"]] == [
    "7.4.33",
    "8.4.7",
]
assert adr018_verification["phpMatrix"][0]["image"] == image_lock["images"][
    "php74Floor"
]["reference"]
assert adr018_verification["phpMatrix"][1]["image"] == image_lock["images"][
    "php84Cli"
]["reference"]
assert all(
    lane["twoPluginBehavior"] == "seed:alpha-v1:beta-v2"
    for lane in adr018_verification["phpMatrix"]
)
assert all(
    lane["globalPolyfillMismatch"] == "rejected-before-private-boot-WPHX5201"
    for lane in adr018_verification["phpMatrix"]
)
adr018_wordpress = adr018_verification["wordpressRuntime"]
assert adr018_wordpress["wordpressVersion"] == "7.0"
assert adr018_wordpress["wordpressImage"] == image_lock["images"][
    "wordpress70Php84"
]["reference"]
assert adr018_wordpress["databaseImage"] == image_lock["images"]["mariadb"][
    "reference"
]
assert adr018_wordpress["bothPluginsDiscoveredActivatedAndBooted"] == "passed"
assert adr018_wordpress["twoPluginBehavior"] == "seed:alpha-v1:beta-v2"
assert adr018_verification["stockFrontControllersPackaged"] is False
assert adr018_verification["processIncludePathMutationPackaged"] is False
assert adr018_verification["runtimeComposerArtifacts"] == 0
assert adr018_verification["strictHaxeForbiddenTokens"] == 0
assert adr018_verification["globalPolyfillMismatch"] == (
    "rejected-before-private-boot-WPHX5201"
)
adr018_hosted = adr018_receipt["hostedWorkflow"]
if adr018_receipt["status"] == "implemented-hosted-pending":
    assert adr018_hosted["runId"] is None
    assert adr018_hosted["commit"] is None
    assert adr018_hosted["status"] == "pending-first-main-run"
    assert all(
        job["jobId"] is None and job["status"] == "pending"
        for job in adr018_hosted["jobs"].values()
    )
else:
    assert isinstance(adr018_hosted["runId"], int)
    assert sha1.fullmatch(adr018_hosted["commit"])
    assert adr018_hosted["status"] == "passed"
    assert all(
        isinstance(job["jobId"], int) and job["status"] == "passed"
        for job in adr018_hosted["jobs"].values()
    )
assert adr018_hosted["required"] is True
assert adr018_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert adr018_receipt["referenceReview"][
    "runtimeOrBuildDependencyCreated"
] is False
assert adr018_receipt["referenceReview"]["genesSourceChanged"] is False
assert adr018_receipt["claims"]["architectureDecision"] == "accepted"
assert adr018_receipt["claims"]["sdk024ProductionPrivateLane"] == (
    "not-tested"
)
assert adr018_receipt["claims"]["runtimeComposerDependencies"] == (
    "unsupported"
)
assert adr018_receipt["claims"]["sharedSiteRuntime"] == "forbidden"
assert adr018_receipt["claims"]["globalPolyfillCompatibility"] == (
    "exact-hash-coexistence-and-conflict-rejection-runtime-tested"
)
assert adr018_receipt["claims"]["productionSupport"] == "not-tested"
assert adr018_receipt["claims"]["publicationAuthorized"] is False


def validate_package_subject(subject):
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
    assert len(package_paths) == subject.get(
        "packageFileCount", len(package_paths)
    )
    return package_paths


def verify_historical_package(subject, implementation_commit):
    package_root = Path(subject["path"])
    package_paths = validate_package_subject(subject)
    package_files = subject["packageFiles"]

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


def historical_subject_records(subject):
    records = []

    def collect(value):
        if isinstance(value, dict):
            if set(value) == {"path", "sha256"}:
                assert sha256.fullmatch(value["sha256"])
                records.append(value)
            else:
                for child in value.values():
                    collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)
        else:
            raise AssertionError("historical receipt subject has an open value")

    collect(subject)
    records.sort(key=lambda item: item["path"])
    assert records
    assert len(records) == len({record["path"] for record in records})
    return records


def verify_versioned_subject(receipt):
    verification = receipt["historicalVerification"]
    assert verification == {
        "algorithm": "sha256-lines-of-sha256-two-spaces-path-lf-v1",
        "subjectCommit": verification["subjectCommit"],
        "subjectContentSha256": verification["subjectContentSha256"],
        "depthOneFallback": "self-contained-subject-digest-inventory",
    }
    subject_commit = verification["subjectCommit"]
    assert subject_commit is None or sha1.fullmatch(subject_commit)
    records = historical_subject_records(receipt["subject"])
    material = bytearray()
    for record in records:
        material.extend(
            f"{record['sha256']}  {record['path']}\n".encode()
        )
    assert hashlib.sha256(material).hexdigest() == (
        verification["subjectContentSha256"]
    )
    if subject_commit is None:
        for record in records:
            current_path = Path(record["path"])
            assert current_path.is_file()
            assert hashlib.sha256(current_path.read_bytes()).hexdigest() == (
                record["sha256"]
            )
        return records

    historical_commit_available = subprocess.run(
        ["git", "cat-file", "-e", f"{subject_commit}^{{commit}}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0
    for record in records:
        current_path = Path(record["path"])
        current_matches = (
            current_path.is_file()
            and hashlib.sha256(current_path.read_bytes()).hexdigest()
            == record["sha256"]
        )
        if current_matches:
            continue
        if historical_commit_available:
            content = subprocess.run(
                [
                    "git",
                    "show",
                    f"{subject_commit}:{record['path']}",
                ],
                check=True,
                capture_output=True,
            ).stdout
            assert hashlib.sha256(content).hexdigest() == record["sha256"]
    return records


def verify_historical_ancestry(ancestor_commit, descendant_commit):
    assert sha1.fullmatch(ancestor_commit)
    assert sha1.fullmatch(descendant_commit)
    commits_available = all(
        subprocess.run(
            ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
            check=False,
            capture_output=True,
        ).returncode
        == 0
        for commit in (ancestor_commit, descendant_commit)
    )
    if commits_available:
        assert subprocess.run(
            ["git", "merge-base", "--is-ancestor", ancestor_commit, descendant_commit],
            check=False,
            capture_output=True,
        ).returncode == 0
        return
    shallow = subprocess.run(
        ["git", "rev-parse", "--is-shallow-repository"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    assert shallow == "true"

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

assert semantic_plan_architecture["schemaVersion"] == 1
assert semantic_plan_architecture["decision"] == "ADR-006"
assert semantic_plan_architecture["status"] == (
    "accepted-contract-not-collector-implementation"
)
semantic_contracts = semantic_plan_architecture["contracts"]
semantic_plan_contract = semantic_contracts["plan"]
semantic_emission_contract = semantic_contracts["emission"]
assert semantic_plan_contract["identity"] == "wordpress-hx.semantic-plan.v1"
assert semantic_emission_contract["identity"] == (
    "wordpress-hx.semantic-emission.v1"
)
for contract in (semantic_plan_contract, semantic_emission_contract):
    schema_bytes = Path(contract["schemaPath"]).read_bytes()
    fixture_bytes = Path(contract["fixturePath"]).read_bytes()
    assert hashlib.sha256(schema_bytes).hexdigest() == contract["schemaSha256"]
    assert hashlib.sha256(fixture_bytes).hexdigest() == contract["fixtureSha256"]
semantic_plan_fixture = json.loads(
    Path(semantic_plan_contract["fixturePath"]).read_text(encoding="utf-8")
)
semantic_emission_fixture = json.loads(
    Path(semantic_emission_contract["fixturePath"]).read_text(encoding="utf-8")
)
assert semantic_plan_fixture["planDigest"] == semantic_plan_contract["planDigest"]
assert semantic_emission_fixture["resultDigest"] == semantic_emission_contract[
    "resultDigest"
]
assert semantic_emission_fixture["planDigest"] == semantic_plan_fixture[
    "planDigest"
]
semantic_canonicalization = semantic_plan_architecture["canonicalization"]
assert semantic_canonicalization["identity"] == (
    "wordpress-hx.canonical-json.v1"
)
assert semantic_canonicalization["encoding"] == "utf-8"
assert semantic_canonicalization["unicodeNormalization"] == "NFC"
assert semantic_canonicalization["duplicateKeys"] == "fail"
assert semantic_canonicalization["floatingPointNumbers"] == (
    "forbidden-use-integer-or-domain-string"
)
assert semantic_plan_architecture["sourceLocations"]["absolutePathsAllowed"] is False
assert semantic_plan_architecture["sourceLocations"]["sourceDigestRequired"] is True
assert semantic_plan_architecture["extensions"]["networkSchemaResolution"] is False
assert semantic_plan_architecture["extensions"]["silentIgnore"] is False
assert semantic_plan_architecture["extensions"]["runtimePluginRegistry"] is False
semantic_emitter_boundary = semantic_plan_architecture["emitterBoundary"]
assert semantic_emitter_boundary["liveOutputWrites"] is False
assert semantic_emitter_boundary["targetTextPatching"] is False
assert semantic_emitter_boundary["projectionCoverage"] == (
    "requested-equals-emitted-or-fail"
)
assert semantic_emitter_boundary["publicationOwner"] == (
    "adr-007-transaction-layer"
)
for registry_item in semantic_plan_architecture["nodeSchemas"]["coreRegistry"]:
    assert hashlib.sha256(Path(registry_item["path"]).read_bytes()).hexdigest() == (
        registry_item["sha256"]
    )
semantic_references = semantic_plan_architecture["referencePatterns"]
assert {reference["repository"] for reference in semantic_references} == {
    "haxe.rust",
    "haxe.ruby",
    "haxe.go",
    "genes",
}
for reference in semantic_references:
    assert sha1.fullmatch(reference["commit"])
    assert sha1.fullmatch(reference["blob"])
    assert sha256.fullmatch(reference["sha256"])
    assert reference["copiedBytes"] is False
semantic_verification = semantic_plan_architecture["verification"]
assert semantic_verification["canonicalVectorCount"] == 6
assert semantic_verification["negativeMutationCount"] == 21
assert semantic_verification["nodeSchemaCount"] == 2
assert semantic_verification["nodeCount"] == 2
assert semantic_verification["projectionCount"] == 2
assert semantic_verification["artifactCount"] == 1
assert semantic_verification["outcome"] == "passed"
assert hashlib.sha256(
    Path(semantic_verification["validatorPath"]).read_bytes()
).hexdigest() == semantic_verification["validatorSha256"]
assert semantic_plan_architecture["claims"]["architectureDecision"] == "accepted"
assert semantic_plan_architecture["claims"]["schemaAndFixtureContract"] == (
    "validated"
)
for unproven_semantic_claim in (
    "sdk040MacroCollector",
    "productionEmitterIntegration",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "productionSupport",
):
    assert semantic_plan_architecture["claims"][unproven_semantic_claim] == (
        "not-tested"
    )
assert semantic_plan_receipt["schemaVersion"] == 1
assert semantic_plan_receipt["receiptId"] == (
    "ADR-006-SEMANTIC-PLAN-CONTRACT"
)
assert semantic_plan_receipt["bead"] == "wordpresshx-adr-006"
for semantic_subject in semantic_plan_receipt["subject"].values():
    assert hashlib.sha256(Path(semantic_subject["path"]).read_bytes()).hexdigest() == (
        semantic_subject["sha256"]
    )
assert semantic_plan_receipt["contract"]["planDigest"] == (
    semantic_plan_contract["planDigest"]
)
assert semantic_plan_receipt["contract"]["emissionResultDigest"] == (
    semantic_emission_contract["resultDigest"]
)
assert semantic_plan_receipt["verification"]["canonicalVectorCount"] == 6
assert semantic_plan_receipt["verification"]["negativeMutationCount"] == 21
assert semantic_plan_receipt["verification"]["projectionCoverage"] == "complete"
assert semantic_plan_receipt["verification"]["outcome"] == "passed"
assert semantic_plan_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert semantic_plan_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert semantic_plan_receipt["referenceReview"]["genesSourceChanged"] is False
semantic_hosted = semantic_plan_receipt["hostedWorkflow"]
assert semantic_hosted["workflow"] == "Repository bootstrap"
assert semantic_hosted["job"] == "semantic-plan"
assert semantic_hosted["required"] is True
if semantic_hosted["status"] == "pending-first-hosted-main-run":
    assert semantic_hosted["runId"] is None
    assert semantic_hosted["jobId"] is None
    assert semantic_hosted["commit"] is None
elif semantic_hosted["status"] == "passed":
    assert isinstance(semantic_hosted["runId"], int)
    assert isinstance(semantic_hosted["jobId"], int)
    assert sha1.fullmatch(semantic_hosted["commit"])
else:
    raise AssertionError("semantic-plan hosted status is invalid")

assert schema_codec_architecture["schemaVersion"] == 1
assert schema_codec_architecture["decisionId"] == "ADR-009"
assert schema_codec_architecture["claims"]["architectureDecision"] == (
    "accepted-after-review"
)
schema_prototype = schema_codec_architecture["prototypeEvidence"]
assert schema_prototype["haxeInvariantCount"] == 27
assert schema_prototype["crossTargetVectorCount"] == 17
assert schema_prototype["independentMutationCount"] == 18
assert schema_prototype["negativeCompileFixtureCount"] == 4
assert adr009_receipt["schemaVersion"] == 1
assert adr009_receipt["receiptId"] == "ADR-009-SCHEMA-CODEC-AUTHORITY"
assert adr009_receipt["bead"] == "wordpresshx-adr-009"
assert adr009_receipt["status"] in {"implemented-hosted-pending", "verified"}
for adr009_subject in adr009_receipt["subject"].values():
    assert hashlib.sha256(Path(adr009_subject["path"]).read_bytes()).hexdigest() == (
        adr009_subject["sha256"]
    )
adr009_verification = adr009_receipt["verification"]
assert adr009_verification["sourceTreeSha256"] == schema_prototype[
    "sourceTreeSha256"
]
assert adr009_verification["haxeInvariantCount"] == 27
assert adr009_verification["crossTargetVectorCount"] == 17
assert adr009_verification["independentMutationCount"] == 18
assert adr009_verification["negativeCompileFixtureCount"] == 4
assert adr009_verification["strictNullSafety"] is True
assert adr009_verification["strictHaxeForbiddenTokenCount"] == 0
assert adr009_verification["canonicalTranscriptByteIdenticalAcrossTargets"] is True
assert adr009_receipt["review"]["finalFreshReview"] == "no-blockers"
assert adr009_receipt["claims"]["architectureDecision"] == "accepted"
assert adr009_receipt["claims"]["publicationAuthorized"] is False
for unproven_schema_claim in (
    "productionMacroDerivation",
    "productionPhpEmitter",
    "productionGenesEmitter",
    "wordpressRestRuntime",
    "gutenbergRuntime",
    "productionSupport",
):
    assert adr009_receipt["claims"][unproven_schema_claim] == "not-tested"
adr009_hosted = adr009_receipt["hostedWorkflow"]
assert adr009_hosted["workflow"] == "Repository bootstrap"
assert adr009_hosted["job"] == "contract-schema"
assert adr009_hosted["required"] is True
if adr009_receipt["status"] == "implemented-hosted-pending":
    assert adr009_hosted["status"] == "pending-first-run"
    assert adr009_hosted["runId"] is None
    assert adr009_hosted["jobId"] is None
    assert adr009_hosted["commit"] is None
else:
    assert adr009_hosted["status"] == "passed"
    assert isinstance(adr009_hosted["runId"], int)
    assert isinstance(adr009_hosted["jobId"], int)
    assert sha1.fullmatch(adr009_hosted["commit"])

assert output_context_architecture["schemaVersion"] == 1
assert output_context_architecture["decisionId"] == "ADR-012"
assert output_context_architecture["status"] == (
    "proposed-pending-fresh-review"
)
output_authority = output_context_architecture["authority"]
assert output_authority["lateEscapingRequired"] is True
assert output_authority["universalSafeTypeAllowed"] is False
assert output_authority["terminalRawStringConversionAllowed"] is False
assert output_authority["terminalValuesSerializable"] is False
assert output_authority["escapingIdempotenceAssumed"] is False
assert len(output_context_architecture["contexts"]) == 10
assert len(output_context_architecture["allowedEdges"]) == 11
assert len(output_context_architecture["forbiddenEdges"]) == 14
assert len(output_context_architecture["hxxResolution"]) == 8
output_prototype = output_context_architecture["prototypeEvidence"]
assert output_prototype["contextCount"] == 10
assert output_prototype["allowedEdgeCount"] == 11
assert output_prototype["forbiddenEdgeCount"] == 14
assert output_prototype["hxxPositionCount"] == 8
assert output_prototype["compileNegativeCount"] == 8
assert output_prototype["independentMutationCount"] == 21
assert len(output_context_architecture["referenceReview"]) == 7
for output_reference in output_context_architecture["referenceReview"]:
    assert sha1.fullmatch(output_reference["commit"])
    assert sha1.fullmatch(output_reference["gitBlob"])
    assert sha256.fullmatch(output_reference["sha256"])
    assert output_reference["copiedBytes"] is False
assert adr012_receipt["schemaVersion"] == 1
assert adr012_receipt["receiptId"] == "ADR-012-OUTPUT-CONTEXT-SAFETY"
assert adr012_receipt["bead"] == "wordpresshx-adr-012"
assert adr012_receipt["status"] in {
    "implemented-hosted-pending",
    "implemented-review-pending",
    "verified",
}
for adr012_subject in adr012_receipt["subject"].values():
    assert hashlib.sha256(Path(adr012_subject["path"]).read_bytes()).hexdigest() == (
        adr012_subject["sha256"]
    )
adr012_verification = adr012_receipt["verification"]
assert adr012_verification["sourceTreeSha256"] == output_prototype[
    "sourceTreeSha256"
]
assert adr012_verification["strictNullSafety"] is True
assert adr012_verification["strictHaxeForbiddenTokenCount"] == 0
assert adr012_verification["contextCount"] == 10
assert adr012_verification["allowedEdgeCount"] == 11
assert adr012_verification["forbiddenEdgeCount"] == 14
assert adr012_verification["hxxPositionCount"] == 8
assert adr012_verification["compileNegativeCount"] == 8
assert adr012_verification["independentMutationCount"] == 21
assert adr012_verification[
    "canonicalTranscriptByteIdenticalAcrossHaxeGenesAndPhp"
] is True
assert adr012_receipt["authority"]["unsafeRawApiPublished"] is False
assert adr012_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert adr012_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert adr012_receipt["referenceReview"]["genesSourceChanged"] is False
assert adr012_receipt["claims"]["publicationAuthorized"] is False
for unproven_output_claim in (
    "productionSdkTypes",
    "productionHxxLowerer",
    "browserRichHtmlPolicy",
    "php74Runtime",
    "packedConsumer",
    "productionSupport",
):
    assert adr012_receipt["claims"][unproven_output_claim] == "not-tested"
adr012_hosted = adr012_receipt["hostedWorkflow"]
assert adr012_hosted["workflow"] == "Output-context safety"
assert adr012_hosted["job"] == "output-context"
assert adr012_hosted["required"] is True
if adr012_hosted["status"] == "pending-first-hosted-main-run":
    assert adr012_receipt["status"] == "implemented-hosted-pending"
    assert adr012_hosted["runId"] is None
    assert adr012_hosted["jobId"] is None
    assert adr012_hosted["commit"] is None
elif adr012_hosted["status"] == "passed":
    assert isinstance(adr012_hosted["runId"], int)
    assert isinstance(adr012_hosted["jobId"], int)
    assert sha1.fullmatch(adr012_hosted["commit"])
else:
    raise AssertionError("output-context hosted status is invalid")

assert adoption_architecture["schemaVersion"] == 1
assert adoption_architecture["decisionId"] == "ADR-015"
assert adoption_architecture["status"] == "proposed-pending-fresh-review"
adoption_authority = adoption_architecture["authority"]
assert adoption_authority["defaultExecution"] == "forbidden"
assert adoption_authority["bindingPolicy"] == "precise-or-omitted"
assert adoption_authority["sourceMerge"] == (
    "one-complete-binding-no-field-splicing"
)
assert adoption_authority["providerRuntimeOwner"] == "native-provider"
assert adoption_authority["implementationOwnershipTransferred"] is False
assert adoption_authority["compilerProviderNameBranchesAllowed"] is False
assert adoption_authority["weakFallbackTypesAllowed"] is False
assert adoption_authority["capabilityTokensSerializable"] is False
assert adoption_authority["staleCapabilityAuthority"] is False
assert adoption_architecture["sourcePrecedence"] == [
    "authoritative-signature",
    "isolated-reflection-opt-in",
    "package-or-source-signature",
    "documentation",
    "curated-contract",
]
adoption_selection = adoption_architecture["selection"]
assert adoption_selection["unit"] == "one-complete-native-binding"
assert adoption_selection["fieldSplicingAcrossSources"] is False
assert adoption_selection["strongerConflictWithLowerSource"] == (
    "omit-binding-and-report"
)
assert adoption_selection["unknownOrUnsupportedShape"] == (
    "omit-with-stable-review-code"
)
assert adoption_selection["generatedBroadFallback"] is False
adoption_execution = adoption_architecture["execution"]
assert adoption_execution["defaultMode"] == "static-no-execution"
assert adoption_execution["providerRuntimeSourceExecutedByDefault"] is False
assert adoption_execution["reflectionMode"] == (
    "explicit-isolated-opt-in-only"
)
assert adoption_execution["reflectionNetwork"] == "none"
assert adoption_execution["reflectionReceiptRequired"] is True
assert adoption_execution["reflectionResultBecomesUniversalAuthority"] is False
adoption_contracts = adoption_architecture["contracts"]
assert adoption_contracts["adoption"]["identity"] == (
    "wordpress-hx.adoption-contract.v1"
)
assert adoption_contracts["capability"]["identity"] == (
    "wordpress-hx.adoption-capability.v1"
)
assert adoption_contracts["review"]["identity"] == (
    "wordpress-hx.adoption-review.v1"
)
assert len(adoption_architecture["providerLayers"]) == 2
assert [stage["id"] for stage in adoption_architecture["evidenceStages"]] == [
    "inventoried",
    "contract-generated",
    "contract-tested",
    "provider-runtime-tested",
]
adoption_prototype = adoption_architecture["prototypeEvidence"]
assert adoption_prototype["bindingCount"] == 3
assert adoption_prototype["capabilityCount"] == 2
assert adoption_prototype["omissionCount"] == 4
assert adoption_prototype["conflictCount"] == 1
assert adoption_prototype["compileNegativeCount"] == 4
assert adoption_prototype["independentMutationCount"] == 31
assert adoption_prototype["providerRuntimeExecutionDuringGeneration"] is False
assert adoption_prototype["realProviderUsed"] is False
assert len(adoption_architecture["referenceReview"]) == 3
for adoption_reference in adoption_architecture["referenceReview"]:
    assert sha1.fullmatch(adoption_reference["commit"])
    assert sha1.fullmatch(adoption_reference["gitBlob"])
    assert sha256.fullmatch(adoption_reference["sha256"])
    assert adoption_reference["copiedBytes"] is False

assert adr015_receipt["schemaVersion"] == 1
assert adr015_receipt["receiptId"] == "ADR-015-INTEROP-ADOPTION-CONTRACT"
assert adr015_receipt["bead"] == "wordpresshx-adr-015"
assert adr015_receipt["status"] in {
    "implemented-hosted-pending",
    "implemented-review-pending",
    "verified",
}
for adr015_subject in adr015_receipt["subject"].values():
    assert hashlib.sha256(Path(adr015_subject["path"]).read_bytes()).hexdigest() == (
        adr015_subject["sha256"]
    )
adr015_authority = adr015_receipt["authority"]
assert adr015_authority["defaultExecution"] == "forbidden"
assert adr015_authority["bindingPolicy"] == "precise-or-omitted"
assert adr015_authority["sourceMerge"] == (
    "one-complete-binding-no-field-splicing"
)
assert adr015_authority["implementationOwnershipTransferred"] is False
assert adr015_authority["weakFallbackTypesAllowed"] is False
assert adr015_authority["capabilityTokensSerializable"] is False
assert adr015_authority["capabilityTokensCacheable"] is False
assert adr015_authority["staleCapabilityAuthority"] is False
adr015_verification = adr015_receipt["verification"]
assert adr015_verification["sourceTreeSha256"] == adoption_prototype[
    "sourceTreeSha256"
]
assert adr015_verification["strictNullSafety"] is True
assert adr015_verification["strictHaxeForbiddenTokenCount"] == 0
assert adr015_verification["bindingCount"] == 3
assert adr015_verification["capabilityCount"] == 2
assert adr015_verification["omissionCount"] == 4
assert adr015_verification["conflictCount"] == 1
assert adr015_verification["compileNegativeCount"] == 4
assert adr015_verification["independentMutationCount"] == 31
assert adr015_verification[
    "canonicalTranscriptByteIdenticalAcrossHaxeGenesAndPhp"
] is True
assert adr015_verification["providerRuntimeExecutionDuringGeneration"] is False
assert adr015_verification["realProviderUsed"] is False
assert adr015_verification["wordpressRuntimeUsed"] is False
assert adr015_receipt["review"]["freshIndependentReview"] == "pending"
assert adr015_receipt["review"]["acceptanceAuthorized"] is False
assert adr015_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert adr015_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert adr015_receipt["referenceReview"]["genesSourceChanged"] is False
assert adr015_receipt["claims"]["publicationAuthorized"] is False
for unproven_adoption_claim in (
    "productionGenerator",
    "isolatedReflectionRuntime",
    "nativeProviderAbi",
    "realProviderRuntime",
    "wordpressRuntime",
    "providerTrustAdmission",
    "php74Runtime",
    "publicPackageConsumer",
    "productionSupport",
):
    assert adr015_receipt["claims"][unproven_adoption_claim] == "not-tested"
adr015_hosted = adr015_receipt["hostedWorkflow"]
adoption_hosted = adoption_architecture["hostedGate"]
assert adr015_hosted["workflow"] == "Adoption-contract architecture"
assert adr015_hosted["job"] == "adoption-contract"
assert adr015_hosted["required"] is True
assert adoption_hosted["job"] == adr015_hosted["job"]
assert adoption_hosted["status"] == adr015_hosted["status"]
for hosted_identity in ("runId", "jobId", "commit"):
    assert adoption_hosted[hosted_identity] == adr015_hosted[hosted_identity]
if adr015_hosted["status"] == "pending-first-hosted-main-run":
    assert adr015_receipt["status"] == "implemented-hosted-pending"
    assert adr015_hosted["runId"] is None
    assert adr015_hosted["jobId"] is None
    assert adr015_hosted["commit"] is None
elif adr015_hosted["status"] == "passed":
    assert isinstance(adr015_hosted["runId"], int)
    assert isinstance(adr015_hosted["jobId"], int)
    assert sha1.fullmatch(adr015_hosted["commit"])
else:
    raise AssertionError("adoption-contract hosted status is invalid")

assert semantic_plan_receipt["claims"]["architectureDecision"] == "accepted"
assert semantic_plan_receipt["claims"]["schemaAndFixtureContract"] == "validated"
for unproven_receipt_claim in (
    "sdk040MacroCollector",
    "productionEmitterIntegration",
    "generatedFilePublicationSafety",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "productionSupport",
):
    assert semantic_plan_receipt["claims"][unproven_receipt_claim] == "not-tested"

assert semantic_collector_architecture["schemaVersion"] == 1
assert semantic_collector_architecture["bead"] == "wordpresshx-sdk-040"
assert semantic_collector_architecture["status"] == (
    "implemented-and-locally-tested"
)
collector_contracts = semantic_collector_architecture["contracts"]
assert collector_contracts["config"]["identity"] == (
    "wordpress-hx.semantic-collector-config.v1"
)
assert collector_contracts["plan"]["identity"] == (
    "wordpress-hx.semantic-plan.v1"
)
assert collector_contracts["inputs"]["identity"] == (
    "wordpress-hx.semantic-collector-inputs.v1"
)
for collector_contract in (
    collector_contracts["config"],
    collector_contracts["inputs"],
):
    assert hashlib.sha256(
        Path(collector_contract["path"]).read_bytes()
    ).hexdigest() == collector_contract["sha256"]
collector_surface = semantic_collector_architecture["publicSurface"]
assert collector_surface["runtimeRegistry"] is False
assert collector_surface["dynamicNodeEscapeHatch"] is False
assert collector_surface["literalIdentityRequired"] is True
collector_inputs = semantic_collector_architecture["effectiveInputs"]
assert collector_inputs["environmentClassification"] == "public-build-only"
assert collector_inputs["environmentRawValuesSerialized"] is False
assert collector_inputs["runtimeSecretsRead"] is False
assert collector_inputs["absolutePathsSerialized"] is False
assert collector_inputs["networkReads"] is False
collector_extensions = semantic_collector_architecture["extensionRules"]
assert collector_extensions["unknownExtension"] == "fail"
assert collector_extensions["networkSchemaResolution"] is False
assert collector_extensions["publicDynamicPayloadCollector"] is False
collector_handoff = semantic_collector_architecture["developmentLoopHandoff"]
assert collector_handoff["defaultCommand"] == "wphx dev"
assert collector_handoff["compileWatchOnly"] == "wphx dev --services=none"
collector_references = semantic_collector_architecture["referencePatterns"]
assert {item["repository"] for item in collector_references} == {
    "genes",
    "haxe.elixir.codex",
}
for reference in collector_references:
    assert sha1.fullmatch(reference["commit"])
    assert sha1.fullmatch(reference["blob"])
    assert sha256.fullmatch(reference["sha256"])
    assert reference["copiedBytes"] is False
collector_verification = semantic_collector_architecture["verification"]
assert collector_verification["haxeVersion"] == "4.3.7"
assert collector_verification["directBuildCount"] == 2
assert collector_verification["serverBuildCount"] == 2
assert collector_verification["negativeCompileCount"] == 18
assert collector_verification["negativeSchemaMutationCount"] == 5
assert collector_verification["collectorSourceCount"] == 24
assert collector_verification["effectiveFileCount"] == 32
assert collector_verification["toolCount"] == 8
assert collector_verification["nodeCount"] == 3
assert collector_verification["outcome"] == "passed"
assert semantic_collector_architecture["claims"]["sdk040MacroCollector"] == (
    "compile-tested"
)
for unproven_collector_claim in (
    "productionEmitterIntegration",
    "generatedFilePublicationSafety",
    "productionWphxDevWatcher",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "productionSupport",
):
    assert semantic_collector_architecture["claims"][unproven_collector_claim] == (
        "not-tested"
    )

assert semantic_collector_receipt["schemaVersion"] == 1
assert semantic_collector_receipt["receiptId"] == "SDK-040-SEMANTIC-COLLECTOR"
assert semantic_collector_receipt["bead"] == "wordpresshx-sdk-040"
for collector_subject in semantic_collector_receipt["subject"].values():
    assert hashlib.sha256(
        Path(collector_subject["path"]).read_bytes()
    ).hexdigest() == collector_subject["sha256"]
collector_receipt_contract = semantic_collector_receipt["contract"]
assert collector_receipt_contract["collectorSourceSha256"] == (
    collector_verification["collectorSourceSha256"]
)
assert collector_receipt_contract["effectiveInputsFingerprint"] == (
    collector_verification["effectiveInputsFingerprint"]
)
assert collector_receipt_contract["planDigest"] == collector_verification[
    "planDigest"
]
collector_receipt_verification = semantic_collector_receipt["verification"]
for count_key in (
    "directBuildCount",
    "serverBuildCount",
    "negativeCompileCount",
    "negativeSchemaMutationCount",
    "effectiveFileCount",
    "collectorSourceCount",
    "toolCount",
    "nodeCount",
):
    assert collector_receipt_verification[count_key] == collector_verification[
        count_key
    ]
assert semantic_collector_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert semantic_collector_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert semantic_collector_receipt["referenceReview"]["genesSourceChanged"] is False
collector_hosted = semantic_collector_receipt["hostedWorkflow"]
assert collector_hosted["workflow"] == "Repository bootstrap"
assert collector_hosted["job"] == "semantic-plan"
assert collector_hosted["required"] is True
if collector_hosted["status"] == "pending-first-hosted-main-run":
    assert collector_hosted["runId"] is None
    assert collector_hosted["jobId"] is None
    assert collector_hosted["commit"] is None
elif collector_hosted["status"] == "passed":
    assert isinstance(collector_hosted["runId"], int)
    assert isinstance(collector_hosted["jobId"], int)
    assert sha1.fullmatch(collector_hosted["commit"])
else:
    raise AssertionError("semantic collector hosted status is invalid")
workflow_text = Path(".github/workflows/repository.yml").read_text(encoding="utf-8")
assert "Compile and validate the semantic macro collector" in workflow_text
assert "bash scripts/semantic-collector/test.sh" in workflow_text

assert ownership_architecture["schemaVersion"] == 1
assert ownership_architecture["decision"] == "ADR-007"
assert ownership_architecture["status"] == (
    "accepted-contract-not-sdk041-production-implementation"
)
ownership_contracts = ownership_architecture["contracts"]
ownership_manifest_contract = ownership_contracts["manifest"]
ownership_journal_contract = ownership_contracts["journal"]
assert ownership_manifest_contract["identity"] == (
    "wordpress-hx.generated-files.v1"
)
assert ownership_journal_contract["identity"] == (
    "wordpress-hx.ownership-journal.v1"
)
assert ownership_journal_contract["protocol"] == (
    "wordpress-hx.ownership-transaction.v1"
)
for contract, schema_key, fixture_keys in (
    (
        ownership_manifest_contract,
        "schemaPath",
        ("currentFixturePath", "nextFixturePath"),
    ),
    (
        ownership_journal_contract,
        "schemaPath",
        ("fixturePath",),
    ),
):
    assert hashlib.sha256(Path(contract[schema_key]).read_bytes()).hexdigest() == (
        contract["schemaSha256"]
    )
    for fixture_key in fixture_keys:
        digest_key = fixture_key.replace("Path", "Sha256")
        assert hashlib.sha256(Path(contract[fixture_key]).read_bytes()).hexdigest() == (
            contract[digest_key]
        )
ownership_current_fixture = json.loads(
    Path(ownership_manifest_contract["currentFixturePath"]).read_text(
        encoding="utf-8"
    )
)
ownership_next_fixture = json.loads(
    Path(ownership_manifest_contract["nextFixturePath"]).read_text(
        encoding="utf-8"
    )
)
ownership_journal_fixture = json.loads(
    Path(ownership_journal_contract["fixturePath"]).read_text(encoding="utf-8")
)
assert ownership_current_fixture["manifestDigest"] == (
    ownership_manifest_contract["currentManifestDigest"]
)
assert ownership_next_fixture["manifestDigest"] == (
    ownership_manifest_contract["nextManifestDigest"]
)
assert ownership_journal_fixture["journalDigest"] == (
    ownership_journal_contract["journalDigest"]
)
ownership_authority = ownership_architecture["authority"]
assert ownership_authority[
    "ownedOnlyWhenExactCurrentManifestPathAndHashMatch"
] is True
assert ownership_authority["byteSizeBound"] is True
assert ownership_authority["directoryOwnership"] is False
assert ownership_authority["commentHeaderOwnership"] is False
assert ownership_authority["looksGeneratedOwnership"] is False
assert ownership_authority["equalUnownedBytesGrantOwnership"] is False
assert ownership_authority["missingManifestMeansNoOwnedFiles"] is True
assert ownership_authority["manifestPublishedLastAsCommitMarker"] is True
ownership_paths = ownership_architecture["pathPolicy"]
assert ownership_paths["absoluteDriveUncTraversalBackslashOrControlAllowed"] is False
assert ownership_paths["duplicatesAllowed"] is False
assert ownership_paths["unicodeCaseFoldCollisionsAllowed"] is False
assert ownership_paths["nestedOutputRootsAllowed"] is False
assert ownership_paths[
    "symbolicLinksJunctionsReparseOrBrokenLinksAllowed"
] is False
assert ownership_paths["hardLinkedRegularFilesMutatedInPlace"] is False
assert ownership_paths["generatedFilesMayUseReservedMetadataRoot"] is False
assert ownership_paths["oneFilesystemV1"] is True
assert ownership_paths["copyDeletePublicationFallback"] is False
ownership_transaction = ownership_architecture["transaction"]
assert ownership_architecture["preflight"][
    "identicalBuildRequiresCompleteStage"
] is True
assert ownership_transaction["journalDurableBeforeLiveMutation"] is True
assert ownership_transaction["manifestPublishedLast"] is True
assert ownership_transaction["normalOrCaughtFailure"] == "failure-atomic"
assert ownership_transaction["caughtFailureAfterCompleteCommit"] == (
    "finalize-and-report-published"
)
assert ownership_transaction["simultaneousMultiFileVisibilityClaimed"] is False
assert ownership_transaction["powerLossDurabilityClaimed"] is False
assert ownership_transaction["forceOverwriteFlag"] is False
assert ownership_transaction["outputRootMigration"] == (
    "safe-additive-exact-root-set-only"
)
ownership_recovery = ownership_architecture["recovery"]
assert ownership_recovery["completeNextManifestAndTree"] == "finalize"
assert ownership_recovery[
    "journalPlanDerivedFromBoundPriorAndNextManifests"
] is True
assert ownership_recovery["newPathRemovalRequiresExactNewHash"] is True
assert ownership_recovery["backupRestoreRequiresExactOldHash"] is True
assert ownership_recovery["blindRollForward"] is False
assert ownership_recovery["blindRollbackOverwrite"] is False
ownership_references = ownership_architecture["referencePatterns"]
assert {reference["repository"] for reference in ownership_references} == {
    "genes",
    "haxe.go",
    "wordpresshx-port",
}
for reference in ownership_references:
    assert sha1.fullmatch(reference["commit"])
    assert sha1.fullmatch(reference["blob"])
    assert sha256.fullmatch(reference["sha256"])
    assert reference["copiedBytes"] is False
    assert reference["dependencyCreated"] is False
ownership_verification = ownership_architecture["verification"]
assert ownership_verification["command"] == (
    "bash scripts/ownership/test-adr-contract.sh"
)
assert ownership_verification["positiveFilesystemCount"] == 11
assert ownership_verification["negativeFilesystemCount"] == 17
assert ownership_verification["negativeMutationCount"] == 25
assert ownership_verification["currentFileCount"] == 2
assert ownership_verification["nextFileCount"] == 2
assert ownership_verification["journalOperationCount"] == 3
assert ownership_verification["recoveryModes"] == [
    "finalize-complete-next",
    "rollback-partial",
]
assert ownership_verification["outcome"] == "passed"
assert hashlib.sha256(
    Path(ownership_verification["validatorPath"]).read_bytes()
).hexdigest() == ownership_verification["validatorSha256"]
assert ownership_architecture["claims"]["architectureDecision"] == "accepted"
assert ownership_architecture["claims"]["schemaAndFilesystemContract"] == (
    "validated"
)
for unproven_ownership_claim in (
    "sdk041ProductionImplementation",
    "powerLossDurability",
    "windowsFilesystem",
    "hostileConcurrentMutation",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "deterministicZip",
    "productionSupport",
):
    assert ownership_architecture["claims"][unproven_ownership_claim] == (
        "not-tested"
    )

assert ownership_receipt["schemaVersion"] == 1
assert ownership_receipt["receiptId"] == (
    "ADR-007-GENERATED-ARTIFACT-OWNERSHIP"
)
assert ownership_receipt["bead"] == "wordpresshx-adr-007"
assert ownership_receipt["verification"]["command"] == (
    "bash scripts/ownership/test-adr-contract.sh"
)
for ownership_subject in ownership_receipt["subject"].values():
    assert hashlib.sha256(Path(ownership_subject["path"]).read_bytes()).hexdigest() == (
        ownership_subject["sha256"]
    )
assert ownership_receipt["contract"]["currentManifestDigest"] == (
    ownership_manifest_contract["currentManifestDigest"]
)
assert ownership_receipt["contract"]["nextManifestDigest"] == (
    ownership_manifest_contract["nextManifestDigest"]
)
assert ownership_receipt["contract"]["preparedJournalDigest"] == (
    ownership_journal_contract["journalDigest"]
)
assert ownership_receipt["contract"]["forceOverwrite"] is False
assert ownership_receipt["verification"]["positiveFilesystemCount"] == 11
assert ownership_receipt["verification"]["negativeFilesystemCount"] == 17
assert ownership_receipt["verification"]["negativeMutationCount"] == 25
assert ownership_receipt["verification"]["operationKinds"] == [
    "create",
    "remove",
    "replace",
]
for ownership_proof in (
    "completeBuildStageRequired",
    "caughtPostCommitFailureFinalizes",
    "hardLinksReplaceEntriesNotTargets",
    "journalDerivedFromBoundManifests",
    "specialFilesRejected",
):
    assert ownership_receipt["verification"][ownership_proof] == "passed"
assert ownership_receipt["verification"]["outcome"] == "passed"
assert ownership_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert ownership_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert ownership_receipt["referenceReview"]["genesSourceChanged"] is False
ownership_sdk042_revision = ownership_receipt["sdk042CompatibilityRevision"]
assert ownership_sdk042_revision == {
    "change": "safe-additive-exact-output-root-set-migration",
    "rootRemovalOrRewriteAllowed": False,
    "command": "bash scripts/ownership/test.sh",
    "outcome": "passed-local",
    "hostedEvidenceOwner": "SDK-042-DETERMINISTIC-BUILD",
}
ownership_hosted = ownership_receipt["hostedWorkflow"]
assert ownership_hosted["workflow"] == "Repository bootstrap"
assert ownership_hosted["job"] == "repository"
assert ownership_hosted["required"] is True
if ownership_hosted["status"] == "pending-first-hosted-main-run":
    assert ownership_hosted["runId"] is None
    assert ownership_hosted["jobId"] is None
    assert ownership_hosted["commit"] is None
elif ownership_hosted["status"] == "passed":
    assert isinstance(ownership_hosted["runId"], int)
    assert isinstance(ownership_hosted["jobId"], int)
    assert sha1.fullmatch(ownership_hosted["commit"])
else:
    raise AssertionError("generated ownership hosted status is invalid")
assert ownership_receipt["claims"]["architectureDecision"] == "accepted"
assert ownership_receipt["claims"]["schemaAndFilesystemContract"] == (
    "validated"
)
for unproven_ownership_receipt_claim in (
    "sdk041ProductionImplementation",
    "powerLossDurability",
    "windowsFilesystem",
    "hostileConcurrentMutation",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "deterministicZip",
    "productionSupport",
):
    assert ownership_receipt["claims"][
        unproven_ownership_receipt_claim
    ] == "not-tested"

assert ownership_implementation["schemaVersion"] == 1
assert ownership_implementation["bead"] == "wordpresshx-sdk-041"
assert ownership_implementation["status"] == "implemented-sdk041"
assert ownership_implementation["contract"] == {
    "manifest": "wordpress-hx.generated-files.v1",
    "journal": "wordpress-hx.ownership-journal.v1",
    "transaction": "wordpress-hx.ownership-transaction.v1",
    "canonicalization": "wordpress-hx.canonical-json.v1",
    "ownershipAuthority": (
        "exact-current-manifest-path-hash-size-and-regular-file"
    ),
    "commitMarker": "manifest-published-last",
}
ownership_code = ownership_implementation["implementation"]
assert ownership_code["language"] == "Haxe"
assert ownership_code["target"] == "Genes-emitted-Node-ESM"
assert ownership_code["publicOwner"] == (
    "packages/cli/src/wordpresshx/cli/ownership/ArtifactOwner.hx"
)
assert ownership_code["publicTypes"] == [
    "packages/cli/src/wordpresshx/cli/ownership/OwnershipLayout.hx",
    "packages/cli/src/wordpresshx/cli/ownership/OwnershipResult.hx",
    "packages/cli/src/wordpresshx/cli/ownership/StageValidator.hx",
]
assert ownership_code["internalContracts"] == [
    "packages/cli/src/wordpresshx/cli/ownership/OwnershipContract.hx",
    "packages/cli/src/wordpresshx/cli/ownership/OwnershipFailure.hx",
    "packages/cli/src/wordpresshx/cli/ownership/OwnershipJson.hx",
]
ownership_toolchain = ownership_code["exactToolchain"]
assert ownership_toolchain == {
    "haxe": cli_dependency_lock["haxe"]["version"],
    "genes": cli_dependency_lock["compiler"]["version"],
    "genesCommit": cli_dependency_lock["compiler"]["commit"],
    "hxnodejs": cli_dependency_lock["nodeExterns"]["version"],
    "node": cli_dependency_lock["runtime"]["version"],
    "nodeImage": cli_dependency_lock["runtime"]["image"],
}
assert ownership_code["genesSourceChanged"] is False
assert ownership_code["siblingDependencyCreated"] is False
assert ownership_implementation["safety"] == {
    "strictCanonicalJsonAndDuplicateKeys": True,
    "binarySha256AndByteSize": True,
    "portableRelativePaths": True,
    "caseCollisionRejection": True,
    "noFollowComponentChecks": True,
    "singleFilesystemRenames": True,
    "exclusiveProjectLock": True,
    "journalDurableBeforeLiveMutation": True,
    "completePrivateStage": True,
    "manifestPublishedLast": True,
    "exactHashRollback": True,
    "exactHashFinalize": True,
    "unexpectedBytesPreserved": True,
    "cleanManifestOnly": True,
    "adoptExactPathsOnly": True,
    "forceFlag": False,
    "networkDependency": False,
}
sdk041_verification = ownership_implementation["verification"]
assert sdk041_verification["command"] == "bash scripts/ownership/test.sh"
assert sdk041_verification["compileReplayCount"] == 2
assert sdk041_verification["exactNodeVersion"] == "22.17.0"
assert sdk041_verification["positiveInvocationCount"] == 17
assert sdk041_verification["negativeInvocationCount"] == 26
assert sdk041_verification["crashCheckpointCount"] == 13
assert sdk041_verification["adrPositiveFilesystemCount"] == 11
assert sdk041_verification["adrNegativeFilesystemCount"] == 17
assert sdk041_verification["adrNegativeMutationCount"] == 25
assert sdk041_verification["recoveryModes"] == [
    "finalize-complete-next",
    "rollback-partial",
]
assert sdk041_verification["outcome"] == "passed"
for sdk041_local_claim in (
    "sdk041ArtifactOwner",
    "processFailureAtomicity",
    "processCrashConsistency",
    "cleanAndAdopt",
):
    assert ownership_implementation["claims"][sdk041_local_claim] == (
        "runtime-tested-local"
    )
for sdk041_unproven_claim in (
    "powerLossDurability",
    "windowsFilesystem",
    "networkFilesystem",
    "hostileConcurrentMutation",
    "finalWphxCommandIntegration",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "productionSupport",
):
    assert ownership_implementation["claims"][sdk041_unproven_claim] == (
        "not-tested"
    )
assert ownership_implementation["limitations"] == [
    "exact-node-22.17.0-linux-container-runtime-evidence",
    "darwin-runtime-not-tested",
    "process-failure-and-interruption-not-power-loss",
    "no-windows-or-network-filesystem-evidence",
    "no-hostile-concurrent-mutation-claim",
    "sdk043-final-cli-integration-pending",
    "no-real-wordpress-or-nextjs-generated-tree",
]

assert sdk041_receipt["schemaVersion"] == 1
assert sdk041_receipt["receiptId"] == "SDK-041-OWNERSHIP-TRANSACTION"
assert sdk041_receipt["bead"] == "wordpresshx-sdk-041"
assert set(sdk041_receipt["subject"]) == {
    "architecture",
    "processBoundary",
    "owner",
    "contract",
    "ownershipFailure",
    "canonicalJson",
    "ownershipLayout",
    "ownershipResult",
    "stageValidator",
    "fixtureEntry",
    "compileProfile",
    "productionCorpus",
    "gate",
    "isolationScanner",
    "emittedIsolationCompilerProbes",
    "manifestSchema",
    "journalSchema",
}
for sdk041_subject in sdk041_receipt["subject"].values():
    assert hashlib.sha256(Path(sdk041_subject["path"]).read_bytes()).hexdigest() == (
        sdk041_subject["sha256"]
    )
sdk041_closure_subjects = {
    "processBoundary": "packages/cli/src/wordpresshx/cli/NodeGlobals.hx",
    "owner": "packages/cli/src/wordpresshx/cli/ownership/ArtifactOwner.hx",
    "contract": (
        "packages/cli/src/wordpresshx/cli/ownership/OwnershipContract.hx"
    ),
    "ownershipFailure": (
        "packages/cli/src/wordpresshx/cli/ownership/OwnershipFailure.hx"
    ),
    "canonicalJson": (
        "packages/cli/src/wordpresshx/cli/ownership/OwnershipJson.hx"
    ),
    "ownershipLayout": (
        "packages/cli/src/wordpresshx/cli/ownership/OwnershipLayout.hx"
    ),
    "ownershipResult": (
        "packages/cli/src/wordpresshx/cli/ownership/OwnershipResult.hx"
    ),
    "stageValidator": (
        "packages/cli/src/wordpresshx/cli/ownership/StageValidator.hx"
    ),
}
assert sdk041_receipt["productionClosureSubjects"] == list(
    sdk041_closure_subjects
)
assert {
    name: sdk041_receipt["subject"][name]["path"]
    for name in sdk041_closure_subjects
} == sdk041_closure_subjects
sdk041_receipt_verification = sdk041_receipt["verification"]
for sdk041_count in (
    "compileReplayCount",
    "positiveInvocationCount",
    "negativeInvocationCount",
    "crashCheckpointCount",
    "adrPositiveFilesystemCount",
    "adrNegativeFilesystemCount",
    "adrNegativeMutationCount",
):
    assert sdk041_receipt_verification[sdk041_count] == (
        sdk041_verification[sdk041_count]
    )
assert sdk041_receipt_verification["command"] == (
    sdk041_verification["command"]
)
assert sdk041_receipt_verification["exactNodeVersion"] == (
    sdk041_verification["exactNodeVersion"]
)
assert sdk041_receipt_verification["network"] == "disabled"
assert sdk041_receipt_verification["directVsReplayGeneratedTree"] == (
    "byte-identical"
)
for sdk041_receipt_proof in (
    "diagnosticAbsolutePathPrivacy",
    "noNetworkOrChildProcessImplementation",
):
    assert sdk041_receipt_verification[sdk041_receipt_proof] == "passed"
assert sdk041_receipt_verification["outcome"] == "passed"
assert sdk041_receipt["sdk042CompatibilityReverification"] == {
    "change": (
        "normalized-generated-modes-and-safe-additive-output-root-migration"
    ),
    "generatedFileMode": 420,
    "rootRemovalOrRewriteAllowed": False,
    "ownershipCommand": "bash scripts/ownership/test.sh",
    "determinismCommand": "bash scripts/determinism/test-production.sh",
    "outcome": "passed-local",
    "hostedEvidenceOwner": "SDK-042-DETERMINISTIC-BUILD",
}
sdk041_hosted = sdk041_receipt["hostedWorkflow"]
assert sdk041_hosted["workflow"] == "Repository bootstrap"
assert sdk041_hosted["job"] == "haxe"
assert sdk041_hosted["required"] is True
if sdk041_hosted["status"] == "pending-first-hosted-main-run":
    assert sdk041_hosted["runId"] is None
    assert sdk041_hosted["jobId"] is None
    assert sdk041_hosted["commit"] is None
    sdk041_evidence_level = "runtime-tested-local"
elif sdk041_hosted["status"] == "passed":
    assert isinstance(sdk041_hosted["runId"], int)
    assert isinstance(sdk041_hosted["jobId"], int)
    assert sha1.fullmatch(sdk041_hosted["commit"])
    sdk041_evidence_level = "runtime-tested-hosted"
else:
    raise AssertionError("SDK-041 ownership hosted status is invalid")
assert sdk041_receipt["discardedHostedAttempts"] == [
    {
        "runId": 29662888829,
        "jobId": 88128417925,
        "commit": "d85b6f9308f80059c99eb6471b8115b9e8780942",
        "status": "failed",
        "failure": (
            "locked Node container wrote root-owned mode-0600 evidence files; "
            "the generalized harness now runs the runtime as the invoking POSIX "
            "uid:gid"
        ),
    }
]
sdk041_corrective = sdk041_receipt["correctiveVerification"]
assert sdk041_corrective["localGate"] == "passed"
assert sdk041_corrective["productionClosureAuthority"] == (
    "haxe-dump-dependencies"
)
assert sdk041_corrective["productionClosureContentBinding"] == (
    "receipt-sha256-for-every-compiler-discovered-repository-source"
)
assert sdk041_corrective["emittedCapabilityAuthority"] == (
    "genes-javascript-modules-mapped-from-haxe-dump-dependencies"
)
assert sdk041_corrective["repositoryDependencyBoundary"] == (
    "production-root-plus-one-exact-harness-entry"
)
assert sdk041_corrective["productionClosureSourceCount"] == 8
assert sdk041_corrective["emittedProductionModuleCount"] == 4
assert sdk041_corrective["allowedNodeCapabilityCount"] == 5
assert sdk041_corrective["auditedProcessBoundaryCount"] == 1
assert sdk041_corrective["sourceForbiddenSelfTestCount"] == 40
assert sdk041_corrective["emittedSyntheticForbiddenSelfTestCount"] == 19
assert sdk041_corrective["emittedCompileConfirmedForbiddenCount"] == 11
assert sdk041_corrective["outOfRootCompileConfirmedForbiddenCount"] == 1
for sdk041_corrective_regression in (
    "importAliasRegression",
    "transitiveWrapperRegression",
    "methodFalsePositiveRegression",
    "extensionMethodRegression",
    "syntaxTypedefRegression",
    "wildcardImportRegression",
    "interpolationRegression",
    "untypedRegression",
    "processMethodReferenceRegression",
    "regexLiteralFalsePositiveRegression",
    "escapedIdentifierRegression",
    "exactRelativeImportRegression",
    "outOfRootDependencyRegression",
    "nodeNetworkGlobalRegression",
):
    assert sdk041_corrective[sdk041_corrective_regression] == "passed"
if sdk041_corrective["status"] == "pending-corrective-hosted-verification":
    assert sdk041_corrective["commit"] is None
    assert sdk041_corrective["runId"] is None
    assert sdk041_corrective["haxeJobId"] is None
    assert sdk041_corrective["allJobsPassed"] is False
    assert sdk041_corrective["completedAt"] is None
elif sdk041_corrective["status"] == "passed":
    assert sha1.fullmatch(sdk041_corrective["commit"])
    assert isinstance(sdk041_corrective["runId"], int)
    assert isinstance(sdk041_corrective["haxeJobId"], int)
    assert sdk041_corrective["allJobsPassed"] is True
    assert re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",
        sdk041_corrective["completedAt"],
    )
else:
    raise AssertionError("SDK-041 corrective hosted status is invalid")
for sdk041_proven_claim in (
    "sdk041ArtifactOwner",
    "processFailureAtomicity",
    "processCrashConsistency",
    "cleanAndAdopt",
):
    assert sdk041_receipt["claims"][sdk041_proven_claim] == (
        sdk041_evidence_level
    )
for sdk041_unproven_claim in (
    "powerLossDurability",
    "windowsFilesystem",
    "networkFilesystem",
    "hostileConcurrentMutation",
    "finalWphxCommandIntegration",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "productionSupport",
):
    assert sdk041_receipt["claims"][sdk041_unproven_claim] == "not-tested"
assert sdk041_receipt["limitations"] == ownership_implementation["limitations"]
assert "Test fail-closed generated-file ownership transaction" in workflow_text
assert "bash scripts/ownership/test.sh" in workflow_text

assert project_cli_architecture["schemaVersion"] == 1
assert project_cli_architecture["decision"] == "ADR-016"
assert project_cli_architecture["status"] == (
    "accepted-contract-not-sdk043-or-sdk044-production-implementation"
)
project_cli_contracts = project_cli_architecture["contracts"]
for project_cli_contract_name in (
    "project",
    "projectLock",
    "effectiveInputs",
    "events",
):
    project_cli_contract = project_cli_contracts[project_cli_contract_name]
    assert hashlib.sha256(
        Path(project_cli_contract["schemaPath"]).read_bytes()
    ).hexdigest() == project_cli_contract["schemaSha256"]
for contract_name, fixture_fields in (
    ("project", ("fixturePath",)),
    ("projectLock", ("fixturePath",)),
    ("effectiveInputs", ("fixturePath",)),
    ("events", ("dryRunFixturePath", "devFixturePath")),
):
    contract = project_cli_contracts[contract_name]
    for fixture_field in fixture_fields:
        fixture_digest_field = fixture_field.replace("Path", "Sha256")
        assert hashlib.sha256(Path(contract[fixture_field]).read_bytes()).hexdigest() == (
            contract[fixture_digest_field]
        )
project_cli_config_fixture = json.loads(
    Path(project_cli_contracts["project"]["fixturePath"]).read_text(
        encoding="utf-8"
    )
)
project_cli_lock_fixture = json.loads(
    Path(project_cli_contracts["projectLock"]["fixturePath"]).read_text(
        encoding="utf-8"
    )
)
project_cli_effective_fixture = json.loads(
    Path(project_cli_contracts["effectiveInputs"]["fixturePath"]).read_text(
        encoding="utf-8"
    )
)
assert project_cli_config_fixture["schema"] == "wordpress-hx.project.v1"
assert project_cli_lock_fixture["schema"] == "wordpress-hx.project-lock.v1"
assert project_cli_lock_fixture["lockDigest"] == (
    project_cli_contracts["projectLock"]["lockDigest"]
)
assert project_cli_effective_fixture["schema"] == (
    "wordpress-hx.effective-inputs.v1"
)
assert project_cli_effective_fixture["fingerprint"] == (
    project_cli_contracts["effectiveInputs"]["fingerprint"]
)
assert project_cli_contracts["events"]["identity"] == (
    "wordpress-hx.cli-event.v1"
)
project_cli_configuration = project_cli_architecture["configurationAuthority"]
assert project_cli_configuration["bootstrapPath"] == "wordpress-hx.json"
assert project_cli_configuration["bootstrapGeneratedByCli"] is True
assert project_cli_configuration["bootstrapIsApplicationModuleGraph"] is False
assert project_cli_configuration["typedDevelopmentServices"] is True
assert project_cli_configuration["handwrittenHxmlRequired"] is False
assert project_cli_configuration[
    "handwrittenPhpJsTsJsonOrCssRequiredForGreenfield"
] is False
assert project_cli_configuration["implicitLockMigrationDuringBuild"] is False
project_cli_commands = project_cli_architecture["commandContract"]
assert project_cli_commands["package"] == "@wordpress-hx/cli"
assert project_cli_commands["binary"] == "wphx"
assert project_cli_commands["legacyPrototypeBinary"] == "wphx-sdk"
assert project_cli_commands["legacyPrototypePublicCompatibilityGuaranteed"] is False
assert project_cli_commands["watchCommand"] is None
assert project_cli_commands["compileWatchOnly"] == "wphx dev --services=none"
assert project_cli_commands["ciDefault"] == "direct-bounded-build"
assert project_cli_commands["machineOutput"] == "canonical-json-lines"
assert project_cli_architecture["buildStages"] == [
    "configuration",
    "profile-resolution",
    "haxe-typing-and-plan",
    "php-emission",
    "browser-emission",
    "metadata-emission",
    "format-and-static-check",
    "asset-build",
    "artifact-validation",
    "ownership-publish",
]
project_cli_package_manager = project_cli_architecture["packageManager"]
assert project_cli_package_manager["supportedV1"] == "npm"
assert project_cli_package_manager["exactVersion"] == "10.9.2"
assert project_cli_package_manager["lockfileVersion"] == 3
assert project_cli_package_manager["implicitInstallDuringBuildCheckOrDev"] is False
assert project_cli_package_manager["pnpmYarnOrBunSupportClaimed"] is False
project_cli_inputs = project_cli_architecture["effectiveInputs"]
assert project_cli_inputs["contentDigestsRequired"] is True
assert project_cli_inputs["directoryDiscoveryRulesIncluded"] is True
assert project_cli_inputs["macroExternalInputsMustBeDeclared"] is True
assert project_cli_inputs["publicBuildEnvironmentValueDigestsIncluded"] is True
assert project_cli_inputs["runtimeAndSecretValuesIncluded"] is False
assert project_cli_inputs["absoluteCheckoutPathsIncluded"] is False
assert project_cli_inputs["mtimesPortsPidsOrClocksIncluded"] is False
assert project_cli_inputs["symlinksOrSpecialFilesAllowed"] is False
assert project_cli_inputs["incrementalPublication"] == (
    "complete-next-staging-through-adr-007"
)
project_cli_dev_loop = project_cli_architecture["developmentLoop"]
assert project_cli_dev_loop["command"] == "wphx dev"
assert project_cli_dev_loop["initialAtomicBuildBeforeArtifactDependentServices"] is True
assert project_cli_dev_loop["defaultDebounceMs"] == 100
assert project_cli_dev_loop["parallelBuildOrPublication"] is False
assert project_cli_dev_loop["failedRebuild"] == (
    "retain-exact-last-good-manifest-and-do-not-reload"
)
assert project_cli_dev_loop["reloadOnlyAfterManifestCommit"] is True
assert project_cli_dev_loop["productionReloadOrWatcherRuntime"] is False
assert project_cli_dev_loop["sigintExitCode"] == 130
project_cli_server = project_cli_architecture["compileServer"]
assert project_cli_server["defaultForDev"] == "managed-project-local-haxe-wait"
assert project_cli_server["defaultForBoundedCommands"] == "direct"
assert project_cli_server["compatibilityDigest"] == (
    project_cli_effective_fixture["compileServer"]["compatibilityDigest"]
)
assert project_cli_server["absoluteProjectRootPersisted"] is False
assert project_cli_server["arbitraryReachableServerAttach"] is False
assert project_cli_server["ownedServerStoppedOnShutdown"] is True
assert project_cli_server["attachedServerKilledByClient"] is False
assert project_cli_server["cacheMayChangeSemantics"] is False
project_cli_services = project_cli_architecture["developmentServices"]
assert project_cli_services["authority"] == "typed-haxe-semantic-plan"
assert project_cli_services["implicitShellCommands"] is False
assert project_cli_services["environmentAllowlistRequired"] is True
assert project_cli_services["secretValuesDurablyRecorded"] is False
assert project_cli_services["unrelatedPortOccupantKilled"] is False
assert project_cli_services["defaultReadinessTimeoutMs"] == 60000
assert project_cli_services["ownedProcessGroups"] is True
project_cli_references = project_cli_architecture["referencePatterns"]
assert len(project_cli_references) == 6
for project_cli_reference in project_cli_references:
    assert project_cli_reference["repository"] == "haxe.elixir.codex"
    assert project_cli_reference["commit"] == (
        "40254f38d9c07c069c7c3e19831096dcc2d6c95d"
    )
    assert sha1.fullmatch(project_cli_reference["blob"])
    assert sha256.fullmatch(project_cli_reference["sha256"])
    assert project_cli_reference["copiedBytes"] is False
    assert project_cli_reference["dependencyCreated"] is False
project_cli_verification = project_cli_architecture["verification"]
assert project_cli_verification["schemaCount"] == 4
assert project_cli_verification["effectiveFileCount"] == 9
assert project_cli_verification["discoveryRootCount"] == 5
assert project_cli_verification["toolchainComponentCount"] == 8
assert project_cli_verification["dryRunEventCount"] == 22
assert project_cli_verification["devEventCount"] == 23
assert project_cli_verification["negativeMutationCount"] == 28
assert project_cli_verification["haxeCommand"] == (
    "(cd fixtures/project-cli/project && haxe .wphx/bootstrap/project.hxml)"
)
assert project_cli_verification["haxeVersion"] == "4.3.7"
assert project_cli_verification["haxeFixtureTyping"] == "passed"
assert project_cli_verification["outcome"] == "passed"
assert hashlib.sha256(
    Path(project_cli_verification["validatorPath"]).read_bytes()
).hexdigest() == project_cli_verification["validatorSha256"]
assert project_cli_architecture["claims"]["architectureDecision"] == "accepted"
assert project_cli_architecture["claims"]["schemaAndFixtureContract"] == (
    "validated"
)
for unproven_project_cli_claim in (
    "sdk043ProductionCli",
    "sdk044RealWatchAndProcessSupervisor",
    "haxeServerRuntimeBehavior",
    "cleanInstalledConsumer",
    "wordpressDevelopmentService",
    "nextjsDevelopmentService",
    "automaticBrowserReload",
    "windowsWatcherAndProcessBehavior",
    "productionSupport",
):
    assert project_cli_architecture["claims"][unproven_project_cli_claim] == (
        "not-tested"
    )

assert project_cli_receipt["schemaVersion"] == 1
assert project_cli_receipt["receiptId"] == (
    "ADR-016-PROJECT-CLI-CONFIGURATION"
)
assert project_cli_receipt["bead"] == "wordpresshx-adr-016"
for project_cli_subject in project_cli_receipt["subject"].values():
    assert hashlib.sha256(Path(project_cli_subject["path"]).read_bytes()).hexdigest() == (
        project_cli_subject["sha256"]
    )
assert project_cli_receipt["contract"]["binary"] == "wphx"
assert project_cli_receipt["contract"]["developmentCommand"] == "wphx dev"
assert project_cli_receipt["contract"]["projectLockDigest"] == (
    project_cli_contracts["projectLock"]["lockDigest"]
)
assert project_cli_receipt["contract"]["effectiveInputsFingerprint"] == (
    project_cli_contracts["effectiveInputs"]["fingerprint"]
)
assert project_cli_receipt["contract"]["compileServerCompatibilityDigest"] == (
    project_cli_server["compatibilityDigest"]
)
assert project_cli_receipt["verification"]["schemaCount"] == 4
assert project_cli_receipt["verification"]["effectiveFileCount"] == 9
assert project_cli_receipt["verification"]["devEventCount"] == 23
assert project_cli_receipt["verification"]["negativeMutationCount"] == 28
assert project_cli_receipt["verification"]["haxeCommand"] == (
    project_cli_verification["haxeCommand"]
)
assert project_cli_receipt["verification"]["haxeVersion"] == "4.3.7"
assert project_cli_receipt["verification"]["haxeFixtureTyping"] == "passed"
assert project_cli_receipt["verification"]["outcome"] == "passed"
assert project_cli_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert project_cli_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert project_cli_receipt["referenceReview"]["genesSourceChanged"] is False
project_cli_hosted = project_cli_receipt["hostedWorkflow"]
assert project_cli_hosted["workflow"] == "Repository bootstrap"
assert project_cli_hosted["jobs"]["contract"]["name"] == "repository"
assert project_cli_hosted["jobs"]["haxeTyping"]["name"] == "haxe"
assert project_cli_hosted["required"] is True
if project_cli_hosted["status"] == "pending-first-hosted-main-run":
    assert project_cli_hosted["runId"] is None
    assert project_cli_hosted["jobs"]["contract"]["jobId"] is None
    assert project_cli_hosted["jobs"]["haxeTyping"]["jobId"] is None
    assert project_cli_hosted["commit"] is None
elif project_cli_hosted["status"] == "passed":
    assert isinstance(project_cli_hosted["runId"], int)
    assert isinstance(project_cli_hosted["jobs"]["contract"]["jobId"], int)
    assert isinstance(project_cli_hosted["jobs"]["haxeTyping"]["jobId"], int)
    assert sha1.fullmatch(project_cli_hosted["commit"])
else:
    raise AssertionError("project CLI hosted status is invalid")
assert project_cli_receipt["claims"]["architectureDecision"] == "accepted"
assert project_cli_receipt["claims"]["schemaAndFixtureContract"] == "validated"
for unproven_project_cli_receipt_claim in (
    "sdk043ProductionCli",
    "sdk044RealWatchAndProcessSupervisor",
    "haxeServerRuntimeBehavior",
    "cleanInstalledConsumer",
    "wordpressDevelopmentService",
    "nextjsDevelopmentService",
    "automaticBrowserReload",
    "windowsWatcherAndProcessBehavior",
    "productionSupport",
):
    assert project_cli_receipt["claims"][
        unproven_project_cli_receipt_claim
    ] == "not-tested"

assert project_cli_implementation["schemaVersion"] == 1
assert project_cli_implementation["bead"] == "wordpresshx-sdk-043"
assert project_cli_implementation["status"] in {
    "implemented-sdk043-local-verified",
    "implemented-sdk043-hosted-verified",
}
sdk043_contracts = project_cli_implementation["contracts"]
assert sdk043_contracts["project"]["identity"] == (
    project_cli_contracts["project"]["identity"]
)
assert sdk043_contracts["projectLock"]["identity"] == (
    project_cli_contracts["projectLock"]["identity"]
)
assert sdk043_contracts["effectiveInputs"]["identity"] == (
    project_cli_contracts["effectiveInputs"]["identity"]
)
assert sdk043_contracts["events"]["identity"] == (
    project_cli_contracts["events"]["identity"]
)
for sdk043_contract_name in (
    "project",
    "projectLock",
    "effectiveInputs",
    "events",
):
    assert Path(sdk043_contracts[sdk043_contract_name]["schema"]).is_file()
sdk043_command = project_cli_implementation["commandSurface"]
assert sdk043_command["binary"] == "wphx"
assert sdk043_command["legacyTraceBinary"] == "wphx-sdk"
assert sdk043_command["commands"] == [
    "build",
    "check",
    "inspect",
    "clean",
    "doctor",
    "dev",
    "trace",
]
cli_package_manifest = json.loads(
    Path("packages/cli/package.json").read_text(encoding="utf-8")
)
assert cli_package_manifest["bin"] == {
    "wphx": "build/wphx.js",
    "wphx-sdk": "build/index.js",
}
assert Path("packages/cli/.npmignore").read_text(encoding="utf-8") == (
    "/*\n!/build/\n!/build/**\n"
)
assert project_cli_implementation["stages"] == (
    project_cli_architecture["buildStages"]
)
sdk043_implementation = project_cli_implementation["implementation"]
assert sdk043_implementation["language"] == "Haxe"
assert sdk043_implementation["target"] == "Genes-emitted-Node-ESM"
assert sdk043_implementation["genesSourceChanged"] is False
assert sdk043_implementation["genesPullRequest"] is None
assert sdk043_implementation["siblingDependencyCreated"] is False
assert sdk043_implementation["handwrittenJavascriptImplementation"] is False
assert sdk043_implementation["exactToolchain"]["haxe"] == (
    cli_dependency_lock["haxe"]["version"]
)
assert sdk043_implementation["exactToolchain"]["genesCommit"] == (
    cli_dependency_lock["compiler"]["commit"]
)
assert sdk043_implementation["exactToolchain"]["nodeImage"] == (
    cli_dependency_lock["runtime"]["image"]
)
sdk043_side_effects = project_cli_implementation["sideEffects"]
for sdk043_no_write_command in (
    "check",
    "doctor",
    "inspect",
    "buildDryRun",
    "failedCommand",
):
    assert sdk043_side_effects[sdk043_no_write_command] == "none"
assert sdk043_side_effects["forcePath"] is False
sdk043_dev_handoff = project_cli_implementation["devHandoff"]
assert sdk043_dev_handoff["commandParsed"] is True
assert sdk043_dev_handoff["implementationManifest"] == (
    "manifests/dev-loop-implementation.json"
)
assert sdk043_dev_handoff["watcherImplemented"] is True
assert sdk043_dev_handoff["compilerServerImplemented"] is True
assert sdk043_dev_handoff["servicesImplemented"] is False
assert sdk043_dev_handoff["reloadImplemented"] is False
for sdk043_preserved in project_cli_implementation["compatibility"].values():
    if not isinstance(sdk043_preserved, dict) or "path" not in sdk043_preserved:
        continue
    assert hashlib.sha256(Path(sdk043_preserved["path"]).read_bytes()).hexdigest() == (
        sdk043_preserved["sha256"]
    )
for sdk043_reference in project_cli_implementation["referencePatterns"]:
    assert sdk043_reference["repository"] == "haxe.elixir.codex"
    assert sdk043_reference["commit"] == (
        "40254f38d9c07c069c7c3e19831096dcc2d6c95d"
    )
    assert sha1.fullmatch(sdk043_reference["blob"])
    assert sha256.fullmatch(sdk043_reference["sha256"])
    assert sdk043_reference["copiedBytes"] is False
sdk043_verification = project_cli_implementation["verification"]
assert sdk043_verification["command"] == (
    "bash scripts/project-cli/test-production.sh"
)
assert sdk043_verification["compileReplayCount"] == 2
assert sdk043_verification["positiveCases"] == 15
assert sdk043_verification["negativeCases"] == 15
assert sdk043_verification["noWriteAssertions"] == 17
assert sdk043_verification["acceptedFixtureEffectiveFingerprint"] == (
    project_cli_contracts["effectiveInputs"]["fingerprint"]
)
assert sdk043_verification["historicalTraceCompatibility"] == (
    "php-and-browser-suites-passed"
)
assert sdk043_verification["outcome"] == "passed"
sdk043_adoption = project_cli_implementation["aggregateLockAdoption"]
assert sdk043_adoption["toolchainLockSha256"] == hashlib.sha256(
    Path("manifests/toolchain.lock.json").read_bytes()
).hexdigest()
assert sdk043_adoption["cliManifestSha256"] == hashlib.sha256(
    Path("packages/cli/package.json").read_bytes()
).hexdigest()
assert sdk043_adoption["cliLockSha256"] == hashlib.sha256(
    Path("packages/cli/package-lock.json").read_bytes()
).hexdigest()
for sdk043_adoption_invariant in (
    "dependencySetChanged",
    "toolOrRuntimeIdentityChanged",
    "semanticNodesProjectionsSourcesOrArtifactBytesChanged",
    "ownershipOperationSetOrArtifactBytesChanged",
    "publicationAuthorized",
):
    assert sdk043_adoption[sdk043_adoption_invariant] is False
for sdk043_unproven_claim in (
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "targetEmitterIntegration",
    "productionSupport",
):
    assert project_cli_implementation["claims"][sdk043_unproven_claim] == (
        "not-tested"
    )
assert project_cli_implementation["claims"]["productionWphxDevWatcher"] == (
    "runtime-tested-local"
)

assert sdk043_receipt["schemaVersion"] == 1
assert sdk043_receipt["receiptId"] == "SDK-043-PROJECT-CLI"
assert sdk043_receipt["bead"] == "wordpresshx-sdk-043"
assert sdk043_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}

verify_versioned_subject(sdk043_receipt)
sdk043_current_architecture_sha256 = hashlib.sha256(
    Path("manifests/project-cli-implementation.json").read_bytes()
).hexdigest()
if sdk043_receipt["status"] == "implemented-hosted-pending":
    assert sdk043_receipt["subject"]["architecture"]["sha256"] == (
        sdk043_current_architecture_sha256
    )
else:
    assert sdk043_receipt["historicalVerification"]["subjectCommit"] == (
        sdk043_receipt["hostedWorkflow"]["commit"]
    )
assert sdk043_receipt["implementation"]["binary"] == "wphx"
assert sdk043_receipt["implementation"]["legacyTraceBinary"] == "wphx-sdk"
assert sdk043_receipt["implementation"]["genesSourceChanged"] is False
assert sdk043_receipt["implementation"]["genesPullRequest"] is None
assert sdk043_receipt["verification"]["outcome"] == "passed"
assert sdk043_receipt["verification"]["positiveCases"] == 15
assert sdk043_receipt["verification"]["negativeCases"] == 15
assert sdk043_receipt["verification"]["noWriteAssertions"] == 17
assert sdk043_receipt["verification"]["effectiveFingerprint"] == (
    project_cli_contracts["effectiveInputs"]["fingerprint"]
)
assert sdk043_receipt["verification"]["legacyPhpTrace"]["outcome"] == (
    "passed"
)
assert sdk043_receipt["verification"]["legacyBrowserTrace"]["outcome"] == (
    "passed"
)
for sdk043_aggregate_gate in (
    "aggregateG0Gate",
    "semanticPlanContractGate",
    "ownershipContractGate",
    "repositoryAggregateGate",
):
    assert sdk043_receipt["verification"][sdk043_aggregate_gate] == "passed"
assert "Test production project CLI foundation" in workflow_text
assert "bash scripts/project-cli/test-production.sh" in workflow_text
sdk043_hosted = sdk043_receipt["hostedWorkflow"]
assert sdk043_hosted["workflow"] == "Repository bootstrap"
assert sdk043_hosted["job"] == "haxe"
assert sdk043_hosted["step"] == "Test production project CLI foundation"
assert sdk043_hosted["required"] is True
if sdk043_hosted["status"] == "pending-first-main-run":
    assert sdk043_receipt["status"] == "implemented-hosted-pending"
    assert project_cli_implementation["status"] == (
        "implemented-sdk043-local-verified"
    )
    assert sdk043_receipt["implementation"]["implementationCommit"] is None
    assert sdk043_hosted["runId"] is None
    assert sdk043_hosted["jobId"] is None
    assert sdk043_hosted["commit"] is None
    sdk043_evidence_level = "runtime-tested-local"
elif sdk043_hosted["status"] == "passed":
    assert sdk043_receipt["status"] == "verified"
    assert project_cli_implementation["status"] == (
        "implemented-sdk043-hosted-verified"
    )
    assert sha1.fullmatch(
        sdk043_receipt["implementation"]["implementationCommit"]
    )
    assert isinstance(sdk043_hosted["runId"], int)
    assert isinstance(sdk043_hosted["jobId"], int)
    assert sha1.fullmatch(sdk043_hosted["commit"])
    sdk043_evidence_level = "runtime-tested-hosted"
else:
    raise AssertionError("SDK-043 project CLI hosted status is invalid")
assert project_cli_implementation["claims"]["sdk043ProjectCli"] == (
    sdk043_evidence_level
)
assert sdk043_receipt["claims"]["sdk043ProjectCli"] == sdk043_evidence_level
for sdk043_unproven_receipt_claim in (
    "productionWphxDevWatcher",
    "wordpressRuntimeCompatibility",
    "nextjsRuntimeCompatibility",
    "targetEmitterIntegration",
    "productionSupport",
):
    assert sdk043_receipt["claims"][sdk043_unproven_receipt_claim] == (
        "not-tested"
    )

assert sdk043_receipt["sdk042CompatibilityReverification"] == {
    "producedArtifacts": [
        "build/nextjs/.wphx/effective-inputs.json",
        "dist/wordpress-hx-build.json",
        "dist/wordpress-hx.zip",
    ],
    "positiveCases": 15,
    "negativeCases": 15,
    "noWriteAssertions": 17,
    "command": "bash scripts/project-cli/test-production.sh",
    "outcome": "passed-local",
    "hostedEvidenceOwner": "SDK-042-DETERMINISTIC-BUILD",
}

for sdk043_compatibility_receipt in (sdk025_receipt, sdk034_receipt):
    sdk043_compatibility = sdk043_compatibility_receipt[
        "sdk043CompatibilityReverification"
    ]
    assert sdk043_compatibility["requiredBins"] == {
        "wphx": "build/wphx.js",
        "wphx-sdk": "build/index.js",
    }
    assert sdk043_compatibility["outcome"] == "passed-local"
    assert sdk043_compatibility["hostedEvidenceOwner"] == (
        sdk043_receipt["receiptId"]
    )

assert dev_loop_implementation["schemaVersion"] == 1
assert dev_loop_implementation["bead"] == "wordpresshx-sdk-044"
assert dev_loop_implementation["status"] in {
    "implemented-sdk044-core-local-verified",
    "implemented-sdk044-core-hosted-verified",
    "implemented-sdk044-services-local-verified",
    "implemented-sdk044-services-hosted-verified",
    "implemented-sdk044-reload-local-verified",
    "implemented-sdk044-reload-hosted-verified",
}
assert dev_loop_implementation["scope"] == (
    "managed-compiler-effective-watch-atomic-publish-typed-development-service-supervision-and-wordpress-browser-reload"
)
sdk044_command = dev_loop_implementation["command"]
assert sdk044_command["default"] == "wphx dev"
assert sdk044_command["compileWatchOnly"] == "wphx dev --services=none"
assert sdk044_command["boundedCi"] == "wphx build"
assert sdk044_command["defaultDebounceMs"] == 100
assert sdk044_command["sigintExitCode"] == 130
assert sdk044_command["sigtermExitCode"] == 143
sdk044_code = dev_loop_implementation["implementation"]
assert sdk044_code["language"] == "Haxe"
assert sdk044_code["target"] == "Genes-emitted-Node-ESM"
for sdk044_code_path in (
    "entry",
    "buildTransaction",
    "watchGraph",
    "managedCompiler",
    "compilerRunner",
    "servicePlanReader",
    "serviceSupervisor",
    "developmentProcessLaunch",
    "wordpressProvider",
    "browserReloadServer",
    "wordpressReloadAdapter",
    "browserReloadClientSource",
    "browserReloadClientProfile",
    "browserReloadClientAsset",
    "closedJsonBoundary",
    "eventStream",
    "publisher",
):
    assert Path(sdk044_code[sdk044_code_path]).is_file()
assert sdk044_code["genesSourceChanged"] is False
assert sdk044_code["genesPullRequest"] is None
assert sdk044_code["siblingDependencyCreated"] is False
assert sdk044_code["handwrittenJavascriptImplementation"] is False
sdk044_watch = dev_loop_implementation["watch"]
assert sdk044_watch["authority"] == "wordpress-hx.effective-inputs.v1"
assert sdk044_watch["criticalIdentityRoles"] == (
    project_cli_effective_fixture["compileServer"]["restartFileRoles"]
)
assert sdk044_watch["ignoredRootsFromEffectiveGraph"] is True
assert sdk044_watch["sortedDeduplicatedChanges"] is True
assert sdk044_watch["burstCoalescing"] is True
assert sdk044_watch["parallelBuilds"] is False
assert sdk044_watch["unknownImpact"] == "full-atomic-rebuild"
assert sdk044_watch["partialTargetPublish"] is False
sdk044_publication = dev_loop_implementation["publication"]
assert sdk044_publication["initialCompleteBuildBeforeWatchReady"] is True
assert sdk044_publication["inputStabilityRecheckedBeforePublish"] is True
assert sdk044_publication["unstableInputDiagnostic"] == "WPHX2200"
assert sdk044_publication["manifestPublishedLast"] is True
assert sdk044_publication["generationAdvancesOnlyAfterPublish"] is True
assert sdk044_publication["incrementalEqualsCleanOracle"] is True
assert sdk044_publication["reloadOnlyAfterCompletePublish"] is True
assert sdk044_publication["reloadAdapterImplemented"] is True
sdk044_server = dev_loop_implementation["compileServer"]
assert sdk044_server["kind"] == "managed-project-local-haxe-wait"
assert sdk044_server["leasePath"] == ".wphx/runtime/compiler-server.json"
assert sdk044_server["projectRootRecordedAsDigestOnly"] is True
assert sdk044_server["compatibilityAlgorithm"] == (
    project_cli_effective_fixture["compileServer"][
        "compatibilityDigestAlgorithm"
    ]
)
assert sdk044_server["arbitraryServerAttach"] is False
assert sdk044_server["semanticDifferenceOnFallback"] is False
assert sdk044_server["compatibilityChangeRestartsOwnedServer"] is True
assert sdk044_server["ownedServerStoppedOnShutdown"] is True
sdk044_services = dev_loop_implementation["services"]
assert sdk044_services["authority"] == "validated-typed-haxe-semantic-plan"
assert sdk044_services["implicitShellCommands"] is False
assert sdk044_services["compileWatchOnlyImplemented"] is True
for sdk044_implemented_service_part in (
    "serviceSupervisorImplemented",
    "readinessImplemented",
    "servicePortReservationImplemented",
    "dependencyOrderImplemented",
    "boundedGraphRestartImplemented",
    "reverseShutdownImplemented",
    "runtimeEnvironmentAllowlistImplemented",
    "wordpressProviderImplemented",
    "postPublishReloadRequestImplemented",
    "wordpressReloadImplemented",
):
    assert sdk044_services[sdk044_implemented_service_part] is True
for sdk044_unimplemented_service_part in (
    "nextjsReloadImplemented",
):
    assert sdk044_services[sdk044_unimplemented_service_part] is False
sdk044_wordpress_lock = cli_dependency_lock["wordpressDevelopmentProvider"]
assert sdk044_wordpress_lock == {
    "profile": "wp70-release",
    "executor": "docker-compose-v2-host-capability",
    "sourceLock": "docker/images.lock.json",
    "sourceLockSha256": hashlib.sha256(
        Path("docker/images.lock.json").read_bytes()
    ).hexdigest(),
    "wordpressImage": image_lock["images"]["wordpress70Php84"]["reference"],
    "databaseImage": image_lock["images"]["mariadb"]["reference"],
}
sdk044_wordpress = dev_loop_implementation["wordpressProvider"]
assert sdk044_wordpress == {
    **sdk044_wordpress_lock,
    "dependencyLock": "packages/cli/dependency-lock.json",
    "runtimeConfiguration": "private-canonical-generated-compose-json",
    "runtimeConfigurationMode": 384,
    "secretTransport": "required-environment-interpolation",
    "hostExecutorEnvironment": "closed-docker-cli-allowlist",
    "publishedPortBinding": "127.0.0.1-only",
    "reloadTransport": "loopback-capability-sse",
    "reloadCapabilityEntropyBits": 256,
    "reloadOriginPolicy": "exact-admitted-wordpress-service-origin",
    "reloadClient": "haxe-authored-genes-1.36.3-esbuild-0.27.2-embedded-asset",
    "reloadAdapter": "read-only-secret-free-0755-directory-0644-development-mu-plugin",
    "reloadProductionArtifact": False,
    "shellExecution": False,
    "normalShutdown": "foreground-compose-up-then-bounded-compose-down-reload-client-close-and-private-runtime-file-removal",
    "exactImageRuntimeEvidence": "SDK-090-WORDPRESS-HARNESS",
}
sdk044_browser_reload_lock = cli_dependency_lock["browserReload"]
assert sdk044_browser_reload_lock == {
    "authoringLanguage": "Haxe",
    "source": sdk044_code["browserReloadClientSource"],
    "sourceSha256": hashlib.sha256(
        Path(sdk044_code["browserReloadClientSource"]).read_bytes()
    ).hexdigest(),
    "profile": sdk044_code["browserReloadClientProfile"],
    "profileSha256": hashlib.sha256(
        Path(sdk044_code["browserReloadClientProfile"]).read_bytes()
    ).hexdigest(),
    "compiler": "genes-ts@1.36.3",
    "bundler": "esbuild@0.27.2",
    "asset": sdk044_code["browserReloadClientAsset"],
    "assetSha256": hashlib.sha256(
        Path(sdk044_code["browserReloadClientAsset"]).read_bytes()
    ).hexdigest(),
    "transport": "loopback-capability-sse",
    "productionArtifact": False,
}
sdk044_wordpress_source = Path(sdk044_code["wordpressProvider"]).read_text(
    encoding="utf-8"
)
assert (
    'WORDPRESS_IMAGE = "' + sdk044_wordpress_lock["wordpressImage"] + '"'
    in sdk044_wordpress_source
)
assert (
    'DATABASE_IMAGE = "' + sdk044_wordpress_lock["databaseImage"] + '"'
    in sdk044_wordpress_source
)
sdk044_verification = dev_loop_implementation["verification"]
assert sdk044_verification["command"] == (
    "bash scripts/dev-loop/test-production.sh"
)
assert sdk044_verification["summarySchema"] == (
    "wordpress-hx.sdk044-production-summary.v1"
)
assert sdk044_verification["compileReplayCount"] == 2
assert sdk044_verification["nodeVersion"] == "22.17.0"
assert sdk044_verification["nodeImage"] == (
    cli_dependency_lock["runtime"]["image"]
)
assert sdk044_verification["containerNetwork"] == "none"
assert sdk044_verification["watchFilesystem"] == "docker-bind-mount"
assert sdk044_verification["publishedGenerations"] == 7
assert sdk044_verification["compilerStarts"] == 3
for sdk044_passed_proof in (
    "initialBuildBeforeWatch",
    "sourceAndAssetBurst",
    "failedTypingRetention",
    "nestedHxxCreateRenameDelete",
    "invalidAndRepairedLock",
    "compilerIdentityRestart",
    "cliOwnedProjectionDriftRetention",
    "editDuringBuildFollowUp",
    "typedPlanAuthentication",
    "externalDependencyOrderAndPortCollision",
    "httpLogAndTcpReadiness",
    "runtimeSecretNonPropagation",
    "boundedCrashRestartExhaustion",
    "reverseServiceShutdown",
    "wordpressProviderControlledProcess",
    "wordpressComposeV2Syntax",
    "wordpressGeneratedConfigPrivacy",
    "wordpressSecretPlaceholder",
    "wordpressUnchangedServiceRetention",
    "postPublishReloadRequest",
    "wordpressChromiumFullPageReload",
    "failedBuildBrowserReloadSuppression",
    "reloadProductionArtifactAbsence",
    "strictHaxeBoundaryGuard",
    "sigintCleanup",
    "durablePathPrivacy",
):
    assert sdk044_verification[sdk044_passed_proof] == "passed"
assert sdk044_verification["incrementalAndCleanOwnedBytes"] == (
    "byte-identical"
)
assert sdk044_verification["browserReloadClientCompileReplay"] == (
    "byte-identical"
)
assert sdk044_verification["browserReloadClientAssetSha256"] == (
    sdk044_browser_reload_lock["assetSha256"]
)
assert sdk044_verification["reloadEndpointSecurityMutations"] == 5
assert sdk044_verification["outcome"] == "passed"
assert dev_loop_implementation["claims"]["wordpressExactImagePair"] == (
    "runtime-tested-by-sdk090"
)
sdk044_reference_authorities = {
    ("haxe.elixir.codex", "lib/haxe_watcher.ex"): (
        "40254f38d9c07c069c7c3e19831096dcc2d6c95d",
        "7a54b03b3c2fdf03caf53c7ac9e1aeba5cb0c418",
        "b5243f3279859d6d9fa50184af5e5450bc54fb34996725699bc5bcd1fe6c08b0",
        "debounced-effective-input-watcher",
    ),
    ("haxe.elixir.codex", "lib/haxe_server.ex"): (
        "40254f38d9c07c069c7c3e19831096dcc2d6c95d",
        "db684a03e104cdaaa2e1fe23b07d7a99b64d1581",
        "1419b50305b80ae229cf441c4b9764b87732917c911740565a1c1f2c7352110c",
        "owned-compatible-haxe-wait-lifecycle",
    ),
    ("haxe.ruby", "test/development_watcher_test.rb"): (
        "d20f3520997616e07c870f91b867717f28216928",
        "8b91637e4fd9fe551b075cbe6fd7ba851938efb6",
        "753eb60e7932435a3d5b285148b698c50e9f9b1a47990721c3bdad2227b3e163",
        "ensure-owned-development-process-shutdown",
    ),
    ("genes", "tools/ts2hx/src/test-runtime-profile.ts"): (
        "2b4b71b00528fb376f7f0f8527237cf336b0f36b",
        "1941a9972c4b6cbc124b66ab7fd53149a736934f",
        "7a0bcd961b3cdbf73e25b910361ed4abad1dd24ed237cd3e1b0d75711abf40f6",
        "bounded-sigterm-to-sigkill-child-cleanup",
    ),
}
assert len(dev_loop_implementation["referencePatterns"]) == len(
    sdk044_reference_authorities
)
for sdk044_reference in dev_loop_implementation["referencePatterns"]:
    sdk044_reference_authority = sdk044_reference_authorities[
        (sdk044_reference["repository"], sdk044_reference["path"])
    ]
    assert sdk044_reference["commit"] == sdk044_reference_authority[0]
    assert sdk044_reference["blob"] == sdk044_reference_authority[1]
    assert sdk044_reference["sha256"] == sdk044_reference_authority[2]
    assert sdk044_reference["concept"] == sdk044_reference_authority[3]
    assert sha1.fullmatch(sdk044_reference["blob"])
    assert sha256.fullmatch(sdk044_reference["sha256"])
    assert sdk044_reference["copiedBytes"] is False
    assert sdk044_reference["dependencyCreated"] is False
for sdk044_unproven_claim in (
    "wordpressDevelopmentService",
    "nextjsDevelopmentService",
    "windowsWatcherAndProcessBehavior",
    "networkFilesystemBehavior",
    "productionSupport",
):
    assert dev_loop_implementation["claims"][sdk044_unproven_claim] == (
        "not-tested"
    )
assert dev_loop_implementation["claims"]["publicPackagePublication"] == (
    "blocked"
)

assert sdk044_receipt["schemaVersion"] == 1
assert sdk044_receipt["receiptId"] == "SDK-044-DEV-LOOP"
assert sdk044_receipt["bead"] == "wordpresshx-sdk-044"
assert sdk044_receipt["status"] in {"implemented-hosted-pending", "verified"}

verify_versioned_subject(sdk044_receipt)
sdk044_current_implementation_sha256 = hashlib.sha256(
    Path("manifests/dev-loop-implementation.json").read_bytes()
).hexdigest()
if sdk044_receipt["status"] == "implemented-hosted-pending":
    assert sdk044_receipt["subject"]["implementationManifest"]["sha256"] == (
        sdk044_current_implementation_sha256
    )
else:
    assert sdk044_receipt["historicalVerification"]["subjectCommit"] == (
        sdk044_receipt["hostedWorkflow"]["commit"]
    )
assert sdk044_receipt["verification"] == {
    "command": "bash scripts/dev-loop/test-production.sh",
    "outcome": "passed",
    "compileReplayCount": 2,
    "nodeVersion": "22.17.0",
    "containerNetwork": "none",
    "publishedGenerations": 7,
    "compilerStarts": 3,
    "serviceScenarios": 4,
    "externalServiceStarts": 6,
    "portCollisionRecovery": "passed",
    "cliOwnedProjectionDriftRetention": "passed",
    "httpLogAndTcpReadiness": "passed",
    "restartExhaustionExitCode": 7,
    "runtimeSecretNonPropagation": "passed",
    "wordpressProviderControlledProcess": "passed",
    "wordpressComposeV2Syntax": "passed",
    "wordpressGeneratedConfigPrivacy": "passed",
    "wordpressSecretPlaceholder": "passed",
    "wordpressUnchangedServiceRetention": "passed",
    "postPublishReloadRequest": "passed",
    "browserReloadClientCompileReplay": "byte-identical",
    "browserReloadClientAssetSha256": "cc9aa72db548a9d7379062bed2b2a7d5889571a8bc774dc1958eb0a6b369b694",
    "realChromiumFullPageReload": "passed",
    "failedBuildBrowserReloadSuppression": "passed",
    "reloadEndpointSecurityMutations": 5,
    "reloadProductionArtifactAbsence": "passed",
    "strictHaxeBoundaryGuard": "passed",
    "incrementalAndCleanOwnedBytes": "byte-identical",
    "failedBuildRetainedExactOwnedBytes": "passed",
    "compilerLeaseRemovedOnSigint": "passed",
    "durablePathPrivacy": "passed",
}
assert "Test production compile and watch development loop" in workflow_text
assert "bash scripts/dev-loop/test-production.sh" in workflow_text
sdk044_hosted = sdk044_receipt["hostedWorkflow"]
assert sdk044_hosted["workflow"] == "Repository bootstrap"
assert sdk044_hosted["job"] == "haxe"
assert sdk044_hosted["step"] == (
    "Test production compile and watch development loop"
)
assert sdk044_hosted["required"] is True
if sdk044_hosted["status"] == "pending-first-main-run":
    assert sdk044_receipt["status"] == "implemented-hosted-pending"
    assert dev_loop_implementation["status"] == (
        "implemented-sdk044-reload-local-verified"
    )
    assert sdk044_receipt["implementationCommit"] is None
    assert sdk044_hosted["runId"] is None
    assert sdk044_hosted["jobId"] is None
    assert sdk044_hosted["commit"] is None
    sdk044_evidence_suffix = "local"
elif sdk044_hosted["status"] == "passed":
    assert sdk044_receipt["status"] == "verified"
    assert dev_loop_implementation["status"] == (
        "implemented-sdk044-reload-hosted-verified"
    )
    assert sha1.fullmatch(sdk044_receipt["implementationCommit"])
    assert isinstance(sdk044_hosted["runId"], int)
    assert isinstance(sdk044_hosted["jobId"], int)
    assert sha1.fullmatch(sdk044_hosted["commit"])
    sdk044_evidence_suffix = "hosted"
else:
    raise AssertionError("SDK-044 dev-loop hosted status is invalid")
for sdk044_claim_record in (
    dev_loop_implementation["claims"],
    sdk044_receipt["claims"],
):
    for sdk044_runtime_claim in (
        "productionWphxDevCompileWatch",
        "atomicIncrementalPublication",
        "lastGoodRetention",
    ):
        assert sdk044_claim_record[sdk044_runtime_claim] == (
            "runtime-tested-" + sdk044_evidence_suffix
        )
    assert sdk044_claim_record["managedCompilerLifecycle"] == (
        "controlled-process-runtime-tested-" + sdk044_evidence_suffix
    )
    assert sdk044_claim_record["externalDevelopmentService"] == (
        "controlled-process-runtime-tested-" + sdk044_evidence_suffix
    )
    assert sdk044_claim_record["wordpressDevelopmentProvider"] == (
        "controlled-process-and-compose-syntax-runtime-tested-"
        + sdk044_evidence_suffix
    )
    assert sdk044_claim_record["postPublishReloadRequest"] == (
        "controlled-event-runtime-tested-" + sdk044_evidence_suffix
    )
    assert sdk044_claim_record["automaticBrowserReload"] == (
        "controlled-wordpress-boundary-real-chromium-runtime-tested-"
        + sdk044_evidence_suffix
    )

assert plugin_development_implementation["schemaVersion"] == 1
assert plugin_development_implementation["bead"] == "wordpresshx-sdk-044.3"
assert plugin_development_implementation["status"] in {
    "implemented-sdk044-plugin-development-hosted-pending",
    "implemented-sdk044-plugin-development-hosted-verified",
}
assert plugin_development_implementation["scope"] == (
    "compiler-inferred-generated-plugin-wordpress-development"
)
sdk044_plugin_ergonomics = plugin_development_implementation[
    "haxeFirstErgonomics"
]
assert sdk044_plugin_ergonomics == {
    "maintainedAuthority": "WordPress.plugin()",
    "additionalDevelopmentDeclarations": 0,
    "defaultCommand": "wphx dev",
    "compileWatchOnlyOptOut": "wphx dev --services=none",
    "handwrittenPhpRequired": False,
    "handwrittenJavascriptOrTypescriptRequired": False,
    "handwrittenComposeRequired": False,
    "handwrittenWordPressConfigurationRequired": False,
}
sdk044_plugin_inference = plugin_development_implementation["inference"]
assert sdk044_plugin_inference == {
    "authority": "process-local-typed-compiler-PluginPlan",
    "timing": "after-successful-manifest-last-plugin-publication",
    "filenameOrScaffoldKindInference": False,
    "explicitGeneratedServicePlanPrecedence": True,
    "missingPlanBehavior": "no-inferred-service",
    "incompleteOrExtraPluginTreeDiagnostic": "WPHX2332",
    "pluginValidation": (
        "re-derive-current-emission-and-compare-exact-file-set-and-sha256-bytes"
    ),
    "mount": "exact-validated-plugin-directory-read-only",
    "generatedPluginHostPermissions": (
        "haxe-publisher-enforced-directory-0755-file-0644-every-generation-and-no-op"
    ),
}
sdk044_plugin_provider = plugin_development_implementation["provider"]
assert sdk044_plugin_provider["profile"] == "wp70-release"
assert sdk044_plugin_provider["executor"] == (
    "docker-compose-v2-host-capability"
)
assert sdk044_plugin_provider["wordpressImage"] == (
    sdk044_wordpress_lock["wordpressImage"]
)
assert sdk044_plugin_provider["databaseImage"] == (
    sdk044_wordpress_lock["databaseImage"]
)
assert sdk044_plugin_provider["installation"] == (
    "fresh-native-wordpress-install"
)
assert sdk044_plugin_provider["bootstrapStartBarrier"] == (
    "wordpress-healthcheck-complete-core-includes-reload-adapter-and-plugin-entry"
)
assert sdk044_plugin_provider["reloadAdapterMount"] == (
    "private-mu-plugin-directory-read-only"
)
assert sdk044_plugin_provider["reloadAdapterScope"] == (
    "private-static-closure-no-global-symbols"
)
assert sdk044_plugin_provider["reloadAdapterHostPermissions"] == (
    "directory-0755-file-0644-secret-free-environment-values-only"
)
assert sdk044_plugin_provider["activePluginHeader"] == (
    "wordpress-send-headers-hook-after-active-plugin-gate"
)
assert sdk044_plugin_provider["activation"] == (
    "native-activate-plugin-before-readiness"
)
assert sdk044_plugin_provider["readiness"] == (
    "bootstrap-ready-log-plus-two-hundred-range-wp-json-and-exact-active-plugin-header"
)
assert sdk044_plugin_provider["readinessTimeoutDiagnostics"] == (
    "redacted-http-status-sentinel-and-header-state"
)
assert sdk044_plugin_provider["shellExecution"] is False
assert sdk044_plugin_provider["productionRuntimeDependency"] is False
sdk044_plugin_shutdown = plugin_development_implementation["shutdown"]
for sdk044_plugin_cleanup in (
    "ownedContainersRemoved",
    "ownedNetworkRemoved",
    "ownedNamedAndAnonymousVolumesRemoved",
    "privateComposeBootstrapAndReloadFilesRemoved",
    "compilerLeaseRemoved",
):
    assert sdk044_plugin_shutdown[sdk044_plugin_cleanup] is True

sdk044_plugin_code = plugin_development_implementation["implementation"]
assert sdk044_plugin_code["language"] == "Haxe"
assert sdk044_plugin_code["target"] == "Genes-emitted-Node-ESM"
sdk044_plugin_code_paths = []
sdk044_plugin_forbidden = re.compile(
    r"\b(?:Dynamic|Any|cast|Reflect|untyped)\b"
)
for sdk044_plugin_code_name in (
    "artifactPermissions",
    "pluginPublisher",
    "deployablePlugin",
    "developmentProject",
    "plan",
    "planReader",
    "provider",
    "runningService",
    "bootstrapAdapter",
    "reloadAdapter",
    "readinessProbe",
):
    sdk044_plugin_code_path = Path(
        sdk044_plugin_code[sdk044_plugin_code_name]
    )
    assert sdk044_plugin_code_path.is_file()
    sdk044_plugin_code_paths.append(sdk044_plugin_code_path)
    assert sdk044_plugin_forbidden.search(
        sdk044_plugin_code_path.read_text(encoding="utf-8")
    ) is None
assert sdk044_plugin_code["strictHaxeBoundary"] is True
assert sdk044_plugin_code["genesSourceChanged"] is False
assert sdk044_plugin_code["genesPullRequest"] is None
assert sdk044_plugin_code["siblingDependencyCreated"] is False
sdk044_plugin_plan_reader_source = Path(
    sdk044_plugin_code["planReader"]
).read_text(encoding="utf-8")
sdk044_plugin_project_source = Path(
    sdk044_plugin_code["developmentProject"]
).read_text(encoding="utf-8")
assert "plan == null || DevelopmentPlanReader.hasExplicit(context)" in (
    sdk044_plugin_project_source
)
sdk044_plugin_explicit_branch = sdk044_plugin_plan_reader_source.index(
    "if (!hasExplicit(context))"
)
sdk044_plugin_inferred_branch = sdk044_plugin_plan_reader_source.index(
    "DevelopmentPlan.forPlugin", sdk044_plugin_explicit_branch
)
sdk044_plugin_decode_branch = sdk044_plugin_plan_reader_source.index(
    "return decode(value, project);", sdk044_plugin_inferred_branch
)
assert sdk044_plugin_explicit_branch < sdk044_plugin_inferred_branch
assert sdk044_plugin_inferred_branch < sdk044_plugin_decode_branch

sdk044_plugin_verification = plugin_development_implementation[
    "verification"
]
assert sdk044_plugin_verification["command"] == (
    "bash scripts/scaffold/test-production.sh"
)
assert sdk044_plugin_verification["summarySchema"] == (
    "wordpress-hx.sdk045-plugin-scaffold-summary.v1"
)
assert sdk044_plugin_verification["summaryResult"] == (
    "inferred-install-activate-reload-cleanup"
)
assert sdk044_plugin_verification["wordpressVersion"] == "7.0"
assert sdk044_plugin_verification["database"] == "mariadb"
for sdk044_plugin_passed_proof in (
    "plainDevInference",
    "servicesNoneAuthoritative",
    "freshInstall",
    "distributionCompletenessBeforeBootstrap",
    "bootstrapSentinelAndPluginHeaderReadiness",
    "pluginActivationBeforeReadiness",
    "exactReadOnlyPluginMount",
    "privateMuAdapterDirectoryAndScope",
    "privateConfigurationModes",
    "secretAndCapabilityExclusion",
    "failedBuildRetentionWithoutReload",
    "postCommitReload",
    "ownedResourceCleanup",
    "strictHaxeBoundaryGuard",
    "controlledServiceAndChromiumRegression",
):
    assert sdk044_plugin_verification[sdk044_plugin_passed_proof] == (
        "passed"
    )
assert sdk044_plugin_verification[
    "extraPluginEntryRejectedBeforeServiceStart"
] == "passed-WPHX2332"
assert sdk044_plugin_verification[
    "generatedPluginNativeRuntimePermissions"
] == "passed-0755-directories-0644-files-and-no-op-repair"
assert sdk044_plugin_verification["serviceRestartsOnSourceEdit"] == 0
assert sdk044_plugin_verification["regressionCommand"] == (
    "bash scripts/dev-loop/test-production.sh"
)

assert sdk044_plugin_receipt["schemaVersion"] == 1
assert sdk044_plugin_receipt["receiptId"] == (
    "SDK-044-INFERRED-PLUGIN-DEVELOPMENT"
)
assert sdk044_plugin_receipt["bead"] == "wordpresshx-sdk-044.3"
assert sdk044_plugin_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
assert sdk044_plugin_receipt["evidenceCommit"] is None or sha1.fullmatch(
    sdk044_plugin_receipt["evidenceCommit"]
)
assert set(sdk044_plugin_receipt["subject"]) == {
    "implementationManifest",
    "compilerPlanBoundary",
    "publicationBoundary",
    "developmentRuntime",
    "consumerGate",
    "controlledRegressionGate",
    "repositoryValidator",
    "workflow",
    "documentation",
}
verify_versioned_subject(sdk044_plugin_receipt)
assert sdk044_plugin_receipt["subject"]["implementationManifest"][
    "sha256"
] == hashlib.sha256(
    Path("manifests/plugin-development-implementation.json").read_bytes()
).hexdigest()
assert sdk044_plugin_receipt["verification"] == (
    sdk044_plugin_verification
)
assert sdk044_plugin_receipt["implementation"] == {
    "applicationLanguage": "Haxe",
    "javascriptCompiler": "Genes",
    "runtime": "Node ESM",
    "commonDeclaration": "WordPress.plugin()",
    "additionalDevelopmentDeclarations": 0,
    "inferenceAuthority": "typed compiler PluginPlan",
    "strictHaxeBoundary": True,
    "genesSourceChanged": False,
    "genesPullRequest": None,
    "siblingDependencyCreated": False,
}
sdk044_plugin_hosted = sdk044_plugin_receipt["hostedWorkflow"]
assert sdk044_plugin_hosted["workflow"] == "Repository bootstrap"
assert sdk044_plugin_hosted["job"] == "haxe"
assert sdk044_plugin_hosted["step"] == "Test Haxe-first site scaffolding"
assert sdk044_plugin_hosted["required"] is True
if sdk044_plugin_hosted["status"] == "pending-first-main-run":
    assert sdk044_plugin_receipt["status"] == "implemented-hosted-pending"
    assert plugin_development_implementation["status"] == (
        "implemented-sdk044-plugin-development-hosted-pending"
    )
    assert sdk044_plugin_receipt["implementationCommit"] is None
    assert sdk044_plugin_receipt["evidenceCommit"] is None
    assert sdk044_plugin_receipt["historicalVerification"][
        "subjectCommit"
    ] is None
    assert sdk044_plugin_hosted["runId"] is None
    assert sdk044_plugin_hosted["jobId"] is None
    assert sdk044_plugin_hosted["commit"] is None
    sdk044_plugin_evidence_suffix = "local"
elif sdk044_plugin_hosted["status"] == "passed":
    assert sdk044_plugin_receipt["status"] == "verified"
    assert plugin_development_implementation["status"] == (
        "implemented-sdk044-plugin-development-hosted-verified"
    )
    assert sha1.fullmatch(sdk044_plugin_receipt["implementationCommit"])
    assert sha1.fullmatch(sdk044_plugin_receipt["evidenceCommit"])
    assert sdk044_plugin_receipt["historicalVerification"][
        "subjectCommit"
    ] == sdk044_plugin_receipt["evidenceCommit"]
    verify_historical_ancestry(
        sdk044_plugin_receipt["implementationCommit"],
        sdk044_plugin_receipt["evidenceCommit"],
    )
    assert isinstance(sdk044_plugin_hosted["runId"], int)
    assert isinstance(sdk044_plugin_hosted["jobId"], int)
    assert sdk044_plugin_hosted["commit"] == (
        sdk044_plugin_receipt["implementationCommit"]
    )
    sdk044_plugin_evidence_suffix = "hosted"
else:
    raise AssertionError(
        "SDK-044 inferred plugin development hosted status is invalid"
    )
assert sdk044_plugin_verification["outcome"] == (
    "passed-" + sdk044_plugin_evidence_suffix
)
for sdk044_plugin_claim_record in (
    plugin_development_implementation["claims"],
    sdk044_plugin_receipt["claims"],
):
    for sdk044_plugin_runtime_claim in (
        "zeroAdditionalDeclarationPluginDevelopment",
        "realWordPress70MariaDbDevelopment",
        "activationBeforeReadiness",
        "lastGoodPluginRetentionAndReload",
        "completeOwnedResourceCleanup",
    ):
        assert sdk044_plugin_claim_record[sdk044_plugin_runtime_claim] == (
            "runtime-tested-" + sdk044_plugin_evidence_suffix
        )
    assert sdk044_plugin_claim_record["explicitServicePlanPrecedence"] == (
        "source-reviewed-and-explicit-plan-regression-"
        + sdk044_plugin_evidence_suffix
    )
    assert sdk044_plugin_claim_record["nextjsDevelopmentService"] == (
        "not-implemented"
    )
    assert sdk044_plugin_claim_record[
        "completeGeneratedSiteDevelopment"
    ] == "not-implemented"
    assert sdk044_plugin_claim_record["publicPackagePublication"] == (
        "blocked"
    )
    assert sdk044_plugin_claim_record["productionSupport"] == "not-tested"

assert scaffold_implementation["schemaVersion"] == 1
assert scaffold_implementation["bead"] == "wordpresshx-sdk-045.1"
assert scaffold_implementation["status"] in {
    "implemented-sdk045-hosted-pending",
    "implemented-sdk045-hosted-verified",
}
assert scaffold_implementation["scope"] == (
    "haxe-first-site-project-scaffold-foundation"
)
sdk045_contract = scaffold_implementation["contract"]
assert sdk045_contract == {
    "identity": "wordpress-hx.scaffold-plan.v1",
    "schema": "schemas/scaffold-plan.schema.json",
    "commands": ["wphx new site <name>", "wphx init [name]"],
    "defaultProfile": "wp70-release",
    "machineEncoding": "canonical-json-with-final-lf",
    "dryRunWrites": False,
    "planCompleteness": (
        "every-path-action-ownership-mode-sha256-and-byte-size"
    ),
}
scaffold_schema = json.loads(
    Path(sdk045_contract["schema"]).read_text(encoding="utf-8")
)
assert scaffold_schema["$schema"] == (
    "https://json-schema.org/draft/2020-12/schema"
)
assert scaffold_schema["additionalProperties"] is False
assert scaffold_schema["properties"]["schema"]["const"] == (
    sdk045_contract["identity"]
)
assert scaffold_schema["properties"]["profile"]["const"] == (
    "wp70-release"
)
sdk045_derivation = scaffold_implementation["haxeFirstDerivation"]
assert sdk045_derivation["singleInput"] == (
    "validated-lowercase-hyphenated-project-slug"
)
assert sdk045_derivation["authoredEntry"] == "Site.hx"
assert sdk045_derivation["packageDerivation"] == (
    "exact-project-slug-segments-with-keyword-safe-normalization"
)
for sdk045_native_authoring_requirement in (
    "handwrittenPhpRequired",
    "handwrittenJavascriptOrTypescriptRequired",
    "handwrittenWordPressJsonOrCssRequired",
    "cliOwnedProjectionHandEditingSupported",
):
    assert sdk045_derivation[sdk045_native_authoring_requirement] is False
assert set(sdk045_derivation["derived"]) == {
    "display-name",
    "haxe-package",
    "entry-type",
    "source-and-test-paths",
    "wordpress-hx-json",
    "project-hxml",
    "haxerc",
    "npm-manifest-and-lock",
    "self-digested-project-lock",
    "readme-and-managed-ignores",
}
sdk045_publication = scaffold_implementation["publication"]
assert sdk045_publication["freshProject"] == (
    "complete-private-sibling-stage-then-one-directory-rename"
)
assert sdk045_publication["existingProject"] == (
    "complete-private-sibling-stage-then-non-overwriting-hard-link-publication"
)
assert sdk045_publication["existingFileEdit"] == (
    "one-exact-gitignore-marker-pair-only"
)
assert sdk045_publication["preflight"] == "complete-before-first-live-write"
assert sdk045_publication["links"] == (
    "live-and-dangling-links-rejected-with-lstat"
)
assert sdk045_publication["collisions"] == "never-overwritten"
assert sdk045_publication["rollback"] == (
    "remove-only-matching-published-bytes-and-restore-exact-backup"
)
assert sdk045_publication["rollbackFailure"] == (
    "retain-private-recovery-bytes-and-stop"
)
assert scaffold_implementation["projection"] == {
    "hxmlAuthority": "entry-type-plus-all-source-and-test-roots",
    "haxeVersion": "4.3.7",
    "haxercResolution": "scoped",
    "buildAndCheckValidation": "exact-derived-bytes-before-haxe",
    "driftDiagnostic": "WPHX3008",
}
sdk045_code = scaffold_implementation["implementation"]
assert sdk045_code["language"] == "Haxe"
assert sdk045_code["target"] == "Genes-emitted-Node-ESM"
for sdk045_code_path in (
    "entry",
    "package",
    "arguments",
    "renderer",
    "publisher",
    "projectionValidator",
    "compilerBoundary",
):
    assert Path(sdk045_code[sdk045_code_path]).exists()
assert sdk045_code["strictHaxeBoundary"] is True
assert sdk045_code["genesSourceChanged"] is False
assert sdk045_code["genesPullRequest"] is None
assert sdk045_code["siblingDependencyCreated"] is False
assert sdk045_code["handwrittenJavascriptImplementation"] is False
assert sdk045_code["exactToolchain"]["haxe"] == (
    cli_dependency_lock["haxe"]["version"]
)
assert sdk045_code["exactToolchain"]["genesCommit"] == (
    cli_dependency_lock["compiler"]["commit"]
)
assert sdk045_code["exactToolchain"]["nodeImage"] == (
    cli_dependency_lock["runtime"]["image"]
)
sdk045_strict_paths = [
    Path("packages/cli/src/wordpresshx/cli/WphxMain.hx"),
    Path("packages/cli/src/wordpresshx/cli/project/CompilerRunner.hx"),
    *sorted(Path(sdk045_code["package"]).glob("*.hx")),
]
sdk045_forbidden = re.compile(r"\b(?:Dynamic|Any|cast|Reflect|untyped)\b")
for sdk045_strict_path in sdk045_strict_paths:
    assert sdk045_forbidden.search(
        sdk045_strict_path.read_text(encoding="utf-8")
    ) is None
assert scaffold_implementation["unsupportedTargetKinds"] == sorted(
    scaffold_implementation["unsupportedTargetKinds"]
)
assert scaffold_implementation["unsupportedTargetBehavior"] == (
    "typed-WPHX3002-before-writes-until-real-native-producer-evidence"
)
sdk045_reference_authorities = {
    ("haxe.elixir.codex", "src/reflaxe/elixir/generator/TemplateContext.hx"): (
        "ff72901cdf22bdb98fc5406a8856a1bb1e18a9d6",
        "d786139264f41bb2d7e3cae50e53347c077bca04",
        "1d879705df895ec177b8473691ec60a5b792f54143bfa4f94f1978ab9bd76354",
    ),
    ("haxe.ruby", "test/generators/common_test.rb"): (
        "d20f3520997616e07c870f91b867717f28216928",
        "d7c0be79b9db1e2b6c12b2cc39584165cd409220",
        "dec70b39c2bfcd2cf35c95b1659348d8184c2e5224c613f2736e1a87eb08e48f",
    ),
}
for sdk045_reference in scaffold_implementation["referencePatterns"]:
    sdk045_authority = sdk045_reference_authorities[
        (sdk045_reference["repository"], sdk045_reference["path"])
    ]
    assert sdk045_reference["commit"] == sdk045_authority[0]
    assert sdk045_reference["blob"] == sdk045_authority[1]
    assert sdk045_reference["sha256"] == sdk045_authority[2]
    assert sdk045_reference["copiedBytes"] is False
    assert sdk045_reference["dependencyCreated"] is False
assert len(scaffold_implementation["referencePatterns"]) == 2
sdk045_verification = scaffold_implementation["verification"]
assert sdk045_verification["command"] == (
    "bash scripts/scaffold/test-production.sh"
)
assert sdk045_verification["summarySchema"] == (
    "wordpress-hx.sdk045-scaffold-summary.v1"
)
assert sdk045_verification["compileReplayCount"] == 2
assert sdk045_verification["actualGeneratedHaxeTyped"] is True
assert sdk045_verification["containerNetwork"] == "none"
assert sdk045_verification["generatedFileCount"] == 11
assert sdk045_verification["positiveCases"] == 10
assert sdk045_verification["negativeCases"] == 11
assert sdk045_verification["noWriteAssertions"] == 16
assert sdk045_verification["freshTreeReplay"] == "byte-identical"
assert sdk045_verification["doctorCheckBuild"] == "passed"
assert sdk045_verification["canonicalToolchainComponentParity"] == "passed"
assert sdk045_verification["forcedMidPublicationRollback"] == (
    "exact-prior-tree-restored"
)
assert sdk045_verification["outcome"] == "passed"
assert "Test Haxe-first site scaffolding" in workflow_text
assert "bash scripts/scaffold/test-production.sh" in workflow_text
for sdk045_unproven_claim in (
    "cleanInstalledConsumer",
    "wordpressRuntimeCompatibility",
    "productionSupport",
):
    assert scaffold_implementation["claims"][sdk045_unproven_claim] == (
        "not-tested"
    )
assert scaffold_implementation["claims"]["nativeWordPressSiteProducer"] == (
    "not-registered"
)
assert scaffold_implementation["claims"]["publicPackagePublication"] == (
    "blocked"
)

assert sdk045_receipt["schemaVersion"] == 1
assert sdk045_receipt["receiptId"] == "SDK-045-SCAFFOLD"
assert sdk045_receipt["bead"] == "wordpresshx-sdk-045.1"
assert sdk045_receipt["status"] in {"implemented-hosted-pending", "verified"}

verify_versioned_subject(sdk045_receipt)
assert sdk045_receipt["subject"]["implementationManifest"]["sha256"] == (
    hashlib.sha256(
        Path("manifests/scaffold-implementation.json").read_bytes()
    ).hexdigest()
)
assert sdk045_receipt["implementation"]["applicationLanguage"] == "Haxe"
assert sdk045_receipt["implementation"]["javascriptCompiler"] == "Genes"
assert sdk045_receipt["implementation"]["strictHaxeBoundary"] is True
assert sdk045_receipt["implementation"]["genesSourceChanged"] is False
assert sdk045_receipt["implementation"]["genesPullRequest"] is None
assert sdk045_receipt["verification"]["command"] == (
    sdk045_verification["command"]
)
assert sdk045_receipt["verification"]["positiveCases"] == 10
assert sdk045_receipt["verification"]["negativeCases"] == 11
assert sdk045_receipt["verification"]["noWriteAssertions"] == 16
assert sdk045_receipt["verification"]["canonicalToolchainComponentParity"] == (
    "passed"
)
assert sdk045_receipt["verification"]["haxePackageDerivation"] == (
    sdk045_derivation["packageDerivation"]
)
assert sdk045_receipt["verification"]["forcedRollback"] == (
    "exact-prior-tree-restored"
)
assert sdk045_receipt["referenceReview"]["codeOrFixtureBytesCopied"] is False
assert sdk045_receipt["referenceReview"]["runtimeOrBuildDependencyCreated"] is False
assert sdk045_receipt["referenceReview"]["genesSourceChanged"] is False
sdk045_hosted = sdk045_receipt["hostedWorkflow"]
assert sdk045_hosted["workflow"] == "Repository bootstrap"
assert sdk045_hosted["job"] == "haxe"
assert sdk045_hosted["step"] == "Test Haxe-first site scaffolding"
assert sdk045_hosted["required"] is True
if sdk045_hosted["status"] == "pending-first-main-run":
    assert sdk045_receipt["status"] == "implemented-hosted-pending"
    assert scaffold_implementation["status"] == (
        "implemented-sdk045-hosted-pending"
    )
    assert sdk045_receipt["implementationCommit"] is None
    assert sdk045_hosted["runId"] is None
    assert sdk045_hosted["jobId"] is None
    assert sdk045_hosted["commit"] is None
    for sdk045_local_claim in (
        "newAndInitSiteFoundation",
        "deterministicScaffold",
        "currentDoctorCheckBuildConsumer",
    ):
        assert sdk045_receipt["claims"][sdk045_local_claim] == (
            "runtime-tested-local"
        )
    sdk045_evidence_suffix = "local"
elif sdk045_hosted["status"] == "passed":
    assert sdk045_receipt["status"] == "verified"
    assert scaffold_implementation["status"] == (
        "implemented-sdk045-hosted-verified"
    )
    assert sha1.fullmatch(sdk045_receipt["implementationCommit"])
    assert isinstance(sdk045_hosted["runId"], int)
    assert isinstance(sdk045_hosted["jobId"], int)
    assert sha1.fullmatch(sdk045_hosted["commit"])
    for sdk045_hosted_claim in (
        "newAndInitSiteFoundation",
        "deterministicScaffold",
        "currentDoctorCheckBuildConsumer",
    ):
        assert sdk045_receipt["claims"][sdk045_hosted_claim] == (
            "runtime-tested-hosted"
        )
    sdk045_evidence_suffix = "hosted"
else:
    raise AssertionError("SDK-045 scaffold hosted status is invalid")
for sdk045_manifest_runtime_claim in (
    "newSiteFoundation",
    "initSiteFoundation",
    "deterministicScaffold",
    "currentDoctorCheckBuildConsumer",
):
    assert scaffold_implementation["claims"][sdk045_manifest_runtime_claim] == (
        "runtime-tested-" + sdk045_evidence_suffix
    )
assert scaffold_implementation["claims"]["actualGeneratedHaxeTyping"] == (
    "compile-tested-" + sdk045_evidence_suffix
)
assert sdk045_receipt["claims"]["actualGeneratedHaxeTyping"] == (
    "compile-tested-" + sdk045_evidence_suffix
)
for sdk045_receipt_unproven_claim in (
    "nativeWordPressSiteProducer",
    "installedConsumer",
    "wordpressRuntimeCompatibility",
    "productionSupport",
):
    assert sdk045_receipt["claims"][sdk045_receipt_unproven_claim] == (
        "not-tested"
    )
assert sdk045_receipt["claims"]["publicPackagePublication"] == "blocked"

assert plugin_scaffold_implementation["schemaVersion"] == 1
assert plugin_scaffold_implementation["bead"] == "wordpresshx-sdk-045.2"
assert plugin_scaffold_implementation["status"] in {
    "implemented-sdk045-plugin-hosted-pending",
    "implemented-sdk045-plugin-hosted-verified",
}
assert plugin_scaffold_implementation["scope"] == (
    "haxe-first-native-plugin-scaffold"
)
sdk045_plugin_contract = plugin_scaffold_implementation["contract"]
assert sdk045_plugin_contract["command"] == "wphx new plugin <name>"
assert sdk045_plugin_contract["planIdentity"] == (
    "wordpress-hx.scaffold-plan.v1"
)
assert sdk045_plugin_contract["pluginPlanIdentity"] == (
    "wordpress-hx.plugin-plan.v1"
)
assert sdk045_plugin_contract["emissionIdentity"] == (
    "wordpress-hx.plugin-emission.v1"
)
assert sdk045_plugin_contract["profile"] == "wp70-release"
assert sdk045_plugin_contract["unsupportedKindsRemainFailClosed"] == sorted(
    sdk045_plugin_contract["unsupportedKindsRemainFailClosed"]
)
assert sdk045_plugin_contract["unsupportedDiagnostic"] == (
    "WPHX3002-before-writes"
)

sdk045_plugin_ergonomics = plugin_scaffold_implementation[
    "haxeFirstErgonomics"
]
assert sdk045_plugin_ergonomics["maintainedAuthority"] == "Site.hx"
assert sdk045_plugin_ergonomics["commonDeclaration"] == "WordPress.plugin()"
assert sdk045_plugin_ergonomics["requiredArguments"] == 0
assert set(
    sdk045_plugin_ergonomics["derivedFromAuthenticatedProjectIdentity"]
) == {
    "plugin-slug",
    "display-name",
    "description",
    "text-domain",
    "php-namespace",
    "wordpress-7.0-requirement",
    "php-7.4-requirement",
    "semantic-version",
    "author",
    "license",
}
assert sdk045_plugin_ergonomics["typedOverrideFields"] == sorted(
    sdk045_plugin_ergonomics["typedOverrideFields"]
)
for sdk045_plugin_native_requirement in (
    "handwrittenPhpRequired",
    "handwrittenJavascriptOrTypescriptRequired",
    "handwrittenWordPressJsonRequired",
    "rawTargetSegmentsRequired",
):
    assert sdk045_plugin_ergonomics[sdk045_plugin_native_requirement] is False

sdk045_plugin_compiler = plugin_scaffold_implementation["compilerBoundary"]
for sdk045_plugin_compiler_path in (
    "projectApi",
    "genericPhpCompiler",
    "wordpressProfile",
):
    assert Path(sdk045_plugin_compiler[sdk045_plugin_compiler_path]).exists()
assert sdk045_plugin_compiler["handoff"] == (
    "closed-typed-plan-after-successful-haxe-typing"
)
assert sdk045_plugin_compiler["liveOutputDuringTyping"] is False
assert sdk045_plugin_compiler["compileServerReuse"] is True
assert sdk045_plugin_compiler["structuredPublicPhpReceipt"] == (
    wordpress_php_receipt["receiptId"]
)
assert sdk045_plugin_compiler["dependencyDirection"] == (
    "cli-to-wordpress-profile-to-generic-compiler"
)
assert sdk045_plugin_compiler["wordpressBranchesInGenericCompiler"] is False
assert sdk045_plugin_compiler["fullPortDependency"] is False

sdk045_plugin_emission = plugin_scaffold_implementation["emission"]
assert sdk045_plugin_emission["files"] == [
    "<slug>.php",
    "includes/Bootstrap.php",
    "includes/autoload.php",
]
assert sdk045_plugin_emission["classification"] == (
    "ordinary-public-native-wordpress-plugin"
)
assert sdk045_plugin_emission["readablePhp"] is True
for sdk045_plugin_zero_boundary in (
    "rawPhpSegments",
    "stockHaxePhpFiles",
):
    assert sdk045_plugin_emission[sdk045_plugin_zero_boundary] == 0
for sdk045_plugin_runtime_boundary in (
    "runtimeHxxDependency",
    "runtimeCompilerDependency",
):
    assert sdk045_plugin_emission[sdk045_plugin_runtime_boundary] is False

sdk045_plugin_ownership = plugin_scaffold_implementation[
    "ownershipAndPackaging"
]
assert sdk045_plugin_ownership["publication"] == (
    "single-existing-manifest-last-ownership-transaction"
)
assert sdk045_plugin_ownership["validation"] == (
    "complete-private-stage-before-live-write"
)
assert sdk045_plugin_ownership["identicalRebuild"] == (
    "no-op-byte-identical"
)
assert sdk045_plugin_ownership["publicFilesystemModes"] == (
    "haxe-publisher-enforced-directory-0755-file-0644"
)
assert sdk045_plugin_ownership["identicalRebuildModeRepair"] == (
    "restore-public-modes-with-ownership-no-op"
)
assert sdk045_plugin_ownership["freshProjectReplay"] == "byte-identical"
assert sdk045_plugin_ownership["archive"] == "deterministic-zip32-stored-v1"

sdk045_plugin_code = plugin_scaffold_implementation["implementation"]
assert sdk045_plugin_code["language"] == "Haxe"
assert sdk045_plugin_code["target"] == "Genes-emitted-Node-ESM"
for sdk045_plugin_code_path in (
    "entry",
    "scaffoldPackage",
    "projectPackage",
    "emitter",
    "publisher",
    "artifactPermissions",
):
    assert Path(sdk045_plugin_code[sdk045_plugin_code_path]).exists()
assert sdk045_plugin_code["strictHaxeBoundary"] is True
assert sdk045_plugin_code["genes"]["version"] == (
    cli_dependency_lock["compiler"]["version"]
)
assert sdk045_plugin_code["genes"]["commit"] == (
    cli_dependency_lock["compiler"]["commit"]
)
assert sdk045_plugin_code["genes"]["sourceChanged"] is False
assert sdk045_plugin_code["genes"]["pullRequest"] is None
assert sdk045_plugin_code["genes"]["siblingDependencyCreated"] is False
assert sdk045_plugin_code["toolchain"]["haxe"] == (
    cli_dependency_lock["haxe"]["version"]
)
assert sdk045_plugin_code["toolchain"]["node"] == (
    cli_dependency_lock["runtime"]["version"]
)

sdk045_plugin_strict_paths = [
    Path("packages/cli/project-api/wordpresshx/WordPress.hx"),
    Path("packages/cli/src/wordpresshx/cli/project/CompilerRunner.hx"),
    Path("packages/cli/src/wordpresshx/cli/project/ProjectBuild.hx"),
    *sorted(
        Path("packages/cli/src/wordpresshx/cli/project").glob("Plugin*.hx")
    ),
    *sorted(Path("packages/cli/src/wordpresshx/cli/scaffold").glob("*.hx")),
]
for sdk045_plugin_strict_path in sdk045_plugin_strict_paths:
    assert sdk045_forbidden.search(
        sdk045_plugin_strict_path.read_text(encoding="utf-8")
    ) is None

sdk045_plugin_verification = plugin_scaffold_implementation["verification"]
assert sdk045_plugin_verification == {
    "command": "bash scripts/scaffold/test-production.sh",
    "summarySchema": "wordpress-hx.sdk045-plugin-scaffold-summary.v1",
    "outcome": "passed",
    "positiveCases": 11,
    "negativeCases": 5,
    "noWriteAssertions": 8,
    "generatedFileCount": 11,
    "nativePhpFileCount": 3,
    "freshTreeReplay": "byte-identical",
    "buildReplay": "no-op-byte-identical",
    "publicPluginFilesystemPermissions": (
        "passed-0755-directories-0644-files-and-no-op-repair"
    ),
    "devReplay": "three-atomic-generations",
    "phpRuntimeMatrix": ["7.4", "8.4"],
    "wordpress": {
        "version": "7.0",
        "database": "mariadb",
        "freshInstall": "passed",
        "headerDiscovery": "passed",
        "activation": "passed",
        "freshRequestProbe": "passed",
    },
    "strictHaxeBoundaryGuard": "passed",
}
assert "-resource project-api/wordpresshx/WordPress.hx@wordpresshx-project-api" in (
    Path("packages/cli/profiles/wphx.hxml").read_text(encoding="utf-8")
)
assert "actions/setup-node@48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e" in (
    workflow_text
)
assert "node-version: 22.17.0" in workflow_text

assert sdk045_plugin_receipt["schemaVersion"] == 1
assert sdk045_plugin_receipt["receiptId"] == "SDK-045-PLUGIN-SCAFFOLD"
assert sdk045_plugin_receipt["bead"] == "wordpresshx-sdk-045.2"
assert sdk045_plugin_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
assert sdk045_plugin_receipt["evidenceCommit"] is None or sha1.fullmatch(
    sdk045_plugin_receipt["evidenceCommit"]
)
assert set(sdk045_plugin_receipt["subject"]) == {
    "implementationManifest",
    "projectApi",
    "compilerIntegration",
    "scaffoldIntegration",
    "profile",
    "schema",
    "consumerGates",
    "compatibilityCorpora",
    "workflow",
    "repositoryValidator",
    "documentation",
}
verify_versioned_subject(sdk045_plugin_receipt)
assert sdk045_plugin_receipt["implementation"] == {
    "applicationLanguage": "Haxe",
    "javascriptCompiler": "Genes",
    "runtime": "Node ESM",
    "profile": "wp70-release",
    "commonDeclaration": "WordPress.plugin()",
    "strictHaxeBoundary": True,
    "genesSourceChanged": False,
    "genesPullRequest": None,
    "siblingDependencyCreated": False,
}
assert sdk045_plugin_receipt["verification"] == (
    sdk045_plugin_verification
)
sdk045_plugin_hosted = sdk045_plugin_receipt["hostedWorkflow"]
assert sdk045_plugin_hosted["workflow"] == "Repository bootstrap"
assert sdk045_plugin_hosted["job"] == "haxe"
assert sdk045_plugin_hosted["step"] == "Test Haxe-first site scaffolding"
assert sdk045_plugin_hosted["required"] is True
if sdk045_plugin_hosted["status"] == "pending-first-main-run":
    assert sdk045_plugin_receipt["status"] == "implemented-hosted-pending"
    assert plugin_scaffold_implementation["status"] == (
        "implemented-sdk045-plugin-hosted-pending"
    )
    assert sdk045_plugin_receipt["implementationCommit"] is None
    assert sdk045_plugin_receipt["evidenceCommit"] is None
    assert sdk045_plugin_receipt["historicalVerification"][
        "subjectCommit"
    ] is None
    assert sdk045_plugin_hosted["runId"] is None
    assert sdk045_plugin_hosted["jobId"] is None
    assert sdk045_plugin_hosted["commit"] is None
    sdk045_plugin_evidence_suffix = "local"
elif sdk045_plugin_hosted["status"] == "passed":
    assert sdk045_plugin_receipt["status"] == "verified"
    assert plugin_scaffold_implementation["status"] == (
        "implemented-sdk045-plugin-hosted-verified"
    )
    assert sha1.fullmatch(sdk045_plugin_receipt["implementationCommit"])
    assert sha1.fullmatch(sdk045_plugin_receipt["evidenceCommit"])
    assert sdk045_plugin_receipt["historicalVerification"][
        "subjectCommit"
    ] == sdk045_plugin_receipt["evidenceCommit"]
    verify_historical_ancestry(
        sdk045_plugin_receipt["implementationCommit"],
        sdk045_plugin_receipt["evidenceCommit"],
    )
    assert isinstance(sdk045_plugin_hosted["runId"], int)
    assert isinstance(sdk045_plugin_hosted["jobId"], int)
    assert sdk045_plugin_hosted["commit"] == (
        sdk045_plugin_receipt["implementationCommit"]
    )
    sdk045_plugin_evidence_suffix = "hosted"
else:
    raise AssertionError("SDK-045 plugin scaffold hosted status is invalid")

for sdk045_plugin_runtime_claim in (
    "haxeOnlyPluginScaffold",
    "nativePhpEmission",
    "deterministicPluginPackaging",
    "compileWatchReuse",
    "wordpress70DiscoveryActivationAndRequest",
):
    assert plugin_scaffold_implementation["claims"][
        sdk045_plugin_runtime_claim
    ] == "runtime-tested-" + sdk045_plugin_evidence_suffix
    assert sdk045_plugin_receipt["claims"][
        sdk045_plugin_runtime_claim
    ] == "runtime-tested-" + sdk045_plugin_evidence_suffix
assert plugin_scaffold_implementation["claims"]["derivedPluginMetadata"] == (
    "compile-tested-" + sdk045_plugin_evidence_suffix
)
assert sdk045_plugin_receipt["claims"]["derivedPluginMetadata"] == (
    "compile-tested-" + sdk045_plugin_evidence_suffix
)
for sdk045_plugin_nonclaim, expected in (
    ("typedHooksBeyondBootstrap", "not-implemented"),
    ("publicPackageInstallation", "blocked"),
    ("productionSupport", "not-tested"),
):
    assert plugin_scaffold_implementation["claims"][
        sdk045_plugin_nonclaim
    ] == expected
    assert sdk045_plugin_receipt["claims"][sdk045_plugin_nonclaim] == expected

assert private_runtime_implementation["schemaVersion"] == 1
assert private_runtime_implementation["bead"] == "wordpresshx-sdk-024"
assert private_runtime_implementation["status"] in {
    "implemented-sdk024-hosted-pending",
    "implemented-sdk024-hosted-verified",
}
assert private_runtime_implementation["scope"] == (
    "bounded-stock-haxe-private-php-production-lane"
)
sdk024_authority = private_runtime_implementation["architectureAuthority"]
assert Path(sdk024_authority["decisionManifest"]).is_file()
assert sdk024_authority["decisionReceipt"] == adr018_receipt["receiptId"]
assert sdk024_authority["publicPhpProfileReceipt"] == (
    wordpress_php_receipt["receiptId"]
)
assert sdk024_authority["publicAdapterReceipt"] == (
    wordpress_adapter_receipt["receiptId"]
)

sdk024_ergonomics = private_runtime_implementation["haxeFirstErgonomics"]
assert sdk024_ergonomics["maintainedAuthority"] == "Site.hx"
assert sdk024_ergonomics["zeroArgumentDeclaration"] == "WordPress.plugin()"
assert sdk024_ergonomics["zeroArgumentPrivateRuntime"] == "omitted"
assert sdk024_ergonomics["typedBehaviorDeclaration"] == (
    "WordPress.plugin({titleFilter: Site.filterTitle})"
)
assert sdk024_ergonomics["callbackSignature"] == (
    "(title:String, postId:Int) -> String"
)
assert sdk024_ergonomics["callbackIdentityResolution"] == (
    "typed-Haxe-AST-at-compile-time"
)
assert sdk024_ergonomics["callbackSourceRangeRecorded"] is True
assert sdk024_ergonomics["inlineLambdaDisposition"] == (
    "compile-time-rejected-WPHX2002"
)
assert sdk024_ergonomics["derivedWithoutUserConfiguration"] == sorted(
    sdk024_ergonomics["derivedWithoutUserConfiguration"]
)
for sdk024_user_config in (
    "handwrittenPhpRequired",
    "handwrittenAutoloadConfigurationRequired",
    "handwrittenComposerConfigurationRequired",
    "privateNamespaceSelectionRequired",
):
    assert sdk024_ergonomics[sdk024_user_config] is False

sdk024_handoff = private_runtime_implementation["semanticHandoff"]
assert sdk024_handoff == {
    "pluginPlan": "wordpress-hx.plugin-plan.v2",
    "pluginEmission": "wordpress-hx.plugin-emission.v2",
    "runtimeManifest": "wordpress-hx.private-runtime-manifest.v1",
    "closedPlanReader": True,
    "exactCallbackClassMethodAndSourceRange": True,
    "sourceRootOwnershipValidated": True,
}
sdk024_compiler = private_runtime_implementation["compilerIntegration"]
assert Path(sdk024_compiler["genericPhpIr"]).is_dir()
assert sdk024_compiler["genericIrAddition"] == "PhpRequire(path, once)"
assert sdk024_compiler["currentGenericPackageFileCount"] == 40
assert sha256.fullmatch(sdk024_compiler["currentGenericPackageContentSha256"])
assert sdk024_compiler["wordpressKnowledgeAddedToGenericCompiler"] is False
assert sdk024_compiler["stockCompiler"] == "Haxe 4.3.7 PHP target"
assert sdk024_compiler["dce"] == "full-derived-single-callback-entry"
for sdk024_runtime_dependency in (
    "runtimeCompilerDependency",
    "runtimeNodeDependency",
    "runtimeHaxeDependency",
):
    assert sdk024_compiler[sdk024_runtime_dependency] is False
assert sdk024_compiler["genes"] == {
    "version": "1.36.3",
    "commit": "c59ecb361fd91418584487c2138bae8d3d3a3961",
    "sourceChanged": False,
    "pullRequest": None,
    "siblingDependencyCreated": False,
}

sdk024_packaging = private_runtime_implementation["privatePackaging"]
assert sdk024_packaging["identitySchema"] == (
    "wordpress-hx.private-runtime-identity.v1"
)
assert sdk024_packaging["digest"] == "sha256"
assert sdk024_packaging["prefixBitsRetained"] == 96
assert sdk024_packaging["scope"] == "per-deployable-plugin"
assert sdk024_packaging["sharedSiteRuntime"] is False
assert sdk024_packaging["classmap"] == (
    "generated-package-local-authoritative-exact-map"
)
assert sdk024_packaging["processIncludePathMutation"] is False
assert sdk024_packaging["autoloadPrepend"] is False
assert sdk024_packaging["runtimeComposerGraph"] == (
    "absent-no-runtime-dependencies"
)
assert sdk024_packaging["stockRuntimePhpFiles"] == 15
assert sdk024_packaging["classmapEntries"] == 14
assert sdk024_packaging["privatePhpFilesIncludingClassmap"] == 16
assert sdk024_packaging["stockFrontPackaged"] is False
assert sdk024_packaging["generatedReachabilityEntryPackaged"] is False
assert sdk024_packaging["globalPolyfill"] == {
    "functions": ["mb_chr", "mb_ord", "mb_scrub", "str_starts_with"],
    "sha256": (
        "80f6c2172d93b501328e2c4fa131b81a186ff850e6a437e9068f9e842a6b3237"
    ),
    "compatibilityMarker": "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256",
    "differentHashDisposition": "reject-before-private-boot-WPHX5201",
}
assert sdk024_packaging["publicationLicenseGate"] == (
    "blocked-pending-qualified-review"
)

assert private_runtime_implementation["publicBoundary"] == {
    "adapter": "generated-native-WordPress-PHP",
    "method": "filterTitle(string,int):string",
    "registration": "add_filter(the_title, generated-static-callback, 10, 2)",
    "privateNamesAllowedInPublicSignature": False,
    "privateTypesReachableOnlyInsideAdapterBody": True,
    "rawPhpSegments": 0,
}
sdk024_ownership = private_runtime_implementation["ownershipAndPublication"]
assert sdk024_ownership["publisher"] == (
    "existing-manifest-last-ownership-transaction"
)
assert sdk024_ownership["privateLaneClassification"] == (
    "wphx.plugin-private-php"
)
assert sdk024_ownership["completeStageValidationBeforeLiveWrite"] is True
assert sdk024_ownership["sameIdentityReplay"] == "byte-identical-no-op"
assert sdk024_ownership["differentPluginPrefixes"] == "distinct"
assert sdk024_ownership["packageTotalPhpCeilingBytes"] == 409600

sdk024_verification = private_runtime_implementation["verification"]
assert sdk024_verification["command"] == (
    "bash scripts/scaffold/test-production.sh"
)
assert sdk024_verification["privateResultSchema"] == (
    "wordpress-hx.sdk024-private-runtime-result.v1"
)
assert sdk024_verification["outcome"] == "passed"
assert sdk024_verification["positiveCases"] == 16
assert sdk024_verification["negativeCases"] == 10
assert sdk024_verification["noWriteAssertions"] == 13
assert sdk024_verification["sameIdentityReplay"] == "byte-identical"
assert sdk024_verification["privatePhpBytes"] < 163840
assert sdk024_verification["privatePhpFiles"] == 16
assert sdk024_verification["classmapEntries"] == 14
assert len(sdk024_verification["phpMatrix"]) == 2
assert [entry["version"] for entry in sdk024_verification["phpMatrix"]] == [
    "7.4.33",
    "8.4.7",
]
for sdk024_php in sdk024_verification["phpMatrix"]:
    assert sdk024_php["image"] in {
        image_lock["images"]["php74Floor"]["reference"],
        image_lock["images"]["php84Cli"]["reference"],
    }
    assert sdk024_php["samples"] == 25
    assert 0 < sdk024_php["coldBootP50Nanoseconds"] < (
        sdk024_verification["coldBootP50CeilingNanoseconds"]
    )
assert sdk024_verification["coldBootP50CeilingNanoseconds"] == 20000000
assert sdk024_verification["coexistence"] == (
    "two-distinct-generated-plugins-passed"
)
assert sdk024_verification["polyfillMismatch"] == (
    "rejected-before-private-boot-WPHX5201"
)
assert sdk024_verification["wordpress"] == {
    "version": "7.0",
    "database": "mariadb",
    "freshInstall": "passed",
    "twoPluginActivation": "passed",
    "typedBehavior": "seed:news:pages",
}
for sdk024_scan in (
    "publicAbiLeakScan",
    "localPathLeakScan",
    "strictHaxeBoundaryGuard",
):
    assert sdk024_verification[sdk024_scan] == "passed"

sdk024_removal = private_runtime_implementation["migrationAndRemovalTrigger"]
assert sdk024_removal["reviewGate"] == "G8"
assert len(sdk024_removal["retainThroughReviewOnlyIf"]) >= 5
assert len(sdk024_removal["removeStockLaneWhen"]) >= 4
assert sdk024_removal["postOneDotZeroGuarantee"] == (
    "none-until-G8-retention-decision"
)
assert private_runtime_implementation["limitations"] == sorted(
    private_runtime_implementation["limitations"]
)

sdk024_strict_paths = [
    Path("packages/cli/project-api/wordpresshx/WordPress.hx"),
    *sorted(Path("packages/cli/src/wordpresshx/cli/project").glob("Plugin*.hx")),
    Path(
        "packages/cli/src/wordpresshx/cli/project/development/DevelopmentPlugin.hx"
    ),
    Path("compiler/reflaxe.php/src/reflaxe/php/ir/PhpExpr.hx"),
    Path("compiler/reflaxe.php/src/reflaxe/php/print/PhpPrinter.hx"),
    Path("compiler/reflaxe.php/test/reflaxe/php/tests/PrinterTest.hx"),
]
sdk024_forbidden = re.compile(r"\b(?:Dynamic|Any|cast|Reflect|untyped)\b")
for sdk024_strict_path in sdk024_strict_paths:
    assert sdk024_forbidden.search(
        sdk024_strict_path.read_text(encoding="utf-8")
    ) is None

assert sdk024_receipt["schemaVersion"] == 1
assert sdk024_receipt["receiptId"] == "SDK-024-PRIVATE-PHP-RUNTIME"
assert sdk024_receipt["bead"] == "wordpresshx-sdk-024"
assert sdk024_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
assert sdk024_receipt["evidenceCommit"] is None or sha1.fullmatch(
    sdk024_receipt["evidenceCommit"]
)
assert set(sdk024_receipt["subject"]) == {
    "implementationManifest",
    "projectApi",
    "genericCompiler",
    "projectIntegration",
    "consumerGates",
    "schema",
    "documentation",
    "workflow",
    "repositoryValidator",
}
verify_versioned_subject(sdk024_receipt)
assert sdk024_receipt["implementation"] == {
    "applicationLanguage": "Haxe",
    "privateCompiler": "Haxe 4.3.7 PHP target",
    "javascriptCompiler": "Genes 1.36.3",
    "runtime": "ordinary-PHP-behind-native-WordPress-adapter",
    "pluginPlan": "wordpress-hx.plugin-plan.v2",
    "pluginEmission": "wordpress-hx.plugin-emission.v2",
    "strictHaxeBoundary": True,
    "genesSourceChanged": False,
    "genesPullRequest": None,
    "siblingDependencyCreated": False,
}
assert sdk024_receipt["verification"] == sdk024_verification
assert sdk024_receipt["migrationAndRemovalTrigger"] == sdk024_removal
assert sdk024_receipt["limitations"] == (
    private_runtime_implementation["limitations"]
)
sdk024_hosted = sdk024_receipt["hostedWorkflow"]
assert sdk024_hosted["workflow"] == "Repository bootstrap"
assert sdk024_hosted["job"] == "haxe"
assert sdk024_hosted["step"] == "Test Haxe-first site scaffolding"
assert sdk024_hosted["required"] is True
if sdk024_hosted["status"] == "pending-first-main-run":
    assert sdk024_receipt["status"] == "implemented-hosted-pending"
    assert private_runtime_implementation["status"] == (
        "implemented-sdk024-hosted-pending"
    )
    assert sdk024_receipt["implementationCommit"] is None
    assert sdk024_receipt["evidenceCommit"] is None
    assert sdk024_receipt["historicalVerification"]["subjectCommit"] is None
    assert sdk024_hosted["runId"] is None
    assert sdk024_hosted["jobId"] is None
    assert sdk024_hosted["commit"] is None
    sdk024_evidence_suffix = "local"
elif sdk024_hosted["status"] == "passed":
    assert sdk024_receipt["status"] == "verified"
    assert private_runtime_implementation["status"] == (
        "implemented-sdk024-hosted-verified"
    )
    assert sha1.fullmatch(sdk024_receipt["implementationCommit"])
    assert sha1.fullmatch(sdk024_receipt["evidenceCommit"])
    assert sdk024_receipt["historicalVerification"]["subjectCommit"] == (
        sdk024_receipt["evidenceCommit"]
    )
    verify_historical_ancestry(
        sdk024_receipt["implementationCommit"],
        sdk024_receipt["evidenceCommit"],
    )
    assert isinstance(sdk024_hosted["runId"], int)
    assert isinstance(sdk024_hosted["jobId"], int)
    assert sdk024_hosted["commit"] == sdk024_receipt["implementationCommit"]
    sdk024_evidence_suffix = "hosted"
else:
    raise AssertionError("SDK-024 private runtime hosted status is invalid")
for sdk024_runtime_claim in (
    "typedPrivateTitleFilter",
    "dependencyClosedPrivatePackaging",
    "deterministicPrivatePackaging",
    "multiplePluginCoexistence",
    "php74And84Compatibility",
    "wordpress70Compatibility",
    "nativePublicAbiIsolation",
):
    assert private_runtime_implementation["claims"][sdk024_runtime_claim] == (
        "runtime-tested-" + sdk024_evidence_suffix
    )
    assert sdk024_receipt["claims"][sdk024_runtime_claim] == (
        "runtime-tested-" + sdk024_evidence_suffix
    )
for sdk024_nonclaim, expected in (
    ("runtimeComposerDependencies", "not-admitted"),
    ("qualifiedLicenseApproval", "blocked"),
    ("generalTypedWordPressHooks", "not-implemented"),
    ("productionSupport", "not-tested"),
):
    assert private_runtime_implementation["claims"][sdk024_nonclaim] == expected
    assert sdk024_receipt["claims"][sdk024_nonclaim] == expected

assert php_quality_implementation["schemaVersion"] == 1
assert php_quality_implementation["bead"] == "wordpresshx-sdk-026"
assert php_quality_implementation["status"] in {
    "implemented-local-verified-hosted-pending",
    "implemented-hosted-verified",
}
assert php_quality_implementation["scope"] == (
    "complete-generated-plugin-php-staging-quality-gate"
)
sdk026_ergonomics = php_quality_implementation["haxeFirstErgonomics"]
assert sdk026_ergonomics["applicationDeclarationUnchanged"] == (
    "WordPress.plugin()"
)
assert sdk026_ergonomics["projectAuthoredConfigurationFiles"] == []
for sdk026_user_config in (
    "handwrittenComposerRequired",
    "handwrittenPhpcsRequired",
    "handwrittenPhpStanRequired",
    "handwrittenWordPressStubsRequired",
    "handwrittenShellRequired",
):
    assert sdk026_ergonomics[sdk026_user_config] is False
assert sdk026_ergonomics["commandsUsingInferredPolicy"] == sorted(
    sdk026_ergonomics["commandsUsingInferredPolicy"]
)
assert sdk026_ergonomics["failureDiagnostic"] == "WPHX3400"
assert sdk026_ergonomics["failurePublicationAuthority"] is False

sdk026_generic = php_quality_implementation["genericCompilerSupport"]
assert sdk026_generic["package"] == "compiler/reflaxe.php"
assert sdk026_generic["wordpressKnowledgeAdded"] is False
assert sdk026_generic["nativeTypedProperties"] is True
assert sdk026_generic["packageFileCount"] == 40
assert sdk026_generic["packageContentSha256"] == (
    sdk024_compiler["currentGenericPackageContentSha256"]
)
assert sdk026_generic["structuredPhpDoc"] == {
    "types": [
        "array<int, T>",
        "array<string, T>",
        "int",
        "mixed",
        "named-qualified-type",
        "normalized-union",
        "string",
    ],
    "methodParameterIdentityChecked": True,
    "defensiveCopies": True,
    "rawDocCommentInput": False,
    "commentInjectionRejected": True,
}

sdk026_policy_paths = [
    "composer.json",
    "composer.lock",
    "phpcs-compat-private.xml",
    "phpcs-compat.xml",
    "phpcs-public.xml",
    "phpstan-private.neon",
    "phpstan-public.neon",
    "run.php",
    "toolchain.json",
]
sdk026_policy_input = bytearray()
for sdk026_policy_name in sdk026_policy_paths:
    sdk026_policy_path = Path("tooling/php-quality") / sdk026_policy_name
    sdk026_policy_digest = hashlib.sha256(sdk026_policy_path.read_bytes()).hexdigest()
    sdk026_policy_input.extend(
        sdk026_policy_name.encode()
        + b"\0"
        + sdk026_policy_digest.encode()
        + b"\0"
    )
sdk026_policy_sha256 = hashlib.sha256(sdk026_policy_input).hexdigest()
assert sdk026_policy_sha256 == (
    "fc85632c5d3dd978ffcb76e8ead1319cfcc345787f798b7d88d31d2af607446a"
)
sdk026_toolchain = php_quality_implementation["toolchain"]
assert sdk026_toolchain["policyId"] == "wp70-release-generated-php-v1"
assert sdk026_toolchain["policySha256"] == sdk026_policy_sha256
assert sdk026_toolchain["lockSha256"] == hashlib.sha256(
    Path("tooling/php-quality/composer.lock").read_bytes()
).hexdigest()
assert sdk026_toolchain["runtimeComposerPackages"] == []
assert sdk026_toolchain["includedInGeneratedPlugin"] is False
assert php_quality_toolchain["schema"] == (
    "wordpress-hx.php-quality-toolchain.v1"
)
assert php_quality_toolchain["policyId"] == sdk026_toolchain["policyId"]
assert php_quality_toolchain["composer"] == {
    "version": "2.10.2",
    "artifactUrl": "https://getcomposer.org/download/2.10.2/composer.phar",
    "artifactSha256": (
        "5ee7125f8a30a34d246cefdc0bc85b8a783b28f2aec968994118512350d28027"
    ),
}
assert php_quality_toolchain["php"] == {
    "syntaxFloor": "7.4.33",
    "primary": "8.4.7",
}
assert php_quality_toolchain["tools"] == {
    "phpCodeSniffer": "3.13.5",
    "wordpressCodingStandards": "3.4.0",
    "phpCompatibilityWordPress": "2.1.8",
    "phpStan": "2.2.5",
    "wordpressStubs": "7.0.0",
    "wordpressExtension": (
        "not-admitted-no-release-supports-wordpress-stubs-7.0"
    ),
}
sdk026_exceptions = php_quality_toolchain["generatedCodePolicy"][
    "justifiedExclusions"
]
assert len(sdk026_exceptions) == 5
assert [item["id"] for item in sdk026_exceptions] == [
    "stock-haxe-style",
    "stock-haxe-reserved-initializer-name",
    "generic-printer-layout",
    "haxe-visible-native-identities",
    "fail-closed-loader-diagnostics",
]

sdk026_locked_packages = {
    package["name"]: package["version"].lstrip("v")
    for package in php_quality_composer_lock["packages-dev"]
}
assert sdk026_locked_packages == {
    "dealerdirect/phpcodesniffer-composer-installer": "1.2.1",
    "php-stubs/wordpress-stubs": "7.0.0",
    "phpcompatibility/php-compatibility": "9.3.5",
    "phpcompatibility/phpcompatibility-paragonie": "1.3.4",
    "phpcompatibility/phpcompatibility-wp": "2.1.8",
    "phpcsstandards/phpcsextra": "1.5.0",
    "phpcsstandards/phpcsutils": "1.2.2",
    "phpstan/phpstan": "2.2.5",
    "squizlabs/php_codesniffer": "3.13.5",
    "wp-coding-standards/wpcs": "3.4.0",
}
sdk026_composer_graph = toolchain_lock["dependencyGraphs"]["composer"]
assert sdk026_composer_graph["status"] == (
    "bounded-build-only-generated-php-validation"
)
assert sdk026_composer_graph["lockSha256"] == sdk026_toolchain["lockSha256"]
assert sdk026_composer_graph["runtimePackages"] == []
assert sdk026_composer_graph["buildInputOnly"] is True
assert sdk026_composer_graph["publicationAuthorized"] is False
assert sdk026_composer_graph["receiptId"] == (
    "SDK-026-GENERATED-PHP-QUALITY"
)
assert {
    package["name"]: package["version"]
    for package in sdk026_composer_graph["activePackages"]
} == sdk026_locked_packages

sdk026_profile = Path("packages/cli/profiles/wphx.hxml").read_text(
    encoding="utf-8"
)
for sdk026_policy_name in sdk026_policy_paths:
    assert f"../../tooling/php-quality/{sdk026_policy_name}@" in sdk026_profile
sdk026_workflow = Path(".github/workflows/repository.yml").read_text(
    encoding="utf-8"
)
for sdk026_step in (
    "Install exact generated-PHP quality toolchain",
    "Test pinned generated-PHP quality policy",
):
    assert sdk026_step in sdk026_workflow
assert "bash scripts/php-quality/install.sh" in sdk026_workflow
assert "bash scripts/php-quality/test-production.sh" in sdk026_workflow
for sdk026_script in (
    Path("scripts/php-quality/expose-runtime.sh"),
    Path("scripts/php-quality/install.sh"),
    Path("scripts/php-quality/test-production.sh"),
):
    assert sdk026_script.stat().st_mode & 0o111
sdk026_gitignore = Path(".gitignore").read_text(encoding="utf-8")
for sdk026_ignored in (
    "tooling/php-quality/vendor/",
    "tooling/php-quality/.cache/",
):
    assert sdk026_ignored in sdk026_gitignore
assert "ignoreErrors" not in Path("tooling/php-quality/phpstan-public.neon").read_text(
    encoding="utf-8"
)
assert "WordPress-Extra" in Path("tooling/php-quality/phpcs-public.xml").read_text(
    encoding="utf-8"
)

sdk026_stage = php_quality_implementation["stagingAndOwnership"]
assert sdk026_stage["input"] == "complete-in-memory-plugin-emission"
assert sdk026_stage["liveTreeReadDuringAnalysis"] is False
assert sdk026_stage["formatWritesToEmission"] is False
assert sdk026_stage["policyEmbeddedInHaxeCli"] is True
assert sdk026_stage["installedPolicyByteEqualityRequired"] is True
assert sdk026_stage["ownedReportPath"] == (
    "build/wordpress/.wphx/php-quality.json"
)
assert sdk026_stage["ownershipValidator"] == "wphx.plugin-php-quality"
assert sdk026_stage["everyEmittedPluginArtifactBoundToValidator"] is True
assert sdk026_stage["failedGenerationPublication"] == "not-attempted"
assert sdk026_stage["privatePathRedaction"] is True
sdk026_strict_paths = [
    Path("compiler/reflaxe.php/src/reflaxe/php/ir/PhpDocParameter.hx"),
    Path("compiler/reflaxe.php/src/reflaxe/php/ir/PhpDocType.hx"),
    Path("compiler/reflaxe.php/src/reflaxe/php/ir/PhpMethodDoc.hx"),
    Path("packages/cli/src/wordpresshx/cli/project/PluginPhpQuality.hx"),
    Path("packages/cli/src/wordpresshx/cli/project/PluginPhpQualityResult.hx"),
]
for sdk026_strict_path in sdk026_strict_paths:
    assert sdk024_forbidden.search(
        sdk026_strict_path.read_text(encoding="utf-8")
    ) is None

assert sdk026_receipt["schemaVersion"] == 1
assert sdk026_receipt["receiptId"] == "SDK-026-GENERATED-PHP-QUALITY"
assert sdk026_receipt["bead"] == "wordpresshx-sdk-026"
assert sdk026_receipt["status"] in {
    "local-verified-hosted-pending",
    "verified",
}
assert sdk026_receipt["subject"]["implementation"] == (
    "manifests/php-quality-implementation.json"
)
assert sdk026_receipt["subject"]["policySha256"] == sdk026_policy_sha256
assert sdk026_receipt["subject"]["composerLockSha256"] == (
    sdk026_toolchain["lockSha256"]
)
assert sdk026_receipt["verification"]["standalonePolicy"] == {
    "command": "bash scripts/php-quality/test-production.sh",
    "outcome": "passed",
    "deterministicFixtureReceipts": 3,
    "negativeMutations": 5,
    "privatePathLeaks": 0,
}
assert sdk026_receipt["verification"]["traceCliRegression"] == {
    "command": "bash packages/cli/scripts/test.sh",
    "outcome": "passed",
    "nativePhpFramesPreserved": True,
    "privateHumanSnapshot": (
        "regenerated-for-structured-phpdoc-line-shift"
    ),
}
sdk026_integrated = sdk026_receipt["verification"]["integratedCli"]
assert sdk026_integrated["command"] == "bash scripts/scaffold/test-production.sh"
assert sdk026_integrated["outcome"] == "passed"
assert sdk026_integrated["positiveCases"] == 16
assert sdk026_integrated["negativeCases"] == 11
assert sdk026_integrated["noWriteAssertions"] == 14
assert sdk026_integrated["publicReportFiles"] == 3
assert sdk026_integrated["privateReportPhpFiles"] == 21
assert sdk026_integrated["privateClassmapEntries"] == 14
assert sdk026_integrated["policyTamper"] == "rejected-before-publication"
assert sdk026_integrated["privateClassmapMismatch"] == "rejected"
sdk026_input_records = {
    record["path"]: record["sha256"]
    for record in sdk026_receipt["authenticatedInputs"]
}
sdk045_plugin_subject_records = {
    record["path"]: record["sha256"]
    for record in historical_subject_records(sdk045_plugin_receipt["subject"])
}
assert list(sdk026_input_records) == sorted(sdk026_input_records)
assert len(sdk026_input_records) == 17
for sdk026_input_path, sdk026_input_sha256 in sdk026_input_records.items():
    assert sha256.fullmatch(sdk026_input_sha256)
    sdk026_current_sha256 = hashlib.sha256(
        Path(sdk026_input_path).read_bytes()
    ).hexdigest()
    if sdk026_current_sha256 != sdk026_input_sha256:
        assert sdk026_current_sha256 == sdk045_plugin_subject_records.get(
            sdk026_input_path
        )
sdk026_hosted = sdk026_receipt["hostedVerification"]
assert sdk026_hosted["workflow"] == "Repository bootstrap"
assert sdk026_hosted["job"] == "haxe"
assert sdk026_hosted["precedingFailure"] == {
    "runId": 29695150919,
    "jobId": 88214513059,
    "commit": "cb87b6a25e405445c61408f29cbcff9f329e18c4",
    "sdk026Steps": "passed",
    "failedStep": "Test Haxe and Genes PHP trace CLI",
    "cause": "private-human-trace-snapshot-retained-pre-phpdoc-native-lines",
}
assert sdk026_hosted["steps"] == [
    "Install exact generated-PHP quality toolchain",
    "Test pinned generated-PHP quality policy",
    "Test Haxe-first site scaffolding",
]
if sdk026_hosted["status"] == "pending":
    assert sdk026_receipt["status"] == "local-verified-hosted-pending"
    assert php_quality_implementation["status"] == (
        "implemented-local-verified-hosted-pending"
    )
    assert sdk026_receipt["implementation"]["implementationCommit"] is None
    assert sdk026_hosted["commit"] is None
    assert sdk026_hosted["runId"] is None
    assert sdk026_hosted["jobId"] is None
    assert sdk026_receipt["verification"]["repository"]["outcome"] in {
        "pending-final-run",
        "passed-local",
    }
    sdk026_claim_prefix = "local"
elif sdk026_hosted["status"] == "passed":
    assert sdk026_receipt["status"] == "verified"
    assert php_quality_implementation["status"] == "implemented-hosted-verified"
    sdk026_implementation_commit = sdk026_receipt["implementation"][
        "implementationCommit"
    ]
    assert sha1.fullmatch(sdk026_implementation_commit)
    assert sdk026_hosted["commit"] == sdk026_implementation_commit
    assert isinstance(sdk026_hosted["runId"], int)
    assert isinstance(sdk026_hosted["jobId"], int)
    assert sdk026_hosted["runId"] == 29695491419
    assert sdk026_hosted["jobId"] == 88215411504
    assert sdk026_hosted["completedAt"] == "2026-07-19T16:53:52Z"
    assert sdk026_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/29695491419"
    )
    assert sdk026_hosted["fullMatrixStatus"] == "passed"
    assert sdk026_hosted["jobCount"] == 11
    assert sdk026_receipt["verification"]["repository"]["outcome"] == (
        "passed-local"
    )
    sdk026_claim_prefix = "hosted"
else:
    raise AssertionError("SDK-026 hosted verification status is invalid")
for sdk026_claim in (
    "pinnedPhpToolchain",
    "formatterAndWpcs",
    "staticAnalysis",
    "autoloadAndDuplicateSymbols",
):
    assert php_quality_implementation["claims"][sdk026_claim] == (
        sdk026_claim_prefix + "-runtime-tested"
    )
assert php_quality_implementation["claims"]["failClosedPublication"] == (
    sdk026_claim_prefix + "-negative-tested"
)
for sdk026_claim in (
    "pinnedToolsAndWordPressStubs",
    "lintFormatWpcsCompatibilityStaticAnalysis",
    "autoloadClassmapAndDuplicateSymbols",
):
    assert sdk026_receipt["claims"][sdk026_claim] == (
        sdk026_claim_prefix + "-runtime-tested"
    )
assert sdk026_receipt["claims"]["failClosedBeforePublication"] == (
    sdk026_claim_prefix + "-negative-tested"
)
assert php_quality_implementation["claims"]["projectConfigurationCeremony"] == (
    "none"
)
for sdk026_nonclaim, expected in (
    ("publicPackagePublication", "blocked"),
    ("productionSupport", "not-tested"),
):
    assert php_quality_implementation["claims"][sdk026_nonclaim] == expected
    assert sdk026_receipt["claims"][sdk026_nonclaim] == expected

assert deterministic_build_implementation["schemaVersion"] == 1
assert deterministic_build_implementation["bead"] == "wordpresshx-sdk-042"
assert deterministic_build_implementation["status"] in {
    "implemented-sdk042-local-verified",
    "implemented-sdk042-hosted-verified",
}
assert deterministic_build_implementation["scope"] == (
    "reproducible-effective-input-generation-and-bounded-unsigned-archive"
)
sdk042_contracts = deterministic_build_implementation["contracts"]
assert sdk042_contracts["effectiveInputs"] == {
    "identity": "wordpress-hx.effective-inputs.v1",
    "schema": "schemas/effective-inputs.schema.json",
    "fingerprintAlgorithm": (
        "sha256-canonical-json-without-fingerprint-v1"
    ),
}
assert sdk042_contracts["ownershipManifest"] == {
    "identity": "wordpress-hx.generated-files.v1",
    "schema": "schemas/generated-files.schema.json",
    "commitMarker": "manifest-published-last",
}
assert sdk042_contracts["reproducibleBuild"] == {
    "identity": "wordpress-hx.reproducible-build.v1",
    "schema": "schemas/reproducible-build.schema.json",
    "sidecarPath": "dist/wordpress-hx-build.json",
    "archivePath": "_wphx/reproducible-build.json",
}
assert sdk042_contracts["archive"] == {
    "format": "zip32-stored-v1",
    "path": "dist/wordpress-hx.zip",
    "signature": "unsigned",
    "boundedEvidenceOnly": True,
}
assert sdk042_contracts["canonicalization"] == (
    "wordpress-hx.canonical-json.v1"
)
for sdk042_schema_contract in (
    "effectiveInputs",
    "ownershipManifest",
    "reproducibleBuild",
):
    assert Path(sdk042_contracts[sdk042_schema_contract]["schema"]).is_file()

sdk042_code = deterministic_build_implementation["implementation"]
assert sdk042_code["language"] == "Haxe"
assert sdk042_code["target"] == "Genes-emitted-Node-ESM"
assert sdk042_code["publisher"] == (
    "packages/cli/src/wordpresshx/cli/project/BuildPublisher.hx"
)
assert sdk042_code["reportBuilder"] == (
    "packages/cli/src/wordpresshx/cli/project/ReproducibleBuild.hx"
)
assert sdk042_code["archiveWriter"] == (
    "packages/cli/src/wordpresshx/cli/project/DeterministicZip.hx"
)
assert sdk042_code["ownershipPreflight"] == (
    "packages/cli/src/wordpresshx/cli/project/OwnershipPreflight.hx"
)
assert sdk042_code["artifactOwner"] == (
    "packages/cli/src/wordpresshx/cli/ownership/ArtifactOwner.hx"
)
assert sdk042_code["comparisonOracle"] == (
    "scripts/determinism/compare-builds.py"
)
assert sdk042_code["exactToolchain"] == {
    "haxe": cli_dependency_lock["haxe"]["version"],
    "genes": cli_dependency_lock["compiler"]["version"],
    "genesCommit": cli_dependency_lock["compiler"]["commit"],
    "node": cli_dependency_lock["runtime"]["version"],
    "nodeImage": cli_dependency_lock["runtime"]["image"],
}
for sdk042_false_implementation_claim in (
    "hostZipDependency",
    "hostZlibDependency",
    "handwrittenJavascriptImplementation",
    "genesSourceChanged",
    "siblingDependencyCreated",
):
    assert sdk042_code[sdk042_false_implementation_claim] is False
assert sdk042_code["genesPullRequest"] is None

sdk042_publication = deterministic_build_implementation["publication"]
assert sdk042_publication["artifacts"] == [
    {
        "path": "build/nextjs/.wphx/effective-inputs.json",
        "role": "effective-input-graph",
        "mode": 420,
    },
    {
        "path": "dist/wordpress-hx-build.json",
        "role": "reproducibility-report",
        "mode": 420,
    },
    {
        "path": "dist/wordpress-hx.zip",
        "role": "normalized-unsigned-archive",
        "mode": 420,
    },
]
assert sdk042_publication["outputRoots"] == [
    {"rootId": "nextjs", "path": "build/nextjs"},
    {"rootId": "wordpress", "path": "build/wordpress"},
    {"rootId": "wphx.distribution", "path": "dist"},
]
assert sdk042_publication["validators"] == [
    "wphx.deterministic-archive",
    "wphx.effective-inputs",
]
assert sdk042_publication["archiveEntries"] == [
    "_wphx/reproducible-build.json",
    "build/nextjs/.wphx/effective-inputs.json",
]
assert sdk042_publication["manifestMode"] == 420
assert sdk042_publication["manifestPublishedLast"] is True
assert sdk042_publication["targetProducers"] == (
    "stage-skipped-until-registered"
)
assert sdk042_publication["deployableSitePackageClaimed"] is False

assert deterministic_build_implementation["normalization"] == {
    "entryOrder": "portable-ascii-path-ascending",
    "encoding": "utf-8",
    "jsonLineEnding": "lf",
    "fileMode": 420,
    "directoryMode": 493,
    "modifiedAt": "1980-01-01T00:00:00Z",
    "compression": "stored",
    "extraFields": False,
    "archiveComment": False,
    "absolutePaths": False,
    "hostPermissions": False,
    "hostMtimes": False,
    "localeOrTimezone": False,
}
assert deterministic_build_implementation["effectiveInputCoverage"] == {
    "sourceFiles": "content-addressed",
    "macroAndBootstrapInputs": "content-addressed",
    "projectAndProfileConfiguration": "content-addressed",
    "toolAndRuntimeLocks": "content-addressed",
    "packageAndResourceLocks": "content-addressed",
    "publicBuildEnvironment": "allowlisted-value-digests",
    "runtimeSecrets": "excluded",
    "hostPathsTimesPortsPids": "excluded",
}
assert deterministic_build_implementation["safety"] == {
    "completePrivateStageBeforePublication": True,
    "canonicalReportRecomputedBeforePublication": True,
    "archiveBytesRecomputedBeforePublication": True,
    "allOwnedArtifactsCompared": True,
    "firstCausalDifferenceReported": True,
    "safeAdditiveOutputRootMigrationOnly": True,
    "rootRemovalOrRewriteAllowed": False,
    "forcePath": False,
    "networkDependency": False,
}

sdk042_verification = deterministic_build_implementation["verification"]
assert sdk042_verification["command"] == (
    "bash scripts/determinism/test-production.sh"
)
assert sdk042_verification["schema"] == (
    "wordpress-hx.sdk042-determinism-summary.v1"
)
assert sdk042_verification["freshRootCount"] == 2
assert sdk042_verification["ownedArtifactCount"] == 3
assert sdk042_verification["archiveEntryCount"] == 2
assert sdk042_verification["negativeComparisonCount"] == 3
assert sdk042_verification["additiveRootMigrationCount"] == 1
assert sdk042_verification["fingerprint"] == (
    project_cli_contracts["effectiveInputs"]["fingerprint"]
)
assert sdk042_verification["archiveSha256"] == (
    "e9da3d59015dece6282a1e180e6dfd338c5e63fd97681cfc69f632723e9f5471"
)
assert sdk042_verification["nodeImage"] == (
    cli_dependency_lock["runtime"]["image"]
)
assert sdk042_verification["containerNetwork"] == "none"
assert sdk042_verification["genesCompileReplay"] == "byte-identical"
assert sdk042_verification["ownedGenerationReplay"] == "byte-identical"
assert sdk042_verification["hostPathAndIdentityScan"] == "passed"
assert sdk042_verification["outcome"] == "passed"

sdk042_references = deterministic_build_implementation["referencePatterns"]
assert len(sdk042_references) == 1
sdk042_reference = sdk042_references[0]
assert sdk042_reference["repository"] == "haxe.elixir.codex"
assert sdk042_reference["path"] == "scripts/release/deterministic-zip.js"
assert sdk042_reference["commit"] == (
    "40254f38d9c07c069c7c3e19831096dcc2d6c95d"
)
assert sdk042_reference["blob"] == (
    "7727d882bef08851edfe12c3da13f351eb1e16a4"
)
assert sdk042_reference["sha256"] == (
    "63c5fe3cf60dd7665854385d809956a89cbf61c4e812de1773ceaeabfbd731cf"
)
assert sdk042_reference["lesson"] == (
    "fixed-entry-order-and-representation"
)
assert sdk042_reference["copiedBytes"] is False
assert sdk042_reference["dependencyCreated"] is False

assert sdk042_receipt["schemaVersion"] == 1
assert sdk042_receipt["receiptId"] == "SDK-042-DETERMINISTIC-BUILD"
assert sdk042_receipt["bead"] == "wordpresshx-sdk-042"
assert sdk042_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}

assert set(sdk042_receipt["subject"]) == {
    "architecture",
    "reportBuilder",
    "archiveWriter",
    "publisher",
    "ownershipPaths",
    "ownershipPreflight",
    "artifactOwner",
    "reportSchema",
    "comparator",
    "productionCorpus",
    "gate",
    "projectCliCorpus",
    "ownershipContract",
    "ownershipFixtures",
    "workflow",
    "architectureDocumentation",
}
assert len(sdk042_receipt["subject"]["ownershipFixtures"]) == 3
verify_versioned_subject(sdk042_receipt)
assert sdk042_receipt["subject"]["architecture"]["sha256"] == (
    hashlib.sha256(
        Path("manifests/deterministic-build-implementation.json").read_bytes()
    ).hexdigest()
)

sdk042_receipt_implementation = sdk042_receipt["implementation"]
assert sdk042_receipt_implementation["applicationLanguage"] == "Haxe"
assert sdk042_receipt_implementation["javascriptCompiler"] == "Genes"
assert sdk042_receipt_implementation["runtime"] == "Node ESM"
assert sdk042_receipt_implementation["productArchiveWriter"] == (
    "closed-haxe-zip32-stored-v1"
)
for sdk042_false_receipt_implementation_claim in (
    "hostZipDependency",
    "hostZlibDependency",
    "networkReads",
    "forcePath",
    "genesSourceChanged",
    "siblingDependencyCreated",
):
    assert sdk042_receipt_implementation[
        sdk042_false_receipt_implementation_claim
    ] is False
assert sdk042_receipt_implementation["genesPullRequest"] is None

sdk042_receipt_verification = sdk042_receipt["verification"]
for sdk042_shared_verification_field in (
    "command",
    "outcome",
    "freshRootCount",
    "ownedArtifactCount",
    "archiveEntryCount",
    "negativeComparisonCount",
    "additiveRootMigrationCount",
    "fingerprint",
    "archiveSha256",
    "nodeImage",
    "containerNetwork",
    "genesCompileReplay",
    "ownedGenerationReplay",
):
    assert sdk042_receipt_verification[sdk042_shared_verification_field] == (
        sdk042_verification[sdk042_shared_verification_field]
    )
for sdk042_receipt_proof in (
    "fixedTimestampModeOrderAndMetadata",
    "hostPathTempPathAndIdentityScan",
    "archiveTamperDiagnostic",
    "modeDriftDiagnostic",
    "missingArtifactDiagnostic",
    "safeAdditiveSdk043Migration",
):
    assert sdk042_receipt_verification[sdk042_receipt_proof] == "passed"
assert sdk042_receipt_verification["manifestReplay"] == "byte-identical"
assert sdk042_receipt_verification["unsignedArchiveReplay"] == (
    "byte-identical"
)

assert "Test deterministic build and unsigned archive replay" in workflow_text
assert "bash scripts/determinism/test-production.sh" in workflow_text
sdk042_hosted = sdk042_receipt["hostedWorkflow"]
assert sdk042_hosted["workflow"] == "Repository bootstrap"
assert sdk042_hosted["job"] == "haxe"
assert sdk042_hosted["step"] == (
    "Test deterministic build and unsigned archive replay"
)
assert sdk042_hosted["required"] is True
if sdk042_hosted["status"] == "pending-first-main-run":
    assert sdk042_receipt["status"] == "implemented-hosted-pending"
    assert deterministic_build_implementation["status"] == (
        "implemented-sdk042-local-verified"
    )
    assert sdk042_receipt_implementation["implementationCommit"] is None
    assert sdk042_hosted["runId"] is None
    assert sdk042_hosted["jobId"] is None
    assert sdk042_hosted["commit"] is None
    assert "jobCount" not in sdk042_hosted
    assert "allJobsPassed" not in sdk042_hosted
    sdk042_evidence_level = "runtime-tested-local"
elif sdk042_hosted["status"] == "passed":
    assert sdk042_receipt["status"] == "verified"
    assert deterministic_build_implementation["status"] == (
        "implemented-sdk042-hosted-verified"
    )
    assert sha1.fullmatch(
        sdk042_receipt_implementation["implementationCommit"]
    )
    assert isinstance(sdk042_hosted["runId"], int)
    assert isinstance(sdk042_hosted["jobId"], int)
    assert sha1.fullmatch(sdk042_hosted["commit"])
    assert sdk042_hosted["commit"] == (
        sdk042_receipt_implementation["implementationCommit"]
    )
    assert sdk042_hosted["jobCount"] == 11
    assert sdk042_hosted["allJobsPassed"] is True
    sdk042_evidence_level = "runtime-tested-hosted"
else:
    raise AssertionError("SDK-042 deterministic build hosted status is invalid")

for sdk042_proven_claim in (
    "sdk042DeterministicBuild",
    "effectiveInputFingerprint",
    "ownedGenerationDeterminism",
    "unsignedArchiveDeterminism",
    "actionableDifferenceReport",
):
    assert deterministic_build_implementation["claims"][
        sdk042_proven_claim
    ] == sdk042_evidence_level
    assert sdk042_receipt["claims"][sdk042_proven_claim] == (
        sdk042_evidence_level
    )
for sdk042_unproven_claim in (
    "targetEmitterIntegration",
    "deployableWordPressPackage",
    "deployableNextjsPackage",
    "packageInstallation",
    "productionSupport",
):
    assert deterministic_build_implementation["claims"][
        sdk042_unproven_claim
    ] == "not-tested"
    assert sdk042_receipt["claims"][sdk042_unproven_claim] == "not-tested"
assert sdk042_receipt["limitations"] == (
    deterministic_build_implementation["limitations"]
)

assert source_correlation_architecture["schemaVersion"] == 1
assert source_correlation_architecture["decision"] == "ADR-014"
assert source_correlation_architecture["status"] == "accepted-architecture"
assert source_correlation_architecture["acceptedAt"] == "2026-07-18"
assert source_correlation_architecture["claim"] == (
    "sdk-025-php-and-sdk-034-browser-runtime-cli-implemented-"
    "official-wordpress-adapter-source-correlation-hosted-verified"
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
assert source_evidence["php"]["implementationReceiptId"] == (
    sdk025_receipt["receiptId"]
)
assert source_evidence["php"]["serializedMapRuntime"] == (
    "bounded-development-packaged-and-wordpress-passed"
)
assert source_evidence["php"]["traceCli"] == (
    "php-and-browser-implemented-sdk-025-sdk-034"
)
assert source_evidence["php"]["contractFixture"] == "runtime-validated"
assert source_evidence["php"]["exactPhp74"] == (
    "lint-and-four-native-failures-passed"
)
assert source_evidence["php"]["exactPhp84"] == (
    "lint-and-four-native-failures-passed"
)
assert source_evidence["php"]["wordpress70"] == (
    "four-native-failures-passed-on-mysql-and-mariadb"
)
assert source_evidence["php"]["productionPackageRetention"] == (
    "five-readable-php-files-only"
)
assert source_evidence["php"]["nativeFrames"] == "preserved"
assert source_evidence["php"]["nearestOrBasenameGuessing"] is False
assert source_evidence["browser"]["genesCommit"] == (
    gutenberg_dependency_lock["compiler"]["commit"]
)
assert source_evidence["browser"]["boundedEsbuildCompositionReceiptId"] == (
    sdk032_receipt["receiptId"]
)
assert source_evidence["browser"]["implementationReceiptId"] == (
    sdk034_receipt["receiptId"]
)
assert source_evidence["browser"]["genesLayerValidation"] == (
    "independently-validated-regular-source-map-v3"
)
assert source_evidence["browser"]["exactEsbuildTraceGate"] == (
    "development-and-minified-composition-plus-two-stage-fallback-"
    "runtime-passed"
)
assert source_evidence["browser"]["traceCli"] == (
    "implemented-offline-stable-text-and-canonical-json"
)
assert source_evidence["browser"]["productionPackageRetention"] == (
    "esbuild-runtime-js-only-and-wordpress-installable-plugin-map-index-"
    "source-content-absent"
)
assert source_evidence["browser"]["officialWordpressScriptsLaneReceiptId"] == (
    sdk033_receipt["receiptId"]
)
assert source_evidence["browser"][
    "officialWordpressScriptsCorrelationReceiptId"
] == g24_receipt["receiptId"]
expected_official_correlation_evidence = (
    "exact-entry-development-and-production-composed-local-verified-"
    "hosted-pending"
    if g24_receipt["status"] == "implemented-hosted-pending"
    else "exact-entry-development-and-production-composed-hosted-verified"
)
assert source_evidence["browser"][
    "officialWordpressScriptsCorrelation"
] == expected_official_correlation_evidence
assert source_evidence["browser"]["deliberateDevelopmentAndProductionThrows"] == (
    "passed-for-exact-sdk-034-esbuild-and-g2.4-wordpress-scripts-fixtures"
)
assert source_evidence["productionSupport"] == "not-tested"
assert source_evidence["boundedProductionPackageEvidence"] == (
    "passed-not-a-production-support-claim"
)
assert source_evidence["publicationAuthorized"] is False

assert sdk025_receipt["schemaVersion"] == 1
assert sdk025_receipt["receiptId"] == "SDK-025-PHP-SOURCE-CORRELATION"
assert sdk025_receipt["bead"] == "wordpresshx-sdk-025"
assert sdk025_receipt["status"] in {
    "implemented-local-verified",
    "verified",
}
sdk025_contracts = sdk025_receipt["publicContracts"]
assert sdk025_contracts["phpMapFormat"] == source_contract["phpMapFormat"]
assert sdk025_contracts["sourceIndexFormat"] == (
    source_contract["sourceIndexFormat"]
)
assert sdk025_contracts["genericMapFixtureFormat"] == (
    "reflaxe.php-range-map.v1"
)
assert sdk025_contracts["nativeLineLookup"] == (
    "unique emitter-owned trace anchor only"
)
assert sdk025_contracts["pathLookup"] == (
    "complete normalized logical relative identity only"
)

sdk025_toolchain = sdk025_receipt["toolchain"]
assert sdk025_toolchain["haxe"] == cli_dependency_lock["haxe"]["version"]
assert sdk025_toolchain["lixPackage"] == (
    cli_dependency_lock["lix"]["packageVersion"]
)
assert sdk025_toolchain["lixReportedCli"] == (
    cli_dependency_lock["lix"]["cliVersion"]
)
assert sdk025_toolchain["lixPackage"] == (
    toolchain_lock["dependencyGraphs"]["npm"]["activePackages"][0][
        "version"
    ]
)
assert sdk025_toolchain["genes"]["version"] == (
    cli_dependency_lock["compiler"]["version"]
)
assert sdk025_toolchain["genes"]["commit"] == (
    cli_dependency_lock["compiler"]["commit"]
)
assert sdk025_toolchain["genes"]["tree"] == (
    cli_dependency_lock["compiler"]["tree"]
)
assert sdk025_toolchain["node"]["image"] == (
    image_lock["images"]["node"]["reference"]
)
assert sdk025_toolchain["php74"]["image"] == (
    image_lock["images"]["php74Floor"]["reference"]
)
assert sdk025_toolchain["php84"]["image"] == (
    image_lock["images"]["php84Cli"]["reference"]
)
assert sdk025_toolchain["wordpress"]["image"] == (
    image_lock["images"]["wordpress70Php84"]["reference"]
)
assert sdk025_toolchain["mysql"] == image_lock["images"]["mysql"][
    "reference"
]
assert sdk025_toolchain["mariadb"] == image_lock["images"]["mariadb"][
    "reference"
]

sdk025_implementation = sdk025_receipt["implementation"]
assert sdk025_implementation["genericCompiler"]["wordpressKnowledge"] is False
assert sdk025_implementation["cli"]["applicationLanguage"] == "Haxe"
assert sdk025_implementation["cli"]["javascriptCompiler"] == "Genes"
assert sdk025_implementation["cli"]["offline"] is True
assert sdk025_implementation["cli"]["readOnly"] is True
assert sdk025_implementation["cli"]["networkLookup"] is False
assert sdk025_implementation["changeDecision"]["genesSourceChanged"] is False
assert sdk025_implementation["changeDecision"]["genesPullRequest"] is None
if sdk025_implementation["implementationCommit"] is not None:
    assert sha1.fullmatch(sdk025_implementation["implementationCommit"])

assert strict_haxe_migration["schemaVersion"] == 1
assert strict_haxe_migration["receiptId"] == "STRICT-HAXE-MIGRATION"
assert strict_haxe_migration["bead"] == "wordpresshx-sjb"
assert strict_haxe_migration["status"] in {
    "implemented-hosted-pending",
    "verified-hosted",
}
strict_haxe_directive = strict_haxe_migration["directive"]
strict_haxe_tokens = ["Dynamic", "Any", "cast", "Reflect", "untyped"]
assert strict_haxe_directive["forbiddenTokens"] == strict_haxe_tokens
assert strict_haxe_directive["typedBoundaryPolicy"] == (
    "decode-or-construct-closed-values-before-domain-or-compiler-logic"
)
assert strict_haxe_directive[
    "repositoryWideClaimAllowedBeforeZeroFindings"
] is False
strict_haxe_subjects = {
    record["path"]: record["sha256"]
    for record in strict_haxe_migration["subjects"]
}
assert set(strict_haxe_subjects) == {
    "packages/core/src/wordpress/hx/core/profile/EvidenceStatus.hx",
    "scripts/profiles/test-profile-haxe.sh",
    "compiler/reflaxe.php/src/reflaxe/php/map/PhpCanonicalJson.hx",
    "compiler/reflaxe.php/src/reflaxe/php/map/PhpRangeMapWriter.hx",
    "compiler/reflaxe.php/scripts/test.sh",
    (
        "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
        "WordPressPhpSourceIndexWriter.hx"
    ),
    (
        "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
        "WordPressPluginArtifact.hx"
    ),
    (
        "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
        "WordPressPublicAdapterArtifact.hx"
    ),
    "compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx",
    (
        "compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/"
        "WordPressPublicAdapterTest.hx"
    ),
    (
        "compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/"
        "WordPressPhpProfileTest.hx"
    ),
    (
        "compiler/wordpress/test/wordpress/hx/compiler/php/profile/tests/"
        "WordPressSourceCorrelationTest.hx"
    ),
    "compiler/wordpress/scripts/test.sh",
    "packages/cli/src/wordpresshx/cli/closedjson/JsonValue.hx",
    "packages/cli/src/wordpresshx/cli/closedjson/JsonParser.hx",
    "packages/cli/src/wordpresshx/cli/CanonicalJson.hx",
    "packages/cli/src/wordpresshx/cli/CliArguments.hx",
    "packages/cli/src/wordpresshx/cli/Contract.hx",
    "packages/cli/src/wordpresshx/cli/Content.hx",
    "packages/cli/src/wordpresshx/cli/SourceIndex.hx",
    "packages/cli/src/wordpresshx/cli/PhpTraceEngine.hx",
    "packages/cli/src/wordpresshx/cli/SourceMapV3.hx",
    "packages/cli/src/wordpresshx/cli/BrowserTraceEngine.hx",
    "packages/cli/src/wordpresshx/cli/CliEventStream.hx",
    "packages/cli/src/wordpresshx/cli/CliJson.hx",
    "packages/cli/src/wordpresshx/cli/Main.hx",
    "packages/cli/src/wordpresshx/cli/TraceCommand.hx",
    "packages/cli/scripts/check-trace-haxe.sh",
    "packages/cli/scripts/test.sh",
    "packages/cli/scripts/test-browser-source-correlation.sh",
    "scripts/lint/haxe-weak-type-guard.py",
}
for strict_haxe_path, strict_haxe_digest in strict_haxe_subjects.items():
    assert sha256.fullmatch(strict_haxe_digest)
    assert hashlib.sha256(Path(strict_haxe_path).read_bytes()).hexdigest() == (
        strict_haxe_digest
    )

strict_haxe_pattern = re.compile(
    r"\b(?:" + "|".join(map(re.escape, strict_haxe_tokens)) + r")\b"
)


def strict_haxe_findings(paths):
    return sum(
        1
        for path in paths
        for line in path.read_text(encoding="utf-8").splitlines()
        if strict_haxe_pattern.search(line)
    )


strict_haxe_inventory = strict_haxe_migration["inventory"]
tracked_haxe_paths = [
    Path(path)
    for path in subprocess.run(
        ["git", "ls-files", "--", "*.hx"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
]
assert strict_haxe_inventory["initialFindingCount"] == 583
assert strict_haxe_inventory["currentFindingCount"] == strict_haxe_findings(
    tracked_haxe_paths
)
assert strict_haxe_inventory["removedFindingCount"] == (
    strict_haxe_inventory["initialFindingCount"]
    - strict_haxe_inventory["currentFindingCount"]
) == 220
assert strict_haxe_inventory["complete"] is False

strict_haxe_scopes = {
    scope["id"]: scope for scope in strict_haxe_migration["completedScopes"]
}
strict_haxe_outcome = (
    "passed-local"
    if strict_haxe_migration["status"] == "implemented-hosted-pending"
    else "passed-hosted"
)
assert set(strict_haxe_scopes) == {
    "core-profile-contract",
    "generic-php-compiler",
    "wordpress-php-compiler",
    "cli-trace-and-shared-json",
}
for strict_haxe_scope_id, strict_haxe_root, strict_haxe_count, strict_haxe_gate in (
    (
        "core-profile-contract",
        "packages/core",
        18,
        "bash scripts/profiles/test-profile-haxe.sh",
    ),
    (
        "generic-php-compiler",
        "compiler/reflaxe.php",
        34,
        "bash compiler/reflaxe.php/scripts/test.sh",
    ),
    (
        "wordpress-php-compiler",
        "compiler/wordpress",
        25,
        "bash compiler/wordpress/scripts/test.sh",
    ),
):
    strict_haxe_scope = strict_haxe_scopes[strict_haxe_scope_id]
    assert strict_haxe_scope["root"] == strict_haxe_root
    strict_haxe_scope_prefix = strict_haxe_root + "/"
    strict_haxe_scope_paths = sorted(
        path
        for path in tracked_haxe_paths
        if str(path).startswith(strict_haxe_scope_prefix)
    )
    assert len(strict_haxe_scope_paths) == strict_haxe_count
    assert strict_haxe_scope["haxeFileCount"] == strict_haxe_count
    assert strict_haxe_scope["findingCount"] == strict_haxe_findings(
        strict_haxe_scope_paths
    ) == 0
    assert strict_haxe_scope["gate"] == strict_haxe_gate
    assert strict_haxe_scope["outcome"] == strict_haxe_outcome

strict_haxe_trace_paths = [
    "packages/cli/src/wordpresshx/cli/BrowserTraceEngine.hx",
    "packages/cli/src/wordpresshx/cli/CanonicalJson.hx",
    "packages/cli/src/wordpresshx/cli/CliArguments.hx",
    "packages/cli/src/wordpresshx/cli/CliEventStream.hx",
    "packages/cli/src/wordpresshx/cli/CliJson.hx",
    "packages/cli/src/wordpresshx/cli/Content.hx",
    "packages/cli/src/wordpresshx/cli/Contract.hx",
    "packages/cli/src/wordpresshx/cli/Main.hx",
    "packages/cli/src/wordpresshx/cli/PhpTraceEngine.hx",
    "packages/cli/src/wordpresshx/cli/SourceIndex.hx",
    "packages/cli/src/wordpresshx/cli/SourceMapV3.hx",
    "packages/cli/src/wordpresshx/cli/TraceCommand.hx",
]
strict_haxe_trace_scope = strict_haxe_scopes["cli-trace-and-shared-json"]
assert strict_haxe_trace_scope["root"] == "packages/cli/src/wordpresshx/cli"
assert strict_haxe_trace_scope["paths"] == strict_haxe_trace_paths
assert strict_haxe_trace_scope["haxeFileCount"] == len(strict_haxe_trace_paths) == 12
assert strict_haxe_trace_scope["findingCount"] == strict_haxe_findings(
    [Path(path) for path in strict_haxe_trace_paths]
) == 0
assert strict_haxe_trace_scope["gate"] == (
    "bash packages/cli/scripts/check-trace-haxe.sh"
)
assert strict_haxe_trace_scope["outcome"] == strict_haxe_outcome

assert strict_haxe_migration["typedAdapters"] == [
    {
        "id": "wordpress-php-source-index",
        "path": (
            "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
            "WordPressPhpSourceIndexWriter.hx"
        ),
        "genericBoundary": (
            "reflaxe.php.map.PhpCanonicalJson.PhpJsonValue"
        ),
        "gate": "bash compiler/wordpress/scripts/test.sh",
        "outcome": strict_haxe_outcome,
        "owningClosureComplete": True,
    },
    {
        "id": "cli-source-correlation-json",
        "path": "packages/cli/src/wordpresshx/cli/SourceIndex.hx",
        "genericBoundary": "wordpresshx.cli.closedjson.JsonValue",
        "gate": "bash packages/cli/scripts/check-trace-haxe.sh",
        "outcome": strict_haxe_outcome,
        "owningClosureComplete": True,
    }
]
strict_haxe_hosted = strict_haxe_migration["hostedVerification"]
assert strict_haxe_hosted["workflow"] == "Repository bootstrap"
assert strict_haxe_hosted["job"] == "haxe"
assert strict_haxe_hosted["required"] is True
if strict_haxe_migration["status"] == "implemented-hosted-pending":
    assert strict_haxe_hosted["implementationCommit"] is None
    assert strict_haxe_hosted["runId"] is None
    assert strict_haxe_hosted["jobId"] is None
    assert strict_haxe_hosted["status"] == "pending-current-subject-run"
    assert strict_haxe_hosted["allJobsPassed"] is False
    assert strict_haxe_hosted["completedAt"] is None
    strict_haxe_claim = "runtime-tested-local"
    assert strict_haxe_migration["previousHostedVerification"] == {
        "workflow": "Repository bootstrap",
        "job": "haxe",
        "implementationCommit": (
            "31c506a0a3789e84fdcda32f6fc71cf6018629c6"
        ),
        "runId": 29820264347,
        "jobId": 88600999236,
        "status": "passed-before-cli-trace-closure",
        "allJobsPassed": True,
        "completedAt": "2026-07-21T10:09:11Z",
    }
else:
    assert sha1.fullmatch(strict_haxe_hosted["implementationCommit"])
    assert isinstance(strict_haxe_hosted["runId"], int)
    assert isinstance(strict_haxe_hosted["jobId"], int)
    assert strict_haxe_hosted["status"] == "passed"
    assert strict_haxe_hosted["allJobsPassed"] is True
    assert strict_haxe_hosted["completedAt"].endswith("Z")
    strict_haxe_claim = "runtime-tested-hosted"
for strict_haxe_claim_name in (
    "coreProfileContractStrict",
    "genericPhpCompilerStrict",
    "wordpressPhpCompilerStrict",
    "wordpressSourceIndexTypedAdapter",
    "cliTraceAndSharedJsonStrict",
    "cliSourceCorrelationTypedAdapter",
):
    assert strict_haxe_migration["claims"][strict_haxe_claim_name] == (
        strict_haxe_claim
    )
assert strict_haxe_migration["claims"]["repositoryWideStrictHaxe"] == (
    "not-yet-remaining-findings"
)
assert strict_haxe_migration["claims"]["productionSupport"] == "not-claimed"

sdk025_inputs = sdk025_receipt["authenticatedInputs"]
assert len({record["path"] for record in sdk025_inputs}) == len(sdk025_inputs)
sdk024_generic_records = {
    record["path"]: record["sha256"]
    for record in sdk024_receipt["subject"]["genericCompiler"]
}
for record in sdk025_inputs:
    assert sha256.fullmatch(record["sha256"])
    current_sha256 = hashlib.sha256(Path(record["path"]).read_bytes()).hexdigest()
    if current_sha256 != record["sha256"]:
        assert current_sha256 in {
            sdk024_generic_records.get(record["path"]),
            sdk026_input_records.get(record["path"]),
            strict_haxe_subjects.get(record["path"]),
        }
        assert sha1.fullmatch(sdk025_implementation["implementationCommit"])

sdk025_fixture = sdk025_receipt["fixtureEvidence"]
assert sdk025_fixture["mappingCount"] == 13
assert sdk025_fixture["traceAnchorCount"] == 4
assert set(sdk025_fixture["failureModes"]) == {
    "hook",
    "rest",
    "render",
    "private",
}
assert sdk025_fixture["privateFailureProducesHonestPartialFrame"] is True
assert sdk025_fixture["multibyteGenericFixture"] == "café"

sdk025_verification = sdk025_receipt["verification"]
assert sdk025_verification["genericCompiler"]["outcome"] == "passed"
assert sdk025_verification["wordpressProfile"]["outcome"] == "passed"
assert sdk025_verification["exactPhpMatrix"]["php74"] == "passed"
assert sdk025_verification["exactPhpMatrix"]["php84"] == "passed"
assert sdk025_verification["wordpressMatrix"]["wordpressVersion"] == "7.0"
assert len(sdk025_verification["wordpressMatrix"]["lanes"]) == 2
assert sdk025_verification["wordpressMatrix"]["nativeStackPreserved"] is True
assert sdk025_verification["traceCli"]["nativeStackCount"] == 8
assert sdk025_verification["traceCli"]["mappedTraceAnchorCount"] == 8
assert sdk025_verification["traceCli"]["nativeLinesPreservedByteForByte"] is True
assert sdk025_verification["traceCli"]["stableTextOutput"] is True
assert sdk025_verification["traceCli"]["canonicalJsonOutput"] is True
assert sdk025_verification["failClosed"]["ambiguousAnchorExit"] == 4
assert sdk025_verification["failClosed"]["basenameOnlyPath"] == (
    "unmapped-no-layer"
)
assert sdk025_verification["failClosed"]["nearestLineFallback"] is False
assert sdk025_verification["failClosed"]["machinePathLeakCount"] == 0

sdk025_packaging = sdk025_receipt["packaging"]
assert sdk025_packaging["productionEntries"] == [
    "includes/Bootstrap.php",
    "includes/FailureCallbacks.php",
    "includes/autoload.php",
    "includes/register-adapters.php",
    "source-correlation.php",
]
assert sdk025_packaging["debugCompanionEntries"] == [
    "includes/FailureCallbacks.php.haxe-map.json",
    "source-index.json",
]
for forbidden_sdk025_retention in (
    "mapsInProduction",
    "sourceIndexInProduction",
    "sourceContentIncluded",
    "developmentHandlerIncluded",
):
    assert sdk025_packaging[forbidden_sdk025_retention] is False
assert sdk025_packaging["debugCompanionBoundToProductionPhp"] is True
assert sdk025_packaging["deterministicReplay"] == "passed"

sdk025_hosted = sdk025_receipt["hostedVerification"]
assert sdk025_hosted["status"] in {
    "pending-main-push",
    "pending-rerun-after-lix-shim-fix",
    "passed",
}
assert sdk025_hosted["discardedAttempts"] == [
    {
        "runId": 29644579049,
        "commit": "08b785fa92e6e43cedb1f49154b577bc5e069c44",
        "outcome": "failed-before-cli-compile",
        "reason": (
            "the hosted gate invoked setup-haxe instead of the authenticated "
            "Lix shim after scoped dependencies were downloaded; all other "
            "nine hosted jobs passed"
        ),
    }
]
assert sdk025_hosted["reverificationReason"] == (
    "The shared CLI dependency lock and verifier now authenticate the exact "
    "per-platform Playwright browser matrix introduced by SDK-034"
)
assert sdk025_hosted["previousPassedVerification"] == {
    "commit": "3fc02d0168d929993e42226db6e419a229b50267",
    "runId": 29644917228,
    "fullMatrixStatus": "passed",
    "jobCount": 10,
    "haxeJobId": 88081445092,
}
if sdk025_hosted["status"] == "passed":
    assert sdk025_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk025_hosted["commit"])
    assert isinstance(sdk025_hosted["runId"], int)
    assert sdk025_hosted["fullMatrixStatus"] == "passed"
    assert sdk025_hosted["jobCount"] == 10
    assert sdk025_hosted["haxeJobId"] == 88091750488
    assert sdk025_hosted["cliStep"] == "Test Haxe and Genes PHP trace CLI"
else:
    assert sdk025_hosted["commit"] is None
    assert sdk025_hosted["runId"] is None
assert sdk025_receipt["claims"]["browserTraceCorrelation"] == (
    "implemented-by-sdk-034-not-part-of-sdk-025-hosted-claim"
)
assert sdk025_receipt["claims"]["productionSupport"] == "not-tested"
assert sdk025_receipt["claims"]["publicPackagePublication"] == "blocked"

assert sdk034_receipt["schemaVersion"] == 1
assert sdk034_receipt["receiptId"] == (
    "SDK-034-BROWSER-SOURCE-CORRELATION"
)
assert sdk034_receipt["bead"] == "wordpresshx-sdk-034"
assert sdk034_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
sdk034_subject = sdk034_receipt["subject"]
assert sdk034_subject["profileId"] == "wp70-release"
assert sdk034_subject["buildAdapter"] == "sdk-034-esbuild-fixture"
assert sdk034_subject["entries"] == [
    "development",
    "production",
    "two-stage",
]

sdk034_scope = sdk034_receipt["scope"]
assert sdk034_scope["genesLayerValidatedIndependently"] is True
assert sdk034_scope["composedModes"] == ["development", "production"]
assert sdk034_scope["twoStageMode"] == "two-stage"
assert sdk034_scope["runtimePlatforms"] == ["linux/amd64", "linux/arm64"]
assert sdk034_scope["officialWordpressScriptsCorrelation"] == (
    "not-tested-follow-up-wordpresshx-g2.4"
)
assert sdk034_scope["nextJsCorrelation"] == (
    "not-tested-owned-by-sdk-113-per-adapter-entry-mode"
)
assert sdk034_scope["generalProductionSupport"] is False
assert sdk034_scope["publicationAuthorized"] is False

sdk034_toolchain = sdk034_receipt["toolchain"]
assert sdk034_toolchain["haxe"] == cli_dependency_lock["haxe"]["version"]
assert sdk034_toolchain["lixPackage"] == (
    cli_dependency_lock["lix"]["packageVersion"]
)
assert sdk034_toolchain["lixReportedCli"] == (
    cli_dependency_lock["lix"]["cliVersion"]
)
assert sdk034_toolchain["genes"]["version"] == (
    cli_dependency_lock["compiler"]["version"]
)
assert sdk034_toolchain["genes"]["commit"] == (
    cli_dependency_lock["compiler"]["commit"]
)
assert sdk034_toolchain["genes"]["tree"] == (
    cli_dependency_lock["compiler"]["tree"]
)
browser_correlation_lock = cli_dependency_lock["browserCorrelation"]
assert sdk034_toolchain["bundler"]["version"] == (
    browser_correlation_lock["bundler"]["version"]
)
assert sdk034_toolchain["bundler"]["npmIntegrity"] == (
    browser_correlation_lock["bundler"]["npmIntegrity"]
)
assert sdk034_toolchain["browser"]["image"] == (
    image_lock["images"]["playwright"]["reference"]
)
assert sdk034_toolchain["browser"]["image"] == (
    browser_correlation_lock["browserRuntime"]["image"]
)
assert sdk034_toolchain["browser"]["platforms"] == (
    browser_correlation_lock["browserRuntime"]["platforms"]
)

sdk034_inputs = sdk034_receipt["authenticatedInputs"]
assert len({record["path"] for record in sdk034_inputs}) == len(
    sdk034_inputs
)
for record in sdk034_inputs:
    assert sha256.fullmatch(record["sha256"])
    sdk034_current_sha256 = hashlib.sha256(
        Path(record["path"]).read_bytes()
    ).hexdigest()
    if sdk034_current_sha256 != record["sha256"]:
        assert sdk034_current_sha256 == strict_haxe_subjects.get(record["path"])
        assert sha1.fullmatch(
            sdk034_receipt["implementation"]["implementationCommit"]
        )

sdk034_implementation = sdk034_receipt["implementation"]
assert sdk034_implementation["sourceMapReader"] == {
    "format": "closed regular Source Map v3",
    "base64Vlq": True,
    "lookup": "exact generated line with greatest-lower-bound column",
    "sectionsSupported": False,
    "sourcesContentAllowed": False,
    "layerContinuityAuthenticated": True,
}
assert sdk034_implementation["sourceIndex"]["sharedByPhpAndBrowser"] is True
assert sdk034_implementation["sourceIndex"]["exactLogicalPathIdentity"] is True
assert sdk034_implementation["sourceIndex"]["basenameOrSuffixGuessing"] is False
assert sdk034_implementation["browserTraceCli"]["applicationLanguage"] == (
    "Haxe"
)
assert sdk034_implementation["browserTraceCli"]["javascriptCompiler"] == (
    "Genes"
)
assert sdk034_implementation["browserTraceCli"]["offline"] is True
assert sdk034_implementation["browserTraceCli"]["readOnly"] is True
assert sdk034_implementation["browserTraceCli"]["networkLookup"] is False
assert sdk034_implementation["browserTraceCli"]["exitCodes"] == (
    trace_cli["exitCodes"]
)
assert sdk034_implementation["changeDecision"]["genesSourceChanged"] is False
assert sdk034_implementation["changeDecision"]["genesPullRequest"] is None

sdk034_fixture = sdk034_receipt["fixtureEvidence"]
assert sdk034_fixture["expectedSource"] == {
    "rootId": "project",
    "path": (
        "packages/cli/test/browser-source-correlation/src/"
        "sdk034/fixture/Main.hx"
    ),
    "line": 12,
    "column": 8,
}
assert sdk034_fixture["indexedFileCount"] == 15
assert sha256.fullmatch(sdk034_fixture["sourceIndexSha256"])
assert sha256.fullmatch(sdk034_fixture["artifactSetSha256"])
assert set(sdk034_fixture["browserReceiptSha256ByPlatform"]) == {
    "linux/amd64",
    "linux/arm64",
}
assert all(
    sha256.fullmatch(value)
    for value in sdk034_fixture["browserReceiptSha256ByPlatform"].values()
)
assert sdk034_fixture["stackHashesApplyToAllRuntimePlatforms"] is True
sdk034_modes = sdk034_fixture["modes"]
assert set(sdk034_modes) == {"development", "production", "two-stage"}
assert sdk034_modes["development"]["status"] == "mapped-composed"
assert sdk034_modes["production"]["status"] == "mapped-composed"
assert sdk034_modes["two-stage"]["status"] == "mapped-two-stage"
for mode in sdk034_modes.values():
    for key, value in mode.items():
        if key.endswith("Sha256"):
            assert sha256.fullmatch(value)

sdk034_verification = sdk034_receipt["verification"]
assert sdk034_verification["browserGate"]["outcome"] == "passed"
assert sdk034_verification["browserGate"]["realChromiumFailureRuns"] == 6
assert sdk034_verification["browserGate"]["runtimePlatforms"] == [
    "linux/amd64",
    "linux/arm64",
]
assert sdk034_verification["browserGate"][
    "crossPlatformNativeStackParity"
] is True
assert sdk034_verification["browserGate"]["browserFailuresReplayStable"] is True
assert sdk034_verification["browserGate"]["nativeStackTextPreservedByteForByte"] is True
assert sdk034_verification["browserGate"]["canonicalJsonReplay"] is True
assert sdk034_verification["phpCliRegression"]["outcome"] == "passed"
sdk034_negatives = sdk034_verification["negativeCases"]
assert len(sdk034_negatives["integrityOrSchemaExit3"]) == 13
assert len(sdk034_negatives["ambiguousContractExit4"]) == 2
assert len(sdk034_negatives["usageOrInputExit2"]) == 5
assert sdk034_negatives["nearestOrBasenameGuessing"] is False
assert sdk034_negatives["machinePathLeakCount"] == 0

sdk034_packaging = sdk034_receipt["packaging"]
assert sdk034_packaging["productionEntries"] == ["runtime/production.js"]
assert sdk034_packaging["debugCompanionEntries"] == [
    "generated/genes/Register.ts",
    "generated/index.ts",
    "generated/sdk034/fixture/Main.ts",
    "maps/development.js.map",
    "maps/generated-main.ts.map",
    "maps/production.js.map",
    "maps/two-stage.js.map",
    "runtime/development.js",
    "runtime/two-stage.js",
    "source-index.json",
]
for forbidden_sdk034_retention in (
    "mapsInProduction",
    "sourceIndexInProduction",
    "sourceContentIncluded",
    "haxeSourceIncluded",
    "inlineSourceMapCommentInRuntime",
):
    assert sdk034_packaging[forbidden_sdk034_retention] is False
assert sdk034_packaging["debugCompanionBoundToProductionRuntime"] is True
assert sdk034_packaging["deterministicReplay"] == "passed"

sdk034_tooling_manifest = json.loads(
    sdk034_tooling_manifest_path.read_text(encoding="utf-8")
)
sdk034_tooling_lock = json.loads(
    sdk034_tooling_lock_path.read_text(encoding="utf-8")
)
assert sdk034_tooling_manifest["private"] is True
assert sdk034_tooling_manifest["engines"] == {
    "node": "22.17.0",
    "npm": "10.9.2",
}
assert sdk034_tooling_manifest["devDependencies"] == {
    "esbuild": "0.27.2",
    "playwright-core": "1.58.2",
}
assert sdk034_toolchain["integrityLockedNpmPackageCount"] == (
    len(sdk034_tooling_lock["packages"]) - 1
)
sdk034_graph = next(
    graph
    for graph in toolchain_lock["dependencyGraphs"]["npm"]["externalGraphs"]
    if graph["id"] == "sdk-034-browser-source-correlation-verification-graph"
)
assert sdk034_graph["receiptId"] == sdk034_receipt["receiptId"]
assert sdk034_graph["profilePath"] == sdk034_profile_path.as_posix()
assert sdk034_graph["profileSha256"] == hashlib.sha256(
    sdk034_profile_path.read_bytes()
).hexdigest()
assert sdk034_graph["manifestPath"] == sdk034_tooling_manifest_path.as_posix()
assert sdk034_graph["manifestSha256"] == hashlib.sha256(
    sdk034_tooling_manifest_path.read_bytes()
).hexdigest()
assert sdk034_graph["lockPath"] == sdk034_tooling_lock_path.as_posix()
assert sdk034_graph["lockSha256"] == hashlib.sha256(
    sdk034_tooling_lock_path.read_bytes()
).hexdigest()
assert sdk034_graph["dependencyLockSha256"] == hashlib.sha256(
    Path(sdk034_graph["dependencyLockPath"]).read_bytes()
).hexdigest()
assert set(sdk034_graph["directPackages"]) == {
    f"{name}@{version}"
    for name, version in sdk034_tooling_manifest["devDependencies"].items()
}
assert sdk034_graph["buildImage"] == image_lock["images"]["node"]["reference"]
assert sdk034_graph["runtimeImage"] == (
    image_lock["images"]["playwright"]["reference"]
)
assert sdk034_graph["lifecycleScriptsAllowed"] is False
assert sdk034_graph["officialWordpressScriptsFollowUp"] == "wordpresshx-g2.4"
assert sdk034_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]

sdk034_hosted = sdk034_receipt["hostedVerification"]
assert sdk034_hosted["status"] in {"pending-main-push", "passed"}
assert sdk034_receipt["discardedHostedAttempts"] == [
    {
        "runId": 29647539344,
        "jobId": 88088189941,
        "commit": "578f2998e60723c7535bd123f7e4de5855f4ee61",
        "outcome": "failed-before-browser-compile",
        "reason": (
            "The gate queried the global Haxelib registry for a Genes "
            "dependency installed exclusively in the authenticated Lix cache; "
            "the other nine workflow jobs passed"
        ),
    },
    {
        "runId": 29647864068,
        "jobId": 88089020995,
        "commit": "732f3f409f3b73842f605e6b9600477714557b75",
        "outcome": "failed-before-browser-compile",
        "reason": (
            "The gate derived the Lix root from haxelib config, but the hosted "
            "haxelib command remained bound to the separate setup-haxe "
            "installation"
        ),
    },
    {
        "runId": 29648122317,
        "jobId": 88089703498,
        "commit": "bfefcd3e3cc77b0f67c826bf82e6f34f0e4b7f22",
        "outcome": "failed-after-cross-platform-browser-execution",
        "reason": (
            "The multi-architecture Playwright index contains browser "
            "145.0.7632.6 on AMD64 and 145.0.7632.0 on ARM64, but the receipt "
            "modeled only the ARM64 version; the other nine workflow jobs "
            "passed"
        ),
    },
]
sdk034_browser_gate_source = Path(
    "packages/cli/scripts/test-browser-source-correlation.sh"
).read_text(encoding="utf-8")
assert "haxelib path genes-ts" not in sdk034_browser_gate_source
assert 'process.env.HAXE_ROOT ||' in sdk034_browser_gate_source
assert 'process.env.HAXESHIM_ROOT ||' in sdk034_browser_gate_source
assert 'process.env.HAXESHIM_LIBCACHE ||' in sdk034_browser_gate_source
assert 'process.env.HAXE_LIBCACHE ||' in sdk034_browser_gate_source
assert 'path.join(os.homedir(), "haxe")' in sdk034_browser_gate_source
assert 'path.join(haxeRoot, "haxe_libraries")' in sdk034_browser_gate_source
assert (
    'genes_root="${haxe_library_cache}/genes-ts/1.36.3/github/'
    'c59ecb361fd91418584487c2138bae8d3d3a3961/src"'
) in sdk034_browser_gate_source
if sdk034_hosted["status"] == "passed":
    assert sdk034_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk034_implementation["implementationCommit"])
    assert sha1.fullmatch(sdk034_hosted["commit"])
    assert isinstance(sdk034_hosted["runId"], int)
    assert isinstance(sdk034_hosted["jobId"], int)
    assert sdk034_hosted["jobCount"] == 10
    assert sdk034_hosted["fullMatrixStatus"] == "passed"
    assert sdk034_hosted["cliStep"] == (
        "Test real browser source-map composition and trace CLI"
    )
else:
    assert sdk034_receipt["status"] == "implemented-hosted-pending"
    assert sdk034_implementation["implementationCommit"] is None
    assert sdk034_hosted["commit"] is None
    assert sdk034_hosted["runId"] is None
    assert sdk034_hosted["jobId"] is None
assert sdk034_receipt["claims"]["officialWordpressScriptsCorrelation"] == (
    "not-tested-wordpresshx-g2.4"
)
assert sdk034_receipt["claims"]["nextJsCorrelation"] == (
    "not-tested-sdk-113"
)
assert sdk034_receipt["claims"]["multiArchitectureBrowserRuntime"] == (
    "exact-child-manifests-runtime-tested-with-byte-identical-stacks"
)
assert sdk034_receipt["claims"]["productionSupport"] == "not-tested"
assert sdk034_receipt["claims"]["publicPackagePublication"] == "blocked"

assert g24_receipt["schemaVersion"] == 1
assert g24_receipt["receiptId"] == (
    "G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION"
)
assert g24_receipt["bead"] == "wordpresshx-g2.4"
assert g24_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
g24_subject = g24_receipt["subject"]
assert g24_subject["package"] == "packages/gutenberg"
assert g24_subject["profileId"] == "wp70-release"
assert g24_subject["adapter"] == "@wordpress/scripts@31.5.0"
assert g24_subject["bundler"] == "webpack@5.108.4"
assert g24_subject["entry"] == "src/editor.tsx"
assert g24_subject["modes"] == ["development", "production"]
g24_scope = g24_receipt["scope"]
assert g24_scope["genesLayerValidatedIndependently"] is True
assert g24_scope["finalWebpackLayersValidatedIndependently"] is True
assert g24_scope["strategy"] == "browser-composed-v3"
assert g24_scope["twoStageFallbackRequired"] is False
assert g24_scope["generalProductionSupport"] is False
assert g24_scope["publicationAuthorized"] is False

g24_toolchain = g24_receipt["toolchain"]
assert g24_toolchain["haxe"] == cli_dependency_lock["haxe"]["version"]
assert g24_toolchain["genes"]["version"] == (
    gutenberg_dependency_lock["compiler"]["version"]
)
assert g24_toolchain["genes"]["commit"] == (
    gutenberg_dependency_lock["compiler"]["commit"]
)
assert g24_toolchain["genes"]["tree"] == (
    gutenberg_dependency_lock["compiler"]["tree"]
)
assert g24_toolchain["nodeBuild"]["image"] == (
    image_lock["images"]["node"]["reference"]
)
assert g24_toolchain["browser"]["image"] == (
    image_lock["images"]["playwright"]["reference"]
)
assert g24_toolchain["browser"]["platforms"] == (
    toolchain_lock["runtimeImages"]["playwright"]["platforms"]
)
assert sorted(g24_toolchain["browser"]["platforms"]) == image_lock[
    "images"
]["playwright"]["requiredPlatforms"]
assert g24_toolchain["integrityLockedNpmPackageCount"] == (
    len(json.loads(sdk033_tooling_lock_path.read_text(encoding="utf-8"))["packages"])
    - 1
)

g24_inputs = g24_receipt["authenticatedInputs"]
assert len({record["path"] for record in g24_inputs}) == len(g24_inputs)
for record in g24_inputs:
    assert sha256.fullmatch(record["sha256"])
    g24_current_sha256 = hashlib.sha256(
        Path(record["path"]).read_bytes()
    ).hexdigest()
    if g24_current_sha256 != record["sha256"]:
        assert g24_current_sha256 == strict_haxe_subjects.get(record["path"])
        assert sha1.fullmatch(g24_receipt["hostedVerification"]["commit"])

g24_layers = g24_receipt["layerEvidence"]
assert g24_layers["genes"]["rawSourceCount"] == 6
assert g24_layers["genes"]["haxeSourceCount"] == 6
assert g24_layers["genes"]["sourcesContentPresent"] is False
assert g24_layers["genes"]["validatedBeforeWebpack"] is True
assert g24_layers["development"]["rawSourceCount"] == 19
assert g24_layers["development"]["haxeSourceCount"] == 7
assert g24_layers["development"][
    "embeddedHaxeSourceContentVerified"
] == 9
assert g24_layers["production"]["rawSourceCount"] == 10
assert g24_layers["production"]["haxeSourceCount"] == 5
for layer in (
    g24_layers["genes"],
    g24_layers["development"],
    g24_layers["production"],
):
    assert sha256.fullmatch(layer["rawSha256"])
    assert sha256.fullmatch(layer["normalizedSha256"])
assert g24_layers["development"]["sourcesContentRemoved"] is True
assert g24_layers["production"]["sourcesContentRemoved"] is True
assert g24_layers["compositionDecision"] == {
    "fullCompositionProvenForExactEntryAndModes": True,
    "twoStageFallbackRetainedByCli": True,
    "twoStageFallbackUsedForThisReceipt": False,
    "unmappedVirtualSegmentsNeverGuessed": True,
}

g24_fixture = g24_receipt["fixtureEvidence"]
assert g24_fixture["expectedSource"] == {
    "rootId": "project",
    "path": (
        "packages/gutenberg/test/assets-fixture/src/"
        "sdk033/fixture/EditorPanel.hx"
    ),
    "line": 12,
    "column": 8,
}
assert g24_fixture["indexedFileCount"] == 15
assert sha256.fullmatch(g24_fixture["sourceIndexSha256"])
assert sha256.fullmatch(g24_fixture["artifactSetSha256"])
assert set(g24_fixture["modes"]) == {"development", "production"}
for mode in g24_fixture["modes"].values():
    assert mode["status"] == "mapped-composed"
    assert sha256.fullmatch(mode["stackSha256"])
    assert sha256.fullmatch(mode["traceJsonSha256"])
    assert sha256.fullmatch(mode["traceTextSha256"])
assert g24_fixture["realChromiumFailureRuns"] == 4
assert g24_fixture["browserFailuresReplayStable"] is True
assert g24_fixture["nativeFramesPreserved"] is True
assert g24_fixture["canonicalJsonReplay"] is True

g24_assets = g24_receipt["assetPreservation"]
assert g24_assets["dependencies"] == [
    "react-jsx-runtime",
    "wp-components",
    "wp-element",
    "wp-i18n",
]
assert g24_assets["developmentProductionDependencyParity"] is True
assert g24_assets["officialAssetPhpCopiedUnchanged"] is True
assert g24_assets["translationsPreserved"] is True
assert g24_assets["publicExportPreserved"] is True
for key, value in g24_assets.items():
    if key.endswith("Sha256"):
        assert sha256.fullmatch(value)

g24_packaging = g24_receipt["packaging"]
assert g24_packaging["productionZip"]["entries"] == [
    "wordpresshx-sdk033-assets/build/editor.asset.php",
    "wordpresshx-sdk033-assets/build/editor.js",
    "wordpresshx-sdk033-assets/generation-manifest.json",
    (
        "wordpresshx-sdk033-assets/languages/"
        "wordpresshx-sdk033-en_US-wordpresshx-sdk033-editor.json"
    ),
    "wordpresshx-sdk033-assets/wordpresshx-sdk033-assets.php",
]
assert g24_packaging["debugCompanionZip"]["entries"] == [
    "generated/sdk033/fixture/EditorPanel.tsx",
    "maps/genes-editor-panel.tsx.map",
    "maps/wordpress-scripts-development.js.map",
    "maps/wordpress-scripts-production.js.map",
    "runtime/development/editor.js",
    "source-index.json",
]
for forbidden_g24_retention in (
    "mapsInProduction",
    "sourceIndexInProduction",
    "haxeSourceIncluded",
    "sourceContentIncluded",
    "inlineSourceMapCommentInRuntime",
):
    assert g24_packaging[forbidden_g24_retention] is False
assert g24_packaging["deterministicReplay"] == "passed"
assert sha256.fullmatch(g24_packaging["packageManifestSha256"])
assert sha256.fullmatch(g24_packaging["productionTreeSha256"])
assert sha256.fullmatch(g24_packaging["productionZip"]["sha256"])
assert sha256.fullmatch(g24_packaging["debugCompanionZip"]["sha256"])

g24_negatives = g24_receipt["verification"]["negativeCases"]
assert g24_receipt["verification"]["commands"][0] == (
    "bash packages/gutenberg/scripts/test-assets.sh"
)
assert g24_receipt["verification"]["wordpress70MysqlRuntime"] == (
    "passed-via-sdk-033"
)
assert len(g24_negatives["integrityOrSchemaExit3"]) == 9
assert g24_negatives["ambiguousContractExit4"] == [
    "ambiguous-correlation"
]
assert len(g24_negatives["usageOrInputExit2"]) == 2
assert len(g24_negatives["unmappedWithoutGuessing"]) == 3
assert g24_negatives["packageRejected"] == [
    "secret-shaped-content",
    "machine-path-content",
]
assert g24_receipt["security"]["machinePathLeakCount"] == 0
assert g24_receipt["security"]["secretShapedLeakCount"] == 0
assert g24_receipt["changeDecision"]["genesSourceChanged"] is False
assert g24_receipt["changeDecision"]["genesPullRequest"] is None

g24_hosted = g24_receipt["hostedVerification"]
assert g24_hosted["workflow"] == "repository.yml"
assert g24_hosted["job"] == "wordpress-runtime"
if g24_receipt["status"] == "verified":
    assert sha1.fullmatch(g24_receipt["implementation"]["commit"])
    assert g24_hosted["status"] == "passed"
    assert g24_hosted["commit"] == g24_receipt["implementation"]["commit"]
    assert isinstance(g24_hosted["runId"], int)
    assert isinstance(g24_hosted["jobId"], int)
    assert g24_hosted["jobCount"] == 10
    assert g24_hosted["fullMatrixStatus"] == "passed"
    assert g24_hosted["g24Step"] == "passed"
    assert set(g24_fixture["browserReceiptSha256ByPlatform"]) == {
        "linux/amd64",
        "linux/arm64",
    }
else:
    assert g24_receipt["implementation"]["commit"] is None
    assert g24_hosted["status"] == "pending-main-push"
    assert g24_hosted["commit"] is None
    assert g24_hosted["runId"] is None
    assert g24_hosted["jobId"] is None
    assert g24_hosted["fullMatrixStatus"] == "pending"
    assert g24_hosted["g24Step"] == "pending"
    assert set(g24_fixture["browserReceiptSha256ByPlatform"]) == {
        "linux/arm64"
    }
assert all(
    sha256.fullmatch(value)
    for value in g24_fixture["browserReceiptSha256ByPlatform"].values()
)
assert g24_receipt["failedHostedAttempts"] == [
    {
        "runId": 29651610543,
        "jobId": 88098774931,
        "commit": "9d048df2b05d1ad30bbd6bd06d7efefcd23ebeab",
        "outcome": "failed-before-g2.4-build",
        "reason": (
            "The clean runner checked the exact Genes cache path before the "
            "authenticated project-scoped lix download materialized it; the "
            "preceding WordPress runtime setup and the other nine workflow "
            "jobs passed."
        ),
        "completedAt": "2026-07-18T16:17:12Z",
        "otherJobsPassed": 9,
    }
]
assert g24_receipt["claims"]["generalProductionSupport"] == "not-tested"
assert g24_receipt["claims"]["publicPackagePublication"] == "blocked"
assert g24_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
assert browser_architecture["evidence"]["sourceMaps"] in {
    (
        "sdk-034-esbuild-contract-and-g2.4-exact-wordpress-scripts-entry-"
        "development-production-composition-implemented-hosted-pending"
    ),
    (
        "sdk-034-esbuild-contract-and-g2.4-exact-wordpress-scripts-entry-"
        "development-production-composition-verified"
    ),
}

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
    "wordpresshx-g2.4",
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
assert classic_output["sdkHxxProjection"] == {
    "profileFiles": [
        "packages/gutenberg/profiles/differential-common.hxml",
        "packages/gutenberg/profiles/differential-strict.hxml",
        "packages/gutenberg/profiles/differential-classic.hxml",
    ],
    "compileTimeMarkupOwner": "wordpresshx-sdk-032-browser-hxx",
    "genesIntentContract": "generic-react-jsx-plan",
    "genesInlineMarkupParserEnabled": False,
    "define": "genes.react.no_inline_markup",
    "reason": (
        "the SDK parser has already lowered HXX to typed Genes intent, so a "
        "second source parser would be ambiguous"
    ),
}
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

assert sdk035_receipt["schemaVersion"] == 1
assert sdk035_receipt["receiptId"] == "SDK-035-CLASSIC-GENES-DIFFERENTIAL"
assert sdk035_receipt["bead"] == "wordpresshx-sdk-035"
assert sdk035_receipt["status"] in {"implemented-hosted-pending", "verified"}
assert sdk035_receipt["subject"]["package"] == "packages/gutenberg"
assert sdk035_receipt["subject"]["profileId"] == "wp70-release"
sdk035_subject_files = sdk035_receipt["subject"]["files"]
sdk035_subject_paths = [item["path"] for item in sdk035_subject_files]
assert sdk035_subject_paths == sorted(set(sdk035_subject_paths))
for sdk035_subject_file in sdk035_subject_files:
    sdk035_subject_path = Path(sdk035_subject_file["path"])
    assert sha256.fullmatch(sdk035_subject_file["sha256"])
    assert hashlib.sha256(sdk035_subject_path.read_bytes()).hexdigest() == (
        sdk035_subject_file["sha256"]
    )

assert sdk035_expected["schemaVersion"] == 1
assert sdk035_expected["fixtureId"] == (
    "wordpresshx-sdk035-classic-genes-differential-v1"
)
assert sdk035_expected["profileId"] == sdk035_receipt["subject"]["profileId"]
sdk035_expected_subject = next(
    item
    for item in sdk035_subject_files
    if item["path"] == sdk035_expected_path.as_posix()
)
assert sdk035_expected_subject["sha256"] == hashlib.sha256(
    sdk035_expected_path.read_bytes()
).hexdigest()

sdk035_inputs = sdk035_receipt["immutableInputs"]
sdk035_compiler = sdk035_inputs["compiler"]
for field in ("name", "version", "commit", "tree"):
    assert sdk035_compiler[field] == gutenberg_dependency_lock["compiler"][field]
assert sdk035_compiler["tag"] == gutenberg_dependency_lock["compiler"]["tag"]
assert sdk035_compiler["releaseArtifactSha256"] == (
    gutenberg_dependency_lock["compiler"]["releaseArtifact"]["sha256"]
)
sdk035_dependency_lock_path = Path(
    sdk035_compiler["dependencyLock"]["path"]
)
assert sdk035_dependency_lock_path == gutenberg_dependency_lock_path
assert sdk035_compiler["dependencyLock"]["sha256"] == hashlib.sha256(
    sdk035_dependency_lock_path.read_bytes()
).hexdigest()
assert sdk035_compiler["admissionReceipt"] == sdk031_receipt["receiptId"]

sdk035_hxx = sdk035_inputs["hxx"]
assert sdk035_hxx["version"] == hxx_dependency_lock["parser"]["version"]
assert sdk035_hxx["commit"] == hxx_dependency_lock["parser"]["commit"]
assert sdk035_hxx["tree"] == hxx_dependency_lock["parser"]["tree"]
assert sdk035_hxx["releaseArtifactSha256"] == (
    hxx_dependency_lock["parser"]["artifact"]["sha256"]
)
assert sdk035_hxx["parserReceipt"] == hxx_receipt["receiptId"]
assert sdk035_hxx["browserLoweringReceipt"] == sdk032_receipt["receiptId"]

sdk035_toolchain = sdk035_inputs["toolchain"]
assert sdk035_toolchain["node"]["image"] == image_lock["images"]["node"][
    "reference"
]
assert sdk035_toolchain["node"]["version"] == "22.17.0"
assert sdk035_toolchain["npm"] == "10.9.2"
assert sdk035_toolchain["typescript"] == "5.9.3"
assert sdk035_toolchain["esbuild"] == "0.27.2"
assert sdk035_toolchain["manifest"]["path"] == (
    sdk032_tooling_manifest_path.as_posix()
)
assert sdk035_toolchain["manifest"]["sha256"] == hashlib.sha256(
    sdk032_tooling_manifest_path.read_bytes()
).hexdigest()
assert sdk035_toolchain["lock"]["path"] == sdk032_tooling_lock_path.as_posix()
assert sdk035_toolchain["lock"]["sha256"] == hashlib.sha256(
    sdk032_tooling_lock_path.read_bytes()
).hexdigest()
assert sdk035_toolchain["install"] == (
    "npm ci --ignore-scripts --no-audit --no-fund"
)

sdk035_reference = sdk035_inputs["referenceFixture"]
assert sdk035_reference == sdk035_expected["compilerProvenance"][
    "referenceFixture"
] | {
    "repository": "https://github.com/fullofcaffeine/genes-ts",
    "commit": gutenberg_dependency_lock["compiler"]["commit"],
}
assert sdk035_reference["relationship"] == (
    "concept-reference-only-no-copied-bytes"
)
assert sdk035_reference["buildInput"] is False

sdk035_implementation = sdk035_receipt["implementation"]
assert sdk035_implementation["authoring"] == (
    "one SDK-owned Haxe facade with direct inline HXX return"
)
assert sdk035_implementation["profiles"]["strict"]["primary"] is True
assert sdk035_implementation["profiles"]["classic"]["primary"] is False
assert sdk035_implementation["hxxProjection"] == {
    "parserOwner": "wordpresshx-sdk-032-browser-hxx",
    "loweringTime": "compile-time",
    "genesIntentContract": "generic-react-jsx-plan",
    "genesInlineMarkupParserEnabled": False,
    "shippedHxxRuntime": False,
}
assert sdk035_implementation["retention"]["stableExportId"] == (
    sdk035_expected["exportPlan"]["stableExportId"]
)
assert sdk035_implementation["retention"]["manifestsComparedAcrossProfiles"] is True
assert len(sdk035_implementation["corpus"]) == 6

sdk035_local = sdk035_receipt["localVerification"]
assert sdk035_local["gate"]["command"] == (
    "bash packages/gutenberg/scripts/test-differential.sh"
)
assert sdk035_local["gate"]["outcome"] == "passed"
assert sdk035_local["gate"]["cleanGenesCompileCount"] == 4
assert sdk035_local["gate"]["bundleCount"] == 4
assert sdk035_local["gate"]["isolatedRuntimeProcessCount"] == 4
assert all(
    sdk035_local["gate"][field] is True
    for field in (
        "generatedTreesByteIdentical",
        "strictBundlesByteIdentical",
        "classicBundlesByteIdentical",
        "allRuntimeTranscriptsIdentical",
    )
)
assert sdk035_local["generatedContract"]["exportEntriesEqual"] is True
assert sdk035_local["generatedContract"]["strictExternalConsumer"] == "passed"
assert sdk035_local["generatedContract"]["classicDeclarationConsumer"] == (
    "passed"
)
assert sdk035_local["generatedContract"]["typescriptOptions"] == (
    primary_output["typecheck"]
)
assert sdk035_local["generatedContract"]["authoredPublicAny"] == 0
assert sdk035_local["generatedContract"]["authoredPublicUnknown"] == 0
assert sdk035_local["generatedContract"][
    "unexplainedContractDifferenceCount"
] == sdk035_expected["publicContract"]["unexplainedContractDifferenceCount"] == 0
assert sdk035_local["targetShape"]["allowedDifferences"] == (
    sdk035_expected["targetShape"]["allowedDifferences"]
)
assert sdk035_local["targetShape"][
    "unexplainedSemanticDifferenceCount"
] == sdk035_expected["targetShape"]["unexplainedSemanticDifferenceCount"] == 0
assert sdk035_local["artifacts"] == sdk035_expected["artifacts"] | {
    "machineLocalPathLeaks": 0
}
assert sdk035_local["runtimeTranscript"]["description"] == (
    sdk035_expected["runtimeTranscript"]["description"]
)
assert sdk035_local["runtimeTranscript"]["serverHtmlSha256"] == hashlib.sha256(
    sdk035_expected["runtimeTranscript"]["serverHtml"].encode()
).hexdigest()
assert sdk035_local["runtimeTranscript"]["clientCountBefore"] == (
    sdk035_expected["runtimeTranscript"]["clientBefore"]["count"]
)
assert sdk035_local["runtimeTranscript"]["clientCountAfterClick"] == (
    sdk035_expected["runtimeTranscript"]["clientAfter"]["count"]
)

sdk035_hosted = sdk035_receipt["repositoryHostedVerification"]
assert sdk035_hosted["workflow"] == "Repository bootstrap"
assert sdk035_hosted["job"] == "haxe"
assert sdk035_hosted["step"] == (
    "Test strict and classic Genes React differential"
)
assert sdk035_hosted["required"] is True
if sdk035_receipt["status"] == "implemented-hosted-pending":
    assert sdk035_implementation["implementationCommit"] is None
    assert sdk035_hosted["status"] == "pending-main-push"
    for field in ("commit", "runId", "jobId", "url"):
        assert sdk035_hosted[field] is None
    assert sdk035_hosted["allJobsPassed"] is None
    assert sdk035_hosted["artifactHashesMatched"] is None
    assert browser_architecture["evidence"]["classicDifferential"] == (
        "implemented-by-sdk-035-hosted-verification-pending"
    )
else:
    assert sha1.fullmatch(sdk035_implementation["implementationCommit"])
    assert sdk035_hosted["status"] == "passed"
    assert sdk035_hosted["commit"] == sdk035_implementation[
        "implementationCommit"
    ]
    assert isinstance(sdk035_hosted["runId"], int)
    assert isinstance(sdk035_hosted["jobId"], int)
    assert sdk035_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk035_hosted['runId']}"
    )
    assert sdk035_hosted["jobCount"] == 10
    assert sdk035_hosted["allJobsPassed"] is True
    assert sdk035_hosted["artifactHashesMatched"] is True
    assert browser_architecture["evidence"]["classicDifferential"] == (
        "verified-by-sdk-035-classic-genes-differential"
    )

assert sdk035_receipt["changeDecision"] == {
    "genesSourceChanged": False,
    "genesPullRequest": None,
    "wordpressSpecificGenesBranch": False,
    "siblingGenesBuildInput": False,
    "reason": (
        "released Genes 1.36.3 already preserves the bounded typed HXX "
        "intent, authored contract, SSR, hook state, and click semantics in "
        "both printers"
    ),
}
assert sdk035_receipt["claims"]["sameSourceCorpus"] == (
    "runtime-and-contract-tested"
)
assert sdk035_receipt["claims"]["strictTsxPrimaryLane"] == "unchanged"
assert sdk035_receipt["claims"]["classicGenesDefaultProductionLane"] is False
assert sdk035_receipt["claims"]["universalSameSourceSwitch"] == "not-claimed"
assert sdk035_receipt["claims"]["productionSupport"] == "not-tested"
assert sdk035_receipt["claims"]["publicationAuthorized"] is False
assert sdk035_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]

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
assert sdk033_graph["browserRuntimeImage"] == (
    image_lock["images"]["playwright"]["reference"]
)
assert sdk033_graph["sourceCorrelationReceiptId"] == g24_receipt["receiptId"]
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
assert sdk033_adapter["sourceMapAdaptation"] == {
    "genesMapEmission": "js-source-map",
    "webpackDevtool": "hidden-source-map",
    "officialSourceMapLoaderRetained": True,
    "productionPluginIncludesMaps": False,
    "receiptId": g24_receipt["receiptId"],
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
    assert sha256.fullmatch(
        sdk033_builds[sdk033_lane]["sourceMapSha256"]
    )
    assert re.fullmatch(
        r"[0-9a-f]{20}", sdk033_builds[sdk033_lane]["version"]
    )
assert sdk033_receipt["nativeEmission"]["officialAssetPhpCopiedUnchanged"] is True
assert sdk033_receipt["nativeEmission"]["manualAssetPhpEditingAllowed"] is False
assert sdk033_receipt["nativeEmission"][
    "hiddenSourceMapsExcludedFromPlugin"
] is True
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
    assert sdk033_hosted["status"] == "pending-main-push"
    assert sdk033_hosted["commit"] is None
    assert sdk033_hosted["runId"] is None
    assert sdk033_hosted["url"] is None
    assert sdk033_hosted["attempt"] is None
    assert sdk033_hosted["jobId"] is None
    assert sdk033_hosted["jobUrl"] is None
    assert sdk033_hosted["sdk033Step"] == "pending"
    assert sdk033_hosted["generatedTreeSha256"] is None
    assert sdk033_hosted["productionBundleSha256"] is None
    assert sdk033_hosted["hostedArtifactHashesMatched"] is False
    assert sdk033_hosted["jobCount"] is None
    assert sdk033_hosted["allJobsPassed"] is False
    assert sdk033_hosted["fullMatrixStatus"] == "pending"
    assert sdk033_hosted["completedAt"] is None
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
sdk033_prior_hosted = sdk033_receipt["priorHostedVerification"]
assert sdk033_prior_hosted == {
    "runId": 29640752835,
    "jobId": 88070758398,
    "commit": "23696ca999a419d64181c44018e193c94a5569f3",
    "status": "passed",
    "completedAt": "2026-07-18T10:25:42Z",
}
assert sdk033_receipt["failedHostedAttempts"] == [
    {
        "runId": 29651610543,
        "jobId": 88098774931,
        "commit": "9d048df2b05d1ad30bbd6bd06d7efefcd23ebeab",
        "outcome": "failed-before-sdk-033-build",
        "reason": (
            "The clean runner checked the exact Genes cache path before the "
            "authenticated project-scoped lix download materialized it; the "
            "preceding WordPress runtime setup and the other nine workflow "
            "jobs passed."
        ),
        "completedAt": "2026-07-18T16:17:12Z",
        "otherJobsPassed": 9,
    }
]
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

assert sdk060_receipt["schemaVersion"] == 1
assert sdk060_receipt["receiptId"] == "SDK-060-TYPED-BLOCK-METADATA"
assert sdk060_receipt["bead"] == "wordpresshx-sdk-060"
assert sdk060_receipt["subject"]["package"] == "packages/gutenberg"
for sdk060_subject_name, sdk060_subject in sdk060_receipt["subject"].items():
    if sdk060_subject_name == "package":
        continue
    sdk060_subject_path = Path(sdk060_subject["path"])
    assert hashlib.sha256(sdk060_subject_path.read_bytes()).hexdigest() == (
        sdk060_subject["sha256"]
    )
assert sdk060_profile["schemaVersion"] == 1
assert sdk060_profile["profileId"] == "wp70-release"
assert sdk060_profile["catalogRevision"] == "wp70-release/catalog-v1"
sdk060_profile_source = sdk060_profile["source"]
assert sdk060_profile_source["repository"] == (
    lock["entries"]["wp70-release"]["embeddedGutenberg"]["repository"]
)
assert sdk060_profile_source["commit"] == (
    lock["entries"]["wp70-release"]["embeddedGutenberg"]["commit"]
)
assert sdk060_profile_source["tree"] == (
    lock["entries"]["wp70-release"]["embeddedGutenberg"]["tree"]
)
assert sdk060_profile_source["path"] == "schemas/json/block.json"
assert sdk060_profile_source["blob"] == (
    "246cb4ed9d2e07da32c80c24d1201c72a420cb54"
)
assert sdk060_profile_source["sha256"] == (
    "f1709bcc9bde24e0a40d58dc3134ea0e917b07032b47f988b73e941200f3ab9d"
)
assert sdk060_profile_source["schemaUrl"] == (
    "https://schemas.wp.org/trunk/block.json"
)
assert sdk060_profile["policy"] == {
    "apiVersion": 3,
    "additionalProperties": False,
    "experimentalMetadata": False,
    "scriptModules": False,
    "manualBlockJsonEditing": False,
}
assert sdk060_profile["allowedMetadataKeys"] == sorted(
    set(sdk060_profile["allowedMetadataKeys"])
)
assert sdk060_profile["allowedSupportsKeys"] == sorted(
    set(sdk060_profile["allowedSupportsKeys"])
)
assert {entry["key"]: entry["kind"] for entry in sdk060_profile["assetKeys"]} == {
    "editorScript": "script",
    "script": "script",
    "viewScript": "script",
    "editorStyle": "style",
    "style": "style",
    "viewStyle": "style",
    "render": "render",
}
assert {entry["key"] for entry in sdk060_profile["forbiddenMetadataKeys"]} == {
    "__experimental",
    "viewScriptModule",
    "futureOnly",
}
assert len(sdk060_profile["allowedHandles"]) == len(
    {entry["reference"] for entry in sdk060_profile["allowedHandles"]}
)
assert sdk060_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
sdk060_provider = sdk060_receipt["provider"]
assert sdk060_provider["profileId"] == sdk060_profile["profileId"]
assert sdk060_provider["catalogRevision"] == sdk060_profile["catalogRevision"]
assert sdk060_provider["wordpressVersion"] == (
    lock["entries"]["wp70-release"]["wordpressSource"]["tag"]
)
assert sdk060_provider["wordpressCommit"] == (
    lock["entries"]["wp70-release"]["wordpressSource"]["commit"]
)
assert sdk060_provider["gutenbergCommit"] == sdk060_profile_source["commit"]
assert sdk060_provider["gutenbergTree"] == sdk060_profile_source["tree"]
assert sdk060_provider["blockSchemaPath"] == sdk060_profile_source["path"]
assert sdk060_provider["blockSchemaBlob"] == sdk060_profile_source["blob"]
assert sdk060_provider["blockSchemaSha256"] == sdk060_profile_source["sha256"]
assert sdk060_provider["apiVersion"] == sdk060_profile["policy"]["apiVersion"]
assert sdk060_provider["additionalProperties"] is False
assert sdk060_provider["scriptModules"] is False
assert sdk060_provider["experimentalMetadata"] is False
assert sdk060_receipt["toolchain"]["haxe"] == "4.3.7"
assert sdk060_receipt["toolchain"]["formatter"] == "1.18.0"
assert sdk060_receipt["toolchain"]["wordpressImage"] == image_lock["images"][
    "wordpress70Php84"
]["reference"]
assert sdk060_receipt["toolchain"]["mysqlImage"] == image_lock["images"][
    "mysql"
]["reference"]
sdk060_implementation = sdk060_receipt["implementation"]
assert sdk060_implementation["authoringSurface"] == "haxe"
assert sdk060_implementation["metadataProjection"] == (
    "normal deterministic block.json"
)
assert sdk060_implementation["serverRegistrationApi"] == "register_block_type"
assert sdk060_implementation["clientRegistrationApi"] == "registerBlockType"
assert sdk060_implementation["manualBlockJsonEditingAllowed"] is False
assert sdk060_implementation["companionApplicationPhpAuthored"] is False
assert sdk060_implementation[
    "companionApplicationJavaScriptOrTypeScriptAuthored"
] is False
assert sdk060_implementation["independentOracleLanguage"] == (
    "native PHP external consumer"
)
assert sdk060_implementation["productPhpCompilerOwner"] == (
    "compiler/reflaxe.php via SDK-062"
)
sdk060_compilation = sdk060_receipt["compilation"]
assert sdk060_compilation["blockCount"] == 2
assert sdk060_compilation["staticBlockCount"] == 1
assert sdk060_compilation["dynamicBlockCount"] == 1
assert sdk060_compilation["ownedAssetCount"] == 5
assert sdk060_compilation["fileReferenceCount"] == 4
assert sdk060_compilation["profileHandleReferenceCount"] == 1
assert sdk060_compilation["generatedFileCountIncludingOwnedFixtures"] == 9
assert sdk060_compilation["expectedOutputPinned"] is True
assert sdk060_compilation["secondCompileMatched"] is True
assert sdk060_compilation["publicWeakTypes"] == []
assert sdk060_compilation["forbiddenHaxeWeakConstructs"] == []
for sdk060_hash_name in (
    "generatedTreeSha256",
    "generationManifestSha256",
    "staticBlockJsonSha256",
    "dynamicBlockJsonSha256",
    "staticRegistrationPlanSha256",
    "dynamicRegistrationPlanSha256",
):
    assert sha256.fullmatch(sdk060_compilation[sdk060_hash_name])
sdk060_diagnostics = sdk060_receipt["negativeDiagnostics"]
assert set(sdk060_diagnostics["compileTime"]) == {
    "WPX6012",
    "WPX6014",
    "WPX6018",
    "WPX6020",
    "WPX6021",
    "WPX6025",
    "WPX6027",
    "WPX6029",
    "WPX6030",
}
assert sdk060_diagnostics["negativeCompileFixtureCount"] == 9
assert sdk060_diagnostics["independentMutationCount"] == 8
assert len(sdk060_diagnostics["mutations"]) == 8
assert sdk060_diagnostics["originalSourcePaths"] is True
sdk060_local = sdk060_receipt["localVerification"]
assert sdk060_local["deterministicCompilerAndVerifier"] == "passed"
assert sdk060_local["phpOracleSyntax"] == "passed"
assert sdk060_local["forbiddenHaxeWeakConstructs"] == "none"
assert sdk060_receipt["changeDecision"]["genesSourceChanged"] is False
assert sdk060_receipt["changeDecision"]["genesPullRequest"] is None
assert sdk060_receipt["changeDecision"]["reflaxePhpSourceChanged"] is False
assert sdk060_receipt["claims"]["typedAttributeDerivation"] == (
    "compile-tested"
)
assert sdk060_receipt["claims"]["profileSpecificMetadata"] == (
    "compile-and-mutation-tested"
)
assert sdk060_receipt["claims"]["deterministicNativeBlockJson"] == (
    "replay-tested"
)
assert sdk060_receipt["claims"]["realBrowserBlockRegistration"] == (
    "not-tested-owned-by-sdk-061"
)
assert sdk060_receipt["claims"]["haxeGeneratedDynamicRenderPhp"] == (
    "not-tested-owned-by-sdk-062"
)
assert sdk060_receipt["claims"]["productionSupport"] == "not-tested"
assert len(sdk060_receipt["knownLimitations"]) >= 5
assert any(
    "independent test consumer" in limitation
    for limitation in sdk060_receipt["knownLimitations"]
)
assert "Prove typed block metadata on WordPress 7.0" in workflow_text
assert "Test typed profile-specific block.json generation" in workflow_text
assert "bash packages/gutenberg/scripts/test-block-metadata.sh" in workflow_text
assert (
    "bash packages/gutenberg/scripts/test-block-metadata.sh --skip-wordpress"
    in workflow_text
)
sdk060_runtime = sdk060_receipt["realWordPressRuntime"]
assert sdk060_runtime["check"] == (
    "wordpresshx-sdk060-real-wordpress-registration-v1"
)
assert sdk060_runtime["wordpressVersion"] == "7.0"
assert sdk060_runtime["profileId"] == "wp70-release"
assert sdk060_runtime["wordpressImage"] == image_lock["images"][
    "wordpress70Php84"
]["reference"]
assert sdk060_runtime["databaseImage"] == image_lock["images"]["mysql"][
    "reference"
]
sdk060_hosted = sdk060_receipt["repositoryHostedVerification"]
assert sdk060_hosted["workflow"] == "Repository bootstrap"
assert sdk060_hosted["required"] is True
assert sdk060_hosted["haxeJob"] == "haxe"
assert sdk060_hosted["haxeStep"] == (
    "Test typed profile-specific block.json generation"
)
assert sdk060_hosted["wordpressJob"] == "wordpress-runtime"
assert sdk060_hosted["wordpressStep"] == (
    "Prove typed block metadata on WordPress 7.0"
)
if sdk060_receipt["status"] == "implemented-hosted-pending":
    assert sdk060_implementation["commit"] is None
    assert sdk060_runtime["outcome"] == "pending-hosted-clean-runner"
    assert sdk060_runtime["registeredBlocks"] is None
    assert sdk060_runtime["dynamicRendered"] is None
    assert sdk060_receipt["claims"]["realWordPressMetadataRegistration"] == (
        "hosted-pending"
    )
    assert sdk060_local["realWordPressRuntime"] == (
        "pending-hosted-clean-runner"
    )
    assert sdk060_hosted["status"] == "pending-main-push"
    for sdk060_pending_name in (
        "commit",
        "runId",
        "url",
        "haxeJobId",
        "wordpressJobId",
        "jobCount",
        "allJobsPassed",
        "artifactHashesMatched",
        "completedAt",
    ):
        assert sdk060_hosted[sdk060_pending_name] is None
else:
    assert sdk060_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk060_implementation["commit"])
    assert sdk060_hosted["commit"] == sdk060_implementation["commit"]
    assert isinstance(sdk060_hosted["runId"], int)
    assert isinstance(sdk060_hosted["haxeJobId"], int)
    assert isinstance(sdk060_hosted["wordpressJobId"], int)
    assert sdk060_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk060_hosted['runId']}"
    )
    assert sdk060_hosted["status"] == "passed"
    assert sdk060_hosted["jobCount"] == 13
    assert sdk060_hosted["allJobsPassed"] is True
    assert sdk060_hosted["artifactHashesMatched"] is True
    assert sdk060_hosted["completedAt"] == sdk060_receipt["observedAt"]
    assert sdk060_runtime["outcome"] == "passed"
    assert sdk060_runtime["registeredBlocks"] == [
        "wordpresshx/book-grid",
        "wordpresshx/callout",
    ]
    assert sdk060_runtime["dynamicRendered"] is True
    assert sdk060_receipt["claims"]["realWordPressMetadataRegistration"] == (
        "real-wordpress-tested"
    )
    assert sdk060_local["realWordPressRuntime"] == (
        "passed-hosted-clean-runner"
    )

assert sdk061_receipt["schemaVersion"] == 1
assert sdk061_receipt["receiptId"] == "SDK-061-STATIC-BLOCK"
assert sdk061_receipt["bead"] == "wordpresshx-sdk-061"
assert sdk061_receipt["subject"]["package"] == "packages/gutenberg"
for sdk061_subject_name, sdk061_subject in sdk061_receipt["subject"].items():
    if sdk061_subject_name == "package":
        continue
    sdk061_subject_path = Path(sdk061_subject["path"])
    assert hashlib.sha256(sdk061_subject_path.read_bytes()).hexdigest() == (
        sdk061_subject["sha256"]
    )
assert sdk061_profile["schemaVersion"] == 1
assert sdk061_profile["profileId"] == "wp70-release"
assert sdk061_profile["catalogId"] == "static-block"
assert sdk061_profile["catalogRevision"] == "wp70-release/static-block-v1"
assert sdk061_profile["requiresBaseCatalogRevision"] == lock["entries"][
    "wp70-release"
]["catalogRevision"]
sdk061_provider = sdk061_receipt["provider"]
assert sdk061_provider["profileId"] == sdk061_profile["profileId"]
assert sdk061_provider["baseCatalogRevision"] == sdk061_profile[
    "requiresBaseCatalogRevision"
]
assert sdk061_provider["staticBlockCatalogRevision"] == sdk061_profile[
    "catalogRevision"
]
assert sdk061_provider["wordpressVersion"] == sdk061_profile["provider"][
    "wordpressVersion"
]
assert sdk061_provider["wordpressCommit"] == lock["entries"][
    "wp70-release"
]["wordpressSource"]["commit"]
assert sdk061_provider["gutenbergCommit"] == lock["entries"][
    "wp70-release"
]["embeddedGutenberg"]["commit"]
assert sdk061_provider["gutenbergTree"] == lock["entries"][
    "wp70-release"
]["embeddedGutenberg"]["tree"]
assert sdk061_provider["sourceVerifiedCapabilityCount"] == len(
    sdk061_profile["admittedCapabilities"]
)
assert sdk061_provider["privateApisAllowed"] is False
assert sdk061_provider["experimentalApisAllowed"] is False
assert all(
    capability["classification"] == "public"
    and capability["evidenceStatus"] == "source-verified"
    for capability in sdk061_profile["admittedCapabilities"]
)
assert sdk061_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
sdk061_tooling_manifest = json.loads(
    sdk063_tooling_manifest_path.read_text(encoding="utf-8")
)
sdk061_tooling_lock = json.loads(
    sdk063_tooling_lock_path.read_text(encoding="utf-8")
)
assert sdk061_provider["exactWordPressNpmPackages"] == [
    "@wordpress/block-editor@15.13.0",
    "@wordpress/blocks@15.13.0",
]
for sdk061_package in sdk061_profile["packages"]:
    sdk061_request = sdk061_package["request"]
    sdk061_version = sdk061_package["version"]
    assert sdk061_tooling_manifest["overrides"][sdk061_request] == (
        sdk061_version
    )
    assert sdk061_tooling_lock["packages"][
        f"node_modules/{sdk061_request}"
    ]["version"] == sdk061_version
assert sdk061_receipt["toolchain"]["haxe"] == "4.3.7"
assert sdk061_receipt["toolchain"]["nodeImage"] == image_lock["images"][
    "node"
]["reference"]
assert sdk061_receipt["toolchain"]["playwrightImage"] == image_lock[
    "images"
]["playwright"]["reference"]
assert sdk061_receipt["toolchain"]["wordpressImage"] == image_lock[
    "images"
]["wordpress70Php84"]["reference"]
assert sdk061_receipt["toolchain"]["mysqlImage"] == image_lock["images"][
    "mysql"
]["reference"]
sdk061_implementation = sdk061_receipt["implementation"]
assert sdk061_implementation["authoringSurface"] == "haxe-hxx"
assert sdk061_implementation["missingAttributes"] == "explicit-default"
assert sdk061_implementation["nullAttributes"] == "not-admitted"
assert sdk061_implementation[
    "companionApplicationJavaScriptOrTypeScriptAuthored"
] is False
assert sdk061_implementation["shippedBrowserHxxRuntime"] is False
assert sdk061_implementation["wordpressSpecificGenesBranch"] is False
sdk061_compilation = sdk061_receipt["compilation"]
assert sdk061_compilation["blockName"] == "wordpresshx/callout"
for sdk061_hash_name in (
    "generatedTreeSha256",
    "browserPlanSha256",
    "blockMetadataSha256",
    "pluginTreeSha256",
    "developmentBundleSha256",
    "productionBundleSha256",
):
    assert sha256.fullmatch(sdk061_compilation[sdk061_hash_name])
assert re.fullmatch(
    r"[0-9a-f]{20}", sdk061_compilation["productionVersion"]
)
assert sdk061_compilation["dependencies"] == [
    "react-jsx-runtime",
    "wp-block-editor",
    "wp-blocks",
]
assert sdk061_compilation["deprecationVersions"] == ["0.9.0"]
assert sdk061_compilation["publicWeakTypes"] == []
assert sdk061_compilation["forbiddenHaxeWeakConstructs"] == []
assert sdk061_compilation["generatedAndBundleMachinePathLeaks"] == 0
assert sdk061_compilation["secondCompileMatched"] is True
assert sdk061_compilation["developmentAndProductionReplayMatched"] is True
assert sdk061_compilation["generatedPluginReplayMatched"] is True
sdk061_expected = json.loads(
    Path("packages/gutenberg/test/expected/static-block.json").read_text(
        encoding="utf-8"
    )
)
sdk061_serialization = sdk061_receipt["nativeSerialization"]
assert sdk061_serialization["check"] == (
    "wordpresshx-sdk061-native-gutenberg-serialization-v1"
)
assert sdk061_serialization["currentBytes"] == sdk061_expected[
    "serialization"
]["currentBytes"]
assert sdk061_serialization["defaultBytes"] == sdk061_expected[
    "serialization"
]["defaultBytes"]
assert sdk061_serialization["legacyBytes"] == sdk061_expected[
    "serialization"
]["legacyBytes"]
assert sdk061_serialization["migratedBytes"] == sdk061_expected[
    "serialization"
]["migratedBytes"]
assert sdk061_serialization["currentValid"] is True
assert sdk061_serialization["legacyValidAndMigrated"] is True
assert sdk061_serialization["replayByteExact"] is True
assert sdk061_serialization["outcome"] == "passed"
sdk061_diagnostics = sdk061_receipt["negativeDiagnostics"]
assert set(sdk061_diagnostics) == {
    "WPX6101",
    "WPX6103",
    "WPX6105",
    "WPX6112",
    "WPX6114",
    "WPX6116",
    "negativeCompileFixtureCount",
    "originalSourcePaths",
}
assert sdk061_diagnostics["negativeCompileFixtureCount"] == 6
assert sdk061_diagnostics["originalSourcePaths"] is True
sdk061_local = sdk061_receipt["localVerification"]
assert sdk061_local["deterministicCompilerAndVerifier"] == "passed"
assert sdk061_local["nativeParserSerializer"] == "passed"
assert sdk061_local["strictTypeScript"] == "passed"
assert sdk061_local["phpOracleSyntax"] == "passed"
assert sdk061_local["forbiddenHaxeWeakConstructs"] == "none"
assert sdk061_receipt["changeDecision"]["genesSourceChanged"] is False
assert sdk061_receipt["changeDecision"]["genesPullRequest"] is None
assert sdk061_receipt["changeDecision"]["siblingGenesBuildInput"] is False
assert sdk061_receipt["changeDecision"]["reflaxePhpSourceChanged"] is False
assert sdk061_receipt["claims"]["dynamicBlockRendering"] == (
    "not-tested-owned-by-sdk-062"
)
assert sdk061_receipt["claims"]["richerBlockFeatures"] == (
    "not-tested-owned-by-sdk-065"
)
assert sdk061_receipt["claims"]["productionSupport"] == "not-tested"
assert len(sdk061_receipt["knownLimitations"]) >= 4
assert "Prove typed static block serialization and migration on WordPress 7.0" in workflow_text
assert "Test typed static block generation and native serialization" in workflow_text
assert "bash packages/gutenberg/scripts/test-static-block.sh" in workflow_text
assert (
    "bash packages/gutenberg/scripts/test-static-block.sh --skip-wordpress"
    in workflow_text
)
sdk061_runtime = sdk061_receipt["realWordPressRuntime"]
sdk061_hosted = sdk061_receipt["repositoryHostedVerification"]
assert sdk061_runtime["check"] == "wordpresshx-sdk061-real-static-block-v1"
assert sdk061_runtime["wordpressVersion"] == "7.0"
assert sdk061_hosted["workflow"] == "Repository bootstrap"
assert sdk061_hosted["required"] is True
assert sdk061_hosted["haxeJob"] == "haxe"
assert sdk061_hosted["haxeStep"] == (
    "Test typed static block generation and native serialization"
)
assert sdk061_hosted["wordpressJob"] == "wordpress-runtime"
assert sdk061_hosted["wordpressStep"] == (
    "Prove typed static block serialization and migration on WordPress 7.0"
)
if sdk061_receipt["status"] == "implemented-hosted-pending":
    assert sdk061_implementation["commit"] is None
    assert sdk061_runtime["outcome"] == "pending-hosted-clean-runner"
    for sdk061_runtime_pending in (
        "pluginActivated",
        "insertEditSaveReload",
        "undoRedo",
        "currentFrontend",
        "legacyMigrated",
        "migrationFrontend",
        "recoveryWarnings",
        "consoleErrors",
        "pageErrors",
    ):
        assert sdk061_runtime[sdk061_runtime_pending] is None
    assert sdk061_local["realWordPressRuntime"] == (
        "pending-hosted-clean-runner"
    )
    assert sdk061_hosted["status"] == "pending-main-push"
    for sdk061_hosted_pending in (
        "commit",
        "runId",
        "url",
        "haxeJobId",
        "wordpressJobId",
        "jobCount",
        "allJobsPassed",
        "artifactHashesMatched",
        "completedAt",
    ):
        assert sdk061_hosted[sdk061_hosted_pending] is None
    assert sdk061_receipt["claims"][
        "realWordPressInsertEditSaveReload"
    ] == "hosted-pending"
    assert sdk061_receipt["claims"]["realWordPressFrontend"] == (
        "hosted-pending"
    )
    assert sdk061_receipt["claims"]["noValidationRecoveryPrompt"] == (
        "hosted-pending"
    )
else:
    assert sdk061_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk061_implementation["commit"])
    assert sdk061_runtime["outcome"] == "passed"
    for sdk061_runtime_true in (
        "pluginActivated",
        "insertEditSaveReload",
        "undoRedo",
        "currentFrontend",
        "legacyMigrated",
        "migrationFrontend",
    ):
        assert sdk061_runtime[sdk061_runtime_true] is True
    assert sdk061_runtime["recoveryWarnings"] == 0
    assert sdk061_runtime["consoleErrors"] == 0
    assert sdk061_runtime["pageErrors"] == 0
    assert sdk061_local["realWordPressRuntime"] == (
        "passed-hosted-clean-runner"
    )
    assert sdk061_hosted["commit"] == sdk061_implementation["commit"]
    assert isinstance(sdk061_hosted["runId"], int)
    assert isinstance(sdk061_hosted["haxeJobId"], int)
    assert isinstance(sdk061_hosted["wordpressJobId"], int)
    assert sdk061_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk061_hosted['runId']}"
    )
    assert sdk061_hosted["status"] == "passed"
    assert sdk061_hosted["jobCount"] == 13
    assert sdk061_hosted["allJobsPassed"] is True
    assert sdk061_hosted["artifactHashesMatched"] is True
    assert sdk061_hosted["completedAt"] == sdk061_receipt["observedAt"]
    assert sdk061_receipt["claims"][
        "realWordPressInsertEditSaveReload"
    ] == "real-wordpress-tested"
    assert sdk061_receipt["claims"]["realWordPressFrontend"] == (
        "real-wordpress-tested"
    )
    assert sdk061_receipt["claims"]["noValidationRecoveryPrompt"] == (
        "real-wordpress-tested"
    )

assert sdk063_receipt["schemaVersion"] == 1
assert sdk063_receipt["receiptId"] == "SDK-063-EDITOR-PLUGIN-SLOTFILL"
assert sdk063_receipt["bead"] == "wordpresshx-sdk-063"
assert sdk063_receipt["subject"]["package"] == "packages/gutenberg"
for sdk063_subject_name, sdk063_subject in sdk063_receipt["subject"].items():
    if sdk063_subject_name == "package":
        continue
    sdk063_subject_path = Path(sdk063_subject["path"])
    assert hashlib.sha256(sdk063_subject_path.read_bytes()).hexdigest() == (
        sdk063_subject["sha256"]
    )
assert sdk063_profile["schemaVersion"] == 1
assert sdk063_profile["profileId"] == "wp70-release"
assert sdk063_profile["catalogId"] == "editor-plugin"
assert sdk063_profile["catalogRevision"] == "wp70-release/editor-plugin-v1"
assert sdk063_profile["requiresBaseCatalogRevision"] == lock["entries"][
    "wp70-release"
]["catalogRevision"]
assert sdk063_receipt["provider"]["profileId"] == sdk063_profile["profileId"]
assert sdk063_receipt["provider"]["baseCatalogRevision"] == (
    sdk063_profile["requiresBaseCatalogRevision"]
)
assert sdk063_receipt["provider"]["editorCatalogRevision"] == (
    sdk063_profile["catalogRevision"]
)
assert sdk063_receipt["provider"]["wordpressCommit"] == lock["entries"][
    "wp70-release"
]["wordpressSource"]["commit"]
assert sdk063_receipt["provider"]["gutenbergCommit"] == lock["entries"][
    "wp70-release"
]["embeddedGutenberg"]["commit"]
assert sdk063_receipt["provider"]["gutenbergTree"] == lock["entries"][
    "wp70-release"
]["embeddedGutenberg"]["tree"]
assert sdk063_receipt["provider"]["overlayComponentCount"] == len(
    sdk063_profile["components"]
)
assert sdk063_receipt["provider"]["sourceVerifiedCapabilityCount"] == len(
    sdk063_profile["admittedCapabilities"]
)
assert sdk063_receipt["provider"]["baseCatalogBytesChanged"] is False
assert sdk063_profile["policy"]["privateApisAllowed"] is False
assert sdk063_profile["policy"]["experimentalApisAllowed"] is False
assert sdk063_profile["policy"]["manualRegistrationJavaScriptAllowed"] is False
assert all(
    capability["classification"] == "public"
    and capability["evidenceStatus"] == "source-verified"
    for capability in sdk063_profile["admittedCapabilities"]
)
sdk063_graph = next(
    graph
    for graph in toolchain_lock["dependencyGraphs"]["npm"]["externalGraphs"]
    if graph["id"] == "sdk-063-editor-plugin-verification-graph"
)
assert sdk063_graph["receiptId"] == sdk063_receipt["receiptId"]
assert sdk063_graph["profilePath"] == sdk063_profile_path.as_posix()
assert sdk063_graph["profileSha256"] == hashlib.sha256(
    sdk063_profile_path.read_bytes()
).hexdigest()
assert sdk063_graph["manifestPath"] == sdk063_tooling_manifest_path.as_posix()
assert sdk063_graph["manifestSha256"] == hashlib.sha256(
    sdk063_tooling_manifest_path.read_bytes()
).hexdigest()
assert sdk063_graph["lockPath"] == sdk063_tooling_lock_path.as_posix()
assert sdk063_graph["lockSha256"] == hashlib.sha256(
    sdk063_tooling_lock_path.read_bytes()
).hexdigest()
sdk063_tooling_manifest = json.loads(
    sdk063_tooling_manifest_path.read_text(encoding="utf-8")
)
sdk063_tooling_lock = json.loads(
    sdk063_tooling_lock_path.read_text(encoding="utf-8")
)
assert set(sdk063_graph["directPackages"]) == {
    f"{name}@{version}"
    for name, version in sdk063_tooling_manifest["devDependencies"].items()
}
assert sdk063_graph["lifecycleScriptsAllowed"] is False
assert sdk063_graph["runtimeImage"] == image_lock["images"]["node"]["reference"]
assert sdk063_graph["browserRuntimeImage"] == image_lock["images"][
    "playwright"
]["reference"]
assert sdk063_graph["wordpressRuntimeImage"] == image_lock["images"][
    "wordpress70Php84"
]["reference"]
assert sdk063_receipt["toolchain"]["npmLockedPackageCount"] == (
    len(sdk063_tooling_lock["packages"]) - 1
)
assert sdk063_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
assert sdk063_receipt["implementation"]["authoringSurface"] == "haxe-hxx"
assert sdk063_receipt["implementation"][
    "companionApplicationJavaScriptOrTypeScriptAuthored"
] is False
assert sdk063_receipt["implementation"]["shippedBrowserHxxRuntime"] is False
assert sdk063_receipt["implementation"]["wordpressSpecificGenesBranch"] is False
assert sdk063_receipt["compilation"]["publicWeakTypes"] == []
assert sdk063_receipt["compilation"]["forbiddenHaxeWeakConstructs"] == []
assert sdk063_receipt["compilation"]["secondCompileMatched"] is True
assert sdk063_receipt["compilation"][
    "developmentAndProductionReplayMatched"
] is True
assert sdk063_receipt["compilation"]["generatedPluginReplayMatched"] is True
assert sdk063_receipt["compilation"]["php74Syntax"] == "passed"
assert sdk063_receipt["compilation"]["php84Syntax"] == "passed"
assert sdk063_receipt["realWordPressRuntime"]["outcome"] == "passed"
assert sdk063_receipt["realWordPressRuntime"]["keyboardMenuOpen"] is True
assert sdk063_receipt["realWordPressRuntime"]["focusEnteredSidebar"] is True
assert sdk063_receipt["realWordPressRuntime"]["keyboardToggle"] is True
assert sdk063_receipt["realWordPressRuntime"]["mousePriority"] is True
assert sdk063_receipt["realWordPressRuntime"]["postTypeNegative"] == (
    "page editor has no extension menu item"
)
assert sdk063_receipt["realWordPressRuntime"]["consoleErrors"] == 0
assert sdk063_receipt["realWordPressRuntime"]["pageErrors"] == 0
assert sdk063_receipt["realWordPressRuntime"]["accessibility"][
    "seriousOrCriticalViolations"
] == 0
assert sdk063_receipt["changeDecision"]["genesSourceChanged"] is False
assert sdk063_receipt["changeDecision"]["genesPullRequest"] is None
assert sdk063_receipt["changeDecision"]["siblingGenesBuildInput"] is False
assert sdk063_receipt["claims"]["typedEditorPluginRegistration"] == (
    "compile-and-runtime-tested"
)
assert sdk063_receipt["claims"]["completeEditorExtensionSurface"] == (
    "not-claimed"
)
assert sdk063_receipt["claims"]["productionSupport"] == "not-tested"
assert "Prove the typed editor plugin and SlotFill on WordPress 7.0" in workflow_text
assert "bash packages/gutenberg/scripts/test-editor-plugin.sh" in workflow_text
sdk063_hosted = sdk063_receipt["repositoryHostedVerification"]
assert sdk063_hosted["workflow"] == "Repository bootstrap"
assert sdk063_hosted["job"] == "wordpress-runtime"
assert sdk063_hosted["step"] == (
    "Prove the typed editor plugin and SlotFill on WordPress 7.0"
)
assert sdk063_hosted["required"] is True
if sdk063_receipt["status"] == "implemented-hosted-pending":
    assert sdk063_receipt["implementation"].get("commit") is None
    assert sdk063_hosted["status"] == "pending-main-push"
    assert sdk063_hosted["commit"] is None
    assert sdk063_hosted["runId"] is None
    assert sdk063_hosted["jobId"] is None
    assert sdk063_hosted["url"] is None
    assert sdk063_hosted["allJobsPassed"] is None
    assert sdk063_hosted["artifactHashesMatched"] is None
else:
    assert sdk063_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk063_receipt["implementation"]["commit"])
    assert sdk063_hosted["commit"] == sdk063_receipt["implementation"]["commit"]
    assert isinstance(sdk063_hosted["runId"], int)
    assert isinstance(sdk063_hosted["jobId"], int)
    assert sdk063_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk063_hosted['runId']}"
    )
    assert sdk063_hosted["jobUrl"] == (
        sdk063_hosted["url"] + f"/job/{sdk063_hosted['jobId']}"
    )
    assert sdk063_hosted["status"] == "passed"
    assert sdk063_hosted["jobCount"] == 13
    assert sdk063_hosted["generatedTreeSha256"] == sdk063_receipt[
        "compilation"
    ]["generatedTreeSha256"]
    assert sdk063_hosted["productionBundleSha256"] == sdk063_receipt[
        "compilation"
    ]["productionBundleSha256"]
    assert sdk063_hosted["allJobsPassed"] is True
    assert sdk063_hosted["artifactHashesMatched"] is True
    assert sdk063_hosted["completedAt"] == sdk063_receipt["observedAt"]

assert sdk064_receipt["schemaVersion"] == 1
assert sdk064_receipt["receiptId"] == "SDK-064-TYPED-DATA-STORE"
assert sdk064_receipt["bead"] == "wordpresshx-sdk-064"
assert sdk064_receipt["subject"]["package"] == "packages/gutenberg"
for sdk064_subject_name, sdk064_subject in sdk064_receipt["subject"].items():
    if sdk064_subject_name == "package":
        continue
    sdk064_subject_path = Path(sdk064_subject["path"])
    assert hashlib.sha256(sdk064_subject_path.read_bytes()).hexdigest() == (
        sdk064_subject["sha256"]
    )
assert sdk064_profile["schemaVersion"] == 1
assert sdk064_profile["profileId"] == "wp70-release"
assert sdk064_profile["catalogId"] == "data-store"
assert sdk064_profile["catalogRevision"] == "wp70-release/data-store-v1"
assert sdk064_profile["requiresBaseCatalogRevision"] == lock["entries"][
    "wp70-release"
]["catalogRevision"]
sdk064_component_source = sdk064_profile["componentCatalogSource"]
assert sdk064_component_source["catalogId"] == sdk063_profile["catalogId"]
assert sdk064_component_source["catalogRevision"] == sdk063_profile[
    "catalogRevision"
]
assert sdk064_component_source["path"] == sdk063_profile_path.as_posix()
assert sdk064_component_source["sha256"] == hashlib.sha256(
    sdk063_profile_path.read_bytes()
).hexdigest()
assert sdk064_receipt["provider"]["profileId"] == sdk064_profile["profileId"]
assert sdk064_receipt["provider"]["baseCatalogRevision"] == (
    sdk064_profile["requiresBaseCatalogRevision"]
)
assert sdk064_receipt["provider"]["editorCatalogRevision"] == (
    sdk064_component_source["catalogRevision"]
)
assert sdk064_receipt["provider"]["dataCatalogRevision"] == sdk064_profile[
    "catalogRevision"
]
assert sdk064_receipt["provider"]["wordpressVersion"] == sdk064_profile[
    "provider"
]["wordpressVersion"]
assert sdk064_receipt["provider"]["wordpressCommit"] == lock["entries"][
    "wp70-release"
]["wordpressSource"]["commit"]
assert sdk064_receipt["provider"]["gutenbergCommit"] == lock["entries"][
    "wp70-release"
]["embeddedGutenberg"]["commit"]
assert sdk064_receipt["provider"]["gutenbergTree"] == lock["entries"][
    "wp70-release"
]["embeddedGutenberg"]["tree"]
sdk064_api_exports = sdk064_profile["apis"][0]["exports"]
assert sdk064_receipt["provider"]["publicDataApiCount"] == len(
    sdk064_api_exports
)
assert sdk064_receipt["provider"]["sourceVerifiedCapabilityCount"] == len(
    sdk064_profile["admittedCapabilities"]
)
assert sdk064_receipt["provider"]["exactWordPressNpmPackageCount"] == 1
assert sdk064_receipt["provider"]["editorComponentCatalogReused"] is True
assert sdk064_receipt["provider"]["privateApisAllowed"] is False
assert sdk064_receipt["provider"]["experimentalApisAllowed"] is False
assert sdk064_receipt["provider"]["legacyStringStoreAccessAllowed"] is False
assert sdk064_profile["package"]["request"] == "@wordpress/data"
assert sdk064_profile["package"]["version"] == "10.40.0"
assert sdk064_profile["package"]["wordpressHandle"] == "wp-data"
assert sdk064_profile["policy"]["privateApisAllowed"] is False
assert sdk064_profile["policy"]["experimentalApisAllowed"] is False
assert sdk064_profile["policy"]["legacyStringStoreAccessAllowed"] is False
assert sdk064_profile["policy"]["manualRegistrationJavaScriptAllowed"] is False
assert all(
    capability["classification"] == "public"
    and capability["evidenceStatus"] == "source-verified"
    for capability in sdk064_profile["admittedCapabilities"]
)
sdk064_graph = next(
    graph
    for graph in toolchain_lock["dependencyGraphs"]["npm"]["externalGraphs"]
    if graph["id"] == "sdk-064-data-store-verification-graph"
)
assert sdk064_graph["authority"] == (
    "exact-provider-data-store-overlay-package-lock-and-real-wordpress-runtime"
)
assert sdk064_graph["receiptId"] == sdk064_receipt["receiptId"]
assert sdk064_graph["profilePath"] == sdk064_profile_path.as_posix()
assert sdk064_graph["profileSha256"] == hashlib.sha256(
    sdk064_profile_path.read_bytes()
).hexdigest()
assert sdk064_graph["manifestPath"] == sdk064_tooling_manifest_path.as_posix()
assert sdk064_graph["manifestSha256"] == hashlib.sha256(
    sdk064_tooling_manifest_path.read_bytes()
).hexdigest()
assert sdk064_graph["lockPath"] == sdk064_tooling_lock_path.as_posix()
assert sdk064_graph["lockSha256"] == hashlib.sha256(
    sdk064_tooling_lock_path.read_bytes()
).hexdigest()
sdk064_tooling_manifest = json.loads(
    sdk064_tooling_manifest_path.read_text(encoding="utf-8")
)
sdk064_tooling_lock = json.loads(
    sdk064_tooling_lock_path.read_text(encoding="utf-8")
)
assert set(sdk064_graph["directPackages"]) == {
    f"{name}@{version}"
    for name, version in sdk064_tooling_manifest["devDependencies"].items()
}
assert sdk064_graph["lifecycleScriptsAllowed"] is False
assert sdk064_graph["buildInputOnly"] is True
assert sdk064_graph["advisoryFollowUp"] == "wordpresshx-g2.3"
assert sdk064_graph["runtimeImage"] == image_lock["images"]["node"][
    "reference"
]
assert sdk064_graph["browserRuntimeImage"] == image_lock["images"][
    "playwright"
]["reference"]
assert sdk064_graph["wordpressRuntimeImage"] == image_lock["images"][
    "wordpress70Php84"
]["reference"]
assert sdk064_receipt["toolchain"]["npmLockedPackageCount"] == (
    len(sdk064_tooling_lock["packages"]) - 1
)
assert sdk064_receipt["receiptId"] in lock["entries"]["wp70-release"][
    "testReceiptIds"
]
sdk064_implementation = sdk064_receipt["implementation"]
assert sdk064_implementation["authoringSurface"] == "haxe-hxx"
assert sdk064_implementation[
    "companionApplicationJavaScriptOrTypeScriptAuthored"
] is False
assert sdk064_implementation["nativeRegistry"] == "@wordpress/data"
assert sdk064_implementation["nativeApis"] == sdk064_api_exports
assert sdk064_implementation["storeKey"] == "wordpresshx/todo-studio-lab"
assert sdk064_implementation["compileTimeValidatedContracts"] == [
    "namespaced store key",
    "initial state and reducer state input",
    "reducer state result",
    "closed action structure",
    "string-compatible action discriminator",
    "store-specific dispatched action",
]
assert sdk064_implementation["domainCommandsLayeredInHaxe"] is True
assert sdk064_implementation["translationsExtractedFromHaxe"] is True
assert sdk064_implementation["shippedBrowserHxxRuntime"] is False
assert sdk064_implementation["wordpressSpecificGenesBranch"] is False
assert sdk064_receipt["exactProfileVerification"]["outcome"] == "passed"
sdk064_compilation = sdk064_receipt["compilation"]
assert sdk064_compilation["dependencies"] == [
    "react-jsx-runtime",
    "wp-components",
    "wp-data",
    "wp-editor",
    "wp-i18n",
    "wp-plugins",
]
assert sdk064_compilation["publicWeakTypes"] == []
assert sdk064_compilation["forbiddenHaxeWeakConstructs"] == []
assert sdk064_compilation["generatedAndBundleMachinePathLeaks"] == 0
assert sdk064_compilation["secondCompileMatched"] is True
assert sdk064_compilation["developmentAndProductionReplayMatched"] is True
assert sdk064_compilation["generatedPluginReplayMatched"] is True
assert sdk064_compilation["php74Syntax"] == "passed"
assert sdk064_compilation["php84Syntax"] == "passed"
sdk064_diagnostics = sdk064_receipt["negativeDiagnostics"]
assert set(sdk064_diagnostics) == {
    "WPX6401",
    "WPX6403",
    "WPX6405",
    "typedActionMismatch",
    "originalSourcePaths",
}
assert sdk064_diagnostics["originalSourcePaths"] is True
sdk064_runtime = sdk064_receipt["realWordPressRuntime"]
assert sdk064_runtime["check"] == "wordpresshx-sdk064-real-data-store-v1"
assert sdk064_runtime["outcome"] == "passed"
assert sdk064_runtime["wordpressVersion"] == "7.0"
assert sdk064_runtime["pluginActivated"] is True
assert sdk064_runtime["initialSnapshotSelected"] is True
assert sdk064_runtime["keyboardAction"] is True
assert sdk064_runtime["mouseActions"] is True
assert sdk064_runtime["finalRevision"] == 7
assert sdk064_runtime["nativeSubscriptionCount"] >= 7
assert sdk064_runtime["loadingObserved"] is True
assert sdk064_runtime["errorObserved"] is True
assert sdk064_runtime["recoveryObserved"] is True
assert sdk064_runtime["focusEnteredSidebar"] is True
assert sdk064_runtime["postTypeNegative"] == (
    "page editor has no extension menu item"
)
assert sdk064_runtime["publicUnregisterBefore"] is True
assert sdk064_runtime["publicUnregisterRemoved"] is True
assert sdk064_runtime["publicUnregisterAfter"] is False
assert sdk064_runtime["consoleErrors"] == 0
assert sdk064_runtime["pageErrors"] == 0
assert sdk064_runtime["accessibility"]["seriousOrCriticalViolations"] == 0
assert sdk064_receipt["localVerification"]["outcome"] == "passed"
assert sdk064_receipt["changeDecision"]["genesSourceChanged"] is False
assert sdk064_receipt["changeDecision"]["genesPullRequest"] is None
assert sdk064_receipt["changeDecision"][
    "wordpressSpecificGenesBranch"
] is False
assert sdk064_receipt["changeDecision"]["siblingGenesBuildInput"] is False
assert sdk064_receipt["claims"]["typedCustomDataStore"] == (
    "compile-and-runtime-tested"
)
assert sdk064_receipt["claims"]["compileTimeInvalidStoreRejection"] == (
    "tested"
)
assert sdk064_receipt["claims"]["nativeDispatchSelectSubscription"] == (
    "real-editor-tested"
)
assert sdk064_receipt["claims"]["loadingErrorAndRecovery"] == (
    "real-editor-tested"
)
assert sdk064_receipt["claims"]["completeTodoStudio"] == "not-claimed"
assert sdk064_receipt["claims"]["productionSupport"] == "not-tested"
assert "Prove the typed native data store on WordPress 7.0" in workflow_text
assert "bash packages/gutenberg/scripts/test-data-store.sh" in workflow_text
assert "Prove typed block metadata on WordPress 7.0" in workflow_text
assert "Test typed profile-specific block.json generation" in workflow_text
assert "bash packages/gutenberg/scripts/test-block-metadata.sh" in workflow_text
assert (
    "bash packages/gutenberg/scripts/test-block-metadata.sh --skip-wordpress"
    in workflow_text
)
sdk064_hosted = sdk064_receipt["repositoryHostedVerification"]
assert sdk064_hosted["workflow"] == "Repository bootstrap"
assert sdk064_hosted["job"] == "wordpress-runtime"
assert sdk064_hosted["step"] == (
    "Prove the typed native data store on WordPress 7.0"
)
assert sdk064_hosted["required"] is True
assert sdk064_hosted["generatedTreeSha256"] == sdk064_compilation[
    "generatedTreeSha256"
]
assert sdk064_hosted["productionBundleSha256"] == sdk064_compilation[
    "productionBundleSha256"
]
if sdk064_receipt["status"] == "implemented-hosted-pending":
    assert sdk064_implementation.get("commit") is None
    assert sdk064_hosted["status"] == "pending-main-push"
    assert sdk064_hosted["commit"] is None
    assert sdk064_hosted["runId"] is None
    assert sdk064_hosted["jobId"] is None
    assert sdk064_hosted["url"] is None
    assert sdk064_hosted["jobUrl"] is None
    assert sdk064_hosted["jobCount"] is None
    assert sdk064_hosted["allJobsPassed"] is None
    assert sdk064_hosted["artifactHashesMatched"] is None
    assert sdk064_hosted["completedAt"] is None
else:
    assert sdk064_receipt["status"] == "verified"
    assert sha1.fullmatch(sdk064_implementation["commit"])
    assert sdk064_hosted["commit"] == sdk064_implementation["commit"]
    assert isinstance(sdk064_hosted["runId"], int)
    assert isinstance(sdk064_hosted["jobId"], int)
    assert sdk064_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        f"{sdk064_hosted['runId']}"
    )
    assert sdk064_hosted["jobUrl"] == (
        sdk064_hosted["url"] + f"/job/{sdk064_hosted['jobId']}"
    )
    assert sdk064_hosted["status"] == "passed"
    assert sdk064_hosted["jobCount"] == 13
    assert sdk064_hosted["allJobsPassed"] is True
    assert sdk064_hosted["artifactHashesMatched"] is True
    assert sdk064_hosted["completedAt"] == sdk064_receipt["observedAt"]

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

assert php_ir_receipt["subject"]["packageContentSha256"] == (
    "cf0fc152f4fe09b8a9eb92f6b9f4c1f1591ab938531d6241c245ab11a75532f6"
)
assert sdk025_receipt["subject"]["genericCompilerPackageContentSha256"] == (
    "4d43afdc4f35cb45e55ab760e982d213a2c0749dc4f0c1b72790c30a64287294"
)
assert sdk024_compiler["currentGenericPackageContentSha256"] == (
    "6dd9674acefeab7ed0aa345dcd8d540f0c3abcdc9f230b0af9064e8b703d693b"
)

assert sdk027_receipt["schemaVersion"] == 1
assert sdk027_receipt["receiptId"] == (
    "SDK-027-GENERIC-PHP-COMPILER-READINESS"
)
assert sdk027_receipt["bead"] == "wordpresshx-sdk-027"
assert sdk027_receipt["status"] in {
    "implemented-hosted-pending",
    "verified",
}
sdk027_subject = sdk027_receipt["subject"]
assert sdk027_subject["package"] == haxelib["name"]
assert sdk027_subject["path"] == "compiler/reflaxe.php"
package_root = Path(sdk027_subject["path"])
assert sdk027_subject["version"] == haxelib["version"]
assert sdk027_subject["packageFileCount"] == 48
assert sdk027_subject["packageContentSha256"] == (
    "a8add1a4bc5bef5b5ec9a5ac99e05c4a2c6a0bc996be7bbe625daf55d06d082f"
)
sdk027_package_paths = validate_package_subject(sdk027_subject)
sdk027_implementation_commit = sdk027_receipt["implementation"][
    "implementationCommit"
]
if sdk027_implementation_commit is None:
    tracked_package_paths = subprocess.run(
        ["git", "ls-files", "--", sdk027_subject["path"]],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    tracked_package_paths = sorted(
        path for path in tracked_package_paths if "/build/" not in path
    )
    assert tracked_package_paths == sdk027_package_paths
    for package_file in sdk027_subject["packageFiles"]:
        package_path = Path(package_file["path"])
        assert package_path.is_file()
        assert hashlib.sha256(package_path.read_bytes()).hexdigest() == (
            package_file["sha256"]
        )
else:
    verify_historical_package(sdk027_subject, sdk027_implementation_commit)

sdk027_implementation = sdk027_receipt["implementation"]
assert sdk027_implementation["dependencyDirection"] == (
    "reflaxe.php <- compiler/wordpress <- WordPressHx SDK"
)
sdk027_artifact = sdk027_implementation["artifact"]
assert sdk027_artifact["format"] == "deterministic-source-only-haxelib-zip"
assert sdk027_artifact["archiveFile"] == "reflaxe.php-0.0.0.zip"
assert sdk027_artifact["archiveSha256"] == (
    "913e9501f6dcac2cfca8879266ccffa124bdd014f9ca5908ee6286312cce6f79"
)
assert sdk027_artifact["sourceContentSha256"] == (
    "23cdce039ba7874750816311e46b77cbfffb40658a871acde4d73fe202189ea7"
)
assert sdk027_artifact["twoBuildsByteIdentical"] is True
assert sdk027_artifact["cleanWorktreeProvenancePassed"] is True
assert sdk027_artifact["artifactManifestWorkingTreeDirty"] is False
assert sdk027_artifact["embeddedPerFileHashes"] is True
assert sdk027_artifact["sourceOnly"] is True
assert sdk027_artifact["publicationAuthorized"] is False
sdk027_consumer = sdk027_implementation["externalConsumer"]
for sdk027_consumer_proof in (
    "disposableLocalHaxelibRepository",
    "preInstallResolutionRejected",
    "checkoutResolutionRejected",
    "installedArchiveCompiled",
    "generatedPhpLinted",
    "generatedPhpExecuted",
):
    assert sdk027_consumer[sdk027_consumer_proof] is True
sdk027_release_policy = sdk027_implementation["releasePolicy"]
for sdk027_release_guard in (
    "exactHaxelibDependencyVersionsRequired",
    "floatingSiblingPathsRejected",
    "haxelibDevReleaseResolutionRejected",
    "machineLocalPathsRejected",
    "cleanWorktreeRequiredInCi",
    "changelogRequired",
):
    assert sdk027_release_policy[sdk027_release_guard] is True

assert set(sdk027_receipt["issueRouting"]) == {
    "generic",
    "wordpress",
    "pressureRule",
}
assert sdk027_receipt["extraction"]["procedure"] == (
    "compiler/reflaxe.php/EXTRACTION.md"
)
assert sdk027_receipt["extraction"]["triggerAccepted"] is False
assert sdk027_receipt["extraction"]["physicalRepositorySplitPerformed"] is False
assert sdk027_receipt["extraction"]["publicationPerformed"] is False
sdk027_reference = sdk027_receipt["referenceReview"]
assert sdk027_reference["repository"] == "haxe.ocaml"
assert sdk027_reference["commit"] == (
    "ef30eba09eff26c4ef09a8302f7cee84e23fc81c"
)
assert sdk027_reference["codeOrFixtureBytesCopied"] is False
assert sdk027_reference["runtimeOrBuildDependencyCreated"] is False
sdk027_verification = sdk027_receipt["verification"]
assert sdk027_verification["genericPackageTest"]["outcome"] == "passed"
assert sdk027_verification["packageReadinessTest"] == {
    "command": "bash compiler/reflaxe.php/scripts/test-package.sh",
    "outcome": "passed",
    "marker": "REFLAXE_PHP_PACKAGE_READINESS:PASS",
}
assert sdk027_verification["exactPhpMatrix"]["outcome"] == "passed"
assert sdk027_verification["downstreamWordPressProfile"]["outcome"] == (
    "passed"
)
assert sdk027_verification["downstreamWordPressPhpMatrix"]["outcome"] == (
    "passed"
)
assert sdk027_verification["repositoryInvariant"]["outcome"] == "passed"
sdk027_hosted = sdk027_verification["hostedWorkflow"]
assert sdk027_hosted["workflow"] == "Repository bootstrap"
assert sdk027_hosted["path"] == ".github/workflows/repository.yml"
assert sdk027_hosted["job"] == "haxe"
assert sdk027_hosted["steps"] == [
    "Test generic PHP compiler package",
    "Test clean standalone PHP compiler package artifact",
    "Test exact PHP 7.4 and 8.4 runtime matrix",
    "Test WordPress public PHP profile",
    "Test public PHP on exact PHP 7.4 and 8.4",
]
assert sdk027_hosted["cleanPackageArtifactRequired"] is True
assert sdk027_hosted["exactPhpMatrixRequired"] is True
assert sdk027_hosted["downstreamWordPressProfileRequired"] is True
if sdk027_receipt["status"] == "implemented-hosted-pending":
    assert sdk027_hosted["runId"] is None
    assert sdk027_hosted["jobId"] is None
    assert sdk027_hosted["commit"] is None
    assert sdk027_hosted["status"] == "pending-first-main-run"
else:
    assert sdk027_hosted["runId"] == 29698338371
    assert sdk027_hosted["jobId"] == 88222834621
    assert sdk027_hosted["attempt"] == 1
    assert sdk027_hosted["commit"] == (
        "586baedef4fb3499be8127022be01759f4389181"
    )
    assert sdk027_hosted["completedAt"] == "2026-07-19T18:22:05Z"
    assert sdk027_hosted["url"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        "29698338371"
    )
    assert sdk027_hosted["jobUrl"] == (
        "https://github.com/fullofcaffeine/wordpresshx/actions/runs/"
        "29698338371/job/88222834621"
    )
    assert sdk027_hosted["status"] == "passed"
    assert sdk027_hosted["fullMatrixStatus"] == "passed"
    assert sdk027_hosted["jobCount"] == 11
assert "Test clean standalone PHP compiler package artifact" in workflow_text
assert (
    "bash compiler/reflaxe.php/scripts/test-package.sh --require-clean"
    in workflow_text
)
assert sdk027_receipt["claims"]["arbitraryHaxePhpBackend"] == "unsupported"
assert sdk027_receipt["claims"]["repositoryExtraction"] == (
    "not-performed-no-trigger"
)
assert sdk027_receipt["claims"]["packagePublication"] == "blocked"
assert sdk027_receipt["claims"]["genericPackageIndependentlyInstallable"] == (
    "runtime-tested-hosted"
)
assert sdk027_receipt["claims"]["deterministicSourceArtifact"] == (
    "byte-identical-hosted"
)
assert sdk027_receipt["claims"]["wordpressProfileCompatibility"] == (
    "runtime-tested-hosted"
)
assert sdk027_receipt["claims"]["php74And84"] == "runtime-tested-hosted"
assert sdk027_receipt["claims"]["productionSupport"] == "not-tested"

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
assert readability["totalPhpBytes"] == 791
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
    # SDK-023 authenticates the original package at its implementation commit;
    # later compiler gates may evolve the committed snapshots in place. Keep
    # the path inside that historical package while the current receipt and
    # manifest authenticate the evolved bytes, as SDK-022 does above.
    assert artifact["snapshotPath"] in adapter_package_digests
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
assert adapter_readability["totalPhpBytes"] == 4090
assert adapter_readability["totalPhpLines"] == 154
assert adapter_readability["adapterClassBytes"] == 2723
assert adapter_readability["adapterClassLines"] == 101
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
    "playwright",
    "wordpress70Php84",
):
    assert image_lock["images"][image_key]["evidenceStatus"] == (
        "runtime-tested"
    )
for image_key in ("node",):
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
assert sdk090_receipt["matrixBoundaries"]["playwright1582"] == (
    "runtime-tested-by-sdk-034-not-sdk-090"
)
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
python3 scripts/runtime-support/test-policy.py
python3 scripts/source-correlation/validate-contracts.py
python3 scripts/semantic-plan/test-contract.py
python3 scripts/contracts/validate-schema-authority.py
python3 scripts/output-context/validate-architecture.py
python3 scripts/adoption/validate-architecture.py
python3 scripts/ownership/test-contract.py
python3 scripts/generated-output-vcs/test-policy.py
python3 scripts/project-cli/test-contract.py
python3 -m py_compile scripts/determinism/compare-builds.py
python3 -m py_compile scripts/determinism/test-production.py
python3 -m py_compile scripts/project-cli/test-production.py
python3 -m py_compile scripts/scaffold/test-production.py
python3 scripts/docker/check-image-lock.py
python3 scripts/gates/test-g0-baseline.py
python3 packages/cli/scripts/verify-dependency-lock.py
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
