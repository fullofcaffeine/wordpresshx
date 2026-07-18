#!/usr/bin/env python3
"""Add the standard Node launcher line to one Genes-emitted ESM entry module."""

from __future__ import annotations

import sys
from pathlib import Path


SHEBANG = b"#!/usr/bin/env node\n"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: add-node-shebang.py <genes-entry.js>")
    path = Path(sys.argv[1])
    content = path.read_bytes()
    if content.startswith(SHEBANG):
        return
    if content.startswith(b"#!"):
        raise SystemExit(f"unexpected existing launcher in {path}")
    path.write_bytes(SHEBANG + content)
    path.chmod(path.stat().st_mode | 0o111)


if __name__ == "__main__":
    main()
