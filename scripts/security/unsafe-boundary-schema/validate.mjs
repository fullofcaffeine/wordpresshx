import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {fileURLToPath} from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const directory = fileURLToPath(new URL(".", import.meta.url));
const root = resolve(directory, "../../..");
const readJson = (path) =>
  JSON.parse(readFileSync(resolve(root, path), "utf8"));
const clone = (value) => structuredClone(value);
const compile = (schema) => {
  const ajv = new Ajv2020({allErrors: true, strict: true});
  assert.equal(ajv.validateSchema(schema), true, JSON.stringify(ajv.errors));
  return ajv.compile(schema);
};

const waiverSchema = readJson("schemas/unsafe-boundary-waiver.schema.json");
const reviewSchema = readJson("schemas/unsafe-boundary-review.schema.json");
const lifecycleSchema = readJson("schemas/unsafe-boundary-lifecycle.schema.json");
const beadSchema = readJson("schemas/unsafe-boundary-bead-status.schema.json");
const waiver = readJson(
  "fixtures/unsafe-boundary/waivers/WPHX-UNSAFE-9999.json",
);
const review = readJson(
  "fixtures/unsafe-boundary/reviews/WPHX-UNSAFE-REVIEW-9999-01.json",
);
const lifecycle = readJson(
  "fixtures/unsafe-boundary/lifecycle/WPHX-UNSAFE-LIFECYCLE-9999.json",
);
const bead = readJson(
  "fixtures/unsafe-boundary/beads/wordpresshx-sdk-052.json",
);

for (const [label, schema, instance] of [
  ["waiver", waiverSchema, waiver],
  ["review", reviewSchema, review],
  ["lifecycle", lifecycleSchema, lifecycle],
  ["Bead status", beadSchema, bead],
]) {
  const validate = compile(schema);
  assert.equal(validate(instance), true, `${label}: ${JSON.stringify(validate.errors)}`);
}

const adversarial = [
  {
    label: "waiver ID pattern",
    mutateSchema(schema) {
      schema.properties.id.pattern = ".*";
    },
    mutateInstance(instance) {
      instance.id = "forged";
    },
  },
  {
    label: "UTC pattern",
    mutateSchema(schema) {
      schema.$defs.utcInstant.pattern = ".*";
    },
    mutateInstance(instance) {
      instance.createdAt = "whenever";
    },
  },
  {
    label: "nested review digest requirement",
    mutateSchema(schema) {
      schema.properties.review.required =
        schema.properties.review.required.filter((field) => field !== "sha256");
    },
    mutateInstance(instance) {
      delete instance.review.sha256;
    },
  },
  {
    label: "evidence cardinality",
    mutateSchema(schema) {
      schema.properties.evidence.minItems = 0;
    },
    mutateInstance(instance) {
      instance.evidence = [];
    },
  },
  {
    label: "source line type",
    mutateSchema(schema) {
      schema.properties.source.properties.startLine = {type: "string"};
    },
    mutateInstance(instance) {
      instance.source.startLine = "1";
    },
  },
  {
    label: "repository path reference",
    mutateSchema(schema) {
      schema.properties.review.properties.path = {type: "string"};
    },
    mutateInstance(instance) {
      instance.review.path = "/tmp/forged-review.json";
    },
  },
  {
    label: "lifecycle required",
    mutateSchema(schema) {
      schema.required = schema.required.filter((field) => field !== "lifecycle");
      delete schema.properties.lifecycle;
    },
    mutateInstance(instance) {
      delete instance.lifecycle;
    },
  },
];

for (const test of adversarial) {
  const originalInvalid = clone(waiver);
  test.mutateInstance(originalInvalid);
  assert.equal(
    compile(clone(waiverSchema))(originalInvalid),
    false,
    `${test.label}: canonical schema accepted adversarial instance`,
  );
  const weakened = clone(waiverSchema);
  delete weakened.$id;
  test.mutateSchema(weakened);
  assert.equal(
    compile(weakened)(originalInvalid),
    true,
    `${test.label}: mutation did not demonstrate material weakening`,
  );
}

console.log(
  `ADR-019 independent Draft 2020-12 validation passed: 4 schemas, ${adversarial.length} semantic weakening probes`,
);
