#!/usr/bin/env python3
"""Stage SDK-061 block assets and emit the SDK-060 ownership manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def emit(bundle_root: Path, css_path: Path, output_root: Path, manifest_path: Path) -> None:
    editor_js = bundle_root / "editor.js"
    editor_asset = bundle_root / "editor.asset.php"
    assert editor_js.is_file(), "production editor bundle is absent"
    assert editor_asset.is_file(), "production WordPress asset metadata is absent"
    assert css_path.is_file(), "static block stylesheet is absent"
    assert output_root.is_dir(), "output root must be pre-created"
    assert not manifest_path.exists(), "asset manifest already exists"

    block_root = output_root / "blocks/callout"
    build_root = block_root / "build"
    assert not block_root.exists(), "static block staging root already exists"
    build_root.mkdir(parents=True)
    shutil.copyfile(editor_js, build_root / "editor.js")
    shutil.copyfile(editor_asset, build_root / "editor.asset.php")
    shutil.copyfile(css_path, block_root / "style.css")

    manifest = {
        "schemaVersion": 1,
        "profileId": "wp70-release",
        "artifacts": [
            {
                "id": "callout-editor",
                "blockName": "wordpresshx/callout",
                "metadataKey": "editorScript",
                "kind": "script",
                "referenceKind": "file",
                "reference": "file:./build/editor.js",
                "path": "blocks/callout/build/editor.js",
                "owner": "wordpresshx.callout",
                "capabilityId": "",
                "sha256": digest(build_root / "editor.js"),
            },
            {
                "id": "callout-style",
                "blockName": "wordpresshx/callout",
                "metadataKey": "style",
                "kind": "style",
                "referenceKind": "file",
                "reference": "file:./style.css",
                "path": "blocks/callout/style.css",
                "owner": "wordpresshx.callout",
                "capabilityId": "",
                "sha256": digest(block_root / "style.css"),
            },
        ],
    }
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-root", type=Path, required=True)
    parser.add_argument("--css", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    emit(
        args.bundle_root.resolve(),
        args.css.resolve(),
        args.output_root.resolve(),
        args.manifest.resolve(),
    )


if __name__ == "__main__":
    main()
