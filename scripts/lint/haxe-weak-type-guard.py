#!/usr/bin/env python3
"""Reject forbidden weak-typing constructs in repository-owned Haxe source."""

from __future__ import annotations

import re
import sys
from pathlib import Path


FORBIDDEN = ("Dynamic", "Any", "cast", "Reflect", "untyped")
PATTERN = re.compile(rf"\b(?:{'|'.join(map(re.escape, FORBIDDEN))})\b")


def matching_lines(source: Path, content: str) -> list[str]:
    return [
        f"{source}:{line_number}:{line}"
        for line_number, line in enumerate(content.splitlines(), start=1)
        if PATTERN.search(line) is not None
    ]


def self_test() -> None:
    synthetic_source = Path("self-test.hx")
    forbidden_content = "\n".join(FORBIDDEN)
    matches = matching_lines(synthetic_source, forbidden_content)
    if len(matches) != len(FORBIDDEN):
        raise RuntimeError(
            "forbidden-token self-test failed: "
            f"expected {len(FORBIDDEN)} matches, found {len(matches)}"
        )

    allowed_content = "\n".join(
        ("DynamicValue", "Anything", "castaway", "Reflection", "typed")
    )
    allowed_matches = matching_lines(synthetic_source, allowed_content)
    if allowed_matches:
        raise RuntimeError(
            "allowed-token self-test failed: " + ", ".join(allowed_matches)
        )


def haxe_files(raw_path: str) -> list[Path]:
    path = Path(raw_path)
    if not path.exists():
        raise ValueError(f"input does not exist: {path}")
    if path.is_file():
        if path.suffix != ".hx":
            raise ValueError(f"input file is not Haxe source: {path}")
        return [path]
    if not path.is_dir():
        raise ValueError(f"input is neither a file nor directory: {path}")
    files = sorted(candidate for candidate in path.rglob("*.hx") if candidate.is_file())
    if not files:
        raise ValueError(f"input directory contains no Haxe source: {path}")
    return files


def main(arguments: list[str]) -> int:
    if arguments == ["--self-test"]:
        self_test()
        print("[guard:haxe-weak-types] Positive and negative self-tests passed.")
        return 0
    if not arguments or "--self-test" in arguments:
        print(
            "usage: haxe-weak-type-guard.py --self-test | <path> [<path> ...]",
            file=sys.stderr,
        )
        return 2

    try:
        sources = [source for raw_path in arguments for source in haxe_files(raw_path)]
    except ValueError as error:
        print(f"[guard:haxe-weak-types] ERROR: {error}", file=sys.stderr)
        return 2

    violations: list[str] = []
    for source in sources:
        violations.extend(matching_lines(source, source.read_text(encoding="utf-8")))

    if violations:
        print(
            "[guard:haxe-weak-types] ERROR: forbidden weak-type constructs found.",
            file=sys.stderr,
        )
        print("\n".join(violations), file=sys.stderr)
        return 1

    print(f"[guard:haxe-weak-types] OK: scanned {len(sources)} Haxe files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
