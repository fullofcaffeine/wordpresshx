#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  AGENTS.md
  README.md
  GOVERNANCE.md
  CONTRIBUTING.md
  SECURITY.md
  SUPPORT.md
  CHANGELOG.md
  LICENSES/README.md
  wordpress-hx-sdk-product-requirements.md
  docs/README.md
  docs/adr/README.md
  docs/architecture/repository-layout.md
  docs/product/README.md
  docs/release/README.md
  packages/README.md
  compiler/README.md
  profiles/README.md
  schemas/README.md
  tools/README.md
  examples/README.md
  fixtures/README.md
  test/README.md
  docker/README.md
  manifests/README.md
)

missing=0
for path in "${required_files[@]}"; do
  if [[ ! -s "${path}" ]]; then
    echo "missing or empty required bootstrap file: ${path}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 1
fi

for path in "${required_files[@]}"; do
  if ! git ls-files --error-unmatch -- "${path}" >/dev/null 2>&1; then
    echo "required bootstrap file is not tracked: ${path}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 1
fi

forbidden_dependency_pattern='\.\./wordpresshx-port|wordpresshx-port/(src|compiler|packages)|haxelib[[:space:]]+dev[^[:cntrl:]]*wordpresshx-port'
scan_output="$(mktemp)"
trap 'rm -f "${scan_output}"' EXIT
if git grep -nE "${forbidden_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!docs/**' ':!wordpress-hx-sdk-product-requirements.md' \
  > "${scan_output}" 2>/dev/null; then
  echo "direct dependency on wordpresshx-port internals detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

git diff --check HEAD

echo "repository bootstrap checks passed"
