#!/usr/bin/env python3
"""Fail closed when the SDK-041 production closure gains ambient capabilities."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


ALLOWED_NODE_REFERENCES = {
    "js.node.Buffer",
    "js.node.Crypto",
    "js.node.Fs",
    "js.node.Path",
    "js.node.fs.Stats",
}
NODE_GLOBALS = Path("wordpresshx/cli/NodeGlobals.hx")
ALLOWED_NODE_REFERENCES_BY_SOURCE = {
    NODE_GLOBALS: {"js.node.Process"},
}
ALLOWED_SYNTAX_CALLS = {
    NODE_GLOBALS: {("code", '"process"')},
    Path("wordpresshx/cli/ownership/ArtifactOwner.hx"): {
        ("code", '"{0}.versions.node"'),
    },
    Path("wordpresshx/cli/ownership/OwnershipJson.hx"): {
        ("code", '"Object.create(null)"'),
        ("code", '"{0}.normalize(\'NFC\')"'),
        ("code", '"Number.isSafeInteger({0})"'),
        ("code", '"Object.prototype.hasOwnProperty.call({0}, {1})"'),
        ("code", '"String({0})"'),
    },
}
ALLOWED_JAVASCRIPT_IMPORTS_BY_SOURCE = {
    Path("wordpresshx/cli/ownership/ArtifactOwner.hx"): {
        "crypto",
        "fs",
        "path",
        "./OwnershipContract.js",
        "./OwnershipFailure.js",
        "./OwnershipJson.js",
        "../../../Reflect.js",
        "../../../genes/Register.js",
        "../../../haxe/Exception.js",
        "../../../haxe/ds/StringMap.js",
    },
    Path("wordpresshx/cli/ownership/OwnershipContract.hx"): {
        "./OwnershipFailure.js",
        "./OwnershipJson.js",
        "../../../EReg.js",
        "../../../Reflect.js",
        "../../../Std.js",
        "../../../StringTools.js",
        "../../../genes/Register.js",
        "../../../haxe/ds/StringMap.js",
    },
    Path("wordpresshx/cli/ownership/OwnershipFailure.hx"): {
        "../../../genes/Register.js",
        "../../../haxe/Exception.js",
    },
    Path("wordpresshx/cli/ownership/OwnershipJson.hx"): {
        "buffer",
        "./OwnershipFailure.js",
        "../../../HxOverrides.js",
        "../../../Reflect.js",
        "../../../genes/Register.js",
        "../../../haxe/crypto/Sha256.js",
        "../../../haxe/ds/StringMap.js",
        "../../../js/node/buffer/Buffer.js",
    },
    Path("probe/Main.hx"): {"../genes/Register.js"},
}
ARTIFACT_OWNER = Path("wordpresshx/cli/ownership/ArtifactOwner.hx")
OWNERSHIP_HARNESS = Path(
    "packages/cli/test/ownership/src/sdk041/fixture/Main.hx"
)

JAVASCRIPT_IMPORT = re.compile(
    r"(?m)^\s*import(?:[^\"'\n]*\bfrom\s+)?[\"'](?P<module>[^\"']+)[\"']"
)
JAVASCRIPT_IDENTIFIER = re.compile(r"(?<![A-Za-z0-9_$])([A-Za-z_$][A-Za-z0-9_$]*)")
JAVASCRIPT_FORBIDDEN_IDENTIFIERS = {
    "Bun": "alternate runtime capability",
    "Deno": "alternate runtime capability",
    "EventSource": "network capability",
    "Function": "dynamic code construction",
    "Image": "network capability",
    "Request": "network capability",
    "SharedWorker": "network capability",
    "WebSocket": "network capability",
    "WebTransport": "network capability",
    "Worker": "network capability",
    "XMLHttpRequest": "network capability",
    "document": "ambient browser capability",
    "eval": "dynamic code execution",
    "fetch": "network capability",
    "global": "ambient global capability",
    "globalThis": "ambient global capability",
    "importScripts": "network capability",
    "navigator": "ambient browser capability",
    "require": "runtime module loading",
    "self": "ambient browser capability",
    "sendBeacon": "network capability",
    "window": "ambient browser capability",
}

NODE_REFERENCE = re.compile(r"\bjs\.node(?:\.[A-Za-z_][A-Za-z0-9_]*)+\b")
IMPORT = re.compile(
    r"(?m)^\s*import\s+"
    r"(?P<path>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_*][A-Za-z0-9_*]*)*)"
    r"(?:\s+as\s+(?P<alias>[A-Za-z_][A-Za-z0-9_]*))?\s*;"
)
QUALIFIED_LOCAL = re.compile(
    r"\bwordpresshx(?:\.[A-Za-z_][A-Za-z0-9_]*)+\b"
)


class IsolationConfigurationError(ValueError):
    """The compiler closure cannot be established safely."""


@dataclass(frozen=True)
class ImportBinding:
    path: str
    alias: str


def mask_comments_and_strings(source: str) -> str:
    result = list(source)
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if current == "/" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "line-comment"
                continue
            if current == "/" and following == "*":
                result[index] = result[index + 1] = " "
                index += 2
                state = "block-comment"
                continue
            if current in {'"', "'"}:
                result[index] = " "
                quote = current
                state = "string"
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
        elif state == "block-comment":
            result[index] = " "
            if current == "*" and following == "/":
                result[index + 1] = " "
                index += 2
                state = "code"
                continue
        else:
            result[index] = " "
            if current == "\\" and following:
                result[index + 1] = " "
                index += 2
                continue
            if current == quote:
                state = "code"
        index += 1
    return "".join(result)


def mask_haxe_regex_literals(source: str, masked: str) -> str:
    """Mask inert Haxe ~/.../ regular expressions after strings/comments."""
    result = list(masked)
    index = 0
    while index + 1 < len(source):
        if result[index] != "~" or result[index + 1] != "/":
            index += 1
            continue
        result[index] = result[index + 1] = " "
        index += 2
        in_character_class = False
        while index < len(source):
            current = source[index]
            result[index] = "\n" if current == "\n" else " "
            if current == "\\" and index + 1 < len(source):
                index += 1
                result[index] = "\n" if source[index] == "\n" else " "
            elif current == "[":
                in_character_class = True
            elif current == "]":
                in_character_class = False
            elif current == "/" and not in_character_class:
                index += 1
                while index < len(source) and source[index].isalpha():
                    result[index] = " "
                    index += 1
                break
            index += 1
    return "".join(result)


def mask_javascript(source: str) -> tuple[str, list[int]]:
    """Mask inert JavaScript text and report unadmitted template literals."""
    result = list(source)
    template_offsets: list[int] = []
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if current == "/" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "line-comment"
                continue
            if current == "/" and following == "*":
                result[index] = result[index + 1] = " "
                index += 2
                state = "block-comment"
                continue
            if current in {'"', "'"}:
                result[index] = " "
                quote = current
                state = "string"
            elif current == "`":
                template_offsets.append(index)
                result[index] = " "
                state = "template"
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
        elif state == "block-comment":
            result[index] = "\n" if current == "\n" else " "
            if current == "*" and following == "/":
                result[index + 1] = " "
                index += 2
                state = "code"
                continue
        else:
            result[index] = "\n" if current == "\n" else " "
            if current == "\\" and following:
                result[index + 1] = "\n" if following == "\n" else " "
                index += 2
                continue
            if state == "string" and current == quote:
                state = "code"
            elif state == "template" and current == "`":
                state = "code"
        index += 1
    return "".join(result), template_offsets


def bindings(masked: str) -> list[ImportBinding]:
    result: list[ImportBinding] = []
    for match in IMPORT.finditer(masked):
        path = match.group("path")
        alias = match.group("alias") or path.rsplit(".", 1)[-1]
        result.append(ImportBinding(path, alias))
    return result


def aliases_for(imports: list[ImportBinding], path: str) -> set[str]:
    return {binding.alias for binding in imports if binding.path == path}


def member_pattern(owners: set[str], member: str) -> re.Pattern[str]:
    qualified = "|".join(
        sorted((re.escape(owner) for owner in owners), key=len, reverse=True)
    )
    return re.compile(rf"\b(?:{qualified})\.{re.escape(member)}\s*\(")


def member_access_pattern(owners: set[str], member: str) -> re.Pattern[str]:
    qualified = "|".join(
        sorted((re.escape(owner) for owner in owners), key=len, reverse=True)
    )
    return re.compile(rf"\b(?:{qualified})\.{re.escape(member)}\b")


def direct_call_pattern(names: set[str]) -> re.Pattern[str] | None:
    if not names:
        return None
    alternatives = "|".join(sorted(map(re.escape, names), key=len, reverse=True))
    return re.compile(rf"(?<![A-Za-z0-9_.])(?:{alternatives})\s*\(")


def direct_reference_pattern(names: set[str]) -> re.Pattern[str] | None:
    if not names:
        return None
    alternatives = "|".join(sorted(map(re.escape, names), key=len, reverse=True))
    return re.compile(rf"(?<![A-Za-z0-9_.])(?:{alternatives})\b")


def line_at(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def first_string_literal(source: str, open_parenthesis: int) -> str | None:
    index = open_parenthesis + 1
    while index < len(source) and source[index].isspace():
        index += 1
    if index >= len(source) or source[index] != '"':
        return None
    start = index
    index += 1
    while index < len(source):
        if source[index] == "\\":
            index += 2
            continue
        if source[index] == '"':
            return source[start : index + 1]
        index += 1
    return None


def scan_source(source_path: Path, source_root: Path) -> list[str]:
    source = source_path.read_text(encoding="utf-8")
    masked = mask_haxe_regex_literals(source, mask_comments_and_strings(source))
    relative = source_path.resolve().relative_to(source_root)
    source_imports = bindings(masked)
    violations: list[str] = []

    allowed_nodes = ALLOWED_NODE_REFERENCES | ALLOWED_NODE_REFERENCES_BY_SOURCE.get(
        relative, set()
    )
    for match in NODE_REFERENCE.finditer(masked):
        if match.group(0) not in allowed_nodes:
            violations.append(
                f"{source_path}:{line_at(masked, match.start())}: "
                f"Node capability is not allowlisted: {match.group(0)}"
            )

    fixed_patterns = (
        (
            "process execution",
            re.compile(r"\b(?:Sys\.command|sys\.io\.Process)\b"),
        ),
        (
            "native or module-loading metadata",
            re.compile(r"@:(?:jsRequire|native)\b"),
        ),
        (
            "local extern escape",
            re.compile(r"\bextern\s+(?:class|interface|abstract)\b"),
        ),
        (
            "browser capability",
            re.compile(r"\bjs\.(?:Browser|html(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\b"),
        ),
        (
            "ambient JavaScript capability",
            re.compile(r"\bjs\.(?:Lib|Node|lib\.Function)\b"),
        ),
        (
            "standard-library network capability",
            re.compile(r"\b(?:haxe\.Http|sys\.Http|sys\.net(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\b"),
        ),
        (
            "browser network API",
            re.compile(
                r"(?<![A-Za-z0-9_.])fetch\s*\("
                r"|\b(?:globalThis|XMLHttpRequest|WebSocket)\b"
            ),
        ),
        (
            "Node wildcard capability import",
            re.compile(r"\bjs\.node(?:\.[A-Za-z_][A-Za-z0-9_]*)*\.\*"),
        ),
        (
            "weakly typed escape",
            re.compile(r"\buntyped\b"),
        ),
    )
    for label, pattern in fixed_patterns:
        for match in pattern.finditer(masked):
            violations.append(
                f"{source_path}:{line_at(masked, match.start())}: "
                f"forbidden {label}: {match.group(0)}"
            )

    sys_owners = {"Sys"} | aliases_for(source_imports, "Sys")
    sys_commands = aliases_for(source_imports, "Sys.command")
    process_owners = {"js.Node"} | aliases_for(source_imports, "js.Node")
    process_calls = aliases_for(source_imports, "js.Node.process")
    require_owners = {
        "js.Lib",
        "js.Node",
    } | aliases_for(source_imports, "js.Lib") | aliases_for(
        source_imports, "js.Node"
    )
    require_calls = aliases_for(source_imports, "js.Lib.require") | aliases_for(
        source_imports, "js.Node.require"
    )

    imported_member_patterns = (
        ("process execution", member_pattern(sys_owners, "command")),
        ("Node process global", member_access_pattern(process_owners, "process")),
        ("raw Node require", member_pattern(require_owners, "require")),
    )
    for label, pattern in imported_member_patterns:
        for match in pattern.finditer(masked):
            violations.append(
                f"{source_path}:{line_at(masked, match.start())}: "
                f"forbidden {label}: {match.group(0).rstrip('(').rstrip()}"
            )

    for label, pattern in (
        ("process execution", direct_call_pattern(sys_commands)),
        ("Node process global", direct_reference_pattern(process_calls)),
        ("raw Node require", direct_call_pattern(require_calls)),
    ):
        if pattern is None:
            continue
        for match in pattern.finditer(masked):
            violations.append(
                f"{source_path}:{line_at(masked, match.start())}: "
                f"forbidden {label}: {match.group(0).rstrip('(').rstrip()}"
            )

    syntax_owners = {"js.Syntax"} | aliases_for(source_imports, "js.Syntax")
    allowed_syntax = ALLOWED_SYNTAX_CALLS.get(relative, set())
    syntax_owner_alternatives = "|".join(
        sorted(map(re.escape, syntax_owners), key=len, reverse=True)
    )
    syntax_member = re.compile(
        rf"\b(?:{syntax_owner_alternatives})\.(?P<member>[A-Za-z_][A-Za-z0-9_]*)\b"
    )
    for match in syntax_member.finditer(masked):
        if match.group("member") not in {"code", "plainCode"}:
            violations.append(
                f"{source_path}:{line_at(masked, match.start())}: "
                f"forbidden raw JavaScript syntax API: {match.group(0)}"
            )
    for binding in source_imports:
        if binding.path.startswith("js.Syntax.") and binding.path not in {
            "js.Syntax.code",
            "js.Syntax.plainCode",
        }:
            violations.append(
                f"{source_path}:1: forbidden raw JavaScript syntax import: "
                f"{binding.path}"
            )
    for method in ("code", "plainCode"):
        pattern = member_pattern(syntax_owners, method)
        for match in pattern.finditer(masked):
            literal = first_string_literal(source, match.end() - 1)
            if literal is None or (method, literal) not in allowed_syntax:
                rendered = literal if literal is not None else "non-literal template"
                violations.append(
                    f"{source_path}:{line_at(masked, match.start())}: "
                    f"forbidden raw JavaScript syntax escape: {method}({rendered})"
                )

    for method in ("code", "plainCode"):
        direct_names = aliases_for(source_imports, f"js.Syntax.{method}")
        pattern = direct_call_pattern(direct_names)
        if pattern is None:
            continue
        for match in pattern.finditer(masked):
            literal = first_string_literal(source, match.end() - 1)
            if literal is None or (method, literal) not in allowed_syntax:
                rendered = literal if literal is not None else "non-literal template"
                violations.append(
                    f"{source_path}:{line_at(masked, match.start())}: "
                    f"forbidden raw JavaScript syntax escape: {method}({rendered})"
                )

    node_globals_aliases = aliases_for(
        source_imports, "wordpresshx.cli.NodeGlobals"
    )
    node_globals_owners = {"wordpresshx.cli.NodeGlobals"} | node_globals_aliases
    node_globals_calls = list(
        member_pattern(node_globals_owners, "process").finditer(masked)
    )
    artifact_owner = Path("wordpresshx/cli/ownership/ArtifactOwner.hx")
    if relative == artifact_owner:
        exact_calls = list(
            re.finditer(r"\bNodeGlobals\.process\s*\(\s*\)", masked)
        )
        process_value_references = list(re.finditer(r"\bnodeProcess\b", masked))
        platform_references = list(
            re.finditer(r"\bnodeProcess\.platform\b", masked)
        )
        if (
            len(node_globals_calls) != 2
            or len(exact_calls) != 2
            or len(process_value_references) != 4
            or len(platform_references) != 2
        ):
            violations.append(
                f"{source_path}:1: audited Node process boundary changed; "
                "expected two direct process reads, one local binding, one "
                "version interpolation, and two platform reads"
            )
    else:
        for match in node_globals_calls:
            violations.append(
                f"{source_path}:{line_at(masked, match.start())}: "
                f"forbidden unaudited Node process boundary: {match.group(0)}"
            )

    return violations


def module_index(source_root: Path) -> dict[str, Path]:
    return {
        ".".join(path.relative_to(source_root).with_suffix("").parts): path.resolve()
        for path in source_root.rglob("*.hx")
        if path.is_file()
    }


def resolve_local_module(
    path: str, modules: dict[str, Path], *, unresolved_is_error: bool = True
) -> Path | None:
    if path.endswith(".*"):
        package = path[:-2]
        if package == "wordpresshx" or package.startswith("wordpresshx."):
            raise IsolationConfigurationError(
                f"local wildcard import cannot prove a closed dependency: {path}"
            )
        return None
    candidate = path
    while "." in candidate or candidate:
        if candidate in modules:
            return modules[candidate]
        if "." not in candidate:
            break
        candidate = candidate.rsplit(".", 1)[0]
    if unresolved_is_error and (
        path == "wordpresshx" or path.startswith("wordpresshx.")
    ):
        raise IsolationConfigurationError(f"unresolved local import: {path}")
    return None


def compiler_sources(
    dependency_dump: Path,
    source_root: Path,
    entry_root: Path,
    *,
    validate_local_references: bool = True,
    repository_root: Path | None = None,
    allowed_repository_sources: set[Path] | None = None,
) -> list[Path]:
    if not dependency_dump.is_file():
        raise IsolationConfigurationError(
            f"missing compiler dependency dump: {dependency_dump}"
        )
    if not source_root.is_dir():
        raise IsolationConfigurationError(f"missing source root: {source_root}")
    if not entry_root.is_dir():
        raise IsolationConfigurationError(f"missing entry root: {entry_root}")

    source_root = source_root.resolve()
    repository_root = repository_root.resolve() if repository_root else None
    allowed_repository_sources = {
        source.resolve() for source in (allowed_repository_sources or set())
    }
    discovered: set[Path] = set()
    for line in dependency_dump.read_text(encoding="utf-8").splitlines():
        candidate_text = line.strip().removesuffix(":")
        if not candidate_text.endswith(".hx"):
            continue
        candidate = Path(candidate_text)
        if not candidate.is_absolute():
            continue
        resolved_candidate = candidate.resolve()
        if resolved_candidate.name == "import.hx" and not resolved_candidate.exists():
            continue
        if repository_root is not None:
            try:
                resolved_candidate.relative_to(repository_root)
            except ValueError:
                pass
            else:
                try:
                    resolved_candidate.relative_to(source_root)
                except ValueError as error:
                    if resolved_candidate not in allowed_repository_sources:
                        raise IsolationConfigurationError(
                            "compiler closure contains repository source outside "
                            f"the production root: {resolved_candidate}"
                        ) from error
                    continue
        try:
            resolved_candidate.relative_to(source_root)
        except ValueError:
            continue
        if resolved_candidate.is_file():
            discovered.add(resolved_candidate)
        elif resolved_candidate.name != "import.hx":
            raise IsolationConfigurationError(
                f"compiler dependency points to missing source: {resolved_candidate}"
            )

    if not discovered:
        raise IsolationConfigurationError(
            "compiler dependency dump contains no repository production sources"
        )
    entries = {
        path.resolve() for path in entry_root.rglob("*.hx") if path.is_file()
    }
    omitted_entries = sorted(entries - discovered)
    if omitted_entries:
        raise IsolationConfigurationError(
            "compiler closure omits ownership entry sources: "
            + ", ".join(map(str, omitted_entries))
        )

    if validate_local_references:
        modules = module_index(source_root)
        for source_path in sorted(discovered):
            masked = mask_comments_and_strings(
                source_path.read_text(encoding="utf-8")
            )
            for binding in bindings(masked):
                local = resolve_local_module(binding.path, modules)
                if local is not None and local not in discovered:
                    raise IsolationConfigurationError(
                        f"compiler closure omits imported local source {local} "
                        f"from {source_path}"
                    )
            for match in QUALIFIED_LOCAL.finditer(masked):
                local = resolve_local_module(
                    match.group(0), modules, unresolved_is_error=False
                )
                if local is not None and local not in discovered:
                    raise IsolationConfigurationError(
                        f"compiler closure omits referenced local source {local} "
                        f"from {source_path}"
                    )
    return sorted(discovered)


def scan_sources(sources: list[Path], source_root: Path) -> list[str]:
    violations: list[str] = []
    for source in sources:
        violations.extend(scan_source(source, source_root.resolve()))
    return violations


def validate_receipt_closure(
    sources: list[Path], receipt_path: Path, repository_root: Path
) -> None:
    if not receipt_path.is_file():
        raise IsolationConfigurationError(
            f"missing ownership evidence receipt: {receipt_path}"
        )
    if not repository_root.is_dir():
        raise IsolationConfigurationError(
            f"missing repository root: {repository_root}"
        )
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        closure_names = receipt["productionClosureSubjects"]
        subjects = receipt["subject"]
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        raise IsolationConfigurationError(
            f"invalid ownership closure receipt: {error}"
        ) from error
    if (
        not isinstance(closure_names, list)
        or not closure_names
        or any(not isinstance(name, str) or not name for name in closure_names)
        or len(set(closure_names)) != len(closure_names)
        or not isinstance(subjects, dict)
    ):
        raise IsolationConfigurationError(
            "ownership closure receipt must name unique subject records"
        )

    repository_root = repository_root.resolve()
    recorded: set[Path] = set()
    for name in closure_names:
        subject = subjects.get(name)
        if not isinstance(subject, dict):
            raise IsolationConfigurationError(
                f"ownership closure subject is missing: {name}"
            )
        relative = subject.get("path")
        digest = subject.get("sha256")
        if (
            not isinstance(relative, str)
            or not relative
            or not isinstance(digest, str)
            or not re.fullmatch(r"[0-9a-f]{64}", digest)
        ):
            raise IsolationConfigurationError(
                f"ownership closure subject is malformed: {name}"
            )
        candidate = (repository_root / relative).resolve()
        try:
            candidate.relative_to(repository_root)
        except ValueError as error:
            raise IsolationConfigurationError(
                f"ownership closure subject escapes the repository: {relative}"
            ) from error
        if not candidate.is_file():
            raise IsolationConfigurationError(
                f"ownership closure subject is missing: {relative}"
            )
        actual_digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if actual_digest != digest:
            raise IsolationConfigurationError(
                f"ownership closure subject digest changed: {relative}"
            )
        recorded.add(candidate)

    if len(recorded) != len(closure_names):
        raise IsolationConfigurationError(
            "ownership closure receipt contains duplicate source paths"
        )

    discovered = {source.resolve() for source in sources}
    if recorded != discovered:
        omitted = sorted(map(str, discovered - recorded))
        stale = sorted(map(str, recorded - discovered))
        raise IsolationConfigurationError(
            "ownership receipt and compiler closure differ; "
            f"unrecorded={omitted}, stale={stale}"
        )


def generated_module_path(
    source: Path, source_root: Path, javascript_root: Path
) -> Path:
    relative = source.resolve().relative_to(source_root.resolve())
    return javascript_root.resolve() / relative.with_suffix(".js")


def javascript_imports(source: str) -> list[tuple[str, int]]:
    return [
        (match.group("module"), match.start())
        for match in JAVASCRIPT_IMPORT.finditer(source)
    ]


def scan_process_boundary(
    module: Path, relative_source: Path, masked: str
) -> list[str]:
    violations: list[str] = []
    process_references = list(re.finditer(r"(?<![A-Za-z0-9_$])process\b", masked))
    node_process_references = list(
        re.finditer(r"(?<![A-Za-z0-9_$])nodeProcess\b", masked)
    )
    if relative_source != ARTIFACT_OWNER:
        for match in process_references:
            violations.append(
                f"{module}:{line_at(masked, match.start())}: "
                "forbidden unaudited process reference"
            )
        for match in node_process_references:
            violations.append(
                f"{module}:{line_at(masked, match.start())}: "
                "forbidden unaudited process alias"
            )
        return violations

    allowed_process = list(
        re.finditer(
            r"(?<![A-Za-z0-9_$])process(?=\s*;)|"
            r"(?<![A-Za-z0-9_$])process(?=\.pid\b)",
            masked,
        )
    )
    allowed_node_process = list(
        re.finditer(
            r"(?<![A-Za-z0-9_$])nodeProcess(?=\s*=\s*process\s*;)|"
            r"(?<![A-Za-z0-9_$])nodeProcess(?=\.versions\.node\b)|"
            r"(?<![A-Za-z0-9_$])nodeProcess(?=\.platform\b)",
            masked,
        )
    )
    if (
        len(process_references) != 2
        or len(allowed_process) != 2
        or len(node_process_references) != 4
        or len(allowed_node_process) != 4
    ):
        violations.append(
            f"{module}:1: emitted audited process boundary changed; expected "
            "one process binding, one process.pid read, one Node version read, "
            "and two platform reads"
        )
    return violations


def scan_javascript_module(
    module: Path, relative_source: Path
) -> list[str]:
    source = module.read_text(encoding="utf-8")
    masked, template_offsets = mask_javascript(source)
    violations: list[str] = []

    allowed_modules = ALLOWED_JAVASCRIPT_IMPORTS_BY_SOURCE.get(
        relative_source, set()
    )
    for imported, offset in javascript_imports(source):
        if imported in allowed_modules:
            continue
        violations.append(
            f"{module}:{line_at(source, offset)}: "
            f"forbidden emitted external module import: {imported}"
        )

    for offset in template_offsets:
        violations.append(
            f"{module}:{line_at(source, offset)}: "
            "emitted template literal is outside the audited compiler profile"
        )

    for match in re.finditer(r"\bimport\s*\(", masked):
        violations.append(
            f"{module}:{line_at(masked, match.start())}: "
            "forbidden emitted dynamic module import"
        )

    for match in re.finditer(r"\\u(?:[0-9A-Fa-f]{4}|\{[0-9A-Fa-f]+\})", masked):
        violations.append(
            f"{module}:{line_at(masked, match.start())}: "
            "escaped JavaScript code token is outside the audited compiler profile"
        )

    for match in re.finditer(
        r"(?<![A-Za-z0-9_$])location\s*\.\s*(?:assign|href|replace)\b",
        masked,
    ):
        violations.append(
            f"{module}:{line_at(masked, match.start())}: "
            "forbidden emitted navigation network capability"
        )

    for match in JAVASCRIPT_IDENTIFIER.finditer(masked):
        identifier = match.group(1)
        label = JAVASCRIPT_FORBIDDEN_IDENTIFIERS.get(identifier)
        if label is None:
            continue
        violations.append(
            f"{module}:{line_at(masked, match.start())}: "
            f"forbidden emitted {label}: {identifier}"
        )

    for match in re.finditer(r"\.constructor\b", masked):
        violations.append(
            f"{module}:{line_at(masked, match.start())}: "
            "forbidden emitted constructor escape"
        )

    violations.extend(scan_process_boundary(module, relative_source, masked))
    return violations


def scan_emitted_modules(
    sources: list[Path], source_root: Path, javascript_root: Path
) -> tuple[list[str], int]:
    if not javascript_root.is_dir():
        raise IsolationConfigurationError(
            f"missing emitted JavaScript root: {javascript_root}"
        )
    violations: list[str] = []
    module_count = 0
    for source in sources:
        module = generated_module_path(source, source_root, javascript_root)
        if not module.is_file():
            continue
        module_count += 1
        relative = source.resolve().relative_to(source_root.resolve())
        violations.extend(scan_javascript_module(module, relative))
    if module_count == 0:
        raise IsolationConfigurationError(
            "compiler closure maps to no emitted repository JavaScript modules"
        )
    return violations, module_count


def self_test() -> int:
    forbidden = (
        "import js.node.ChildProcess;",
        "import js.node.child_process.ChildProcess as Runner;",
        "import js.node.Process;",
        "import js.node.dns.Resolver;",
        "import js.node.http.ClientRequest;",
        "import js.node.https.Agent;",
        "import js.node.net.Socket;",
        "import js.node.tls.TLSSocket;",
        'Sys.command("printf", []);',
        'import Sys as Host; Host.command("printf", []);',
        'final process = new sys.io.Process("printf", []);',
        'js.Lib.require("node:http");',
        'import js.Lib as Loader; Loader.require("node:http");',
        'import js.Lib.require as load; load("node:http");',
        'js.Node.require("node:http");',
        'import js.Node as Runtime; Runtime.process;',
        'import js.Node.process as runtime; runtime();',
        'js.Syntax.code("process.exit(1)");',
        'import js.Syntax; Syntax.code("process.exit(1)");',
        'import js.Syntax as Escape; Escape.plainCode("process.exit(1)");',
        'import js.Syntax.code as emit; emit("process.exit(1)");',
        'import js.Syntax; Syntax.field({}, "process");',
        'import js.Syntax.field as field; field({}, "process");',
        'js.Lib.dynamicImport("node:child_process");',
        'js.Node.global;',
        'final request = new haxe.Http("https://example.invalid");',
        'import sys.net.Socket;',
        'import js.lib.Function;',
        'import wordpresshx.cli.NodeGlobals; NodeGlobals.process().kill(1);',
        '@:jsRequire("node:http") extern class HttpModule {}',
        '@:native("process") extern class NativeProcess {}',
        'extern class LocalEscape {}',
        'fetch("https://example.invalid");',
        'globalThis.fetch("https://example.invalid");',
        'new XMLHttpRequest();',
        'new WebSocket("wss://example.invalid");',
        'import js.Browser;',
        'import js.html.XMLHttpRequest;',
        'import js.node.*;',
        'untyped process.exit(91);',
    )
    with tempfile.TemporaryDirectory(prefix="wordpresshx-isolation-self-test-") as raw:
        root = Path(raw).resolve()
        source_root = root / "src"
        entry_root = source_root / "wordpresshx" / "cli" / "ownership"
        entry_root.mkdir(parents=True)
        probe = entry_root / "Probe.hx"
        safe = "\n".join(
            (
                "import js.node.Buffer;",
                "import js.node.Crypto;",
                "import js.node.Fs;",
                "import js.node.Path;",
                "import js.node.fs.Stats;",
                "class Probe {",
                "  static function require():Void {}",
                "  static function check(store:Store):Void {",
                "    final regex = ~/js.node.ChildProcess/;",
                "    require();",
                "    store.fetch();",
                "  }",
                "}",
            )
        )
        probe.write_text(safe, encoding="utf-8")
        if scan_sources([probe], source_root):
            raise RuntimeError("safe capability self-test was rejected")

        for source in forbidden:
            probe.write_text(source + "\n", encoding="utf-8")
            if not scan_sources([probe], source_root):
                raise RuntimeError(f"forbidden capability self-test passed: {source}")
        probe.unlink()

        root_source = entry_root / "Root.hx"
        hidden = source_root / "wordpresshx" / "cli" / "Hidden.hx"
        root_source.write_text(
            "package wordpresshx.cli.ownership;\n"
            "import wordpresshx.cli.Hidden;\n"
            "class Root { static final hidden = Hidden.value; }\n",
            encoding="utf-8",
        )
        hidden.parent.mkdir(parents=True, exist_ok=True)
        hidden.write_text(
            "package wordpresshx.cli;\n"
            "import js.node.child_process.ChildProcess as Runner;\n"
            "class Hidden { public static final value = 1; }\n",
            encoding="utf-8",
        )
        dependency_dump = root / "dependencies.dump"
        dependency_dump.write_text(f"{root_source}:\n", encoding="utf-8")
        try:
            compiler_sources(dependency_dump, source_root, entry_root)
        except IsolationConfigurationError:
            pass
        else:
            raise RuntimeError("omitted local wrapper self-test passed")

        dependency_dump.write_text(
            f"{root_source}:\n\t{hidden}\n{hidden}:\n", encoding="utf-8"
        )
        closure = compiler_sources(dependency_dump, source_root, entry_root)
        if not scan_sources(closure, source_root):
            raise RuntimeError("forbidden transitive wrapper self-test passed")

        outside = root / "test" / "evil" / "Helper.hx"
        outside.parent.mkdir(parents=True)
        outside.write_text("package evil; class Helper {}\n", encoding="utf-8")
        dependency_dump.write_text(
            f"{root_source}:\n\t{outside}\n{outside}:\n", encoding="utf-8"
        )
        try:
            compiler_sources(
                dependency_dump,
                source_root,
                entry_root,
                repository_root=root,
            )
        except IsolationConfigurationError:
            pass
        else:
            raise RuntimeError("out-of-production-root dependency self-test passed")

        javascript_root = root / "runtime"
        safe_source = source_root / "wordpresshx" / "cli" / "Safe.hx"
        safe_source.write_text("class Safe {}\n", encoding="utf-8")
        safe_module = generated_module_path(safe_source, source_root, javascript_root)
        safe_module.parent.mkdir(parents=True)
        safe_module.write_text(
            "// process.exit(91); require('child_process')\n"
            'const note = "fetch globalThis process.exit require";\n'
            "export class Safe { check(store) { store.lookup(); this.requireState(); } }\n",
            encoding="utf-8",
        )
        emitted_violations, emitted_count = scan_emitted_modules(
            [safe_source], source_root, javascript_root
        )
        if emitted_violations or emitted_count != 1:
            raise RuntimeError("safe emitted capability self-test was rejected")

        emitted_forbidden = (
            'import * as Child from "child_process"\nexport const value = Child;\n',
            'import {escape} from "./evil.js"\nescape();\n',
            'const child = require("child_process");\n',
            'proc\\u0065ss.exit(91);\n',
            'const child = requ\\u0069re("child_process");\n',
            'async function load() { return import("node:http"); }\n',
            'process.exit(91);\n',
            'globalThis.fetch("https://example.invalid");\n',
            'new XMLHttpRequest();\n',
            'new WebSocket("wss://example.invalid");\n',
            'window.fetch("https://example.invalid");\n',
            'navigator.sendBeacon("https://example.invalid", "owned");\n',
            'new EventSource("https://example.invalid");\n',
            'new Worker("https://example.invalid/worker.js");\n',
            'new WebTransport("https://example.invalid");\n',
            'location.href = "https://example.invalid";\n',
            'Function("return process")();\n',
            'const escape = value.constructor("return process");\n',
            'const value = `${process.exit(91)}`;\n',
        )
        for emitted in emitted_forbidden:
            safe_module.write_text(emitted, encoding="utf-8")
            emitted_violations, _ = scan_emitted_modules(
                [safe_source], source_root, javascript_root
            )
            if not emitted_violations:
                raise RuntimeError(
                    f"forbidden emitted capability self-test passed: {emitted}"
                )

    print(
        "[ownership-isolation] Positive, alias, false-positive, "
        f"{len(forbidden)} source, and {len(emitted_forbidden)} emitted "
        "capability self-tests passed."
    )
    return len(forbidden)


def parse_arguments(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--entry-root", type=Path)
    parser.add_argument("--dependencies", type=Path)
    parser.add_argument("--javascript-root", type=Path)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--emitted-only", action="store_true")
    parsed = parser.parse_args(arguments)
    if parsed.self_test:
        if any(
            value is not None
            for value in (
                parsed.source_root,
                parsed.entry_root,
                parsed.dependencies,
                parsed.javascript_root,
                parsed.receipt,
                parsed.repository_root,
            )
        ) or parsed.emitted_only:
            parser.error("--self-test cannot be combined with closure inputs")
        return parsed
    if any(
        value is None
        for value in (
            parsed.source_root,
            parsed.entry_root,
            parsed.dependencies,
            parsed.javascript_root,
        )
    ):
        parser.error(
            "--source-root, --entry-root, --dependencies, and --javascript-root "
            "are all required"
        )
    if not parsed.emitted_only and (
        parsed.receipt is None or parsed.repository_root is None
    ):
        parser.error(
            "--receipt and --repository-root are required for the production gate"
        )
    return parsed


def main(arguments: list[str]) -> int:
    parsed = parse_arguments(arguments)
    if parsed.self_test:
        self_test()
        return 0
    try:
        repository_root = (
            parsed.repository_root.resolve() if not parsed.emitted_only else None
        )
        sources = compiler_sources(
            parsed.dependencies.resolve(),
            parsed.source_root.resolve(),
            parsed.entry_root.resolve(),
            validate_local_references=not parsed.emitted_only,
            repository_root=repository_root,
            allowed_repository_sources=(
                {repository_root / OWNERSHIP_HARNESS}
                if repository_root is not None
                else None
            ),
        )
    except IsolationConfigurationError as error:
        print(f"[ownership-isolation] ERROR: {error}", file=sys.stderr)
        return 3
    if not parsed.emitted_only:
        try:
            validate_receipt_closure(
                sources,
                parsed.receipt.resolve(),
                parsed.repository_root.resolve(),
            )
        except IsolationConfigurationError as error:
            print(f"[ownership-isolation] ERROR: {error}", file=sys.stderr)
            return 3
    violations = [] if parsed.emitted_only else scan_sources(
        sources, parsed.source_root.resolve()
    )
    try:
        emitted_violations, module_count = scan_emitted_modules(
            sources,
            parsed.source_root.resolve(),
            parsed.javascript_root.resolve(),
        )
    except IsolationConfigurationError as error:
        print(f"[ownership-isolation] ERROR: {error}", file=sys.stderr)
        return 3
    violations.extend(emitted_violations)
    if violations:
        print("\n".join(violations), file=sys.stderr)
        return 2
    print(
        "[ownership-isolation] OK: scanned the compiler-authoritative "
        f"production closure ({len(sources)} Haxe sources, "
        f"{module_count} emitted JavaScript modules)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
