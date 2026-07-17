#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

required_files=(
  .gitleaks.toml
  .github/workflows/repository.yml
  .beads/hooks/pre-commit
  .beads/hooks/pre-push
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
  docs/adr/004-generic-php-compiler-home.md
  docs/architecture/browser-compiler.md
  docs/architecture/php-compiler.md
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
  manifests/evidence/sdk-020-reflaxe-php-bootstrap.json
  compiler/reflaxe.php/haxelib.json
  compiler/reflaxe.php/provenance.json
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpArrayEntry.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpExpr.hx
  compiler/reflaxe.php/src/reflaxe/php/ir/PhpStmt.hx
  compiler/reflaxe.php/src/reflaxe/php/print/PhpPrinter.hx
  compiler/reflaxe.php/test/reflaxe/php/tests/PrinterTest.hx
  compiler/reflaxe.php/scripts/test.sh
  scripts/beads/push-safe.sh
  scripts/ci/check-security-tooling.sh
  scripts/ci/install-gitleaks.sh
  scripts/hooks/install.sh
  scripts/hooks/pre-commit
  scripts/hooks/pre-push
  scripts/hooks/test.sh
  scripts/lint/hx-format-guard.sh
  scripts/lint/local-path-guard-staged.sh
  scripts/lint/whitespace-guard.sh
  scripts/security/run-beads-gitleaks.sh
  scripts/security/run-gitleaks.sh
  scripts/security/run-local-path-audit.sh
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
import hashlib
import json
import re
from pathlib import Path

lock = json.loads(Path("manifests/upstream.lock.json").read_text(encoding="utf-8"))
receipt = json.loads(
    Path("manifests/evidence/sdk-030-genes-ts-v1.33.0.json").read_text(
        encoding="utf-8"
    )
)
php_provenance = json.loads(
    Path("compiler/reflaxe.php/provenance.json").read_text(encoding="utf-8")
)
php_receipt = json.loads(
    Path("manifests/evidence/sdk-020-reflaxe-php-bootstrap.json").read_text(
        encoding="utf-8"
    )
)
haxelib = json.loads(
    Path("compiler/reflaxe.php/haxelib.json").read_text(encoding="utf-8")
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

assert php_provenance["schemaVersion"] == 1
assert php_provenance["component"] == "reflaxe.php"
assert sha1.fullmatch(php_provenance["origin"]["commit"])
assert sha1.fullmatch(php_provenance["origin"]["tree"])
assert php_provenance["destination"]["releaseEligible"] is False
assert php_provenance["review"]["publicationAuthorized"] is False
assert haxelib["name"] == "reflaxe.php"
assert haxelib["version"] == "0.0.0"
assert haxelib["license"] == "GPL"
assert haxelib["url"] == ""
assert php_receipt["schemaVersion"] == 1
assert php_receipt["receiptId"] == "SDK-020-REFLAXE-PHP-BOOTSTRAP"
assert php_receipt["subject"]["canonicalRepositoryUrl"] is None
assert php_receipt["subject"]["repositoryUrlFollowup"] == "wordpresshx-sdk-004"
assert php_receipt["subject"]["originCommit"] == php_provenance["origin"]["commit"]
assert php_receipt["subject"]["originTree"] == php_provenance["origin"]["tree"]
assert php_receipt["localVerification"]["packageTest"]["outcome"] == "passed"
assert php_receipt["localVerification"]["php84"]["runtimeOutcome"] == "passed"
assert php_receipt["localVerification"]["php74"]["outcome"] == "not-tested"
assert php_receipt["claims"]["wordpressSupport"] == "not-tested"

package_root = Path("compiler/reflaxe.php")
package_files = sorted(
    (
        path
        for path in package_root.rglob("*")
        if path.is_file() and "build" not in path.relative_to(package_root).parts
    ),
    key=lambda path: path.as_posix(),
)
package_digest_input = bytearray()
for path in package_files:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    package_digest_input.extend(f"{digest}  {path.as_posix()}\n".encode())
package_digest = hashlib.sha256(package_digest_input).hexdigest()
assert package_digest == php_receipt["subject"]["packageContentSha256"]

generic_haxe_files = list((package_root / "src").rglob("*.hx")) + list(
    (package_root / "test").rglob("*.hx")
)
for path in generic_haxe_files:
    content = path.read_text(encoding="utf-8").lower()
    for forbidden in (
        "wordpress",
        "gutenberg",
        "wphx",
        "@:wp.",
        "wordpresshx-port",
        "compiler/wordpress",
    ):
        assert forbidden not in content, f"generic compiler coupling in {path}: {forbidden}"
assert "PhpRawBlock" not in "\n".join(
    path.read_text(encoding="utf-8") for path in generic_haxe_files
)

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

floating_reflaxe_dependency_pattern='haxelib[[:space:]]+dev[[:space:]]+reflaxe([^[:alnum:]_.-]|$)|(^|[[:space:]])-cp[[:space:]]+\.\./haxe\.compilerdev\.reference/reflaxe([^[:alnum:]_.-]|$)'
if git grep -nE "${floating_reflaxe_dependency_pattern}" -- \
  '*.hx' '*.hxml' '*.json' '*.yaml' '*.yml' '*.xml' \
  ':!.beads/**' ':!manifests/evidence/**' ':!compiler/reflaxe.php/provenance.json' \
  > "${scan_output}" 2>/dev/null; then
  echo "floating dependency on a sibling Reflaxe checkout detected:" >&2
  sed -n '1,80p' "${scan_output}" >&2
  exit 1
fi

git diff --check HEAD

bash scripts/ci/check-security-tooling.sh

echo "repository bootstrap checks passed"
