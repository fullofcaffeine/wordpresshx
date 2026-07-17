#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

bash "${repository_root}/scripts/ci/check-security-tooling.sh"
bash "${repository_root}/scripts/lint/hx-format-guard.sh" --tool-only
bash "${repository_root}/scripts/lint/local-path-guard-staged.sh" --self-test
bash "${repository_root}/scripts/security/run-gitleaks.sh" --staged

configured_hooks_path="$(git -C "${repository_root}" config --get core.hooksPath || true)"
if [[ "${configured_hooks_path}" != ".beads/hooks" ]]; then
  echo "[hooks-test] ERROR: expected relative core.hooksPath .beads/hooks, found ${configured_hooks_path:-unset}." >&2
  exit 1
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-hook-test.XXXXXX")"
trap 'rm -rf "${temporary_directory}"' EXIT
printf '%s\n' 'documentation example with no credential' > "${temporary_directory}/safe.txt"
gitleaks dir "${temporary_directory}" --redact --no-banner --config "${repository_root}/.gitleaks.toml"

canary_value="z9Qp2Lm8Vx4Nc7Rt""1Ks6Yw3Hb0Df5GjU"
printf 'api_key = "%s"\n' "${canary_value}" > "${temporary_directory}/canary.txt"
if gitleaks dir "${temporary_directory}" --redact --no-banner --config "${repository_root}/.gitleaks.toml" >/dev/null 2>&1; then
  echo "[hooks-test] ERROR: Gitleaks failed to reject the synthetic credential canary." >&2
  exit 1
fi

echo "[hooks-test] Positive and negative hook tests passed."
