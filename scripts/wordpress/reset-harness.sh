#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="${repository_root}/docker/wordpress/compose.yml"
lane="${1:-}"
project_name="${WORDPRESSHX_COMPOSE_PROJECT_NAME:-wordpresshx-sdk090}"

if [[ "${lane}" != "mysql" && "${lane}" != "mariadb" ]]; then
  echo "usage: $0 <mysql|mariadb>" >&2
  exit 2
fi

if [[ ! "${project_name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "invalid WORDPRESSHX_COMPOSE_PROJECT_NAME: ${project_name}" >&2
  exit 2
fi

docker compose \
  --project-name "${project_name}" \
  --file "${compose_file}" \
  --profile "${lane}" \
  down --volumes --remove-orphans
