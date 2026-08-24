"use strict";

const fs = require("node:fs");
const path = require("node:path");
const Ajv2020 = require("../../packages/gutenberg/build-tooling/node_modules/ajv-formats/node_modules/ajv/dist/2020").default;

const root = path.resolve(__dirname, "../..");
const entries = [
  ["contract", "schemas/adoption-contract.schema.json", "fixtures/adoption-contract/contract/acme-calendar.contract.json", "contractId"],
  ["capability", "schemas/adoption-capability.schema.json", "fixtures/adoption-contract/contract/acme-calendar.capability.json", "capabilitySetId"],
  ["review", "schemas/adoption-review.schema.json", "fixtures/adoption-contract/contract/acme-calendar.review.json", "reportId"],
  ["bundle", "schemas/adoption-bundle.schema.json", "fixtures/adoption-contract/contract/acme-calendar.bundle.json", "bundleId"],
];

for (const [label, schemaPath, documentPath, identityField] of entries) {
  const schema = JSON.parse(fs.readFileSync(path.join(root, schemaPath), "utf8"));
  const document = JSON.parse(fs.readFileSync(path.join(root, documentPath), "utf8"));
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  const validate = ajv.compile(schema);
  if (!validate(document)) {
    throw new Error(`${label} failed independent JSON Schema validation: ${ajv.errorsText(validate.errors)}`);
  }
  for (const invalid of [`!${document[identityField]}`, `${document[identityField]}!`]) {
    const candidate = structuredClone(document);
    candidate[identityField] = invalid;
    if (validate(candidate)) {
      throw new Error(`${label} accepted a non-anchored identity: ${invalid}`);
    }
  }

  const relativePath = schema.$defs?.relativePath;
  if (relativePath !== undefined) {
    const validateRelativePath = ajv.compile(relativePath);
    for (const invalid of ["../x", "a/../x", "./x", "a/./x", "/absolute", "a\\x"]) {
      if (validateRelativePath(invalid)) {
        throw new Error(`${label} accepted unsafe relative path: ${invalid}`);
      }
    }
  }
}

process.stdout.write("ADR-015 public schemas passed Ajv 2020-12 with anchored adversaries\n");
