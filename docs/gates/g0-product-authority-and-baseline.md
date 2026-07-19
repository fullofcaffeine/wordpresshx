# G0 — Product authority and baseline lock

Gate G0 may close because the SDK now has independent task, repository, profile,
package, toolchain, evidence, security, and release authority. Closure means the
project may begin the bounded G1–G3 feasibility work. It is not a WordPress SDK
compatibility, package publication, or production-support claim.

## Evidence map

| G0 requirement | Authority |
|---|---|
| Independent repository, Git/Beads remotes, hooks, security, governance, and release skeleton | `SDK-004-CANONICAL-REPOSITORY`, `SDK-003-RELEASE-GOVERNANCE` |
| Product/repository boundary and claim separation | ADR-001 |
| Exact peer profiles | ADR-002, `SDK-010-WP70-RELEASE-SOURCE`, `SDK-011-GUTENBERG-FORWARD-23.4` |
| Monorepo/package boundary | ADR-003 and `manifests/package-topology.json` |
| Generic PHP compiler home | ADR-004 and `SDK-020-REFLAXE-PHP-BOOTSTRAP` |
| API classification and evidence vocabulary | ADR-008, `SDK-012-PROFILE-SCHEMA`, `SDK-013-PROFILE-GENERATOR` |
| Exact aggregate toolchain baseline | `manifests/toolchain.lock.json` |
| Full-port separation | compiler provenance, generic-source scan, and repository local-path/import gates |
| Reference hashes and snapshot method | `G0-PRODUCT-AUTHORITY-BASELINE` reference-artifact ledger |

The aggregate toolchain lock makes absence explicit. Composer and a root npm
graph were not active inputs when G0 closed. Later gates may extend this same
lock only through a bounded, receipt-backed admission. SDK-026 therefore adds
one exact Composer graph for build-time generated-PHP validation while keeping
runtime packages empty, deployment artifacts independent of Composer, and
publication blocked. Haxelib and npm build inputs that do exist are pinned
through artifact hashes, commits/trees, or a closed transitive lock. An omitted
future dependency is unresolved, never implicitly permitted.

## Licensing is still a release blocker

The PRD assigns the licensing decision a **before any public release** deadline.
Its G0 criteria do not require ADR-020 acceptance, and its backlog makes SDK-002
depend on SDK-000 rather than on the feasibility gates. The release candidate
still depends on SDK-002.

Accordingly, ADR-020 remains proposed, SDK-002 remains open, no root license
grant is inferred, and the mechanical publication gate remains blocked. This
lets experimental compiler work proceed without manufacturing a legal decision
or allowing public packages, release archives, or production claims.

## Verification

```bash
python3 scripts/gates/test-g0-baseline.py
bash scripts/check-repository.sh
```

The validator checks the closed receipt schema, accepted decisions, cross-file
toolchain identities, exact source/profile/artifact hashes, generic compiler
boundary, generated catalog digests, hosted status, and publication block. Its
negative tests mutate compiler versions, image identities, dependency state,
decision coverage, port coupling, hosted evidence, and publication authority.
