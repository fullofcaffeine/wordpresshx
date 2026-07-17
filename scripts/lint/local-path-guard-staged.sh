#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

mac_users="/Us""ers/"
linux_home="/ho""me/"
mac_temp="/var/fol""ders/"
mac_private_temp="/private/var/fol""ders/"
windows_users='[A-Za-z]:\\Us''ers\\'
absolute_local_pattern="(${mac_users}[^[:space:]\"'<>]+|${linux_home}[^[:space:]\"'<>]+|${mac_temp}[^[:space:]\"'<>]+|${mac_private_temp}[^[:space:]\"'<>]+|${windows_users}[^[:space:]\"'<>]+)"

scan_lines() {
  local lines="$1"
  local hits
  hits="$(printf '%s\n' "${lines}" | grep -En "${absolute_local_pattern}" || true)"
  if [[ -n "${hits}" ]]; then
    printf '%s\n' "${hits}"
    return 1
  fi
}

if [[ "${1:-}" == "--self-test" ]]; then
  safe_sample='docs/compiler.md:use ../genes only as a development reference'
  unsafe_sample="docs/compiler.md:${mac_users}developer/workspace/compiler"
  scan_lines "${safe_sample}"
  if scan_lines "${unsafe_sample}" >/dev/null; then
    echo "[guard:local-paths] ERROR: negative self-test was not rejected." >&2
    exit 1
  fi
  echo "[guard:local-paths] Positive and negative self-tests passed."
  exit 0
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--self-test]" >&2
  exit 2
fi

staged_added_lines="$({
  git diff --cached --unified=0 --no-color -- . |
    awk '
      /^diff --git / { file = ""; next }
      /^\+\+\+ / {
        file = $2
        if (file == "/dev/null") {
          file = ""
        } else {
          sub(/^[a-z]\//, "", file)
        }
        next
      }
      /^\+/ && $0 !~ /^\+\+\+/ && file != "" {
        print file ":" substr($0, 2)
      }
    '
} || true)"

if [[ -z "${staged_added_lines}" ]]; then
  exit 0
fi

if ! hits="$(scan_lines "${staged_added_lines}")"; then
  echo "[guard:local-paths] ERROR: absolute local filesystem paths detected." >&2
  echo "[guard:local-paths] Use repository-relative paths instead." >&2
  printf '%s\n' "${hits}" >&2
  exit 1
fi

echo "[guard:local-paths] OK"
