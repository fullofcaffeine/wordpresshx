#!/usr/bin/env python3
"""Verify the immutable SDK-031 compiler and TypeScript tooling closure."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
LOCK_PATH = PACKAGE_ROOT / "dependency-lock.json"
ARCHITECTURE_PATH = REPOSITORY_ROOT / "manifests/browser-build-architecture.json"
UPSTREAM_LOCK_PATH = REPOSITORY_ROOT / "manifests/upstream.lock.json"

SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
NPM_INTEGRITY = re.compile(r"sha512-[A-Za-z0-9+/]+={0,2}\Z")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def assert_exact_keys(value: dict, keys: set[str], label: str) -> None:
    assert set(value) == keys, f"{label} keys changed: {sorted(value)}"


def hxml_lines(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def verify_metadata(lock: dict) -> None:
    assert lock["schemaVersion"] == 1
    assert lock["status"] == "resolved-sdk-031"
    assert lock["profile"] == "wp70-release"

    toolchain = lock["toolchain"]
    assert toolchain["haxe"] == "4.3.7"
    assert toolchain["lix"]["version"] == "15.12.4"
    assert toolchain["lix"]["reportedCliVersion"] == "15.12.2"
    assert toolchain["node"] == {
        "version": "22.17.0",
        "image": (
            "docker.io/library/node@sha256:"
            "b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
        ),
    }
    assert toolchain["npm"] == "10.9.2"
    assert toolchain["typescript"] == "5.9.3"
    assert toolchain["esbuild"] == "0.27.2"
    lix_artifact = toolchain["lix"]["artifact"]
    assert SHA256.fullmatch(lix_artifact["sha256"])
    assert NPM_INTEGRITY.fullmatch(lix_artifact["npmIntegrity"])

    compiler = lock["compiler"]
    assert_exact_keys(
        compiler,
        {
            "name",
            "version",
            "tag",
            "repository",
            "commit",
            "tree",
            "releaseArtifact",
            "admission",
        },
        "compiler",
    )
    assert compiler["name"] == "genes-ts"
    assert compiler["version"] == "1.36.3"
    assert compiler["tag"] == "v1.36.3"
    assert compiler["repository"] == "https://github.com/fullofcaffeine/genes-ts"
    assert SHA1.fullmatch(compiler["commit"])
    assert SHA1.fullmatch(compiler["tree"])
    release_artifact = compiler["releaseArtifact"]
    assert_exact_keys(
        release_artifact,
        {"name", "url", "sizeBytes", "sha256"},
        "compiler release artifact",
    )
    assert release_artifact["name"] == "submit.zip"
    assert release_artifact["url"] == (
        f"{compiler['repository']}/releases/download/{compiler['tag']}/submit.zip"
    )
    assert release_artifact["sizeBytes"] > 0
    assert SHA256.fullmatch(release_artifact["sha256"])

    admission = compiler["admission"]
    assert_exact_keys(admission, {"kind", "baseline", "change"}, "admission")
    assert admission["kind"] == "generalized-upstream-fix-release"
    assert admission["baseline"] == {
        "receiptId": "SDK-030-GENES-TS-V1.33.0",
        "version": "1.33.0",
        "tag": "v1.33.0",
        "commit": "7999b7cff09f78ebb8e09c3db6e221beb141b67b",
        "tree": "5ec14a28160ae676d24e6092ace8f1d2a4ad6dc5",
        "releaseArtifactSha256": (
            "4bf2d2d1046ee5a99830ef31158a90033bfa521da12eb1d5ecd136b35b4fd145"
        ),
    }
    assert admission["change"] == {
        "pullRequest": {
            "number": 3,
            "url": "https://github.com/fullofcaffeine/genes-ts/pull/3",
        },
        "fixCommit": "77aa609279886fd8f53f48e0d2b751f898489930",
        "fixTree": "987359de08e83b4159aefc1a7987aa4146285037",
        "mergeCommit": "e5f2cc146eaf6e5e8d89ceae4f6c544e07ff2d58",
    }
    assert compiler["commit"] != admission["baseline"]["commit"]

    assert len(lock["dependencies"]) == 1
    dependency = lock["dependencies"][0]
    assert dependency["name"] == "helder.set"
    assert dependency["version"] == "0.3.1"
    assert dependency["sourceKind"] == "haxelib"
    assert SHA256.fullmatch(dependency["artifact"]["sha256"])

    assert lock["policy"] == {
        "floatingVersionsAllowed": False,
        "haxelibDevAllowed": False,
        "repositoryRelativeDependencyAllowed": False,
        "mutableSiblingCheckoutAllowed": False,
        "wordpressSpecificGenesPatchAllowed": False,
        "generatedDirectNpmRangesAllowed": False,
    }

    assert load_json(PACKAGE_ROOT / ".haxerc") == {
        "version": "4.3.7",
        "resolveLibs": "scoped",
    }
    scoped_hxml = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((PACKAGE_ROOT / "haxe_libraries").glob("*.hxml"))
    )
    assert (
        'gh://github.com/fullofcaffeine/genes-ts#'
        + compiler["commit"]
    ) in scoped_hxml
    assert (
        f"genes-ts/{compiler['version']}/github/{compiler['commit']}" in scoped_hxml
    )
    assert 'haxelib:/helder.set#0.3.1' in scoped_hxml
    assert "=dev" not in scoped_hxml
    assert "../" not in scoped_hxml
    assert "../genes" not in scoped_hxml

    common = {
        "-lib genes-ts",
        "-cp src",
        "-cp test/fixture/src",
        "-main sdk031.fixture.Main",
        "-D wordpress_hx_profile=wp70-release",
        "-D js-es=6",
        "-dce full",
        "--macro include('sdk031.fixture')",
    }
    strict = set(hxml_lines(PACKAGE_ROOT / "profiles/strict.hxml"))
    classic = set(hxml_lines(PACKAGE_ROOT / "profiles/classic.hxml"))
    default = set(hxml_lines(PACKAGE_ROOT / "profiles/default-dce.hxml"))
    assert strict == common | {
        "-D genes.ts",
        "-D genes.ts.no_extension",
        "-D genes.library",
    }
    assert classic == common | {
        "-D dts",
        "-D genes.library",
        "-D genes.no_extension",
        "-D genes.react.inline_markup",
    }
    assert default == common | {"-D genes.no_extension"}

    package_manifest = load_json(PACKAGE_ROOT / "tooling/package.json")
    assert package_manifest["private"] is True
    assert package_manifest["type"] == "module"
    assert package_manifest["engines"] == {
        "node": "22.17.0",
        "npm": "10.9.2",
    }
    assert package_manifest["devDependencies"] == {
        "esbuild": "0.27.2",
        "typescript": "5.9.3",
    }
    assert package_manifest["packageManager"] == "npm@10.9.2"

    package_lock = load_json(PACKAGE_ROOT / "tooling/package-lock.json")
    assert package_lock["lockfileVersion"] == 3
    assert package_lock["requires"] is True
    root_package = package_lock["packages"][""]
    assert root_package["devDependencies"] == package_manifest["devDependencies"]
    assert root_package["engines"] == package_manifest["engines"]
    for package_name, version in package_manifest["devDependencies"].items():
        entry = package_lock["packages"][f"node_modules/{package_name}"]
        assert entry["version"] == version
        assert entry["resolved"].startswith("https://registry.npmjs.org/")
        assert NPM_INTEGRITY.fullmatch(entry["integrity"])
    for package_path, entry in package_lock["packages"].items():
        if not package_path:
            continue
        assert "resolved" in entry, f"unresolved npm package: {package_path}"
        assert NPM_INTEGRITY.fullmatch(entry["integrity"]), (
            f"invalid npm integrity: {package_path}"
        )

    architecture = load_json(ARCHITECTURE_PATH)
    assert architecture["profile"]["id"] == lock["profile"]
    baseline = admission["baseline"]
    assert architecture["compiler"]["name"] == compiler["name"]
    for field in ("version", "tag", "commit", "tree"):
        assert architecture["compiler"][field] == baseline[field]
    assert architecture["compiler"]["artifactSha256"] == baseline[
        "releaseArtifactSha256"
    ]
    assert architecture["compiler"]["mutableSiblingBuildInputAllowed"] is False
    sdk_toolchain = architecture["toolchains"]["sdkProject"]
    assert sdk_toolchain["node"]["version"] == toolchain["node"]["version"]
    assert sdk_toolchain["node"]["image"] == toolchain["node"]["image"]
    assert sdk_toolchain["packageManager"]["version"] == toolchain["npm"]
    assert sdk_toolchain["typescript"]["version"] == toolchain["typescript"]
    assert architecture["sourceOutput"]["primary"]["typecheck"] == {
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

    upstream = load_json(UPSTREAM_LOCK_PATH)["entries"]["genes-ts"]
    assert upstream["version"] == baseline["version"]
    assert upstream["releaseTag"] == baseline["tag"]
    assert upstream["commit"] == baseline["commit"]
    assert upstream["tree"] == baseline["tree"]
    assert (
        upstream["releaseArtifact"]["sha256"]
        == baseline["releaseArtifactSha256"]
    )


def download(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "wordpresshx-sdk-031-evidence/1"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def verify_artifact(label: str, artifact: dict) -> bytes:
    data = download(artifact["url"])
    assert len(data) == artifact["sizeBytes"], f"{label} artifact size mismatch"
    assert digest(data) == artifact["sha256"], f"{label} artifact digest mismatch"
    return data


def read_zip_json(data: bytes, path: str) -> dict:
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        return json.loads(archive.read(path))


def read_tgz_json(data: bytes, path: str) -> dict:
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        member = archive.extractfile(path)
        assert member is not None, f"missing {path} in npm artifact"
        return json.load(member)


def resolve_tag(repository: str, tag: str) -> set[str]:
    tag_ref = f"refs/tags/{tag}"
    tag_output = subprocess.check_output(
        [
            "git",
            "ls-remote",
            "--tags",
            repository,
            tag_ref,
            f"{tag_ref}^{{}}",
        ],
        text=True,
    ).splitlines()
    return {line.split()[0] for line in tag_output}


def verify_genes_git(compiler: dict) -> None:
    admission = compiler["admission"]
    baseline = admission["baseline"]
    change = admission["change"]
    assert compiler["commit"] in resolve_tag(
        compiler["repository"], compiler["tag"]
    ), "active Genes tag does not resolve to commit"
    assert baseline["commit"] in resolve_tag(
        compiler["repository"], baseline["tag"]
    ), "baseline Genes tag does not resolve to commit"

    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk031-genes-") as root:
        subprocess.run(["git", "init", "--quiet", root], check=True)
        subprocess.run(
            [
                "git",
                "-C",
                root,
                "fetch",
                "--quiet",
                "--no-tags",
                "--no-auto-maintenance",
                compiler["repository"],
                (
                    f"refs/tags/{baseline['tag']}:"
                    "refs/tags/wordpresshx-sdk031-baseline"
                ),
                (
                    f"refs/tags/{compiler['tag']}:"
                    "refs/tags/wordpresshx-sdk031-active"
                ),
            ],
            check=True,
        )
        baseline_commit = subprocess.check_output(
            [
                "git",
                "-C",
                root,
                "rev-parse",
                "refs/tags/wordpresshx-sdk031-baseline^{commit}",
            ],
            text=True,
        ).strip()
        commit = subprocess.check_output(
            [
                "git",
                "-C",
                root,
                "rev-parse",
                "refs/tags/wordpresshx-sdk031-active^{commit}",
            ],
            text=True,
        ).strip()
        tree = subprocess.check_output(
            ["git", "-C", root, "rev-parse", f"{commit}^{{tree}}"], text=True
        ).strip()
        baseline_tree = subprocess.check_output(
            ["git", "-C", root, "rev-parse", f"{baseline_commit}^{{tree}}"],
            text=True,
        ).strip()
        fix_tree = subprocess.check_output(
            ["git", "-C", root, "rev-parse", f"{change['fixCommit']}^{{tree}}"],
            text=True,
        ).strip()
        for ancestor, descendant, label in (
            (baseline_commit, change["fixCommit"], "baseline -> fix"),
            (change["fixCommit"], change["mergeCommit"], "fix -> merge"),
            (change["mergeCommit"], commit, "merge -> release"),
        ):
            ancestry = subprocess.run(
                ["git", "-C", root, "merge-base", "--is-ancestor", ancestor, descendant]
            )
            assert ancestry.returncode == 0, f"Genes ancestry failed: {label}"
        haxelib = json.loads(
            subprocess.check_output(
                ["git", "-C", root, "show", f"{commit}:haxelib.json"],
                text=True,
            )
        )
    assert baseline_commit == baseline["commit"]
    assert baseline_tree == baseline["tree"]
    assert commit == compiler["commit"]
    assert tree == compiler["tree"]
    assert fix_tree == change["fixTree"]
    assert haxelib["name"] == compiler["name"]
    assert haxelib["version"] == compiler["version"]
    assert haxelib["dependencies"] == {"helder.set": "0.3.1"}


def verify_network(lock: dict) -> None:
    lix_data = verify_artifact("Lix", lock["toolchain"]["lix"]["artifact"])
    lix_manifest = read_tgz_json(lix_data, "package/package.json")
    assert lix_manifest["name"] == "lix"
    assert lix_manifest["version"] == lock["toolchain"]["lix"]["version"]

    compiler = lock["compiler"]
    genes_data = verify_artifact("Genes", compiler["releaseArtifact"])
    genes_manifest = read_zip_json(genes_data, "haxelib.json")
    assert genes_manifest["name"] == compiler["name"]
    assert genes_manifest["version"] == compiler["version"]
    assert genes_manifest["dependencies"] == {"helder.set": "0.3.1"}
    verify_genes_git(compiler)

    dependency = lock["dependencies"][0]
    dependency_data = verify_artifact(dependency["name"], dependency["artifact"])
    dependency_manifest = read_zip_json(dependency_data, "haxelib.json")
    assert dependency_manifest["name"] == dependency["name"]
    assert dependency_manifest["version"] == dependency["version"]

    package_lock = load_json(PACKAGE_ROOT / "tooling/package-lock.json")
    for name, version in (("typescript", "5.9.3"), ("esbuild", "0.27.2")):
        entry = package_lock["packages"][f"node_modules/{name}"]
        data = download(entry["resolved"])
        manifest = read_tgz_json(data, "package/package.json")
        assert manifest["name"] == name
        assert manifest["version"] == version


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--metadata-only",
        action="store_true",
        help="validate committed lock linkage without network materialization",
    )
    arguments = parser.parse_args()
    lock = load_json(LOCK_PATH)
    verify_metadata(lock)
    if not arguments.metadata_only:
        verify_network(lock)
    print("SDK-031 immutable browser dependency lock passed")


if __name__ == "__main__":
    main()
