# License-policy fixtures

`expected/publication-blocked.txt` is the exact human diagnostic emitted by the
provisional ADR-020 publication gate. `scripts/licenses/test-license-policy.py`
requires exit status 3 and byte-for-byte output equality, then applies negative
mutations for accidental publication enablement, invented reviewer data,
premature acceptance, missing components/findings, hidden license conflicts,
unstable inventory ordering, and raw output-license overrides.

These fixtures prove a fail-closed review state. They are not a legal opinion,
license grant, release approval, or evidence about the contents of a future
packed artifact.
