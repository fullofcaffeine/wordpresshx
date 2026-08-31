# ADR-015 final repair acceptance disposition

- Request: `orq_20260830T221744Z_569f2935`
- Reviewed revision: `85aae723a1314489b1a645acd88f58d4cc86ad68`
- Oracle verdict: `changes required`
- Local disposition: retain the verdict, but reject the predicted F004 bypass.
  Keep ADR-015 proposed and `wordpresshx-g6.1` in progress.

## Local baseline

The reviewed revision was the exact clean tracked `HEAD` and `origin/main`
before the response was read. Repair commit `add2f6e9` passed the focused gate
locally and with forced container PHP. Both observer records bind content root
`2c1dfaff` and evidence subject `d9b64581`. The complete repository,
pre-commit, and pre-push gates passed. Hosted run `33338453939`, job
`99329523358`, passed on that repair commit. Evidence-only commit `85aae72`
records the hosted result without changing the executable subject.

The response was captured complete with no response attachments. Caf-oracle
recorded valid GPT-5.6 Pro model proof. The request owner is
`wordpresshx/wordpresshx-maintainer`; consultation mode is `review`;
reconciliation uses `gpt-5.6-sol` at the `xhigh` floor.

Before reading the response, the local provisional decision was to accept only
if no reproducible critical or major blocker remained.

## Claim matrix

| Finding | Disposition | Local conclusion |
|---|---|---|
| F001: JavaScript declaration grammar | Retained, major | A block-comment declaration decoy plus real `export async function` is accepted by both current source paths. The returned promise can serialize as the expected string, so the native probe also launders the mismatch. |
| F003: independent JavaScript observer | Closed | The TypeScript AST observer does not import or execute the Python producer. Its remaining incomplete declaration policy belongs to F001. |
| F004: Haxe access-metadata authority mint | Rejected | The supplied reproducer cannot import the private module subtype `AuthorityCore` on Haxe 4.3.7. Interpreter, PHP, and JavaScript compilations all fail with `Importing private declarations from a module is not allowed`; adding global `@:allow(Main)` metadata does not change that result. General private-field access metadata does not make this private module subtype addressable. |
| F009: stage validation TOCTOU | Retained, critical | `ArtifactOwner` parses the manifest, scans the caller stage, lets the validator reopen both paths, discards the first buffers, then scans again for publication. A phase-changing filesystem can therefore validate different bytes from those installed. |
| F010: Python freshness | Retained, major | On a detached exact `85aae72` checkout, CPython 3.13.2 ran `refresh-evidence.py` successfully and retained observations recorded by CPython 3.14.5. Python executes the producer and most evidence code, so it is an authoritative omitted runtime. |

## Integrated conclusion

The Oracle verdict remains `changes required` because F001, F009, and F010
independently reproduce within the bounded fixture. F004 does not reproduce
under the pinned compiler and must not drive a product redesign. The existing
private module subtype remains a useful negative boundary, but a new exact
compile fixture should preserve the observed `@:access` rejection.

The retained repair is narrow and coherent:

1. make the Python producer lex actual top-level JavaScript declarations,
   require plain named non-default, non-async, non-generator exports in both
   producer and independent observer, and reject thenables before serialization;
2. capture manifest and complete stage bytes once in `ArtifactOwner`, validate
   an immutable-copy snapshot, and install the original captured buffers without
   reopening caller paths; and
3. pin CPython 3.14.5 for this gate, verify it before Python execution, install
   it explicitly in hosted CI, and bind its identity into every scorecard and
   freshness decision.

ADR-015 cannot yet be accepted, and `wordpresshx-g6.1` cannot yet close.

## Verification and gaps

Verified locally against the reviewed checkout:

- the response metadata is complete, attachment-free, and owned by the expected
  agent with the required review/reconciliation settings;
- the F001 mutation passed generation and independent AST observation, returned
  a thenable at runtime, and serialized as `"3 calendar events"`;
- the exact F004 access-metadata fixture failed compilation on interpreter, PHP,
  and JavaScript targets; a command-line macro adding `@:allow(Main)` still did
  not expose the private subtype;
- the F009 manifest/scan/validator/scan sequence and later transaction use were
  traced directly through the current `ArtifactOwner` and validator code; and
- CPython 3.13.2 retained the exact current evidence receipt, reproducing F010.

Remaining proof gaps before acceptance:

- no regression yet rejects async/default/generator/comment-decoy declarations
  and immediate-result laundering;
- the owner still validates filesystem paths rather than one captured snapshot;
- no phase-changing-view adversary proves the installed bytes are the validated
  bytes;
- Python is neither pinned nor recorded; and
- the fixture README still says eight negative programs while the durable ADR
  and receipt report nine.

The Oracle packet's XML representation did not expose the binary provider ZIP
for direct static inspection. That packaging limitation does not affect this
disposition because none of the retained or rejected findings depends on ZIP
contents.
