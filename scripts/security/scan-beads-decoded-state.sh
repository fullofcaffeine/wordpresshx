#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" != "1" ]]; then
  echo "usage: scan-beads-decoded-state.sh <decoded-state-file>" >&2
  exit 2
fi

repository_root="$(git rev-parse --show-toplevel)"
decoded_state="$1"
if [[ ! -s "${decoded_state}" ]]; then
  echo "[beads-decoded-scan] ERROR: decoded Beads state is missing or empty." >&2
  exit 1
fi
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "[beads-decoded-scan] ERROR: gitleaks is required." >&2
  exit 1
fi

mac_users="/Us""ers/"
linux_home="/ho""me/"
mac_temp="/var/fol""ders/"
mac_private_temp="/private/var/fol""ders/"
windows_users='[A-Za-z]:\\Us''ers\\'
absolute_local_pattern="(${mac_users}[^[:space:]\"'<>]+|${linux_home}[^[:space:]\"'<>]+|${mac_temp}[^[:space:]\"'<>]+|${mac_private_temp}[^[:space:]\"'<>]+|${windows_users}[^[:space:]\"'<>]+)"
if grep -En "${absolute_local_pattern}" "${decoded_state}" >/dev/null; then
  echo "[beads-decoded-scan] ERROR: machine-local paths exist in decoded Beads state or history." >&2
  grep -En "${absolute_local_pattern}" "${decoded_state}" | sed -n '1,40p' >&2
  exit 1
fi

gitleaks stdin \
  --redact \
  --config "${repository_root}/.gitleaks.toml" \
  --no-banner < "${decoded_state}"
