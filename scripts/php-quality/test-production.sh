#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tool_root="${repository_root}/tooling/php-quality"
temporary_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk026-gate.XXXXXX")"
cleanup() {
  case "${test_root}" in
    "${temporary_parent}"/wordpresshx-sdk026-gate.*) rm -rf -- "${test_root}" ;;
    *) echo "refusing to remove unexpected SDK-026 test path" >&2 ;;
  esac
}
trap cleanup EXIT

for command_name in haxe php python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-026 PHP quality gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-026 PHP quality gate requires Haxe 4.3.7" >&2
  exit 1
fi

bash "${repository_root}/scripts/php-quality/install.sh"
bash "${repository_root}/compiler/wordpress/scripts/test.sh"

for fixture in acme-books acme-books-adapters source-correlation/production-plugin; do
  receipt="${test_root}/$(echo "${fixture}" | tr '/' '-').receipt"
  replay="${receipt}.replay"
  php "${tool_root}/run.php" "${repository_root}/compiler/wordpress/build/${fixture}" >"${receipt}"
  php "${tool_root}/run.php" "${repository_root}/compiler/wordpress/build/${fixture}" >"${replay}"
  cmp "${receipt}" "${replay}"
done

python3 - "${test_root}" "${repository_root}" <<'PY'
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
repository = Path(sys.argv[2])
required = {
    "autoloadMode",
    "classmapEntries",
    "composerLockSha256",
    "formatChangedFiles",
    "phpFileCount",
    "phpStanPrivateLevel",
    "phpStanPublicLevel",
    "policyId",
    "policySha256",
    "privatePhpFileCount",
    "publicPhpFileCount",
    "schema",
    "status",
    "wordpressStubsSha256",
}
for receipt in sorted(root.glob("*.receipt")):
    fields = dict(line.split("=", 1) for line in receipt.read_text().splitlines())
    assert set(fields) == required
    assert fields["schema"] == "wordpress-hx.php-quality-run.v1"
    assert fields["status"] == "passed"
    assert fields["policyId"] == "wp70-release-generated-php-v1"
    assert fields["formatChangedFiles"] == "0"
    assert fields["phpStanPublicLevel"] == "6"
    for name in ("composerLockSha256", "policySha256", "wordpressStubsSha256"):
        assert len(fields[name]) == 64 and int(fields[name], 16) >= 0

source = repository / "compiler/wordpress/build/acme-books"
mutations = root / "mutations"


def clone(name: str) -> Path:
    target = mutations / name
    shutil.copytree(source, target)
    return target


target = clone("syntax")
with (target / "acme-books.php").open("a", encoding="utf-8") as stream:
    stream.write("\nfunction sdk026_broken(\n")

target = clone("formatter")
path = target / "includes/Bootstrap.php"
text = path.read_text()
changed = text.replace("private static bool $booted = false;", "private static bool $booted=false;")
assert changed != text
path.write_text(changed)

target = clone("wpcs-security")
path = target / "includes/Bootstrap.php"
text = path.read_text()
needle = "public static function boot(): void {\n"
changed = text.replace(needle, needle + "\t\teval( 'return true;' );\n")
assert changed != text
path.write_text(changed)

target = clone("phpstan")
path = target / "includes/Bootstrap.php"
text = path.read_text()
changed = text.replace("private static bool $booted = false;", "private static string $booted = 'no';")
assert changed != text
path.write_text(changed)

target = clone("duplicate-symbol")
shutil.copyfile(target / "includes/Bootstrap.php", target / "includes/BootstrapCopy.php")
PY

expect_failure() {
  local mutation="$1"
  local expected="$2"
  local stdout_path="${test_root}/${mutation}.out"
  local stderr_path="${test_root}/${mutation}.err"
  set +e
  php "${tool_root}/run.php" "${test_root}/mutations/${mutation}" >"${stdout_path}" 2>"${stderr_path}"
  local status=$?
  set -e
  if (( status != 6 )); then
    echo "${mutation} exited ${status}, expected 6" >&2
    sed -n '1,120p' "${stderr_path}" >&2
    exit 1
  fi
  if ! grep -F "${expected}" "${stderr_path}" >/dev/null; then
    echo "${mutation} did not fail through ${expected}" >&2
    sed -n '1,120p' "${stderr_path}" >&2
    exit 1
  fi
  if [[ -s "${stdout_path}" ]] \
    || grep -F "${test_root}" "${stderr_path}" >/dev/null \
    || grep -F "${repository_root}" "${stderr_path}" >/dev/null; then
    echo "${mutation} leaked output or a private absolute path" >&2
    sed -n '1,120p' "${stderr_path}" >&2
    exit 1
  fi
}

expect_failure syntax "PHP syntax lint"
expect_failure formatter "not formatter-stable"
expect_failure wpcs-security "WordPress Coding Standards"
expect_failure phpstan "PHPStan public level 6"
expect_failure duplicate-symbol "duplicate PHP symbol"

echo "SDK-026 pinned generated-PHP quality gate passed"
