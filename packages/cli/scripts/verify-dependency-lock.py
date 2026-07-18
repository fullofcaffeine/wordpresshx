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
    assert lock["browserCorrelation"] == {
        "genesMapFormat": "source-map-v3",
        "bundler": {
            "name": "esbuild",
            "version": "0.27.2",
            "npmIntegrity": "sha512-HyNQImnsOC7X9PMNaCIeAm4ISCQXs5a5YasTXVliKv4uuBo1dKrG0A+uQS8M5eXjVMnLg3WgXaKvprHlFJQffw==",
        },
        "browserDriver": {
            "name": "playwright-core",
            "version": "1.58.2",
            "npmIntegrity": "sha512-yZkEtftgwS8CsfYo7nm0KE8jsvm6i/PTgVtB8DL726wNf6H2IMsDuxCpJj59KDaxCtSnrWan2AeDqM7JBaultg==",
        },
        "browserRuntime": {
            "image": "mcr.microsoft.com/playwright@sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d",
            "node": "24.13.0",
            "npm": "11.6.2",
            "platforms": {
                "linux/amd64": {
                    "manifestDigest": "sha256:65cefd09a5e943921ecd3a6e5414c603db2eb161e9eb48f2e2ccc63486dc7dc0",
                    "browserVersion": "145.0.7632.6",
                },
                "linux/arm64": {
                    "manifestDigest": "sha256:68f1c3dca663d0e8331e8af4681b0b315eca7de1bd7fa934aac0accbeb9f8323",
                    "browserVersion": "145.0.7632.0",
                },
            },
        },
        "npmClosure": {
            "manifest": "packages/cli/browser-tooling/package.json",
            "lock": "packages/cli/browser-tooling/package-lock.json",
            "install": "npm ci --ignore-scripts --no-audit --no-fund",
        },
    }

    package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
    assert package["name"] == "@wordpress-hx/cli"
    assert package["type"] == "module"
    assert package["engines"] == {"node": "22.17.0"}
    assert package["bin"] == {
        "wphx": "build/wphx.js",
        "wphx-sdk": "build/index.js",
    }

    browser_manifest = json.loads(
        (ROOT / "browser-tooling/package.json").read_text(encoding="utf-8")
    )
    browser_lock = json.loads(
        (ROOT / "browser-tooling/package-lock.json").read_text(encoding="utf-8")
    )
    assert browser_manifest["name"] == "@wordpress-hx/sdk-034-browser-tooling"
    assert browser_manifest["private"] is True
    assert browser_manifest["engines"] == {
        "node": "22.17.0",
        "npm": "10.9.2",
    }
    assert browser_manifest["packageManager"] == "npm@10.9.2"
    assert browser_manifest["devDependencies"] == {
        "esbuild": "0.27.2",
        "playwright-core": "1.58.2",
    }
    assert browser_lock["lockfileVersion"] == 3
    assert browser_lock["requires"] is True
    assert browser_lock["packages"][""]["devDependencies"] == browser_manifest[
        "devDependencies"
    ]
    assert browser_lock["packages"]["node_modules/esbuild"] == {
        "version": "0.27.2",
        "resolved": "https://registry.npmjs.org/esbuild/-/esbuild-0.27.2.tgz",
        "integrity": "sha512-HyNQImnsOC7X9PMNaCIeAm4ISCQXs5a5YasTXVliKv4uuBo1dKrG0A+uQS8M5eXjVMnLg3WgXaKvprHlFJQffw==",
        "dev": True,
        "hasInstallScript": True,
        "license": "MIT",
        "bin": {"esbuild": "bin/esbuild"},
        "engines": {"node": ">=18"},
        "optionalDependencies": {
            name.removeprefix("node_modules/"): entry["version"]
            for name, entry in browser_lock["packages"].items()
            if name.startswith("node_modules/@esbuild/")
        },
    }
    assert browser_lock["packages"]["node_modules/playwright-core"] == {
        "version": "1.58.2",
        "resolved": "https://registry.npmjs.org/playwright-core/-/playwright-core-1.58.2.tgz",
        "integrity": "sha512-yZkEtftgwS8CsfYo7nm0KE8jsvm6i/PTgVtB8DL726wNf6H2IMsDuxCpJj59KDaxCtSnrWan2AeDqM7JBaultg==",
        "dev": True,
        "license": "Apache-2.0",
        "bin": {"playwright-core": "cli.js"},
        "engines": {"node": ">=18"},
    }
    npm_integrity = "sha512-"
    for package_path, entry in browser_lock["packages"].items():
        if not package_path:
            continue
        assert entry["resolved"].startswith("https://registry.npmjs.org/")
        assert entry["integrity"].startswith(npm_integrity)
        assert "file:" not in entry["resolved"]

    playwright_image = json.loads(
        (REPOSITORY_ROOT / "docker/images.lock.json").read_text(encoding="utf-8")
    )["images"]["playwright"]
    assert playwright_image == {
        "tag": "mcr.microsoft.com/playwright:v1.58.2-noble",
        "reference": "mcr.microsoft.com/playwright@sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d",
        "indexDigest": "sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d",
        "requiredPlatforms": ["linux/amd64", "linux/arm64"],
        "purpose": "exact SDK-034 Chromium source-correlation runtime",
        "evidenceStatus": "runtime-tested",
    }

    print(
        "CLI dependency lock passed: Genes 1.36.3, hxnodejs 10.0.0, "
        "Node 22.17.0, esbuild 0.27.2, Playwright/Chromium 1.58.2"
    )


if __name__ == "__main__":
    main()
