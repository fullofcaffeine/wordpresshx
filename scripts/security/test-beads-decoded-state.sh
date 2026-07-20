#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-beads-decoded-test.XXXXXX")"
cleanup() {
  rm -rf "${temporary_directory}"
}
trap cleanup EXIT

safe_fixture="${temporary_directory}/safe.jsonl"
printf '%s\n' '{"id":"example-1","description":"ordinary public test value"}' > "${safe_fixture}"
bash "${repository_root}/scripts/security/scan-beads-decoded-state.sh" "${safe_fixture}"

local_path_fixture="${temporary_directory}/local-path.jsonl"
local_path="/Us""ers/example/private/project"
printf '{"id":"example-2","description":"%s"}\n' "${local_path}" > "${local_path_fixture}"
if bash "${repository_root}/scripts/security/scan-beads-decoded-state.sh" "${local_path_fixture}" >/dev/null 2>&1; then
  echo "[beads-decoded-test] ERROR: machine-local path fixture was accepted." >&2
  exit 1
fi

secret_fixture="${temporary_directory}/secret.jsonl"
canary_value="z9Qp2Lm8Vx4Nc7Rt""1Ks6Yw3Hb0Df5GjU"
printf '{"id":"example-3","api_key":"%s"}\n' "${canary_value}" > "${secret_fixture}"
if bash "${repository_root}/scripts/security/scan-beads-decoded-state.sh" "${secret_fixture}" >/dev/null 2>&1; then
  echo "[beads-decoded-test] ERROR: synthetic credential fixture was accepted." >&2
  exit 1
fi

echo "[beads-decoded-test] Safe, machine-path, and credential fixtures passed."
