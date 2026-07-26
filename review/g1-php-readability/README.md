# G1 independent WordPress/PHP review

This review answers one narrow question: can an experienced WordPress/PHP
developer understand, debug, and safely call the public PHP emitted by
WordPressHx without knowing Haxe internals?

The compiler and SDK owner prepares the packet, but cannot approve it. The
normal reviewer is a separate Oracle/agent context instructed to act as an
experienced WordPress/PHP developer. It is eligible only if it did not
implement the emitter, contribute to the reviewed implementation commit, or
prepare this packet. A human reviewer is optional, not required.

## Review packet

The checked-in [`packet`](packet/) is bound to implementation commit
`d6f74f9ac009862f0f65b2a46c67b69999b7fea9`. Its manifest lists every file,
byte count, SHA-256 digest, and one digest for the complete inventory. The
packet includes:

- the ordinary generated plugin root, bootstrap, adapters, registrations, and
  source-correlation plugin PHP;
- ordinary non-Haxe callers and WordPress runtime probes;
- the Haxe authoring sources and the bounded compiler profiles that produced
  the public shape;
- native exception stacks plus exact Haxe-correlated trace results;
- the content-bound PHP map, source index, and relevant evidence receipts.

Read [`packet/README.md`](packet/README.md) first. It maps each required review
category to the smallest useful set of files.

## Record the review

1. Copy `reviewer-receipt.template.json` to `reviewer-receipt.json`.
2. Replace every placeholder and review all six categories.
3. Add every finding to `findings`, including non-blocking observations.
4. Resolve every blocking finding and review the replacement packet before
   selecting `accepted`.
5. Compute `receiptDigest` as SHA-256 over canonical JSON with
   `receiptDigest` omitted.
6. Run:

   ```bash
   python3 scripts/php-review/validate-g1-review.py \
     review/g1-php-readability/reviewer-receipt.json
   ```

The validator rejects placeholders, self-review, incomplete category coverage,
open blocking findings, a stale packet identity, and publication or production
support claims. Automated validation proves receipt consistency; the separate
review context remains responsible for the technical judgment.

## Rebuild the packet

The packet is generated, but tracked so a reviewer can inspect it without
installing Haxe, PHP, Node, or Docker. A maintainer can reproduce it with:

```bash
bash packages/cli/scripts/test.sh
python3 scripts/php-review/build-g1-packet.py \
  --implementation-commit d6f74f9ac009862f0f65b2a46c67b69999b7fea9
```

The first command regenerates and tests the PHP artifacts and trace CLI. The
second command runs fresh PHP exceptions in the exact locked containers,
correlates their native frames, replaces only this packet directory, and
recomputes its manifest.

The 2026-07-26 GPT-5.6 Oracle receipt is accepted and machine-validated. It
records three non-blocking observations: a stale supplemental SDK-025 digest,
eager include/registration behavior in `autoload.php`, and the bounded manually
planned PHP-IR scope of the adapter proof. These remain follow-up work under
`wordpresshx-g1.4`; they do not broaden G1 into a general PHP compiler,
publication, or production-support claim.
