# ADR-017 generated-output VCS fixtures

This source-only project drives the synthetic Git and release rehearsal in
`scripts/generated-output-vcs/test-policy.py`. It deliberately does not exercise
the production PHP compiler, Genes, WordPress, or a publish operation. The
fixture isolates the version-control contract:

- authored Haxe and exact fixture tool identities are committed;
- default consumer build and distribution roots are ignored;
- a closed explicit per-root policy admits committed output and rejects absent,
  extra, nested, or inferred roots before comparing exact bytes and provenance;
- reviewed SDK goldens compare against a new private stage; and
- release rehearsal clones a clean commit, regenerates twice outside the
  checkout, and compares deterministic archives.

The generated PHP and JavaScript are test carriers only. They make no syntax,
runtime, compatibility, quality, or production claim.
