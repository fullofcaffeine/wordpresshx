#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

bash scripts/ownership/test-adr-contract.sh

for command_name in diff docker grep haxe haxelib lix node python3 realpath; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-041 production ownership gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-041 production ownership gate requires host Haxe 4.3.7" >&2
  exit 1
fi

lix_command="$(command -v lix)"
lix_bin_dir="$(cd "$(dirname "${lix_command}")" && pwd -P)"
lix_package_path="$(cd "$(dirname "$(realpath "${lix_command}")")/.." && pwd -P)/package.json"
lix_haxe="${lix_bin_dir}/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
  echo "SDK-041 production ownership gate requires Lix package 15.12.4 (CLI 15.12.2) and its Haxe shim" >&2
  exit 1
fi
if [[ "$(cd packages/cli && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-041 production ownership gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi

docker info >/dev/null
(
  cd packages/cli
  lix --silent download
)
haxelib run formatter --check \
  -s packages/cli/src/wordpresshx/cli/ownership \
  -s packages/cli/test/ownership/src

temporary_parent="$(python3 - <<'PY'
import os
import tempfile
print(os.path.realpath(tempfile.gettempdir()))
PY
)"
evidence_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk041-evidence.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk041-replay.XXXXXX")"
cleanup() {
  for temporary_root in "${evidence_root}" "${replay_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk041-*) rm -rf -- "${temporary_root}" ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
}
trap cleanup EXIT

(
  cd packages/cli
  "${lix_haxe}" profiles/ownership-test.hxml -js "${evidence_root}/runtime/index.js"
  "${lix_haxe}" profiles/ownership-test.hxml -js "${replay_root}/runtime/index.js"
)
diff -ru "${evidence_root}/runtime" "${replay_root}/runtime"

node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
docker run --rm --network none "${node_image}" node --version | grep -Fx 'v22.17.0' >/dev/null
python3 scripts/ownership/test-production.py "${evidence_root}/runtime"

scan_ownership_isolation() {
  python3 - "$@" <<'PY'
import pathlib
import re
import sys

allowed_node_references = {
    "js.node.Buffer",
    "js.node.Crypto",
    "js.node.Fs",
    "js.node.Path",
    "js.node.fs.Stats",
}
node_reference = re.compile(r"\bjs\.node(?:\.[A-Za-z_][A-Za-z0-9_]*)+\b")
forbidden_patterns = (
    ("process execution", re.compile(r"\b(?:Sys\.command|sys\.io\.Process)\b")),
    ("Node process global", re.compile(r"\bjs\.Node\.process\b")),
    ("raw Node require", re.compile(r"\bjs\.Lib\.require\s*\(|(?<![A-Za-z0-9_.])require\s*\(")),
    ("raw JavaScript syntax escape", re.compile(r"\bjs\.Syntax\.(?:code|plainCode)\s*\(")),
    ("native or module-loading metadata", re.compile(r"@:(?:jsRequire|native)\b")),
    ("local extern escape", re.compile(r"\bextern\s+(?:class|interface|abstract)\b")),
    ("browser network API", re.compile(r"(?<![A-Za-z0-9_])fetch\s*\(|\b(?:XMLHttpRequest|WebSocket)\b")),
)


def mask_comments_and_strings(source: str) -> str:
    result = list(source)
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if current == "/" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "line-comment"
                continue
            if current == "/" and following == "*":
                result[index] = result[index + 1] = " "
                index += 2
                state = "block-comment"
                continue
            if current in {'"', "'"}:
                result[index] = " "
                quote = current
                state = "string"
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
        elif state == "block-comment":
            result[index] = " "
            if current == "*" and following == "/":
                result[index + 1] = " "
                index += 2
                state = "code"
                continue
        else:
            result[index] = " "
            if current == "\\" and following:
                result[index + 1] = " "
                index += 2
                continue
            if current == quote:
                state = "code"
        index += 1
    return "".join(result)


sources: list[pathlib.Path] = []
for raw_path in sys.argv[1:]:
    path = pathlib.Path(raw_path)
    if path.is_dir():
        sources.extend(sorted(path.rglob("*.hx")))
    elif path.is_file() and path.suffix == ".hx":
        sources.append(path)
    else:
        print(f"[ownership-isolation] ERROR: missing Haxe input: {path}", file=sys.stderr)
        raise SystemExit(3)
if not sources:
    print("[ownership-isolation] ERROR: no Haxe sources were provided.", file=sys.stderr)
    raise SystemExit(3)

violations: list[str] = []
for source_path in sources:
    masked = mask_comments_and_strings(source_path.read_text(encoding="utf-8"))
    for match in node_reference.finditer(masked):
        if match.group(0) not in allowed_node_references:
            line = masked.count("\n", 0, match.start()) + 1
            violations.append(f"{source_path}:{line}: Node capability is not allowlisted: {match.group(0)}")
    for label, pattern in forbidden_patterns:
        for match in pattern.finditer(masked):
            line = masked.count("\n", 0, match.start()) + 1
            violations.append(f"{source_path}:{line}: forbidden {label}: {match.group(0)}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(2)
PY
}

isolation_probe="${evidence_root}/ownership-isolation-probe.hx"
printf '%s\n' \
  'import js.node.Buffer;' \
  'import js.node.Crypto;' \
  'import js.node.Fs;' \
  'import js.node.Path;' \
  'import js.node.fs.Stats;' \
  'final fetcher = new LocalFetcher();' > "${isolation_probe}"
scan_ownership_isolation "${isolation_probe}"

for forbidden_input in \
  'import js.node.ChildProcess;' \
  'import js.node.child_process.ChildProcess;' \
  'import js.node.Process;' \
  'import js.node.dns.Resolver;' \
  'import js.node.http.ClientRequest;' \
  'import js.node.https.Agent;' \
  'import js.node.net.Socket;' \
  'import js.node.tls.TLSSocket;' \
  'Sys.command("printf", []);' \
  'final process = new sys.io.Process("printf", []);' \
  'js.Lib.require("node:http");' \
  'require("child_process")' \
  'js.Syntax.code("process.exit(1)");' \
  'js.Syntax.plainCode("process.exit(1)");' \
  '@:jsRequire("node:http") extern class HttpModule {}' \
  '@:native("process") extern class NativeProcess {}' \
  'final process = js.Node.process;' \
  'extern class LocalEscape {}' \
  'fetch("https://example.invalid")' \
  'new XMLHttpRequest()' \
  'new WebSocket("wss://example.invalid")'; do
  printf '%s\n' "${forbidden_input}" > "${isolation_probe}"
  if scan_ownership_isolation "${isolation_probe}" >/dev/null 2>&1; then
    echo "SDK-041 production owner isolation scan missed forbidden self-test input: ${forbidden_input}" >&2
    exit 1
  else
    isolation_self_test_status="$?"
    if [[ "${isolation_self_test_status}" -ne 2 ]]; then
      echo "SDK-041 production owner isolation scanner failed with status ${isolation_self_test_status}" >&2
      exit 1
    fi
  fi
done
scan_ownership_isolation packages/cli/src/wordpresshx/cli/ownership

echo "SDK-041 ownership runtime-isolation allowlist scan passed"
echo "SDK-041 Haxe ownership transaction gate passed"
