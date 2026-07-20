#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

for command_name in bd jq gitleaks; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[beads-gitleaks] ERROR: ${command_name} is required." >&2
    exit 1
  fi
done

stock_bd="$(command -v bd)"
if ! "${stock_bd}" -C "${repository_root}" context >/dev/null 2>&1; then
  echo "[beads-gitleaks] ERROR: the repository Beads database is unavailable." >&2
  exit 1
fi

live_issue_ids="$({
  "${stock_bd}" -C "${repository_root}" export --all |
    jq -r 'select(type == "object" and (.id | type == "string")) | .id'
} | sort -u)"
probe_issue="$(printf '%s\n' "${live_issue_ids}" | awk 'NF { print; exit }')"
if [[ -z "${probe_issue}" ]]; then
  echo "[beads-gitleaks] ERROR: no issue IDs were exported from the Beads database." >&2
  exit 1
fi

umask 077
decoded_state="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-beads-decoded.XXXXXX")"
history_probe="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-beads-history-probe.XXXXXX")"
history_error="$(mktemp "${TMPDIR:-/tmp}/wordpresshx-beads-history-error.XXXXXX")"
audit_root=""
cleanup() {
  rm -f "${decoded_state}" "${history_probe}" "${history_error}"
  if [[ -n "${audit_root}" ]]; then
    rm -rf "${audit_root}"
  fi
}
trap cleanup EXIT

history_bd="${stock_bd}"
history_root="${repository_root}"
if ! "${stock_bd}" -C "${repository_root}" history "${probe_issue}" --json > "${history_probe}" 2> "${history_error}"; then
  if ! grep -Fq 'converting NULL to string is unsupported' "${history_error}" &&
    ! grep -Fq 'converting NULL to string is unsupported' "${history_probe}"; then
    echo "[beads-gitleaks] ERROR: bd history failed for an unknown reason; publication remains blocked." >&2
    sed -n '1,20p' "${history_error}" >&2
    jq -r '.error // empty' "${history_probe}" 2>/dev/null | sed -n '1,5p' >&2 || true
    exit 1
  fi

  if [[ ! -d "${repository_root}/.beads/embeddeddolt" ]]; then
    echo "[beads-gitleaks] ERROR: the known NULL-history fallback only supports a copied embedded-Dolt database." >&2
    exit 1
  fi

  echo "[beads-gitleaks] Released bd cannot decode migrated NULL history fields; using the pinned read-only compatibility reader." >&2
  history_bd="$(bash "${repository_root}/scripts/beads/build-history-reader.sh")"
  audit_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-beads-history-audit.XXXXXX")"
  mkdir -p "${audit_root}/.beads"
  chmod 700 "${audit_root}" "${audit_root}/.beads"
  cp -rf "${repository_root}/.beads/embeddeddolt" "${audit_root}/.beads/embeddeddolt"
  for metadata_file in config.yaml metadata.json .local_version; do
    if [[ -f "${repository_root}/.beads/${metadata_file}" ]]; then
      cp -f "${repository_root}/.beads/${metadata_file}" "${audit_root}/.beads/${metadata_file}"
    fi
  done
  git -C "${audit_root}" init -q
  history_root="${audit_root}"
fi

issue_ids="$({
  "${history_bd}" -C "${history_root}" export --all |
    jq -r 'select(type == "object" and (.id | type == "string")) | .id'
} | sort -u)"
if [[ "${issue_ids}" != "${live_issue_ids}" ]]; then
  echo "[beads-gitleaks] ERROR: the audit reader did not expose the same complete issue ID set as released bd." >&2
  exit 1
fi
issue_count="$(printf '%s\n' "${issue_ids}" | awk 'NF { count++ } END { print count + 0 }')"

echo "[beads-gitleaks] Scanning all current Beads records and the history of ${issue_count} issues"
{
  "${history_bd}" -C "${history_root}" export --all
  while IFS= read -r issue_id; do
    if [[ -n "${issue_id}" ]]; then
      "${history_bd}" -C "${history_root}" history "${issue_id}" --json
    fi
  done <<< "${issue_ids}"
} > "${decoded_state}"

bash "${repository_root}/scripts/security/scan-beads-decoded-state.sh" "${decoded_state}"

echo "[beads-gitleaks] OK"
