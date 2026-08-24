#!/usr/bin/env python3
"""Independently verify the complete SDK-055 translation artifact."""

from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from pathlib import Path


EXPECTED = {
    "books.count": {
        "comment": "Number of books in the current result.",
        "context": None,
        "kind": "plural-count",
        "line": 30,
        "singular": "%1$d book",
        "plural": "%1$d books",
        "translations": ["%1$d libro", "%1$d libros"],
    },
    "books.open-action": {
        "comment": "Button label that opens one book.",
        "context": "verb",
        "kind": "text",
        "line": 15,
        "singular": "Open",
        "plural": None,
        "translations": ["Abrir"],
    },
    "books.open-title": {
        "comment": "Button label. The placeholder is a book title.",
        "context": None,
        "kind": "string-placeholder",
        "line": 23,
        "singular": "Open %1$s",
        "plural": None,
        "translations": ["Abrir %1$s"],
    },
    "books.ready": {
        "comment": "Shown when the books interface has finished loading.",
        "context": None,
        "kind": "text",
        "line": 8,
        "singular": "Library ready.",
        "plural": None,
        "translations": ["Biblioteca lista."],
    },
    "books.shelf-count": {
        "comment": "Number of books stored on one shelf.",
        "context": "inventory noun",
        "kind": "plural-count",
        "line": 38,
        "singular": "%1$d shelf item",
        "plural": "%1$d shelf items",
        "translations": [
            "%1$d elemento de estante",
            "%1$d elementos de estante",
        ],
    },
}

DOMAIN = "wordpresshx-sdk055"
HANDLE = "wordpresshx-sdk055-messages"
LOCALE = "es_MX"
PLURAL_FORMS = "nplurals=2; plural=(n != 1);"
SOURCE = "test/i18n-fixture/src/sdk055/fixture/BooksCatalog.hx"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gettext_key(record: dict[str, object]) -> str:
    context = record["context"]
    singular = record["singular"]
    assert isinstance(singular, str)
    return f"{context}\x04{singular}" if isinstance(context, str) else singular


def parse_pot(path: Path) -> dict[str, dict[str, object]]:
    records: dict[str, dict[str, object]] = {}
    for block in path.read_text(encoding="utf-8").strip().split("\n\n")[1:]:
        lines = block.splitlines()
        comment = next(
            line.removeprefix("#. translators: ")
            for line in lines
            if line.startswith("#. translators: ")
        )
        source = next(
            line.removeprefix("#: ") for line in lines if line.startswith("#: ")
        )
        context_line = next(
            (line.removeprefix("msgctxt ") for line in lines if line.startswith("msgctxt ")),
            None,
        )
        msgid_line = next(
            line.removeprefix("msgid ") for line in lines if line.startswith("msgid ")
        )
        plural_line = next(
            (
                line.removeprefix("msgid_plural ")
                for line in lines
                if line.startswith("msgid_plural ")
            ),
            None,
        )
        context = json.loads(context_line) if context_line is not None else None
        singular = json.loads(msgid_line)
        plural = json.loads(plural_line) if plural_line is not None else None
        key = f"{context}\x04{singular}" if context is not None else singular
        records[key] = {
            "comment": comment,
            "context": context,
            "plural": plural,
            "singular": singular,
            "source": source,
        }
    return records


def parse_mo(path: Path) -> dict[str, str]:
    data = path.read_bytes()
    assert len(data) >= 28
    magic, revision, count, originals_offset, translations_offset, hash_size, hash_offset = struct.unpack_from(
        "<7I", data, 0
    )
    assert magic == 0x950412DE
    assert revision == 0 and count == 6 and hash_size == 0 and hash_offset == 0
    result: dict[str, str] = {}
    for index in range(count):
        original_length, original_offset = struct.unpack_from(
            "<2I", data, originals_offset + index * 8
        )
        translated_length, translated_offset = struct.unpack_from(
            "<2I", data, translations_offset + index * 8
        )
        original = data[original_offset : original_offset + original_length].decode("utf-8")
        translated = data[
            translated_offset : translated_offset + translated_length
        ].decode("utf-8")
        assert data[original_offset + original_length] == 0
        assert data[translated_offset + translated_length] == 0
        result[original] = translated
    return result


def expected_gettext() -> dict[str, dict[str, object]]:
    return {gettext_key(value): value for value in EXPECTED.values()}


def verify_manifest(root: Path) -> dict[str, object]:
    manifest_path = root / "wordpresshx-i18n-artifact.v1.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert set(manifest) == {
        "browser",
        "claims",
        "files",
        "locale",
        "manifestId",
        "messages",
        "plugin",
        "profileId",
        "provenance",
        "schemaVersion",
        "sources",
    }
    assert manifest["schemaVersion"] == 1
    assert manifest["manifestId"] == "wordpresshx-i18n-artifact-v1"
    assert manifest["profileId"] == "wp70-release"
    assert manifest["plugin"] == {
        "rootPath": f"{DOMAIN}.php",
        "slug": DOMAIN,
        "textDomain": DOMAIN,
    }
    browser = manifest["browser"]
    assert browser["handle"] == HANDLE
    assert browser["dependencies"] == ["wp-i18n"]
    assert browser["hooks"] == [
        "enqueue_block_editor_assets",
        "wp_enqueue_scripts",
    ]
    assert re.fullmatch(r"[0-9a-f]{20}", browser["version"])
    assert re.fullmatch(r"[0-9a-f]{64}", browser["bundleSha256"])
    assert manifest["locale"] == {"id": LOCALE, "pluralForms": PLURAL_FORMS}
    assert manifest["provenance"] == {
        "externalMessagesAllowed": False,
        "extraction": "byte-linked-deterministic-surrogate",
        "sourceBytesRequired": True,
    }
    assert manifest["claims"] == {
        "editorRuntime": "not-tested",
        "frontendRuntime": "not-tested",
        "generation": "generated",
        "phpRuntime": "not-tested",
        "publicationAuthorized": False,
    }

    files = {record["path"]: record for record in manifest["files"]}
    assert len(files) == 8
    for relative, record in files.items():
        path = root / relative
        assert path.is_file()
        assert record["bytes"] == path.stat().st_size
        assert record["sha256"] == digest(path)
        assert record["classification"] == "public-native"
    assert files["build/messages.js"]["sha256"] == browser["bundleSha256"]

    package_root = Path(__file__).resolve().parent.parent
    source_records = manifest["sources"]
    assert len(source_records) == 1 and source_records[0]["path"] == SOURCE
    source_path = package_root / SOURCE
    assert source_records[0]["bytes"] == source_path.stat().st_size
    assert source_records[0]["sha256"] == digest(source_path)

    messages = {record["key"]: record for record in manifest["messages"]}
    assert set(messages) == set(EXPECTED)
    for key, expected in EXPECTED.items():
        assert messages[key] == {
            "comment": expected["comment"],
            "context": expected["context"],
            "domain": DOMAIN,
            "key": key,
            "kind": expected["kind"],
            "source": {"file": SOURCE, "line": expected["line"]},
        }
    return manifest


def verify_gettext(root: Path) -> None:
    expected = expected_gettext()
    pot = parse_pot(root / "languages" / f"{DOMAIN}.pot")
    assert set(pot) == set(expected)
    for key, record in expected.items():
        assert pot[key] == {
            "comment": record["comment"],
            "context": record["context"],
            "plural": record["plural"],
            "singular": record["singular"],
            "source": f"{SOURCE}:{record['line']}",
        }

    jed_path = root / "languages" / f"{DOMAIN}-{LOCALE}-{HANDLE}.json"
    jed = json.loads(jed_path.read_text(encoding="utf-8"))
    locale_data = jed["locale_data"][DOMAIN]
    assert locale_data[""] == {
        "domain": DOMAIN,
        "lang": LOCALE,
        "plural-forms": PLURAL_FORMS,
    }
    assert set(locale_data) == {"", *expected.keys()}
    for key, record in expected.items():
        assert locale_data[key] == record["translations"]

    mo = parse_mo(root / "languages" / f"{DOMAIN}-{LOCALE}.mo")
    assert "Plural-Forms: " + PLURAL_FORMS in mo[""]
    assert "Language: " + LOCALE in mo[""]
    expected_mo = {"": mo[""]}
    for key, record in expected.items():
        original = key
        if record["plural"] is not None:
            original += "\x00" + record["plural"]
        expected_mo[original] = "\x00".join(record["translations"])
    assert mo == expected_mo


def verify_native_shapes(root: Path, manifest: dict[str, object]) -> None:
    plugin = (root / f"{DOMAIN}.php").read_text(encoding="utf-8")
    messages = (root / "includes" / "messages.php").read_text(encoding="utf-8")
    surrogate = (root / "languages" / f"{DOMAIN}.extraction.js").read_text(
        encoding="utf-8"
    )
    bundle = (root / "build" / "messages.js").read_text(encoding="utf-8")
    metadata = (root / "build" / "messages.asset.php").read_text(encoding="utf-8")

    assert plugin.count("wp_set_script_translations") == 1
    assert plugin.count(HANDLE) == 3
    assert "'enqueue_block_editor_assets'" in plugin
    assert "'wp_enqueue_scripts'" in plugin
    assert "load_plugin_textdomain" in plugin
    assert f"/{DOMAIN}-{LOCALE}.mo" not in plugin
    assert re.fullmatch(
        r"<\?php return array\('dependencies' => array\('wp-i18n'\), "
        r"'version' => '[0-9a-f]{20}'\);\n?",
        metadata,
    )
    assert "window.wp.i18n" in bundle
    for native_call in (".__)", "._x)", "._n)", "._nx)", ".sprintf)"):
        assert native_call in bundle
    assert digest(root / "build" / "messages.js") == manifest["browser"][
        "bundleSha256"
    ]

    for record in EXPECTED.values():
        assert f"translators: {record['comment']}" in messages
        assert f"translators: {record['comment']}" in surrogate
        assert json.dumps(record["singular"]) in surrogate
        if record["plural"] is not None:
            assert json.dumps(record["plural"]) in surrogate
    assert "\\__( 'Library ready.', 'wordpresshx-sdk055' )" in messages
    assert "\\_x( 'Open', 'verb', 'wordpresshx-sdk055' )" in messages
    assert "\\_n( '%1$d book', '%1$d books', $count" in messages
    assert "\\_nx( '%1$d shelf item', '%1$d shelf items', $count" in messages
    assert "\\sprintf( \\__( 'Open %1$s'" in messages
    assert "import { __, _n, _nx, _x } from '@wordpress/i18n';" in surrogate


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify-i18n.py <artifact-root>")
    root = Path(sys.argv[1]).resolve()
    assert root.is_dir()
    manifest = verify_manifest(root)
    verify_gettext(root)
    verify_native_shapes(root, manifest)
    print(
        json.dumps(
            {
                "artifactFiles": 8,
                "check": "wordpresshx-sdk055-i18n-artifact-v1",
                "locale": LOCALE,
                "messages": len(EXPECTED),
                "outcome": "passed",
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
