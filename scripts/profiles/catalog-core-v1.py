#!/usr/bin/env python3
"""Generate exact-profile capability inventories from pinned Git objects.

The generator reads only explicitly selected blobs with ``git show``. It does
not check out or execute upstream PHP, JavaScript, or TypeScript. Lexical
presence is emitted as ``inventoried`` evidence; ambiguous contracts are
reported as omissions for later curation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SELECTION = ROOT / "profiles" / "catalog-selection.json"
PROFILE_SCHEMA = ROOT / "schemas" / "profile.schema.json"
TOOLCHAIN_IDENTITY = "python-stdlib-json-v1+git-object-reader-v1"


class GenerationError(RuntimeError):
    """An exact input or closed selection invariant did not hold."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def pretty_json(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    ).encode("utf-8")


def json_pointer(value: object, pointer: str) -> object:
    if pointer == "":
        return value
    if not pointer.startswith("/"):
        raise GenerationError(f"invalid JSON pointer: {pointer}")
    current = value
    for raw_component in pointer[1:].split("/"):
        component = raw_component.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict) and component in current:
            current = current[component]
        elif isinstance(current, list) and component.isdigit():
            index = int(component)
            if index >= len(current):
                raise GenerationError(f"JSON pointer index is absent: {pointer}")
            current = current[index]
        else:
            raise GenerationError(f"JSON pointer is absent: {pointer}")
    return current


def safe_source_path(value: str) -> str:
    if not value or "\\" in value or "\x00" in value:
        raise GenerationError(f"unsafe source path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or path.as_posix() in {"", "."}:
        raise GenerationError(f"unsafe source path: {value!r}")
    return path.as_posix()


def safe_target_path(value: str) -> Path:
    normalized = safe_source_path(value)
    return Path(*PurePosixPath(normalized).parts)


def run_git(repository: Path, *arguments: str, check: bool = True) -> bytes:
    completed = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        raise GenerationError(
            f"git {' '.join(arguments)} failed for exact repository: {detail}"
        )
    return completed.stdout


def git_text(repository: Path, *arguments: str) -> str:
    return run_git(repository, *arguments).decode("utf-8").strip()


def has_git_object(repository: Path, expression: str) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(repository), "cat-file", "-e", expression],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return completed.returncode == 0


def materialize_repository(
    destination: Path, repository_url: str, commit: str
) -> None:
    if not (destination / ".git").is_dir():
        if destination.exists() and any(destination.iterdir()):
            raise GenerationError(
                f"repository cache path is non-empty and unowned: {destination}"
            )
        destination.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["git", "init", "-q", str(destination)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        run_git(destination, "remote", "add", "origin", repository_url)
    remote_url = git_text(destination, "remote", "get-url", "origin")
    if remote_url != repository_url:
        raise GenerationError(
            f"repository cache remote mismatch for {destination.name}"
        )
    if not has_git_object(destination, f"{commit}^{{commit}}"):
        run_git(
            destination,
            "fetch",
            "-q",
            "--depth=1",
            "--filter=blob:none",
            "origin",
            commit,
        )


def parse_repository_arguments(values: list[str]) -> dict[str, Path]:
    repositories: dict[str, Path] = {}
    for value in values:
        name, separator, raw_path = value.partition("=")
        if not separator or not name or not raw_path:
            raise GenerationError(
                f"repository mapping must be NAME=PATH, found {value!r}"
            )
        if name in repositories:
            raise GenerationError(f"duplicate repository mapping: {name}")
        repositories[name] = Path(raw_path).resolve()
    return repositories


def input_from_lock(
    definition: dict[str, object], source_lock: dict[str, object]
) -> dict[str, object]:
    pointers = definition["pointers"]
    if not isinstance(pointers, dict):
        raise GenerationError("input pointers must be an object")
    resolved = {
        name: json_pointer(source_lock, str(pointer))
        for name, pointer in pointers.items()
    }
    common = {
        "inputId": definition["inputId"],
        "kind": definition["kind"],
        "providerIdentity": definition["providerIdentity"],
    }
    if definition["kind"] == "git-source":
        required = {"repository", "commit", "tree"}
        if not required.issubset(resolved):
            raise GenerationError("git input pointers are incomplete")
        output = {**common, **resolved}
    elif definition["kind"] == "release-artifact":
        required = {"url", "sizeBytes", "sha256"}
        if not required.issubset(resolved):
            raise GenerationError("release input pointers are incomplete")
        output = {**common, **resolved}
    else:
        raise GenerationError(f"unknown input kind: {definition['kind']}")
    return output


def verify_repository(
    repository: Path, exact_input: dict[str, object]
) -> None:
    if not (repository / ".git").is_dir():
        raise GenerationError(f"not a Git repository: {repository}")
    commit = str(exact_input["commit"])
    if not has_git_object(repository, f"{commit}^{{commit}}"):
        raise GenerationError(
            f"repository is missing exact commit {commit} for {exact_input['inputId']}"
        )
    actual_commit = git_text(repository, "rev-parse", f"{commit}^{{commit}}")
    actual_tree = git_text(repository, "rev-parse", f"{commit}^{{tree}}")
    if actual_commit != commit:
        raise GenerationError(
            f"commit identity mismatch for {exact_input['inputId']}"
        )
    if actual_tree != exact_input["tree"]:
        raise GenerationError(f"tree identity mismatch for {exact_input['inputId']}")


def read_git_blob(
    repository: Path, exact_input: dict[str, object], source_path: str
) -> bytes:
    path = safe_source_path(source_path)
    commit = str(exact_input["commit"])
    return run_git(repository, "show", f"{commit}:{path}")


def exported_names(source: str) -> list[str]:
    names: list[str] = []
    for match in re.finditer(
        r"\bexport\s*\{(?P<body>.*?)\}\s*from\s*['\"]",
        source,
        re.DOTALL,
    ):
        body = re.sub(r"/\*.*?\*/", "", match.group("body"), flags=re.DOTALL)
        body = re.sub(r"//[^\n]*", "", body)
        for raw_entry in body.split(","):
            entry = raw_entry.strip()
            if not entry:
                continue
            entry = re.sub(r"^type\s+", "", entry)
            alias = re.split(r"\s+as\s+", entry)
            name = alias[-1].strip()
            if re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", name):
                names.append(name)
    return names


def locator_count(source: bytes, locator: dict[str, object]) -> int:
    text = source.decode("utf-8")
    kind = locator["kind"]
    value = str(locator["value"])
    if kind == "php-function-declaration":
        pattern = rf"(?m)^[ \t]*function[ \t]+{re.escape(value)}[ \t]*\("
        return len(re.findall(pattern, text))
    if kind == "php-call-literal":
        call = str(locator["call"])
        pattern = (
            rf"\b{re.escape(call)}\s*\(\s*(['\"])"
            rf"{re.escape(value)}\1"
        )
        return len(re.findall(pattern, text))
    if kind == "php-interpolated-call-prefix":
        call = str(locator["call"])
        pattern = (
            rf"\b{re.escape(call)}\s*\(\s*\""
            rf"{re.escape(value)}\{{\$"
        )
        return len(re.findall(pattern, text))
    if kind == "php-array-key":
        pattern = rf"(['\"]){re.escape(value)}\1\s*=>"
        return len(re.findall(pattern, text))
    if kind == "json-pointer-equals":
        parsed = json.loads(text)
        return int(json_pointer(parsed, str(locator["pointer"])) == locator["value"])
    if kind == "js-named-export":
        return exported_names(text).count(value)
    if kind == "text-literal":
        return text.count(value)
    raise GenerationError(f"unknown locator kind: {kind}")


def locator_description(locator: dict[str, object]) -> str:
    kind = str(locator["kind"])
    if kind == "json-pointer-equals":
        return f"{kind}:{locator['pointer']}={locator['value']}"
    if "call" in locator:
        return f"{kind}:{locator['call']}:{locator['value']}"
    return f"{kind}:{locator['value']}"


def validate_locator(
    source: bytes, locator: dict[str, object], label: str
) -> None:
    expected = locator.get("expectedCount")
    if not isinstance(expected, int) or isinstance(expected, bool) or expected < 1:
        raise GenerationError(f"{label}: expectedCount must be a positive integer")
    actual = locator_count(source, locator)
    if actual != expected:
        raise GenerationError(
            f"{label}: locator count drifted; expected {expected}, found {actual}"
        )


def catalog_digest(document: dict[str, object]) -> str:
    material = canonical_bytes(
        {
            "schemaVersion": document["schemaVersion"],
            "generator": document["generator"],
            "catalog": document["catalog"],
        }
    )
    return sha256(material)


def omissions_digest(document: dict[str, object]) -> str:
    material = canonical_bytes(
        {
            "schemaVersion": document["schemaVersion"],
            "profileId": document["profileId"],
            "catalogRevision": document["catalogRevision"],
            "generator": document["generator"],
            "omissions": document["omissions"],
        }
    )
    return sha256(material)


def generate_profile(
    profile: dict[str, object],
    selection_digest: str,
    generator: dict[str, object],
    inventory_receipt_id: str,
    repositories: dict[str, Path],
) -> dict[str, bytes]:
    source_lock_path = ROOT / str(profile["sourceLockPath"])
    source_lock_bytes = source_lock_path.read_bytes()
    source_lock = json.loads(source_lock_bytes)
    profile_id = str(profile["profileId"])
    catalog_revision = str(profile["catalogRevision"])
    if source_lock["profileId"] != profile_id:
        raise GenerationError(f"{profile_id}: source lock profile mismatch")
    if source_lock["catalogRevision"] != catalog_revision:
        raise GenerationError(f"{profile_id}: catalog revision mismatch")

    exact_inputs: list[dict[str, object]] = []
    exact_by_id: dict[str, dict[str, object]] = {}
    definition_by_id: dict[str, dict[str, object]] = {}
    for raw_definition in profile["inputs"]:
        definition = dict(raw_definition)
        exact_input = input_from_lock(definition, source_lock)
        input_id = str(exact_input["inputId"])
        if input_id in exact_by_id:
            raise GenerationError(f"{profile_id}: duplicate input {input_id}")
        exact_inputs.append(exact_input)
        exact_by_id[input_id] = exact_input
        definition_by_id[input_id] = definition
        if exact_input["kind"] == "git-source":
            argument = str(definition["repositoryArgument"])
            if argument not in repositories:
                raise GenerationError(
                    f"{profile_id}: missing repository mapping {argument}"
                )
            verify_repository(repositories[argument], exact_input)

    blob_cache: dict[tuple[str, str], bytes] = {}

    def selected_blob(input_id: str, source_path: str) -> bytes:
        key = (input_id, safe_source_path(source_path))
        if key not in blob_cache:
            exact_input = exact_by_id.get(input_id)
            if exact_input is None or exact_input["kind"] != "git-source":
                raise GenerationError(
                    f"{profile_id}: locator uses non-Git input {input_id}"
                )
            definition = definition_by_id[input_id]
            argument = str(definition["repositoryArgument"])
            blob_cache[key] = read_git_blob(
                repositories[argument], exact_input, key[1]
            )
        return blob_cache[key]

    capabilities: list[dict[str, object]] = []
    seen_capabilities: set[str] = set()
    source_receipts = [str(value) for value in profile["sourceReceiptIds"]]
    receipt_ids = sorted({inventory_receipt_id, *source_receipts})
    for raw_capability in profile["capabilities"]:
        capability = dict(raw_capability)
        capability_id = str(capability["capabilityId"])
        if capability_id in seen_capabilities:
            raise GenerationError(f"{profile_id}: duplicate capability {capability_id}")
        seen_capabilities.add(capability_id)
        source_input_id = str(capability["sourceInputId"])
        source_path = safe_source_path(str(capability["sourcePath"]))
        locator = dict(capability["locator"])
        source = selected_blob(source_input_id, source_path)
        validate_locator(source, locator, capability_id)
        capabilities.append(
            {
                "capabilityId": capability_id,
                "providerIdentity": capability["providerIdentity"],
                "kind": capability["kind"],
                "classification": capability["classification"],
                "classificationMetadata": {},
                "evidenceStatus": "inventoried",
                "availableIn": [profile_id],
                "provenance": [
                    {
                        "sourceInputId": source_input_id,
                        "sourcePath": source_path,
                        "sourceDigest": sha256(source),
                        "locator": locator_description(locator),
                    }
                ],
                "evidence": {
                    "inventory": {"receiptId": inventory_receipt_id}
                },
                "receiptIds": receipt_ids,
                "administrativeResults": [
                    {
                        "result": "not-tested",
                        "reason": (
                            "SDK-013 inventories exact lexical presence; typed, "
                            "runtime, and production behavior remain unproven."
                        ),
                        "receiptId": inventory_receipt_id,
                    }
                ],
            }
        )

    omission_entries: list[dict[str, object]] = []
    seen_omissions: set[str] = set()
    for raw_omission in profile["omissions"]:
        omission = dict(raw_omission)
        omission_id = str(omission["omissionId"])
        if omission_id in seen_omissions:
            raise GenerationError(f"{profile_id}: duplicate omission {omission_id}")
        seen_omissions.add(omission_id)
        source_input_id = str(omission["sourceInputId"])
        source_path = safe_source_path(str(omission["sourcePath"]))
        locator = dict(omission["locator"])
        source = selected_blob(source_input_id, source_path)
        validate_locator(source, locator, omission_id)
        omission_entries.append(
            {
                "omissionId": omission_id,
                "kind": omission["kind"],
                "sourceInputId": source_input_id,
                "sourcePath": source_path,
                "sourceDigest": sha256(source),
                "locator": locator_description(locator),
                "reasonCode": omission["reasonCode"],
                "reason": omission["reason"],
                "receiptIds": receipt_ids,
            }
        )

    capabilities.sort(key=lambda item: str(item["capabilityId"]))
    omission_entries.sort(key=lambda item: str(item["omissionId"]))
    catalog_document: dict[str, object] = {
        "schemaVersion": 1,
        "catalogDigestAlgorithm": "sha256-canonical-json-v1",
        "catalogDigest": "",
        "generator": generator,
        "catalog": {
            "profileId": profile_id,
            "catalogRevision": catalog_revision,
            "upstreamInputs": exact_inputs,
            "capabilities": capabilities,
            "correctionAncestry": [],
        },
    }
    catalog_document["catalogDigest"] = catalog_digest(catalog_document)
    catalog_bytes = pretty_json(catalog_document)

    omission_document: dict[str, object] = {
        "schemaVersion": 1,
        "profileId": profile_id,
        "catalogRevision": catalog_revision,
        "omissionsDigestAlgorithm": "sha256-canonical-json-v1",
        "omissionsDigest": "",
        "generator": generator,
        "omissions": omission_entries,
    }
    omission_document["omissionsDigest"] = omissions_digest(omission_document)
    omission_bytes = pretty_json(omission_document)

    effective_inputs = [
        {
            "sourceInputId": input_id,
            "sourcePath": source_path,
            "sourceDigest": sha256(source),
        }
        for (input_id, source_path), source in sorted(blob_cache.items())
    ]
    fingerprint_material = {
        "generatorSourceDigest": generator["sourceDigest"],
        "selectionDigest": selection_digest,
        "profileSchemaDigest": sha256(PROFILE_SCHEMA.read_bytes()),
        "sourceLockDigest": sha256(source_lock_bytes),
        "upstreamInputs": exact_inputs,
        "effectiveInputs": effective_inputs,
    }
    report = {
        "schemaVersion": 1,
        "profileId": profile_id,
        "catalogRevision": catalog_revision,
        "generator": generator,
        "inventoryReceiptId": inventory_receipt_id,
        "inputFingerprintAlgorithm": "sha256-canonical-json-v1",
        "inputFingerprint": sha256(canonical_bytes(fingerprint_material)),
        "selection": {
            "path": "profiles/catalog-selection.json",
            "sha256": selection_digest,
        },
        "profileSchema": {
            "path": "schemas/profile.schema.json",
            "sha256": sha256(PROFILE_SCHEMA.read_bytes()),
        },
        "sourceLock": {
            "path": str(profile["sourceLockPath"]),
            "sha256": sha256(source_lock_bytes),
        },
        "effectiveInputs": effective_inputs,
        "outputs": {
            "catalog": {
                "path": "catalog.json",
                "sha256": sha256(catalog_bytes),
                "catalogDigest": catalog_document["catalogDigest"],
                "capabilityCount": len(capabilities),
            },
            "omissions": {
                "path": "omissions.json",
                "sha256": sha256(omission_bytes),
                "omissionsDigest": omission_document["omissionsDigest"],
                "omissionCount": len(omission_entries),
            },
        },
        "claims": {
            "catalogEvidenceStatus": "inventoried",
            "typedContracts": "not-tested",
            "runtimeCompatibility": "not-tested",
            "productionSupport": "not-tested",
            "upstreamCodeExecuted": False,
        },
    }
    return {
        "catalog.json": catalog_bytes,
        "omissions.json": omission_bytes,
        "generation-report.json": pretty_json(report),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--selection", type=Path, default=DEFAULT_SELECTION)
    parser.add_argument(
        "--repository",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help="Map a selection repositoryArgument to an exact local Git repository.",
    )
    parser.add_argument("--fetch-missing", action="store_true")
    parser.add_argument("--cache-root", type=Path)
    parser.add_argument("--profile", action="append", default=[])
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()

    selection_path = args.selection.resolve()
    selection_bytes = selection_path.read_bytes()
    selection = json.loads(selection_bytes)
    if selection.get("schemaVersion") != 1:
        raise GenerationError("selection schemaVersion must be 1")
    profiles = list(selection["profiles"])
    known_profile_ids = [str(profile["profileId"]) for profile in profiles]
    if len(known_profile_ids) != len(set(known_profile_ids)):
        raise GenerationError("selection contains duplicate profile IDs")
    requested = set(args.profile)
    unknown = sorted(requested - set(known_profile_ids))
    if unknown:
        raise GenerationError(f"unknown requested profile(s): {', '.join(unknown)}")
    selected_profiles = [
        profile
        for profile in profiles
        if not requested or profile["profileId"] in requested
    ]
    selected_profiles.sort(key=lambda profile: str(profile["profileId"]))

    repositories = parse_repository_arguments(args.repository)
    if args.fetch_missing:
        if args.cache_root is None:
            raise GenerationError("--fetch-missing requires --cache-root")
        cache_root = args.cache_root.resolve()
        for profile in selected_profiles:
            source_lock = json.loads((ROOT / profile["sourceLockPath"]).read_bytes())
            for definition in profile["inputs"]:
                if definition["kind"] != "git-source":
                    continue
                argument = str(definition["repositoryArgument"])
                exact_input = input_from_lock(definition, source_lock)
                if argument not in repositories:
                    repositories[argument] = cache_root / argument
                materialize_repository(
                    repositories[argument],
                    str(exact_input["repository"]),
                    str(exact_input["commit"]),
                )

    generator = {
        "identity": selection["generatorIdentity"],
        "version": selection["generatorVersion"],
        "sourceDigest": sha256(Path(__file__).read_bytes()),
        "toolchainIdentity": TOOLCHAIN_IDENTITY,
    }
    selection_digest = sha256(selection_bytes)
    output_root = args.output_root.resolve()
    if output_root.exists():
        raise GenerationError(f"output root already exists: {output_root}")
    output_root.parent.mkdir(parents=True, exist_ok=True)
    temporary_root: Path | None = Path(
        tempfile.mkdtemp(prefix=".wordpresshx-catalogs-", dir=output_root.parent)
    )
    try:
        summaries: list[dict[str, object]] = []
        for profile in selected_profiles:
            files = generate_profile(
                profile,
                selection_digest,
                generator,
                str(selection["inventoryReceiptId"]),
                repositories,
            )
            target = temporary_root / safe_target_path(str(profile["targetPath"]))
            target.mkdir(parents=True, exist_ok=False)
            for name, content in sorted(files.items()):
                (target / name).write_bytes(content)
            report = json.loads(files["generation-report.json"])
            summaries.append(
                {
                    "profileId": profile["profileId"],
                    "capabilityCount": report["outputs"]["catalog"][
                        "capabilityCount"
                    ],
                    "omissionCount": report["outputs"]["omissions"][
                        "omissionCount"
                    ],
                    "inputFingerprint": report["inputFingerprint"],
                }
            )
        os.replace(temporary_root, output_root)
        temporary_root = None
    finally:
        if temporary_root is not None and temporary_root.exists():
            shutil.rmtree(temporary_root)
    print(json.dumps({"outcome": "passed", "profiles": summaries}, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (GenerationError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise SystemExit(f"catalog generation failed: {error}") from error
