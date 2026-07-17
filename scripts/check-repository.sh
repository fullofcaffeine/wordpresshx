#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  AGENTS.md
  README.md
  GOVERNANCE.md
  CONTRIBUTING.md
  SECURITY.md
  SUPPORT.md
  CHANGELOG.md
  LICENSES/README.md
  wordpress-hx-sdk-product-requirements.md
  docs/README.md
  docs/adr/README.md
  docs/adr/001-product-and-repository-boundary.md
  docs/architecture/browser-compiler.md
  docs/architecture/repository-layout.md
  docs/product/README.md
  docs/release/README.md
  packages/README.md
  compiler/README.md
  profiles/README.md
  schemas/README.md
  tools/README.md
  examples/README.md
  fixtures/README.md
  test/README.md
  docker/README.md
  manifests/README.md
  manifests/upstream.lock.json
  manifests/evidence/sdk-030-genes-ts-v1.33.0.json
)

missing=0
for path in "${required_files[@]}"; do
  if [[ ! -s "${path}" ]]; then
    echo "missing or empty required bootstrap file: ${path}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 1
fi

for path in "${required_files[@]}"; do
  if ! git ls-files --error-unmatch -- "${path}" >/dev/null 2>&1; then
    echo "required bootstrap file is not tracked: ${path}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 1
fi

python3 - <<'PY'
import json
import re
from pathlib import Path

lock = json.loads(Path("manifests/upstream.lock.json").read_text(encoding="utf-8"))
receipt = json.loads(
    Path("manifests/evidence/sdk-030-genes-ts-v1.33.0.json").read_text(
        encoding="utf-8"
    )
)
adr = Path("docs/adr/001-product-and-repository-boundary.md").read_text(
    encoding="utf-8"
)
readme = Path("README.md").read_text(encoding="utf-8")

entry = lock["entries"]["genes-ts"]
subject = receipt["subject"]
sha1 = re.compile(r"[0-9a-f]{40}\Z")
sha256 = re.compile(r"[0-9a-f]{64}\Z")

assert lock["schemaVersion"] == 1
assert lock["lockStatus"] == "partial"
assert receipt["schemaVersion"] == 1
assert receipt["receiptId"] in entry["testReceiptIds"]
assert entry["version"] == subject["version"] == "1.33.0"
assert entry["releaseTag"] == subject["releaseTag"] == "v1.33.0"
assert entry["commit"] == subject["commit"]
assert entry["tree"] == subject["tree"]
assert sha1.fullmatch(entry["commit"])
assert sha1.fullmatch(entry["tree"])
assert entry["releaseArtifact"]["sha256"] == subject["releaseArtifact"]["sha256"]
assert sha256.fullmatch(entry["releaseArtifact"]["sha256"])
assert receipt["localVerification"]["releaseGate"]["outcome"] == "passed"
assert receipt["changeDecision"]["genesSourceChanged"] is False
assert receipt["changeDecision"]["upstreamPullRequest"] is None

for status in (
    "inventoried",
    "typed",
    "generated",
    "runtime-tested",
    "production-supported",
    "not-tested",
    "failed",
    "not-applicable",
    "unsupported",
    "withdrawn",
):
    assert f"`{status}`" in adr

for claim_field in ("wp70-release", "gutenberg-forward-23.4", "WordPressHx"):
    assert claim_field in adr
    assert claim_field in readme
PY

forbidden_dependency_pattern='\.\./wordpresshx-port|wordpresshx-port/(src|compiler|packages)|haxelib[[:space:]]+dev[^[:cntrl:]]*wordpresshx-port'
scan_output="$(mktemp)"
trap 'rm -f "${scan_output}"' EXIT
if git grep -nE "${forbidden_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!docs/**' ':!wordpress-hx-sdk-product-requirements.md' \
  > "${scan_output}" 2>/dev/null; then
  echo "direct dependency on wordpresshx-port internals detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

floating_genes_dependency_pattern='(file:|link:)[^[:cntrl:]]*\.\./genes|haxelib[[:space:]]+dev[[:space:]]+genes([^[:alnum:]_.-]|$)|(^|[[:space:]])-cp[[:space:]]+\.\./genes([^[:alnum:]_.-]|$)'
if git grep -nE "${floating_genes_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!manifests/evidence/**' \
  > "${scan_output}" 2>/dev/null; then
  echo "floating dependency on the sibling genes checkout detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

git diff --check HEAD

echo "repository bootstrap checks passed"
