# ADR-012 F004 rereview integration

The independent GPT-5.6 Pro rereview of commit
`0e01ab5e18fe023e43f2d45e1052bdccef658f05` returned
`changes-required` with high confidence. The exact imported report is
[`ORACLE-REREVIEW.md`](ORACLE-REREVIEW.md); its SHA-256 is
`ee960c76303b0affb8f1f569dc8a13554dd566c2a13a86e6528c6c2bbda8f7db`.
The imported reviewed-input manifest has SHA-256
`1af00aa963b15a63df5628b2802c4e1faf9d1d7778082eb6602e90a1d4972c36`.

The rereview confirmed that the original raw-C0 codec path was repaired, then
identified three remaining invariant failures:

1. `ADR012-F004-RR-F001` — public `JsonPlan.success` could still brand
   caller-authored bytes as successful JSON. The repair removes public success
   and failure factories, makes the constructor private and grants construction
   only to `OutputSinks`, adds two all-target compile-negative fixtures, and
   statically rejects any public raw-string success factory.
2. `ADR009-RR-F001` — depth was measured by visited child nodes, so 65 empty
   containers passed a nominal limit of 64. The repair defines depth as JSON
   container nesting and tests arrays, objects, mixed containers, empty and
   scalar leaves, exact limits 1 and 64, non-positive limits, and cycles.
3. `ADR009-RR-F002` — malformed values reachable from non-strict or foreign
   callers could escape through target exceptions, and object keys were sorted
   before validation. The repair validates every public shape, validates names
   before ordering, snapshots the mutable tree into a private representation,
   then encodes only that snapshot. A deliberately non-strict boundary corpus
   proves modeled rejection; strict application fixtures prove invalid direct
   construction fails to compile.

The focused ADR-009 and ADR-012 gates and the complete repository gate pass
locally after these corrections. `wordpresshx-g4.1.1` nevertheless remains in
progress: ADR-009 and ADR-012 require a new content-addressed independent
rereview. This integration does not authorize publication or broaden the
bounded prototype claims.
