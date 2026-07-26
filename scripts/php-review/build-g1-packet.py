#!/usr/bin/env python3
"""Build the content-addressed G1 WordPress/PHP review packet."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path, PurePosixPath


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
REVIEW_ROOT = REPOSITORY_ROOT / "review" / "g1-php-readability"
PACKET_ROOT = REVIEW_ROOT / "packet"
PHP_IMAGE = (
    "docker.io/library/php@"
    "sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"
)
NODE_IMAGE = (
    "docker.io/library/node@"
    "sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
)
SHA1 = re.compile(r"^[0-9a-f]{40}$")
LOCAL_PATH_MARKERS = (
    b"/Us" + b"ers/",
    b"/ho" + b"me/",
    b"workspace/" + b"code",
)
TRACE_MODES = ("hook", "private", "render", "rest")
EXPECTED_TRACE_SOURCE_LINES = {
    "hook": 6,
    "private": 26,
    "render": 18,
    "rest": 14,
}


def run(
    arguments: list[str],
    *,
    cwd: Path = REPOSITORY_ROOT,
    expected_status: int = 0,
) -> bytes:
    result = subprocess.run(
        arguments,
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != expected_status:
        raise RuntimeError(
            f"{' '.join(arguments)} exited {result.returncode}, "
            f"expected {expected_status}\n"
            + result.stdout.decode("utf-8", errors="replace")
            + result.stderr.decode("utf-8", errors="replace")
        )
    return result.stdout


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def safe_relative(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if (
        not value
        or path.is_absolute()
        or "\\" in value
        or ":" in value
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise ValueError(f"unsafe packet path: {value}")
    return path


def write(destination_root: Path, relative: str, data: bytes) -> None:
    path = safe_relative(relative)
    destination = destination_root.joinpath(*path.parts)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)


def git_bytes(commit: str, path: str) -> bytes:
    safe_relative(path)
    return run(["git", "show", f"{commit}:{path}"])


def current_bytes(path: str) -> bytes:
    safe_relative(path)
    source = REPOSITORY_ROOT.joinpath(*PurePosixPath(path).parts)
    if not source.is_file():
        raise FileNotFoundError(f"missing packet input: {path}")
    return source.read_bytes()


def copy_git(
    destination_root: Path,
    commit: str,
    destination: str,
    source: str,
) -> None:
    write(destination_root, destination, git_bytes(commit, source))


def copy_current(
    destination_root: Path,
    destination: str,
    source: str,
) -> None:
    write(destination_root, destination, current_bytes(source))


def require_implementation_commit(commit: str) -> str:
    if not SHA1.fullmatch(commit):
        raise ValueError("--implementation-commit must be a full lowercase Git SHA-1")
    resolved = run(["git", "rev-parse", f"{commit}^{{commit}}"]).decode().strip()
    if resolved != commit:
        raise ValueError("implementation commit did not resolve to itself")
    run(["git", "merge-base", "--is-ancestor", commit, "HEAD"])
    run(
        [
            "git",
            "diff",
            "--exit-code",
            commit,
            "--",
            "compiler/reflaxe.php",
            "compiler/wordpress",
            "packages/cli/src",
            "packages/cli/profiles",
            "packages/cli/test/expected/private.text",
        ]
    )
    return run(["git", "rev-parse", f"{commit}^{{tree}}"]).decode().strip()


def require_generated_inputs() -> None:
    required = (
        "compiler/wordpress/build/acme-books-adapters/acme-books-adapters.php",
        "compiler/wordpress/build/acme-books-adapters/includes/PublicAdapters.php",
        (
            "compiler/wordpress/build/source-correlation/development/"
            "includes/FailureCallbacks.php.haxe-map.json"
        ),
        (
            "compiler/wordpress/build/source-correlation/development/"
            "source-index.json"
        ),
        (
            "compiler/wordpress/build/source-correlation/production-plugin/"
            "includes/FailureCallbacks.php"
        ),
        "packages/cli/build/index.js",
    )
    missing = [path for path in required if not (REPOSITORY_ROOT / path).is_file()]
    if missing:
        raise RuntimeError(
            "missing tested generated inputs; run "
            "`bash packages/cli/scripts/test.sh` first: "
            + ", ".join(missing)
        )


def require_generated_bindings(commit: str) -> None:
    adapter_root = REPOSITORY_ROOT / "compiler/wordpress/build/acme-books-adapters"
    expected_root = (
        "compiler/wordpress/test/expected/acme-books-adapters"
    )
    for relative in (
        "acme-books-adapters.php",
        "includes/Bootstrap.php",
        "includes/PublicAdapters.php",
        "includes/autoload.php",
        "includes/register-adapters.php",
    ):
        generated = (adapter_root / relative).read_bytes()
        expected = git_bytes(commit, f"{expected_root}/{relative}.txt")
        if generated != expected:
            raise RuntimeError(
                f"generated adapter differs from implementation snapshot: {relative}"
            )
    generated_manifest = (
        adapter_root / "wordpresshx-public-php-adapters.v1.json"
    ).read_bytes()
    expected_manifest = git_bytes(
        commit,
        f"{expected_root}/wordpresshx-public-php-adapters.v1.json",
    )
    if generated_manifest != expected_manifest:
        raise RuntimeError(
            "generated adapter manifest differs from implementation snapshot"
        )

    development = (
        REPOSITORY_ROOT / "compiler/wordpress/build/source-correlation/development"
    )
    production = (
        REPOSITORY_ROOT
        / "compiler/wordpress/build/source-correlation/production-plugin"
    )
    runtime = (development / "includes/FailureCallbacks.php").read_bytes()
    production_runtime = (
        production / "includes/FailureCallbacks.php"
    ).read_bytes()
    if runtime != production_runtime:
        raise RuntimeError(
            "development and production source-correlation PHP differ"
        )
    map_bytes = (
        development / "includes/FailureCallbacks.php.haxe-map.json"
    ).read_bytes()
    php_map = json.loads(map_bytes)
    generated_record = php_map["generated"]
    if (
        generated_record["path"] != "includes/FailureCallbacks.php"
        or generated_record["sha256"] != digest(runtime)
        or generated_record["byteLength"] != len(runtime)
        or generated_record["lineCount"] != len(runtime.splitlines())
        or generated_record["encoding"] != "utf-8"
        or generated_record["lineEndings"] != "lf"
    ):
        raise RuntimeError("source-correlation PHP map is stale")
    index = json.loads(
        (development / "source-index.json").read_text(encoding="utf-8")
    )
    records = {record["role"]: record for record in index["files"]}
    if records["runtime"]["sha256"] != digest(runtime):
        raise RuntimeError("source index runtime hash is stale")
    if records["source-map"]["sha256"] != digest(map_bytes):
        raise RuntimeError("source index map hash is stale")
    source = git_bytes(
        commit,
        "compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx",
    )
    if records["source"]["sha256"] != digest(source):
        raise RuntimeError("source index Haxe source hash is stale")
    if index["artifactSetSha256"] != digest(canonical(index["files"])):
        raise RuntimeError("source index artifact-set digest is stale")


def write_traces(destination_root: Path) -> None:
    repository_mount = f"type=bind,src={REPOSITORY_ROOT},dst=/repo,readonly"
    packet_mount = (
        f"type=bind,src={destination_root},dst=/packet,readonly"
    )
    for mode in TRACE_MODES:
        native = run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--mount",
                repository_mount,
                "-w",
                "/repo",
                PHP_IMAGE,
                "php",
                "/repo/compiler/wordpress/runtime/source-correlation-caller.php",
                (
                    "/repo/compiler/wordpress/build/source-correlation/"
                    "development/includes/FailureCallbacks.php"
                ),
                mode,
            ],
            expected_status=17,
        )
        native_path = f"traces/{mode}.native.stack"
        write(destination_root, native_path, native)
        correlated = run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--mount",
                repository_mount,
                "--mount",
                packet_mount,
                "-w",
                "/repo",
                NODE_IMAGE,
                "node",
                "/repo/packages/cli/build/index.js",
                "trace",
                "php",
                f"/packet/{native_path}",
                "--index",
                (
                    "/repo/compiler/wordpress/build/source-correlation/"
                    "development/source-index.json"
                ),
                "--source-root",
                "project=/repo",
                "--format",
                "json",
            ]
        )
        document = json.loads(correlated)
        if correlated != canonical(document) + b"\n":
            raise RuntimeError(f"{mode}: correlated trace is not canonical JSON")
        if [frame["native"] for frame in document["frames"]] != (
            native.decode("utf-8").splitlines()
        ):
            raise RuntimeError(f"{mode}: correlated trace changed native frames")
        if document["summary"].get("mapped-trace-anchor") != 1:
            raise RuntimeError(f"{mode}: expected exactly one mapped trace anchor")
        mapped = [
            frame
            for frame in document["frames"]
            if frame["status"] == "mapped-trace-anchor"
        ][0]["correlated"]
        expected_mapping = f"fixture:source-correlation:throw:{mode}"
        if (
            mapped["mappingId"] != expected_mapping
            or mapped["semanticNodeId"] != expected_mapping
            or mapped["nodeKind"] != "statement"
            or mapped["source"]["rootId"] != "project"
            or mapped["source"]["path"]
            != "compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx"
            or mapped["source"]["start"]["line"]
            != EXPECTED_TRACE_SOURCE_LINES[mode]
        ):
            raise RuntimeError(f"{mode}: correlated trace mapped the wrong source")
        write(
            destination_root,
            f"traces/{mode}.correlated.json",
            correlated,
        )


def populate(destination_root: Path, commit: str) -> None:
    copy_current(
        destination_root,
        "README.md",
        "review/g1-php-readability/packet-guide.md",
    )

    adapter_root = "compiler/wordpress/build/acme-books-adapters"
    for relative in (
        "acme-books-adapters.php",
        "includes/Bootstrap.php",
        "includes/PublicAdapters.php",
        "includes/autoload.php",
        "includes/register-adapters.php",
    ):
        copy_current(
            destination_root,
            f"php/acme-books-adapters/{relative}",
            f"{adapter_root}/{relative}",
        )
    copy_current(
        destination_root,
        "artifact-manifests/wordpresshx-public-php-adapters.v1.json",
        f"{adapter_root}/wordpresshx-public-php-adapters.v1.json",
    )

    correlation_root = (
        "compiler/wordpress/build/source-correlation/production-plugin"
    )
    for relative in (
        "source-correlation.php",
        "includes/Bootstrap.php",
        "includes/FailureCallbacks.php",
        "includes/autoload.php",
        "includes/register-adapters.php",
    ):
        copy_current(
            destination_root,
            f"php/source-correlation/{relative}",
            f"{correlation_root}/{relative}",
        )
    development_root = "compiler/wordpress/build/source-correlation/development"
    copy_current(
        destination_root,
        "debug/includes/FailureCallbacks.php.haxe-map.json",
        f"{development_root}/includes/FailureCallbacks.php.haxe-map.json",
    )
    copy_current(
        destination_root,
        "debug/source-index.json",
        f"{development_root}/source-index.json",
    )

    for destination, source in (
        (
            "haxe/fixtures/AcmeBooksAdapters.hx",
            "compiler/wordpress/test/fixtures/AcmeBooksAdapters.hx",
        ),
        (
            "haxe/fixtures/SourceCorrelationCallbacks.hx",
            "compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx",
        ),
        (
            "haxe/fixtures/SourceCorrelationFixture.hx",
            "compiler/wordpress/test/fixtures/SourceCorrelationFixture.hx",
        ),
        (
            "haxe/compiler/WordPressPluginActivationCallback.hx",
            (
                "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
                "WordPressPluginActivationCallback.hx"
            ),
        ),
        (
            "haxe/compiler/WordPressPublicAdapterPlan.hx",
            (
                "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
                "WordPressPublicAdapterPlan.hx"
            ),
        ),
        (
            "haxe/compiler/Wp70PhpProfile.hx",
            (
                "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
                "Wp70PhpProfile.hx"
            ),
        ),
        (
            "haxe/compiler/Wp70PublicAdapterProfile.hx",
            (
                "compiler/wordpress/src/wordpress/hx/compiler/php/profile/"
                "Wp70PublicAdapterProfile.hx"
            ),
        ),
        (
            "callers/native-adapter-caller.php",
            "compiler/wordpress/runtime/native-adapter-caller.php",
        ),
        (
            "callers/probe-adapters.php",
            "compiler/wordpress/runtime/probe-adapters.php",
        ),
        (
            "callers/probe-source-correlation.php",
            "compiler/wordpress/runtime/probe-source-correlation.php",
        ),
        (
            "callers/source-correlation-caller.php",
            "compiler/wordpress/runtime/source-correlation-caller.php",
        ),
    ):
        copy_git(destination_root, commit, destination, source)

    for receipt in (
        "g1.3-wordpress-activation-hook.json",
        "sdk-023-wordpress-public-php-adapters.json",
        "sdk-024-private-php-runtime.json",
        "sdk-025-php-source-correlation.json",
        "sdk-026-generated-php-quality.json",
    ):
        copy_current(
            destination_root,
            f"evidence/{receipt}",
            f"manifests/evidence/{receipt}",
        )

    write_traces(destination_root)


def role(path: str) -> str:
    return path.split("/", 1)[0] if "/" in path else "guide"


def write_manifest(
    destination_root: Path,
    commit: str,
    tree: str,
) -> None:
    records = []
    for path in sorted(destination_root.rglob("*")):
        if not path.is_file() or path.name == "packet-manifest.json":
            continue
        relative = path.relative_to(destination_root).as_posix()
        data = path.read_bytes()
        for marker in LOCAL_PATH_MARKERS:
            if marker in data:
                raise RuntimeError(
                    f"{relative}: packet contains a machine-local path marker"
                )
        records.append(
            {
                "path": relative,
                "role": role(relative),
                "bytes": len(data),
                "lines": len(data.splitlines()),
                "sha256": digest(data),
            }
        )
    author_name = run(
        ["git", "show", "-s", "--format=%an", commit]
    ).decode("utf-8").strip()
    identity = {
        "packetId": "wordpresshx-g1-php-readability-v1",
        "implementationCommit": commit,
        "implementationTree": tree,
        "files": records,
    }
    document = {
        "schemaVersion": 1,
        **identity,
        "packetDigestAlgorithm": (
            "sha256 over canonical JSON of packetId, implementationCommit, "
            "implementationTree, and files"
        ),
        "packetDigest": digest(canonical(identity)),
        "reviewPolicy": {
            "independentReviewerRequired": True,
            "ineligibleReviewerNames": [author_name],
            "requiredCategories": [
                "ordinary-php-naming-and-shape",
                "wordpress-conventions",
                "control-flow-and-bootstrap",
                "adapters-and-private-boundary",
                "errors-and-native-stack-frames",
                "haxe-source-correlation",
            ],
            "blockingFindingsMustBeResolved": True,
            "publicationAuthorized": False,
            "productionSupportClaimed": False,
        },
    }
    write(
        destination_root,
        "packet-manifest.json",
        json.dumps(
            document,
            ensure_ascii=False,
            sort_keys=True,
            indent=2,
        ).encode("utf-8")
        + b"\n",
    )


def publish(staging: Path) -> None:
    backup = REVIEW_ROOT / ".packet-backup"
    if backup.exists():
        raise RuntimeError(f"refusing to overwrite stale packet backup: {backup}")
    if PACKET_ROOT.exists():
        PACKET_ROOT.rename(backup)
    try:
        staging.rename(PACKET_ROOT)
    except BaseException:
        if backup.exists() and not PACKET_ROOT.exists():
            backup.rename(PACKET_ROOT)
        raise
    if backup.exists():
        shutil.rmtree(backup)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--implementation-commit", required=True)
    args = parser.parse_args()

    tree = require_implementation_commit(args.implementation_commit)
    require_generated_inputs()
    require_generated_bindings(args.implementation_commit)
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".packet-stage-",
        dir=REVIEW_ROOT,
    ) as temporary:
        staging = Path(temporary) / "packet"
        staging.mkdir()
        populate(staging, args.implementation_commit)
        write_manifest(staging, args.implementation_commit, tree)
        publish(staging)

    manifest = json.loads(
        (PACKET_ROOT / "packet-manifest.json").read_text(encoding="utf-8")
    )
    print(
        "G1 PHP review packet written: "
        f"{len(manifest['files'])} files, "
        f"digest {manifest['packetDigest']}"
    )


if __name__ == "__main__":
    main()
