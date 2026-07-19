#!/usr/bin/env python3
"""Exercise ADR-017 with closed-policy mutations and real temporary Git repos."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "scripts/generated-output-vcs/check-policy.py"
POLICY_PATH = ROOT / "manifests/generated-output-vcs-policy.json"
RECEIPT_PATH = ROOT / "manifests/evidence/adr-017-generated-output-vcs-policy.json"
FIXTURE = ROOT / "fixtures/generated-output-vcs/project"
COMMITTED_OUTPUT_POLICY_FIXTURE = (
    ROOT / "fixtures/generated-output-vcs/committed-output-policy.json"
)

SOURCE_PATH = Path("src/acme/site/Site.hx")
LOCK_PATH = Path("wordpress-hx.fixture-lock.json")
MANIFEST_NAME = "generated-files.fixture.json"
PROJECT_OUTPUT_POLICY_PATH = Path("wordpress-hx.generated-output-vcs.json")
EXPECTED_GENERATED_PATHS = ["assets/site.js", "plugin/site.php"]
POLICY_MUTATION_COUNT = 19
RECEIPT_MUTATION_COUNT = 4
PORTABLE_SEGMENT = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?")


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def run(
    arguments: list[str], cwd: Path, *, check: bool = True
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        arguments,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command failed ({result.returncode}): {' '.join(arguments)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def git(repository: Path, *arguments: str, check: bool = True) -> str:
    return run(["git", *arguments], repository, check=check).stdout.strip()


def initialize_git(repository: Path, message: str = "fixture baseline") -> None:
    git(repository, "init", "--quiet", "--initial-branch=main")
    git(repository, "config", "user.name", "ADR-017 Fixture")
    git(repository, "config", "user.email", "adr-017-fixture@example.invalid")
    git(repository, "add", "--all")
    git(repository, "commit", "--quiet", "--message", message)


def copy_fixture(destination: Path) -> Path:
    shutil.copytree(FIXTURE, destination)
    return destination


def repository_head(repository: Path) -> str:
    return git(repository, "rev-parse", "HEAD")


def git_status(repository: Path) -> list[str]:
    output = run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"], repository
    ).stdout
    return output.splitlines()


def require_clean(repository: Path) -> None:
    status = git_status(repository)
    if status:
        raise ValueError(f"release source is not clean: {status}")


def load_lock(project: Path) -> dict[str, object]:
    value = json.loads((project / LOCK_PATH).read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError("fixture lock must be an object")
    expected_keys = {
        "schemaVersion",
        "fixtureOnly",
        "sdkIdentity",
        "generatorIdentity",
        "profileIdentity",
    }
    expect(set(value) == expected_keys, "fixture lock fields drifted")
    expect(value["schemaVersion"] == 1, "fixture lock schema drifted")
    expect(value["fixtureOnly"] is True, "fixture lock must remain fixture-only")
    return value


def validate_project_output_policy(
    project: Path, expected_roots: list[str]
) -> dict[str, object]:
    policy_path = project / PROJECT_OUTPUT_POLICY_PATH
    try:
        policy = json.loads(policy_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"explicit committed-output policy is missing or invalid: {error}") from error
    if not isinstance(policy, dict):
        raise ValueError("explicit committed-output policy must be an object")
    expected_keys = {
        "schemaVersion",
        "policyId",
        "mode",
        "outputRoots",
        "manifestPath",
        "authority",
        "handEditsAllowed",
        "fixtureOnly",
    }
    if set(policy) != expected_keys:
        raise ValueError("explicit committed-output policy fields are not closed")
    if policy["schemaVersion"] != 1:
        raise ValueError("explicit committed-output policy schema differs")
    if policy["policyId"] != "wordpress-hx.generated-output-vcs-project.v1":
        raise ValueError("explicit committed-output policy identity differs")
    if policy["mode"] != "consumer-committed-output-opt-in":
        raise ValueError("explicit committed-output policy mode differs")
    if policy["authority"] != "haxe-and-exact-locks":
        raise ValueError("explicit committed-output authority differs")
    if policy["handEditsAllowed"] is not False or policy["fixtureOnly"] is not True:
        raise ValueError("explicit committed-output safety boundary differs")
    roots = policy.get("outputRoots")
    if (
        not isinstance(roots, list)
        or not roots
        or roots != sorted(set(roots))
        or roots != expected_roots
    ):
        raise ValueError("explicit committed-output roots are absent, extra, or unordered")
    for root in roots:
        if not isinstance(root, str) or root == "" or root.startswith("/") or "\\" in root:
            raise ValueError("explicit committed-output root is not project-relative")
        segments = root.split("/")
        if any(
            segment in {"", ".", ".."} or PORTABLE_SEGMENT.fullmatch(segment) is None
            for segment in segments
        ):
            raise ValueError("explicit committed-output root is not portable")
    for index, root in enumerate(roots):
        for other in roots[index + 1 :]:
            if other.startswith(root + "/"):
                raise ValueError("explicit committed-output roots may not nest")
    expected_manifest = roots[0] + "/" + MANIFEST_NAME
    if policy["manifestPath"] != expected_manifest:
        raise ValueError("explicit committed-output manifest path differs")
    return policy


def render_artifacts(project: Path) -> dict[str, bytes]:
    source = (project / SOURCE_PATH).read_bytes()
    lock_bytes = (project / LOCK_PATH).read_bytes()
    lock = load_lock(project)
    source_digest = sha256_bytes(source)
    lock_digest = sha256_bytes(lock_bytes)
    php = (
        "<?php\n"
        "// Synthetic ADR-017 VCS fixture; not production compiler output.\n"
        "return [\n"
        f"    'sourceSha256' => '{source_digest}',\n"
        f"    'lockSha256' => '{lock_digest}',\n"
        f"    'profile' => '{lock['profileIdentity']}',\n"
        "];\n"
    ).encode("utf-8")
    javascript = (
        "// Synthetic ADR-017 VCS fixture; not Genes output.\n"
        f"export const sourceSha256 = \"{source_digest}\";\n"
        f"export const lockSha256 = \"{lock_digest}\";\n"
        f"export const profile = \"{lock['profileIdentity']}\";\n"
    ).encode("utf-8")
    return {
        "assets/site.js": javascript,
        "plugin/site.php": php,
    }


def generate_tree(project: Path, output: Path) -> dict[str, object]:
    artifacts = render_artifacts(project)
    lock = load_lock(project)
    source_bytes = (project / SOURCE_PATH).read_bytes()
    lock_bytes = (project / LOCK_PATH).read_bytes()
    output.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, object]] = []
    for relative in sorted(artifacts):
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(artifacts[relative])
        entries.append(
            {
                "path": relative,
                "sha256": sha256_bytes(artifacts[relative]),
                "byteSize": len(artifacts[relative]),
            }
        )
    manifest_without_digest: dict[str, object] = {
        "schemaVersion": 1,
        "manifestId": "wordpress-hx.adr-017-fixture-generated-files.v1",
        "fixtureOnly": True,
        "source": {
            "path": SOURCE_PATH.as_posix(),
            "sha256": sha256_bytes(source_bytes),
        },
        "toolchain": {
            "lockPath": LOCK_PATH.as_posix(),
            "lockSha256": sha256_bytes(lock_bytes),
            "sdkIdentity": lock["sdkIdentity"],
            "generatorIdentity": lock["generatorIdentity"],
            "profileIdentity": lock["profileIdentity"],
        },
        "files": entries,
    }
    manifest = {
        **manifest_without_digest,
        "manifestDigest": sha256_bytes(canonical_json(manifest_without_digest)),
    }
    (output / MANIFEST_NAME).write_bytes(canonical_json(manifest))
    return manifest


def generated_files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def compare_trees(expected: Path, actual: Path) -> None:
    expected_files = generated_files(expected)
    actual_files = generated_files(actual)
    if expected_files != actual_files:
        expected_paths = sorted(expected_files)
        actual_paths = sorted(actual_files)
        differing = sorted(
            path
            for path in set(expected_files) & set(actual_files)
            if expected_files[path] != actual_files[path]
        )
        raise ValueError(
            "generated tree drift: "
            f"expectedPaths={expected_paths} actualPaths={actual_paths} "
            f"differentBytes={differing}"
        )


def validate_generated_tree(project: Path, output: Path) -> dict[str, object]:
    manifest_path = output / MANIFEST_NAME
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"generated manifest is missing or invalid: {error}") from error
    if not isinstance(manifest, dict):
        raise ValueError("generated manifest must be an object")
    expected_manifest_keys = {
        "schemaVersion",
        "manifestId",
        "fixtureOnly",
        "source",
        "toolchain",
        "files",
        "manifestDigest",
    }
    if set(manifest) != expected_manifest_keys:
        raise ValueError("generated manifest fields are not closed")
    manifest_without_digest = {
        key: value for key, value in manifest.items() if key != "manifestDigest"
    }
    expected_digest = sha256_bytes(canonical_json(manifest_without_digest))
    if manifest["manifestDigest"] != expected_digest:
        raise ValueError("generated manifest self-digest differs")
    if manifest["schemaVersion"] != 1 or manifest["fixtureOnly"] is not True:
        raise ValueError("generated manifest identity differs")

    source = manifest.get("source")
    if not isinstance(source, dict) or set(source) != {"path", "sha256"}:
        raise ValueError("generated manifest source identity is invalid")
    if source["path"] != SOURCE_PATH.as_posix():
        raise ValueError("generated manifest source path differs")
    if source["sha256"] != sha256_bytes((project / SOURCE_PATH).read_bytes()):
        raise ValueError("generated manifest source digest differs")

    lock = load_lock(project)
    toolchain = manifest.get("toolchain")
    expected_toolchain = {
        "lockPath": LOCK_PATH.as_posix(),
        "lockSha256": sha256_bytes((project / LOCK_PATH).read_bytes()),
        "sdkIdentity": lock["sdkIdentity"],
        "generatorIdentity": lock["generatorIdentity"],
        "profileIdentity": lock["profileIdentity"],
    }
    if toolchain != expected_toolchain:
        raise ValueError("generated manifest toolchain provenance differs")

    entries = manifest.get("files")
    if not isinstance(entries, list):
        raise ValueError("generated manifest files must be an array")
    paths = [entry.get("path") for entry in entries if isinstance(entry, dict)]
    if paths != EXPECTED_GENERATED_PATHS:
        raise ValueError("generated manifest path set differs")
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"path", "sha256", "byteSize"}:
            raise ValueError("generated manifest file entry is invalid")
        artifact = output / str(entry["path"])
        if not artifact.is_file():
            raise ValueError(f"generated artifact is missing: {entry['path']}")
        value = artifact.read_bytes()
        if entry["sha256"] != sha256_bytes(value) or entry["byteSize"] != len(value):
            raise ValueError(f"generated artifact differs: {entry['path']}")
    expected_live_paths = [MANIFEST_NAME, *EXPECTED_GENERATED_PATHS]
    if sorted(generated_files(output)) != sorted(expected_live_paths):
        raise ValueError("generated output contains undeclared files")
    return manifest


def deterministic_zip(source: Path, destination: Path) -> bytes:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        destination,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for relative, value in sorted(generated_files(source).items()):
            info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, value)
    return destination.read_bytes()


def expect_value_error(operation: Callable[[], object], context: str) -> None:
    try:
        operation()
    except ValueError:
        return
    raise AssertionError(f"{context} unexpectedly passed")


def load_checker_module() -> Any:
    specification = importlib.util.spec_from_file_location(
        "wordpresshx_generated_output_vcs_checker", CHECKER
    )
    if specification is None or specification.loader is None:
        raise AssertionError("cannot load generated-output VCS checker")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def run_checker(policy_path: Path = POLICY_PATH) -> subprocess.CompletedProcess[str]:
    return run(
        [sys.executable, str(CHECKER), "--policy", str(policy_path)],
        ROOT,
        check=False,
    )


def run_policy_mutations(policy: dict[str, Any]) -> None:
    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        (
            "allow-hand-edits",
            lambda value: value["authority"].__setitem__(
                "handEditGeneratedOutputAllowed", True
            ),
        ),
        (
            "promote-generated-authority",
            lambda value: value["authority"].__setitem__(
                "generatedBytesMaySupersedeAuthoredSource", True
            ),
        ),
        (
            "same-bytes-own",
            lambda value: value["authority"].__setitem__("sameBytesGrantOwnership", True),
        ),
        (
            "consumer-commit-default",
            lambda value: next(
                mode for mode in value["repositoryModes"] if mode["id"] == "consumer-default"
            ).__setitem__(
                "generatedOutputAdmission", "all-generated-output"
            ),
        ),
        (
            "opt-in-becomes-default",
            lambda value: next(
                mode
                for mode in value["repositoryModes"]
                if mode["id"] == "consumer-committed-output-opt-in"
            ).__setitem__("selectedByDefault", True),
        ),
        (
            "consumer-stops-ignoring-output",
            lambda value: next(
                mode for mode in value["repositoryModes"] if mode["id"] == "consumer-default"
            )["ignores"].remove("runtime-and-deployment-output"),
        ),
        (
            "consumer-drops-haxe-authority",
            lambda value: next(
                mode for mode in value["repositoryModes"] if mode["id"] == "consumer-default"
            )["commits"].remove("authored-haxe-and-hand-owned-assets"),
        ),
        (
            "consumer-adds-unknown-artifact-class",
            lambda value: next(
                mode for mode in value["repositoryModes"] if mode["id"] == "consumer-default"
            )["commits"].append("unknown-generated-class"),
        ),
        (
            "opt-in-drops-required-metadata",
            lambda value: next(
                mode
                for mode in value["repositoryModes"]
                if mode["id"] == "consumer-committed-output-opt-in"
            )["requiredMetadata"].remove("exact-generated-manifest"),
        ),
        (
            "opt-in-commit-ignore-overlap",
            lambda value: next(
                mode
                for mode in value["repositoryModes"]
                if mode["id"] == "consumer-committed-output-opt-in"
            )["ignores"].append("runtime-and-deployment-output"),
        ),
        (
            "opt-in-skips-byte-compare",
            lambda value: next(
                mode
                for mode in value["repositoryModes"]
                if mode["id"] == "consumer-committed-output-opt-in"
            ).__setitem__("requiredGate", "review-only"),
        ),
        (
            "sdk-admits-unclassified-output",
            lambda value: next(
                mode for mode in value["repositoryModes"] if mode["id"] == "sdk"
            ).__setitem__("generatedOutputAdmission", "any-generated-file"),
        ),
        (
            "drop-drift-stage",
            lambda value: value["driftWorkflow"]["steps"].pop(),
        ),
        (
            "drop-manual-edit-failure",
            lambda value: value["driftWorkflow"]["failureConditions"].remove(
                "manual-generated-file-edit"
            ),
        ),
        (
            "trust-working-output",
            lambda value: value["releaseProtocol"].__setitem__(
                "workingTreeGeneratedOutputTrusted", True
            ),
        ),
        (
            "single-regeneration",
            lambda value: value["releaseProtocol"].__setitem__("regenerationRuns", 1),
        ),
        (
            "single-archive",
            lambda value: value["releaseProtocol"].__setitem__("archiveBuilds", 1),
        ),
        (
            "relax-release-invariant",
            lambda value: value["changeControl"].__setitem__(
                "releaseRegenerationMayBeRelaxed", True
            ),
        ),
        (
            "invent-production-proof",
            lambda value: value["claims"].__setitem__(
                "productionSupport", "runtime-tested"
            ),
        ),
    ]
    expect(len(mutations) == POLICY_MUTATION_COUNT, "policy mutation count drifted")
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr017-mutations-") as temporary:
        mutation_root = Path(temporary)
        for name, mutate in mutations:
            candidate = copy.deepcopy(policy)
            mutate(candidate)
            candidate_path = mutation_root / f"{name}.json"
            candidate_path.write_text(
                json.dumps(candidate, indent=2) + "\n", encoding="utf-8"
            )
            result = run_checker(candidate_path)
            expect(result.returncode == 1, f"policy mutation {name} unexpectedly passed")
            expect(
                "generated-output VCS policy error:" in result.stderr,
                f"policy mutation {name} lacked a fail-closed diagnostic",
            )


def exercise_consumer_default(workspace: Path) -> None:
    project = copy_fixture(workspace / "consumer-default")
    initialize_git(project)
    first = project / "build"
    second = workspace / "consumer-default-second"
    generate_tree(project, first)
    generate_tree(project, second)
    validate_generated_tree(project, first)
    compare_trees(first, second)
    archive = deterministic_zip(first, project / "dist/site.zip")
    expect(len(archive) > 0, "default consumer archive was empty")
    for ignored in ("build/plugin/site.php", "dist/site.zip"):
        result = run(["git", "check-ignore", "--quiet", ignored], project, check=False)
        expect(result.returncode == 0, f"default consumer did not ignore {ignored}")
    expect(git_status(project) == [], "ignored consumer output dirtied the checkout")

    original = generated_files(first)
    source_path = project / SOURCE_PATH
    source_path.write_text(
        source_path.read_text(encoding="utf-8").replace(
            "Typed Observatory", "Typed Observatory Changed"
        ),
        encoding="utf-8",
    )
    shutil.rmtree(first)
    generate_tree(project, first)
    expect(generated_files(first) != original, "source change did not change generated bytes")
    status = git_status(project)
    expect(status == [f" M {SOURCE_PATH.as_posix()}"], "ignored output leaked into Git status")


def exercise_sdk_goldens(workspace: Path) -> None:
    project = copy_fixture(workspace / "sdk")
    initialize_git(project)
    candidate = workspace / "sdk-candidate"
    generate_tree(project, candidate)
    expected = project / "expected"
    shutil.copytree(candidate, expected)
    git(project, "add", "expected")
    git(project, "commit", "--quiet", "--message", "reviewed generated contract")

    fresh = workspace / "sdk-fresh"
    generate_tree(project, fresh)
    validate_generated_tree(project, fresh)
    compare_trees(expected, fresh)

    php_path = expected / "plugin/site.php"
    php_path.write_bytes(php_path.read_bytes() + b"// hand edit\n")
    expect_value_error(lambda: compare_trees(expected, fresh), "SDK golden hand edit")
    shutil.rmtree(expected)
    shutil.copytree(fresh, expected)

    source_path = project / SOURCE_PATH
    source_path.write_text(
        source_path.read_text(encoding="utf-8").replace(
            "Typed Observatory", "Golden Drift"
        ),
        encoding="utf-8",
    )
    changed = workspace / "sdk-changed"
    generate_tree(project, changed)
    expect_value_error(lambda: compare_trees(expected, changed), "stale SDK golden")


def exercise_consumer_opt_in(workspace: Path) -> None:
    project = copy_fixture(workspace / "consumer-opt-in")
    initialize_git(project)
    output = project / "generated"
    generate_tree(project, output)
    validate_generated_tree(project, output)
    git(project, "add", "generated")
    expect_value_error(
        lambda: validate_project_output_policy(project, ["generated"]),
        "tracked generated-looking files without explicit opt-in",
    )
    shutil.copy2(
        COMMITTED_OUTPUT_POLICY_FIXTURE,
        project / PROJECT_OUTPUT_POLICY_PATH,
    )
    valid_policy_bytes = (project / PROJECT_OUTPUT_POLICY_PATH).read_bytes()
    validate_project_output_policy(project, ["generated"])
    expect_value_error(
        lambda: validate_project_output_policy(project, ["generated", "other"]),
        "extra inferred committed-output root",
    )

    policy_path = project / PROJECT_OUTPUT_POLICY_PATH
    missing_roots = json.loads(valid_policy_bytes)
    missing_roots["outputRoots"] = []
    policy_path.write_bytes(canonical_json(missing_roots))
    expect_value_error(
        lambda: validate_project_output_policy(project, []),
        "absent committed-output roots",
    )
    nested_roots = json.loads(valid_policy_bytes)
    nested_roots["outputRoots"] = ["generated", "generated/nested"]
    policy_path.write_bytes(canonical_json(nested_roots))
    expect_value_error(
        lambda: validate_project_output_policy(
            project, ["generated", "generated/nested"]
        ),
        "nested committed-output roots",
    )
    policy_path.write_bytes(valid_policy_bytes)
    validate_project_output_policy(project, ["generated"])
    git(project, "add", PROJECT_OUTPUT_POLICY_PATH.as_posix())
    git(project, "commit", "--quiet", "--message", "explicit generated-output opt-in")

    fresh = workspace / "consumer-opt-in-fresh"
    generate_tree(project, fresh)
    compare_trees(output, fresh)
    expect(git_status(project) == [], "matching committed output was not clean")

    php_path = output / "plugin/site.php"
    php_path.write_bytes(php_path.read_bytes() + b"// manual edit\n")
    expect_value_error(
        lambda: validate_generated_tree(project, output),
        "hand-edited opt-in artifact",
    )
    expect_value_error(lambda: compare_trees(output, fresh), "opt-in byte drift")
    shutil.rmtree(output)
    shutil.copytree(fresh, output)

    source_path = project / SOURCE_PATH
    source_path.write_text(
        source_path.read_text(encoding="utf-8").replace(
            "Typed Observatory", "Opt-in Drift"
        ),
        encoding="utf-8",
    )
    changed = workspace / "consumer-opt-in-changed"
    generate_tree(project, changed)
    expect_value_error(
        lambda: validate_generated_tree(project, output),
        "stale opt-in source provenance",
    )
    expect_value_error(lambda: compare_trees(output, changed), "stale opt-in output")

    source_path.write_text(
        source_path.read_text(encoding="utf-8").replace(
            "Opt-in Drift", "Typed Observatory"
        ),
        encoding="utf-8",
    )
    manifest_path = output / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["toolchain"]["profileIdentity"] = "tampered-profile"
    manifest_without_digest = {
        key: value for key, value in manifest.items() if key != "manifestDigest"
    }
    manifest["manifestDigest"] = sha256_bytes(canonical_json(manifest_without_digest))
    manifest_path.write_bytes(canonical_json(manifest))
    expect_value_error(
        lambda: validate_generated_tree(project, output),
        "tampered opt-in provenance",
    )


def release_provenance(
    project: Path,
    source_commit: str,
    manifest_bytes: bytes,
    archive_bytes: bytes,
) -> dict[str, object]:
    lock = load_lock(project)
    material: dict[str, object] = {
        "schemaVersion": 1,
        "sourceCommit": source_commit,
        "toolchainLockSha256": sha256_bytes((project / LOCK_PATH).read_bytes()),
        "sdkIdentity": lock["sdkIdentity"],
        "generatorIdentity": lock["generatorIdentity"],
        "profileIdentity": lock["profileIdentity"],
        "generatedManifestSha256": sha256_bytes(manifest_bytes),
        "archiveSha256": sha256_bytes(archive_bytes),
    }
    return {
        **material,
        "provenanceDigest": sha256_bytes(canonical_json(material)),
    }


def validate_release_provenance(
    project: Path, report: dict[str, object], manifest_bytes: bytes, archive_bytes: bytes
) -> None:
    expected_keys = {
        "schemaVersion",
        "sourceCommit",
        "toolchainLockSha256",
        "sdkIdentity",
        "generatorIdentity",
        "profileIdentity",
        "generatedManifestSha256",
        "archiveSha256",
        "provenanceDigest",
    }
    expect(set(report) == expected_keys, "release provenance fields are not closed")
    expected = release_provenance(
        project,
        repository_head(project),
        manifest_bytes,
        archive_bytes,
    )
    expect(report == expected, "release provenance does not bind every exact identity")


def release_rehearsal(
    source_repository: Path,
    workspace: Path,
    *,
    committed_build_input: Path | None = None,
) -> dict[str, object]:
    require_clean(source_repository)
    workspace.mkdir(parents=True, exist_ok=True)
    source_commit = repository_head(source_repository)
    clones = [workspace / "release-clone-one", workspace / "release-clone-two"]
    stages = [workspace / "release-stage-one", workspace / "release-stage-two"]
    archives = [workspace / "release-one.zip", workspace / "release-two.zip"]
    for index, clone in enumerate(clones):
        run(
            [
                "git",
                "clone",
                "--quiet",
                "--no-local",
                str(source_repository),
                str(clone),
            ],
            workspace,
        )
        expect(repository_head(clone) == source_commit, "release clone identity drifted")
        cache_path = clone / ".wphx/private/cache.txt"
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(f"ambient-cache-{index}\n", encoding="utf-8")
        expect(git_status(clone) == [], "ignored ambient cache dirtied release clone")
        if committed_build_input is not None:
            candidate = workspace / f"build-input-candidate-{index}"
            generate_tree(clone, candidate)
            compare_trees(clone / committed_build_input, candidate)
        generate_tree(clone, stages[index])
        validate_generated_tree(clone, stages[index])
        deterministic_zip(stages[index], archives[index])
        expect(git_status(clone) == [], "release generation mutated its checkout")
    compare_trees(stages[0], stages[1])
    first_archive = archives[0].read_bytes()
    second_archive = archives[1].read_bytes()
    expect(first_archive == second_archive, "release archives were not byte-identical")
    require_clean(source_repository)
    first_manifest = (stages[0] / MANIFEST_NAME).read_bytes()
    report = release_provenance(
        source_repository,
        source_commit,
        first_manifest,
        first_archive,
    )
    validate_release_provenance(
        source_repository,
        report,
        first_manifest,
        first_archive,
    )
    return report


def exercise_release(workspace: Path) -> dict[str, object]:
    default_project = copy_fixture(workspace / "release-source-default")
    initialize_git(default_project)
    report = release_rehearsal(default_project, workspace / "default-replay")

    committed_project = copy_fixture(workspace / "release-source-committed-output")
    initialize_git(committed_project)
    shutil.copy2(
        COMMITTED_OUTPUT_POLICY_FIXTURE,
        committed_project / PROJECT_OUTPUT_POLICY_PATH,
    )
    validate_project_output_policy(committed_project, ["generated"])
    committed_output = committed_project / "generated"
    generate_tree(committed_project, committed_output)
    git(committed_project, "add", PROJECT_OUTPUT_POLICY_PATH.as_posix(), "generated")
    git(committed_project, "commit", "--quiet", "--message", "committed deployment output")
    committed_marker = b"tampered-committed-deployment-output"
    committed_php = committed_output / "plugin/site.php"
    committed_php.write_bytes(committed_php.read_bytes() + committed_marker + b"\n")
    git(committed_project, "add", "generated/plugin/site.php")
    git(committed_project, "commit", "--quiet", "--message", "stale committed deployment output")
    committed_workspace = workspace / "committed-output-replay"
    release_rehearsal(committed_project, committed_workspace)
    for generated_value in generated_files(
        committed_workspace / "release-stage-one"
    ).values():
        expect(
            committed_marker not in generated_value,
            "release consumed stale committed deployment output",
        )
    with zipfile.ZipFile(committed_workspace / "release-one.zip", mode="r") as archive:
        for name in archive.namelist():
            expect(
                committed_marker not in archive.read(name),
                "release archive consumed stale committed deployment output",
            )

    build_input_project = copy_fixture(workspace / "release-source-build-input")
    initialize_git(build_input_project)
    build_input = build_input_project / "bootstrap"
    generate_tree(build_input_project, build_input)
    git(build_input_project, "add", "bootstrap")
    git(build_input_project, "commit", "--quiet", "--message", "required generated build input")
    release_rehearsal(
        build_input_project,
        workspace / "build-input-valid-replay",
        committed_build_input=Path("bootstrap"),
    )
    build_input_php = build_input / "plugin/site.php"
    build_input_php.write_bytes(build_input_php.read_bytes() + b"// stale build input\n")
    git(build_input_project, "add", "bootstrap/plugin/site.php")
    git(build_input_project, "commit", "--quiet", "--message", "stale required build input")
    expect_value_error(
        lambda: release_rehearsal(
            build_input_project,
            workspace / "build-input-stale-replay",
            committed_build_input=Path("bootstrap"),
        ),
        "stale committed generated build input",
    )

    source_path = default_project / SOURCE_PATH
    source_path.write_text(
        source_path.read_text(encoding="utf-8").replace(
            "Typed Observatory", "Dirty Release"
        ),
        encoding="utf-8",
    )
    expect_value_error(
        lambda: release_rehearsal(default_project, workspace / "dirty-attempt"),
        "dirty release source",
    )
    return report


def validate_receipt(
    policy: dict[str, Any], receipt_path: Path = RECEIPT_PATH
) -> None:
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    expect(
        set(receipt)
        == {
            "schemaVersion",
            "receiptId",
            "bead",
            "observedAt",
            "subject",
            "contract",
            "verification",
            "referenceReview",
            "freshEyesReview",
            "hostedWorkflow",
            "limitations",
            "claims",
        },
        "ADR-017 receipt fields drifted",
    )
    expect(receipt["schemaVersion"] == 1, "ADR-017 receipt schema drifted")
    expect(
        receipt["receiptId"] == "ADR-017-GENERATED-OUTPUT-VCS-POLICY",
        "ADR-017 receipt identity drifted",
    )
    expect(receipt["bead"] == "wordpresshx-adr-017", "ADR-017 receipt bead drifted")
    for subject in receipt["subject"].values():
        subject_path = ROOT / subject["path"]
        expect(subject_path.is_file(), f"receipt subject is missing: {subject_path}")
        expect(
            sha256_bytes(subject_path.read_bytes()) == subject["sha256"],
            f"receipt subject digest differs: {subject['path']}",
        )
    contract = receipt["contract"]
    expected_contract = {
        "policyId": policy["policyId"],
        "ownershipContract": policy["authority"]["ownershipContract"],
        "consumerDefault": "ignore-and-regenerate",
        "consumerCommittedOutput": "explicit-per-root-opt-in",
        "sdkCommittedOutput": "review-contract-or-required-build-input-only",
        "handEditGeneratedOutputAllowed": False,
        "releaseTrustsCommittedOrWorkingOutput": False,
        "releaseRegenerationRuns": 2,
        "releaseArchiveBuilds": 2,
        "publicationAuthorized": False,
    }
    expect(contract == expected_contract, "ADR-017 receipt contract is not exact")

    verification = receipt["verification"]
    expect(
        verification["command"]
        == "python3 scripts/generated-output-vcs/test-policy.py",
        "receipt command drifted",
    )
    expect(
        verification["policyMutationCount"] == POLICY_MUTATION_COUNT,
        "receipt mutation count drifted",
    )
    expect(
        verification["receiptMutationCount"] == RECEIPT_MUTATION_COUNT,
        "receipt security mutation count drifted",
    )
    expect(verification["repositoryModeCount"] == 3, "receipt mode count drifted")
    expect(verification["generatedArtifactCount"] == 2, "receipt artifact count drifted")
    expect(verification["gitRepositoryCount"] == 13, "receipt Git repository count drifted")
    expect(verification["releaseCloneCount"] == 7, "receipt release clone count drifted")
    expect(verification["releaseScenarioCount"] == 5, "receipt release scenario count drifted")
    expect(
        verification["explicitRootPolicyNegativeCount"] == 4,
        "receipt explicit-root negative count drifted",
    )
    for result in (
        "defaultConsumerIgnoreAndRegenerate",
        "sdkGoldenDrift",
        "consumerOptInDriftAndProvenance",
        "cleanReleaseDoubleReplay",
        "dirtyReleaseRejection",
        "ambientCacheIsolation",
        "checkoutNonMutation",
        "committedDeploymentOutputIgnored",
        "committedBuildInputFreshComparison",
        "staleCommittedBuildInputRejection",
        "releaseProvenanceBinding",
        "outcome",
    ):
        expect(verification[result] == "passed", f"receipt {result} did not pass")
    references = receipt["referenceReview"]
    expect(references["repositoryCount"] == 3, "receipt reference count drifted")
    expect(references["exactCommitPathBlobAndSha256Recorded"] is True, "reference identities not exact")
    expect(references["codeOrFixtureBytesCopied"] is False, "receipt claims copied bytes")
    expect(references["runtimeOrBuildDependencyCreated"] is False, "receipt claims a sibling dependency")
    expect(
        receipt["freshEyesReview"]
        == {
            "reviewer": "Codex fresh-eyes subagent",
            "modelFamilyIndependenceClaimed": False,
            "initialBlockingFindingCount": 5,
            "initialLowerRiskFindingCount": 3,
            "blockingFindingsResolvedBeforeCommit": True,
            "scope": [
                "acceptance-and-stop-condition",
                "evidence-and-overclaim-boundaries",
                "policy-and-test-consistency",
                "release-and-version-control-security",
            ],
        },
        "fresh-eyes review record differs",
    )

    hosted = receipt["hostedWorkflow"]
    expect(hosted["workflow"] == "Repository bootstrap", "hosted workflow drifted")
    expect(hosted["job"] == "generated-output-vcs", "hosted job drifted")
    expect(hosted["required"] is True, "hosted proof must be required")
    if hosted["status"] == "pending-first-hosted-main-run":
        expect(hosted["runId"] is None, "pending hosted run has an ID")
        expect(hosted["jobId"] is None, "pending hosted job has an ID")
        expect(hosted["commit"] is None, "pending hosted run has a commit")
        expect(
            policy["status"] == "proposed-hosted-evidence-pending",
            "pending hosted evidence cannot accompany an accepted policy",
        )
        expect(
            policy["claims"]["architectureDecision"]
            == "proposed-hosted-evidence-pending",
            "pending hosted evidence cannot claim an accepted decision",
        )
        expect(
            "- Status: proposed" in (
                ROOT / "docs/adr/017-generated-output-version-control-policy.md"
            ).read_text(encoding="utf-8"),
            "pending hosted evidence requires a proposed ADR",
        )
    elif hosted["status"] == "passed":
        expect(isinstance(hosted["runId"], int), "passed hosted run lacks an ID")
        expect(isinstance(hosted["jobId"], int), "passed hosted job lacks an ID")
        expect(
            isinstance(hosted["commit"], str) and len(hosted["commit"]) == 40,
            "passed hosted run lacks a commit",
        )
        expect(policy["status"] == "accepted", "passed hosted evidence requires acceptance")
        expect(
            policy["claims"]["architectureDecision"] == "accepted",
            "passed hosted evidence requires an accepted decision claim",
        )
        expect(
            "- Status: accepted" in (
                ROOT / "docs/adr/017-generated-output-version-control-policy.md"
            ).read_text(encoding="utf-8"),
            "passed hosted evidence requires an accepted ADR",
        )
    else:
        raise AssertionError("hosted ADR-017 status is invalid")
    expect(
        receipt["claims"] == policy["claims"],
        "receipt claims exceed or differ from the policy",
    )


def run_receipt_mutations(policy: dict[str, Any]) -> None:
    receipt = json.loads(RECEIPT_PATH.read_text(encoding="utf-8"))
    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        (
            "allow-generated-hand-edits",
            lambda value: value["contract"].__setitem__(
                "handEditGeneratedOutputAllowed", True
            ),
        ),
        (
            "trust-committed-release-output",
            lambda value: value["contract"].__setitem__(
                "releaseTrustsCommittedOrWorkingOutput", True
            ),
        ),
        (
            "authorize-publication",
            lambda value: value["contract"].__setitem__(
                "publicationAuthorized", True
            ),
        ),
        (
            "widen-sdk-generated-output",
            lambda value: value["contract"].__setitem__(
                "sdkCommittedOutput", "all-generated-output"
            ),
        ),
    ]
    expect(len(mutations) == RECEIPT_MUTATION_COUNT, "receipt mutation count drifted")
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr017-receipt-") as temporary:
        mutation_root = Path(temporary)
        for name, mutate in mutations:
            candidate = copy.deepcopy(receipt)
            mutate(candidate)
            candidate_path = mutation_root / f"{name}.json"
            candidate_path.write_text(
                json.dumps(candidate, indent=2) + "\n", encoding="utf-8"
            )
            try:
                validate_receipt(policy, candidate_path)
            except AssertionError:
                continue
            raise AssertionError(f"receipt mutation {name} unexpectedly passed")


def main() -> int:
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    checker = load_checker_module()
    expect(checker.validate_policy(policy) == [], "in-process policy validation failed")
    workflow = (ROOT / ".github/workflows/repository.yml").read_text(encoding="utf-8")
    expect("  generated-output-vcs:\n" in workflow, "hosted ADR-017 job is missing")
    expect(
        "Validate generated-output VCS and clean release replay policy" in workflow,
        "hosted ADR-017 step is missing",
    )
    expect(
        "python3 scripts/generated-output-vcs/test-policy.py" in workflow,
        "hosted ADR-017 command is missing",
    )
    normal = run_checker()
    expect(normal.returncode == 0, f"policy checker failed:\n{normal.stderr}")
    run_policy_mutations(policy)

    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr017-git-") as temporary:
        workspace = Path(temporary)
        exercise_consumer_default(workspace)
        exercise_sdk_goldens(workspace)
        exercise_consumer_opt_in(workspace)
        release_report = exercise_release(workspace)
        expect(
            isinstance(release_report["sourceCommit"], str)
            and len(release_report["sourceCommit"]) == 40,
            "release source was not commit-bound",
        )
        expect(
            isinstance(release_report["generatedManifestSha256"], str)
            and len(release_report["generatedManifestSha256"]) == 64,
            "release manifest was not digest-bound",
        )
        expect(
            isinstance(release_report["archiveSha256"], str)
            and len(release_report["archiveSha256"]) == 64,
            "release archive was not digest-bound",
        )
        expect(
            isinstance(release_report["provenanceDigest"], str)
            and len(release_report["provenanceDigest"]) == 64,
            "release provenance was not self-bound",
        )

    validate_receipt(policy)
    run_receipt_mutations(policy)
    print(
        "ADR-017 generated-output VCS tests passed: "
        f"3 repository modes, {POLICY_MUTATION_COUNT} policy mutations, "
        f"{RECEIPT_MUTATION_COUNT} receipt mutations, 13 Git repositories, "
        "2 generated artifacts, 7 clean release clones"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
