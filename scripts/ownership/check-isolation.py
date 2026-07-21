#!/usr/bin/env python3
"""Fail closed when the SDK-041 production closure gains ambient capabilities."""

from __future__ import annotations

import argparse
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
    masked = mask_comments_and_strings(source)
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
    dependency_dump: Path, source_root: Path, entry_root: Path
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
    discovered: set[Path] = set()
    for line in dependency_dump.read_text(encoding="utf-8").splitlines():
        candidate_text = line.strip().removesuffix(":")
        if not candidate_text.endswith(".hx"):
            continue
        candidate = Path(candidate_text)
        if not candidate.is_absolute():
            continue
        try:
            candidate.relative_to(source_root)
        except ValueError:
            continue
        if candidate.is_file():
            discovered.add(candidate.resolve())
        elif candidate.name != "import.hx":
            raise IsolationConfigurationError(
                f"compiler dependency points to missing source: {candidate}"
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

    modules = module_index(source_root)
    for source_path in sorted(discovered):
        masked = mask_comments_and_strings(source_path.read_text(encoding="utf-8"))
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

    print(
        "[ownership-isolation] Positive, alias, false-positive, and "
        f"{len(forbidden)} forbidden capability self-tests passed."
    )
    return len(forbidden)


def parse_arguments(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--entry-root", type=Path)
    parser.add_argument("--dependencies", type=Path)
    parsed = parser.parse_args(arguments)
    if parsed.self_test:
        if any(
            value is not None
            for value in (parsed.source_root, parsed.entry_root, parsed.dependencies)
        ):
            parser.error("--self-test cannot be combined with closure inputs")
        return parsed
    if any(
        value is None
        for value in (parsed.source_root, parsed.entry_root, parsed.dependencies)
    ):
        parser.error(
            "--source-root, --entry-root, and --dependencies are all required"
        )
    return parsed


def main(arguments: list[str]) -> int:
    parsed = parse_arguments(arguments)
    if parsed.self_test:
        self_test()
        return 0
    try:
        sources = compiler_sources(
            parsed.dependencies.resolve(),
            parsed.source_root.resolve(),
            parsed.entry_root.resolve(),
        )
    except IsolationConfigurationError as error:
        print(f"[ownership-isolation] ERROR: {error}", file=sys.stderr)
        return 3
    violations = scan_sources(sources, parsed.source_root.resolve())
    if violations:
        print("\n".join(violations), file=sys.stderr)
        return 2
    print(
        "[ownership-isolation] OK: scanned the compiler-authoritative "
        f"production closure ({len(sources)} Haxe sources)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
