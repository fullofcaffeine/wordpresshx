# ADR-019 independent security Oracle review

- Reviewed commit: `9b855b979c8db30822cc6cffcc6110e4e44f6e1f`
- Reviewer: GPT-5.6 / OpenAI / independent Oracle agent
- Immutable packet SHA-256: `8adf80367cc104323908bd1c46327f3090b444905562fdc3314d944862098644`
- Prompt SHA-256: `9022e588986be72936593d06dc225538e6bbd142f6338a713a59f2778051a9e4`
- Repository snapshot SHA-256: `fb3bc9acd6da3732fab788b5b69781202d9e88cf890c3d23b82a1df575cb10af`
- Declared inspection paths SHA-256: `07dc98b96049feb1acb717207a7eda51e408921192931cd70136e45c70fec43a`
- Final decision: **changes-required**

All three packet input hashes verified, and all 17 declared inspection paths exist in the archived snapshot. The policy has a strong default-deny direction, a useful closed nine-category vocabulary, explicit source/generated/final inventory separation, and appropriately bounded claims. The executable waiver authority is nevertheless not yet strong enough to support acceptance: lifecycle/removal state and independent approval are forgeable or absent, while the published schema can be materially weakened without the validator noticing.

## Findings

### ADR019-F001 — Lifecycle and removal authority are not represented or enforced

**Severity:** blocking-high  
**Confidence:** high

The policy declares `active`, `expired`, `revoked`, and `superseded` states, additive renewal with a new ID, no inherited approval, and an active condition requiring the removal Bead to be open or in progress. The closed waiver schema contains no lifecycle state, revocation, supersession, `supersedes`/`renewalOf`, or external lifecycle-record reference. The instance validator therefore cannot distinguish a revoked or superseded waiver from an active one.

The validator checks only the removal Bead string pattern and that its deadline is not after expiry. It does not verify that the Bead exists, is open/in progress, or that the removal deadline has not already passed. Independent mutations demonstrated that both of these records pass:

```text
removal.bead = "wordpresshx-does-not-exist"
removal.deadline = "2026-07-19T00:00:00Z"
```

The latter deadline precedes creation and the `2026-07-26T23:00:00Z` evaluation instant, yet the waiver remains accepted through its September expiry. This makes the removal deadline non-operative and contradicts the declared active conditions.

**Evidence:** `schemas/unsafe-boundary-waiver.schema.json`; `validate_waiver_instance` in `scripts/security/test-unsafe-boundary-policy.py`; `lifecycle` and `waiverContract` in `manifests/unsafe-boundary-policy.json`.

**Required correction:** define one immutable lifecycle authority that represents active/revoked/superseded state and additive ancestry; require a new waiver ID and fresh review for renewal; resolve the removal Bead from authoritative Beads state; require it to be open/in progress; and fail when the removal deadline is before creation, review, or evaluation.

### ADR019-F002 — Independent approval can be manufactured with an arbitrary string and unrelated evidence

**Severity:** blocking-high  
**Confidence:** high

The schema records only `reviewer`, `reviewedAt`, `decision`, and one SHA-256. The validator treats reviewer independence as `reviewer != owner` and accepts any evidence-file digest listed on the waiver. It does not bind a review ID/schema, reviewer role/model identity, immutable prompt/input hashes, findings, decision document, reviewed waiver/source digest, or confirmation that the reviewer did not prepare the implementation/evidence.

An independent mutation replacing the reviewer with `arbitrary-unverified-string` passes. The canonical synthetic waiver uses `independent-oracle-fixture` and points `review.evidenceSha256` to `scenarios.json`, which is policy simulation input—not an independent approval report. Thus an author can create a different string and hash any convenient repository file to satisfy the machine gate.

Owner/reviewer string inequality is useful but is not proof of independent judgment. This also makes the stable-package allowance for low/medium raw or weak boundaries indefensible until approval provenance is fixed.

**Evidence:** `review` in `schemas/unsafe-boundary-waiver.schema.json`; lines 240–251 and 301–329 of `scripts/security/test-unsafe-boundary-policy.py`; canonical `WPHX-UNSAFE-9999.json`.

**Required correction:** require a closed, content-addressed review receipt binding reviewer identity/role, prompt and immutable input hashes, exact waiver/source/evidence digests, findings, decision, and independence declaration. Validate that receipt rather than accepting an arbitrary evidence-file hash.

### ADR019-F003 — The published JSON Schema and its validator can silently diverge

**Severity:** blocking-high  
**Confidence:** high

`validate_schema` checks the root field set, category enum, SHA pattern, a loose repository-path-pattern substring test, and `additionalProperties` on five objects. It does not validate most nested `required`, field schemas, references, types, or patterns.

The following independent schema weakenings all pass `validate_schema`:

```text
properties.id.pattern = ".*"
$defs.utcInstant.pattern = ".*"
remove "evidenceSha256" from properties.review.required
```

The 51 advertised mutations do not cover these decisive mismatches. A repository update can therefore retain a green validator while an independent standards-compliant JSON Schema consumer accepts waiver IDs, dates, or review records that the custom instance validator would reject. Conversely, the custom validator is the real authority despite the ADR naming the schema as the closed record.

**Evidence:** `validate_schema` and `run_schema_mutations` in `scripts/security/test-unsafe-boundary-policy.py`; `schemas/unsafe-boundary-waiver.schema.json`; the receipt's `waiverSchemaClosed` claim.

**Required correction:** validate the canonical and adversarial instances with a pinned independent Draft 2020-12 validator, exhaustively validate the expected schema structure/semantics, and add mutations for every security-relevant nested required field, type, pattern, reference, cardinality, and closure rule.

### ADR019-F004 — Repository path confinement follows symlinks

**Severity:** major-medium  
**Confidence:** high

`repository_path` rejects absolute text, backslashes, and literal `..`, then uses `(ROOT / text).is_file()` and reads the path. Those operations follow symlinks. A tracked repository-relative symlink can therefore bind source or evidence bytes outside the repository, contrary to the repository-contained provenance claim and with environment-dependent results.

**Evidence:** `repository_path` in `scripts/security/test-unsafe-boundary-policy.py`; `$defs.repositoryPath` in the waiver schema.

**Required correction:** reject symlinks or resolve both root and candidate and require the resolved candidate to remain beneath the resolved repository root before hashing.

## Positive conclusions

- The nine categories cover the requested Haxe, PHP, JavaScript, TypeScript, generated, private/profile, and external-contract boundary families without a permissive unknown category.
- Strict Haxe remains stronger than waiver policy: public API, application source, recommended examples, public signatures, and routine HXX are prohibited scopes, and high/critical risk cannot be waived.
- The 90-day maximum, absolute UTC syntax, source/evidence hashes, full-file hash plus line range, category scope, and source/generated/final inventory separation are sound design elements.
- TypeScript `unknown` is limited to a decoded foreign boundary with mandatory decoder evidence; `typescript-any` remains waiver/review constrained.
- The ADR correctly permits an independent Oracle instead of mandating a human review while retaining a named accountable owner concept.
- ADR-008 unsafe classification remains unsupported; ADR-012's public raw constructor remains withheld; ADR-021 still blocks stable release and requires an unsafe inventory.
- Stable low/medium internal waiver eligibility could be defensible only after F001–F004 are corrected and the package/final-artifact and independent-review authorities are actually implemented. It is not current release authorization.

## Verification observations

`python3 scripts/security/test-unsafe-boundary-policy.py` passes with 9 categories, 14 scenarios, and 51 mutations. The canonical source and evidence hashes match real repository-relative files, and every ADR-019 subject hash in the evidence receipt matches the packet.

The canonical pass is insufficient because the scenarios mostly consume self-asserted booleans rather than lifecycle, review, Beads, detector, generated-inventory, or final-artifact records. `scripts/check-repository.sh` rechecks hashes, counts, fixed claims, and the same validator; its ADR-019 section does not close the findings above. The production scanners, inventories, waiver API, native security behavior, and release artifacts are accurately marked `not-tested` or withheld.

The packet records hosted run `30225305825`, job `89854421141`, and implementation commit `75e4f76b9f80f2a5694a04386ff626aedee5040d`, but contains no immutable hosted log or attestation. Those declarations were not treated as independent proof.

## Scope limitations

This review decides only the bounded ADR-019 architecture/prototype at commit `9b855b979c8db30822cc6cffcc6110e4e44f6e1f`. It does not evaluate production scanners, publish an unsafe API, establish a final artifact inventory, prove WordPress/browser behavior, authorize stable release/publication, or claim production support.

## Final decision

**changes-required**. Correct ADR019-F001 through ADR019-F004 and submit a new immutable independent-review packet. No manual-human review is required.
