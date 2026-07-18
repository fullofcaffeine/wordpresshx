# Project and CLI contract fixture

`project/` is a synthetic greenfield consumer created to validate ADR-016. It
demonstrates the generated `wordpress-hx.json` bootstrap, an exact project
lock, Haxe-owned development service declarations, ordinary npm aliases, and a
closed effective-input graph. SDK-043 also runs the production Haxe/Genes
one-shot CLI against isolated copies of it. It is not a published SDK example
or a WordPress/Next.js runtime compatibility claim.

`valid/effective-inputs.json` is regenerated from the project by
`python3 scripts/project-cli/test-contract.py --update`. The two JSONL files are
closed machine-event transcripts: one bounded dry-run and one development run
with an initial publish, a coalesced failing rebuild that retains the last-good
generation, a successful rebuild, reload, and owned-process shutdown.

The synthetic npm files use the inert names `npm-manifest.json` and
`npm-lock.json` so this contract data is not mistaken for another active
repository package graph. Their contents and configured roles are ordinary
`package.json`/lockfile-v3 shapes; real generated projects use the conventional
filenames.

The historical contract vectors remain unchanged. Run
`bash scripts/project-cli/test-production.sh` for the real command corpus; it
does not claim the SDK-044 watcher/process supervisor, target emitters, or
production support.
