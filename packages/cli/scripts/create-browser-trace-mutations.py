#!/usr/bin/env python3
"""Create deterministic SDK-034 fail-closed trace mutations and input stacks."""

from __future__ import annotations

import copy
import hashlib
import json
import shutil
import sys
from pathlib import Path


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def clone(source: Path, mutations: Path, name: str) -> Path:
    target = mutations / name
    shutil.copytree(source, target)
    return target


def refresh_index(root: Path, index: dict) -> None:
    index["artifactSetSha256"] = digest(canonical(index["files"]))
    (root / "source-index.json").write_bytes(canonical(index) + b"\n")


def refresh_artifact(root: Path, relative: str, document: dict) -> None:
    path = root / relative
    data = canonical(document) + b"\n"
    path.write_bytes(data)
    index = json.loads((root / "source-index.json").read_text())
    record = next(value for value in index["files"] if value["path"] == relative)
    record["sha256"] = digest(data)
    record["byteLength"] = len(data)
    refresh_index(root, index)


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: create-browser-trace-mutations.py <evidence> <mutations> <project-root>"
        )
    evidence = Path(sys.argv[1]).resolve(strict=True)
    mutations = Path(sys.argv[2]).resolve()
    project_root = Path(sys.argv[3]).resolve(strict=True)
    mutations.mkdir(parents=True, exist_ok=True)

    root = clone(evidence, mutations, "stale-runtime")
    with (root / "runtime/production.js").open("a", encoding="utf-8") as file:
        file.write("// stale runtime\n")

    root = clone(evidence, mutations, "stale-map")
    with (root / "maps/production.js.map").open("a", encoding="utf-8") as file:
        file.write(" ")

    root = clone(evidence, mutations, "stale-generated")
    with (root / "generated/sdk034/fixture/Main.ts").open(
        "a", encoding="utf-8"
    ) as file:
        file.write("// stale generated source\n")

    for name, mutate in (
        (
            "absolute-map-source",
            lambda document: document["sources"].__setitem__(0, "/tmp/leak.hx"),
        ),
        (
            "escaping-map-source",
            lambda document: document["sources"].__setitem__(
                0, "../../../../escape.hx"
            ),
        ),
        (
            "invalid-vlq",
            lambda document: document.__setitem__("mappings", "!"),
        ),
        (
            "sources-content",
            lambda document: document.__setitem__(
                "sourcesContent", ["secret"] + [None] * (len(document["sources"]) - 1)
            ),
        ),
        (
            "wrong-map-file",
            lambda document: document.__setitem__("file", "other.js"),
        ),
        (
            "unknown-map-field",
            lambda document: document.__setitem__("x_google_ignoreList", []),
        ),
    ):
        root = clone(evidence, mutations, name)
        relative = "maps/production.js.map"
        document = json.loads((root / relative).read_text())
        mutate(document)
        refresh_artifact(root, relative, document)

    root = clone(evidence, mutations, "unknown-index-field")
    index = json.loads((root / "source-index.json").read_text())
    index["lookupByBasename"] = True
    (root / "source-index.json").write_bytes(canonical(index) + b"\n")

    root = clone(evidence, mutations, "absolute-index-path")
    index = json.loads((root / "source-index.json").read_text())
    next(
        value
        for value in index["files"]
        if value["id"] == "file:runtime:browser:production"
    )["path"] = "/tmp/production.js"
    refresh_index(root, index)

    root = clone(evidence, mutations, "ambiguous-correlation")
    index = json.loads((root / "source-index.json").read_text())
    duplicate = copy.deepcopy(index["correlations"][0])
    duplicate["id"] = "correlation:browser:development:duplicate"
    index["correlations"].append(duplicate)
    index["correlations"].sort(key=lambda value: value["id"])
    (root / "source-index.json").write_bytes(canonical(index) + b"\n")

    root = clone(evidence, mutations, "ambiguous-file-path")
    index = json.loads((root / "source-index.json").read_text())
    first, second = index["files"][:2]
    second["path"] = first["path"]
    refresh_index(root, index)

    root = clone(evidence, mutations, "dishonest-continuity")
    index = json.loads((root / "source-index.json").read_text())
    correlation = next(
        value
        for value in index["correlations"]
        if value["strategy"] == "browser-two-stage-v3"
    )
    generated_index = next(
        value
        for value in index["files"]
        if value["path"] == "generated/index.ts"
    )
    correlation["layers"][1]["generatedFileId"] = generated_index["id"]
    (root / "source-index.json").write_bytes(canonical(index) + b"\n")

    mutated_project = mutations / "mutated-project"
    fixture_relative = Path(
        "packages/cli/test/browser-source-correlation/src/sdk034/fixture/Main.hx"
    )
    target = mutated_project / fixture_relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((project_root / fixture_relative).read_bytes() + b"// stale\n")

    stacks = mutations / "stacks"
    stacks.mkdir(parents=True, exist_ok=True)
    (stacks / "basename.stack").write_text(
        "    at deliberateFailure (http://127.0.0.1:41734/production.js:1:2976)\n",
        encoding="utf-8",
    )
    (stacks / "unknown.stack").write_text(
        "    at unknown (http://127.0.0.1:41734/runtime/unknown.js:1:1)\n",
        encoding="utf-8",
    )
    (stacks / "missing-column.stack").write_text(
        "    at deliberateFailure (http://127.0.0.1:41734/runtime/production.js:1)\n",
        encoding="utf-8",
    )
    (stacks / "out-of-range.stack").write_text(
        "    at deliberateFailure (http://127.0.0.1:41734/runtime/production.js:9999:1)\n",
        encoding="utf-8",
    )
    (stacks / "empty.stack").write_bytes(b"")

    print("SDK-034 negative fixtures created: integrity, privacy, ambiguity, continuity, and exact-path cases")


if __name__ == "__main__":
    main()
