#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

for command_name in bd jq gitleaks; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[beads-gitleaks] ERROR: ${command_name} is required." >&2
    exit 1
  fi
done

if ! bd -C "${repository_root}" context >/dev/null 2>&1; then
  echo "[beads-gitleaks] ERROR: the repository Beads database is unavailable." >&2
  exit 1
fi

issue_ids="$({
  bd -C "${repository_root}" export --all |
    jq -r 'select(type == "object" and (.id | type == "string")) | .id'
} | sort -u)"
issue_count="$(printf '%s\n' "${issue_ids}" | awk 'NF { count++ } END { print count + 0 }')"

echo "[beads-gitleaks] Scanning all current Beads records and the history of ${issue_count} issues"
umask 077
decoded_state="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-beads-decoded.XXXXXX")"
trap 'rm -f "${decoded_state}"' EXIT
{
  bd -C "${repository_root}" export --all
  while IFS= read -r issue_id; do
    if [[ -n "${issue_id}" ]]; then
      bd -C "${repository_root}" history "${issue_id}" --json
    fi
  done <<< "${issue_ids}"
} > "${decoded_state}"

mac_users="/Us""ers/"
linux_home="/ho""me/"
mac_temp="/var/fol""ders/"
mac_private_temp="/private/var/fol""ders/"
windows_users='[A-Za-z]:\\Us''ers\\'
absolute_local_pattern="(${mac_users}[^[:space:]\"'<>]+|${linux_home}[^[:space:]\"'<>]+|${mac_temp}[^[:space:]\"'<>]+|${mac_private_temp}[^[:space:]\"'<>]+|${windows_users}[^[:space:]\"'<>]+)"
if grep -En "${absolute_local_pattern}" "${decoded_state}" >/dev/null; then
  echo "[beads-gitleaks] ERROR: machine-local paths exist in decoded Beads state or history." >&2
  grep -En "${absolute_local_pattern}" "${decoded_state}" | sed -n '1,40p' >&2
  exit 1
fi

gitleaks stdin \
  --redact \
  --config "${repository_root}/.gitleaks.toml" \
  --no-banner < "${decoded_state}"

echo "[beads-gitleaks] OK"
