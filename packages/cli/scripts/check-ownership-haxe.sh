#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(cd "${package_root}/../.." && pwd)"

python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" --self-test
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" \
  "${package_root}/src/wordpresshx/cli/closedjson/JsonParser.hx" \
  "${package_root}/src/wordpresshx/cli/closedjson/JsonValue.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/ArtifactOwner.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/OwnershipContract.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/OwnershipFailure.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/OwnershipJson.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/OwnershipLayout.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/OwnershipResult.hx" \
  "${package_root}/src/wordpresshx/cli/ownership/StageValidator.hx" \
  "${package_root}/test/ownership/src/sdk041/fixture/Main.hx"
