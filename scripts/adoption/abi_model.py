#!/usr/bin/env python3
"""Parse the bounded ADR-015 provider into one precise ABI model."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path


JAVASCRIPT_STRICT_BINDING_FORBIDDEN = frozenset(
    {
        "arguments",
        "await",
        "break",
        "case",
        "catch",
        "class",
        "const",
        "continue",
        "debugger",
        "default",
        "delete",
        "do",
        "else",
        "enum",
        "eval",
        "export",
        "extends",
        "false",
        "finally",
        "for",
        "function",
        "if",
        "implements",
        "import",
        "in",
        "instanceof",
        "interface",
        "let",
        "new",
        "null",
        "package",
        "private",
        "protected",
        "public",
        "return",
        "static",
        "super",
        "switch",
        "this",
        "throw",
        "true",
        "try",
        "typeof",
        "var",
        "void",
        "while",
        "with",
        "yield",
    }
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class SourceSpan:
    input_id: str
    path: str
    start_byte: int
    end_byte: int
    text: str

    def json(self) -> dict[str, object]:
        return {
            "inputId": self.input_id,
            "path": self.path,
            "startByte": self.start_byte,
            "endByte": self.end_byte,
            "sha256": sha256(self.text.encode("utf-8")),
        }


@dataclass(frozen=True)
class JavascriptToken:
    text: str
    start: int
    end: int


@dataclass(frozen=True)
class AbiField:
    name: str
    requirement: str
    readonly: bool
    value_type: "AbiType"

    def json(self) -> dict[str, object]:
        return {
            "name": self.name,
            "haxeName": self.name,
            "requirement": self.requirement,
            "readonly": self.readonly,
            "type": self.value_type.json(),
        }


@dataclass(frozen=True)
class AbiType:
    kind: str
    target: str | None = None
    name: str | None = None
    value: "AbiType | None" = None
    fields: tuple[AbiField, ...] = ()

    def json(self) -> dict[str, object]:
        result: dict[str, object] = {"kind": self.kind}
        if self.target is not None:
            result["target"] = self.target
        if self.name is not None:
            result["name"] = self.name
        if self.value is not None:
            result["value"] = self.value.json()
        if self.fields:
            result["fields"] = [field.json() for field in self.fields]
        return result

    def signature(self) -> str:
        if self.kind == "native-nominal":
            return f"{self.target}:{self.name}"
        if self.kind == "structure":
            fields = ",".join(
                f"{field.name}{'?' if field.requirement == 'optional' else ''}:"
                f"{field.value_type.signature()}"
                for field in self.fields
            )
            return f"javascript:structure:{self.name}{{{fields}}}"
        if self.kind == "list" and self.value is not None:
            return f"list<{self.value.signature()}>"
        return self.kind

    def is_precise(self) -> bool:
        if self.kind == "unsupported":
            return False
        if self.value is not None and not self.value.is_precise():
            return False
        return all(field.value_type.is_precise() for field in self.fields)


@dataclass(frozen=True)
class Parameter:
    name: str
    requirement: str
    passing: str
    variadic: bool
    value_type: AbiType

    def json(self, position: int) -> dict[str, object]:
        return {
            "position": position,
            "nativeName": self.name,
            "haxeName": self.name,
            "requirement": self.requirement,
            "passing": self.passing,
            "type": self.value_type.json(),
        }

    def signature(self) -> str:
        prefix = "&" if self.passing == "reference" else ""
        spread = "..." if self.variadic else ""
        optional = "?" if self.requirement == "optional" else ""
        return f"{prefix}{spread}{self.name}{optional}:{self.value_type.signature()}"


@dataclass(frozen=True)
class Declaration:
    native_name: str
    target: str
    kind: str
    parameters: tuple[Parameter, ...]
    return_type: AbiType
    spans: tuple[SourceSpan, ...]

    @property
    def signature(self) -> str:
        local = self.native_name.rsplit(".", 1)[-1].rsplit("::", 1)[-1].rsplit("\\", 1)[-1]
        parameters = ",".join(parameter.signature() for parameter in self.parameters)
        return f"{self.kind} {local}({parameters}):{self.return_type.signature()}"

    @property
    def signature_sha256(self) -> str:
        return sha256(self.signature.encode("utf-8"))

    def same_abi(self, other: "Declaration") -> bool:
        return (
            self.target == other.target
            and self.kind == other.kind
            and self.parameters == other.parameters
            and self.return_type == other.return_type
        )


@dataclass(frozen=True)
class Candidate:
    declaration: Declaration
    runtime: Declaration
    omission_code: str | None
    omission_reason: str | None
    required_action: str | None

    @property
    def native_name(self) -> str:
        return self.declaration.native_name

    @property
    def precise(self) -> bool:
        return self.omission_code is None

    @property
    def spans(self) -> tuple[SourceSpan, ...]:
        return self.declaration.spans + self.runtime.spans


@dataclass(frozen=True)
class AbiModel:
    candidates: tuple[Candidate, ...]

    def by_name(self) -> dict[str, Candidate]:
        return {candidate.native_name: candidate for candidate in self.candidates}

    def admitted(self) -> tuple[Candidate, ...]:
        return tuple(candidate for candidate in self.candidates if candidate.precise)

    def omitted(self) -> tuple[Candidate, ...]:
        return tuple(candidate for candidate in self.candidates if not candidate.precise)


def source_span(
    input_id: str,
    relative_path: str,
    text: str,
    start: int,
    end: int,
) -> SourceSpan:
    selected = text[start:end]
    return SourceSpan(
        input_id=input_id,
        path=relative_path,
        start_byte=len(text[:start].encode("utf-8")),
        end_byte=len(text[:end].encode("utf-8")),
        text=selected,
    )


def split_parameters(source: str) -> list[str]:
    if source.strip() == "":
        return []
    result: list[str] = []
    start = 0
    depth = 0
    for index, character in enumerate(source):
        if character in "<({[":
            depth += 1
        elif character in ">)}]":
            depth -= 1
        elif character == "," and depth == 0:
            result.append(source[start:index].strip())
            start = index + 1
    result.append(source[start:].strip())
    return result


def parse_typescript_type(
    source: str,
    interfaces: dict[str, tuple[AbiType, SourceSpan]],
) -> tuple[AbiType, tuple[SourceSpan, ...]]:
    value = source.strip()
    primitive = {
        "string": AbiType("string"),
        "number": AbiType("javascript-number"),
        "boolean": AbiType("bool"),
        "object": AbiType("javascript-object"),
        "void": AbiType("void"),
    }.get(value)
    if primitive is not None:
        return primitive, ()
    interface = interfaces.get(value)
    if interface is not None:
        return interface[0], (interface[1],)
    return AbiType("unsupported", target="javascript", name=value), ()


def parse_typescript(path: Path, relative_path: str) -> list[Declaration]:
    text = path.read_text(encoding="utf-8")
    interfaces: dict[str, tuple[AbiType, SourceSpan]] = {}
    interface_pattern = re.compile(
        r"^export interface (?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\{(?P<body>.*?)^\}$",
        re.MULTILINE | re.DOTALL,
    )
    for match in interface_pattern.finditer(text):
        fields: list[AbiField] = []
        for raw in match.group("body").splitlines():
            line = raw.strip()
            if line == "":
                continue
            field = re.fullmatch(
                r"(?P<readonly>readonly\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?P<optional>\?)?:\s*(?P<type>[^;]+);",
                line,
            )
            if field is None:
                raise ValueError(f"unsupported TypeScript interface field: {line}")
            value_type, references = parse_typescript_type(field.group("type"), interfaces)
            if references:
                raise ValueError("nested fixture TypeScript interfaces are not supported")
            fields.append(
                AbiField(
                    name=field.group("name"),
                    requirement="optional" if field.group("optional") else "required",
                    readonly=field.group("readonly") is not None,
                    value_type=value_type,
                )
            )
        name = match.group("name")
        span = source_span("browser-types", relative_path, text, match.start(), match.end())
        interfaces[name] = (
            AbiType("structure", target="javascript", name=name, fields=tuple(fields)),
            span,
        )

    declarations: list[Declaration] = []
    function_pattern = re.compile(
        r"^export declare function (?P<name>[A-Za-z_][A-Za-z0-9_]*)"
        r"\((?P<parameters>[^\n]*)\):\s*(?P<return>[^;]+);$",
        re.MULTILINE,
    )
    for match in function_pattern.finditer(text):
        parameters: list[Parameter] = []
        references: list[SourceSpan] = []
        for raw in split_parameters(match.group("parameters")):
            parameter = re.fullmatch(
                r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?P<optional>\?)?:\s*(?P<type>.+)",
                raw,
            )
            if parameter is None:
                raise ValueError(f"unsupported TypeScript parameter: {raw}")
            value_type, selected = parse_typescript_type(parameter.group("type"), interfaces)
            references.extend(selected)
            parameters.append(
                Parameter(
                    name=parameter.group("name"),
                    requirement="optional" if parameter.group("optional") else "required",
                    passing="value",
                    variadic=False,
                    value_type=value_type,
                )
            )
        return_type, selected = parse_typescript_type(match.group("return"), interfaces)
        references.extend(selected)
        name = match.group("name")
        declarations.append(
            Declaration(
                native_name=f"@acme/calendar.{name}",
                target="javascript",
                kind="react-component" if name == "CalendarBadge" else "module-function",
                parameters=tuple(parameters),
                return_type=return_type,
                spans=(
                    source_span("browser-types", relative_path, text, match.start(), match.end()),
                    *tuple(dict.fromkeys(references)),
                ),
            )
        )

    value_pattern = re.compile(
        r"^export declare const (?P<name>[A-Za-z_][A-Za-z0-9_]*):\s*(?P<type>[^;]+);$",
        re.MULTILINE,
    )
    for match in value_pattern.finditer(text):
        value_type, references = parse_typescript_type(match.group("type"), interfaces)
        declarations.append(
            Declaration(
                native_name=f"@acme/calendar.{match.group('name')}",
                target="javascript",
                kind="exported-value",
                parameters=(),
                return_type=value_type,
                spans=(
                    source_span("browser-types", relative_path, text, match.start(), match.end()),
                    *references,
                ),
            )
        )
    return declarations


def javascript_tokens(text: str) -> tuple[JavascriptToken, ...]:
    """Lex significant JavaScript tokens without treating comments as code."""

    result: list[JavascriptToken] = []
    index = 0
    while index < len(text):
        character = text[index]
        if character.isspace():
            index += 1
            continue
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("unterminated JavaScript block comment")
            index = end + 2
            continue
        if character in ('"', "'", "`"):
            quote = character
            start = index
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                elif text[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            else:
                raise ValueError("unterminated JavaScript string or template literal")
            result.append(JavascriptToken(text[start:index], start, index))
            continue
        identifier = re.match(r"[A-Za-z_$][A-Za-z0-9_$]*", text[index:])
        if identifier is not None:
            start = index
            index += len(identifier.group(0))
            result.append(JavascriptToken(text[start:index], start, index))
            continue
        result.append(JavascriptToken(character, index, index + 1))
        index += 1
    return tuple(result)


def javascript_gap_is_whitespace(text: str, left: JavascriptToken, right: JavascriptToken) -> bool:
    return text[left.end : right.start].strip() == ""


def reject_host_active_javascript_export(name: str) -> None:
    if name == "then":
        raise ValueError(
            "host-active JavaScript export is not adoptable: @acme/calendar.then"
        )


def parse_javascript_runtime(path: Path, relative_path: str) -> list[Declaration]:
    text = path.read_text(encoding="utf-8")
    declarations: list[Declaration] = []
    tokens = javascript_tokens(text)
    depth = 0
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token.text == "{":
            depth += 1
            index += 1
            continue
        if token.text == "}":
            depth -= 1
            if depth < 0:
                raise ValueError("unbalanced JavaScript runtime braces")
            index += 1
            continue
        if depth != 0 or token.text != "export":
            index += 1
            continue
        if index + 1 >= len(tokens):
            raise ValueError("incomplete JavaScript runtime export")
        declaration = tokens[index + 1]
        if not javascript_gap_is_whitespace(text, token, declaration):
            raise ValueError("unsupported comments in JavaScript runtime export declaration")
        if declaration.text in {"async", "default"}:
            raise ValueError(
                "unsupported JavaScript runtime export modifier: " + declaration.text
            )
        if declaration.text == "function":
            if index + 2 >= len(tokens):
                raise ValueError("incomplete JavaScript runtime function export")
            name_token = tokens[index + 2]
            if name_token.text == "*":
                raise ValueError("unsupported JavaScript runtime generator export")
            if (
                re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", name_token.text) is None
                or not javascript_gap_is_whitespace(text, declaration, name_token)
            ):
                raise ValueError("unsupported JavaScript runtime function name")
            open_index = index + 3
            if open_index >= len(tokens) or tokens[open_index].text != "(":
                raise ValueError(
                    "unsupported JavaScript runtime function declaration: "
                    + name_token.text
                )
            parameter_end = open_index + 1
            while parameter_end < len(tokens) and tokens[parameter_end].text != ")":
                parameter_end += 1
            if parameter_end >= len(tokens):
                raise ValueError(
                    "unterminated JavaScript runtime parameters: " + name_token.text
                )
            body_index = parameter_end + 1
            if body_index >= len(tokens) or tokens[body_index].text != "{":
                raise ValueError(
                    "unsupported JavaScript runtime function body: " + name_token.text
                )
            raw_parameters = text[tokens[open_index].end : tokens[parameter_end].start]
            if not javascript_gap_is_whitespace(
                text, tokens[parameter_end], tokens[body_index]
            ):
                raise ValueError(
                    "unsupported comments after JavaScript runtime parameters: "
                    + name_token.text
                )
            parameters_list: list[Parameter] = []
            parameter_names: set[str] = set()
            for raw in split_parameters(raw_parameters):
                identifier = re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", raw)
                if identifier is None:
                    raise ValueError(
                        "unsupported JavaScript runtime parameter syntax: " + raw
                    )
                parameter_name = identifier.group(0)
                if parameter_name in JAVASCRIPT_STRICT_BINDING_FORBIDDEN:
                    raise ValueError(
                        "unsupported JavaScript runtime parameter identifier: "
                        + parameter_name
                    )
                if parameter_name in parameter_names:
                    raise ValueError(
                        "duplicate JavaScript runtime parameter identifier: "
                        + parameter_name
                    )
                parameter_names.add(parameter_name)
                parameters_list.append(
                    Parameter(
                        parameter_name,
                        "required",
                        "value",
                        False,
                        AbiType("runtime-unknown"),
                    )
                )
            name = name_token.text
            reject_host_active_javascript_export(name)
            declarations.append(
                Declaration(
                    native_name=f"@acme/calendar.{name}",
                    target="javascript",
                    kind="react-component" if name == "CalendarBadge" else "module-function",
                    parameters=tuple(parameters_list),
                    return_type=AbiType("runtime-unknown"),
                    spans=(
                        source_span(
                            "browser-runtime",
                            relative_path,
                            text,
                            token.start,
                            tokens[body_index].end,
                        ),
                    ),
                )
            )
            depth += 1
            index = body_index + 1
            continue
        if declaration.text == "const":
            if index + 3 >= len(tokens):
                raise ValueError("incomplete JavaScript runtime value export")
            name_token = tokens[index + 2]
            equals = tokens[index + 3]
            if (
                re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", name_token.text) is None
                or equals.text != "="
                or not javascript_gap_is_whitespace(text, declaration, name_token)
            ):
                raise ValueError("unsupported JavaScript runtime value export")
            reject_host_active_javascript_export(name_token.text)
            declarations.append(
                Declaration(
                    native_name=f"@acme/calendar.{name_token.text}",
                    target="javascript",
                    kind="exported-value",
                    parameters=(),
                    return_type=AbiType("runtime-unknown"),
                    spans=(
                        source_span(
                            "browser-runtime",
                            relative_path,
                            text,
                            token.start,
                            equals.end,
                        ),
                    ),
                )
            )
            index += 4
            continue
        raise ValueError(
            "unsupported JavaScript runtime export declaration: " + declaration.text
        )
    if depth != 0:
        raise ValueError("unbalanced JavaScript runtime braces")
    return declarations


PHP_DECLARATION = re.compile(
    r"(?P<doc>/\*\*.*?\*/\s*)?"
    r"^(?P<indent>\s*)(?:public\s+)?function\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\((?P<parameters>[^\n]*)\)"
    r"(?::\s*(?P<return>[^\s{]+))?\s*\{",
    re.MULTILINE | re.DOTALL,
)


def class_ranges(text: str) -> list[tuple[int, int, str]]:
    result: list[tuple[int, int, str]] = []
    for match in re.finditer(r"^final class ([A-Za-z_][A-Za-z0-9_]*)\s*\{", text, re.MULTILINE):
        depth = 0
        for index in range(match.end() - 1, len(text)):
            if text[index] == "{":
                depth += 1
            elif text[index] == "}":
                depth -= 1
                if depth == 0:
                    result.append((match.start(), index + 1, match.group(1)))
                    break
        else:
            raise ValueError(f"unclosed PHP class {match.group(1)}")
    return result


def php_type(source: str, namespace: str) -> AbiType:
    value = source.strip().lstrip("\\")
    primitive = {
        "string": AbiType("string"),
        "int": AbiType("php-int"),
        "bool": AbiType("bool"),
        "void": AbiType("void"),
        "mixed": AbiType("unsupported", target="php", name="mixed"),
        "array": AbiType("unsupported", target="php", name="array"),
    }.get(value)
    if primitive is not None:
        return primitive
    list_match = re.fullmatch(r"list<(.+)>", value)
    if list_match is not None:
        return AbiType("list", value=php_type(list_match.group(1), namespace))
    qualified = value if "\\" in value else f"{namespace}\\{value}"
    return AbiType("native-nominal", target="php", name=qualified)


def parse_php(path: Path, relative_path: str, input_id: str) -> list[Declaration]:
    text = path.read_text(encoding="utf-8")
    namespace_match = re.search(r"^namespace\s+([^;]+);$", text, re.MULTILINE)
    if namespace_match is None:
        raise ValueError(f"missing namespace in {relative_path}")
    namespace = namespace_match.group(1)
    ranges = class_ranges(text)
    declarations: list[Declaration] = []
    for match in PHP_DECLARATION.finditer(text):
        owning_class = next(
            (name for start, end, name in ranges if start < match.start("name") < end),
            None,
        )
        name = match.group("name")
        native_name = (
            f"{namespace}\\{owning_class}::{name}"
            if owning_class is not None
            else f"{namespace}\\{name}"
        )
        parameters: list[Parameter] = []
        for raw in split_parameters(match.group("parameters")):
            normalized = re.sub(r"^(?:public|protected|private|readonly)\s+", "", raw.strip())
            parameter = re.fullmatch(
                r"(?P<type>[\\A-Za-z_][\\A-Za-z0-9_]*)\s+"
                r"(?P<reference>&)?(?P<variadic>\.\.\.)?\$(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
                r"(?P<default>\s*=\s*.+)?",
                normalized,
            )
            if parameter is None:
                raise ValueError(f"unsupported PHP parameter: {raw}")
            parameters.append(
                Parameter(
                    name=parameter.group("name"),
                    requirement="optional" if parameter.group("default") else "required",
                    passing="reference" if parameter.group("reference") else "value",
                    variadic=parameter.group("variadic") is not None,
                    value_type=php_type(parameter.group("type"), namespace),
                )
            )
        doc = match.group("doc") or ""
        documented_return = re.search(r"@return\s+([^\s*]+)", doc)
        if name == "__construct" and owning_class is not None:
            return_type = AbiType(
                "native-nominal", target="php", name=f"{namespace}\\{owning_class}"
            )
            kind = "constructor"
        else:
            return_source = (
                documented_return.group(1)
                if documented_return is not None
                else (match.group("return") or "mixed")
            )
            return_type = php_type(return_source, namespace)
            kind = "instance-method" if owning_class is not None else "function"
        declarations.append(
            Declaration(
                native_name=native_name,
                target="php",
                kind=kind,
                parameters=tuple(parameters),
                return_type=return_type,
                spans=(source_span(input_id, relative_path, text, match.start(), match.end()),),
            )
        )
    return declarations


def merge_model(input_root: Path, logical_path: object) -> AbiModel:
    if not callable(logical_path):
        raise TypeError("logical_path must be callable")
    typescript = parse_typescript(
        input_root / "index.d.ts", logical_path(input_root / "index.d.ts")
    )
    javascript = parse_javascript_runtime(
        input_root / "index.js", logical_path(input_root / "index.js")
    )
    php_stubs = parse_php(
        input_root / "provider-stubs.php",
        logical_path(input_root / "provider-stubs.php"),
        "php-stubs",
    )
    php_runtime = parse_php(
        input_root / "plugin.php",
        logical_path(input_root / "plugin.php"),
        "plugin-source",
    )

    runtime_js = {declaration.native_name: declaration for declaration in javascript}
    runtime_php = {declaration.native_name: declaration for declaration in php_runtime}
    candidates: list[Candidate] = []

    for declaration in typescript:
        runtime = runtime_js.get(declaration.native_name)
        if runtime is None:
            raise ValueError(
                f"JavaScript runtime exports omit declared symbol: {declaration.native_name}"
            )
        if runtime.kind != declaration.kind or len(runtime.parameters) != len(declaration.parameters):
            raise ValueError(
                f"JavaScript runtime export shape conflicts with declaration: {declaration.native_name}"
            )
        if declaration.kind == "exported-value" or not declaration.return_type.is_precise():
            candidates.append(
                Candidate(
                    declaration,
                    runtime,
                    "dynamic-property",
                    "the declaration contains an unknown value shape that cannot become a precise Haxe surface",
                    "obtain-authoritative-signature",
                )
            )
        elif any(not parameter.value_type.is_precise() for parameter in declaration.parameters):
            candidates.append(
                Candidate(
                    declaration,
                    runtime,
                    "ambiguous-type",
                    "the declaration contains an unsupported parameter type",
                    "obtain-authoritative-signature",
                )
            )
        else:
            candidates.append(Candidate(declaration, runtime, None, None, None))

    for declaration in php_stubs:
        runtime = runtime_php.get(declaration.native_name)
        if runtime is None:
            raise ValueError(f"PHP runtime omits declared symbol: {declaration.native_name}")
        if not declaration.same_abi(runtime):
            candidates.append(
                Candidate(
                    declaration,
                    runtime,
                    "conflicting-authority",
                    "the authoritative stub and lower-precedence runtime declaration disagree",
                    "obtain-authoritative-signature",
                )
            )
        elif declaration.native_name.endswith("::__call"):
            candidates.append(
                Candidate(
                    declaration,
                    runtime,
                    "magic-member",
                    "the provider does not publish a finite method and return contract",
                    "omit",
                )
            )
        elif any(
            parameter.passing == "reference" or parameter.variadic
            for parameter in declaration.parameters
        ):
            candidates.append(
                Candidate(
                    declaration,
                    runtime,
                    "by-reference-variadic",
                    "the v1 ABI algebra does not prove variadic reference aliasing",
                    "supply-curated-precise-contract",
                )
            )
        elif not declaration.return_type.is_precise() or any(
            not parameter.value_type.is_precise() for parameter in declaration.parameters
        ):
            candidates.append(
                Candidate(
                    declaration,
                    runtime,
                    "ambiguous-type",
                    "the declaration contains an unsupported PHP type",
                    "obtain-authoritative-signature",
                )
            )
        else:
            candidates.append(Candidate(declaration, runtime, None, None, None))

    declared_names = {declaration.native_name for declaration in (*typescript, *php_stubs)}
    runtime_names = set(runtime_js) | set(runtime_php)
    unexpected = sorted(runtime_names - declared_names)
    if unexpected:
        raise ValueError("runtime source exports symbols absent from declarations: " + ", ".join(unexpected))
    return AbiModel(tuple(sorted(candidates, key=lambda candidate: candidate.native_name)))
