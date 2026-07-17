#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/wordpresshx-sdk013.XXXXXX")"
trap 'rm -rf "${temporary_root}"' EXIT

repository_arguments=()
fetch_arguments=()
wordpress_repository="${WORDPRESSHX_WORDPRESS_REPOSITORY:-}"
embedded_repository="${WORDPRESSHX_EMBEDDED_GUTENBERG_REPOSITORY:-}"
forward_repository="${WORDPRESSHX_FORWARD_GUTENBERG_REPOSITORY:-}"

provided=0
[[ -n "${wordpress_repository}" ]] && provided=$((provided + 1))
[[ -n "${embedded_repository}" ]] && provided=$((provided + 1))
[[ -n "${forward_repository}" ]] && provided=$((provided + 1))
if (( provided != 0 && provided != 3 )); then
  echo "set all three WORDPRESSHX_*_REPOSITORY overrides or none" >&2
  exit 1
fi

if (( provided == 3 )); then
  repository_arguments=(
    --repository "wordpress=${wordpress_repository}"
    --repository "embedded-gutenberg=${embedded_repository}"
    --repository "forward-gutenberg=${forward_repository}"
  )
else
  fetch_arguments=(--fetch-missing --cache-root "${temporary_root}/cache")
fi

generate() {
  local output_root="$1"
  if (( provided == 3 )); then
    python3 "${repository_root}/scripts/profiles/generate-catalogs.py" \
      "${repository_arguments[@]}" \
      --output-root "${output_root}"
  else
    python3 "${repository_root}/scripts/profiles/generate-catalogs.py" \
      "${fetch_arguments[@]}" \
      --output-root "${output_root}"
  fi
}

generate "${temporary_root}/run-one"
generate "${temporary_root}/run-two"
diff -ru "${temporary_root}/run-one" "${temporary_root}/run-two"
diff -ru "${repository_root}/generated" "${temporary_root}/run-one"

if grep -R -F -- "${temporary_root}" "${temporary_root}/run-one" >/dev/null; then
  echo "generated catalog leaked its materialization path" >&2
  exit 1
fi

if (( provided == 0 )); then
  wordpress_repository="${temporary_root}/cache/wordpress"
  embedded_repository="${temporary_root}/cache/embedded-gutenberg"
  forward_repository="${temporary_root}/cache/forward-gutenberg"
fi

negative_log="${temporary_root}/wrong-repository.log"
if python3 "${repository_root}/scripts/profiles/generate-catalogs.py" \
  --repository "wordpress=${embedded_repository}" \
  --repository "embedded-gutenberg=${embedded_repository}" \
  --repository "forward-gutenberg=${forward_repository}" \
  --output-root "${temporary_root}/negative-output" \
  >"${negative_log}" 2>&1; then
  echo "generator accepted a repository without the exact WordPress commit" >&2
  exit 1
fi
grep -F -- "repository is missing exact commit" "${negative_log}" >/dev/null
if [[ -e "${temporary_root}/negative-output" ]]; then
  echo "failed generation published a partial output tree" >&2
  exit 1
fi

python3 "${repository_root}/scripts/profiles/check-generated-catalogs.py"
echo "SDK-013 exact profile generator tests passed"
