# `gutenberg-forward-23.4` source authority

[`source.lock.json`](source.lock.json) records the exact Gutenberg `v23.4.0`
source commit and official release ZIP admitted by SDK-011. The network verifier
fetches the commit into a fresh temporary repository, proves that the lightweight
tag resolves directly to it, checks source blobs and plugin metadata, downloads
the official release asset, rejects unsafe or duplicate ZIP paths, and verifies
the complete file-content tree.

Run the source and release verification with:

```bash
python3 scripts/profiles/verify-gutenberg-forward-23-4.py
```

Run the offline selection and final-artifact leak fixtures with:

```bash
python3 scripts/profiles/check-profile-isolation.py
```

An explicit `--artifact-dir` may cache the checksum-locked ZIP between network
runs. Git source is always fetched directly into a fresh temporary repository;
sibling checkouts are never evidence inputs.

This profile is an opt-in peer of `wp70-release`, not its child or superset. It
has a distinct package identity, generated namespace, artifact root, and
manifest identity. Mixed imports and cross-profile final-artifact markers are
rejected. All capability evidence remains `inventoried`; WordPress runtime
compatibility and production support remain `not-tested`, and a WordPress 7.0
compatibility claim is explicitly forbidden.
