#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-beads-history-failure.XXXXXX")"
cleanup() {
  rm -rf "${temporary_directory}"
}
trap cleanup EXIT

fake_bd="${temporary_directory}/bd"
cat > "${fake_bd}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

arguments=" $* "
if [[ "${arguments}" == *" context "* ]]; then
  exit 0
fi
if [[ "${arguments}" == *" export --all "* ]]; then
  printf '%s\n' '{"id":"fixture-1","title":"fixture"}'
  exit 0
fi
if [[ "${arguments}" == *" history fixture-1 --json "* ]]; then
  printf '%s\n' '{"error":"unrelated history provider failure"}'
  exit 1
fi
echo "unexpected fake bd invocation: $*" >&2
exit 2
SH
chmod 700 "${fake_bd}"

failure_output="${temporary_directory}/failure.txt"
if PATH="${temporary_directory}:${PATH}" \
  bash "${repository_root}/scripts/security/run-beads-gitleaks.sh" > "${failure_output}" 2>&1; then
  echo "[beads-history-failure-test] ERROR: unrelated history failure was accepted." >&2
  exit 1
fi
if ! grep -Fq 'bd history failed for an unknown reason; publication remains blocked' "${failure_output}"; then
  echo "[beads-history-failure-test] ERROR: unrelated history failure did not produce the fail-closed diagnostic." >&2
  sed -n '1,40p' "${failure_output}" >&2
  exit 1
fi

echo "[beads-history-failure-test] Unknown history failures remain fail-closed."
