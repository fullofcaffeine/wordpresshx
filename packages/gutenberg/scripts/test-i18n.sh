#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="$(git -C "${package_root}" rev-parse --show-toplevel)"
node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
php74_image="docker.io/library/php@sha256:620a6b9f4d4feef2210026172570465e9d0c1de79766418d3affd09190a7fda5"
php84_image="docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367"
skip_wordpress=false

if [[ "${1:-}" == "--skip-wordpress" ]]; then
	skip_wordpress=true
	shift
fi
if (( $# != 0 )); then
	echo "usage: $0 [--skip-wordpress]" >&2
	exit 2
fi

for command_name in docker git haxe haxelib lix node npm python3; do
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "SDK-055 i18n gate requires ${command_name}" >&2
		exit 1
	fi
done
docker info >/dev/null

lix_package_path="$(npm root --global)/lix/package.json"
lix_haxe="$(npm prefix --global)/bin/haxe"
if [[ ! -f "${lix_package_path}" ]] \
	|| [[ ! -x "${lix_haxe}" ]] \
	|| [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
	|| [[ "$(lix --version)" != "15.12.2" ]] \
	|| [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
	echo "SDK-055 requires npm package Lix 15.12.4 (CLI reports 15.12.2)" >&2
	exit 1
fi
if [[ "$(cd "${package_root}" && "${lix_haxe}" --version)" != "4.3.7" ]]; then
	echo "SDK-055 requires Lix-scoped Haxe 4.3.7" >&2
	exit 1
fi

haxe_library_cache="$(node -e '
	const os = require("node:os");
	const path = require("node:path");
	const haxeRoot =
		process.env.HAXE_ROOT ||
		process.env.HAXESHIM_ROOT ||
		path.join(os.homedir(), "haxe");
	process.stdout.write(
		process.env.HAXESHIM_LIBCACHE ||
		process.env.HAXE_LIBCACHE ||
		path.join(haxeRoot, "haxe_libraries")
	);
')"
genes_root="${haxe_library_cache}/genes-ts/1.41.4/github/98a51bdb7a5a1e31002b9ba47855d41905ea48ef/src"
helder_root="${haxe_library_cache}/helder.set/0.3.1/haxelib/src"
if [[ ! -f "${genes_root}/genes/Register.hx" ]] \
	|| [[ ! -f "${helder_root}/helder/Set.hx" ]]; then
	(
		cd "${package_root}"
		lix --silent download
	)
fi
python3 "${package_root}/scripts/verify-dependency-lock.py" --metadata-only
haxelib run formatter --check \
	-s "${repository_root}/packages/core/src/wordpress/hx/i18n" \
	-s "${package_root}/src/wordpress/hx/gutenberg/i18n" \
	-s "${package_root}/test/i18n-fixture/src" \
	-s "${package_root}/test-negative-i18n" \
	-s "${repository_root}/compiler/wordpress/src/wordpress/hx/compiler/php/profile" \
	-s "${repository_root}/compiler/reflaxe.php/src/reflaxe/php/ir" \
	-s "${repository_root}/compiler/reflaxe.php/src/reflaxe/php/print" \
	-s "${repository_root}/compiler/reflaxe.php/test/reflaxe/php/tests"

weak_type_guard="${repository_root}/scripts/lint/haxe-weak-type-guard.py"
python3 "${weak_type_guard}" --self-test
python3 "${weak_type_guard}" \
	"${repository_root}/packages/core/src/wordpress/hx/i18n" \
	"${package_root}/src/wordpress/hx/gutenberg/i18n" \
	"${package_root}/test/i18n-fixture/src" \
	"${package_root}/test-negative-i18n" \
	"${repository_root}/compiler/wordpress/src/wordpress/hx/compiler/php/profile" \
	"${repository_root}/compiler/reflaxe.php/src/reflaxe/php/ir" \
	"${repository_root}/compiler/reflaxe.php/src/reflaxe/php/print"
(
	cd "${repository_root}/compiler/reflaxe.php"
	haxe test.hxml
)

temporary_parent="${package_root}/.sdk055-tmp"
mkdir -p "${temporary_parent}"
build_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk055-build.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk055-replay.XXXXXX")"
tooling_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk055-tooling.XXXXXX")"
negative_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk055-negative.XXXXXX")"

cleanup() {
	for temporary_root in "${negative_root}" "${tooling_root}" "${replay_root}" "${build_root}"; do
		case "${temporary_root}" in
			"${temporary_parent}"/wordpresshx-sdk055-*) rm -rf -- "${temporary_root}" || true ;;
			*) echo "refusing to remove unexpected SDK-055 path: ${temporary_root}" >&2 ;;
		esac
	done
	rmdir "${temporary_parent}" 2>/dev/null || true
}
trap cleanup EXIT

compile_browser() {
	local output_root="$1"
	(
		cd "${package_root}"
		"${lix_haxe}" profiles/i18n-strict.hxml -js "${output_root}/messages.ts"
	)
	cp -f "${package_root}/build-tooling/package.json" "${output_root}/package.json"
}

compile_browser "${build_root}"
compile_browser "${replay_root}"
diff -ru --exclude='.genes-output-*' "${build_root}" "${replay_root}"
if ! grep -R -F --include='*.ts' 'from "@wordpress/i18n"' "${build_root}" >/dev/null; then
	echo "SDK-055 generated browser source omitted the native @wordpress/i18n import" >&2
	exit 1
fi

cp -f "${package_root}/build-tooling/package.json" "${tooling_root}/package.json"
cp -f "${package_root}/build-tooling/package-lock.json" "${tooling_root}/package-lock.json"
cp -f "${package_root}/build-tooling/webpack.config.cjs" "${tooling_root}/webpack.config.cjs"
cp -f "${package_root}/scripts/run-i18n-playwright.mjs" "${tooling_root}/run-i18n-playwright.mjs"

container_build_root="/repo/packages/gutenberg/.sdk055-tmp/$(basename "${build_root}")"
container_replay_root="/repo/packages/gutenberg/.sdk055-tmp/$(basename "${replay_root}")"
docker run --rm \
	--user "$(id -u):$(id -g)" \
	--tmpfs /tmp:rw,exec,nosuid,nodev \
	-e npm_config_cache=/tmp/npm-cache \
	-v "${repository_root}:/repo" \
	-v "${tooling_root}:/tooling" \
	-w /tooling \
	"${node_image}" \
	sh -eu -c '
		test "$(node --version)" = "v22.17.0"
		test "$(npm --version)" = "10.9.2"
		npm ci --ignore-scripts --no-audit --no-fund
		for root in "$1" "$2"; do
			ln -s /tooling/node_modules "${root}/node_modules"
			(
				cd "${root}"
				node /tooling/node_modules/@wordpress/scripts/bin/wp-scripts.js \
					build messages.ts \
					--config /tooling/webpack.config.cjs \
					--output-path build
			)
		done
	' _ "${container_build_root}" "${container_replay_root}"
diff -ru "${build_root}/build" "${replay_root}/build"

(
	cd "${package_root}"
	"${lix_haxe}" \
		-cp ../core/src \
		-cp ../../compiler/reflaxe.php/src \
		-cp ../../compiler/wordpress/src \
		-cp test/i18n-fixture/src \
		--run sdk055.fixture.ContractMain \
		"${build_root}/build/messages.js" \
		"${build_root}/build/messages.asset.php"
)

emit_artifact() {
	local output_root="$1"
	(
		cd "${package_root}"
		"${lix_haxe}" \
			-cp ../core/src \
			-cp ../../compiler/reflaxe.php/src \
			-cp ../../compiler/wordpress/src \
			-cp test/i18n-fixture/src \
			--run sdk055.fixture.ArtifactMain \
			"${output_root}/build/messages.js" \
			"${output_root}/build/messages.asset.php" \
			"${output_root}/wordpress-plugin"
	)
}

emit_artifact "${build_root}"
emit_artifact "${replay_root}"
diff -ru "${build_root}/wordpress-plugin" "${replay_root}/wordpress-plugin"
python3 "${package_root}/scripts/verify-i18n.py" "${build_root}/wordpress-plugin"

expect_compile_failure() {
	local label="$1"
	local expected="$2"
	local output="${negative_root}/${label}.txt"
	if (
		cd "${package_root}"
		"${lix_haxe}" \
			-lib genes-ts \
			-cp ../core/src \
			-cp src \
			-cp test/i18n-fixture/src \
			-cp "test-negative-i18n/${label}" \
			-main Main \
			-D wordpress_hx_profile=wp70-release \
			-D genes.ts \
			-D genes.ts.no_extension \
			-D js-es=6 \
			-dce full \
			-js "${negative_root}/${label}.ts"
	) >"${output}" 2>&1; then
		echo "negative i18n fixture unexpectedly compiled: ${label}" >&2
		exit 1
	fi
	if ! grep -F -- "${expected}" "${output}" >/dev/null \
		|| ! grep -F -- "test-negative-i18n/${label}/Main.hx" "${output}" >/dev/null; then
		echo "negative i18n fixture failed for the wrong reason: ${label}" >&2
		sed -n '1,140p' "${output}" >&2
		exit 1
	fi
}

expect_compile_failure dynamic_key WPX5500
expect_compile_failure placeholder_shape WPX5504
expect_compile_failure translation_placeholder WPX5508
expect_compile_failure missing_argument "Not enough arguments"
expect_compile_failure extra_argument "Too many arguments"
expect_compile_failure wrong_count "String should be Int"
expect_compile_failure wrong_domain WPX5504

for image in "${php74_image}" "${php84_image}"; do
	docker run --rm --network none \
		--mount "type=bind,src=${build_root}/wordpress-plugin,dst=/plugin,readonly" \
		"${image}" \
		sh -eu -c 'find /plugin -type f -name "*.php" -exec php -l {} \;'
done

if [[ -n "${SDK055_I18N_OUTPUT:-}" ]]; then
	mkdir -p -- "${SDK055_I18N_OUTPUT}"
	retained_output="$(cd "${SDK055_I18N_OUTPUT}" && pwd -P)"
	case "${retained_output}" in
		/|"${repository_root}"|"${package_root}")
			echo "refusing unsafe SDK055_I18N_OUTPUT: ${retained_output}" >&2
			exit 1
			;;
	esac
	rm -rf -- "${retained_output}/wordpress-plugin"
	cp -rf "${build_root}/wordpress-plugin" "${retained_output}/wordpress-plugin"
	echo "SDK-055 i18n artifact written to ${retained_output}"
fi

if [[ "${skip_wordpress}" != "true" ]]; then
	bash "${package_root}/scripts/run-wordpress-i18n-lane.sh" \
		"${build_root}/wordpress-plugin" \
		"${tooling_root}"
fi

echo "SDK-055 typed internationalization gate passed"
