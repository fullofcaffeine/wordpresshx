#!/usr/bin/env bash
set -euo pipefail

# The reviewed checksum is stored here rather than downloaded beside the
# archive, so a compromised release source cannot replace both at runtime.
readonly gitleaks_version="8.30.0"
readonly gitleaks_asset="gitleaks_${gitleaks_version}_linux_x64.tar.gz"
readonly gitleaks_sha256="79a3ab579b53f71efd634f3aaf7e04a0fa0cf206b7ed434638d1547a2470a66e"
readonly gitleaks_download_url="https://github.com/gitleaks/gitleaks/releases/download/v${gitleaks_version}/${gitleaks_asset}"

usage() {
  printf '%s\n' 'Usage: scripts/ci/install-gitleaks.sh --install-dir DIR [--archive FILE]'
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  else
    echo "[gitleaks-install] ERROR: sha256sum or shasum is required." >&2
    return 1
  fi
}

is_linux_x64() {
  [[ "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]]
}

install_dir=""
provided_archive=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 ]] || { echo "[gitleaks-install] ERROR: --install-dir requires a value." >&2; exit 2; }
      install_dir="$2"
      shift 2
      ;;
    --archive)
      [[ $# -ge 2 ]] || { echo "[gitleaks-install] ERROR: --archive requires a value." >&2; exit 2; }
      provided_archive="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[gitleaks-install] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${install_dir}" ]]; then
  echo "[gitleaks-install] ERROR: --install-dir is required." >&2
  exit 2
fi

umask 077
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-gitleaks.XXXXXX")"
trap 'rm -rf "${temporary_directory}"' EXIT

archive="${provided_archive}"
if [[ -z "${archive}" ]]; then
  if ! is_linux_x64; then
    echo "[gitleaks-install] ERROR: the pinned CI binary supports Linux x64 only." >&2
    exit 2
  fi
  archive="${temporary_directory}/${gitleaks_asset}"
  curl --proto '=https' --tlsv1.2 -fsSL \
    --connect-timeout 15 --max-time 180 \
    --retry 5 --retry-all-errors --retry-delay 2 \
    -o "${archive}" "${gitleaks_download_url}"
elif [[ ! -f "${archive}" ]]; then
  echo "[gitleaks-install] ERROR: archive does not exist: ${archive}" >&2
  exit 2
fi

actual_sha256="$(sha256_file "${archive}")"
if [[ "${actual_sha256}" != "${gitleaks_sha256}" ]]; then
  echo "[gitleaks-install] ERROR: checksum mismatch for ${gitleaks_asset}." >&2
  echo "[gitleaks-install] expected: ${gitleaks_sha256}" >&2
  echo "[gitleaks-install] actual:   ${actual_sha256}" >&2
  exit 1
fi

if ! is_linux_x64; then
  echo "[gitleaks-install] ERROR: verified archive, but the pinned CI binary supports Linux x64 only." >&2
  exit 2
fi

tar -xzf "${archive}" -C "${temporary_directory}" gitleaks
chmod 0755 "${temporary_directory}/gitleaks"
reported_version="$("${temporary_directory}/gitleaks" version | tr -d '\r\n')"
if [[ "${reported_version}" != "${gitleaks_version}" ]]; then
  echo "[gitleaks-install] ERROR: expected Gitleaks ${gitleaks_version}, binary reported ${reported_version}." >&2
  exit 1
fi

mkdir -p "${install_dir}"
install -m 0755 "${temporary_directory}/gitleaks" "${install_dir}/gitleaks"
echo "[gitleaks-install] Verified Gitleaks ${gitleaks_version} (${gitleaks_sha256})"
