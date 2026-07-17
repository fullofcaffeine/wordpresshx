# Profile schema fixtures

The two documents under `valid/` are minimal exact-profile inputs for SDK-012.
They intentionally contain only `inventoried` entries and do not claim generated
catalog breadth or runtime behavior.

`sha256-canonical-json-v1` is SHA-256 over UTF-8 JSON for this object:

```json
{
  "schemaVersion": "<document schemaVersion>",
  "generator": "<document generator object>",
  "catalog": "<document catalog object>"
}
```

The actual values—not the strings shown above—are serialized with keys sorted,
no insignificant whitespace, no ASCII escaping, and separators `,` and `:`.
`catalogDigest` and `catalogDigestAlgorithm` are excluded from the digest input.
The Python validator is the version-1 executable authority for this algorithm.

Negative fixtures are deterministic in-memory mutations of these checked-in
valid documents. This keeps every failure focused on one schema or semantic
rule while avoiding stale duplicate JSON snapshots.
