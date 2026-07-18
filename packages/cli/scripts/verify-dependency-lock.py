#!/usr/bin/env python3
"""Verify the immutable Genes/Node CLI closure without consulting sibling paths."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = ROOT.parents[1]


def main() -> None:
    lock = json.loads((ROOT / "dependency-lock.json").read_text(encoding="utf-8"))
    assert lock["schemaVersion"] == 1
    assert lock["profile"] == "classic-genes-node-esm"

    compiler = lock["compiler"]
    assert compiler == {
        "name": "genes-ts",
        "version": "1.36.3",
        "repository": "https://github.com/fullofcaffeine/genes-ts",
        "commit": "c59ecb361fd91418584487c2138bae8d3d3a3961",
        "tree": "be1a96453ac97e6f80916b415deff0d0ad3f18a6",
        "dependency": {"name": "helder.set", "version": "0.3.1"},
        "sourceChanged": False,
        "pullRequest": None,
    }
    genes_hxml = (ROOT / "haxe_libraries/genes-ts.hxml").read_text(
        encoding="utf-8"
    )
    assert compiler["commit"] in genes_hxml
    assert f"genes-ts={compiler['version']}" in genes_hxml
    assert "-lib helder.set" in genes_hxml
    assert "../genes" not in genes_hxml

    externs = lock["nodeExterns"]
    assert externs["name"] == "hxnodejs"
    assert externs["version"] == "10.0.0"
    assert externs["repository"] == "https://github.com/HaxeFoundation/hxnodejs"
    assert externs["license"] == "MIT"
    assert externs["haxelibManifestSha256"] == (
        "406ba17008d327c591bec4c62b0d54c410d98e4a4e84a6501779c6040044112f"
    )
    hxnode_hxml = (ROOT / "haxe_libraries/hxnodejs.hxml").read_text(
        encoding="utf-8"
    )
    assert 'haxelib:/hxnodejs#10.0.0' in hxnode_hxml
    assert "-D hxnodejs=10.0.0" in hxnode_hxml

    node = lock["runtime"]
    image_lock = json.loads(
        (REPOSITORY_ROOT / "docker/images.lock.json").read_text(encoding="utf-8")
    )["images"]["node"]
    assert node == {
        "name": "node",
        "version": "22.17.0",
        "image": image_lock["reference"],
    }
    assert image_lock["tag"] == "docker.io/library/node:22.17.0-bookworm-slim"
    assert lock["haxe"] == {"version": "4.3.7"}
    assert lock["lix"] == {
        "packageVersion": "15.12.4",
        "cliVersion": "15.12.2",
    }

    package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
    assert package["name"] == "@wordpress-hx/cli"
    assert package["type"] == "module"
    assert package["engines"] == {"node": "22.17.0"}
    assert package["bin"] == {"wphx-sdk": "build/index.js"}

    print(
        "CLI dependency lock passed: Genes 1.36.3, hxnodejs 10.0.0, "
        "Node 22.17.0"
    )


if __name__ == "__main__":
    main()
