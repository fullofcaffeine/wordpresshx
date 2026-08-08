import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const transcriptPath = process.argv[2];
assert.ok(transcriptPath, "wire JSON transcript is required");

const lines = readFileSync(transcriptPath, "utf8").trimEnd().split("\n");
let encodedCount = 0;
for (const line of lines) {
  const separator = line.indexOf("=encoded:");
  if (separator === -1) {
    continue;
  }
  JSON.parse(line.slice(separator + "=encoded:".length));
  encodedCount += 1;
}
assert.ok(encodedCount > 0, "wire JSON transcript has no encoded vectors");

console.log(`Node decoded ${encodedCount} wire JSON vectors`);
