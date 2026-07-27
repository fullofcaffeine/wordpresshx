#!/usr/bin/env python3
"""Generate the complete lock-derived build-input inventory and SPDX SBOM.

This inventory is deliberately conservative. Lock metadata can identify a
component and report its declared license, but it cannot establish the license
conclusion for bytes in a future release artifact. Artifact-specific manifests
and notices remain a separate publication requirement.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.parse import quote


SCHEMA_VERSION = 1
GENERATOR = "scripts/licenses/generate-build-input-inventory.py"
DEFAULT_INVENTORY = "LICENSES/inventory/build-inputs.json"
DEFAULT_SBOM = "LICENSES/sbom/build-inputs.spdx.json"
COMPONENT_EVIDENCE = "LICENSES/evidence/component-license-evidence.json"

FIXED_LOCK_PATHS = {
    "docker/images.lock.json",
    "fixtures/generated-output-vcs/project/wordpress-hx.fixture-lock.json",
    "manifests/toolchain.lock.json",
    "manifests/upstream.lock.json",
    "profiles/classification-decision-lock.json",
    "profiles/decision-lock.json",
    "tooling/beads/history-reader.lock.json",
}
LOCK_BASENAMES = {
    "composer.lock",
    "dependency-lock.json",
    "haxelib.json",
    "npm-lock.json",
    "package-lock.json",
    "project.lock.json",
    "source.lock.json",
}


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=False) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top level must be an object")
    return value


def tracked_paths(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return sorted(
        value.decode("utf-8")
        for value in result.stdout.split(b"\0")
        if value
    )


def is_inventory_source(relative: str) -> bool:
    path = Path(relative)
    return relative in FIXED_LOCK_PATHS or path.name in LOCK_BASENAMES


def inventory_sources(root: Path) -> list[str]:
    try:
        return [
            relative
            for relative in tracked_paths(root)
            if is_inventory_source(relative)
        ]
    except (OSError, subprocess.CalledProcessError):
        portable = read_object(root / DEFAULT_INVENTORY)
        sources = portable.get("sources")
        if not isinstance(sources, list) or not sources:
            raise ValueError(
                "portable inventory source list is absent outside a Git checkout"
            )
        paths = [
            value.get("path")
            for value in sources
            if isinstance(value, dict)
        ]
        if not all(isinstance(value, str) for value in paths):
            raise ValueError("portable inventory contains an invalid source path")
        return sorted(paths)


def normalized_name(value: str) -> str:
    return value.strip().lower().replace("-", "_").replace(".", "_")


def license_values(value: object) -> list[str]:
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    if isinstance(value, list):
        return sorted(
            {
                item.strip()
                for item in value
                if isinstance(item, str) and item.strip()
            }
        )
    return []


def npm_name(locator: str, package: dict[str, Any]) -> str:
    explicit = package.get("name")
    if isinstance(explicit, str) and explicit:
        return explicit
    marker = "node_modules/"
    if marker not in locator:
        raise ValueError(f"cannot derive npm package name from {locator!r}")
    return locator.rsplit(marker, 1)[1]


def version_from_tag(value: object, fallback: str) -> str:
    if not isinstance(value, str) or not value:
        return fallback
    return value[1:] if value.startswith("v") else value


@dataclass(frozen=True)
class Observation:
    source: str
    locator: str
    scope: str
    declared_licenses: tuple[str, ...]

    def as_json(self) -> dict[str, object]:
        return {
            "source": self.source,
            "locator": self.locator,
            "scope": self.scope,
            "declaredLicenses": list(self.declared_licenses),
        }


@dataclass
class Component:
    ecosystem: str
    name: str
    version: str
    resolution: str
    distribution_class: str
    declared_licenses: set[str] = field(default_factory=set)
    observations: list[Observation] = field(default_factory=list)
    review_bindings: set[str] = field(default_factory=set)
    exact_evidence_ids: set[str] = field(default_factory=set)

    @property
    def identity(self) -> str:
        return "\0".join(
            [self.ecosystem, self.name, self.version, self.resolution]
        )

    @property
    def component_id(self) -> str:
        suffix = sha256_bytes(self.identity.encode("utf-8"))[:16]
        coordinate = (
            f"{self.ecosystem}:{quote(self.name, safe='@/._-')}@"
            f"{quote(self.version, safe='._+-')}"
        )
        return f"{coordinate}#{suffix}"

    @property
    def evidence_status(self) -> str:
        if self.distribution_class == "test-runtime-input":
            return "test-input-not-redistributed-no-license-conclusion"
        if self.distribution_class == "fixture-build-input":
            return "fixture-only-no-publication-conclusion"
        if not self.declared_licenses:
            return "missing-license-declaration-publication-blocked"
        if len(self.declared_licenses) > 1:
            return "multiple-declarations-require-artifact-review"
        if self.exact_evidence_ids:
            return "exact-component-license-evidence-recorded"
        return "lock-or-exact-source-metadata-recorded"

    def as_json(self) -> dict[str, object]:
        licenses = sorted(self.declared_licenses) or ["NOASSERTION"]
        return {
            "id": self.component_id,
            "ecosystem": self.ecosystem,
            "name": self.name,
            "version": self.version,
            "resolution": self.resolution,
            "declaredLicenses": licenses,
            "licenseEvidenceStatus": self.evidence_status,
            "distributionClass": self.distribution_class,
            "publicationDecision": "not-a-final-artifact-conclusion",
            "reviewBindings": sorted(self.review_bindings),
            "exactLicenseEvidenceIds": sorted(self.exact_evidence_ids),
            "observedIn": [
                item.as_json()
                for item in sorted(
                    self.observations,
                    key=lambda value: (
                        value.source,
                        value.locator,
                        value.scope,
                        value.declared_licenses,
                    ),
                )
            ],
        }


class InventoryBuilder:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.components: dict[str, Component] = {}
        self.source_records: list[dict[str, object]] = []
        self.curated = self._curated_components()
        self.component_evidence = self._component_evidence()

    def _curated_components(self) -> dict[tuple[str, str], list[dict[str, Any]]]:
        inventory = read_object(self.root / "LICENSES/components.json")
        result: dict[tuple[str, str], list[dict[str, Any]]] = {}
        for value in inventory.get("components", []):
            if not isinstance(value, dict):
                continue
            name = value.get("name")
            version = value.get("version")
            if not isinstance(name, str) or not isinstance(version, str):
                continue
            key = (normalized_name(name), version)
            result.setdefault(key, []).append(value)
        return result

    def _component_evidence(self) -> list[dict[str, Any]]:
        evidence = read_object(self.root / COMPONENT_EVIDENCE)
        if evidence.get("schemaVersion") != 1:
            raise ValueError(f"{COMPONENT_EVIDENCE}: schemaVersion must be 1")
        if evidence.get("publicationAuthorized") is not False:
            raise ValueError(f"{COMPONENT_EVIDENCE}: publication must remain blocked")
        components = evidence.get("components")
        if not isinstance(components, list):
            raise ValueError(f"{COMPONENT_EVIDENCE}: components must be an array")
        ids: set[str] = set()
        for index, component in enumerate(components):
            if not isinstance(component, dict):
                raise ValueError(f"{COMPONENT_EVIDENCE}: invalid component {index}")
            evidence_id = component.get("id")
            match = component.get("match")
            license_evidence = component.get("licenseEvidence")
            if (
                not isinstance(evidence_id, str)
                or evidence_id in ids
                or not isinstance(match, dict)
                or not isinstance(license_evidence, dict)
            ):
                raise ValueError(f"{COMPONENT_EVIDENCE}: invalid evidence identity")
            ids.add(evidence_id)
            snapshot_path = license_evidence.get("snapshotPath")
            snapshot_sha256 = license_evidence.get("snapshotSha256")
            if not isinstance(snapshot_path, str) or not isinstance(snapshot_sha256, str):
                raise ValueError(f"{COMPONENT_EVIDENCE}: snapshot identity required")
            actual = sha256_bytes((self.root / snapshot_path).read_bytes())
            if actual != snapshot_sha256:
                raise ValueError(
                    f"{COMPONENT_EVIDENCE}: snapshot digest mismatch for {evidence_id}"
                )
        return components

    def curated_evidence(
        self, name: str, version: str
    ) -> tuple[list[str], list[str]]:
        matches = self.curated.get((normalized_name(name), version), [])
        licenses = sorted(
            {
                license_id
                for value in matches
                for license_id in license_values(value.get("declaredLicense"))
            }
        )
        bindings = sorted(
            {
                component_id
                for value in matches
                if isinstance((component_id := value.get("id")), str)
            }
        )
        return licenses, bindings

    def add(
        self,
        *,
        ecosystem: str,
        name: str,
        version: str,
        resolution: str,
        distribution_class: str,
        source: str,
        locator: str,
        scope: str,
        licenses: list[str] | None = None,
        curated_name: str | None = None,
        curated_version: str | None = None,
    ) -> None:
        declared = list(licenses or [])
        curated_licenses, bindings = self.curated_evidence(
            curated_name or name, curated_version or version
        )
        if not declared:
            declared = curated_licenses
        prototype = Component(
            ecosystem=ecosystem,
            name=name,
            version=version,
            resolution=resolution,
            distribution_class=distribution_class,
        )
        component = self.components.setdefault(prototype.identity, prototype)
        if component.distribution_class != distribution_class:
            component.distribution_class = "multiple-build-test-or-source-roles"
        component.declared_licenses.update(declared)
        component.review_bindings.update(bindings)
        observation = Observation(
            source=source,
            locator=locator,
            scope=scope,
            declared_licenses=tuple(sorted(declared)),
        )
        if observation not in component.observations:
            component.observations.append(observation)

    def parse_npm(self, relative: str, value: dict[str, Any]) -> int:
        packages = value.get("packages")
        if not isinstance(packages, dict):
            raise ValueError(f"{relative}: npm lock packages must be an object")
        count = 0
        distribution = (
            "fixture-build-input"
            if relative.startswith("fixtures/")
            else "repository-build-input"
        )
        for locator, package in packages.items():
            if locator == "":
                continue
            if not isinstance(locator, str) or not isinstance(package, dict):
                raise ValueError(f"{relative}: invalid npm package entry")
            version = package.get("version")
            if not isinstance(version, str) or not version:
                raise ValueError(f"{relative}#{locator}: version is required")
            name = npm_name(locator, package)
            integrity = package.get("integrity")
            resolved = package.get("resolved")
            resolution = (
                f"integrity:{integrity}"
                if isinstance(integrity, str) and integrity
                else f"url:{resolved}"
                if isinstance(resolved, str) and resolved
                else f"lock-local:{relative}#{locator}"
            )
            scope = "development" if package.get("dev") is True else "runtime"
            if package.get("optional") is True:
                scope += "-optional"
            self.add(
                ecosystem="npm",
                name=name,
                version=version,
                resolution=resolution,
                distribution_class=distribution,
                source=relative,
                locator=f"/packages/{locator}",
                scope=scope,
                licenses=license_values(package.get("license")),
            )
            count += 1
        return count

    def parse_composer(self, relative: str, value: dict[str, Any]) -> int:
        count = 0
        for section, scope in (("packages", "runtime"), ("packages-dev", "development")):
            packages = value.get(section, [])
            if not isinstance(packages, list):
                raise ValueError(f"{relative}: {section} must be an array")
            for index, package in enumerate(packages):
                if not isinstance(package, dict):
                    raise ValueError(f"{relative}: invalid Composer package entry")
                name = package.get("name")
                version = package.get("version")
                if not isinstance(name, str) or not isinstance(version, str):
                    raise ValueError(f"{relative}: Composer name/version required")
                source = package.get("source")
                distribution = package.get("dist")
                reference = (
                    source.get("reference")
                    if isinstance(source, dict)
                    else None
                )
                if not isinstance(reference, str) and isinstance(distribution, dict):
                    reference = distribution.get("reference")
                if not isinstance(reference, str):
                    reference = f"{relative}#/{section}/{index}"
                self.add(
                    ecosystem="composer",
                    name=name,
                    version=version,
                    resolution=f"reference:{reference}",
                    distribution_class="repository-build-input",
                    source=relative,
                    locator=f"/{section}/{index}",
                    scope=scope,
                    licenses=license_values(package.get("license")),
                )
                count += 1
        return count

    def add_haxe_toolchain(
        self, relative: str, locator: str, toolchain: dict[str, Any]
    ) -> int:
        count = 0
        haxe = toolchain.get("haxe")
        if isinstance(haxe, str):
            for role, curated_name, declared in (
                ("compiler", "Haxe compiler", ["GPL-2.0-or-later"]),
                ("standard-library", "Haxe standard library", ["MIT"]),
            ):
                self.add(
                    ecosystem="haxe",
                    name=f"haxe-{role}",
                    version=haxe,
                    resolution=f"version:{haxe}",
                    distribution_class="repository-build-input",
                    source=relative,
                    locator=f"{locator}/haxe",
                    scope=role,
                    licenses=declared,
                    curated_name=curated_name,
                )
                count += 1
        lix = toolchain.get("lix")
        if isinstance(lix, dict) and isinstance(lix.get("version"), str):
            version = lix["version"]
            artifact = lix.get("artifact")
            sha256 = artifact.get("sha256") if isinstance(artifact, dict) else None
            resolution = (
                f"sha256:{sha256}"
                if isinstance(sha256, str)
                else f"version:{version}"
            )
            self.add(
                ecosystem="npm",
                name="lix",
                version=version,
                resolution=resolution,
                distribution_class="repository-build-input",
                source=relative,
                locator=f"{locator}/lix",
                scope="dependency-manager",
                curated_name="Lix",
            )
            count += 1
        return count

    def add_haxe_dependency(
        self, relative: str, locator: str, dependency: dict[str, Any]
    ) -> None:
        name = dependency.get("name")
        version = dependency.get("version")
        if not isinstance(name, str) or not isinstance(version, str):
            raise ValueError(f"{relative}{locator}: dependency name/version required")
        artifact = dependency.get("artifact")
        sha256 = dependency.get("sha256")
        if isinstance(artifact, dict):
            sha256 = artifact.get("sha256")
        commit = dependency.get("commit")
        resolution = (
            f"sha256:{sha256}"
            if isinstance(sha256, str)
            else f"git:{commit}"
            if isinstance(commit, str)
            else f"version:{version}"
        )
        self.add(
            ecosystem="haxelib",
            name=name,
            version=version,
            resolution=resolution,
            distribution_class="repository-build-input",
            source=relative,
            locator=locator,
            scope="compile-time",
        )

    def parse_dependency_lock(self, relative: str, value: dict[str, Any]) -> int:
        count = 0
        compiler = value.get("compiler")
        if isinstance(compiler, dict):
            name = compiler.get("name")
            version = compiler.get("version")
            if isinstance(name, str) and isinstance(version, str):
                artifact = compiler.get("releaseArtifact")
                sha256 = artifact.get("sha256") if isinstance(artifact, dict) else None
                commit = compiler.get("commit")
                resolution = (
                    f"git:{commit}#tree={compiler.get('tree')}"
                    if isinstance(commit, str)
                    else f"sha256:{sha256}"
                    if isinstance(sha256, str)
                    else f"version:{version}"
                )
                self.add(
                    ecosystem="haxelib",
                    name=name,
                    version=version,
                    resolution=resolution,
                    distribution_class="repository-build-input",
                    source=relative,
                    locator="/compiler",
                    scope="compiler",
                )
                count += 1
        parser = value.get("parser")
        if isinstance(parser, dict):
            self.add_haxe_dependency(relative, "/parser", parser)
            count += 1
        dependencies = value.get("dependencies", [])
        if dependencies is None:
            dependencies = []
        if not isinstance(dependencies, list):
            raise ValueError(f"{relative}: dependencies must be an array")
        for index, dependency in enumerate(dependencies):
            if not isinstance(dependency, dict):
                raise ValueError(f"{relative}: invalid Haxe dependency")
            self.add_haxe_dependency(relative, f"/dependencies/{index}", dependency)
            count += 1
        toolchain = value.get("toolchain")
        if isinstance(toolchain, dict):
            count += self.add_haxe_toolchain(relative, "/toolchain", toolchain)
        return count

    def add_source_component(
        self,
        relative: str,
        locator: str,
        source: dict[str, Any],
        name: str,
        version: str,
        curated_name: str,
        curated_version: str,
    ) -> None:
        commit = source.get("commit")
        tree = source.get("tree")
        resolution = (
            f"git:{commit}#tree={tree}"
            if isinstance(commit, str) and isinstance(tree, str)
            else f"git:{commit}"
            if isinstance(commit, str)
            else f"version:{version}"
        )
        self.add(
            ecosystem="git-source",
            name=name,
            version=version,
            resolution=resolution,
            distribution_class="profile-source-authority",
            source=relative,
            locator=locator,
            scope="catalog-or-runtime-authority",
            curated_name=curated_name,
            curated_version=curated_version,
        )

    def parse_source_lock(self, relative: str, value: dict[str, Any]) -> int:
        count = 0
        wordpress = value.get("wordpressSource")
        if isinstance(wordpress, dict):
            version = version_from_tag(wordpress.get("tag"), "7.0.0")
            self.add_source_component(
                relative,
                "/wordpressSource",
                wordpress,
                "wordpress",
                version,
                "WordPress",
                "7.0.0",
            )
            count += 1
        embedded = value.get("embeddedGutenberg")
        if isinstance(embedded, dict):
            self.add_source_component(
                relative,
                "/embeddedGutenberg",
                embedded,
                "gutenberg",
                "wordpress-7.0-embedded",
                "Gutenberg embedded in WordPress 7.0",
                "wordpress-7.0-embedded",
            )
            count += 1
        gutenberg = value.get("gutenbergSource")
        if isinstance(gutenberg, dict):
            version = version_from_tag(gutenberg.get("tag"), "23.4.0")
            self.add_source_component(
                relative,
                "/gutenbergSource",
                gutenberg,
                "gutenberg",
                version,
                "Gutenberg",
                "23.4.0",
            )
            count += 1
        return count

    def parse_images(self, relative: str, value: dict[str, Any]) -> int:
        images = value.get("images")
        if not isinstance(images, dict):
            raise ValueError(f"{relative}: images must be an object")
        for image_id, image in images.items():
            if not isinstance(image_id, str) or not isinstance(image, dict):
                raise ValueError(f"{relative}: invalid OCI image entry")
            reference = image.get("reference")
            tag = image.get("tag")
            if not isinstance(reference, str) or "@sha256:" not in reference:
                raise ValueError(f"{relative}#{image_id}: digest reference required")
            version = tag.rsplit(":", 1)[-1] if isinstance(tag, str) else "digest-pinned"
            self.add(
                ecosystem="oci",
                name=image_id,
                version=version,
                resolution=reference,
                distribution_class="test-runtime-input",
                source=relative,
                locator=f"/images/{image_id}",
                scope="test-runtime",
            )
        return len(images)

    def parse_haxelib_manifest(self, relative: str, value: dict[str, Any]) -> int:
        name = value.get("name")
        version = value.get("version")
        if not isinstance(name, str) or not isinstance(version, str):
            raise ValueError(f"{relative}: haxelib name/version required")
        self.add(
            ecosystem="haxelib",
            name=name,
            version=version,
            resolution=f"repository-path:{relative}",
            distribution_class="internal-package-manifest",
            source=relative,
            locator="/",
            scope="internal-not-publishable",
            licenses=license_values(value.get("license")),
        )
        return 1

    def parse_upstream(self, relative: str, value: dict[str, Any]) -> int:
        entries = value.get("entries")
        if not isinstance(entries, dict):
            raise ValueError(f"{relative}: entries must be an object")
        count = 0
        for entry_id, entry in entries.items():
            if not isinstance(entry_id, str) or not isinstance(entry, dict):
                raise ValueError(f"{relative}: invalid upstream entry")
            if entry_id == "genes-ts":
                version = entry.get("version")
                if not isinstance(version, str):
                    raise ValueError(f"{relative}: Genes version required")
                self.add_source_component(
                    relative,
                    f"/entries/{entry_id}",
                    entry,
                    "genes-ts",
                    version,
                    "genes-ts",
                    version,
                )
                count += 1
            elif entry_id == "tink-hxx-parser":
                version = entry.get("version")
                if not isinstance(version, str):
                    raise ValueError(f"{relative}: tink_hxx version required")
                self.add_source_component(
                    relative,
                    f"/entries/{entry_id}",
                    entry,
                    "tink_hxx",
                    version,
                    "tink_hxx",
                    version,
                )
                count += 1
            elif entry_id == "wp70-release":
                count += self.parse_source_lock(relative, entry)
            elif entry_id == "gutenberg-forward-23.4":
                count += self.parse_source_lock(relative, entry)
        return count

    def parse_toolchain(self, relative: str, value: dict[str, Any]) -> int:
        count = 0
        compilers = value.get("compilers")
        if isinstance(compilers, dict):
            haxe = compilers.get("haxe")
            if isinstance(haxe, dict) and isinstance(haxe.get("version"), str):
                version = haxe["version"]
                for role, curated_name, declared in (
                    ("compiler", "Haxe compiler", ["GPL-2.0-or-later"]),
                    ("standard-library", "Haxe standard library", ["MIT"]),
                ):
                    self.add(
                        ecosystem="haxe",
                        name=f"haxe-{role}",
                        version=version,
                        resolution=f"git:{haxe.get('commit')}#tree={haxe.get('tree')}",
                        distribution_class="repository-build-input",
                        source=relative,
                        locator=f"/compilers/haxe/{role}",
                        scope=role,
                        licenses=declared,
                        curated_name=curated_name,
                    )
                    count += 1
            genes = compilers.get("genesTs")
            if isinstance(genes, dict) and isinstance(genes.get("version"), str):
                version = genes["version"]
                self.add_source_component(
                    relative,
                    "/compilers/genesTs",
                    genes,
                    "genes-ts",
                    version,
                    "genes-ts",
                    version,
                )
                count += 1
            reflaxe = compilers.get("reflaxePhp")
            if isinstance(reflaxe, dict) and isinstance(reflaxe.get("version"), str):
                version = reflaxe["version"]
                self.add(
                    ecosystem="repository-import",
                    name="reflaxe.php",
                    version=version,
                    resolution=f"git:{reflaxe.get('originCommit')}#tree={reflaxe.get('originTree')}",
                    distribution_class="internal-imported-source",
                    source=relative,
                    locator="/compilers/reflaxePhp",
                    scope="compiler",
                    licenses=["GPL-2.0-or-later"],
                )
                count += 1
        formatters = value.get("formatters")
        formatter = formatters.get("haxeFormatter") if isinstance(formatters, dict) else None
        if isinstance(formatter, dict) and isinstance(formatter.get("version"), str):
            version = formatter["version"]
            self.add_source_component(
                relative,
                "/formatters/haxeFormatter",
                formatter,
                "haxe-formatter",
                version,
                "Haxe Formatter",
                version,
            )
            count += 1
        graphs = value.get("dependencyGraphs")
        npm = graphs.get("npm") if isinstance(graphs, dict) else None
        active = npm.get("activePackages", []) if isinstance(npm, dict) else []
        if isinstance(active, list):
            for index, package in enumerate(active):
                if not isinstance(package, dict):
                    continue
                name = package.get("name")
                version = package.get("version")
                if isinstance(name, str) and isinstance(version, str):
                    self.add(
                        ecosystem="npm",
                        name=name,
                        version=version,
                        resolution=f"sha256:{package.get('artifactSha256')}",
                        distribution_class="repository-build-input",
                        source=relative,
                        locator=f"/dependencyGraphs/npm/activePackages/{index}",
                        scope="compile-time",
                    )
                    count += 1
        return count

    def parse_project_lock(self, relative: str, value: dict[str, Any]) -> int:
        components = value.get("components")
        if not isinstance(components, list):
            return 0
        count = 0
        for index, component in enumerate(components):
            if not isinstance(component, dict):
                raise ValueError(f"{relative}: invalid project-lock component")
            component_id = component.get("id")
            version = component.get("version")
            identity = component.get("identity")
            if not all(isinstance(item, str) for item in (component_id, version, identity)):
                raise ValueError(f"{relative}: project component identity required")
            self.add(
                ecosystem="wordpresshx-project-lock",
                name=component_id,
                version=version,
                resolution=identity,
                distribution_class="fixture-build-input",
                source=relative,
                locator=f"/components/{index}",
                scope=str(component.get("role", "fixture")),
            )
            count += 1
        return count

    def parse_beads_history(self, relative: str, value: dict[str, Any]) -> int:
        version = value.get("baseTag")
        commit = value.get("baseCommit")
        if not isinstance(version, str) or not isinstance(commit, str):
            raise ValueError(f"{relative}: Beads tag/commit required")
        self.add(
            ecosystem="git-source",
            name="beads-history-reader",
            version=version.removeprefix("v"),
            resolution=f"git:{commit}",
            distribution_class="repository-build-input",
            source=relative,
            locator="/",
            scope="security-history-reader-build",
            curated_name="beads",
            curated_version="1.0.4",
        )
        return 1

    def parse(self, relative: str, value: dict[str, Any]) -> tuple[str, int]:
        name = Path(relative).name
        if name in {"package-lock.json", "npm-lock.json"}:
            return "npm-package-lock", self.parse_npm(relative, value)
        if name == "composer.lock":
            return "composer-lock", self.parse_composer(relative, value)
        if name == "dependency-lock.json":
            return "haxe-or-browser-dependency-lock", self.parse_dependency_lock(relative, value)
        if name == "source.lock.json":
            return "profile-source-lock", self.parse_source_lock(relative, value)
        if name == "haxelib.json":
            return "haxelib-manifest", self.parse_haxelib_manifest(relative, value)
        if name == "project.lock.json":
            return "wordpresshx-project-lock", self.parse_project_lock(relative, value)
        if relative == "docker/images.lock.json":
            return "oci-image-lock", self.parse_images(relative, value)
        if relative == "manifests/upstream.lock.json":
            return "upstream-source-lock", self.parse_upstream(relative, value)
        if relative == "manifests/toolchain.lock.json":
            return "aggregate-toolchain-lock", self.parse_toolchain(relative, value)
        if relative == "tooling/beads/history-reader.lock.json":
            return "git-source-lock", self.parse_beads_history(relative, value)
        return "policy-or-fixture-identity-lock", 0

    def bind_component_evidence(self) -> None:
        for evidence in self.component_evidence:
            evidence_id = evidence["id"]
            match = evidence["match"]
            ecosystem = match.get("ecosystem")
            name = match.get("name")
            version = match.get("version")
            resolution = match.get("resolution")
            if not all(
                isinstance(value, str)
                for value in (ecosystem, name, version, resolution)
            ):
                raise ValueError(
                    f"{COMPONENT_EVIDENCE}: incomplete match for {evidence_id}"
                )
            candidates = [
                component
                for component in self.components.values()
                if component.name == name and component.version == version
            ]
            if not candidates or not any(
                component.ecosystem == ecosystem
                and component.resolution == resolution
                for component in candidates
            ):
                raise ValueError(
                    f"{COMPONENT_EVIDENCE}: no exact lock match for {evidence_id}"
                )
            license_evidence = evidence["licenseEvidence"]
            observed = license_evidence.get("observedExpression")
            if not isinstance(observed, str) or not observed:
                raise ValueError(
                    f"{COMPONENT_EVIDENCE}: observed expression required for {evidence_id}"
                )
            for component in candidates:
                component.declared_licenses.add(observed)
                component.exact_evidence_ids.add(evidence_id)

    def build(self) -> tuple[dict[str, object], dict[str, object]]:
        for relative in inventory_sources(self.root):
            path = self.root / relative
            value = read_object(path)
            parser, component_count = self.parse(relative, value)
            self.source_records.append(
                {
                    "path": relative,
                    "sha256": sha256_bytes(path.read_bytes()),
                    "parser": parser,
                    "componentObservationCount": component_count,
                }
            )

        self.bind_component_evidence()
        component_values = [
            component.as_json()
            for component in sorted(
                self.components.values(),
                key=lambda value: (
                    value.ecosystem,
                    value.name,
                    value.version,
                    value.resolution,
                ),
            )
        ]
        unresolved = [
            value["id"]
            for value in component_values
            if value["licenseEvidenceStatus"]
            == "missing-license-declaration-publication-blocked"
        ]
        source_observations = sum(
            int(value["componentObservationCount"]) for value in self.source_records
        )
        inventory: dict[str, object] = {
            "schemaVersion": SCHEMA_VERSION,
            "inventoryId": "wordpresshx-lock-derived-build-inputs-v1",
            "status": "complete-lock-derived-publication-blocked",
            "generatedBy": {
                "path": GENERATOR,
                "algorithm": "tracked-lock-discovery-and-normalization-v1",
            },
            "scope": {
                "claim": "every recognized tracked dependency/source/toolchain lock",
                "finalArtifactConclusion": False,
                "publicationAuthorized": False,
                "artifactSpecificInventoryRequired": True,
            },
            "sources": self.source_records,
            "components": component_values,
            "unresolvedLicenseEvidence": unresolved,
            "summary": {
                "sourceCount": len(self.source_records),
                "componentObservationCount": source_observations,
                "uniqueComponentCount": len(component_values),
                "unresolvedLicenseEvidenceCount": len(unresolved),
            },
        }
        sbom = self.spdx(component_values, inventory)
        return inventory, sbom

    def spdx(
        self, components: list[dict[str, object]], inventory: dict[str, object]
    ) -> dict[str, object]:
        inventory_digest = sha256_bytes(canonical_json(inventory))
        packages: list[dict[str, object]] = []
        relationships: list[dict[str, str]] = []
        for component in components:
            component_id = str(component["id"])
            spdx_id = "SPDXRef-Package-" + sha256_bytes(component_id.encode("utf-8"))[:20]
            packages.append(
                {
                    "SPDXID": spdx_id,
                    "name": component["name"],
                    "versionInfo": component["version"],
                    "downloadLocation": "NOASSERTION",
                    "filesAnalyzed": False,
                    "licenseConcluded": "NOASSERTION",
                    "licenseDeclared": "NOASSERTION",
                    "copyrightText": "NOASSERTION",
                    "comment": (
                        "Lock-derived build/test/source input only; declared "
                        "metadata is preserved in the companion inventory and "
                        "is not promoted to an SPDX conclusion here. This is not "
                        "a final artifact license conclusion. Inventory component: "
                        f"{component_id}"
                    ),
                    "externalRefs": [
                        {
                            "referenceCategory": "PACKAGE-MANAGER",
                            "referenceType": "purl",
                            "referenceLocator": (
                                f"pkg:generic/{quote(str(component['name']), safe='@._-')}"
                                f"@{quote(str(component['version']), safe='._+-')}"
                                f"?ecosystem={quote(str(component['ecosystem']), safe='._-')}"
                            ),
                        }
                    ],
                }
            )
            relationships.append(
                {
                    "spdxElementId": "SPDXRef-DOCUMENT",
                    "relationshipType": "DESCRIBES",
                    "relatedSpdxElement": spdx_id,
                }
            )
        namespace = (
            "https://wordpress-hx.dev/spdx/build-inputs/"
            + inventory_digest
        )
        return {
            "spdxVersion": "SPDX-2.3",
            "dataLicense": "CC0-1.0",
            "SPDXID": "SPDXRef-DOCUMENT",
            "name": "WordPressHx lock-derived build inputs",
            "documentNamespace": namespace,
            "creationInfo": {
                "created": "1970-01-01T00:00:00Z",
                "creators": [f"Tool: {GENERATOR}"],
                "licenseListVersion": "3.25",
                "comment": (
                    "The fixed timestamp makes the evidence deterministic. "
                    "Source lock hashes and exact component observations are in "
                    f"{DEFAULT_INVENTORY}."
                ),
            },
            "documentComment": (
                "Publication remains blocked. This build-input SBOM does not "
                "classify bytes in a final WordPressHx artifact."
            ),
            "packages": packages,
            "relationships": relationships,
        }


def compare(path: Path, expected: bytes) -> str | None:
    try:
        actual = path.read_bytes()
    except OSError as error:
        return f"{path}: cannot read generated inventory: {error}"
    if actual != expected:
        return f"{path}: stale; run {GENERATOR} --write"
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    default_root = Path(__file__).resolve().parents[2]
    parser.add_argument("--root", type=Path, default=default_root)
    parser.add_argument("--inventory", default=DEFAULT_INVENTORY)
    parser.add_argument("--sbom", default=DEFAULT_SBOM)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    inventory_path = root / args.inventory
    sbom_path = root / args.sbom
    try:
        inventory, sbom = InventoryBuilder(root).build()
    except (OSError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print(f"build-input inventory error: {error}", file=sys.stderr)
        return 1

    inventory_bytes = canonical_json(inventory)
    sbom_bytes = canonical_json(sbom)
    if args.write:
        inventory_path.parent.mkdir(parents=True, exist_ok=True)
        sbom_path.parent.mkdir(parents=True, exist_ok=True)
        inventory_path.write_bytes(inventory_bytes)
        sbom_path.write_bytes(sbom_bytes)
    else:
        errors = [
            error
            for error in (
                compare(inventory_path, inventory_bytes),
                compare(sbom_path, sbom_bytes),
            )
            if error is not None
        ]
        if errors:
            for error in errors:
                print(f"build-input inventory error: {error}", file=sys.stderr)
            return 1

    summary = inventory["summary"]
    print(
        "build-input inventory passed: "
        f"{summary['sourceCount']} sources, "
        f"{summary['componentObservationCount']} observations, "
        f"{summary['uniqueComponentCount']} unique components, "
        f"{summary['unresolvedLicenseEvidenceCount']} unresolved"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
