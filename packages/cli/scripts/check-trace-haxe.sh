#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(cd "${package_root}/../.." && pwd)"

python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" --self-test
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" \
  "${package_root}/src/wordpresshx/cli/BrowserTraceEngine.hx" \
  "${package_root}/src/wordpresshx/cli/CanonicalJson.hx" \
  "${package_root}/src/wordpresshx/cli/CliArguments.hx" \
  "${package_root}/src/wordpresshx/cli/CliEventStream.hx" \
  "${package_root}/src/wordpresshx/cli/CliJson.hx" \
  "${package_root}/src/wordpresshx/cli/Content.hx" \
  "${package_root}/src/wordpresshx/cli/Contract.hx" \
  "${package_root}/src/wordpresshx/cli/Main.hx" \
  "${package_root}/src/wordpresshx/cli/PhpTraceEngine.hx" \
  "${package_root}/src/wordpresshx/cli/SourceIndex.hx" \
  "${package_root}/src/wordpresshx/cli/SourceMapV3.hx" \
  "${package_root}/src/wordpresshx/cli/TraceCommand.hx"
