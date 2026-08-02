#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compiler_root="${repository_root}/compiler/reflaxe.php"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-reflaxe-module-package.XXXXXX")"
trap 'rm -rf -- "${temporary_root}"' EXIT

if [[ "$(haxe --version)" != "4.3.7" ]]; then
	echo "WordPress reflaxe.php package proof requires Haxe 4.3.7" >&2
	exit 1
fi

graph_root="${temporary_root}/graph"
(
	cd "${compiler_root}"
	haxe test/compiler-tracer/build.hxml -D "reflaxe_php_output=${graph_root}"
)

first_package="${temporary_root}/package-a"
second_package="${temporary_root}/package-b"
for output_root in "${first_package}" "${second_package}"; do
	python3 "${package_root}/scripts/package-reflaxe-module-graph.py" \
		--graph-root "${graph_root}" \
		--output-root "${output_root}"
done
diff -ru "${first_package}" "${second_package}"

archive_name="wordpresshx-reflaxe-module-proof.zip"
archive_path="${first_package}/${archive_name}"
package_manifest="${first_package}/wordpresshx-reflaxe-module-package.json"
extract_root="${temporary_root}/extracted"
python3 - "${graph_root}" "${archive_path}" "${package_manifest}" "${extract_root}" <<'PY'
import hashlib
import json
import sys
import zipfile
from pathlib import Path, PurePosixPath

graph_root = Path(sys.argv[1])
archive_path = Path(sys.argv[2])
manifest_path = Path(sys.argv[3])
extract_root = Path(sys.argv[4])
package = json.loads(manifest_path.read_text(encoding="utf-8"))
graph = json.loads((graph_root / "reflaxe.php-artifacts.json").read_text(encoding="utf-8"))
assert package["format"] == "wordpresshx.reflaxe-module-package.v1", "package format drifted"
assert package["sourceGraph"]["loadOrder"] == graph["loadOrder"], "source graph load order drifted"
assert package["package"]["sourceMapsIncluded"] is False, "source maps entered the runtime package"
assert package["claims"] == {
    "deterministicPackage": True,
    "moduleGraphPreserved": True,
    "publicationAuthorized": False,
    "wordpressRuntimeCompatibility": "not-claimed",
}, "package claims drifted"
assert package["package"]["sha256"] == hashlib.sha256(archive_path.read_bytes()).hexdigest(), "archive digest drifted"
expected_runtime = {artifact["path"] for artifact in graph["artifacts"]}
with zipfile.ZipFile(archive_path) as archive:
    entries = archive.namelist()
    assert entries == sorted(entries), "archive entries are not sorted"
    assert all(not entry.endswith((".map", ".map.json", ".haxe-map.json")) for entry in entries), "source map entered archive"
    packaged_runtime = {
        entry.removeprefix("wordpresshx-reflaxe-module-proof/includes/application/")
        for entry in entries
        if entry.startswith("wordpresshx-reflaxe-module-proof/includes/application/")
    }
    assert packaged_runtime == expected_runtime, f"runtime inventory drifted: expected={sorted(expected_runtime)} actual={sorted(packaged_runtime)}"
    for info in archive.infolist():
        assert info.date_time == (1980, 1, 1, 0, 0, 0), f"archive timestamp drifted: {info.filename}"
        relative = PurePosixPath(info.filename)
        destination = extract_root.joinpath(*relative.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        data = archive.read(info)
        destination.write_bytes(data)
        assert not any(marker in data for marker in (b"/Users/", b"/home/", b"workspace/code")), f"machine path leaked: {info.filename}"
for artifact in graph["artifacts"]:
    packaged = (
        extract_root
        / "wordpresshx-reflaxe-module-proof"
        / "includes"
        / "application"
        / artifact["path"]
    ).read_bytes()
    assert hashlib.sha256(packaged).hexdigest() == artifact["sha256"], f"packaged artifact digest drifted: {artifact['path']}"
PY

while IFS= read -r php_file; do
	php -l "${php_file}" >/dev/null
done < <(find "${extract_root}" -type f -name '*.php' | sort)

plugin_root="${extract_root}/wordpresshx-reflaxe-module-proof/wordpresshx-reflaxe-module-proof.php"
guard_output="$(php "${plugin_root}")"
if [[ -n "${guard_output}" ]]; then
	echo "packaged WordPress root produced output without ABSPATH" >&2
	exit 1
fi
php -d error_reporting=-1 -d display_errors=1 -r \
	'define("ABSPATH", __DIR__); require $argv[1];' "${plugin_root}" \
	>"${temporary_root}/packaged.stdout" 2>"${temporary_root}/packaged.stderr"
test ! -s "${temporary_root}/packaged.stderr"
cmp "${compiler_root}/test/compiler-tracer/expected.stdout" "${temporary_root}/packaged.stdout"

mutated_graph="${temporary_root}/mutated-graph"
cp -rf "${graph_root}" "${mutated_graph}"
printf '\n' >>"${mutated_graph}/modules/6_tracer/4_Main/4_Main.php"
set +e
mutation_diagnostic="$(
	python3 "${package_root}/scripts/package-reflaxe-module-graph.py" \
		--graph-root "${mutated_graph}" \
		--output-root "${temporary_root}/mutated-package" 2>&1
)"
mutation_status=$?
set -e
if (( mutation_status == 0 )) || [[ "${mutation_diagnostic}" != *"stale PHP digest"* ]]; then
	printf '%s\n' "${mutation_diagnostic}" >&2
	echo "WordPress packager accepted a stale compiler module" >&2
	exit 1
fi
if [[ -d "${temporary_root}/mutated-package" ]] \
	&& find "${temporary_root}/mutated-package" -type f -print -quit | grep -q .; then
	echo "failed WordPress package validation published a partial package" >&2
	exit 1
fi

echo "WordPress compiler packaged and booted the exact reflaxe.php module graph"
