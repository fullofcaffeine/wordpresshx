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

dependency_plan="${temporary_root}/dependency-plan.tsv"
python3 - "${package_root}/haxelib.json" > "${dependency_plan}" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for name, version in sorted(metadata["dependencies"].items()):
    print(f"{name}\t{version}")
PY

dependency_archives="${temporary_root}/dependency-archives"
mkdir -p "${dependency_archives}"
while IFS=$'\t' read -r dependency_name dependency_version; do
  if [[ -z "${dependency_name}" || -z "${dependency_version}" ]]; then
    echo "package dependency plan contains an empty identity" >&2
    exit 1
  fi
  dependency_source="$(haxelib libpath "${dependency_name}:${dependency_version}")"
  dependency_archive="${dependency_archives}/${dependency_name}-${dependency_version}.zip"
  PYTHONDONTWRITEBYTECODE=1 python3 \
    "${package_root}/scripts/package-installed-haxelib.py" \
    --source "${dependency_source}" \
    --out "${dependency_archive}" \
    --name "${dependency_name}" \
    --version "${dependency_version}"
done < "${dependency_plan}"

archive_name="reflaxe.php-0.0.0.zip"
if ! cmp -s "${build_a}/${archive_name}" "${build_b}/${archive_name}"; then
  echo "two reflaxe.php package builds were not byte-identical" >&2
  exit 1
fi
if ! cmp -s "${build_a}/artifact-manifest.json" "${build_b}/artifact-manifest.json"; then
  echo "two reflaxe.php artifact manifests were not byte-identical" >&2
  exit 1
fi

python3 - \
  "${build_a}/${archive_name}" \
  "${build_a}/artifact-manifest.json" \
  "${package_root}/semantic-capabilities.json" <<'PY'
import hashlib
import json
import sys
import zipfile
from pathlib import Path

archive_path = Path(sys.argv[1])
artifact = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
semantic_authority = Path(sys.argv[3]).read_bytes()
with zipfile.ZipFile(archive_path) as archive:
    assert "COPYING" in archive.namelist(), "package omits complete GPL text"
    copying = archive.read("COPYING")
    source = json.loads(archive.read("package-source.json"))
    packaged_semantic_authority = archive.read("semantic-capabilities.json")
    semantic_matrix = json.loads(packaged_semantic_authority)
assert hashlib.sha256(copying).hexdigest() == (
    "edaef632cbb643e4e7a221717a6c441a4c1a7c918e6e4d56debc3d8739b233f6"
), "packaged GPL text digest changed"
assert source["licenseMaterials"]["expression"] == "GPL-2.0-or-later", (
    "package source manifest has the wrong license expression"
)
assert source["licenseMaterials"]["completeText"]["path"] == "COPYING", (
    "package source manifest does not bind the complete license text"
)
assert source["sourceCorrespondence"]["status"] == "complete-source-only-archive", (
    "package source correspondence is incomplete"
)
assert packaged_semantic_authority == semantic_authority, (
    "packaged semantic capability authority differs from the tracked source"
)
capabilities = semantic_matrix["capabilities"]
states = ("admitted", "unsupported-owned", "unverified-owned")
derived_summary = {
    "capabilityCount": len(capabilities),
    "categoryCount": len({capability["category"] for capability in capabilities}),
    "stateCounts": {
        state: sum(capability["state"] == state for capability in capabilities)
        for state in states
    },
}
assert semantic_matrix["summary"] == derived_summary, (
    "semantic capability summary is not derived from its capability records"
)
assert artifact["package"]["completeLicenseText"]["path"] == "COPYING", (
    "artifact manifest does not bind the complete license text"
)
assert artifact["package"]["sourceCorrespondence"] == (
    "complete-source-only-archive"
), "artifact manifest source correspondence is incomplete"
PY

artifact_root="${package_root}/build/package-artifact"
mkdir -p "${artifact_root}"
cp -f "${build_a}/${archive_name}" "${artifact_root}/${archive_name}"
cp -f "${build_a}/artifact-manifest.json" "${artifact_root}/artifact-manifest.json"

application_root="${temporary_root}/external-application"
isolated_haxelib="${application_root}/.haxelib"
mkdir -p "${application_root}"
cp -rf "${package_root}/test/package-consumer/." "${application_root}/"
(cd "${application_root}" && haxelib newrepo --quiet)

while IFS=$'\t' read -r dependency_name dependency_version; do
  dependency_archive="${dependency_archives}/${dependency_name}-${dependency_version}.zip"
  (cd "${application_root}" && haxelib install \
    "${dependency_archive}" --always --quiet --skip-dependencies)
  resolved_dependency="$(cd "${application_root}" && \
    haxelib libpath "${dependency_name}:${dependency_version}")"
  case "${resolved_dependency}" in
    "${isolated_haxelib}"/*) ;;
    *)
      echo "installed dependency resolved outside the disposable repository: ${resolved_dependency}" >&2
      exit 1
      ;;
  esac
done < "${dependency_plan}"

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

(cd "${application_root}" && haxelib install \
  "${build_a}/${archive_name}" --always --quiet --skip-dependencies)
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
