#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

echo "[beads-push] Scanning decoded Beads state and history before publication..."
bash "${repository_root}/scripts/security/run-beads-gitleaks.sh"

echo "[beads-push] Pushing the audited Dolt history..."
bd -C "${repository_root}" dolt push "$@"
