#!/usr/bin/env python3
"""Compile adversarial Haxe forms and reject their actual Genes output."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Probe:
    probe_id: str
    source: str
    accepted: bool = False


PROBES = (
    Probe(
        "safe",
        """package probe;
class Main {
  static function main():Void {
    final value = "safe";
    if (value.length == 0) return;
  }
}
""",
        accepted=True,
    ),
    Probe(
        "using-sys-command",
        """package probe;
using Sys;
class Main {
  static function main():Void {
    "printf".command(["owned"]);
  }
}
""",
    ),
    Probe(
        "using-syntax-code",
        """package probe;
using js.Syntax;
class Main {
  static function main():Void {
    "process.exit(91)".code();
  }
}
""",
    ),
    Probe(
        "typedef-syntax-code",
        """package probe;
private typedef Escape = js.Syntax;
class Main {
  static function main():Void {
    Escape.code("process.exit(91)");
  }
}
""",
    ),
    Probe(
        "wildcard-syntax-code",
        """package probe;
import js.*;
class Main {
  static function main():Void {
    Syntax.code("process.exit(91)");
  }
}
""",
    ),
    Probe(
        "interpolated-sys-command",
        """package probe;
class Main {
  static function main():Void {
    final value = '${Sys.command("printf", ["owned"])}';
    if (value.length == 0) throw "impossible";
  }
}
""",
    ),
    Probe(
        "untyped-process",
        """package probe;
class Main {
  static function main():Void {
    untyped process.exit(91);
  }
}
""",
    ),
    Probe(
        "untyped-require",
        """package probe;
class Main {
  static function main():Void {
    final child = untyped require("child_process");
    if (child == null) throw "missing";
  }
}
""",
    ),
    Probe(
        "escaped-process-identifier",
        """package probe;
import js.Syntax;
class Main {
  static function main():Void {
    Syntax.code("proc\\\\u0065ss.exit(91)");
  }
}
""",
    ),
    Probe(
        "escaped-require-identifier",
        """package probe;
import js.Syntax;
class Main {
  static function main():Void {
    Syntax.code("requ\\\\u0069re('child_process')");
  }
}
""",
    ),
    Probe(
        "node-process-method-reference",
        """package probe;
import wordpresshx.cli.NodeGlobals;
class Main {
  static function main():Void {
    final getProcess = NodeGlobals.process;
    getProcess().exit(91);
  }
}
""",
    ),
    Probe(
        "node-process-import-alias",
        """package probe;
import wordpresshx.cli.NodeGlobals.process as getProcess;
class Main {
  static function main():Void {
    getProcess().exit(91);
  }
}
""",
    ),
)


def parse_arguments(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--haxe", type=Path, required=True)
    parser.add_argument("--package-root", type=Path, required=True)
    parser.add_argument("--temporary-root", type=Path, required=True)
    return parser.parse_args(arguments)


def run_checked(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        rendered = " ".join(command)
        raise RuntimeError(
            f"command failed ({completed.returncode}): {rendered}\n"
            f"{completed.stdout}{completed.stderr}"
        )
    return completed


def compile_probe(
    probe: Probe, haxe: Path, package_root: Path, temporary_root: Path
) -> tuple[Path, Path, Path]:
    probe_root = temporary_root / probe.probe_id
    source_root = probe_root / "src"
    entry_root = source_root / "probe"
    entry_root.mkdir(parents=True)
    (entry_root / "Main.hx").write_text(probe.source, encoding="utf-8")
    javascript_root = probe_root / "runtime"
    dump_root = probe_root / "compiler-dump"
    run_checked(
        [
            str(haxe),
            "-lib",
            "genes-ts",
            "-lib",
            "hxnodejs",
            "-cp",
            "src",
            "-cp",
            str(source_root),
            "-main",
            "probe.Main",
            "-D",
            "js-es=6",
            "-dce",
            "full",
            "-js",
            str(javascript_root / "index.js"),
            "-D",
            "dump=record",
            "-D",
            "dump-dependencies",
            "-D",
            f"dump-path={dump_root}",
        ],
        package_root,
    )
    return source_root, entry_root, javascript_root


def check_probe(
    probe: Probe,
    repository_root: Path,
    source_root: Path,
    entry_root: Path,
    javascript_root: Path,
) -> None:
    dependency_dump = (
        javascript_root.parent / "compiler-dump" / "js" / "dependencies.dump"
    )
    command = [
        sys.executable,
        str(repository_root / "scripts/ownership/check-isolation.py"),
        "--emitted-only",
        "--source-root",
        str(source_root),
        "--entry-root",
        str(entry_root),
        "--dependencies",
        str(dependency_dump),
        "--javascript-root",
        str(javascript_root),
    ]
    completed = subprocess.run(
        command,
        cwd=repository_root,
        text=True,
        capture_output=True,
        check=False,
    )
    expected = 0 if probe.accepted else 2
    if completed.returncode != expected:
        raise RuntimeError(
            f"emitted probe {probe.probe_id} returned {completed.returncode}, "
            f"expected {expected}\n{completed.stdout}{completed.stderr}"
        )


def check_out_of_root_dependency(
    haxe: Path, package_root: Path, temporary_root: Path
) -> None:
    probe_root = temporary_root / "out-of-root-dependency"
    source_root = probe_root / "production"
    entry_root = source_root / "probe"
    helper_root = probe_root / "test"
    helper_package = helper_root / "evil"
    entry_root.mkdir(parents=True)
    helper_package.mkdir(parents=True)
    main_path = entry_root / "Main.hx"
    main_path.write_text(
        "package probe;\n"
        "import evil.Helper;\n"
        "class Main { static function main():Void { Helper.run(); } }\n",
        encoding="utf-8",
    )
    (helper_package / "Helper.hx").write_text(
        "package evil;\n"
        "import js.Syntax;\n"
        "class Helper { public static function run():Void { "
        'Syntax.code("process.exit(91)"); } }\n',
        encoding="utf-8",
    )
    javascript_root = probe_root / "runtime"
    dump_root = probe_root / "compiler-dump"
    run_checked(
        [
            str(haxe),
            "-lib",
            "genes-ts",
            "-lib",
            "hxnodejs",
            "-cp",
            "src",
            "-cp",
            str(source_root),
            "-cp",
            str(helper_root),
            "-main",
            "probe.Main",
            "-D",
            "js-es=6",
            "-dce",
            "full",
            "-js",
            str(javascript_root / "index.js"),
            "-D",
            "dump=record",
            "-D",
            "dump-dependencies",
            "-D",
            f"dump-path={dump_root}",
        ],
        package_root,
    )
    relative_main = main_path.relative_to(probe_root).as_posix()
    receipt = probe_root / "receipt.json"
    receipt.write_text(
        json.dumps(
            {
                "productionClosureSubjects": ["main"],
                "subject": {
                    "main": {
                        "path": relative_main,
                        "sha256": hashlib.sha256(main_path.read_bytes()).hexdigest(),
                    }
                },
            },
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    completed = subprocess.run(
        [
            sys.executable,
            str(
                package_root.parent.parent
                / "scripts/ownership/check-isolation.py"
            ),
            "--source-root",
            str(source_root),
            "--entry-root",
            str(entry_root),
            "--dependencies",
            str(dump_root / "js" / "dependencies.dump"),
            "--javascript-root",
            str(javascript_root),
            "--receipt",
            str(receipt),
            "--repository-root",
            str(probe_root),
        ],
        cwd=package_root.parent.parent,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 3 or "outside the production root" not in (
        completed.stdout + completed.stderr
    ):
        raise RuntimeError(
            "out-of-root compiler dependency was not rejected\n"
            f"{completed.stdout}{completed.stderr}"
        )


def main(arguments: list[str]) -> int:
    parsed = parse_arguments(arguments)
    package_root = parsed.package_root.resolve()
    repository_root = package_root.parent.parent
    temporary_root = parsed.temporary_root.resolve()
    temporary_root.mkdir(parents=True, exist_ok=True)
    for probe in PROBES:
        source_root, entry_root, javascript_root = compile_probe(
            probe,
            parsed.haxe.resolve(),
            package_root,
            temporary_root,
        )
        check_probe(
            probe,
            repository_root,
            source_root,
            entry_root,
            javascript_root,
        )
    check_out_of_root_dependency(
        parsed.haxe.resolve(), package_root, temporary_root
    )
    print(
        "[ownership-isolation] One safe and "
        f"{len(PROBES) - 1} compile-confirmed emitted capability probes passed."
    )
    print(
        "[ownership-isolation] One compile-confirmed out-of-root dependency "
        "probe passed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
