# Test environments

This directory owns reproducible local and hosted test environments. It is not a production deployment system, and no container is shipped with a WordPressHx plugin or theme.

`images.lock.json` records exact multi-platform image-index digests. Runtime commands use only `name@sha256:...` references; the associated tags are discovery metadata checked explicitly with:

```bash
python3 scripts/docker/check-image-lock.py
python3 scripts/docker/check-image-lock.py --resolve
```

The first command is deterministic and offline. The optional registry resolution proves that each mutable discovery tag still resolves to the recorded index and contains the required `linux/amd64` and `linux/arm64` variants.

## WordPress 7.0 harness

`wordpress/compose.yml` provides two isolated database lanes over the same exact WordPress 7.0/PHP 8.4 Apache image:

- MySQL `8.4.10`;
- MariaDB `11.4.5`.

Each lane removes its named Compose volumes before startup, waits for the real database and WordPress containers, runs the native WordPress installer, proves the install was fresh, seeds one deterministic option, executes `SELECT 1` and `SELECT VERSION()` through `$wpdb`, requests the rendered site over HTTP, and removes all lane volumes afterward.

```bash
bash scripts/wordpress/run-harness.sh mysql
bash scripts/wordpress/run-harness.sh mariadb
bash scripts/wordpress/test-harness.sh
```

To clean a retained or interrupted lane without touching unrelated Docker state:

```bash
bash scripts/wordpress/reset-harness.sh mysql
bash scripts/wordpress/reset-harness.sh mariadb
```

`verify-distribution.py` separately proves, with the container network disabled, that `/usr/src/wordpress` contains the exact 3,951-file official WordPress 7.0 distribution tree recorded in `profiles/wp70-release/source.lock.json`. The two additional official-image bootstrap files are a closed, individually hashed set.

The exact PHP 7.4 CLI image remains the generated-PHP syntax/runtime floor. The official WordPress 7.0 image used here runs PHP 8.4.23; SDK-090 does not claim an installed WordPress 7.0/PHP 7.4 container lane. Node and Playwright images are pinned inputs for later browser beads and remain `inventoried`, not runtime-tested.
