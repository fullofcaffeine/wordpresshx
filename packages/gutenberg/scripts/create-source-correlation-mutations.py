#!/usr/bin/env python3
"""Create deterministic G2.4 integrity, privacy, and ambiguity mutations."""

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
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: create-source-correlation-mutations.py "
            "<combined-evidence> <production-plugin> <mutations> <project-root>"
        )
    evidence = Path(sys.argv[1]).resolve(strict=True)
    plugin = Path(sys.argv[2]).resolve(strict=True)
    mutations = Path(sys.argv[3]).resolve()
    project_root = Path(sys.argv[4]).resolve(strict=True)
    mutations.mkdir(parents=True, exist_ok=True)

    root = clone(evidence, mutations, "stale-runtime")
    with (
        root / "wordpresshx-sdk033-assets/build/editor.js"
    ).open("a", encoding="utf-8") as file:
        file.write("// stale runtime\n")

    root = clone(evidence, mutations, "stale-map")
    with (
        root / "maps/wordpress-scripts-production.js.map"
    ).open("a", encoding="utf-8") as file:
        file.write(" ")

    for name, mutate in (
        (
            "absolute-map-source",
            lambda document: document["sources"].__setitem__(
                0, "/tmp/private-source.hx"
            ),
        ),
        (
            "sources-content",
            lambda document: document.__setitem__(
                "sourcesContent",
                ["private source"]
                + [None] * (len(document["sources"]) - 1),
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
        relative = "maps/wordpress-scripts-production.js.map"
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
        if value["id"] == "file:runtime:wordpress-scripts:production"
    )["path"] = "/tmp/editor.js"
    refresh_index(root, index)

    root = clone(evidence, mutations, "ambiguous-correlation")
    index = json.loads((root / "source-index.json").read_text())
    duplicate = copy.deepcopy(index["correlations"][0])
    duplicate["id"] = "correlation:browser:wordpress-scripts:development:duplicate"
    index["correlations"].append(duplicate)
    index["correlations"].sort(key=lambda value: value["id"])
    (root / "source-index.json").write_bytes(canonical(index) + b"\n")

    mutated_project = mutations / "mutated-project"
    index = json.loads((evidence / "source-index.json").read_text())
    for record in index["files"]:
        identity = record.get("sourceIdentity")
        if identity is None or identity["rootId"] != "project":
            continue
        source = project_root / identity["path"]
        target = mutated_project / identity["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    fixture = mutated_project / (
        "packages/gutenberg/test/assets-fixture/src/"
        "sdk033/fixture/EditorPanel.hx"
    )
    with fixture.open("a", encoding="utf-8") as file:
        file.write("// stale project source\n")

    secret_plugin = mutations / "secret-plugin"
    path_plugin = mutations / "path-plugin"
    shutil.copytree(plugin, secret_plugin)
    shutil.copytree(plugin, path_plugin)
    with (secret_plugin / "generation-manifest.json").open(
        "a", encoding="utf-8"
    ) as file:
        file.write("\n" + "AK" + "IA" + "A" * 16 + "\n")
    with (path_plugin / "generation-manifest.json").open(
        "a", encoding="utf-8"
    ) as file:
        file.write("\n" + "/Us" + "ers/private/build" + "\n")

    stacks = mutations / "stacks"
    stacks.mkdir(parents=True, exist_ok=True)
    (stacks / "basename.stack").write_text(
        "    at sourceCorrelationProbe "
        "(http://127.0.0.1:41735/editor.js:1:3000)\n",
        encoding="utf-8",
    )
    (stacks / "unknown.stack").write_text(
        "    at unknown (http://127.0.0.1:41735/runtime/unknown.js:1:1)\n",
        encoding="utf-8",
    )
    (stacks / "missing-column.stack").write_text(
        "    at sourceCorrelationProbe "
        "(http://127.0.0.1:41735/wordpresshx-sdk033-assets/build/editor.js:1)\n",
        encoding="utf-8",
    )
    (stacks / "out-of-range.stack").write_text(
        "    at sourceCorrelationProbe "
        "(http://127.0.0.1:41735/wordpresshx-sdk033-assets/build/editor.js:9999:1)\n",
        encoding="utf-8",
    )
    (stacks / "empty.stack").write_bytes(b"")

    print(
        "G2.4 mutations created: stale artifacts/source, map/index privacy, "
        "ambiguity, exact-path, secret, and machine-path cases"
    )


if __name__ == "__main__":
    main()
