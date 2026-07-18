#!/usr/bin/env python3
"""Strict, dependency-free helpers for regular Source Map v3 projection."""

from __future__ import annotations

import hashlib
import json
from pathlib import PurePosixPath


BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_logical_path(value: str) -> str:
    path = PurePosixPath(value)
    if (
        not value
        or value.endswith("/")
        or "//" in value
        or path.is_absolute()
        or "\\" in value
        or ":" in value
        or any(part in {"", ".", ".."} for part in path.parts)
        or any(ord(character) < 32 or ord(character) == 127 for character in value)
    ):
        raise ValueError(f"unsafe logical path: {value}")
    return value


def decode_vlq(value: str, offset: int) -> tuple[int, int]:
    accumulated = 0
    shift = 0
    while True:
        if offset >= len(value):
            raise ValueError("unterminated Source Map VLQ")
        digit = BASE64.find(value[offset])
        if digit < 0:
            raise ValueError("non-base64 Source Map VLQ digit")
        offset += 1
        accumulated += (digit & 31) << shift
        shift += 5
        if shift > 35 or accumulated > 2_147_483_647:
            raise ValueError("Source Map VLQ exceeds supported integer range")
        if not digit & 32:
            break
    magnitude = accumulated >> 1
    return (-magnitude if accumulated & 1 else magnitude), offset


def encode_vlq(value: int) -> str:
    encoded = ((-value) << 1 | 1) if value < 0 else value << 1
    output: list[str] = []
    while True:
        digit = encoded & 31
        encoded >>= 5
        if encoded:
            digit |= 32
        output.append(BASE64[digit])
        if not encoded:
            return "".join(output)


def decode_segment(value: str) -> list[int]:
    if not value:
        raise ValueError("empty Source Map segment")
    output: list[int] = []
    offset = 0
    while offset < len(value):
        decoded, offset = decode_vlq(value, offset)
        output.append(decoded)
    if len(output) not in {1, 4, 5}:
        raise ValueError("unsupported Source Map segment field count")
    if output[0] < 0:
        raise ValueError("negative Source Map generated-column delta")
    return output


def referenced_source_indexes(
    mappings: str,
    source_count: int,
    name_count: int | None = None,
) -> set[int]:
    if not mappings:
        raise ValueError("empty Source Map mappings")
    previous_source = 0
    previous_original_line = 0
    previous_original_column = 0
    previous_name = 0
    referenced: set[int] = set()
    for line in mappings.split(";"):
        generated_column = 0
        for segment in line.split(",") if line else ():
            fields = decode_segment(segment)
            generated_column += fields[0]
            if generated_column < 0:
                raise ValueError("Source Map generated column overflowed")
            if len(fields) > 1:
                previous_source += fields[1]
                previous_original_line += fields[2]
                previous_original_column += fields[3]
                if not 0 <= previous_source < source_count:
                    raise ValueError(
                        "Source Map segment references an unknown source"
                    )
                if previous_original_line < 0 or previous_original_column < 0:
                    raise ValueError(
                        "Source Map segment has a negative original position"
                    )
                if len(fields) == 5:
                    previous_name += fields[4]
                    if previous_name < 0 or (
                        name_count is not None and previous_name >= name_count
                    ):
                        raise ValueError(
                            "Source Map segment references an unknown name"
                        )
                referenced.add(previous_source)
    if not referenced:
        raise ValueError("Source Map has no mapped segments")
    return referenced


def project_mappings(
    mappings: str,
    old_to_new: list[int | None],
) -> str:
    """Project a map onto admitted sources, leaving other segments unmapped."""

    admitted = {value for value in old_to_new if value is not None}
    if admitted != set(range(len(admitted))):
        raise ValueError("projected Source Map source indexes are not contiguous")

    previous_old_source = 0
    previous_old_line = 0
    previous_old_column = 0
    previous_old_name = 0
    previous_new_source = 0
    previous_new_line = 0
    previous_new_column = 0
    previous_new_name = 0
    referenced: set[int] = set()
    mapped = 0
    output_lines: list[str] = []

    for line in mappings.split(";"):
        generated_column = 0
        output_segments: list[str] = []
        for segment in line.split(",") if line else ():
            fields = decode_segment(segment)
            generated_column += fields[0]
            if generated_column < 0:
                raise ValueError("Source Map generated column overflowed")
            if len(fields) == 1:
                output_segments.append(encode_vlq(fields[0]))
                continue

            previous_old_source += fields[1]
            previous_old_line += fields[2]
            previous_old_column += fields[3]
            if (
                not 0 <= previous_old_source < len(old_to_new)
                or previous_old_line < 0
                or previous_old_column < 0
            ):
                raise ValueError("Source Map contains an invalid original position")
            if len(fields) == 5:
                previous_old_name += fields[4]
                if previous_old_name < 0:
                    raise ValueError("Source Map contains a negative name index")

            projected = old_to_new[previous_old_source]
            if projected is None:
                output_segments.append(encode_vlq(fields[0]))
                continue

            next_fields = [
                fields[0],
                projected - previous_new_source,
                previous_old_line - previous_new_line,
                previous_old_column - previous_new_column,
            ]
            previous_new_source = projected
            previous_new_line = previous_old_line
            previous_new_column = previous_old_column
            if len(fields) == 5:
                next_fields.append(previous_old_name - previous_new_name)
                previous_new_name = previous_old_name
            output_segments.append(
                "".join(encode_vlq(value) for value in next_fields)
            )
            referenced.add(projected)
            mapped += 1
        output_lines.append(",".join(output_segments))

    if mapped == 0 or referenced != admitted:
        raise ValueError("projected Source Map did not retain every admitted source")
    return ";".join(output_lines)
