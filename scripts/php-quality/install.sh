#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tool_root="${repository_root}/tooling/php-quality"
cache_root="${tool_root}/.cache"
composer_phar="${cache_root}/composer-2.10.2.phar"
composer_url="https://getcomposer.org/download/2.10.2/composer.phar"
composer_sha256="5ee7125f8a30a34d246cefdc0bc85b8a783b28f2aec968994118512350d28027"

for command_name in curl php; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "PHP quality installation requires ${command_name}" >&2
    exit 1
  fi
done

mkdir -p "${cache_root}" "${cache_root}/composer-home" "${cache_root}/composer-cache"

verify_phar() {
  local path="$1"
  local actual
  actual="$(php -r 'echo hash_file("sha256", $argv[1]);' "${path}")"
  [[ "${actual}" == "${composer_sha256}" ]]
}

if [[ -f "${composer_phar}" ]] && ! verify_phar "${composer_phar}"; then
  echo "cached Composer 2.10.2 artifact has the wrong SHA-256" >&2
  exit 1
fi

if [[ ! -f "${composer_phar}" ]]; then
  temporary_phar="$(mktemp "${cache_root}/composer-download.XXXXXX")"
  cleanup_download() {
    rm -f -- "${temporary_phar}"
  }
  trap cleanup_download EXIT
  curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
    "${composer_url}" --output "${temporary_phar}"
  if ! verify_phar "${temporary_phar}"; then
    echo "downloaded Composer 2.10.2 artifact has the wrong SHA-256" >&2
    exit 1
  fi
  chmod 0600 "${temporary_phar}"
  mv -f -- "${temporary_phar}" "${composer_phar}"
  trap - EXIT
fi

export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_HOME="${cache_root}/composer-home"
export COMPOSER_CACHE_DIR="${cache_root}/composer-cache"

php "${composer_phar}" install \
  --working-dir="${tool_root}" \
  --no-ansi \
  --no-interaction \
  --no-progress \
  --prefer-dist \
  --optimize-autoloader
php "${composer_phar}" validate \
  --working-dir="${tool_root}" \
  --strict \
  --no-ansi \
  --no-interaction
php "${composer_phar}" audit \
  --working-dir="${tool_root}" \
  --locked \
  --no-ansi \
  --no-interaction
php -l "${tool_root}/run.php" >/dev/null

echo "Exact Composer 2.10.2 PHP quality graph installed"
