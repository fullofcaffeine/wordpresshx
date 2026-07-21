#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

bash scripts/ownership/test-adr-contract.sh

for command_name in diff docker grep haxe haxelib lix node python3 realpath; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "SDK-041 production ownership gate requires ${command_name}" >&2
    exit 1
  fi
done
if [[ "$(haxe --version)" != "4.3.7" ]]; then
  echo "SDK-041 production ownership gate requires host Haxe 4.3.7" >&2
  exit 1
fi

lix_command="$(command -v lix)"
lix_bin_dir="$(cd "$(dirname "${lix_command}")" && pwd -P)"
lix_package_path="$(cd "$(dirname "$(realpath "${lix_command}")")/.." && pwd -P)/package.json"
lix_haxe="${lix_bin_dir}/haxe"
if [[ ! -f "${lix_package_path}" ]] \
  || [[ ! -x "${lix_haxe}" ]] \
  || [[ "$(node -p 'require(process.argv[1]).version' "${lix_package_path}")" != "15.12.4" ]] \
  || [[ "$(lix --version)" != "15.12.2" ]] \
  || [[ "$(basename "$(realpath "${lix_haxe}")")" != "haxeshim.js" ]]; then
  echo "SDK-041 production ownership gate requires Lix package 15.12.4 (CLI 15.12.2) and its Haxe shim" >&2
  exit 1
fi
if [[ "$(cd packages/cli && "${lix_haxe}" --version)" != "4.3.7" ]]; then
  echo "SDK-041 production ownership gate requires Lix-scoped Haxe 4.3.7" >&2
  exit 1
fi

docker info >/dev/null
(
  cd packages/cli
  lix --silent download
)
haxelib run formatter --check \
  -s packages/cli/src/wordpresshx/cli/ownership \
  -s packages/cli/test/ownership/src
python3 scripts/ownership/check-isolation.py --self-test

temporary_parent="$(python3 - <<'PY'
import os
import tempfile
print(os.path.realpath(tempfile.gettempdir()))
PY
)"
evidence_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk041-evidence.XXXXXX")"
replay_root="$(mktemp -d "${temporary_parent}/wordpresshx-sdk041-replay.XXXXXX")"
cleanup() {
  for temporary_root in "${evidence_root}" "${replay_root}"; do
    case "${temporary_root}" in
      "${temporary_parent}"/wordpresshx-sdk041-*) rm -rf -- "${temporary_root}" ;;
      *) echo "refusing to remove unexpected temporary path: ${temporary_root}" >&2 ;;
    esac
  done
}
trap cleanup EXIT

(
  cd packages/cli
  "${lix_haxe}" profiles/ownership-test.hxml \
    -js "${evidence_root}/runtime/index.js" \
    -D dump=record \
    -D dump-dependencies \
    -D "dump-path=${evidence_root}/compiler-dump"
  "${lix_haxe}" profiles/ownership-test.hxml -js "${replay_root}/runtime/index.js"
)
diff -ru "${evidence_root}/runtime" "${replay_root}/runtime"

node_image="docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
docker run --rm --network none "${node_image}" node --version | grep -Fx 'v22.17.0' >/dev/null
python3 scripts/ownership/test-production.py "${evidence_root}/runtime"
python3 scripts/ownership/check-isolation.py \
  --source-root packages/cli/src \
  --entry-root packages/cli/src/wordpresshx/cli/ownership \
  --dependencies "${evidence_root}/compiler-dump/js/dependencies.dump"

echo "SDK-041 ownership runtime-isolation allowlist scan passed"
echo "SDK-041 Haxe ownership transaction gate passed"
