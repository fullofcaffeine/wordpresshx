#!/usr/bin/env python3
"""Verify the frozen wp70-release build-tool advisory decision."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RECEIPT_PATH = ROOT / "manifests/evidence/g2.3-wp70-build-tool-advisories.json"
SEVERITY = {"info": 0, "low": 1, "moderate": 2, "high": 3, "critical": 4}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ghsa_id(url: str) -> str:
    value = url.rstrip("/").rsplit("/", 1)[-1].lower()
    assert value.startswith("ghsa-"), f"unexpected advisory URL: {url}"
    return "GHSA-" + value.removeprefix("ghsa-")


def verify_receipt(receipt: dict) -> None:
    assert receipt["schemaVersion"] == 1
    assert receipt["receiptId"] == "G2.3-WP70-BUILD-TOOL-ADVISORIES"
    assert receipt["bead"] == "wordpresshx-g2.3"
    assert receipt["status"] == "verified-bounded-build-residual-provider-risk"
    assert receipt["profileId"] == "wp70-release"

    for subject in receipt["subjects"].values():
        path = ROOT / subject["path"]
        assert path.is_file(), f"missing advisory subject: {path}"
        assert sha256(path) == subject["sha256"], f"stale advisory subject: {path}"

    manifest_path = ROOT / receipt["subjects"]["manifest"]["path"]
    lock_path = ROOT / receipt["subjects"]["lock"]["path"]
    manifest = load_json(manifest_path)
    lock = load_json(lock_path)
    direct = receipt["exactProvider"]["directPackages"]
    assert manifest["devDependencies"]["@wordpress/scripts"] == direct[
        "@wordpress/scripts"
    ]
    assert manifest["devDependencies"]["@wordpress/components"] == direct[
        "@wordpress/components"
    ]
    assert lock["packages"][""]["devDependencies"] == manifest["devDependencies"]
    for package, version in direct.items():
        assert lock["packages"][f"node_modules/{package}"]["version"] == version

    audit = receipt["auditSnapshot"]
    assert audit["criticalCount"] == 0
    assert sum(
        audit["packageNodeCounts"][severity]
        for severity in ("info", "low", "moderate", "high", "critical")
    ) == audit["packageNodeCount"]
    assert audit["packageNodeCounts"]["total"] == audit["packageNodeCount"]
    assert len(audit["advisories"]) == audit["uniqueAdvisoryCount"]

    advisory_ids = set(audit["advisories"])
    classified_ids: set[str] = set()
    for classification in receipt["reachabilityClassifications"]:
        assert classification["advisoryIds"], "empty advisory classification"
        assert classification["executionScope"]
        assert classification["mitigation"]
        for advisory_id in classification["advisoryIds"]:
            assert advisory_id not in classified_ids, (
                f"advisory classified more than once: {advisory_id}"
            )
            classified_ids.add(advisory_id)
    assert classified_ids == advisory_ids, (
        f"unclassified advisories: {sorted(advisory_ids - classified_ids)}; "
        f"unknown classifications: {sorted(classified_ids - advisory_ids)}"
    )

    for advisory_id, advisory in audit["advisories"].items():
        assert advisory_id.startswith("GHSA-")
        assert advisory["url"] == (
            f"https://github.com/advisories/{advisory_id.lower()}"
        )
        assert advisory["severity"] in SEVERITY

    candidate = receipt["officialWp70PatchCandidate"]
    assert candidate["registryTags"] == {
        "@wordpress/scripts": "31.5.1",
        "@wordpress/components": "32.2.1",
    }
    assert candidate["auditResult"]["uniqueAdvisoryCount"] == (
        audit["uniqueAdvisoryCount"]
    )
    assert candidate["auditResult"]["packageNodeCounts"] == (
        audit["packageNodeCounts"]
    )
    assert candidate["exactContainerTest"]["node"] == receipt["exactProvider"]["node"]
    assert candidate["exactContainerTest"]["npm"] == receipt["exactProvider"]["npm"]
    assert candidate["exactContainerTest"]["image"] == receipt["exactProvider"][
        "nodeImage"
    ]
    assert candidate["exactContainerTest"]["user"] == "node"
    assert candidate["exactContainerTest"]["installCommand"] == (
        "npm ci --ignore-scripts --no-audit --no-fund"
    )
    assert candidate["exactContainerTest"]["installedPackageCount"] > 0
    assert candidate["exactContainerTest"]["outcome"] == (
        "passed-no-advisory-reduction"
    )
    assert candidate["decision"] == "not-admitted-no-advisory-reduction"

    mitigations = receipt["buildBoundary"]
    assert mitigations["installCommand"] == (
        "npm ci --ignore-scripts --no-audit --no-fund"
    )
    assert mitigations["lifecycleScriptsAllowed"] is False
    assert mitigations["untrustedBuildInputsAllowed"] is False
    assert mitigations["devServerStarted"] is False
    assert mitigations["nodeModulesShipped"] is False
    assert mitigations["publicationAuthorized"] is False


def run_live_audit(receipt: dict) -> None:
    tooling_dir = ROOT / "packages/gutenberg/build-tooling"
    result = subprocess.run(
        ["npm", "audit", "--json"],
        cwd=tooling_dir,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode in {0, 1}, (
        f"npm audit failed with {result.returncode}: {result.stderr.strip()}"
    )
    report = json.loads(result.stdout)
    metadata = report["metadata"]["vulnerabilities"]
    assert metadata["critical"] == 0, "live audit introduced a critical finding"

    observed: dict[str, str] = {}
    direct_packages: set[str] = set()
    for package_name, vulnerability in report["vulnerabilities"].items():
        if vulnerability["isDirect"]:
            direct_packages.add(package_name)
        for via in vulnerability["via"]:
            if not isinstance(via, dict):
                continue
            advisory_id = ghsa_id(via["url"])
            severity = via["severity"]
            previous = observed.get(advisory_id)
            if previous is None or SEVERITY[severity] > SEVERITY[previous]:
                observed[advisory_id] = severity

    snapshot = receipt["auditSnapshot"]
    allowed = snapshot["advisories"]
    unknown = sorted(set(observed) - set(allowed))
    assert not unknown, f"live audit contains unclassified advisories: {unknown}"
    escalated = sorted(
        advisory_id
        for advisory_id, severity in observed.items()
        if SEVERITY[severity] > SEVERITY[allowed[advisory_id]["severity"]]
    )
    assert not escalated, f"live advisory severity increased: {escalated}"
    allowed_direct = set(snapshot["directVulnerablePackages"])
    assert direct_packages <= allowed_direct, (
        f"live audit contains new direct vulnerable packages: "
        f"{sorted(direct_packages - allowed_direct)}"
    )
    print(
        json.dumps(
            {
                "receiptId": receipt["receiptId"],
                "liveAudit": "passed",
                "packageNodeCounts": metadata,
                "observedAdvisoryIds": sorted(observed),
                "retiredSinceSnapshot": sorted(set(allowed) - set(observed)),
            },
            indent=2,
            sort_keys=True,
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--live",
        action="store_true",
        help="query npm and reject new or severity-escalated advisories",
    )
    args = parser.parse_args()

    receipt = load_json(RECEIPT_PATH)
    verify_receipt(receipt)
    if args.live:
        run_live_audit(receipt)
    else:
        print("G2.3 frozen build-tool advisory receipt passed")


if __name__ == "__main__":
    main()
