#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
readonly formatter_version="1.18.0"
mode="check"

case "${1:-}" in
  "") ;;
  --write) mode="write" ;;
  --tool-only) mode="tool-only" ;;
  *)
    echo "[guard:hx-format] ERROR: expected --write or --tool-only" >&2
    exit 2
    ;;
esac

if ! command -v haxelib >/dev/null 2>&1; then
  echo "[guard:hx-format] ERROR: haxelib is required." >&2
  exit 1
fi

formatter_help="$(haxelib run formatter --help 2>&1 || true)"
reported_version="$(printf '%s\n' "${formatter_help}" | awk '/^Haxe Formatter / {print $3; exit}')"
if [[ "${reported_version}" != "${formatter_version}" ]]; then
  echo "[guard:hx-format] ERROR: expected formatter ${formatter_version}, found ${reported_version:-none}." >&2
  echo "[guard:hx-format] Install: haxelib install formatter ${formatter_version}" >&2
  exit 1
fi

if [[ "${mode}" == "tool-only" ]]; then
  echo "[guard:hx-format] Formatter ${formatter_version} available."
  exit 0
fi

sources=()
for source_root in compiler packages profiles examples fixtures test tools; do
  if [[ -d "${repository_root}/${source_root}" ]] && find "${repository_root}/${source_root}" -type f -name '*.hx' -print -quit | grep -q .; then
    sources+=("-s" "${repository_root}/${source_root}")
  fi
done

if [[ "${#sources[@]}" -eq 0 ]]; then
  echo "[guard:hx-format] OK: no repository-owned Haxe sources found."
  exit 0
fi

if [[ "${mode}" == "write" ]]; then
  echo "[guard:hx-format] Formatting repository-owned Haxe with formatter ${formatter_version}..."
  haxelib run formatter "${sources[@]}"
else
  echo "[guard:hx-format] Checking repository-owned Haxe with formatter ${formatter_version}..."
  haxelib run formatter "${sources[@]}" --check
fi

echo "[guard:hx-format] OK"
