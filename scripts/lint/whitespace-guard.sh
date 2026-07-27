#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

# This downloaded Oracle report is immutable review evidence. Its Markdown
# hard-break spaces are authenticated by scripts/check-repository.sh.
oracle_report_exclusion=':!review/oracle/results/adr019-review-9b855b9/ORACLE-ADR019-REVIEW.md'

if [[ "${1:-}" == "--staged" ]]; then
  git diff --cached --check -- . "${oracle_report_exclusion}"
elif [[ $# -eq 0 ]]; then
  git diff --check -- . "${oracle_report_exclusion}"
else
  echo "usage: $0 [--staged]" >&2
  exit 2
fi
