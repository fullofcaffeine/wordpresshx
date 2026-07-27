# Combined Oracle rereview: repository integration

This record explains how the independent GPT-5.6 Pro review returned on
2026-07-27 changes the current WordPressHx plan. It is an integration and
adjudication record, not a replacement for the full review text and not a new
independent review.

## Reviewed subject

- Commit: `76a90da1639aa28e163c1713067274323e5b4db2`
- Tree: `b341fb3cdaee2303c18e50ce47d9f71fb30ff4ca`
- Packet SHA-256:
  `3e7126fac1651f9b8d0afe99534709b27aca73135339ba17a019f8c0c531d921`
- Reviewer: OpenAI GPT-5.6 Pro, acting as the independent Oracle
- Decision: changes required, high confidence

The current integration commit descends directly from the reviewed subject.
The only intervening repository commit before this integration documented the
Genes ownership boundary; it did not change the JSON codec, development
service lifecycle, adoption contracts, licensing evidence, or G1 packet.

## Practical result

Two previously accepted implementation claims are reopened:

1. A successful output-context JSON value can contain a raw C0 control byte
   that PHP and JavaScript reject as invalid JSON. `wordpresshx-g4.1.1` owns
   the repair and a fresh ADR-012 rereview.
2. `wphx dev` stops only a service's direct child. A worker or watcher spawned
   by that child can survive shutdown. `wordpresshx-sdk-044.4` owns complete
   process-tree termination and Linux/Windows regression evidence.

The other material findings reinforce existing work rather than creating
parallel plans:

| Review findings | Current owner | Integrated disposition |
|---|---|---|
| ADR015-F001–F010 | `wordpresshx-g6.1` | All remain open. The next adoption proof must be source-derived, call real providers, use target-owned lifecycle observations, and bind one immutable bundle. |
| ADR020-F001–F008 | `wordpresshx-sdk-plan.2` | F001, F003, F007, and F008 have technical closure for the reviewed snapshot. F002, F004, F005, and the authority part of F006 remain open; publication stays blocked. |
| ARCH-N01–N04 | `wordpresshx-sdk-plan.3` | Remain applicable. The complete beginner-facing WordPress vertical is the organizing product proof. |
| ADR012-R3-N001 | `wordpresshx-sdk-plan.4` | Remains a non-blocking review-packet hardening task. |
| G1-N01–N03 | `wordpresshx-g1.4` | Remain non-blocking. G1 is still accepted only as one manually planned PHP-IR slice, not a general Haxe-to-PHP compiler. |

## Independent current-tree checks

The integration pass checked the three newly decisive code claims against
current `main`:

- `TodoCardCodec.encode` rejects NUL only, while `PlanJson.quote` leaves other
  bytes in `U+0000`–`U+001F` unescaped. `OutputSinks` treats every
  `EncodedJson` as success. The Oracle's native-decoder counterexample follows
  directly from this code.
- `RunningService.start` spawns without an owned group/session and
  `RunningService.stop` calls `child.kill` for only the direct process. No
  descendant or Windows job ownership exists in the implementation or
  production fixture.
- The public ADR-015 schema patterns lack whole-string anchors. Standard JSON
  Schema `pattern` uses substring matching, so the Oracle's leading/trailing
  junk counterexamples are valid even though the repository's custom
  validator is stricter.

## Authority boundaries

“Blocking” is scoped to the claim named by the finding. The JSON regression
blocks renewed ADR-012 acceptance; the process defect blocks the complete
SDK-044 lifecycle claim; ADR-015 findings block adoption-contract acceptance;
ADR-020 findings block publication. They do not prohibit unrelated local SDK
development.

Licensing inventory and provenance can be improved by engineering, but code
cannot invent contributor rights, a root grant, qualified review, or
product-owner publication approval. Those items remain explicitly external
authority requirements. This record is engineering evidence, not legal advice
or publication authorization.

## Review limitations retained

The Oracle reconstructed the exact tracked tree and independently reproduced
the JSON, schema, and POSIX process defects. It could not rerun the complete
Haxe, Genes, WordPress, Docker, browser, Composer, Gitleaks, Beads, or original
Git-history matrices in its environment. Historical receipts therefore remain
bounded supporting evidence; every repaired claim still needs its repository
gate, exact hosted matrix, and a new content-addressed rereview.
