#!/usr/bin/env python3
"""Regression checks for ADR-015 identity refresh and local pass minting."""

from __future__ import annotations

import copy
import shutil
import tempfile
from pathlib import Path

from evidence_state import (
    evidence_subject_paths,
    evidence_subject_sha256,
    pending_local_state,
    record_local_pass,
    refresh_local_state,
)


ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    pending = pending_local_state(ROOT)
    stale = copy.deepcopy(pending)
    stale["contentRoot"] = "0" * 64
    stale["outcome"] = "passed"
    stale["observedAt"] = "2026-01-01T00:00:00Z"
    for observer in stale["observers"]:
        observer["outcome"] = "passed"
    try:
        refresh_local_state(ROOT, stale, reset_stale_pass=False)
    except ValueError as error:
        if "refuses to retain" not in str(error):
            raise
    else:
        raise AssertionError("identity-only refresh retained a stale local pass")
    reset = refresh_local_state(ROOT, stale, reset_stale_pass=True)
    if reset["outcome"] != "pending" or reset["observedAt"] is not None:
        raise AssertionError("identity refresh did not reset a stale local pass")
    stale_subject = copy.deepcopy(pending)
    stale_subject["evidenceSubjectSha256"] = "0" * 64
    stale_subject["outcome"] = "passed"
    stale_subject["observedAt"] = "2026-01-01T00:00:00Z"
    for observer in stale_subject["observers"]:
        observer["outcome"] = "passed"
    reset_subject = refresh_local_state(
        ROOT, stale_subject, reset_stale_pass=True
    )
    if reset_subject["outcome"] != "pending":
        raise AssertionError("evidence-subject mismatch did not reset a local pass")
    stale_python = copy.deepcopy(pending)
    stale_python["pythonRuntime"]["version"] = "0.0.0"
    stale_python["outcome"] = "passed"
    stale_python["observedAt"] = "2026-01-01T00:00:00Z"
    for observer in stale_python["observers"]:
        observer["outcome"] = "passed"
    reset_python = refresh_local_state(ROOT, stale_python, reset_stale_pass=True)
    if reset_python["outcome"] != "pending":
        raise AssertionError("Python-runtime mismatch did not reset a local pass")
    incomplete = copy.deepcopy(pending)
    incomplete["observedAt"] = "2026-01-01T00:00:00Z"
    incomplete["observers"] = incomplete["observers"][:-1]
    try:
        record_local_pass(ROOT, incomplete)
    except ValueError:
        pass
    else:
        raise AssertionError("local pass minted without every exact observer")
    complete = copy.deepcopy(pending)
    complete["observedAt"] = "2026-01-01T00:00:00Z"
    complete["outcome"] = "passed"
    for observer in complete["observers"]:
        observer["outcome"] = "passed"
    if record_local_pass(ROOT, complete)["outcome"] != "passed":
        raise AssertionError("complete same-root observer record did not mint a pass")
    container = pending_local_state(ROOT, "container")
    container["observedAt"] = "2026-01-01T00:00:00Z"
    container["outcome"] = "passed"
    for observer in container["observers"]:
        observer["outcome"] = "passed"
    if record_local_pass(ROOT, container, "container")["executionMode"] != "container":
        raise AssertionError("container observer record lost its execution mode")
    try:
        record_local_pass(ROOT, container, "local")
    except ValueError:
        pass
    else:
        raise AssertionError("container evidence minted a local-runtime pass")

    baseline_subject = evidence_subject_sha256(ROOT)
    subject_mutations = {
        "provider-input": "fixtures/adoption-contract/inputs/plugin.php",
        "schema": "schemas/adoption-contract.schema.json",
        "abi-model": "scripts/adoption/abi_model.py",
        "generator": "scripts/adoption/generate-fixture.py",
        "authored-haxe": "fixtures/adoption-contract/src/wordpress/hx/adoption/prototype/Adoption.hx",
        "generated-member": "fixtures/adoption-contract/contract/generated/adoption/acme-calendar/contract.json",
        "bundle": "fixtures/adoption-contract/contract/acme-calendar.bundle.json",
        "runtime-anchor": "fixtures/adoption-contract/contract/generated/adoption/acme-calendar/php/acme-calendar-facade.php",
        "ownership-manifest": "fixtures/adoption-contract/contract/acme-calendar.generated-files.json",
        "validator": "fixtures/adoption-contract/test-ownership/adoption/ownership/AdoptionBundleValidator.hx",
        "adversary": "scripts/adoption/test-ownership.py",
        "gate": "scripts/adoption/test.sh",
        "workflow": ".github/workflows/adoption-contract.yml",
        "repository-workflow": ".github/workflows/repository.yml",
        "repository-gate": "scripts/check-repository.sh",
        "lock": "packages/cli/dependency-lock.json",
        "python-lock": "manifests/adoption-contract-toolchain.lock.json",
    }
    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr015-subject-") as temporary:
        copy_root = Path(temporary)
        for relative in evidence_subject_paths(ROOT):
            destination = copy_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)
        for name, relative in subject_mutations.items():
            target = copy_root / relative
            original = target.read_bytes()
            target.write_bytes(original + f"\nsubject-mutation:{name}\n".encode("utf-8"))
            if evidence_subject_sha256(copy_root) == baseline_subject:
                raise AssertionError(f"evidence subject ignored {name}")
            target.write_bytes(original)

        workflow = copy_root / ".github/workflows/repository.yml"
        workflow_text = workflow.read_text(encoding="utf-8")
        python_step = """      - name: Install exact adoption evidence Python runtime
        uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0
        with:
          python-version: 3.14.5
"""
        repository_step = """      - name: Validate bootstrap repository
        run: bash scripts/check-repository.sh
"""
        repository_gate = copy_root / "scripts/check-repository.sh"
        repository_gate_text = repository_gate.read_text(encoding="utf-8")
        semantic_mutations = {
            "repository-python-order": (
                workflow,
                workflow_text.replace(
                    python_step + repository_step,
                    repository_step + python_step,
                    1,
                ),
            ),
            "repository-python-version": (
                workflow,
                workflow_text.replace("python-version: 3.14.5", "python-version: 3.14.4", 1),
            ),
            "repository-refresh-removal": (
                repository_gate,
                repository_gate_text.replace(
                    "python3 scripts/adoption/refresh-evidence.py\n", "", 1
                ),
            ),
            "repository-validation-removal": (
                repository_gate,
                repository_gate_text.replace(
                    "python3 scripts/adoption/validate-architecture.py\n", "", 1
                ),
            ),
            "repository-interpreter-drift": (
                repository_gate,
                repository_gate_text.replace(
                    "python3 scripts/adoption/refresh-evidence.py",
                    "python scripts/adoption/refresh-evidence.py",
                    1,
                ),
            ),
        }
        for name, (target, mutation) in semantic_mutations.items():
            original = target.read_text(encoding="utf-8")
            if mutation == original:
                raise AssertionError(f"evidence mutation did not alter {name}")
            target.write_text(mutation, encoding="utf-8")
            if evidence_subject_sha256(copy_root) == baseline_subject:
                raise AssertionError(f"evidence subject ignored {name}")
            target.write_text(original, encoding="utf-8")
    print(
        "ADR-015 evidence state rejected stale and incomplete passes and covered "
        "every authoritative subject class"
    )


if __name__ == "__main__":
    main()
