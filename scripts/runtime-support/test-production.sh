#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "${repository_root}"

bash scripts/runtime-support/test.sh
bash scripts/runtime-support/test-php-matrix.sh
bash scripts/runtime-support/test-wordpress.sh
