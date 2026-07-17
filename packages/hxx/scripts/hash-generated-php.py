#!/usr/bin/env python3
"""Hash generated PHP after narrow Haxe-stdlib source-marker normalization."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


HAXE_VERSION = "4.3.7"
STDLIB_SOURCE_MARKER = re.compile(
    rb"(?m)^([ \t]*)#[^\r\n]*[\\/]haxe[\\/]versions[\\/]4\.3\.7[\\/]std[\\/]"
)
ABSOLUTE_SOURCE_MARKER = re.compile(
    rb"(?m)^[ \t]*#(?:[\\/]|[A-Za-z]:[\\/])"
)
CANONICAL_STDLIB_MARKER = rb"\1#<haxe-stdlib>/"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--format", choices=("json", "tsv"), default="json")
    return parser.parse_args()


def collect_metrics(root: Path) -> dict[str, int | str]:
    if not root.is_dir():
        raise ValueError(f"generated PHP root is not a directory: {root}")

    paths = sorted(
        (path for path in root.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(root).as_posix(),
    )
    if not paths:
        raise ValueError("generated PHP root contains no files")

    raw_size = 0
    normalized_size = 0
    stdlib_marker_count = 0
    digest_input = bytearray()
    for path in paths:
        relative = path.relative_to(root).as_posix()
        raw = path.read_bytes()
        normalized, marker_count = STDLIB_SOURCE_MARKER.subn(
            CANONICAL_STDLIB_MARKER,
            raw,
        )
        if ABSOLUTE_SOURCE_MARKER.search(normalized):
            raise ValueError(
                f"unrecognized absolute generated source marker: {relative}"
            )
        raw_size += len(raw)
        normalized_size += len(normalized)
        stdlib_marker_count += marker_count
        digest = hashlib.sha256(normalized).hexdigest()
        digest_input.extend(f"{digest}  {relative}\n".encode())

    return {
        "fileCount": len(paths),
        "rawSizeBytes": raw_size,
        "normalizedSizeBytes": normalized_size,
        "stdlibSourceMarkerCount": stdlib_marker_count,
        "normalizedContentTreeSha256": hashlib.sha256(digest_input).hexdigest(),
    }


def main() -> None:
    arguments = parse_arguments()
    metrics = collect_metrics(arguments.root)
    if arguments.format == "tsv":
        print(
            "\t".join(
                str(metrics[key])
                for key in (
                    "fileCount",
                    "rawSizeBytes",
                    "normalizedSizeBytes",
                    "stdlibSourceMarkerCount",
                    "normalizedContentTreeSha256",
                )
            )
        )
        return
    print(json.dumps(metrics, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
