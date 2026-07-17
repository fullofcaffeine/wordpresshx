#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

if [[ "${1:-}" == "--staged" ]]; then
  git diff --cached --check -- .
elif [[ $# -eq 0 ]]; then
  git diff --check -- .
else
  echo "usage: $0 [--staged]" >&2
  exit 2
fi
