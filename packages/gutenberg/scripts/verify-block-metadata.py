#!/usr/bin/env python3
"""Verify SDK-060 exact-profile metadata, ownership, and parity outputs."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from copy import deepcopy
from pathlib import Path


SHA256 = re.compile(r"[0-9a-f]{64}\Z")
BLOCK_NAME = re.compile(r"[a-z][a-z0-9-]*/[a-z][a-z0-9-]*\Z")


def load(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict), f"{path} must contain an object"
    return value


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_inventory(root: Path) -> tuple[str, list[dict[str, object]]]:
    records: list[dict[str, object]] = []
    material = bytearray()
    for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
        relative = path.relative_to(root).as_posix()
        content = path.read_bytes()
        content_sha256 = hashlib.sha256(content).hexdigest()
        records.append(
            {
                "path": relative,
                "sha256": content_sha256,
                "sizeBytes": len(content),
            }
        )
        material.extend(f"{content_sha256}  {relative}\n".encode())
    return hashlib.sha256(material).hexdigest(), records


def exact(value: dict[str, object], keys: set[str], label: str) -> None:
    assert set(value) == keys, f"{label} fields drifted: {set(value) ^ keys}"


def validate_profile(profile: dict[str, object], repository_root: Path) -> None:
    exact(
        profile,
        {
            "schemaVersion",
            "profileId",
            "catalogRevision",
            "source",
            "policy",
            "allowedMetadataKeys",
            "forbiddenMetadataKeys",
            "allowedSupportsKeys",
            "assetKeys",
            "allowedHandles",
        },
        "block profile",
    )
    assert profile["schemaVersion"] == 1
    assert profile["profileId"] == "wp70-release"
    assert profile["catalogRevision"] == "wp70-release/catalog-v1"
    assert profile["source"] == {
        "repository": "https://github.com/WordPress/gutenberg.git",
        "commit": "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd",
        "tree": "8bd91d6b490d79ef991d388409705b5cd06fdc94",
        "path": "schemas/json/block.json",
        "blob": "246cb4ed9d2e07da32c80c24d1201c72a420cb54",
        "sha256": (
            "f1709bcc9bde24e0a40d58dc3134ea0e917b07032b47f988b73e941200f3ab9d"
        ),
        "schemaUrl": "https://schemas.wp.org/trunk/block.json",
    }
    assert profile["policy"] == {
        "apiVersion": 3,
        "additionalProperties": False,
        "experimentalMetadata": False,
        "scriptModules": False,
        "manualBlockJsonEditing": False,
    }
    allowed = profile["allowedMetadataKeys"]
    assert isinstance(allowed, list) and allowed == sorted(set(allowed))
    assert {"apiVersion", "name", "title", "attributes", "supports"} <= set(
        allowed
    )
    forbidden = profile["forbiddenMetadataKeys"]
    assert isinstance(forbidden, list)
    assert {entry["key"] for entry in forbidden} == {
        "__experimental",
        "viewScriptModule",
        "futureOnly",
    }
    supports = profile["allowedSupportsKeys"]
    assert isinstance(supports, list) and supports == sorted(set(supports))

    catalog = load(
        repository_root / "generated/wp70-release/catalog-v1/catalog.json"
    )
    capabilities = {
        entry["capabilityId"]: entry
        for entry in catalog["catalog"]["capabilities"]
    }
    handles = profile["allowedHandles"]
    assert isinstance(handles, list)
    for handle in handles:
        capability = capabilities[handle["capabilityId"]]
        assert capability["kind"] == "script-handle"
        assert capability["classification"] == "public"
        assert capability["evidenceStatus"] == "inventoried"


def validate_attribute(name: str, value: object) -> None:
    assert re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", name)
    assert isinstance(value, dict)
    assert set(value) <= {
        "type",
        "enum",
        "source",
        "selector",
        "attribute",
        "role",
        "default",
    }
    assert value.get("type") in {
        "boolean",
        "integer",
        "number",
        "string",
        "rich-text",
        "array",
    }
    if "enum" in value:
        assert value["type"] == "string"
        assert isinstance(value["enum"], list)
        assert len(value["enum"]) == len(set(value["enum"]))
        if "default" in value:
            assert value["default"] in value["enum"]
    if value.get("source") == "attribute":
        assert "selector" in value and "attribute" in value
    if value.get("source") in {"text", "rich-text", "html"}:
        assert "selector" in value and "attribute" not in value
    if "role" in value:
        assert value["role"] in {"content", "local"}
    if "default" in value:
        expected = value["type"]
        default = value["default"]
        type_checks = {
            "boolean": lambda candidate: isinstance(candidate, bool),
            "integer": lambda candidate: isinstance(candidate, int)
            and not isinstance(candidate, bool),
            "number": lambda candidate: isinstance(candidate, (int, float))
            and not isinstance(candidate, bool),
            "string": lambda candidate: isinstance(candidate, str),
            "rich-text": lambda candidate: isinstance(candidate, str),
            "array": lambda candidate: isinstance(candidate, list),
        }
        assert type_checks[expected](default), f"invalid default for {name}"


def validate_block_document(
    block: dict[str, object], profile: dict[str, object]
) -> None:
    allowed = set(profile["allowedMetadataKeys"]) | {"$schema"}
    assert set(block) <= allowed
    assert block["$schema"] == profile["source"]["schemaUrl"]
    assert block["apiVersion"] == 3
    assert BLOCK_NAME.fullmatch(block["name"])
    assert isinstance(block["title"], str) and block["title"]
    assert block["category"] in {
        "text",
        "media",
        "design",
        "widgets",
        "theme",
        "embed",
    }
    attributes = block["attributes"]
    assert isinstance(attributes, dict) and attributes
    for name, value in attributes.items():
        validate_attribute(name, value)
    if "supports" in block:
        assert isinstance(block["supports"], dict)
        assert set(block["supports"]) <= set(profile["allowedSupportsKeys"])
    assert "editorScript" in block
    assert "viewScriptModule" not in block and "__experimental" not in block


def validate_registration(
    registration: dict[str, object],
    profile: dict[str, object],
    block: dict[str, object],
    metadata_path: str,
    metadata_sha256: str,
) -> None:
    exact(
        registration,
        {"schemaVersion", "profileId", "kind", "client", "server"},
        "registration plan",
    )
    assert registration["schemaVersion"] == 1
    assert registration["profileId"] == profile["profileId"]
    assert registration["kind"] in {"static", "dynamic"}
    client = registration["client"]
    server = registration["server"]
    assert isinstance(client, dict) and isinstance(server, dict)
    identity_keys = {"blockName", "metadataPath", "metadataSha256"}
    assert {key: client[key] for key in identity_keys} == {
        key: server[key] for key in identity_keys
    } == {
        "blockName": block["name"],
        "metadataPath": metadata_path,
        "metadataSha256": metadata_sha256,
    }
    assert client["api"] == "registerBlockType"
    assert server["api"] == "register_block_type"
    assert client["capabilityId"] == (
        "gutenberg.export.@wordpress/blocks.registerBlockType"
    )
    assert server["capabilityId"] == (
        "wordpress.php.function.register_block_type"
    )


def validate_ownership(
    output_root: Path,
    block: dict[str, object],
    manifest: dict[str, object],
) -> None:
    records = manifest["artifacts"]
    assert isinstance(records, list)
    index = {
        (entry["blockName"], entry["metadataKey"], entry["reference"]): entry
        for entry in records
    }
    for metadata_key in {
        "editorScript",
        "script",
        "viewScript",
        "editorStyle",
        "style",
        "viewStyle",
        "render",
    }:
        if metadata_key not in block:
            continue
        references = block[metadata_key]
        if isinstance(references, str):
            references = [references]
        assert isinstance(references, list)
        for reference in references:
            record = index[(block["name"], metadata_key, reference)]
            if record["referenceKind"] == "file":
                artifact = output_root / record["path"]
                assert artifact.is_file()
                assert digest(artifact) == record["sha256"]
            else:
                assert record["referenceKind"] == "handle"
                identity = "\n".join(
                    [record["owner"], record["capabilityId"], reference]
                ).encode()
                assert hashlib.sha256(identity).hexdigest() == record["sha256"]


def validate_mutations(
    callout: dict[str, object],
    registration: dict[str, object],
    profile: dict[str, object],
    metadata_path: str,
    metadata_sha256: str,
) -> int:
    failures = 0

    def rejected(action: object) -> None:
        nonlocal failures
        try:
            action()
        except (AssertionError, KeyError, TypeError):
            failures += 1
            return
        raise AssertionError("SDK-060 verifier accepted an invalid mutation")

    unknown = deepcopy(callout)
    unknown["mysteryKey"] = True
    rejected(lambda: validate_block_document(unknown, profile))

    forward = deepcopy(callout)
    forward["viewScriptModule"] = "file:./build/view.js"
    rejected(lambda: validate_block_document(forward, profile))

    api = deepcopy(callout)
    api["apiVersion"] = 4
    rejected(lambda: validate_block_document(api, profile))

    default = deepcopy(callout)
    default["attributes"]["tone"]["default"] = "danger"
    rejected(lambda: validate_block_document(default, profile))

    support = deepcopy(callout)
    support["supports"]["telepathy"] = True
    rejected(lambda: validate_block_document(support, profile))

    missing_editor = deepcopy(callout)
    del missing_editor["editorScript"]
    rejected(lambda: validate_block_document(missing_editor, profile))

    client = deepcopy(registration)
    client["client"]["blockName"] = "wordpresshx/other"
    rejected(
        lambda: validate_registration(
            client, profile, callout, metadata_path, metadata_sha256
        )
    )

    server = deepcopy(registration)
    server["server"]["metadataSha256"] = "0" * 64
    rejected(
        lambda: validate_registration(
            server, profile, callout, metadata_path, metadata_sha256
        )
    )
    return failures


def compare_trees(left: Path, right: Path) -> None:
    left_files = sorted(path.relative_to(left) for path in left.rglob("*") if path.is_file())
    right_files = sorted(
        path.relative_to(right) for path in right.rglob("*") if path.is_file()
    )
    assert left_files == right_files
    for path in left_files:
        assert (left / path).read_bytes() == (right / path).read_bytes(), path


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: verify-block-metadata.py <profile> <assets> <build> <replay>"
        )
    profile_path, assets_path, build_root, replay_root = map(Path, sys.argv[1:])
    repository_root = Path(__file__).resolve().parents[3]
    profile = load(profile_path)
    assets = load(assets_path)
    expected = load(repository_root / "packages/gutenberg/test/expected/block-metadata.json")
    build = build_root.resolve()
    replay = replay_root.resolve()
    validate_profile(profile, repository_root)
    exact(assets, {"schemaVersion", "profileId", "artifacts"}, "asset manifest")
    assert assets["schemaVersion"] == 1
    assert assets["profileId"] == profile["profileId"]
    compare_trees(build, replay)
    exact(
        expected,
        {"schemaVersion", "treeDigestAlgorithm", "generatedTreeSha256", "files"},
        "expected block metadata",
    )
    assert expected["schemaVersion"] == 1
    assert expected["treeDigestAlgorithm"] == (
        "sha256-lines-of-sha256-two-spaces-path-lf-v1"
    )
    generated_tree_sha256, generated_files = tree_inventory(build)
    assert generated_tree_sha256 == expected["generatedTreeSha256"]
    assert generated_files == expected["files"]

    generation = load(build / "block-generation-manifest.json")
    exact(
        generation,
        {
            "schemaVersion",
            "profileId",
            "catalogRevision",
            "blockSchemaSha256",
            "generator",
            "blocks",
        },
        "generation manifest",
    )
    assert generation["schemaVersion"] == 1
    assert generation["profileId"] == profile["profileId"]
    assert generation["catalogRevision"] == profile["catalogRevision"]
    assert generation["blockSchemaSha256"] == profile["source"]["sha256"]
    assert generation["generator"] == "wordpresshx-sdk060-block-metadata-v1"
    assert [entry["name"] for entry in generation["blocks"]] == [
        "wordpresshx/book-grid",
        "wordpresshx/callout",
    ]

    callout: dict[str, object] | None = None
    callout_registration: dict[str, object] | None = None
    callout_path = ""
    callout_sha256 = ""
    for entry in generation["blocks"]:
        assert SHA256.fullmatch(entry["metadataSha256"])
        assert SHA256.fullmatch(entry["registrationSha256"])
        metadata_path = entry["metadataPath"]
        registration_path = entry["registrationPath"]
        assert digest(build / metadata_path) == entry["metadataSha256"]
        assert digest(build / registration_path) == entry["registrationSha256"]
        block = load(build / metadata_path)
        registration = load(build / registration_path)
        validate_block_document(block, profile)
        validate_registration(
            registration,
            profile,
            block,
            metadata_path,
            entry["metadataSha256"],
        )
        validate_ownership(build, block, assets)
        assert entry["kind"] == (
            "dynamic" if "render" in block else "static"
        ) == registration["kind"]
        if block["name"] == "wordpresshx/callout":
            callout = block
            callout_registration = registration
            callout_path = metadata_path
            callout_sha256 = entry["metadataSha256"]

    assert callout is not None and callout_registration is not None
    assert callout["attributes"] == {
        "message": {
            "default": "",
            "role": "content",
            "selector": "p",
            "source": "rich-text",
            "type": "rich-text",
        },
        "tone": {
            "default": "info",
            "enum": ["info", "warning"],
            "type": "string",
        },
    }
    mutation_count = validate_mutations(
        callout,
        callout_registration,
        profile,
        callout_path,
        callout_sha256,
    )
    print(
        "SDK-060 block metadata passed: "
        f"2 blocks, {len(assets['artifacts'])} owned assets, "
        f"{mutation_count} fail-closed mutations"
    )


if __name__ == "__main__":
    main()
