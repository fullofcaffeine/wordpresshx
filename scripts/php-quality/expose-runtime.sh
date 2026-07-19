#!/usr/bin/env bash
set -euo pipefail

if (( $# == 0 )); then
  echo "usage: expose-runtime.sh <compiled-wphx-directory> [...]" >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tool_root="${repository_root}/tooling/php-quality"
if [[ ! -f "${tool_root}/vendor/autoload.php" ]]; then
  echo "install the exact PHP quality graph before exposing a runtime" >&2
  exit 1
fi

for runtime_root in "$@"; do
  if [[ ! -d "${runtime_root}" ]] || [[ -L "${runtime_root}" ]]; then
    echo "compiled wphx runtime must be a real directory: ${runtime_root}" >&2
    exit 1
  fi
  target="${runtime_root}/php-quality"
  if [[ -e "${target}" ]] || [[ -L "${target}" ]]; then
    echo "refusing to replace an existing runtime PHP quality bundle: ${target}" >&2
    exit 1
  fi
  ln -s "${tool_root}" "${target}"
done
