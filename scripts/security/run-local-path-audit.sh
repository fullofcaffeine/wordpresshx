#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
mac_users="/Us""ers/"
linux_home="/ho""me/"
mac_temp="/var/fol""ders/"
mac_private_temp="/private/var/fol""ders/"
windows_users='[A-Za-z]:\\Us''ers\\'
absolute_local_pattern="(${mac_users}[^[:space:]\"'<>]+|${linux_home}[^[:space:]\"'<>]+|${mac_temp}[^[:space:]\"'<>]+|${mac_private_temp}[^[:space:]\"'<>]+|${windows_users}[^[:space:]\"'<>]+)"
findings_file="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-local-paths.XXXXXX")"
trap 'rm -f "${findings_file}"' EXIT

echo "[local-path-audit] Scanning every reachable Git revision"
while IFS= read -r revision; do
  git -C "${repository_root}" grep -I -n -E "${absolute_local_pattern}" "${revision}" -- . \
    >> "${findings_file}" 2>/dev/null || true
done < <(git -C "${repository_root}" rev-list --all)

if [[ -s "${findings_file}" ]]; then
  echo "[local-path-audit] ERROR: machine-local paths exist in reachable history." >&2
  sed -n '1,80p' "${findings_file}" >&2
  exit 1
fi

echo "[local-path-audit] OK"
