#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WORDPRESSHX_COMPOSE_PROJECT_NAME="wordpresshx-reflaxe-consumer" \
	bash "${package_root}/scripts/run-reflaxe-wordpress-consumer-lane.sh"
