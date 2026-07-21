#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
repository_root="$(cd "${package_root}/../.." && pwd -P)"
guard="${repository_root}/scripts/lint/haxe-weak-type-guard.py"

python3 "${guard}" --self-test
git -C "${repository_root}" ls-files -z -- '*.hx' \
  | (cd "${repository_root}" && xargs -0 python3 "${guard}")

echo "WordPressHx repository Haxe strict-type closure passed"
