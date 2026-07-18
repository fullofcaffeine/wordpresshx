#!/usr/bin/env python3
"""Verify the exact SDK-035 same-source Genes differential profile."""

from __future__ import annotations

import json
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def hxml_lines(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def main() -> None:
    expected = load_json(PACKAGE_ROOT / "test/expected/differential.json")
    dependency_lock = load_json(PACKAGE_ROOT / "dependency-lock.json")
    browser_profile = load_json(
        PACKAGE_ROOT
        / "src/wordpress/hx/gutenberg/profile/wp70-release.browser-hxx.json"
    )
    architecture = load_json(
        REPOSITORY_ROOT / "manifests/browser-build-architecture.json"
    )
    tooling = load_json(PACKAGE_ROOT / "hxx-tooling/package.json")
    tooling_lock = load_json(PACKAGE_ROOT / "hxx-tooling/package-lock.json")

    assert expected["schemaVersion"] == 1
    assert expected["fixtureId"] == (
        "wordpresshx-sdk035-classic-genes-differential-v1"
    )
    assert expected["profileId"] == "wp70-release"
    assert expected["compilerProvenance"] == {
        "name": "genes-ts",
        "version": "1.36.3",
        "commit": "c59ecb361fd91418584487c2138bae8d3d3a3961",
        "referenceFixture": {
            "path": "tests/genes-ts/snapshot/react/src/DualJsxMain.hx",
            "blob": "eb27affc2acea430120308cd262a4d31b0ac4edb",
            "sha256": (
                "4d49ecde37d13de4b76c52f20e3e5c8e"
                "f81739f680da5f42bc0d3d9c5e147184"
            ),
            "relationship": "concept-reference-only-no-copied-bytes",
            "buildInput": False,
        },
        "wordpressSpecificGenesChange": False,
        "genesPullRequest": None,
    }
    compiler = dependency_lock["compiler"]
    assert compiler["name"] == expected["compilerProvenance"]["name"]
    assert compiler["version"] == expected["compilerProvenance"]["version"]
    assert compiler["commit"] == expected["compilerProvenance"]["commit"]
    assert dependency_lock["policy"]["mutableSiblingCheckoutAllowed"] is False
    assert dependency_lock["policy"]["wordpressSpecificGenesPatchAllowed"] is False
    genes_hxml = (PACKAGE_ROOT / "haxe_libraries/genes-ts.hxml").read_text(
        encoding="utf-8"
    )
    assert compiler["commit"] in genes_hxml
    assert "../genes" not in genes_hxml
    assert "=dev" not in genes_hxml

    common = hxml_lines(PACKAGE_ROOT / "profiles/differential-common.hxml")
    strict = hxml_lines(PACKAGE_ROOT / "profiles/differential-strict.hxml")
    classic = hxml_lines(PACKAGE_ROOT / "profiles/differential-classic.hxml")
    assert common == [
        "-lib genes-ts",
        "-lib tink_hxx",
        "-cp ../hxx/src",
        "-cp src",
        "-cp test/differential-fixture/src",
        "-main sdk035.fixture.Main",
        "-D wordpress_hx_profile=wp70-release",
        "-D wordpress_hx_browser_hxx",
        "-D genes.react.no_inline_markup",
        "-D genes.library",
        "-D js-es=6",
        "-dce full",
        "--macro wordpress.hx.gutenberg.hxx.BrowserHxx.enable()",
        "--macro include('sdk035.fixture')",
    ]
    assert strict == [
        "profiles/differential-common.hxml",
        "-D genes.ts",
        "-D genes.ts.no_extension",
    ]
    assert classic == [
        "profiles/differential-common.hxml",
        "-D dts",
        "-D genes.no_extension",
    ]
    joined_profiles = "\n".join(common + strict + classic)
    assert "genes.react.inline_markup" not in joined_profiles
    assert "../genes" not in joined_profiles

    assert browser_profile["profileId"] == expected["profileId"]
    assert browser_profile["react"] == {
        "runtimeVersion": "18.3.1",
        "typesVersion": "18.3.27",
        "jsxRuntimeRequest": "react/jsx-runtime",
        "wordpressHandle": "react-jsx-runtime",
    }
    assert browser_profile["policy"]["rawJsxAllowed"] is False
    assert browser_profile["policy"]["browserHxxRuntimeAllowed"] is False

    assert tooling["engines"] == {"node": "22.17.0", "npm": "10.9.2"}
    assert tooling["packageManager"] == "npm@10.9.2"
    for package_name, version in {
        "@types/react": "18.3.27",
        "@types/react-dom": "18.3.7",
        "@wordpress/element": "6.40.0",
        "esbuild": "0.27.2",
        "jsdom": "26.1.0",
        "react": "18.3.1",
        "react-dom": "18.3.1",
        "typescript": "5.9.3",
    }.items():
        assert tooling["devDependencies"][package_name] == version
        assert (
            tooling_lock["packages"][f"node_modules/{package_name}"]["version"]
            == version
        )

    primary = architecture["sourceOutput"]["primary"]
    differential = architecture["sourceOutput"]["classicDifferential"]
    assert primary["id"] == "strict-typescript-source"
    assert primary["status"] == "primary-development-and-production-input"
    assert differential["id"] == "classic-genes-esm"
    assert differential["status"] == (
        "representative-differential-not-default-production-fallback"
    )
    assert differential["comparison"] == (
        "observable-runtime-and-public-contract-not-textual-output"
    )
    assert differential["coveragePolicy"] == (
        "bounded-explicit-corpus-no-universal-mode-switch-claim"
    )
    assert differential["sdkHxxProjection"] == {
        "profileFiles": [
            "packages/gutenberg/profiles/differential-common.hxml",
            "packages/gutenberg/profiles/differential-strict.hxml",
            "packages/gutenberg/profiles/differential-classic.hxml",
        ],
        "compileTimeMarkupOwner": "wordpresshx-sdk-032-browser-hxx",
        "genesIntentContract": "generic-react-jsx-plan",
        "genesInlineMarkupParserEnabled": False,
        "define": "genes.react.no_inline_markup",
        "reason": (
            "the SDK parser has already lowered HXX to typed Genes intent, so a "
            "second source parser would be ambiguous"
        ),
    }

    fixture = (
        PACKAGE_ROOT
        / "test/differential-fixture/src/sdk035/fixture/DifferentialApi.hx"
    ).read_text(encoding="utf-8")
    consumer = (PACKAGE_ROOT / "test/differential-consumer/consumer.ts").read_text(
        encoding="utf-8"
    )
    runner = (PACKAGE_ROOT / "test/differential-runtime/run.mjs").read_text(
        encoding="utf-8"
    )
    assert "return <section" in fixture
    assert "BrowserHxx.lower" not in fixture
    assert "useState(props.initial)" in fixture
    assert "DifferentialApi.Counter" in consumer
    assert 'dispatchEvent(new dom.window.MouseEvent("click"' in runner
    assert expected["targetShape"]["unexplainedSemanticDifferenceCount"] == 0
    assert expected["publicContract"]["unexplainedContractDifferenceCount"] == 0

    print("SDK-035 exact same-source Genes differential profile passed")


if __name__ == "__main__":
    main()
