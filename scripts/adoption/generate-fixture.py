#!/usr/bin/env python3
"""Generate the bounded ADR-015 fixture from one parsed provider ABI model."""

from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import os
import zipfile
from pathlib import Path

from abi_model import AbiModel, AbiType, Candidate, merge_model


ROOT = Path(__file__).resolve().parents[2]
GENERATOR_PATH = Path(__file__).resolve()
FIXTURE = ROOT / "fixtures" / "adoption-contract"
INPUT_ROOT = Path(
    os.environ.get("WORDPRESSHX_ADOPTION_INPUT_ROOT", str(FIXTURE / "inputs"))
).resolve()
CONTENT_ROOT = "generated/adoption/acme-calendar"


BINDING_POLICY: dict[str, tuple[str, str, str]] = {
    "@acme/calendar.CalendarBadge": (
        "js.calendar.badge",
        "acme.calendar.browser.CalendarBadge",
        "calendar.badge.browser",
    ),
    "@acme/calendar.formatCalendarLabel": (
        "js.calendar.format-label",
        "acme.calendar.browser.CalendarLabels.format",
        "calendar.badge.browser",
    ),
    "Acme\\Calendar\\Event::__construct": (
        "php.calendar.event.construct",
        "acme.calendar.server.Event.create",
        "calendar.read.php",
    ),
    "Acme\\Calendar\\Event::title": (
        "php.calendar.event.title",
        "acme.calendar.server.Event.title",
        "calendar.read.php",
    ),
    "Acme\\Calendar\\list_events": (
        "php.calendar.list-events",
        "acme.calendar.server.CalendarEvents.list",
        "calendar.read.php",
    ),
}


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


def canonical_file(value: object) -> bytes:
    return canonical(value) + b"\n"


def pretty(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    ).encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def self_digest(document: dict[str, object], field: str) -> str:
    payload = copy.deepcopy(document)
    payload.pop(field, None)
    return sha256(canonical(payload))


def deterministic_provider_archive() -> bytes:
    entries = ["index.js", "package-metadata.json", "plugin.php"]
    output = io.BytesIO()
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for name in entries:
            logical = f"fixtures/adoption-contract/inputs/{name}"
            info = zipfile.ZipInfo(logical, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (INPUT_ROOT / name).read_bytes())
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


def provider_version() -> str:
    metadata = json.loads(
        (INPUT_ROOT / "package-metadata.json").read_text(encoding="utf-8")
    )
    if not isinstance(metadata, dict) or not isinstance(metadata.get("version"), str):
        raise ValueError("package metadata omits its version")
    version = metadata["version"]
    plugin = (INPUT_ROOT / "plugin.php").read_text(encoding="utf-8")
    marker = f"Version: {version}"
    if plugin.count(marker) != 1:
        raise ValueError("PHP and JavaScript provider versions differ")
    return version


def require_policy(model: AbiModel) -> None:
    precise = {candidate.native_name for candidate in model.admitted()}
    missing = sorted(set(BINDING_POLICY) - precise)
    if missing:
        name = missing[0]
        candidate = model.by_name().get(name)
        if candidate is not None and candidate.omission_code == "conflicting-authority":
            raise ValueError(
                f"lower-precedence runtime declaration conflicts with required binding: {name}"
            )
        raise ValueError(f"required provider binding is not precise: {name}")
    unowned = sorted(precise - set(BINDING_POLICY))
    if unowned:
        raise ValueError(
            "precise provider candidate needs a semantic binding policy: "
            + ", ".join(unowned)
        )


def require_semantic_facade_policy(model: AbiModel) -> None:
    """Fail if the provider ABI no longer fits the fixture's authored PHP adapter."""

    list_events = admitted_candidate(model, "Acme\\Calendar\\list_events")
    title = admitted_candidate(model, "Acme\\Calendar\\Event::title")
    parameters = list_events.declaration.parameters
    returned = list_events.declaration.return_type
    if (
        len(parameters) != 1
        or parameters[0].value_type.kind != "php-int"
        or returned.kind != "list"
        or returned.value is None
        or returned.value.kind != "native-nominal"
        or returned.value.name != "Acme\\Calendar\\Event"
        or title.declaration.parameters
        or title.declaration.return_type.kind != "string"
    ):
        raise ValueError(
            "the source-derived PHP ABI no longer fits the listEventTitles semantic facade"
        )


def source_evidence(candidate: Candidate) -> dict[str, object]:
    return {
        "signatureSha256": candidate.declaration.signature_sha256,
        "spans": [span.json() for span in candidate.spans],
    }


def binding(candidate: Candidate) -> dict[str, object]:
    binding_id, haxe_path, capability_id = BINDING_POLICY[candidate.native_name]
    declaration = candidate.declaration
    return {
        "id": binding_id,
        "target": declaration.target,
        "kind": declaration.kind,
        "nativeName": declaration.native_name,
        "haxePath": haxe_path,
        "sourceInputId": (
            "browser-types" if declaration.target == "javascript" else "php-stubs"
        ),
        "sourceEvidence": source_evidence(candidate),
        "capabilityId": capability_id,
        "parameters": [
            parameter.json(position)
            for position, parameter in enumerate(declaration.parameters)
        ],
        "returnType": declaration.return_type.json(),
        "status": "admitted-precise",
    }


def generate_documents(model: AbiModel) -> dict[str, dict[str, object]]:
    require_policy(model)
    require_semantic_facade_policy(model)
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
        "sha256": file_sha256(GENERATOR_PATH),
    }
    admitted = sorted(
        (binding(candidate) for candidate in model.admitted()),
        key=lambda value: str(value["id"]),
    )
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
        "bindings": admitted,
        "ownership": {
            "providerRuntime": "external-native-provider",
            "contract": "cli-owned-generated",
            "applicationLogic": "haxe-authored",
            "compilerRecognition": "generic-contract-only-no-provider-name-branches",
            "regeneration": "private-stage-deterministic-diff-before-publication",
            "removal": "manifest-owned-complete-content-bundle-provider-source-untouched",
            "modifiedGeneratedFile": "fail-closed-no-overwrite-or-delete",
        },
    }
    contract["contractDigest"] = self_digest(contract, "contractDigest")

    capabilities: list[dict[str, object]] = []
    capability_specs = (
        ("calendar.badge.browser", "javascript", "browser-module", True, "javascript-exports"),
        ("calendar.read.php", "php", "request", False, "wordpress-plugin-and-symbols"),
    )
    for capability_id, target, scope, optional, kind in capability_specs:
        selected = [
            value for value in admitted if value["capabilityId"] == capability_id
        ]
        capabilities.append(
            {
                "id": capability_id,
                "target": target,
                "scope": scope,
                "optional": optional,
                "probe": {
                    "kind": kind,
                    "requiredBindings": [str(value["id"]) for value in selected],
                    "requiredNativeSymbols": [
                        str(value["nativeName"]) for value in selected
                    ],
                    "versionMatch": "exact",
                    "artifactMatch": "exact-sha256",
                    "conditionalFailure": "unavailable-not-partially-authorized",
                },
            }
        )
    capability: dict[str, object] = {
        "schema": "wordpress-hx.adoption-capability.v1",
        "schemaVersion": 1,
        "capabilitySetId": "acme-calendar.capabilities",
        "capabilitySetVersion": "1.0.0",
        "contract": {
            "id": "acme-calendar.wp70",
            "version": "1.0.0",
            "sha256": contract["contractDigest"],
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
        "capabilities": capabilities,
    }
    capability["capabilitySetDigest"] = self_digest(
        capability, "capabilitySetDigest"
    )

    omissions = [
        {
            "nativeName": candidate.native_name,
            "target": candidate.declaration.target,
            "kind": candidate.declaration.kind,
            "code": candidate.omission_code,
            "reason": candidate.omission_reason,
            "sourceInputIds": sorted({span.input_id for span in candidate.spans}),
            "sourceSpans": [span.json() for span in candidate.spans],
            "signatureSha256": candidate.declaration.signature_sha256,
            "requiredAction": candidate.required_action,
        }
        for candidate in model.omitted()
    ]
    conflicts = [
        {
            "nativeName": candidate.native_name,
            "strongerInputId": candidate.declaration.spans[0].input_id,
            "weakerInputId": candidate.runtime.spans[0].input_id,
            "strongerSourceSpan": candidate.declaration.spans[0].json(),
            "weakerSourceSpan": candidate.runtime.spans[0].json(),
            "resolution": "omit-binding-and-report",
        }
        for candidate in model.omitted()
        if candidate.omission_code == "conflicting-authority"
    ]
    review: dict[str, object] = {
        "schema": "wordpress-hx.adoption-review.v1",
        "schemaVersion": 1,
        "reportId": "acme-calendar.review.1",
        "contract": {
            "id": "acme-calendar.wp70",
            "version": "1.0.0",
            "sha256": contract["contractDigest"],
        },
        "provider": {
            "id": "acme-calendar",
            "version": version,
            "artifactSha256": artifact_sha,
        },
        "generator": generator,
        "summary": {
            "discovered": len(model.candidates),
            "included": len(admitted),
            "omitted": len(omissions),
            "conflicts": len(conflicts),
        },
        "includedBindings": [str(value["id"]) for value in admitted],
        "omissions": omissions,
        "conflicts": conflicts,
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


def haxe_type(value: AbiType) -> str:
    primitive = {
        "string": "String",
        "javascript-number": "Float",
        "php-int": "Int",
        "bool": "Bool",
        "javascript-object": "GeneratedJavascriptObject",
        "void": "Void",
    }.get(value.kind)
    if primitive is not None:
        return primitive
    if value.kind == "list" and value.value is not None:
        return f"Array<{haxe_type(value.value)}>"
    if value.kind == "native-nominal" and value.name is not None:
        return value.name.rsplit("\\", 1)[-1]
    raise ValueError(
        f"admitted ABI type has no Haxe representation: {value.signature()}"
    )


def admitted_candidate(model: AbiModel, native_name: str) -> Candidate:
    candidate = model.by_name().get(native_name)
    if candidate is None or not candidate.precise:
        raise ValueError(
            f"generated Haxe surface requires precise binding: {native_name}"
        )
    return candidate


def find_structure(model: AbiModel, name: str) -> AbiType:
    for candidate in model.admitted():
        for parameter in candidate.declaration.parameters:
            if parameter.value_type.kind == "structure" and parameter.value_type.name == name:
                return parameter.value_type
    raise ValueError(f"admitted ABI omits structure {name}")


def haxe_surface(
    model: AbiModel,
    documents: dict[str, dict[str, object]],
) -> bytes:
    contract = documents["contract"]
    provider = dict(contract["provider"])
    capability = documents["capability"]
    capability_records = {
        str(value["id"]): value for value in list(capability["capabilities"])
    }
    format_label = admitted_candidate(model, "@acme/calendar.formatCalendarLabel")
    badge_binding = admitted_candidate(model, "@acme/calendar.CalendarBadge")
    list_events = admitted_candidate(model, "Acme\\Calendar\\list_events")
    if len(format_label.declaration.parameters) != 1:
        raise ValueError("formatCalendarLabel semantic facade requires one parameter")
    if len(badge_binding.declaration.parameters) != 1:
        raise ValueError("CalendarBadge semantic facade requires one parameter")
    if len(list_events.declaration.parameters) != 1:
        raise ValueError("list_events semantic facade requires one parameter")
    badge = find_structure(model, "CalendarBadgeProps")
    fields = "\n".join(
        f"\tpublic final {'?' if field.requirement == 'optional' else ''}{field.name}:{haxe_type(field.value_type)};"
        for field in badge.fields
    )
    arguments = ", ".join(
        f"{field.name}:{haxe_type(field.value_type)}" for field in badge.fields
    )
    assignments = "\n".join(
        f"\t\tthis.{field.name} = {field.name};" for field in badge.fields
    )
    read_bindings = list(
        dict(capability_records["calendar.read.php"])["probe"]["requiredBindings"]
    )
    badge_bindings = list(
        dict(capability_records["calendar.badge.browser"])["probe"]["requiredBindings"]
    )
    event_query_type = haxe_type(list_events.declaration.parameters[0].value_type)
    format_parameter_type = haxe_type(
        format_label.declaration.parameters[0].value_type
    )
    format_return_type = haxe_type(format_label.declaration.return_type)
    badge_return_type = haxe_type(badge_binding.declaration.return_type)
    read_binding_lines = "\n".join(
        f'\t\t\t"{binding}"{"," if index + 1 < len(read_bindings) else ""}'
        for index, binding in enumerate(read_bindings)
    )
    source = f'''package wordpress.hx.adoption.prototype.generated;

import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityRequirement;
import wordpress.hx.adoption.prototype.Adoption.LifecycleKind;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.ProviderContract;

final class AcmeCalendarProvider {{}}
final class CalendarReadCapability {{}}
final class CalendarBadgeCapability {{}}

final class GeneratedAcmeCalendar {{
\tpublic static final provider = new ProviderContract<AcmeCalendarProvider>("acme-calendar", "{provider['version']}",
\t\t"{provider['artifactSha256']}");

\tpublic static final read = new CapabilityContract<AcmeCalendarProvider, CalendarReadCapability, PhpRequestScope>("calendar.read.php",
\t\tLifecycleKind.PhpRequest, CapabilityRequirement.Required, [
{read_binding_lines}
\t\t]);

\tpublic static final badge = new CapabilityContract<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>("calendar.badge.browser",
\t\tLifecycleKind.BrowserModule, CapabilityRequirement.Optional, {json.dumps(badge_bindings)});
}}

final class EventQuery {{
\tpublic final limit:{event_query_type};

\tpublic function new(limit:{event_query_type}) {{
\t\tthis.limit = limit;
\t}}
}}

final class CalendarBadgeProps {{
{fields}

\tpublic function new({arguments}) {{
{assignments}
\t}}
}}

#if php
@:native("WordPressHxAcmeCalendarVerifiedProvider")
extern class GeneratedPhpProviderHandle {{
\tpublic final bundleDigest:String;
}}

@:native("WordPressHxAcmeCalendarFacade")
extern class GeneratedPhpFacade {{
\tpublic static function open(pluginFile:String, bundleFile:String):GeneratedPhpProviderHandle;

\tpublic static function listEventTitles(provider:GeneratedPhpProviderHandle, limit:Int):php.NativeIndexedArray<String>;
}}
#end

#if js
/** Opaque because the authoritative TypeScript declaration promises only object. */
extern class GeneratedJavascriptObject {{}}

extern class GeneratedBrowserProviderHandle {{
\tpublic final bundleDigest:String;
\tpublic function formatLabel(count:{format_parameter_type}):{format_return_type};
\tpublic function renderBadge(props:CalendarBadgeProps):{badge_return_type};
}}

@:native("WordPressHxAcmeCalendarFacade")
extern class GeneratedBrowserFacade {{
\tpublic static function openExactProvider(packageRoot:String, generation:String, bundleFile:String):js.lib.Promise<GeneratedBrowserProviderHandle>;
}}
#end
'''
    return source.encode("utf-8")


def static_member_bytes(
    model: AbiModel,
    documents: dict[str, dict[str, object]],
    provider_archive: bytes,
    version: str,
) -> dict[str, tuple[str, bytes]]:
    return {
        f"{CONTENT_ROOT}/capability.json": (
            "capability",
            canonical_file(documents["capability"]),
        ),
        f"{CONTENT_ROOT}/contract.json": (
            "contract",
            canonical_file(documents["contract"]),
        ),
        f"{CONTENT_ROOT}/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx": (
            "haxe-facade",
            haxe_surface(model, documents),
        ),
        f"{CONTENT_ROOT}/provider/acme-calendar.{version}.zip": (
            "provider-artifact",
            provider_archive,
        ),
        f"{CONTENT_ROOT}/review.json": (
            "review",
            canonical_file(documents["review"]),
        ),
    }


def runtime_bundle_policy(
    members: dict[str, tuple[str, bytes]],
) -> list[dict[str, object]]:
    return [
        {
            "path": path,
            "role": role,
            "sha256": sha256(content),
            "sizeBytes": len(content),
        }
        for path, (role, content) in sorted(members.items())
    ]


def php_facade(
    version: str,
    plugin_sha256: str,
    provider_artifact_sha256: str,
    static_policy: list[dict[str, object]],
) -> bytes:
    policy_json = canonical(static_policy).decode("utf-8")
    source = f'''<?php

declare(strict_types=1);

final class WordPressHxAcmeCalendarProviderUnavailable extends RuntimeException {{}}

final class WordPressHxAcmeCalendarVerifiedProvider
{{
    public function __construct(
        public readonly string $bundleDigest
    ) {{}}

    /** @return list<string> */
    public function listEventTitles(int $limit): array
    {{
        try {{
            $events = \\Acme\\Calendar\\list_events($limit);
        }} catch (Throwable $failure) {{
            throw new RuntimeException('provider-call-failed', 0, $failure);
        }}
        $titles = [];
        foreach ($events as $event) {{
            if (!$event instanceof \\Acme\\Calendar\\Event) {{
                throw new UnexpectedValueException('provider-returned-wrong-event');
            }}
            $titles[] = $event->title();
        }}
        return $titles;
    }}
}}

final class WordPressHxAcmeCalendarFacade
{{
    private static function verifyBundle(string $bundleFile): string
    {{
        if (!is_file($bundleFile)) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('content-bundle-absent');
        }}
        $bytes = file_get_contents($bundleFile);
        if (!is_string($bytes) || !str_ends_with($bytes, "\\n")) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }}
        $canonical = substr($bytes, 0, -1);
        if (preg_match('/^\\{{"bundleDigest":"([0-9a-f]{{64}})",/', $canonical, $match) !== 1
            || !isset($match[0], $match[1])) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }}
        $material = '{{' . substr($canonical, strlen($match[0]));
        if (!hash_equals($match[1], hash('sha256', $material))) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }}
        try {{
            $bundle = json_decode($canonical, true, 512, JSON_THROW_ON_ERROR);
        }} catch (JsonException $failure) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle', 0, $failure);
        }}
        if (!is_array($bundle)
            || ($bundle['schema'] ?? null) !== 'wordpress-hx.adoption-bundle.v1'
            || ($bundle['schemaVersion'] ?? null) !== 1
            || ($bundle['bundleId'] ?? null) !== 'acme-calendar.wp70.bundle'
            || ($bundle['bundleVersion'] ?? null) !== '1.0.0'
            || ($bundle['provider']['id'] ?? null) !== 'acme-calendar'
            || ($bundle['provider']['version'] ?? null) !== '{version}'
            || ($bundle['provider']['artifactSha256'] ?? null) !== '{provider_artifact_sha256}') {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }}
        $expectedStaticMembers = json_decode('{policy_json}', true, 512, JSON_THROW_ON_ERROR);
        $members = $bundle['members'] ?? null;
        if (!is_array($expectedStaticMembers) || !is_array($members) || count($members) !== 7) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }}
        $membersByRole = [];
        foreach ($members as $member) {{
            if (!is_array($member)
                || array_keys($member) !== ['path', 'role', 'sha256', 'sizeBytes']
                || !is_string($member['role'])
                || isset($membersByRole[$member['role']])) {{
                throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
            }}
            $membersByRole[$member['role']] = $member;
        }}
        foreach ($expectedStaticMembers as $expected) {{
            if (!is_array($expected)
                || !is_string($expected['role'] ?? null)
                || ($membersByRole[$expected['role']] ?? null) != $expected) {{
                throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
            }}
        }}
        foreach ([
            'javascript-facade' => 'generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs',
            'php-facade' => 'generated/adoption/acme-calendar/php/acme-calendar-facade.php',
        ] as $role => $path) {{
            $member = $membersByRole[$role] ?? null;
            if (!is_array($member)
                || ($member['path'] ?? null) !== $path
                || preg_match('/^[0-9a-f]{{64}}$/', $member['sha256'] ?? '') !== 1
                || !is_int($member['sizeBytes'] ?? null)
                || $member['sizeBytes'] <= 0) {{
                throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
            }}
        }}
        return $match[1];
    }}

    public static function open(
        string $pluginFile,
        string $bundleFile
    ): WordPressHxAcmeCalendarVerifiedProvider {{
        $bundleDigest = self::verifyBundle($bundleFile);
        if (!is_file($pluginFile)) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('provider-absent');
        }}
        $bytes = file_get_contents($pluginFile);
        if (!is_string($bytes) || !hash_equals('{plugin_sha256}', hash('sha256', $bytes))) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-provider-artifact');
        }}
        if (preg_match('/^Version:\\s*([^\\s]+)$/m', $bytes, $match) !== 1
            || !isset($match[1])
            || $match[1] !== '{version}') {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-provider-version');
        }}
        if (!str_starts_with($bytes, '<?php')) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-provider-artifact');
        }}
        eval(substr($bytes, 5));
        if (!function_exists('Acme\\\\Calendar\\\\list_events')
            || !class_exists('Acme\\\\Calendar\\\\Event', false)) {{
            throw new WordPressHxAcmeCalendarProviderUnavailable('required-provider-symbol-missing');
        }}
        return new WordPressHxAcmeCalendarVerifiedProvider($bundleDigest);
    }}

    /** @return list<string> */
    public static function listEventTitles(
        WordPressHxAcmeCalendarVerifiedProvider $provider,
        int $limit
    ): array {{
        return $provider->listEventTitles($limit);
    }}
}}
'''
    return source.encode("utf-8")


def browser_facade(
    version: str,
    module_sha256: str,
    package_sha256: str,
    provider_artifact_sha256: str,
    static_policy: list[dict[str, object]],
) -> bytes:
    policy_json = canonical(static_policy).decode("utf-8")
    source = f'''import {{ createHash }} from "node:crypto";
import {{ readFile }} from "node:fs/promises";
import path from "node:path";

const expected = Object.freeze({{
  version: "{version}",
  moduleSha256: "{module_sha256}",
  packageSha256: "{package_sha256}",
  providerArtifactSha256: "{provider_artifact_sha256}",
}});
const expectedStaticMembers = Object.freeze({policy_json});

function digest(bytes) {{
  return createHash("sha256").update(bytes).digest("hex");
}}

async function verifyBundle(bundleFile) {{
  let bytes;
  try {{
    bytes = await readFile(bundleFile);
  }} catch (_) {{
    throw new Error("content-bundle-absent");
  }}
  const canonical = bytes.toString("utf8");
  const match = /^\\{{"bundleDigest":"([0-9a-f]{{64}})",/.exec(canonical);
  if (!match || !canonical.endsWith("\\n")) {{
    throw new Error("wrong-content-bundle");
  }}
  const withoutNewline = canonical.slice(0, -1);
  const material = "{{" + withoutNewline.slice(match[0].length);
  if (digest(Buffer.from(material, "utf8")) !== match[1]) {{
    throw new Error("wrong-content-bundle");
  }}
  let bundle;
  try {{
    bundle = JSON.parse(withoutNewline);
  }} catch (_) {{
    throw new Error("wrong-content-bundle");
  }}
  if (bundle.schema !== "wordpress-hx.adoption-bundle.v1"
      || bundle.schemaVersion !== 1
      || bundle.bundleId !== "acme-calendar.wp70.bundle"
      || bundle.bundleVersion !== "1.0.0"
      || bundle.provider?.id !== "acme-calendar"
      || bundle.provider?.version !== expected.version
      || bundle.provider?.artifactSha256 !== expected.providerArtifactSha256) {{
    throw new Error("wrong-content-bundle");
  }}
  if (!Array.isArray(bundle.members) || bundle.members.length !== 7) {{
    throw new Error("wrong-content-bundle");
  }}
  const membersByRole = new Map();
  for (const member of bundle.members) {{
    if (!member || typeof member !== "object" || Array.isArray(member)
        || Object.keys(member).sort().join("|") !== "path|role|sha256|sizeBytes"
        || typeof member.role !== "string" || membersByRole.has(member.role)) {{
      throw new Error("wrong-content-bundle");
    }}
    membersByRole.set(member.role, member);
  }}
  for (const member of expectedStaticMembers) {{
    if (JSON.stringify(membersByRole.get(member.role)) !== JSON.stringify(member)) {{
      throw new Error("wrong-content-bundle");
    }}
  }}
  for (const [role, memberPath] of [
    ["javascript-facade", "generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs"],
    ["php-facade", "generated/adoption/acme-calendar/php/acme-calendar-facade.php"],
  ]) {{
    const member = membersByRole.get(role);
    if (!member || member.path !== memberPath || !/^[0-9a-f]{{64}}$/.test(member.sha256)
        || !Number.isSafeInteger(member.sizeBytes) || member.sizeBytes <= 0) {{
      throw new Error("wrong-content-bundle");
    }}
  }}
  return match[1];
}}

export async function openExactProvider(packageRoot, generation, bundleFile) {{
  const bundleDigest = await verifyBundle(bundleFile);
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
  const moduleUrl = `data:text/javascript;base64,${{moduleBytes.toString("base64")}}#${{encodeURIComponent(generation)}}`;
  const provider = await import(moduleUrl);
  if (typeof provider.CalendarBadge !== "function" || typeof provider.formatCalendarLabel !== "function") {{
    throw new Error("required-provider-symbol-missing");
  }}
  return Object.freeze({{
    bundleDigest,
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


def content_bundle(
    documents: dict[str, dict[str, object]],
    members: dict[str, tuple[str, bytes]],
) -> dict[str, object]:
    provider = dict(documents["contract"]["provider"])
    bundle: dict[str, object] = {
        "schema": "wordpress-hx.adoption-bundle.v1",
        "schemaVersion": 1,
        "bundleId": "acme-calendar.wp70.bundle",
        "bundleVersion": "1.0.0",
        "provider": {
            "id": "acme-calendar",
            "version": provider["version"],
            "artifactSha256": provider["artifactSha256"],
        },
        "members": [
            {
                "role": role,
                "path": path,
                "sha256": sha256(content),
                "sizeBytes": len(content),
            }
            for path, (role, content) in sorted(members.items())
        ],
    }
    bundle["bundleDigest"] = self_digest(bundle, "bundleDigest")
    return bundle


def ownership_manifest(
    owned_files: dict[str, bytes],
    contract: dict[str, object],
) -> dict[str, object]:
    source_bytes = GENERATOR_PATH.read_bytes()
    source_span = {
        "path": "scripts/adoption/generate-fixture.py",
        "sourceSha256": sha256(source_bytes),
        "symbol": "write_documents",
        "start": {"line": 1, "column": 1, "offset": 0},
        "end": {
            "line": len(source_bytes.splitlines()),
            "column": 1,
            "offset": len(source_bytes),
        },
    }
    file_records = [
        {
            "contentSha256": sha256(content),
            "kind": "adoption.generated",
            "ownerNodeId": "adoption/acme-calendar",
            "path": path,
            "projectionIds": ["adoption/acme-calendar/bundle"],
            "rootId": "generated",
            "sizeBytes": len(content),
            "sourceNodeIds": ["adoption/acme-calendar/provider-inputs"],
            "sourceSpans": [source_span],
            "validatorIds": ["adoption.bundle"],
        }
        for path, content in sorted(owned_files.items())
    ]
    generation_material = [
        {
            "contentSha256": value["contentSha256"],
            "path": value["path"],
            "sizeBytes": value["sizeBytes"],
        }
        for value in file_records
    ]
    profile = dict(contract["profile"])
    provider = dict(contract["provider"])
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
            "generatorSourceSha256": file_sha256(GENERATOR_PATH),
            "sdkVersion": "0.0.0-fixture",
            "toolchainSha256": file_sha256(ROOT / "manifests/toolchain.lock.json"),
        },
        "inputs": {
            "emissionResultSha256s": [
                sha256(b"".join(owned_files[path] for path in sorted(owned_files)))
            ],
            "generationSha256": sha256(canonical(generation_material)),
            "profile": {
                "catalogRevision": profile["catalogRevision"],
                "catalogSha256": profile["catalogSha256"],
                "profileId": profile["id"],
            },
            "semanticPlanSha256": contract["contractDigest"],
            "sourceTreeSha256": provider["sourceSha256"],
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
                    ROOT / "schemas/adoption-bundle.schema.json"
                ),
                "outcome": "passed",
                "scope": "complete-staged-tree",
                "tool": "ADR-015 adoption bundle validator",
                "toolSha256": file_sha256(
                    ROOT
                    / "fixtures/adoption-contract/test-ownership/adoption/ownership/AdoptionBundleValidator.hx"
                ),
                "validatorId": "adoption.bundle",
                "version": "v1",
            }
        ],
        "files": file_records,
    }
    manifest["manifestDigest"] = self_digest(manifest, "manifestDigest")
    return manifest


def write_documents(output: Path) -> None:
    model = merge_model(INPUT_ROOT, logical_path)
    documents = generate_documents(model)
    output.mkdir(parents=True, exist_ok=True)
    version = provider_version()
    provider_archive = deterministic_provider_archive()
    provider_artifact_sha256 = sha256(provider_archive)
    static_members = static_member_bytes(model, documents, provider_archive, version)
    static_policy = runtime_bundle_policy(static_members)
    members: dict[str, tuple[str, bytes]] = {
        **static_members,
        f"{CONTENT_ROOT}/browser/acme-calendar-facade.mjs": (
            "javascript-facade",
            browser_facade(
                version,
                file_sha256(INPUT_ROOT / "index.js"),
                file_sha256(INPUT_ROOT / "package-metadata.json"),
                provider_artifact_sha256,
                static_policy,
            ),
        ),
        f"{CONTENT_ROOT}/php/acme-calendar-facade.php": (
            "php-facade",
            php_facade(
                version,
                file_sha256(INPUT_ROOT / "plugin.php"),
                provider_artifact_sha256,
                static_policy,
            ),
        ),
    }
    bundle = content_bundle(documents, members)
    bundle_path = f"{CONTENT_ROOT}/adoption.bundle.json"
    bundle_bytes = canonical_file(bundle)
    owned_files = {
        **{path: content for path, (_, content) in members.items()},
        bundle_path: bundle_bytes,
    }
    ownership = ownership_manifest(owned_files, documents["contract"])

    for path, content in owned_files.items():
        target = output / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    manifest_target = output / "generated/_GeneratedFiles.json"
    manifest_target.parent.mkdir(parents=True, exist_ok=True)
    manifest_target.write_bytes(canonical_file(ownership))

    (output / "acme-calendar.contract.json").write_bytes(pretty(documents["contract"]))
    (output / "acme-calendar.capability.json").write_bytes(
        pretty(documents["capability"])
    )
    (output / "acme-calendar.review.json").write_bytes(pretty(documents["review"]))
    (output / "acme-calendar.bundle.json").write_bytes(bundle_bytes)
    (output / "acme-calendar.generated-files.json").write_bytes(
        canonical_file(ownership)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    write_documents(arguments.output)


if __name__ == "__main__":
    main()
