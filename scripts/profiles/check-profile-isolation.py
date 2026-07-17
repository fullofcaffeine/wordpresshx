#!/usr/bin/env python3
"""Prove exact-profile compile admission and final-artifact isolation."""

from __future__ import annotations

import json
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
DECISION_LOCK_PATH = ROOT / "profiles" / "decision-lock.json"
PROFILE_LOCK_PATHS = {
    "wp70-release": ROOT / "profiles" / "wp70-release" / "source.lock.json",
    "gutenberg-forward-23.4": (
        ROOT
        / "profiles"
        / "gutenberg-forward-23.4"
        / "source.lock.json"
    ),
}
WP70_ARTIFACT_IDENTITY = {
    "packageIdentity": "wordpress-hx-profile:wp70-release/catalog-v1",
    "generatedNamespace": "wordpress.profiles.wp70_release",
    "generatedArtifactRoot": "generated/wp70-release/catalog-v1",
}


class ProfileIsolationError(ValueError):
    pass


@dataclass(frozen=True)
class ImportRequest:
    name: str
    available_in: frozenset[str]


WP70_ONLY = ImportRequest(
    "wordpress.wp70.profile_marker", frozenset({"wp70-release"})
)
FORWARD_CONTENT_TYPES = ImportRequest(
    "@wordpress/content-types", frozenset({"gutenberg-forward-23.4"})
)
SHARED_BLOCKS = ImportRequest(
    "wordpress.blocks.shared", frozenset(PROFILE_LOCK_PATHS)
)


def compile_profile_manifest(
    decision: dict[str, object],
    profile_locks: dict[str, dict[str, object]],
    selections: list[str],
    imports: list[ImportRequest],
) -> dict[str, object]:
    if len(selections) != 1:
        raise ProfileIsolationError(
            "compile admission requires exactly one compatibility profile"
        )
    profile_id = selections[0]
    if profile_id not in profile_locks:
        raise ProfileIsolationError(f"unknown compatibility profile: {profile_id}")
    for requested in imports:
        if profile_id not in requested.available_in:
            raise ProfileIsolationError(
                f"{requested.name} is unavailable in {profile_id}"
            )

    profile = profile_locks[profile_id]
    decision_profile = decision["profiles"][profile_id]
    if profile["catalogRevision"] != decision_profile["catalogRevision"]:
        raise ProfileIsolationError("profile catalog identity drift")
    identity = (
        WP70_ARTIFACT_IDENTITY
        if profile_id == "wp70-release"
        else {
            field: profile[field]
            for field in (
                "packageIdentity",
                "generatedNamespace",
                "generatedArtifactRoot",
            )
        }
    )
    return {
        "schemaVersion": 1,
        "profileId": profile_id,
        "catalogRevision": profile["catalogRevision"],
        **identity,
        "imports": sorted(requested.name for requested in imports),
    }


def forbidden_markers(profile_id: str) -> tuple[str, ...]:
    if profile_id == "wp70-release":
        return (
            "gutenberg-forward-23.4",
            "gutenberg_forward_23_4",
            "@wordpress/content-types",
            "lib/experimental/content-types",
            "build/modules/content-types",
            "build/pages/content-types",
            "build/routes/content-types",
        )
    if profile_id == "gutenberg-forward-23.4":
        return (
            "wp70-release",
            "wp70_release",
            "wordpress.wp70.profile_marker",
        )
    raise ProfileIsolationError(f"unknown compatibility profile: {profile_id}")


def scan_final_artifact(
    artifact_root: Path,
    expected_manifest: dict[str, object],
) -> None:
    manifest_path = artifact_root / "profile-manifest.json"
    if not manifest_path.is_file():
        raise ProfileIsolationError("final artifact lacks profile-manifest.json")
    actual_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for field in (
        "profileId",
        "catalogRevision",
        "packageIdentity",
        "generatedNamespace",
        "generatedArtifactRoot",
    ):
        if actual_manifest.get(field) != expected_manifest[field]:
            raise ProfileIsolationError(f"final artifact {field} mismatch")

    markers = forbidden_markers(str(expected_manifest["profileId"]))
    for path in sorted(artifact_root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(artifact_root).as_posix()
        payload = path.read_bytes()
        for marker in markers:
            if marker in relative or marker.encode() in payload:
                raise ProfileIsolationError(
                    f"cross-profile marker in final artifact: {marker}"
                )


def write_artifact(
    root: Path,
    manifest: dict[str, object],
    files: dict[str, str],
) -> None:
    root.mkdir(parents=True, exist_ok=True)
    (root / "profile-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    for relative, content in files.items():
        destination = root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content, encoding="utf-8")


def expect_rejected(run: Callable[[], object], label: str) -> None:
    try:
        run()
    except ProfileIsolationError:
        return
    raise AssertionError(f"negative profile fixture did not fail closed: {label}")


def main() -> None:
    decision = json.loads(DECISION_LOCK_PATH.read_text(encoding="utf-8"))
    profile_locks = {
        profile_id: json.loads(path.read_text(encoding="utf-8"))
        for profile_id, path in PROFILE_LOCK_PATHS.items()
    }
    selection = decision["selectionPolicy"]
    assert selection["profilesArePeers"] is True
    assert selection["profileInheritance"] is False
    assert selection["exactlyOneCompatibilityTargetPerArtifact"] is True
    assert selection["combinedTargetAllowedDuringMvp"] is False
    assert selection["separatePackageGraphs"] is True
    assert selection["separateArtifactRoots"] is True

    forward = profile_locks["gutenberg-forward-23.4"]
    for profile_id, profile in profile_locks.items():
        assert profile["profileId"] == profile_id
        assert profile["catalogRevision"].startswith(f"{profile_id}/")
    for identity_field in (
        "packageIdentity",
        "generatedNamespace",
        "generatedArtifactRoot",
    ):
        assert WP70_ARTIFACT_IDENTITY[identity_field] != forward[identity_field]
    assert forward["wordpress70CompatibilityStatus"] == "forbidden"
    assert forward["supportStatus"] == "experimental"
    assert forward["releaseChannel"] == "preview-or-experimental"
    assert forward["prohibitions"]["mixedProfileImports"] == "forbidden"
    assert forward["prohibitions"]["wp70ArtifactLeakage"] == "forbidden"

    wp_manifest = compile_profile_manifest(
        decision, profile_locks, ["wp70-release"], [SHARED_BLOCKS, WP70_ONLY]
    )
    forward_manifest = compile_profile_manifest(
        decision,
        profile_locks,
        ["gutenberg-forward-23.4"],
        [SHARED_BLOCKS, FORWARD_CONTENT_TYPES],
    )

    expect_rejected(
        lambda: compile_profile_manifest(
            decision,
            profile_locks,
            ["wp70-release", "gutenberg-forward-23.4"],
            [SHARED_BLOCKS],
        ),
        "two selected profiles",
    )
    expect_rejected(
        lambda: compile_profile_manifest(
            decision,
            profile_locks,
            ["wp70-release"],
            [WP70_ONLY, FORWARD_CONTENT_TYPES],
        ),
        "mixed stable and forward imports under wp70-release",
    )
    expect_rejected(
        lambda: compile_profile_manifest(
            decision,
            profile_locks,
            ["gutenberg-forward-23.4"],
            [WP70_ONLY, FORWARD_CONTENT_TYPES],
        ),
        "mixed stable and forward imports under forward profile",
    )
    expect_rejected(
        lambda: compile_profile_manifest(
            decision, profile_locks, ["wordpress-latest"], [SHARED_BLOCKS]
        ),
        "unknown or floating profile",
    )

    with tempfile.TemporaryDirectory(prefix="wordpresshx-profile-isolation-") as tmp:
        root = Path(tmp)
        wp_artifact = root / "wp70"
        forward_artifact = root / "forward"
        write_artifact(
            wp_artifact,
            wp_manifest,
            {"src/WordPressBlocks.php": "<?php // wp70-release artifact\n"},
        )
        write_artifact(
            forward_artifact,
            forward_manifest,
            {
                "src/ContentTypes.php": (
                    "<?php // @wordpress/content-types forward artifact\n"
                )
            },
        )
        scan_final_artifact(wp_artifact, wp_manifest)
        scan_final_artifact(forward_artifact, forward_manifest)

        leaked_wp_artifact = root / "leaked-wp70"
        write_artifact(
            leaked_wp_artifact,
            wp_manifest,
            {
                "src/LeakedContentTypes.php": (
                    "<?php // @wordpress/content-types "
                    "lib/experimental/content-types\n"
                )
            },
        )
        expect_rejected(
            lambda: scan_final_artifact(leaked_wp_artifact, wp_manifest),
            "forward marker in wp70-release final artifact",
        )

        leaked_forward_artifact = root / "leaked-forward"
        write_artifact(
            leaked_forward_artifact,
            forward_manifest,
            {"src/Wp70Leak.php": "<?php // wp70-release\n"},
        )
        expect_rejected(
            lambda: scan_final_artifact(
                leaked_forward_artifact, forward_manifest
            ),
            "wp70 marker in forward final artifact",
        )

        drifted_manifest = dict(forward_manifest)
        drifted_manifest["generatedArtifactRoot"] = wp_manifest[
            "generatedArtifactRoot"
        ]
        drifted_artifact = root / "drifted-forward"
        write_artifact(drifted_artifact, drifted_manifest, {})
        expect_rejected(
            lambda: scan_final_artifact(drifted_artifact, forward_manifest),
            "forward final artifact claims stable root",
        )

    print(
        "exact-profile compile admission and final-artifact isolation passed"
    )


if __name__ == "__main__":
    main()
