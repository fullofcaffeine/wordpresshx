#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-beads-history-reader-test.XXXXXX")"
cleanup() {
  case "${temporary_root}" in
    "${TMPDIR:-/tmp}"/wordpresshx-beads-history-reader-test.*) rm -rf -- "${temporary_root}" ;;
    *) echo "[beads-history-reader-test] refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
  esac
}
trap cleanup EXIT

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

cold_builder_output="$(
  WORDPRESSHX_BEADS_TOOL_CACHE="${temporary_root}/cache" \
    bash "${repository_root}/scripts/beads/build-history-reader.sh"
)"
cold_builder_line_count="$(printf '%s\n' "${cold_builder_output}" | awk 'NF { count += 1 } END { print count + 0 }')"
if [[ "${cold_builder_line_count}" != "1" || ! -x "${cold_builder_output}" ]]; then
  echo "[beads-history-reader-test] ERROR: cold-cache builder stdout must be exactly one executable path." >&2
  printf '%s\n' "${cold_builder_output}" >&2
  exit 1
fi

bash "${repository_root}/scripts/security/run-beads-gitleaks.sh"

after_export="$(bd -C "${repository_root}" export --all | hash_stdin)"
if [[ "${before_export}" != "${after_export}" ]]; then
  echo "[beads-history-reader-test] ERROR: the live decoded issue state changed during the audit." >&2
  exit 1
fi

echo "[beads-history-reader-test] Complete history scan passed without changing live decoded issue state."
