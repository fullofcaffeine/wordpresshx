#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
require_clean=0

if (( $# > 1 )); then
  echo "usage: bash compiler/reflaxe.php/scripts/test-package.sh [--require-clean]" >&2
  exit 1
fi
if (( $# == 1 )); then
  if [[ "$1" != "--require-clean" ]]; then
    echo "unknown package-test argument: $1" >&2
    exit 1
  fi
  require_clean=1
fi

haxe_version="$(haxe --version)"
if [[ "${haxe_version}" != "4.3.7" ]]; then
  echo "reflaxe.php package proof requires Haxe 4.3.7; found ${haxe_version}" >&2
  exit 1
fi
php -r 'if (PHP_VERSION_ID < 70400) { fwrite(STDERR, "PHP 7.4 or newer is required\n"); exit(1); }'
PYTHONDONTWRITEBYTECODE=1 python3 "${package_root}/scripts/test-package-builder.py"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/reflaxe-php-package.XXXXXX")"
temporary_root="$(cd "${temporary_root}" && pwd -P)"
cleanup() {
  rm -rf -- "${temporary_root}"
}
trap cleanup EXIT

build_a="${temporary_root}/build-a"
build_b="${temporary_root}/build-b"
build_package() {
  local output_root="$1"
  if (( require_clean == 1 )); then
    SOURCE_DATE_EPOCH=315532800 python3 "${package_root}/scripts/build-package.py" --out "${output_root}" --require-clean
  else
    SOURCE_DATE_EPOCH=315532800 python3 "${package_root}/scripts/build-package.py" --out "${output_root}"
  fi
}

build_package "${build_a}"
build_package "${build_b}"

archive_name="reflaxe.php-0.0.0.zip"
if ! cmp -s "${build_a}/${archive_name}" "${build_b}/${archive_name}"; then
  echo "two reflaxe.php package builds were not byte-identical" >&2
  exit 1
fi
if ! cmp -s "${build_a}/artifact-manifest.json" "${build_b}/artifact-manifest.json"; then
  echo "two reflaxe.php artifact manifests were not byte-identical" >&2
  exit 1
fi

artifact_root="${package_root}/build/package-artifact"
mkdir -p "${artifact_root}"
cp -f "${build_a}/${archive_name}" "${artifact_root}/${archive_name}"
cp -f "${build_a}/artifact-manifest.json" "${artifact_root}/artifact-manifest.json"

application_root="${temporary_root}/external-application"
isolated_haxelib="${application_root}/.haxelib"
mkdir -p "${application_root}"
cp -rf "${package_root}/test/package-consumer/." "${application_root}/"
(cd "${application_root}" && haxelib newrepo --quiet)

set +e
missing_output="$(cd "${application_root}" && haxe build.hxml 2>&1)"
missing_status=$?
set -e
if (( missing_status == 0 )); then
  echo "external consumer unexpectedly resolved reflaxe.php before package installation" >&2
  exit 1
fi
if [[ "${missing_output}" != *"reflaxe.php"* ]]; then
  printf '%s\n' "${missing_output}" >&2
  echo "missing-package diagnostic did not identify reflaxe.php" >&2
  exit 1
fi

(cd "${application_root}" && haxelib install "${build_a}/${archive_name}" --always --quiet)
resolved_library="$(cd "${application_root}" && haxelib path reflaxe.php | awk 'NF && $1 !~ /^-/ { print; exit }')"
case "${resolved_library}" in
  "${isolated_haxelib}"/*) ;;
  *)
    echo "installed reflaxe.php resolved outside the disposable repository: ${resolved_library}" >&2
    exit 1
    ;;
esac

consumer_output="$(cd "${application_root}" && haxe build.hxml)"
if [[ "${consumer_output}" != "REFLAXE_PHP_EXTERNAL_CONSUMER:PASS" ]]; then
  echo "unexpected external Haxe consumer output: ${consumer_output}" >&2
  exit 1
fi

generated_php="${application_root}/build/external-consumer.php"
php -l "${generated_php}"
runtime_output="$(php "${generated_php}")"
expected_output="$(tr -d '\n' < "${application_root}/expected.stdout")"
if [[ "${runtime_output}" != "${expected_output}" ]]; then
  echo "unexpected installed-package PHP output: ${runtime_output}" >&2
  exit 1
fi
if grep -E -n -i 'wordpress|gutenberg|wphx|wordpresshx-port' "${generated_php}"; then
  echo "external generic package output contains WordPress coupling" >&2
  exit 1
fi

echo "reflaxe.php isolated package install and external PHP runtime passed"
echo "REFLAXE_PHP_PACKAGE_READINESS:PASS"
