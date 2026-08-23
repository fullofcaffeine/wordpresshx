#!/usr/bin/env python3
"""Derive ADR-015 tool, artifact, and hosted identities from one authority."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARCHITECTURE_PATH = ROOT / "manifests/adoption-contract-architecture.json"
RECEIPT_PATH = ROOT / "manifests/evidence/adr-015-interop-adoption-contract.json"
FIXTURE = ROOT / "fixtures/adoption-contract"


def load(relative: str) -> dict[str, object]:
    value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{relative} must contain one JSON object")
    return value


def pretty(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_tree_sha256() -> str:
    lines: list[str] = []
    for source_root in (
        FIXTURE / "src",
        FIXTURE / "test-support",
        FIXTURE / "test",
        FIXTURE / "test-negative",
    ):
        for path in source_root.rglob("*.hx"):
            relative = path.relative_to(ROOT).as_posix()
            lines.append(f"{sha256(path.read_bytes())}  {relative}\n")
    return sha256("".join(sorted(lines)).encode("utf-8"))


def npm_version(package_lock: dict[str, object], package: str) -> str:
    packages = package_lock.get("packages")
    if not isinstance(packages, dict):
        raise ValueError("build-tooling package lock omits packages")
    record = packages.get(f"node_modules/{package}")
    if not isinstance(record, dict) or not isinstance(record.get("version"), str):
        raise ValueError(f"build-tooling package lock omits {package}")
    return record["version"]


def derive() -> tuple[dict[str, object], dict[str, object]]:
    architecture = load("manifests/adoption-contract-architecture.json")
    receipt = load("manifests/evidence/adr-015-interop-adoption-contract.json")
    contract = load("fixtures/adoption-contract/contract/acme-calendar.contract.json")
    capability = load("fixtures/adoption-contract/contract/acme-calendar.capability.json")
    review = load("fixtures/adoption-contract/contract/acme-calendar.review.json")
    bundle = load("fixtures/adoption-contract/contract/acme-calendar.bundle.json")
    cli_lock = load("packages/cli/dependency-lock.json")
    toolchain = load("manifests/toolchain.lock.json")
    npm_lock = load("packages/gutenberg/build-tooling/package-lock.json")

    compiler = cli_lock.get("compiler")
    runtime = cli_lock.get("runtime")
    haxe = cli_lock.get("haxe")
    if not isinstance(compiler, dict) or not isinstance(runtime, dict) or not isinstance(haxe, dict):
        raise ValueError("CLI dependency lock omits the compiler runtime closure")
    php = toolchain.get("runtimeImages")
    if not isinstance(php, dict):
        raise ValueError("toolchain lock omits runtime images")
    php_record = php.get("php")
    if not isinstance(php_record, dict):
        raise ValueError("toolchain lock omits PHP")
    primary_php = php_record.get("primaryCli")
    if not isinstance(primary_php, dict):
        raise ValueError("toolchain lock omits the primary PHP CLI")
    genes_version = compiler.get("version")
    genes_commit = compiler.get("commit")
    node_version = runtime.get("version")
    haxe_version = haxe.get("version")
    php_version = primary_php.get("version")
    if not all(
        isinstance(value, str)
        for value in (
            genes_version,
            genes_commit,
            node_version,
            haxe_version,
            php_version,
        )
    ):
        raise ValueError("an exact tool identity is missing")
    typescript_version = npm_version(npm_lock, "typescript")

    for relative in (
        "fixtures/adoption-contract/README.md",
        "docs/adr/015-interop-and-adoption-contract-format.md",
    ):
        text = (ROOT / relative).read_text(encoding="utf-8")
        if re.search(r"\bGenes\s+[0-9]+\.[0-9]+\.[0-9]+\b", text):
            raise ValueError(f"{relative} duplicates the exact Genes version")
        if "packages/cli/dependency-lock.json" not in text:
            raise ValueError(f"{relative} omits the Genes lock authority")

    authority = architecture["authority"]
    if not isinstance(authority, dict):
        raise ValueError("architecture authority is not an object")
    authority.update(
        {
            "capabilityObservationOwner": "target-runtime-adapter",
            "callerSuppliedObservationFactsAllowed": False,
            "lifecycleIdentity": "generative-runtime-nonce",
            "sameNominalScopeInstanceReusable": False,
            "bundleVerificationBeforeCapabilityMint": True,
        }
    )
    contracts = architecture["contracts"]
    if not isinstance(contracts, dict):
        raise ValueError("architecture contracts are not an object")
    contracts["bundle"] = {
        "identity": "wordpress-hx.adoption-bundle.v1",
        "schema": "schemas/adoption-bundle.schema.json",
        "purpose": "one-digest-root-for-records-facades-and-ownership",
    }

    hosted = receipt["hostedWorkflow"]
    if not isinstance(hosted, dict):
        raise ValueError("receipt hosted workflow is not an object")
    architecture_hosted = {
        "workflow": ".github/workflows/adoption-contract.yml",
        "job": hosted["job"],
        "command": "bash scripts/adoption/test.sh",
        "runId": hosted["runId"],
        "jobId": hosted["jobId"],
        "commit": hosted["commit"],
        "status": hosted["status"],
    }
    for field in ("historicalRunId", "historicalJobId", "historicalCommit"):
        if field in hosted:
            architecture_hosted[field] = hosted[field]
    architecture["hostedGate"] = architecture_hosted

    prototype = architecture["prototypeEvidence"]
    if not isinstance(prototype, dict):
        raise ValueError("architecture prototype evidence is not an object")
    prototype.update(
        {
            "contractSha256": contract["contractDigest"],
            "capabilitySha256": capability["capabilitySetDigest"],
            "reviewSha256": review["reportDigest"],
            "bundleDigest": bundle["bundleDigest"],
            "bundleFileSha256": sha256(
                (FIXTURE / "contract/acme-calendar.bundle.json").read_bytes()
            ),
            "ownershipManifestSha256": sha256(
                (FIXTURE / "contract/acme-calendar.generated-files.json").read_bytes()
            ),
            "sourceTreeSha256": source_tree_sha256(),
            "transcriptSha256": sha256(
                (FIXTURE / "expected/capability-plan.txt").read_bytes()
            ),
            "contractSchemaSha256": sha256(
                (ROOT / "schemas/adoption-contract.schema.json").read_bytes()
            ),
            "capabilitySchemaSha256": sha256(
                (ROOT / "schemas/adoption-capability.schema.json").read_bytes()
            ),
            "reviewSchemaSha256": sha256(
                (ROOT / "schemas/adoption-review.schema.json").read_bytes()
            ),
            "bundleSchemaSha256": sha256(
                (ROOT / "schemas/adoption-bundle.schema.json").read_bytes()
            ),
            "bindingCount": len(contract["bindings"]),
            "capabilityCount": len(capability["capabilities"]),
            "omissionCount": len(review["omissions"]),
            "conflictCount": len(review["conflicts"]),
            "compileNegativeCount": len(
                [path for path in (FIXTURE / "test-negative").iterdir() if path.is_dir()]
            ),
            "independentMutationCount": 33,
            "targets": [
                f"haxe-{haxe_version}-interp",
                f"genes-ts-{genes_version}@{genes_commit}-typescript-{typescript_version}-node-{node_version}",
                f"stock-haxe-php-{php_version}",
            ],
            "providerRuntimeExecutionDuringGeneration": False,
            "syntheticProviderRuntimeUsed": True,
            "productionOwnershipTransactionUsed": True,
            "realProviderUsed": False,
        }
    )
    architecture_claims = architecture["claims"]
    receipt_claims = receipt["claims"]
    if not isinstance(architecture_claims, dict) or not isinstance(receipt_claims, dict):
        raise ValueError("adoption claims are not objects")
    architecture_claims["typedCapabilityPrototype"] = receipt_claims[
        "typedCapabilityPrototype"
    ]
    architecture_claims["fixtureGenerator"] = receipt_claims["fixtureGenerator"]
    architecture_claims["nativeSyntheticProviderRuntime"] = receipt_claims[
        "nativeProviderAbi"
    ]
    architecture_claims["ownershipTransaction"] = receipt_claims[
        "ownershipTransaction"
    ]

    verification = receipt["verification"]
    if not isinstance(verification, dict):
        raise ValueError("receipt verification is not an object")
    verification.update(
        {
            "sourceTreeSha256": prototype["sourceTreeSha256"],
            "haxeVersion": haxe_version,
            "genesVersion": genes_version,
            "genesCommit": genes_commit,
            "genesAuthority": "packages/cli/dependency-lock.json",
            "typescriptVersion": typescript_version,
            "nodeVersion": node_version,
            "phpVersion": php_version,
            "bindingCount": prototype["bindingCount"],
            "capabilityCount": prototype["capabilityCount"],
            "omissionCount": prototype["omissionCount"],
            "conflictCount": prototype["conflictCount"],
            "compileNegativeCount": prototype["compileNegativeCount"],
            "independentMutationCount": prototype["independentMutationCount"],
            "providerRuntimeExecutionDuringGeneration": False,
            "syntheticProviderRuntimeUsed": True,
            "productionOwnershipTransactionUsed": True,
            "realProviderUsed": False,
        }
    )

    architecture_bytes = pretty(architecture)
    subjects = receipt["subject"]
    if not isinstance(subjects, dict):
        raise ValueError("receipt subjects are not an object")
    for subject in subjects.values():
        if not isinstance(subject, dict) or not isinstance(subject.get("path"), str):
            raise ValueError("receipt subject is invalid")
        path = subject["path"]
        data = architecture_bytes if path == ARCHITECTURE_PATH.relative_to(ROOT).as_posix() else (ROOT / path).read_bytes()
        subject["sha256"] = sha256(data)

    return architecture, receipt


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    arguments = parser.parse_args()
    architecture, receipt = derive()
    expected_architecture = pretty(architecture)
    expected_receipt = pretty(receipt)
    if arguments.write:
        ARCHITECTURE_PATH.write_bytes(expected_architecture)
        RECEIPT_PATH.write_bytes(expected_receipt)
        print("ADR-015 evidence identities refreshed from the CLI lock and receipt")
        return
    stale = []
    if ARCHITECTURE_PATH.read_bytes() != expected_architecture:
        stale.append(ARCHITECTURE_PATH.relative_to(ROOT).as_posix())
    if RECEIPT_PATH.read_bytes() != expected_receipt:
        stale.append(RECEIPT_PATH.relative_to(ROOT).as_posix())
    if stale:
        raise SystemExit("stale ADR-015 evidence identity: " + ", ".join(stale))
    print("ADR-015 evidence identities match the CLI lock and receipt")


if __name__ == "__main__":
    main()
