#!/usr/bin/env python3
"""Generate the bounded ADR-015 contract from static provider declarations."""

from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import os
import re
import zipfile
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GENERATOR_PATH = Path(__file__).resolve()
FIXTURE = ROOT / "fixtures" / "adoption-contract"
INPUT_ROOT = Path(
    os.environ.get("WORDPRESSHX_ADOPTION_INPUT_ROOT", str(FIXTURE / "inputs"))
).resolve()


def logical_path(path: Path) -> str:
    return (
        Path("fixtures")
        / "adoption-contract"
        / "inputs"
        / path.relative_to(INPUT_ROOT)
    ).as_posix()


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def pretty(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    ).encode("utf-8")


def canonical_file(value: object) -> bytes:
    return canonical(value) + b"\n"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def self_digest(document: dict[str, object], field: str) -> str:
    payload = copy.deepcopy(document)
    payload.pop(field, None)
    return sha256(canonical(payload))


@dataclass(frozen=True)
class SourceSpan:
    input_id: str
    path: str
    start_byte: int
    end_byte: int
    text: str

    def json(self) -> dict[str, object]:
        encoded = self.text.encode("utf-8")
        return {
            "inputId": self.input_id,
            "path": self.path,
            "startByte": self.start_byte,
            "endByte": self.end_byte,
            "sha256": sha256(encoded),
        }


@dataclass(frozen=True)
class Candidate:
    native_name: str
    target: str
    kind: str
    signature: str
    spans: tuple[SourceSpan, ...]

    @property
    def signature_sha256(self) -> str:
        return sha256(self.signature.encode("utf-8"))


def span_for_match(input_id: str, relative: str, text: str, match: re.Match[str]) -> SourceSpan:
    start = len(text[: match.start()].encode("utf-8"))
    matched = match.group(0)
    end = start + len(matched.encode("utf-8"))
    return SourceSpan(input_id, relative, start, end, matched)


def parse_typescript(path: Path) -> list[Candidate]:
    text = path.read_text(encoding="utf-8")
    relative = logical_path(path)
    candidates: list[Candidate] = []
    function_pattern = re.compile(
        r"^export declare function ([A-Za-z_][A-Za-z0-9_]*)"
        r"\(([^\n]*)\): ([^;]+);$",
        re.MULTILINE,
    )
    for match in function_pattern.finditer(text):
        name = match.group(1)
        kind = "react-component" if name == "CalendarBadge" else "module-function"
        signature = f"function {name}({match.group(2)}): {match.group(3)}"
        candidates.append(
            Candidate(
                f"@acme/calendar.{name}",
                "javascript",
                kind,
                signature,
                (span_for_match("browser-types", relative, text, match),),
            )
        )
    value_pattern = re.compile(
        r"^export declare const ([A-Za-z_][A-Za-z0-9_]*): ([^;]+);$",
        re.MULTILINE,
    )
    for match in value_pattern.finditer(text):
        candidates.append(
            Candidate(
                f"@acme/calendar.{match.group(1)}",
                "javascript",
                "exported-value",
                f"const {match.group(1)}: {match.group(2)}",
                (span_for_match("browser-types", relative, text, match),),
            )
        )
    return candidates


PHP_DECLARATION = re.compile(
    r"^(?P<indent>\s*)(?:public\s+)?function\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\((?P<parameters>[^\n]*)\)"
    r"(?::\s*(?P<return>[^\s{]+))?\s*\{",
    re.MULTILINE,
)


def class_ranges(text: str) -> list[tuple[int, int, str]]:
    result: list[tuple[int, int, str]] = []
    for match in re.finditer(r"^final class ([A-Za-z_][A-Za-z0-9_]*)\s*\{", text, re.MULTILINE):
        depth = 0
        end = -1
        for index in range(match.end() - 1, len(text)):
            if text[index] == "{":
                depth += 1
            elif text[index] == "}":
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        if end < 0:
            raise ValueError(f"unclosed PHP class {match.group(1)}")
        result.append((match.start(), end, match.group(1)))
    return result


def parse_php(path: Path, input_id: str) -> list[Candidate]:
    text = path.read_text(encoding="utf-8")
    relative = logical_path(path)
    namespace_match = re.search(r"^namespace\s+([^;]+);$", text, re.MULTILINE)
    if namespace_match is None:
        raise ValueError(f"missing namespace in {relative}")
    namespace = namespace_match.group(1)
    ranges = class_ranges(text)
    candidates: list[Candidate] = []
    for match in PHP_DECLARATION.finditer(text):
        owning_class = next(
            (name for start, end, name in ranges if start < match.start() < end),
            None,
        )
        name = match.group("name")
        native_name = (
            f"{namespace}\\{owning_class}::{name}"
            if owning_class is not None
            else f"{namespace}\\{name}"
        )
        kind = "constructor" if name == "__construct" else (
            "instance-method" if owning_class is not None else "function"
        )
        return_type = match.group("return") or "mixed"
        signature = f"function {name}({match.group('parameters')}): {return_type}"
        candidates.append(
            Candidate(
                native_name,
                "php",
                kind,
                signature,
                (span_for_match(input_id, relative, text, match),),
            )
        )
    return candidates


def merge_candidates() -> dict[str, Candidate]:
    authoritative = parse_typescript(INPUT_ROOT / "index.d.ts") + parse_php(
        INPUT_ROOT / "provider-stubs.php", "php-stubs"
    )
    runtime = parse_php(INPUT_ROOT / "plugin.php", "plugin-source")
    runtime_by_name = {candidate.native_name: candidate for candidate in runtime}
    result: dict[str, Candidate] = {}
    for candidate in authoritative:
        runtime_candidate = runtime_by_name.get(candidate.native_name)
        spans = candidate.spans
        if runtime_candidate is not None:
            spans += runtime_candidate.spans
        result[candidate.native_name] = Candidate(
            candidate.native_name,
            candidate.target,
            candidate.kind,
            candidate.signature,
            spans,
        )
    unexpected_runtime = sorted(set(runtime_by_name) - set(result))
    if unexpected_runtime:
        raise ValueError(
            "runtime source exports symbols absent from declarations: "
            + ", ".join(unexpected_runtime)
        )
    return result


def deterministic_provider_archive() -> bytes:
    entries = [
        "fixtures/adoption-contract/inputs/index.js",
        "fixtures/adoption-contract/inputs/package-metadata.json",
        "fixtures/adoption-contract/inputs/plugin.php",
    ]
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in entries:
            info = zipfile.ZipInfo(relative, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (INPUT_ROOT / Path(relative).name).read_bytes())
    return output.getvalue()


def source_tree_digest(paths: list[Path]) -> str:
    material = b"".join(
        f"{file_sha256(path)}  {logical_path(path)}\n".encode("utf-8")
        for path in sorted(paths)
    )
    return sha256(material)


def input_record(
    input_id: str,
    target: str,
    kind: str,
    authority: str,
    precedence: int,
    path: Path,
) -> dict[str, object]:
    return {
        "id": input_id,
        "target": target,
        "kind": kind,
        "authorityClass": authority,
        "precedence": precedence,
        "path": logical_path(path),
        "sha256": file_sha256(path),
        "executed": False,
    }


def php_facade(version: str, plugin_sha256: str) -> bytes:
    source = f'''<?php

declare(strict_types=1);

namespace WordPressHx\\Adoption\\AcmeCalendar;

final class ProviderUnavailable extends \\RuntimeException {{}}

final class Facade
{{
    private const VERSION = '{version}';
    private const MAIN_FILE_SHA256 = '{plugin_sha256}';

    /** @return list<string> */
    public static function listEventTitles(string $pluginFile, int $limit): array
    {{
        self::loadExactProvider($pluginFile);
        try {{
            $events = \\Acme\\Calendar\\list_events($limit);
        }} catch (\\Throwable $failure) {{
            throw new \\RuntimeException('provider-call-failed', 0, $failure);
        }}
        $titles = [];
        foreach ($events as $event) {{
            if (!$event instanceof \\Acme\\Calendar\\Event) {{
                throw new \\UnexpectedValueException('provider-returned-wrong-event');
            }}
            $titles[] = $event->title();
        }}
        return $titles;
    }}

    private static function loadExactProvider(string $pluginFile): void
    {{
        if (!is_file($pluginFile)) {{
            throw new ProviderUnavailable('provider-absent');
        }}
        $digest = hash_file('sha256', $pluginFile);
        if (!is_string($digest) || !hash_equals(self::MAIN_FILE_SHA256, $digest)) {{
            throw new ProviderUnavailable('wrong-provider-artifact');
        }}
        $bytes = file_get_contents($pluginFile);
        if (!is_string($bytes)
            || preg_match('/^Version:\\s*([^\\s]+)$/m', $bytes, $match) !== 1
            || !isset($match[1])
            || $match[1] !== self::VERSION) {{
            throw new ProviderUnavailable('wrong-provider-version');
        }}
        require_once $pluginFile;
        if (!function_exists('Acme\\\\Calendar\\\\list_events')
            || !class_exists('Acme\\\\Calendar\\\\Event', false)) {{
            throw new ProviderUnavailable('required-provider-symbol-missing');
        }}
    }}
}}
'''
    return source.encode("utf-8")


def browser_facade(version: str, module_sha256: str, package_sha256: str) -> bytes:
    source = f'''import {{ createHash }} from "node:crypto";
import {{ readFile }} from "node:fs/promises";
import {{ pathToFileURL }} from "node:url";
import path from "node:path";

const expected = Object.freeze({{
  version: "{version}",
  moduleSha256: "{module_sha256}",
  packageSha256: "{package_sha256}",
}});

function digest(bytes) {{
  return createHash("sha256").update(bytes).digest("hex");
}}

export async function loadExactProvider(packageRoot, generation) {{
  const packagePath = path.join(packageRoot, "package-metadata.json");
  const modulePath = path.join(packageRoot, "index.js");
  let packageBytes;
  let moduleBytes;
  try {{
    [packageBytes, moduleBytes] = await Promise.all([readFile(packagePath), readFile(modulePath)]);
  }} catch (_) {{
    throw new Error("provider-absent");
  }}
  if (digest(packageBytes) !== expected.packageSha256 || digest(moduleBytes) !== expected.moduleSha256) {{
    throw new Error("wrong-provider-artifact");
  }}
  const metadata = JSON.parse(packageBytes.toString("utf8"));
  if (metadata.version !== expected.version) {{
    throw new Error("wrong-provider-version");
  }}
  const moduleUrl = `${{pathToFileURL(modulePath).href}}?generation=${{encodeURIComponent(generation)}}`;
  const provider = await import(moduleUrl);
  if (typeof provider.CalendarBadge !== "function" || typeof provider.formatCalendarLabel !== "function") {{
    throw new Error("required-provider-symbol-missing");
  }}
  return Object.freeze({{
    formatLabel(count) {{
      return provider.formatCalendarLabel(count);
    }},
    renderBadge(props) {{
      return provider.CalendarBadge(props);
    }},
  }});
}}
'''
    return source.encode("utf-8")


def ownership_manifest(
    generated_files: dict[str, bytes],
    contract: dict[str, object],
    generator_sha256: str,
) -> dict[str, object]:
    source_path = "scripts/adoption/generate-fixture.py"
    source_bytes = GENERATOR_PATH.read_bytes()
    source_span = {
        "path": source_path,
        "sourceSha256": sha256(source_bytes),
        "symbol": "generate_documents",
        "start": {"line": 1, "column": 1, "offset": 0},
        "end": {
            "line": len(source_bytes.splitlines()),
            "column": 1,
            "offset": len(source_bytes),
        },
    }
    file_records = []
    for relative, content in sorted(generated_files.items()):
        file_records.append(
            {
                "contentSha256": sha256(content),
                "kind": "adoption.generated",
                "ownerNodeId": "adoption/acme-calendar",
                "path": relative,
                "projectionIds": ["adoption/acme-calendar/bundle"],
                "rootId": "generated",
                "sizeBytes": len(content),
                "sourceNodeIds": ["adoption/acme-calendar/provider-inputs"],
                "sourceSpans": [source_span],
                "validatorIds": ["adoption.bundle"],
            }
        )
    generation_material = [
        {
            "contentSha256": record["contentSha256"],
            "path": record["path"],
            "sizeBytes": record["sizeBytes"],
        }
        for record in file_records
    ]
    manifest: dict[str, object] = {
        "schema": "wordpress-hx.generated-files.v1",
        "canonicalization": "wordpress-hx.canonical-json.v1",
        "transactionProtocol": "wordpress-hx.ownership-transaction.v1",
        "manifestDigestAlgorithm": "sha256-canonical-json-without-manifestDigest-v1",
        "locations": {
            "journalPath": "generated/.wphx-transactions/journal.json",
            "lockPath": "generated/.wphx-transactions/lock",
            "manifestPath": "generated/_GeneratedFiles.json",
            "transactionRoot": "generated/.wphx-transactions",
        },
        "generator": {
            "cliVersion": "0.0.0-fixture",
            "generatorId": "wordpress-hx.adoption.generator",
            "generatorSourceSha256": generator_sha256,
            "sdkVersion": "0.0.0-fixture",
            "toolchainSha256": file_sha256(ROOT / "manifests" / "toolchain.lock.json"),
        },
        "inputs": {
            "emissionResultSha256s": [
                sha256(b"".join(generated_files[path] for path in sorted(generated_files)))
            ],
            "generationSha256": sha256(canonical(generation_material)),
            "profile": {
                "catalogRevision": str(
                    dict(contract["profile"])["catalogRevision"]
                ),
                "catalogSha256": str(dict(contract["profile"])["catalogSha256"]),
                "profileId": str(dict(contract["profile"])["id"]),
            },
            "semanticPlanSha256": str(contract["contractDigest"]),
            "sourceTreeSha256": str(dict(contract["provider"])["sourceSha256"]),
        },
        "outputRoots": [
            {
                "ownershipMode": "exact-file-manifest-coexists-with-unowned",
                "path": "generated",
                "rootId": "generated",
            }
        ],
        "validators": [
            {
                "configSha256": file_sha256(
                    ROOT / "schemas" / "adoption-bundle.schema.json"
                ),
                "outcome": "passed",
                "scope": "complete-staged-tree",
                "tool": "ADR-015 adoption bundle validator",
                "toolSha256": file_sha256(
                    ROOT / "scripts" / "adoption" / "validate-architecture.py"
                ),
                "validatorId": "adoption.bundle",
                "version": "v1",
            }
        ],
        "files": file_records,
    }
    manifest["manifestDigest"] = self_digest(manifest, "manifestDigest")
    return manifest


def bundle_manifest(
    documents: dict[str, dict[str, object]],
    generated_files: dict[str, bytes],
    ownership: dict[str, object],
    provider_archive: bytes,
) -> dict[str, object]:
    contract = documents["contract"]
    bundle: dict[str, object] = {
        "schema": "wordpress-hx.adoption-bundle.v1",
        "schemaVersion": 1,
        "bundleId": "acme-calendar.wp70.bundle",
        "bundleVersion": "1.0.0",
        "provider": {
            "id": "acme-calendar",
            "version": dict(contract["provider"])["version"],
            "artifactSha256": sha256(provider_archive),
        },
        "records": {
            "contract": {
                "path": "generated/adoption/acme-calendar/contract.json",
                "sha256": sha256(generated_files["generated/adoption/acme-calendar/contract.json"]),
            },
            "capability": {
                "path": "generated/adoption/acme-calendar/capability.json",
                "sha256": sha256(generated_files["generated/adoption/acme-calendar/capability.json"]),
            },
            "review": {
                "path": "generated/adoption/acme-calendar/review.json",
                "sha256": sha256(generated_files["generated/adoption/acme-calendar/review.json"]),
            },
            "ownership": {
                "path": "generated/_GeneratedFiles.json",
                "sha256": sha256(canonical_file(ownership)),
                "manifestDigest": ownership["manifestDigest"],
            },
        },
        "generatedFiles": [
            {
                "path": relative,
                "sha256": sha256(content),
                "sizeBytes": len(content),
            }
            for relative, content in sorted(generated_files.items())
        ],
    }
    bundle["bundleDigest"] = self_digest(bundle, "bundleDigest")
    return bundle


def source_evidence(candidate: Candidate, input_id: str) -> dict[str, object]:
    span = next(span for span in candidate.spans if span.input_id == input_id)
    return {
        "signatureSha256": candidate.signature_sha256,
        "span": span.json(),
    }


def type_ref(kind: str, **extra: object) -> dict[str, object]:
    return {"kind": kind, **extra}


def provider_version() -> str:
    metadata = json.loads((INPUT_ROOT / "package-metadata.json").read_text(encoding="utf-8"))
    if not isinstance(metadata, dict) or not isinstance(metadata.get("version"), str):
        raise ValueError("package metadata omits its version")
    version = metadata["version"]
    plugin = (INPUT_ROOT / "plugin.php").read_text(encoding="utf-8")
    match = re.search(r"^Version:\s*([^\s]+)$", plugin, re.MULTILINE)
    if match is None or match.group(1) != version:
        raise ValueError("PHP and JavaScript provider versions differ")
    if re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", version) is None:
        raise ValueError("fixture provider version is not exact semver")
    return version


def parameter(
    position: int,
    native_name: str,
    haxe_name: str,
    value_type: dict[str, object],
) -> dict[str, object]:
    return {
        "position": position,
        "nativeName": native_name,
        "haxeName": haxe_name,
        "requirement": "required",
        "passing": "value",
        "type": value_type,
    }


def binding(
    candidate: Candidate,
    binding_id: str,
    haxe_path: str,
    capability_id: str,
    parameters: list[dict[str, object]],
    return_type: dict[str, object],
) -> dict[str, object]:
    return {
        "id": binding_id,
        "target": candidate.target,
        "kind": candidate.kind,
        "nativeName": candidate.native_name,
        "haxePath": haxe_path,
        "sourceInputId": "browser-types" if candidate.target == "javascript" else "php-stubs",
        "sourceEvidence": source_evidence(
            candidate,
            "browser-types" if candidate.target == "javascript" else "php-stubs",
        ),
        "capabilityId": capability_id,
        "parameters": parameters,
        "returnType": return_type,
        "status": "admitted-precise",
    }


def generate_documents() -> dict[str, dict[str, object]]:
    candidates = merge_candidates()
    expected_signatures = {
        "@acme/calendar.CalendarBadge": "function CalendarBadge(props: CalendarBadgeProps): object",
        "@acme/calendar.CalendarRegistry": "const CalendarRegistry: Record<string, unknown>",
        "@acme/calendar.formatCalendarLabel": "function formatCalendarLabel(count: number): string",
        "Acme\\Calendar\\Event::__call": "function __call(string $name, array $arguments): mixed",
        "Acme\\Calendar\\Event::__construct": "function __construct(string $eventTitle): mixed",
        "Acme\\Calendar\\Event::title": "function title(): string",
        "Acme\\Calendar\\conditional_helper": "function conditional_helper(string $value): string",
        "Acme\\Calendar\\list_events": "function list_events(int $limit): array",
        "Acme\\Calendar\\mutate_all": "function mutate_all(Event &...$events): void",
    }
    if set(candidates) != set(expected_signatures):
        raise ValueError("provider candidate inventory changed without an explicit disposition")
    for name, expected in expected_signatures.items():
        if candidates[name].signature != expected:
            raise ValueError(f"provider signature changed without an exact type decision: {name}")
    version = provider_version()
    provider_archive = deterministic_provider_archive()
    artifact_sha = sha256(provider_archive)
    inputs = [
        input_record(
            "browser-runtime",
            "javascript",
            "provider-runtime-source",
            "package-or-source-signature",
            3,
            INPUT_ROOT / "index.js",
        ),
        input_record(
            "browser-types",
            "javascript",
            "typescript-declaration",
            "authoritative-signature",
            1,
            INPUT_ROOT / "index.d.ts",
        ),
        input_record(
            "package-metadata",
            "provider",
            "package-metadata",
            "package-or-source-signature",
            3,
            INPUT_ROOT / "package-metadata.json",
        ),
        input_record(
            "php-stubs",
            "php",
            "provider-stub",
            "authoritative-signature",
            1,
            INPUT_ROOT / "provider-stubs.php",
        ),
        input_record(
            "plugin-source",
            "wordpress",
            "provider-runtime-source",
            "package-or-source-signature",
            3,
            INPUT_ROOT / "plugin.php",
        ),
    ]
    generator = {
        "id": "wordpress-hx-adoption-generator",
        "version": "0.0.0-fixture",
        "sha256": file_sha256(Path(__file__)),
    }
    contract: dict[str, object] = {
        "schema": "wordpress-hx.adoption-contract.v1",
        "schemaVersion": 1,
        "contractId": "acme-calendar.wp70",
        "contractVersion": "1.0.0",
        "profile": {
            "id": "wp70-release",
            "catalogRevision": "wp70-release/catalog-v1",
            "catalogSha256": "d86d1d887f1a3d8894831e3ec092201ee5caba57e88f4eeff59816d22dd9aa6e",
        },
        "provider": {
            "id": "acme-calendar",
            "kind": "wordpress-plugin",
            "version": version,
            "artifactUrl": f"https://example.test/acme-calendar/acme-calendar.{version}.zip",
            "artifactSha256": artifact_sha,
            "artifactFormat": "deterministic-fixture-zip-v1",
            "sourceUrl": f"https://example.test/acme-calendar/source/{version}",
            "sourceRevision": f"fixture-acme-calendar-{version}",
            "sourceSha256": source_tree_digest(
                [
                    INPUT_ROOT / "index.d.ts",
                    INPUT_ROOT / "index.js",
                    INPUT_ROOT / "package-metadata.json",
                    INPUT_ROOT / "plugin.php",
                    INPUT_ROOT / "provider-stubs.php",
                ]
            ),
            "runtimeOwner": "native-provider",
            "implementationOwnership": "external-not-transferred",
        },
        "generation": {
            "mode": "static-no-execution",
            "mergePolicy": "one-complete-binding-from-highest-nonconflicting-authority",
            "generator": generator,
            "inputs": inputs,
            "reflection": None,
        },
        "capabilitySet": {
            "id": "acme-calendar.capabilities",
            "version": "1.0.0",
        },
        "bindings": [],
        "ownership": {
            "providerRuntime": "external-native-provider",
            "contract": "cli-owned-generated",
            "applicationLogic": "haxe-authored",
            "compilerRecognition": "generic-contract-only-no-provider-name-branches",
            "regeneration": "private-stage-deterministic-diff-before-publication",
            "removal": "manifest-owned-contract-and-facade-only-provider-untouched",
            "modifiedGeneratedFile": "fail-closed-no-overwrite-or-delete",
        },
    }
    admitted = [
        binding(
            candidates["@acme/calendar.CalendarBadge"],
            "js.calendar.badge",
            "acme.calendar.browser.CalendarBadge",
            "calendar.badge.browser",
            [
                parameter(
                    0,
                    "props",
                    "props",
                    type_ref(
                        "native-nominal",
                        target="javascript",
                        name="CalendarBadgeProps",
                    ),
                )
            ],
            type_ref("javascript-object"),
        ),
        binding(
            candidates["@acme/calendar.formatCalendarLabel"],
            "js.calendar.format-label",
            "acme.calendar.browser.CalendarLabels.format",
            "calendar.badge.browser",
            [parameter(0, "count", "count", type_ref("javascript-number"))],
            type_ref("string"),
        ),
        binding(
            candidates["Acme\\Calendar\\Event::__construct"],
            "php.calendar.event.construct",
            "acme.calendar.server.Event.create",
            "calendar.read.php",
            [parameter(0, "eventTitle", "eventTitle", type_ref("string"))],
            type_ref(
                "native-nominal",
                target="php",
                name="Acme\\Calendar\\Event",
            ),
        ),
        binding(
            candidates["Acme\\Calendar\\Event::title"],
            "php.calendar.event.title",
            "acme.calendar.server.Event.title",
            "calendar.read.php",
            [],
            type_ref("string"),
        ),
        binding(
            candidates["Acme\\Calendar\\list_events"],
            "php.calendar.list-events",
            "acme.calendar.server.CalendarEvents.list",
            "calendar.read.php",
            [parameter(0, "limit", "limit", type_ref("php-int"))],
            type_ref(
                "list",
                value=type_ref(
                    "native-nominal",
                    target="php",
                    name="Acme\\Calendar\\Event",
                ),
            ),
        ),
    ]
    contract["bindings"] = admitted
    contract["contractDigest"] = self_digest(contract, "contractDigest")
    contract_digest = str(contract["contractDigest"])

    capability: dict[str, object] = {
        "schema": "wordpress-hx.adoption-capability.v1",
        "schemaVersion": 1,
        "capabilitySetId": "acme-calendar.capabilities",
        "capabilitySetVersion": "1.0.0",
        "contract": {
            "id": "acme-calendar.wp70",
            "version": "1.0.0",
            "sha256": contract_digest,
        },
        "profile": contract["profile"],
        "provider": {
            "id": "acme-calendar",
            "version": version,
            "artifactSha256": artifact_sha,
        },
        "authority": {
            "tokenScope": "declared-per-capability",
            "tokenSerializable": False,
            "tokenCacheable": False,
            "staleTokenAuthority": False,
            "observationOwner": "target-runtime-adapter",
            "callerSuppliedFactsAllowed": False,
            "lifecycleIdentity": "generative-runtime-nonce",
            "scopeTypes": ["browser-module", "php-process", "php-request"],
            "sameNominalScopeInstanceReusable": False,
            "tokenBoundFacts": [
                "artifact-sha256",
                "bundle-digest",
                "capability-id",
                "lifecycle-kind",
                "observed-bindings",
                "provider-id",
                "provider-version",
                "runtime-nonce",
            ],
            "bundleVerification": "required-before-observation",
            "absenceBehavior": "typed-unavailable-with-core-fallback",
            "providerTrustAdmission": "separate-sdk-117-requirement",
        },
        "capabilities": [
            {
                "id": "calendar.badge.browser",
                "target": "javascript",
                "scope": "browser-module",
                "optional": True,
                "probe": {
                    "kind": "javascript-exports",
                    "requiredBindings": [
                        "js.calendar.badge",
                        "js.calendar.format-label",
                    ],
                    "requiredNativeSymbols": [
                        "@acme/calendar.CalendarBadge",
                        "@acme/calendar.formatCalendarLabel",
                    ],
                    "versionMatch": "exact",
                    "artifactMatch": "exact-sha256",
                    "conditionalFailure": "unavailable-not-partially-authorized",
                },
            },
            {
                "id": "calendar.read.php",
                "target": "php",
                "scope": "request",
                "optional": False,
                "probe": {
                    "kind": "wordpress-plugin-and-symbols",
                    "requiredBindings": [
                        "php.calendar.event.construct",
                        "php.calendar.event.title",
                        "php.calendar.list-events",
                    ],
                    "requiredNativeSymbols": [
                        "Acme\\Calendar\\Event::__construct",
                        "Acme\\Calendar\\Event::title",
                        "Acme\\Calendar\\list_events",
                    ],
                    "versionMatch": "exact",
                    "artifactMatch": "exact-sha256",
                    "conditionalFailure": "unavailable-not-partially-authorized",
                },
            },
        ],
    }
    capability["capabilitySetDigest"] = self_digest(
        capability, "capabilitySetDigest"
    )

    omission_specs = [
        (
            "@acme/calendar.CalendarRegistry",
            "dynamic-property",
            "the declaration exposes unknown values that cannot become a precise Haxe surface",
            "obtain-authoritative-signature",
        ),
        (
            "Acme\\Calendar\\Event::__call",
            "magic-member",
            "the provider does not publish a finite method and return contract",
            "omit",
        ),
        (
            "Acme\\Calendar\\conditional_helper",
            "conflicting-authority",
            "the authoritative stub and runtime-source signatures disagree",
            "obtain-authoritative-signature",
        ),
        (
            "Acme\\Calendar\\mutate_all",
            "by-reference-variadic",
            "the v1 ABI algebra does not prove variadic reference aliasing",
            "supply-curated-precise-contract",
        ),
    ]
    omissions: list[dict[str, object]] = []
    for native_name, code, reason, action in omission_specs:
        candidate = candidates[native_name]
        omissions.append(
            {
                "nativeName": native_name,
                "target": candidate.target,
                "kind": candidate.kind,
                "code": code,
                "reason": reason,
                "sourceInputIds": sorted(
                    {span.input_id for span in candidate.spans}
                ),
                "sourceSpans": [span.json() for span in candidate.spans],
                "signatureSha256": candidate.signature_sha256,
                "requiredAction": action,
            }
        )
    review: dict[str, object] = {
        "schema": "wordpress-hx.adoption-review.v1",
        "schemaVersion": 1,
        "reportId": "acme-calendar.review.1",
        "contract": {
            "id": "acme-calendar.wp70",
            "version": "1.0.0",
            "sha256": contract_digest,
        },
        "provider": {
            "id": "acme-calendar",
            "version": version,
            "artifactSha256": artifact_sha,
        },
        "generator": generator,
        "summary": {
            "discovered": len(candidates),
            "included": len(admitted),
            "omitted": len(omissions),
            "conflicts": 1,
        },
        "includedBindings": [str(value["id"]) for value in admitted],
        "omissions": omissions,
        "conflicts": [
            {
                "nativeName": "Acme\\Calendar\\conditional_helper",
                "strongerInputId": "php-stubs",
                "weakerInputId": "plugin-source",
                "strongerSourceSpan": next(
                    span.json()
                    for span in candidates[
                        "Acme\\Calendar\\conditional_helper"
                    ].spans
                    if span.input_id == "php-stubs"
                ),
                "weakerSourceSpan": next(
                    span.json()
                    for span in candidates[
                        "Acme\\Calendar\\conditional_helper"
                    ].spans
                    if span.input_id == "plugin-source"
                ),
                "resolution": "omit-binding-and-report",
            }
        ],
        "reflection": {
            "requested": False,
            "executed": False,
            "isolationReceiptSha256": None,
        },
        "claims": {
            "evidenceStage": "contract-generated",
            "reviewRequired": True,
            "providerRuntimeTested": False,
            "providerTrustAdmitted": False,
            "productionSupported": False,
            "implementationOwnershipTransferred": False,
        },
    }
    review["reportDigest"] = self_digest(review, "reportDigest")
    return {"contract": contract, "capability": capability, "review": review}


def write_documents(output: Path) -> None:
    documents = generate_documents()
    output.mkdir(parents=True, exist_ok=True)
    names = {
        "contract": "acme-calendar.contract.json",
        "capability": "acme-calendar.capability.json",
        "review": "acme-calendar.review.json",
    }
    for key, name in names.items():
        (output / name).write_bytes(pretty(documents[key]))
    version = provider_version()
    provider_archive = deterministic_provider_archive()
    (output / f"acme-calendar.{version}.zip").write_bytes(provider_archive)
    generated_files = {
        "generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs": browser_facade(
            version,
            file_sha256(INPUT_ROOT / "index.js"),
            file_sha256(INPUT_ROOT / "package-metadata.json"),
        ),
        "generated/adoption/acme-calendar/capability.json": pretty(
            documents["capability"]
        ),
        "generated/adoption/acme-calendar/contract.json": pretty(
            documents["contract"]
        ),
        "generated/adoption/acme-calendar/php/acme-calendar-facade.php": php_facade(
            version, file_sha256(INPUT_ROOT / "plugin.php")
        ),
        "generated/adoption/acme-calendar/review.json": pretty(documents["review"]),
    }
    ownership = ownership_manifest(
        generated_files,
        documents["contract"],
        file_sha256(GENERATOR_PATH),
    )
    bundle = bundle_manifest(documents, generated_files, ownership, provider_archive)
    for relative, content in generated_files.items():
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    manifest_target = output / "generated" / "_GeneratedFiles.json"
    manifest_target.parent.mkdir(parents=True, exist_ok=True)
    manifest_target.write_bytes(canonical_file(ownership))
    (output / "acme-calendar.bundle.json").write_bytes(pretty(bundle))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    write_documents(arguments.output)


if __name__ == "__main__":
    main()
