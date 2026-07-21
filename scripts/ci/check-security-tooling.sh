#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  .gitleaks.toml
  .beads/hooks/pre-commit
  .beads/hooks/pre-push
  scripts/beads/push-safe.sh
  scripts/beads/build-history-reader.sh
  scripts/beads/test-history-reader.sh
  scripts/beads/verify-history-reader-lock.py
  scripts/ci/install-gitleaks.sh
  scripts/hooks/install.sh
  scripts/hooks/pre-commit
  scripts/hooks/pre-push
  scripts/hooks/test.sh
  scripts/lint/hx-format-guard.sh
  scripts/lint/local-path-guard-staged.sh
  scripts/lint/whitespace-guard.sh
  scripts/security/run-beads-gitleaks.sh
  scripts/security/scan-beads-decoded-state.sh
  scripts/security/test-beads-decoded-state.sh
  scripts/security/test-beads-history-failure.sh
  scripts/security/run-gitleaks.sh
  scripts/security/run-local-path-audit.sh
  tooling/beads/history-reader.lock.json
  tooling/beads/README.md
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
grep -Fq 'scripts/beads/build-history-reader.sh' scripts/security/run-beads-gitleaks.sh
grep -Fq 'scripts/security/scan-beads-decoded-state.sh' scripts/security/run-beads-gitleaks.sh
grep -Fq 'Test decoded Beads state scanner' .github/workflows/repository.yml
python3 scripts/beads/verify-history-reader-lock.py

readonly checkout_action="actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0"
checkout_action_lines="$(grep -E '^[[:space:]]*uses:[[:space:]]+actions/checkout@' .github/workflows/*.yml || true)"
checkout_action_count="$(printf '%s\n' "${checkout_action_lines}" | awk 'NF { count += 1 } END { print count + 0 }')"
if [[ "${checkout_action_count}" != "15" ]]; then
  echo "[security-policy] ERROR: expected 15 reviewed checkout action uses, found ${checkout_action_count}." >&2
  exit 1
fi
if printf '%s\n' "${checkout_action_lines}" | grep -Fv "${checkout_action}" >/dev/null; then
  echo "[security-policy] ERROR: every checkout action must use the reviewed v7.0.0 commit." >&2
  exit 1
fi
if [[ "$(grep -Fc 'fetch-depth: 0' .github/workflows/repository.yml)" != "1" ]]; then
  echo "[security-policy] ERROR: the security checkout must be the only full-history checkout." >&2
  exit 1
fi

unlocked_actions="$(awk '/^[[:space:]]*uses:/ {print $2}' .github/workflows/*.yml | grep -Ev '^\./|^[^@]+@[0-9a-f]{40}$' || true)"
if [[ -n "${unlocked_actions}" ]]; then
  echo "[security-policy] ERROR: workflow actions must use full commit SHAs:" >&2
  printf '%s\n' "${unlocked_actions}" >&2
  exit 1
fi

python3 scripts/ci/check-checkout-action.py

if [[ "${CI:-}" == "true" ]]; then
  bash scripts/beads/test-history-reader.sh --build-only
fi

echo "[security-policy] OK"
