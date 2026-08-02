#!/usr/bin/env python3
"""Verify semantic-matrix PHP/map output against independently authored source facts."""

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
    require(len(sys.argv) == 4, "usage: verify-semantic-matrix.py SOURCE_ROOT PHP MAP")
    source_root = Path(sys.argv[1])
    sources = {
        path.relative_to(source_root).as_posix(): path.read_bytes()
        for path in sorted(source_root.rglob("*.hx"))
    }
    generated = Path(sys.argv[2]).read_bytes()
    document = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))

    require(document["format"] == "reflaxe.php-range-map.v1", "range-map format drifted")
    require(document["generated"]["sha256"] == digest(generated), "generated PHP digest drifted")
    require(document["generated"]["byteLength"] == len(generated), "generated PHP byte length drifted")
    source_records = {record["path"]: record for record in document["sources"]}
    require(set(source_records) == set(sources), "semantic source inventory drifted")
    for path, source in sources.items():
        source_record = source_records[path]
        require(source_record["sha256"] == digest(source), f"Haxe source digest drifted for {path}")
        require(source_record["byteLength"] == len(source), f"Haxe source byte length drifted for {path}")

    expected = {
        "class:semantics.Calculator:Calculator": ("declaration", 0, "semantics/Calculator.hx", b"class Calculator"),
        "method:semantics.Calculator:add": ("member", 1, "semantics/Calculator.hx", b"public static function add"),
        "stmt:return-int:96:115": ("statement", 2, "semantics/Calculator.hx", b"return left + right"),
        "class:semantics.Main:Main": ("declaration", 0, "semantics/Main.hx", b"class Main"),
        "method:semantics.Main:main": ("member", 1, "semantics/Main.hx", b"public static function main"),
        "stmt:local-int:73:110": ("statement", 2, "semantics/Main.hx", b"final answer = Calculator.add(40, 2)"),
        "stmt:if-int-equality:113:237": ("statement", 2, "semantics/Main.hx", b"if (answer == 42)"),
        "stmt:sys-println:136:176": ("statement", 3, "semantics/Main.hx", b'Sys.println("numeric-control-flow:pass")'),
        "stmt:sys-println:192:232": ("statement", 3, "semantics/Main.hx", b'Sys.println("numeric-control-flow:fail")'),
        "entrypoint:semantics.Main:Main": ("statement", 0, "semantics/Main.hx", b"class Main"),
    }
    mappings = document["mappings"]
    require({mapping["id"] for mapping in mappings} == set(expected), "semantic mapping identities drifted")
    for mapping in mappings:
        mapping_id = mapping["id"]
        node_kind, structural_depth, source_path, fragment = expected[mapping_id]
        require(mapping["nodeKind"] == node_kind, f"node kind drifted for {mapping_id}")
        require(mapping["structuralDepth"] == structural_depth, f"mapping depth drifted for {mapping_id}")
        origin = mapping["origin"]
        require(origin["sourceId"] == "source:" + source_path, f"source identity drifted for {mapping_id}")
        span = origin["sourceSpan"]
        selected = sources[source_path][span["startByte"] : span["endByte"]]
        require(fragment in selected, f"source span lost its semantic owner for {mapping_id}")

    anchors = {anchor["mappingId"] for anchor in document["traceAnchors"]}
    require(
        anchors
        == {
            "stmt:return-int:96:115",
            "stmt:local-int:73:110",
            "stmt:if-int-equality:113:237",
            "stmt:sys-println:136:176",
            "stmt:sys-println:192:232",
        },
        "semantic trace anchors drifted",
    )
    print("reflaxe.php numeric/control-flow/function-call map passed")


if __name__ == "__main__":
    main()
