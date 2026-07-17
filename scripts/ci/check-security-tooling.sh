#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  .gitleaks.toml
  .beads/hooks/pre-commit
  .beads/hooks/pre-push
  scripts/beads/push-safe.sh
  scripts/ci/install-gitleaks.sh
  scripts/hooks/install.sh
  scripts/hooks/pre-commit
  scripts/hooks/pre-push
  scripts/hooks/test.sh
  scripts/lint/hx-format-guard.sh
  scripts/lint/local-path-guard-staged.sh
  scripts/lint/whitespace-guard.sh
  scripts/security/run-beads-gitleaks.sh
  scripts/security/run-gitleaks.sh
  scripts/security/run-local-path-audit.sh
)

for path in "${required_files[@]}"; do
  if [[ ! -s "${path}" ]]; then
    echo "[security-policy] ERROR: missing or empty ${path}." >&2
    exit 1
  fi
done

grep -Fq 'minVersion = "8.30.0"' .gitleaks.toml
grep -Fq 'useDefault = true' .gitleaks.toml
if grep -Eq '^\[allowlist\]' .gitleaks.toml; then
  echo "[security-policy] ERROR: repository-wide Gitleaks allowlists are forbidden." >&2
  exit 1
fi

grep -Fq 'readonly gitleaks_version="8.30.0"' scripts/ci/install-gitleaks.sh
grep -Fq '79a3ab579b53f71efd634f3aaf7e04a0fa0cf206b7ed434638d1547a2470a66e' scripts/ci/install-gitleaks.sh
grep -Fq 'readonly formatter_version="1.18.0"' scripts/lint/hx-format-guard.sh
grep -Fq 'scripts/hooks/pre-commit' .beads/hooks/pre-commit
grep -Fq 'scripts/hooks/pre-push' .beads/hooks/pre-push
grep -Fq 'scripts/security/run-gitleaks.sh' scripts/hooks/pre-commit
grep -Fq 'scripts/security/run-gitleaks.sh' scripts/hooks/pre-push
grep -Fq 'scripts/security/run-beads-gitleaks.sh' scripts/beads/push-safe.sh

unlocked_actions="$(awk '/^[[:space:]]*uses:/ {print $2}' .github/workflows/*.yml | grep -Ev '^\./|^[^@]+@[0-9a-f]{40}$' || true)"
if [[ -n "${unlocked_actions}" ]]; then
  echo "[security-policy] ERROR: workflow actions must use full commit SHAs:" >&2
  printf '%s\n' "${unlocked_actions}" >&2
  exit 1
fi

echo "[security-policy] OK"
