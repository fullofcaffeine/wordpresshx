#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
mode="full"
readonly expected_version="8.30.0"
readonly dolt_remote_ref="refs/dolt/data"
readonly dolt_local_ref="refs/remotes/origin/dolt/data"

if [[ "${1:-}" == "--staged" ]]; then
  mode="staged"
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--staged]" >&2
  exit 2
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "[gitleaks] ERROR: Gitleaks ${expected_version} is required." >&2
  exit 1
fi

reported_version="$(gitleaks version | tr -d '\r\n')"
if [[ "${reported_version}" != "${expected_version}" ]]; then
  echo "[gitleaks] ERROR: expected Gitleaks ${expected_version}, found ${reported_version:-none}." >&2
  exit 1
fi

config_args=(--config "${repository_root}/.gitleaks.toml")
if [[ "${mode}" == "staged" ]]; then
  echo "[gitleaks] Scanning staged changes"
  (cd "${repository_root}" && gitleaks git --staged --redact --no-banner "${config_args[@]}")
  exit 0
fi

if git -C "${repository_root}" remote get-url origin >/dev/null 2>&1; then
  set +e
  GIT_TERMINAL_PROMPT=0 git -C "${repository_root}" ls-remote \
    --exit-code --refs origin "${dolt_remote_ref}" >/dev/null 2>&1
  dolt_lookup_status=$?
  set -e
  case "${dolt_lookup_status}" in
    0)
      echo "[gitleaks] Fetching the remote Beads Dolt ref for audit"
      GIT_TERMINAL_PROMPT=0 git -C "${repository_root}" fetch \
        --no-tags --force origin "${dolt_remote_ref}:${dolt_local_ref}"
      ;;
    2)
      echo "[gitleaks] No remote Beads Dolt ref is advertised"
      ;;
    *)
      echo "[gitleaks] ERROR: could not inspect origin for ${dolt_remote_ref}." >&2
      exit 1
      ;;
  esac
else
  echo "[gitleaks] No origin remote is configured; scanning local refs only"
fi

echo "[gitleaks] Scanning every reachable Git revision"
echo "[gitleaks] Reachable commits: $(git -C "${repository_root}" rev-list --all --count)"
(cd "${repository_root}" && gitleaks git . --redact --no-banner --log-opts='--all' "${config_args[@]}")
