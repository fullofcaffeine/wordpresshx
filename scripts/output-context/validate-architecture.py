#!/usr/bin/env python3
"""Independently validate the ADR-012 output-context architecture."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARCHITECTURE_PATH = ROOT / "manifests" / "output-context-architecture.json"
FIXTURE_ROOT = ROOT / "fixtures" / "output-context"
TRANSCRIPT_PATH = FIXTURE_ROOT / "expected" / "context-plan.txt"


class ValidationError(ValueError):
    pass


def strict_json(text: str, label: str) -> object:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ValidationError(f"{label}: duplicate key {key}")
            result[key] = value
        return result

    def reject_number(value: str) -> object:
        raise ValidationError(f"{label}: floating point is forbidden: {value}")

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs,
            parse_float=reject_number,
            parse_constant=reject_number,
        )
    except json.JSONDecodeError as error:
        raise ValidationError(f"{label}: malformed JSON: {error}") from error


def require_dict(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValidationError(f"{label} must be an object")
    return value


def require_list(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        raise ValidationError(f"{label} must be an array")
    return value


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_tree_digest() -> str:
    lines: list[str] = []
    for source in sorted(path for path in FIXTURE_ROOT.rglob("*") if path.is_file()):
        if source == TRANSCRIPT_PATH:
            continue
        relative = source.relative_to(ROOT).as_posix()
        lines.append(f"{sha256(source.read_bytes())}  {relative}\n")
    return sha256("".join(lines).encode("utf-8"))


def unique_strings(value: object, label: str) -> list[str]:
    entries = require_list(value, label)
    if not all(isinstance(entry, str) and entry for entry in entries):
        raise ValidationError(f"{label} must contain non-empty strings")
    strings = [entry for entry in entries if isinstance(entry, str)]
    if len(strings) != len(set(strings)):
        raise ValidationError(f"{label} contains a duplicate")
    return strings


def validate_model(model: dict[str, object]) -> None:
    if model.get("schemaVersion") != 1 or model.get("decisionId") != "ADR-012":
        raise ValidationError("output-context architecture identity changed")
    if model.get("profileId") != "wp70-release":
        raise ValidationError("output-context architecture profile changed")
    if model.get("status") not in {
        "proposed-pending-fresh-review",
        "review-corrections-applied-pending-rereview",
        "accepted-after-review",
    }:
        raise ValidationError("output-context architecture status is invalid")

    authority = require_dict(model.get("authority"), "authority")
    expected_authority = {
        "owner": "wordpress-hx-output-context-v1",
        "lateEscapingRequired": True,
        "universalSafeTypeAllowed": False,
        "terminalRawStringConversionAllowed": False,
        "terminalValuesSerializable": False,
        "escapingIdempotenceAssumed": False,
        "validationEqualsEscaping": False,
        "sanitizationEqualsValidation": False,
        "nonceEqualsAuthorization": False,
    }
    if authority != expected_authority:
        raise ValidationError("output-context authority policy changed")

    source_states = require_list(model.get("sourceStates"), "sourceStates")
    expected_states = {"untrusted", "validated", "sanitized", "domain-value"}
    state_ids: set[str] = set()
    for index, value in enumerate(source_states):
        state = require_dict(value, f"sourceStates[{index}]")
        identity = state.get("id")
        if not isinstance(identity, str) or identity in state_ids:
            raise ValidationError("source state identity is invalid")
        if state.get("outputAuthority") is not False:
            raise ValidationError(f"source state {identity} became output authority")
        state_ids.add(identity)
    if state_ids != expected_states:
        raise ValidationError("source state inventory changed")

    contexts = require_list(model.get("contexts"), "contexts")
    expected_contexts = {
        "html-text": ("HtmlText", "esc_html-at-final-sink"),
        "html-attribute": ("HtmlAttribute", "esc_attr-at-final-sink"),
        "html-url": ("HtmlUrl", "esc_url-at-final-sink"),
        "html-textarea": ("TextareaText", "esc_textarea-at-final-sink"),
        "html-rich-policy": (
            "policy-branded-KsesHtml",
            "wp_kses_post-or-wp_kses_data-or-wp_kses-at-final-sink",
        ),
        "json-document": (
            "JsonDocument<T>",
            "wp_json_encode-with-explicit-failure-handling-for-JSON-response",
        ),
        "html-script-data": (
            "HtmlScriptData<T>",
            "wp_json_encode-with-JSON_HEX_TAG-AMP-APOS-QUOT-and-explicit-failure",
        ),
        "css-declarations": (
            "CssDeclarations",
            "typed-CSS-printer-then-esc_attr",
        ),
        "compiler-markup": (
            "CompilerMarkup",
            "static-native-markup-plus-context-specific-native-calls",
        ),
        "unsafe-raw-target": ("withheld-until-ADR-019", "not-published"),
    }
    by_context: dict[str, dict[str, object]] = {}
    for index, value in enumerate(contexts):
        context = require_dict(value, f"contexts[{index}]")
        identity = context.get("id")
        if not isinstance(identity, str) or identity in by_context:
            raise ValidationError("context identity is invalid")
        if context.get("crossContextReuse") is not False:
            raise ValidationError(f"context {identity} permits cross-context reuse")
        unique_strings(context.get("sinks"), f"context {identity} sinks")
        by_context[identity] = context
    if set(by_context) != set(expected_contexts):
        raise ValidationError("output-context inventory changed")
    for identity, (terminal, server_lowering) in expected_contexts.items():
        context = by_context[identity]
        if context.get("terminalContract") != terminal:
            raise ValidationError(f"context {identity} terminal contract changed")
        if context.get("serverLowering") != server_lowering:
            raise ValidationError(f"context {identity} server lowering changed")
    if by_context["html-url"].get("acceptedSource") != "ValidatedUrl":
        raise ValidationError("URL context no longer requires a validated URL")
    if by_context["html-rich-policy"].get("acceptedSource") != (
        "String-plus-named-profile-native-or-content-addressed-custom-KSES-policy"
    ):
        raise ValidationError("rich HTML policy authority changed")
    if by_context["unsafe-raw-target"].get("sinks") != []:
        raise ValidationError("unsafe raw target gained a published sink")

    allowed = unique_strings(model.get("allowedEdges"), "allowedEdges")
    forbidden = unique_strings(model.get("forbiddenEdges"), "forbiddenEdges")
    if len(allowed) != 11 or len(forbidden) != 14:
        raise ValidationError("conversion edge inventory changed")
    required_forbidden = {
        "HtmlText->HtmlAttribute",
        "HtmlAttribute->HtmlText",
        "HtmlUrl->HtmlText",
        "JsonDocument<T>->HtmlScriptData<T>",
        "HtmlScriptData<T>->JsonDocument<T>",
        "KsesHtml->CompilerMarkup",
        "String->KsesHtml-without-policy",
        "String->CompilerMarkup",
        "String->CssDeclarations",
        "terminal-output->storage",
        "terminal-output->serialization",
        "server-event-attribute->inline-JavaScript",
        "browser-raw-string->rich-HTML",
        "unsafe-raw-target->release-without-current-waiver",
    }
    if set(forbidden) != required_forbidden:
        raise ValidationError("forbidden conversion graph changed")
    if any(edge in allowed for edge in required_forbidden):
        raise ValidationError("a forbidden conversion entered the allowed graph")

    hxx_values = require_list(model.get("hxxResolution"), "hxxResolution")
    hxx: dict[str, dict[str, object]] = {}
    for index, value in enumerate(hxx_values):
        rule = require_dict(value, f"hxxResolution[{index}]")
        position = rule.get("position")
        if not isinstance(position, str) or position in hxx:
            raise ValidationError("HXX position identity is invalid")
        hxx[position] = rule
    if len(hxx) != 8:
        raise ValidationError("HXX position inventory changed")
    if hxx.get("href-src-action-formaction", {}).get("input") != (
        "static-checked-literal-or-ValidatedUrl"
    ):
        raise ValidationError("HXX URL positions no longer require URL validation")
    if hxx.get("server-event-handler-attribute", {}).get("result") != "compile-error":
        raise ValidationError("server HXX admitted inline event code")

    constructors = require_list(model.get("trustConstructors"), "trustConstructors")
    by_constructor: dict[str, dict[str, object]] = {}
    for index, value in enumerate(constructors):
        constructor = require_dict(value, f"trustConstructors[{index}]")
        identity = constructor.get("id")
        if not isinstance(identity, str) or identity in by_constructor:
            raise ValidationError("trust constructor identity is invalid")
        by_constructor[identity] = constructor
    if set(by_constructor) != {
        "compiler-resolved-hxx",
        "wordpress-kses-policy",
        "admitted-native-provider",
        "unsafe-waiver",
    }:
        raise ValidationError("trust constructor inventory changed")
    if by_constructor["compiler-resolved-hxx"].get("acceptsRawMarkupString") is not False:
        raise ValidationError("compiler HXX constructor accepts raw markup")
    if by_constructor["admitted-native-provider"].get("acceptsRawMarkupString") is not False:
        raise ValidationError("native provider constructor accepts raw markup")
    if by_constructor["wordpress-kses-policy"].get("provenanceRequired") != (
        "policy-kind-identity-version-and-for-custom-allowlist-protocol-digest"
    ):
        raise ValidationError("KSES policy provenance changed")
    if by_constructor["unsafe-waiver"].get("provenanceRequired") != (
        "ADR-019-waiver-id-source-hash-owner-expiry-and-removal-gate"
    ):
        raise ValidationError("unsafe constructor lost waiver provenance")

    wordpress = require_dict(model.get("wordpressSemantics"), "wordpressSemantics")
    if wordpress.get("escapeLate") is not True:
        raise ValidationError("WordPress output no longer escapes late")
    if wordpress.get("nativeKsesPolicyAuthority") != (
        "exact-profile-filterable-runtime-semantics"
    ):
        raise ValidationError("native KSES policy semantics changed")
    if wordpress.get("customKsesPolicyAuthority") != (
        "content-addressed-tags-attributes-and-explicit-protocols"
    ):
        raise ValidationError("custom KSES policy semantics changed")
    if wordpress.get("escUrlRawIsNotAnOutputFunction") is not True:
        raise ValidationError("esc_url_raw became an output operation")
    if wordpress.get("wpJsonEncodeFailureMustBeHandled") is not True:
        raise ValidationError("JSON encoding failure became implicit")
    if wordpress.get("inlineEventAttributesDefault") != "rejected":
        raise ValidationError("inline event attributes became a default")

    browser = require_dict(model.get("browserSemantics"), "browserSemantics")
    if browser.get("reactUrlSanitizationAuthority") is not False:
        raise ValidationError("React became URL validation authority")
    if browser.get("richHtmlServerPolicyReusableInBrowser") is not False:
        raise ValidationError("server rich HTML proof leaked into the browser")
    if browser.get("unsafeHtmlPropertyPublic") is not False:
        raise ValidationError("unsafe React HTML property became public")

    evidence = require_dict(model.get("prototypeEvidence"), "prototypeEvidence")
    expected_evidence = {
        "sourceTreeSha256": source_tree_digest(),
        "transcriptSha256": sha256(TRANSCRIPT_PATH.read_bytes()),
        "contextCount": 10,
        "allowedEdgeCount": 11,
        "forbiddenEdgeCount": 14,
        "hxxPositionCount": 8,
        "compileNegativeCount": 8,
        "independentMutationCount": 21,
    }
    for field, expected in expected_evidence.items():
        if evidence.get(field) != expected:
            raise ValidationError(
                f"prototype evidence {field} changed: expected {expected!r}"
            )
    targets = unique_strings(evidence.get("targets"), "prototypeEvidence targets")
    if len(targets) != 5 or not any(target.startswith("genes-ts-1.36.3-") for target in targets):
        raise ValidationError("prototype target inventory changed")

    hosted = require_dict(model.get("hostedGate"), "hostedGate")
    if hosted != {
        "workflow": ".github/workflows/output-context.yml",
        "job": "output-context",
        "command": "bash scripts/output-context/test.sh",
        "status": "configured-pending-first-hosted-run",
    }:
        raise ValidationError("hosted output-context gate declaration changed")

    references = require_list(model.get("referenceReview"), "referenceReview")
    if len(references) != 7:
        raise ValidationError("reference review inventory changed")
    sha1 = re.compile(r"^[0-9a-f]{40}$")
    sha256_pattern = re.compile(r"^[0-9a-f]{64}$")
    for index, value in enumerate(references):
        reference = require_dict(value, f"referenceReview[{index}]")
        if reference.get("copiedBytes") is not False:
            raise ValidationError(f"reference {index} copied bytes")
        if not sha1.fullmatch(str(reference.get("commit", ""))):
            raise ValidationError(f"reference {index} commit is invalid")
        if not sha1.fullmatch(str(reference.get("gitBlob", ""))):
            raise ValidationError(f"reference {index} blob is invalid")
        if not sha256_pattern.fullmatch(str(reference.get("sha256", ""))):
            raise ValidationError(f"reference {index} digest is invalid")

    documentation = require_list(
        model.get("officialDocumentation"), "officialDocumentation"
    )
    if len(documentation) != 3:
        raise ValidationError("official documentation inventory changed")
    for index, value in enumerate(documentation):
        entry = require_dict(value, f"officialDocumentation[{index}]")
        if not str(entry.get("url", "")).startswith("https://developer.wordpress.org/"):
            raise ValidationError("non-authoritative output-security documentation entered")
        if entry.get("retrievedAt") != "2026-07-19":
            raise ValidationError("documentation review date changed")

    claims = require_dict(model.get("claims"), "claims")
    if claims.get("architectureDecision") != model.get("status"):
        raise ValidationError("architecture decision claim and status differ")
    for unproven in (
        "productionSdkTypes",
        "productionHxxLowerer",
        "browserRichHtmlPolicy",
        "php74Runtime",
        "packedConsumer",
        "productionSupport",
    ):
        if claims.get(unproven) != "not-tested":
            raise ValidationError(f"architecture overclaims {unproven}")


def mutation_cases(model: dict[str, object]) -> list[tuple[str, dict[str, object]]]:
    mutations: list[tuple[str, dict[str, object]]] = []

    def changed(label: str) -> dict[str, object]:
        value = copy.deepcopy(model)
        mutations.append((label, value))
        return value

    changed("universal-safe-type")["authority"]["universalSafeTypeAllowed"] = True
    changed("terminal-string-conversion")["authority"]["terminalRawStringConversionAllowed"] = True
    changed("validation-as-escaping")["authority"]["validationEqualsEscaping"] = True
    changed("sanitized-output-authority")["sourceStates"][2]["outputAuthority"] = True
    changed("missing-context")["contexts"].pop()
    changed("duplicate-context")["contexts"][1]["id"] = "html-text"
    changed("text-lowering")["contexts"][0]["serverLowering"] = "htmlspecialchars"
    changed("raw-url-source")["contexts"][2]["acceptedSource"] = "String"
    changed("cross-context-reuse")["contexts"][0]["crossContextReuse"] = True
    changed("unsafe-sink")["contexts"][9]["sinks"] = ["template-root"]
    changed("forbidden-allowed")["allowedEdges"].append("HtmlText->HtmlAttribute")
    changed("removed-forbidden")["forbiddenEdges"].remove("HtmlText->HtmlAttribute")
    changed("raw-compiler-markup")["trustConstructors"][0]["acceptsRawMarkupString"] = True
    changed("raw-provider-markup")["trustConstructors"][2]["acceptsRawMarkupString"] = True
    changed("weak-kses-provenance")["trustConstructors"][1]["provenanceRequired"] = "identity-only"
    changed("unsafe-without-waiver")["trustConstructors"][3]["provenanceRequired"] = "reason-only"
    changed("raw-hxx-url")["hxxResolution"][2]["input"] = "String"
    changed("server-inline-event")["hxxResolution"][7]["result"] = "html-attribute"
    changed("esc-url-raw-output")["wordpressSemantics"]["escUrlRawIsNotAnOutputFunction"] = False
    changed("react-url-authority")["browserSemantics"]["reactUrlSanitizationAuthority"] = True
    changed("production-overclaim")["claims"]["productionSupport"] = "supported"
    return mutations


def main() -> None:
    model = require_dict(
        strict_json(ARCHITECTURE_PATH.read_text(encoding="utf-8"), "architecture"),
        "architecture",
    )
    validate_model(model)
    mutations = mutation_cases(model)
    if len(mutations) != 21:
        raise ValidationError("independent mutation inventory changed")
    for label, mutation in mutations:
        try:
            validate_model(mutation)
        except ValidationError:
            continue
        raise ValidationError(f"mutation passed unexpectedly: {label}")
    print(
        "ADR-012 output-context architecture passed: "
        f"{len(model['contexts'])} contexts, "
        f"{len(model['forbiddenEdges'])} forbidden edges, "
        f"{len(mutations)} independent mutations"
    )


if __name__ == "__main__":
    main()
