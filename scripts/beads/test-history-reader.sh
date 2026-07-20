#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

hash_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return
  fi
  echo "[beads-history-reader-test] ERROR: sha256sum or shasum is required." >&2
  exit 1
}

before_export="$(bd -C "${repository_root}" export --all | hash_stdin)"

bash "${repository_root}/scripts/security/run-beads-gitleaks.sh"

after_export="$(bd -C "${repository_root}" export --all | hash_stdin)"
if [[ "${before_export}" != "${after_export}" ]]; then
  echo "[beads-history-reader-test] ERROR: the live decoded issue state changed during the audit." >&2
  exit 1
fi

echo "[beads-history-reader-test] Complete history scan passed without changing live decoded issue state."
