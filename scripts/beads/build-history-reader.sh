#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
lock_file="${repository_root}/tooling/beads/history-reader.lock.json"

for command_name in git go jq; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[beads-history-reader] ERROR: ${command_name} is required to build the pinned compatibility reader." >&2
    exit 1
  fi
done

python3 "${repository_root}/scripts/beads/verify-history-reader-lock.py" >/dev/null

upstream_repository="$(jq -r '.upstreamRepository' "${lock_file}")"
base_commit="$(jq -r '.baseCommit' "${lock_file}")"
fix_commit="$(jq -r '.historyFix.commit' "${lock_file}")"
ancestor_distance="$(jq -r '.historyFix.ancestorDistance' "${lock_file}")"
database_schema_version="$(jq -r '.repositoryCompatibility.databaseSchemaVersion' "${lock_file}")"
client_identity="$(jq -r '.repositoryCompatibility.clientIdentity' "${lock_file}")"
cgo_enabled="$(jq -r '.build.cgoEnabled' "${lock_file}")"
build_tags="$(jq -r '.build.tags' "${lock_file}")"
test_package="$(jq -r '.build.testPackage' "${lock_file}")"
test_name="$(jq -r '.build.testName' "${lock_file}")"

git_directory="$(git rev-parse --absolute-git-dir)"
cache_root="${WORDPRESSHX_BEADS_TOOL_CACHE:-${git_directory}/wordpresshx-tools/beads-history-reader}"
cache_key="${base_commit}"
cache_directory="${cache_root}/${cache_key}"
cached_binary="${cache_directory}/bd"
cache_receipt="${cache_directory}/receipt.json"

if [[ -x "${cached_binary}" && -s "${cache_receipt}" ]] &&
  jq -e --arg source "${base_commit}" --arg fix "${fix_commit}" --argjson schema "${database_schema_version}" --arg identity "${client_identity}" \
    '.sourceCommit == $source and .historyFixCommit == $fix and .databaseSchemaVersion == $schema and .clientIdentity == $identity and .regression == "passed"' \
    "${cache_receipt}" >/dev/null 2>&1; then
  printf '%s\n' "${cached_binary}"
  exit 0
fi

echo "[beads-history-reader] Building the pinned schema-${database_schema_version} history reader in an isolated directory..." >&2
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-beads-history-reader.XXXXXX")"
cleanup() {
  rm -rf "${temporary_root}"
}
trap cleanup EXIT
source_root="${temporary_root}/beads"

git init -q "${source_root}"
git -C "${source_root}" remote add origin "${upstream_repository}"
git -C "${source_root}" fetch -q --depth="$((ancestor_distance + 1))" origin "${base_commit}"
git -C "${source_root}" checkout -q --detach FETCH_HEAD
if [[ "$(git -C "${source_root}" rev-parse HEAD)" != "${base_commit}" ]]; then
  echo "[beads-history-reader] ERROR: fetched base commit does not match the lock." >&2
  exit 1
fi

if ! git -C "${source_root}" merge-base --is-ancestor "${fix_commit}" "${base_commit}"; then
  echo "[beads-history-reader] ERROR: the pinned history fix is not an ancestor of the source commit." >&2
  exit 1
fi
actual_distance="$(git -C "${source_root}" rev-list --count "${fix_commit}..${base_commit}")"
if [[ "${actual_distance}" != "${ancestor_distance}" ]]; then
  echo "[beads-history-reader] ERROR: source/fix ancestry distance differs from the lock." >&2
  exit 1
fi

actual_changed="$(git -C "${source_root}" diff-tree --no-commit-id --name-only -r "${fix_commit}" | LC_ALL=C sort)"
expected_changed="$(jq -r '.expectedChangedFiles[]' "${lock_file}" | LC_ALL=C sort)"
if [[ "${actual_changed}" != "${expected_changed}" ]]; then
  echo "[beads-history-reader] ERROR: the pinned fix changed an unexpected file set." >&2
  diff -u <(printf '%s\n' "${expected_changed}") <(printf '%s\n' "${actual_changed}") >&2 || true
  exit 1
fi
if ! grep -Fq "COALESCE(description, '') AS description" "${source_root}/internal/storage/issueops/history.go" ||
  ! grep -Fq "COALESCE(description, '') AS description" "${source_root}/internal/storage/dolt/history.go"; then
  echo "[beads-history-reader] ERROR: the pinned fix does not normalize the known nullable history fields." >&2
  exit 1
fi

echo "[beads-history-reader] Running the upstream embedded-Dolt NULL-history regression..." >&2
(
  cd "${source_root}"
  BEADS_TEST_EMBEDDED_DOLT=1 \
    CGO_ENABLED="${cgo_enabled}" \
    GOTOOLCHAIN=auto \
    go test -tags "${build_tags}" "${test_package}" -run "^${test_name}$" -count=1 >&2
  CGO_ENABLED="${cgo_enabled}" \
    GOTOOLCHAIN=auto \
    go build -buildvcs=false -tags "${build_tags}" -ldflags "-X main.Build=${base_commit:0:9}" -o "${temporary_root}/bd" ./cmd/bd
)

actual_identity="$("${temporary_root}/bd" version | head -n 1)"
if [[ "${actual_identity}" != "${client_identity}" ]]; then
  echo "[beads-history-reader] ERROR: built client identity differs from the repository lock." >&2
  printf '[beads-history-reader] expected: %s\n' "${client_identity}" >&2
  printf '[beads-history-reader] actual:   %s\n' "${actual_identity}" >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]] && command -v codesign >/dev/null 2>&1; then
  codesign -s - -f "${temporary_root}/bd" >/dev/null 2>&1 || true
fi

mkdir -p "${cache_directory}"
temporary_binary="$(mktemp "${cache_directory}/bd.XXXXXX")"
cp -f "${temporary_root}/bd" "${temporary_binary}"
chmod 700 "${temporary_binary}"
mv -f "${temporary_binary}" "${cached_binary}"
temporary_receipt="$(mktemp "${cache_directory}/receipt.XXXXXX")"
jq -n \
  --arg source "${base_commit}" \
  --arg fix "${fix_commit}" \
  --arg identity "${client_identity}" \
  --argjson databaseSchemaVersion "${database_schema_version}" \
  '{schemaVersion: 2, sourceCommit: $source, historyFixCommit: $fix, databaseSchemaVersion: $databaseSchemaVersion, regression: "passed", clientIdentity: $identity}' \
  > "${temporary_receipt}"
mv -f "${temporary_receipt}" "${cache_receipt}"

echo "[beads-history-reader] Pinned compatibility reader ready." >&2
printf '%s\n' "${cached_binary}"
