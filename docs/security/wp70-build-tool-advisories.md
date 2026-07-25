# WordPress 7.0 build-tool advisories

The `wp70-release` browser build remains usable for trusted, repository-owned
Haxe projects, but its private Node toolchain is not vulnerability-free. The
installed packages are build inputs only: WordPressHx does not put
`node_modules` in a plugin or theme, does not start the affected development
server in evidence builds, and does not accept untrusted source or
configuration in that build workspace.

This distinction matters because an audit finding describes code that exists
in the dependency graph, not necessarily code that executes in our command.
For example, `@wordpress/scripts` includes linting, testing, ZIP packaging,
development-server, and production-build commands. The WordPressHx production
lane invokes only the bounded build command against Haxe-generated TSX and
SDK-owned configuration.

## Current decision

The exact graph stays pinned to `@wordpress/scripts@31.5.0` and
`@wordpress/components@32.2.0`. On 2026-07-25, npm reported 20 unique GitHub
advisories represented by 73 affected package nodes: 1 low, 22 moderate, 50
high, and 0 critical. “Package nodes” counts every affected package in the
dependency tree, so it is larger than the number of distinct vulnerabilities.

WordPress publishes official `wp-7.0` patch tags at
`@wordpress/scripts@31.5.1` and `@wordpress/components@32.2.1`. Testing that
pair in an isolated candidate lock—changing only those two direct versions
and using the same audit procedure—produced the same 20 advisory IDs and the
same package-node counts. We therefore do not churn the frozen compatibility
profile for a change that provides no security improvement.

This is a bounded risk acceptance, not a claim that the dependencies are
secure in every use:

- `npm ci --ignore-scripts` prevents dependency lifecycle scripts from
  executing during installation.
- The checksum-locked Node container runs as an unprivileged user with a
  disposable workspace and cache.
- Only repository-owned generated source, patterns, source maps, and build
  configuration enter Babel, glob matching, schema validation, and
  serialization.
- The evidence command does not expose a development server, accept uploaded
  ZIP files, run Markdown linting, or invoke Lighthouse telemetry.
- `node_modules` is never copied into the produced WordPress plugin or theme.
- Publication remains blocked by the ordinary release gates.

The detailed per-advisory classification and exact lock hashes live in
`manifests/evidence/g2.3-wp70-build-tool-advisories.json`.

## Checking it

The offline check is deterministic and runs as part of the repository gate:

```bash
python3 scripts/gates/check-g2-build-advisories.py
```

The live check asks npm for today’s advisory graph. It allows an advisory to
disappear, but rejects a new advisory, a severity increase, a new directly
vulnerable package, or any critical finding until the receipt is reviewed:

```bash
python3 scripts/gates/check-g2-build-advisories.py --live
```

Do not run `npm audit fix` on this graph. That command currently proposes
major provider versions which no longer represent the exact WordPress 7.0
profile. A future official WordPress 7.0 patch can replace the lock only after
it reduces the classified risk and passes the complete strict TSX, bundle,
source-map, browser, accessibility, and WordPress runtime gates.
