# `wp70-release` source authority

[`source.lock.json`](source.lock.json) records the exact WordPress 7.0 source, embedded Gutenberg commit, and official release archives admitted by SDK-010. The network verifier fetches both Git commits into fresh temporary repositories, resolves the official WordPress tag, downloads both official archives, rejects unsafe archive paths, and proves that the tar/ZIP file trees are byte-identical.

Run the complete verification with:

```bash
python3 scripts/profiles/verify-wp70-release.py
```

An explicit `--artifact-dir` may cache the two checksum-locked archives between runs. Git source is always fetched directly into a fresh temporary repository; sibling checkouts are never evidence inputs.

This is source/distribution identity evidence, not a generated API catalog or a compatibility result. Capabilities remain `inventoried`; real WordPress installation and behavior remain `not-tested`. SDK-012/013 own the profile schema/catalog, and the later WordPress harness owns runtime claims.
