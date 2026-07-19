#!/usr/bin/env python3
"""Exercise production wphx committed output with real Git and generated PHP."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = Path(".wphx/generated-output-vcs.json")
MANIFEST_PATH = Path("build/wordpress/_GeneratedFiles.json")
EVIDENCE_RECEIPT = ROOT / "manifests/evidence/sdk-045-generated-output-vcs.json"
BEGIN = "# BEGIN wordpress-hx committed generated output"
END = "# END wordpress-hx committed generated output"


def canonical(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode()


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def exact_environment() -> dict[str, str]:
    candidates: list[Path] = []
    configured = os.environ.get("WORDPRESSHX_EXACT_NODE_DIR")
    if configured:
        candidates.append(Path(configured))
    candidates.append(Path.home() / ".nvm/versions/node/v22.17.0/bin")
    discovered = shutil.which("node")
    if discovered:
        candidates.append(Path(discovered).resolve().parent)
    for candidate in candidates:
        node = candidate / "node"
        npm = candidate / "npm"
        if not node.is_file() or not npm.exists():
            continue
        node_version = subprocess.run(
            [str(node), "--version"], text=True, capture_output=True, check=True
        ).stdout.strip()
        npm_version = subprocess.run(
            [str(npm), "--version"], text=True, capture_output=True, check=True
        ).stdout.strip()
        if node_version == "v22.17.0" and npm_version == "10.9.2":
            environment = os.environ.copy()
            environment["PATH"] = str(candidate) + os.pathsep + environment["PATH"]
            environment["WORDPRESSHX_EXACT_NODE_DIR"] = str(candidate)
            return environment
    raise AssertionError("production generated-output gate requires Node 22.17.0/npm 10.9.2")


def run(
    arguments: list[str],
    cwd: Path,
    environment: dict[str, str],
    *,
    expected: int = 0,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        arguments,
        cwd=cwd,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != expected:
        raise AssertionError(
            f"command exited {result.returncode}, expected {expected}: {arguments!r}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def git(repository: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=repository,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()


def initialize(repository: Path) -> None:
    git(repository, "init", "--quiet", "--initial-branch=main")
    git(repository, "config", "user.name", "SDK-045.3 Fixture")
    git(repository, "config", "user.email", "sdk-045-3@example.invalid")
    git(repository, "add", "--all")
    git(repository, "commit", "--quiet", "--message", "Haxe authority")


def pack_and_install_cli(
    runtime_root: Path, evidence: Path, environment: dict[str, str]
) -> tuple[Path, Path]:
    package_root = evidence / "cli-package"
    build_root = package_root / "build"
    shutil.copytree(runtime_root, build_root, symlinks=False)
    shutil.copy2(build_root / "index.js", build_root / "wphx.js")
    package_manifest_bytes = (ROOT / "packages/cli/package.json").read_bytes()
    package_manifest = json.loads(package_manifest_bytes)
    assert package_manifest["name"] == "@wordpress-hx/cli"
    assert package_manifest["version"] == "0.0.0"
    assert package_manifest["private"] is True
    assert package_manifest["bin"]["wphx"] == "build/wphx.js"
    assert package_manifest["engines"]["node"] == "22.17.0"
    assert package_manifest["packageManager"] == "npm@10.9.2"
    (package_root / "package.json").write_bytes(package_manifest_bytes)
    shutil.copy2(ROOT / "packages/cli/.npmignore", package_root / ".npmignore")
    forbidden_paths = {
        str(ROOT).encode(),
        str(runtime_root.resolve()).encode(),
    }
    for candidate in sorted(package_root.rglob("*")):
        if candidate.is_symlink() or not candidate.is_file():
            continue
        content = candidate.read_bytes()
        assert not any(value in content for value in forbidden_paths), candidate
    archive_root = evidence / "archives"
    archive_root.mkdir()
    packed = run(
        [
            "npm",
            "pack",
            "--json",
            "--ignore-scripts",
            "--pack-destination",
            str(archive_root),
        ],
        package_root,
        environment,
    )
    pack_result = json.loads(packed.stdout)
    assert len(pack_result) == 1
    file_paths = {entry["path"] for entry in pack_result[0]["files"]}
    assert all(
        path and not path.startswith("/") and ".." not in Path(path).parts
        for path in file_paths
    )
    assert "build/index.js" in file_paths
    assert "build/wphx.js" in file_paths
    assert "package.json" in file_paths
    assert "build/php-quality/vendor/autoload.php" in file_paths
    archive = (archive_root / pack_result[0]["filename"]).resolve(strict=True)
    assert hashlib.sha1(archive.read_bytes()).hexdigest() == pack_result[0]["shasum"]

    install_root = evidence / "installed-cli"
    install_root.mkdir()
    (install_root / "package.json").write_bytes(
        canonical({"name": "clean-cli-host", "version": "0.0.0", "private": True})
    )
    run(
        [
            "npm",
            "install",
            "--ignore-scripts",
            "--no-audit",
            "--no-fund",
            "--package-lock=false",
            str(archive),
        ],
        install_root,
        environment,
    )
    installed_package = install_root / "node_modules/@wordpress-hx/cli"
    assert (installed_package / "build/index.js").is_file()
    assert (installed_package / "build/wphx.js").is_file()
    assert (installed_package / "build/php-quality/vendor/autoload.php").is_file()
    assert (install_root / "node_modules/.bin/wphx").exists()
    return installed_package / "build/wphx.js", archive


class Runtime:
    def __init__(self, entry: Path, environment: dict[str, str]) -> None:
        self.entry = entry.resolve(strict=True)
        self.environment = environment
        self.positive = 0
        self.negative = 0
        self.no_write = 0

    def invoke(
        self,
        arguments: list[str],
        *,
        expected: int = 0,
        cwd: Path,
    ) -> subprocess.CompletedProcess[str]:
        node = Path(self.environment["WORDPRESSHX_EXACT_NODE_DIR"]) / "node"
        result = run(
            [str(node), str(self.entry), *arguments],
            cwd,
            self.environment,
            expected=expected,
        )
        if expected == 0:
            self.positive += 1
        else:
            self.negative += 1
        return result

    def document(
        self,
        arguments: list[str],
        *,
        expected: int = 0,
        cwd: Path,
    ) -> dict[str, object]:
        result = self.invoke([*arguments, "--json"], expected=expected, cwd=cwd)
        stream = result.stdout if expected == 0 else result.stderr
        assert stream.endswith("\n") and len(stream.splitlines()) == 1
        value = json.loads(stream)
        assert stream.encode() == canonical(value)
        assert isinstance(value, dict)
        return value


def working_snapshot(root: Path) -> dict[str, tuple[str, int, bytes | str]]:
    result: dict[str, tuple[str, int, bytes | str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if relative.parts[0] == ".git":
            continue
        metadata = path.lstat()
        mode = stat.S_IMODE(metadata.st_mode)
        key = relative.as_posix()
        if stat.S_ISLNK(metadata.st_mode):
            result[key] = ("link", mode, os.readlink(path))
        elif stat.S_ISREG(metadata.st_mode):
            result[key] = ("file", mode, path.read_bytes())
        elif stat.S_ISDIR(metadata.st_mode):
            result[key] = ("directory", mode, "")
        else:
            result[key] = ("special", mode, "")
    return result


def validate_result(value: dict[str, object], operation: str, status: str) -> None:
    assert set(value) == {
        "schema",
        "operation",
        "status",
        "projectId",
        "policy",
        "source",
        "generator",
        "profile",
        "manifest",
        "continuousIntegration",
        "roots",
        "comparison",
        "checkoutUnchanged",
        "releaseRegenerationRequired",
    }
    assert value["schema"] == "wordpress-hx.generated-output-vcs-result.v1"
    assert value["operation"] == operation and value["status"] == status
    assert value["projectId"] == "git-deploy"
    assert value["comparison"] == "exact-path-size-sha256-and-bytes"
    assert value["releaseRegenerationRequired"] is True
    assert value["roots"] == [
        {
            "fileCount": 8,
            "id": "wordpress",
            "path": "build/wordpress",
            "treeSha256": value["roots"][0]["treeSha256"],
        }
    ]
    for digest in (
        value["policy"]["sha256"],
        value["source"]["fingerprint"],
        value["generator"]["toolchainSha256"],
        value["profile"]["catalogSha256"],
        value["manifest"]["sha256"],
        value["continuousIntegration"]["sha256"],
        value["roots"][0]["treeSha256"],
    ):
        assert isinstance(digest, str) and len(digest) == 64


def validate_policy(project: Path) -> dict[str, object]:
    source = (project / POLICY_PATH).read_bytes()
    policy = json.loads(source)
    assert source == canonical(policy)
    assert set(policy) == {
        "schema",
        "canonicalization",
        "policyDigestAlgorithm",
        "policyDigest",
        "mode",
        "projectId",
        "authority",
        "outputRoots",
        "manifestSchema",
        "continuousIntegration",
        "verification",
    }
    assert policy["schema"] == "wordpress-hx.generated-output-vcs-project.v1"
    assert policy["mode"] == "consumer-committed-output-opt-in"
    assert policy["projectId"] == "git-deploy"
    assert policy["outputRoots"] == [{"id": "wordpress", "path": "build/wordpress"}]
    assert policy["authority"] == {
        "applicationSource": "haxe",
        "exactProjectLockRequired": True,
        "generatedOutputRole": "derived-inspectable-non-authoritative",
        "handEditsAllowed": False,
        "releaseRegenerationRequired": True,
    }
    assert policy["continuousIntegration"]["provider"] == "github-actions"
    assert policy["continuousIntegration"]["command"] == [
        "./node_modules/.bin/wphx",
        "generated-output",
        "check",
        "--project",
        ".",
        "--json",
    ]
    material = dict(policy)
    digest = material.pop("policyDigest")
    assert digest == sha256(canonical(material)[:-1])
    return policy


def validate_workflow(
    repository: Path,
    policy: dict[str, object],
    working_directory: str,
) -> Path:
    ci = policy["continuousIntegration"]
    workflow_path = repository / ci["workflowPath"]
    content = workflow_path.read_bytes()
    assert sha256(content) == ci["workflowSha256"]
    source = content.decode()
    assert f'working-directory: "{working_directory}"\n' in source
    assert "actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0" in source
    assert "actions/setup-node@48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e # v6.4.0" in source
    assert "krdlab/setup-haxe@d93667502be3b4f31a94a3308a74388f2e178a8d # v2.1.0" in source
    assert "npm ci --ignore-scripts --no-audit --no-fund" in source
    assert "./node_modules/.bin/wphx generated-output check --project . --json" in source
    assert "${{" not in source
    return Path(ci["workflowPath"])


def validate_manifest_bound_tree(project: Path) -> None:
    manifest_bytes = (project / MANIFEST_PATH).read_bytes()
    manifest = json.loads(manifest_bytes)
    assert manifest_bytes == canonical(manifest)
    expected: set[str] = {MANIFEST_PATH.as_posix()}
    for entry in manifest["files"]:
        if entry["rootId"] != "wordpress":
            continue
        path = project / entry["path"]
        value = path.read_bytes()
        assert len(value) == entry["sizeBytes"]
        assert sha256(value) == entry["contentSha256"]
        expected.add(entry["path"])
    actual = {
        path.relative_to(project).as_posix()
        for path in (project / "build/wordpress").rglob("*")
        if path.is_file()
    }
    assert actual == expected
    assert not (project / "build/wordpress/.wphx-transactions").exists()


def validate_evidence_receipt(
    runtime: Runtime, negative_corpus_cases: int
) -> None:
    receipt = json.loads(EVIDENCE_RECEIPT.read_text())
    assert receipt["schemaVersion"] == 1
    assert receipt["receiptId"] == "SDK-045-3-GENERATED-OUTPUT-VCS"
    assert receipt["bead"] == "wordpresshx-sdk-045.3"
    assert receipt["status"] in {
        "verified-local-pending-hosted",
        "verified-hosted",
    }
    assert receipt["subject"]["digestAlgorithm"] == "sha256-file-bytes-v1"
    records: list[dict[str, str]] = []
    for name, section in receipt["subject"].items():
        if name == "digestAlgorithm":
            continue
        if isinstance(section, list):
            records.extend(section)
        else:
            records.append(section)
    assert len(records) == 32
    assert len({record["path"] for record in records}) == len(records)
    for record in records:
        subject = ROOT / record["path"]
        assert subject.is_file(), record["path"]
        assert sha256(subject.read_bytes()) == record["sha256"], record["path"]
    verification = receipt["verification"]
    assert verification["positiveCases"] == runtime.positive
    assert verification["negativeCases"] == runtime.negative
    assert verification["negativeCorpusCases"] == negative_corpus_cases
    assert verification["noWriteAssertions"] == runtime.no_write
    assert verification["freshRegeneration"] == "exact-path-size-sha256-and-bytes"
    assert verification["releaseDistributionTracked"] is False
    assert receipt["review"]["initialBlockingFindingCount"] == 2
    assert receipt["review"]["remainingBlockingFindings"] == 0
    assert receipt["review"]["modelFamilyIndependenceClaimed"] is False
    assert receipt["review"]["freshReview"]["blockingFindingCount"] == 2
    assert receipt["review"]["freshReview"]["modelFamily"] == "GPT-5"
    assert receipt["claims"]["releaseIntegration"] == "not-implemented-sdk-101"
    assert receipt["claims"]["publicPackagePublication"] == "blocked"
    assert receipt["claims"]["productionSupport"] == "not-claimed"


def clone(source: Path, destination: Path) -> Path:
    subprocess.run(
        ["git", "clone", "--quiet", "--no-hardlinks", str(source), str(destination)],
        text=True,
        capture_output=True,
        check=True,
    )
    git(destination, "config", "user.name", "SDK-045.3 Mutation")
    git(destination, "config", "user.email", "sdk-045-3-mutation@example.invalid")
    return destination


def expect_failure(
    runtime: Runtime,
    project: Path,
    expected_code: str,
    expected_exit: int = 5,
) -> None:
    value = runtime.document(
        ["generated-output", "check", "--project", str(project)],
        expected=expected_exit,
        cwd=project,
    )
    assert value["schema"] == "wordpress-hx.cli-diagnostic.v1"
    assert value["code"] == expected_code


def rewrite_lock(project: Path, mutation: str) -> None:
    path = project / ".wphx/project.lock.json"
    value = json.loads(path.read_bytes())
    if mutation == "tool":
        value["generatedBy"]["cliVersion"] = "0.0.1"
    elif mutation == "profile":
        value["profile"]["catalogRevision"] = "wp70-release/catalog-drift"
    else:
        raise AssertionError(f"unknown lock mutation {mutation}")
    value.pop("lockDigest")
    value["lockDigest"] = sha256(canonical(value)[:-1])
    path.write_bytes(canonical(value))


def commit_mutation(project: Path, message: str) -> None:
    git(project, "add", "--all")
    git(project, "commit", "--quiet", "--message", message)
    assert git(project, "status", "--porcelain=v1", "--untracked-files=all") == ""


def negative_corpus(runtime: Runtime, baseline: Path, parent: Path) -> int:
    cases = 0

    dirty = clone(baseline, parent / "dirty")
    (dirty / "README.md").write_text((dirty / "README.md").read_text() + "dirty\n")
    expect_failure(runtime, dirty, "WPHX3417")
    cases += 1

    manual = clone(baseline, parent / "manual")
    plugin = manual / "build/wordpress/git-deploy/git-deploy.php"
    plugin.write_bytes(plugin.read_bytes() + b"// unsupported edit\n")
    commit_mutation(manual, "manual generated edit")
    expect_failure(runtime, manual, "WPHX3416")
    cases += 1

    source = clone(baseline, parent / "source")
    haxe = source / "src/git/deploy/Site.hx"
    haxe.write_text(haxe.read_text().replace("WordPress.plugin();", 'WordPress.plugin({version: "1.0.0"});'))
    commit_mutation(source, "source drift without regeneration")
    expect_failure(runtime, source, "WPHX3416")
    cases += 1

    tool = clone(baseline, parent / "tool")
    rewrite_lock(tool, "tool")
    commit_mutation(tool, "tool drift without regeneration")
    expect_failure(runtime, tool, "WPHX3416")
    cases += 1

    profile = clone(baseline, parent / "profile")
    rewrite_lock(profile, "profile")
    commit_mutation(profile, "profile drift without regeneration")
    expect_failure(runtime, profile, "WPHX3416")
    cases += 1

    missing = clone(baseline, parent / "missing")
    (missing / "build/wordpress/git-deploy/includes/Bootstrap.php").unlink()
    commit_mutation(missing, "remove generated path")
    expect_failure(runtime, missing, "WPHX1007", 3)
    cases += 1

    extra = clone(baseline, parent / "extra")
    (extra / "build/wordpress/unowned.txt").write_text("not manifest bound\n")
    commit_mutation(extra, "add unowned generated path")
    expect_failure(runtime, extra, "WPHX3414")
    cases += 1

    linked = clone(baseline, parent / "linked")
    os.symlink("../../../README.md", linked / "build/wordpress/linked.txt")
    commit_mutation(linked, "add generated link")
    expect_failure(runtime, linked, "WPHX3414")
    cases += 1

    policy = clone(baseline, parent / "policy")
    policy_path = policy / POLICY_PATH
    policy_value = json.loads(policy_path.read_bytes())
    policy_value["outputRoots"] = [{"id": "inferred", "path": "build/wordpress"}]
    policy_value.pop("policyDigest")
    policy_value["policyDigest"] = sha256(canonical(policy_value)[:-1])
    policy_path.write_bytes(canonical(policy_value))
    commit_mutation(policy, "invent output root")
    expect_failure(runtime, policy, "WPHX3412")
    cases += 1

    transaction = clone(baseline, parent / "transaction")
    transaction_root = transaction / "build/wordpress/.wphx-transactions"
    transaction_root.mkdir()
    (transaction_root / "journal.json").write_text("{}\n")
    assert git(transaction, "status", "--porcelain=v1", "--untracked-files=all") == ""
    expect_failure(runtime, transaction, "WPHX3414")
    cases += 1

    distribution = clone(baseline, parent / "distribution")
    (distribution / "dist").mkdir()
    (distribution / "dist/release.zip").write_bytes(b"not a release\n")
    git(distribution, "add", "--force", "dist/release.zip")
    git(distribution, "commit", "--quiet", "--message", "track forbidden release")
    expect_failure(runtime, distribution, "WPHX3417")
    cases += 1

    workflow = clone(baseline, parent / "workflow")
    workflow_policy = json.loads((workflow / POLICY_PATH).read_bytes())
    workflow_path = workflow / workflow_policy["continuousIntegration"]["workflowPath"]
    workflow_path.write_text(workflow_path.read_text() + "# unsupported workflow edit\n")
    commit_mutation(workflow, "tamper generated-output CI workflow")
    expect_failure(runtime, workflow, "WPHX3420")
    cases += 1

    return cases


def git_only_deployment(source: Path, destination: Path, environment: dict[str, str]) -> None:
    deployed = clone(source, destination)
    assert not (deployed / "dist").exists()
    validate_policy(deployed)
    validate_manifest_bound_tree(deployed)
    result = run(
        [
            "php",
            str(ROOT / "scripts/scaffold/plugin-native-caller.php"),
            str(deployed / "build/wordpress/git-deploy/git-deploy.php"),
            "Git\\Deploy\\Bootstrap",
        ],
        deployed,
        environment,
    )
    assert json.loads(result.stdout) == {
        "booted": True,
        "class": "Git\\Deploy\\Bootstrap",
        "methods": ["boot", "isBooted"],
        "outputBytes": 0,
    }


def configure_nested_output(project: Path) -> None:
    config_path = project / "wordpress-hx.json"
    config = json.loads(config_path.read_bytes())
    config["paths"]["outputRoots"] = [
        {"id": "browser", "path": "build/assets/browser"},
        {"id": "wordpress", "path": "build/wordpress"},
    ]
    config_path.write_text(json.dumps(config, indent=2) + "\n")
    lock_path = project / ".wphx/project.lock.json"
    lock = json.loads(lock_path.read_bytes())
    lock["project"]["configSemanticSha256"] = sha256(canonical(config)[:-1])
    lock.pop("lockDigest")
    lock["lockDigest"] = sha256(canonical(lock)[:-1])
    lock_path.write_bytes(canonical(lock))


def nested_root_gate(runtime: Runtime, parent: Path) -> None:
    scaffold_parent = parent / "nested-parent"
    scaffold_parent.mkdir()
    runtime.document(
        ["new", "site", "nested-output", "--project", str(scaffold_parent)],
        cwd=parent,
    )
    project = scaffold_parent / "nested-output"
    configure_nested_output(project)
    initialize(scaffold_parent)
    before = working_snapshot(scaffold_parent)
    omitted_metadata = runtime.document(
        [
            "generated-output",
            "enable",
            "--root",
            "wordpress",
            "--project",
            str(project),
        ],
        expected=5,
        cwd=project,
    )
    assert omitted_metadata["code"] == "WPHX3412"
    assert working_snapshot(scaffold_parent) == before
    runtime.no_write += 1
    enabled = runtime.document(
        [
            "generated-output",
            "enable",
            "--root",
            "browser",
            "--project",
            str(project),
        ],
        cwd=project,
    )
    assert enabled["status"] == "enabled"
    assert enabled["roots"][0]["path"] == "build/assets/browser"
    policy = json.loads((project / POLICY_PATH).read_bytes())
    workflow_path = validate_workflow(scaffold_parent, policy, "nested-output")
    marker = (project / ".gitignore").read_text()
    assert "!/build/assets/\n" in marker
    assert "!/build/assets/browser/**\n" in marker
    ignored_sibling = subprocess.run(
        ["git", "check-ignore", "--quiet", "build/assets/sibling/file.js"],
        cwd=project,
        check=False,
    )
    assert ignored_sibling.returncode == 0
    admitted_file = subprocess.run(
        ["git", "check-ignore", "--quiet", "build/assets/browser/_GeneratedFiles.json"],
        cwd=project,
        check=False,
    )
    assert admitted_file.returncode == 1
    git(
        scaffold_parent,
        "add",
        "nested-output/.gitignore",
        f"nested-output/{POLICY_PATH.as_posix()}",
        "nested-output/build/assets/browser",
        workflow_path.as_posix(),
    )
    git(
        scaffold_parent,
        "commit",
        "--quiet",
        "--message",
        "commit nested generated root",
    )
    checked = runtime.document(
        ["generated-output", "check", "--project", str(project)], cwd=project
    )
    assert checked["status"] == "passed" and checked["checkoutUnchanged"] is True
    assert not any(
        path.startswith("nested-output/build/wordpress/")
        for path in git(scaffold_parent, "ls-files").splitlines()
    )
    runtime.no_write += 1


def run_gate(runtime_root: Path) -> dict[str, object]:
    environment = exact_environment()
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(
        prefix="wordpresshx-sdk0453-production-", dir=temporary_parent
    ) as raw:
        evidence = Path(raw)
        installed_entry, cli_archive = pack_and_install_cli(
            runtime_root, evidence, environment
        )
        runtime = Runtime(installed_entry, environment)
        parent = evidence / "project-parent"
        parent.mkdir()
        runtime.document(
            ["new", "plugin", "git-deploy", "--project", str(parent)], cwd=evidence
        )
        project = parent / "git-deploy"
        initialize(project)

        ignore_before = (project / ".gitignore").read_text()
        assert "/build/*\n" in ignore_before
        assert BEGIN not in ignore_before and END not in ignore_before
        assert git(project, "check-ignore", "build/wordpress/example.php")
        before_missing_root = working_snapshot(project)
        missing_root = runtime.document(
            ["generated-output", "enable", "--project", str(project)],
            expected=2,
            cwd=project,
        )
        assert missing_root["code"] == "WPHX3400"
        assert working_snapshot(project) == before_missing_root
        runtime.no_write += 1
        unknown_root = runtime.document(
            [
                "generated-output",
                "enable",
                "--root",
                "guessed",
                "--project",
                str(project),
            ],
            expected=5,
            cwd=project,
        )
        assert unknown_root["code"] == "WPHX3412"
        assert working_snapshot(project) == before_missing_root
        runtime.no_write += 1

        before_dry_run = working_snapshot(project)
        planned = runtime.document(
            [
                "generated-output",
                "enable",
                "--root",
                "wordpress",
                "--project",
                str(project),
                "--dry-run",
            ],
            cwd=project,
        )
        validate_result(planned, "enable", "planned")
        assert planned["checkoutUnchanged"] is True
        assert working_snapshot(project) == before_dry_run
        assert git(project, "status", "--porcelain=v1", "--untracked-files=all") == ""
        runtime.no_write += 1

        enabled = runtime.document(
            [
                "generated-output",
                "enable",
                "--root",
                "wordpress",
                "--project",
                str(project),
            ],
            cwd=project,
        )
        validate_result(enabled, "enable", "enabled")
        assert enabled["checkoutUnchanged"] is False
        policy = validate_policy(project)
        workflow_path = validate_workflow(project, policy, ".")
        marker = (project / ".gitignore").read_text()
        assert marker.count(BEGIN) == marker.count(END) == 1
        assert "/dist/\n" in marker
        validate_manifest_bound_tree(project)
        tracked_before_commit = set(git(project, "ls-files").splitlines())
        assert not any(path.startswith("build/") for path in tracked_before_commit)
        assert not any(path.startswith("dist/") for path in tracked_before_commit)

        git(
            project,
            "add",
            ".gitignore",
            POLICY_PATH.as_posix(),
            "build/wordpress",
            workflow_path.as_posix(),
        )
        git(project, "commit", "--quiet", "--message", "review generated deployment")
        tracked = set(git(project, "ls-files").splitlines())
        assert POLICY_PATH.as_posix() in tracked and MANIFEST_PATH.as_posix() in tracked
        assert workflow_path.as_posix() in tracked
        assert not any(path.startswith("dist/") for path in tracked)
        assert not any(".wphx-transactions" in path for path in tracked)

        before_check = working_snapshot(project)
        head_before = git(project, "rev-parse", "HEAD")
        checked = runtime.document(
            ["generated-output", "check", "--project", str(project)], cwd=project
        )
        validate_result(checked, "check", "passed")
        assert checked["checkoutUnchanged"] is True
        assert working_snapshot(project) == before_check
        assert git(project, "rev-parse", "HEAD") == head_before
        assert git(project, "status", "--porcelain=v1", "--untracked-files=all") == ""
        runtime.no_write += 1

        package_before = (project / "package.json").read_bytes()
        package_lock_before = (project / "package-lock.json").read_bytes()
        run(
            [
                "npm",
                "install",
                "--ignore-scripts",
                "--no-audit",
                "--no-fund",
                "--package-lock=false",
                "--no-save",
                str(cli_archive),
            ],
            project,
            environment,
        )
        assert (project / "package.json").read_bytes() == package_before
        assert (project / "package-lock.json").read_bytes() == package_lock_before
        workflow_tree_before = working_snapshot(project / "build")
        workflow_result = run(
            [
                str(project / "node_modules/.bin/wphx"),
                "generated-output",
                "check",
                "--project",
                ".",
                "--json",
            ],
            project,
            environment,
        )
        workflow_document = json.loads(workflow_result.stdout)
        assert workflow_result.stdout.encode() == canonical(workflow_document)
        validate_result(workflow_document, "check", "passed")
        assert working_snapshot(project / "build") == workflow_tree_before
        assert git(project, "status", "--porcelain=v1", "--untracked-files=all") == ""
        runtime.positive += 1
        runtime.no_write += 1

        mutations = evidence / "mutations"
        mutations.mkdir()
        negative_count = negative_corpus(runtime, project, mutations)
        deployment = evidence / "deployment"
        git_only_deployment(project, deployment, environment)
        nested_root_gate(runtime, evidence)

        no_policy = clone(project, evidence / "no-policy")
        (no_policy / POLICY_PATH).unlink()
        marker_source = (no_policy / ".gitignore").read_text()
        marker_source = marker_source[: marker_source.index(BEGIN)]
        (no_policy / ".gitignore").write_text(marker_source)
        commit_mutation(no_policy, "remove explicit policy")
        no_policy_result = runtime.document(
            ["generated-output", "check", "--project", str(no_policy)],
            expected=3,
            cwd=no_policy,
        )
        assert no_policy_result["code"] == "WPHX1007"
        negative_count += 1

        schema = json.loads(
            (ROOT / "schemas/generated-output-vcs-project.schema.json").read_text()
        )
        result_schema = json.loads(
            (ROOT / "schemas/generated-output-vcs-result.schema.json").read_text()
        )
        implementation = json.loads(
            (ROOT / "manifests/generated-output-vcs-implementation.json").read_text()
        )
        assert schema["additionalProperties"] is False
        assert result_schema["additionalProperties"] is False
        assert policy["verification"]["freshSource"] == "clean-head-local-clone"
        assert implementation["schemaVersion"] == 1
        assert implementation["bead"] == "wordpresshx-sdk-045.3"
        assert implementation["contract"]["defaultConsumerMode"] == "ignore-and-regenerate"
        assert implementation["contract"]["rootAdmission"] == "explicit-configured-id-and-path-only"
        assert implementation["contract"]["handEditsAllowed"] is False
        assert implementation["contract"]["releaseRegenerationRequired"] is True
        assert implementation["verification"]["positiveCases"] == 8
        assert implementation["verification"]["negativeCases"] == 16
        assert implementation["verification"]["negativeCorpusCases"] == 13
        assert implementation["versionControl"]["releaseArchivesTracked"] is False
        validate_evidence_receipt(runtime, negative_count)

        return {
            "schema": "wordpress-hx.sdk0453-generated-output-summary.v1",
            "positiveCases": runtime.positive,
            "negativeCases": runtime.negative,
            "negativeCorpusCases": negative_count,
            "noWriteAssertions": runtime.no_write,
            "selectedRoots": 1,
            "freshRegeneration": "exact-path-size-sha256-and-bytes",
            "gitOnlyDeployment": "manifest-bound-generated-php-executed",
            "consumerCi": "generated-tracked-and-executed",
            "cleanCliInstall": "local-tarball",
            "releaseDistributionTracked": False,
            "checkoutMutation": "none",
            "outcome": "passed",
        }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-production-integration.py <compiled-runtime-root>")
    print(json.dumps(run_gate(Path(sys.argv[1])), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
