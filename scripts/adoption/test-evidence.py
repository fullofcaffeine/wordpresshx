#!/usr/bin/env python3
"""Regression checks for ADR-015 identity refresh and local pass minting."""

from __future__ import annotations

import copy
from pathlib import Path

from evidence_state import pending_local_state, record_local_pass, refresh_local_state


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
    print("ADR-015 evidence state rejected stale and incomplete local passes")


if __name__ == "__main__":
    main()
