#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
compiler_root="${repository_root}/compiler/reflaxe.php"
fixture_root="${package_root}/test/reflaxe-wordpress-consumer"
authored_root="${repository_root}/fixtures/reflaxe-wordpress-consumer"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-reflaxe-consumer.XXXXXX")"
trap 'rm -rf -- "${temporary_root}"' EXIT

compile_graph() {
	local output_root="$1"
	(
		cd "${compiler_root}"
		haxe ../wordpress/test/reflaxe-wordpress-consumer/build.hxml \
			-D "reflaxe_php_output=${output_root}"
	)
}

first_graph="${temporary_root}/graph-a"
second_graph="${temporary_root}/graph-b"
compile_graph "${first_graph}"
compile_graph "${second_graph}"
diff -ru "${first_graph}" "${second_graph}"
cmp \
	"${fixture_root}/expected/modules/18_wordpress_consumer/4_Main/4_Main.php" \
	"${first_graph}/modules/18_wordpress_consumer/4_Main/4_Main.php"

first_package="${temporary_root}/package-a"
second_package="${temporary_root}/package-b"
python3 "${package_root}/scripts/package-reflaxe-module-graph.py" \
	--graph-root "${first_graph}" \
	--output-root "${first_package}"
python3 "${package_root}/scripts/package-reflaxe-module-graph.py" \
	--graph-root "${second_graph}" \
	--output-root "${second_package}"
diff -ru "${first_package}" "${second_package}"

python3 - \
	"${first_graph}" \
	"${first_package}/wordpresshx-reflaxe-module-proof.zip" \
	"${first_package}/wordpresshx-reflaxe-module-package.json" <<'PY'
import hashlib
import json
import sys
import zipfile
from pathlib import Path

graph_root = Path(sys.argv[1])
archive_path = Path(sys.argv[2])
manifest_path = Path(sys.argv[3])
graph = json.loads((graph_root / "reflaxe.php-artifacts.json").read_text(encoding="utf-8"))
package = json.loads(manifest_path.read_text(encoding="utf-8"))
assert package["claims"]["wordpressRuntimeCompatibility"] == "not-claimed"
assert package["package"]["sha256"] == hashlib.sha256(archive_path.read_bytes()).hexdigest()
assert graph["entrypoint"]["identity"] == "wordpress_consumer.Main@Main"
assert graph["loadOrder"] == ["modules/18_wordpress_consumer/4_Main/4_Main.php"]
with zipfile.ZipFile(archive_path) as archive:
    names = archive.namelist()
    assert names == sorted(names)
    assert "wordpresshx-reflaxe-module-proof/wordpresshx-reflaxe-module-proof.php" in names
    assert (
        "wordpresshx-reflaxe-module-proof/includes/application/"
        "modules/18_wordpress_consumer/4_Main/4_Main.php"
    ) in names
    assert not any(name.endswith((".map", ".map.json", ".haxe-map.json", ".hx")) for name in names)
PY

if rg -n 'reflaxe\.php\.(ir|compiler)' "${authored_root}"; then
	echo "WordPress consumer imports compiler implementation or PHP IR" >&2
	exit 1
fi
if find "${authored_root}" -type f -name '*.php' -print -quit | grep -q .; then
	echo "WordPress consumer contains handwritten PHP" >&2
	exit 1
fi
python3 "${repository_root}/scripts/lint/haxe-weak-type-guard.py" \
	"${package_root}/src" \
	"${authored_root}"

echo "WordPress ordinary-Haxe reflaxe.php consumer package passed"
