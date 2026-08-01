#!/usr/bin/env python3
"""Verify the first semantic-matrix PHP/map output against authored source facts."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def digest(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def main() -> None:
    require(len(sys.argv) == 4, "usage: verify-semantic-matrix.py SOURCE PHP MAP")
    source = Path(sys.argv[1]).read_bytes()
    generated = Path(sys.argv[2]).read_bytes()
    document = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))

    require(document["format"] == "reflaxe.php-range-map.v1", "range-map format drifted")
    require(document["generated"]["sha256"] == digest(generated), "generated PHP digest drifted")
    require(document["generated"]["byteLength"] == len(generated), "generated PHP byte length drifted")
    require(len(document["sources"]) == 1, "semantic fixture must have one application source")
    source_record = document["sources"][0]
    require(source_record["path"] == "semantics/Main.hx", "logical source path drifted")
    require(source_record["sha256"] == digest(source), "Haxe source digest drifted")
    require(source_record["byteLength"] == len(source), "Haxe source byte length drifted")

    expected = {
        "class:semantics.Main:Main": ("declaration", 0, b"class Main"),
        "method:semantics.Main:main": ("member", 1, b"public static function main"),
        "stmt:local-int:73:95": ("statement", 2, b"final answer = 40 + 2"),
        "stmt:if-int-equality:98:222": ("statement", 2, b"if (answer == 42)"),
        "stmt:sys-println:121:161": ("statement", 3, b'Sys.println("numeric-control-flow:pass")'),
        "stmt:sys-println:177:217": ("statement", 3, b'Sys.println("numeric-control-flow:fail")'),
        "entrypoint:semantics.Main:Main": ("statement", 0, b"class Main"),
    }
    mappings = document["mappings"]
    require({mapping["id"] for mapping in mappings} == set(expected), "semantic mapping identities drifted")
    for mapping in mappings:
        mapping_id = mapping["id"]
        node_kind, structural_depth, fragment = expected[mapping_id]
        require(mapping["nodeKind"] == node_kind, f"node kind drifted for {mapping_id}")
        require(mapping["structuralDepth"] == structural_depth, f"mapping depth drifted for {mapping_id}")
        origin = mapping["origin"]
        require(origin["sourceId"] == "source:semantics/Main.hx", f"source identity drifted for {mapping_id}")
        span = origin["sourceSpan"]
        selected = source[span["startByte"] : span["endByte"]]
        require(fragment in selected, f"source span lost its semantic owner for {mapping_id}")

    anchors = {anchor["mappingId"] for anchor in document["traceAnchors"]}
    require(
        anchors
        == {
            "stmt:local-int:73:95",
            "stmt:if-int-equality:98:222",
            "stmt:sys-println:121:161",
            "stmt:sys-println:177:217",
        },
        "semantic trace anchors drifted",
    )
    print("reflaxe.php numeric/control-flow map passed")


if __name__ == "__main__":
    main()
