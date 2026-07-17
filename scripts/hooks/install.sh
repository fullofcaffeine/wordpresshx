#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

if [[ ! -x "${repository_root}/.beads/hooks/pre-commit" || ! -x "${repository_root}/.beads/hooks/pre-push" ]]; then
  echo "[hooks] ERROR: expected executable tracked Beads hook wrappers." >&2
  exit 1
fi

chmod +x \
  "${repository_root}/scripts/beads/push-safe.sh" \
  "${repository_root}/scripts/ci/check-security-tooling.sh" \
  "${repository_root}/scripts/ci/install-gitleaks.sh" \
  "${repository_root}/scripts/hooks/install.sh" \
  "${repository_root}/scripts/hooks/pre-commit" \
  "${repository_root}/scripts/hooks/pre-push" \
  "${repository_root}/scripts/hooks/test.sh" \
  "${repository_root}/scripts/lint/hx-format-guard.sh" \
  "${repository_root}/scripts/lint/local-path-guard-staged.sh" \
  "${repository_root}/scripts/lint/whitespace-guard.sh" \
  "${repository_root}/scripts/security/run-beads-gitleaks.sh" \
  "${repository_root}/scripts/security/run-gitleaks.sh" \
  "${repository_root}/scripts/security/run-local-path-audit.sh"

git -C "${repository_root}" config core.hooksPath .beads/hooks

echo "[hooks] Installed tracked repository hooks through .beads/hooks."
echo "[hooks] Pre-commit formats staged Haxe and scans staged content."
echo "[hooks] Pre-push scans every reachable Git revision."
echo "[hooks] Use scripts/beads/push-safe.sh for audited Dolt publication."
echo "[hooks] Required locally: Haxe Formatter 1.18.0 and Gitleaks 8.30.0."
