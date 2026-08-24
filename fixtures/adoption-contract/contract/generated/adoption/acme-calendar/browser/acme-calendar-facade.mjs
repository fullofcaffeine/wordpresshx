import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";

const expected = Object.freeze({
  version: "2.4.1",
  moduleSha256: "9228805f03547e088b0a96a581dfcab823fccd8a4c2a4dd810764972a76d1710",
  packageSha256: "eb0e484d9bb26022868a4f13d8bb53d887d8f5a2c3861308e339c1fdf9f09d1f",
  providerArtifactSha256: "923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd",
});
const expectedStaticMembers = Object.freeze([{"path":"generated/adoption/acme-calendar/capability.json","role":"capability","sha256":"e1a3065b3ada1dbed158be41f1b9070afdb20fcfe52bf274e90952112c0bdd68","sizeBytes":2234},{"path":"generated/adoption/acme-calendar/contract.json","role":"contract","sha256":"a3cad8cd3b4b8a32a9b4d55c47c10f9287897a25769f2377ce7f3edcacbedbb6","sizeBytes":8278},{"path":"generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx","role":"haxe-facade","sha256":"3cb252231264ad1efa4ae84e1e768a25b0cba858830c483ed81472c32ca7fc05","sizeBytes":2668},{"path":"generated/adoption/acme-calendar/provider/acme-calendar.2.4.1.zip","role":"provider-artifact","sha256":"923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd","sizeBytes":1549},{"path":"generated/adoption/acme-calendar/review.json","role":"review","sha256":"1154cf0d9d46e971739f216341cb9e698f6edf65f5af2df130473d834b190f68","sizeBytes":4785}]);

function digest(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

async function verifyBundle(bundleFile) {
  let bytes;
  try {
    bytes = await readFile(bundleFile);
  } catch (_) {
    throw new Error("content-bundle-absent");
  }
  const canonical = bytes.toString("utf8");
  const match = /^\{"bundleDigest":"([0-9a-f]{64})",/.exec(canonical);
  if (!match || !canonical.endsWith("\n")) {
    throw new Error("wrong-content-bundle");
  }
  const withoutNewline = canonical.slice(0, -1);
  const material = "{" + withoutNewline.slice(match[0].length);
  if (digest(Buffer.from(material, "utf8")) !== match[1]) {
    throw new Error("wrong-content-bundle");
  }
  let bundle;
  try {
    bundle = JSON.parse(withoutNewline);
  } catch (_) {
    throw new Error("wrong-content-bundle");
  }
  if (bundle.schema !== "wordpress-hx.adoption-bundle.v1"
      || bundle.schemaVersion !== 1
      || bundle.bundleId !== "acme-calendar.wp70.bundle"
      || bundle.bundleVersion !== "1.0.0"
      || bundle.provider?.id !== "acme-calendar"
      || bundle.provider?.version !== expected.version
      || bundle.provider?.artifactSha256 !== expected.providerArtifactSha256) {
    throw new Error("wrong-content-bundle");
  }
  if (!Array.isArray(bundle.members) || bundle.members.length !== 7) {
    throw new Error("wrong-content-bundle");
  }
  const membersByRole = new Map();
  for (const member of bundle.members) {
    if (!member || typeof member !== "object" || Array.isArray(member)
        || Object.keys(member).sort().join("|") !== "path|role|sha256|sizeBytes"
        || typeof member.role !== "string" || membersByRole.has(member.role)) {
      throw new Error("wrong-content-bundle");
    }
    membersByRole.set(member.role, member);
  }
  for (const member of expectedStaticMembers) {
    if (JSON.stringify(membersByRole.get(member.role)) !== JSON.stringify(member)) {
      throw new Error("wrong-content-bundle");
    }
  }
  for (const [role, memberPath] of [
    ["javascript-facade", "generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs"],
    ["php-facade", "generated/adoption/acme-calendar/php/acme-calendar-facade.php"],
  ]) {
    const member = membersByRole.get(role);
    if (!member || member.path !== memberPath || !/^[0-9a-f]{64}$/.test(member.sha256)
        || !Number.isSafeInteger(member.sizeBytes) || member.sizeBytes <= 0) {
      throw new Error("wrong-content-bundle");
    }
  }
  return match[1];
}

export async function openExactProvider(packageRoot, generation, bundleFile) {
  const bundleDigest = await verifyBundle(bundleFile);
  const packagePath = path.join(packageRoot, "package-metadata.json");
  const modulePath = path.join(packageRoot, "index.js");
  let packageBytes;
  let moduleBytes;
  try {
    [packageBytes, moduleBytes] = await Promise.all([readFile(packagePath), readFile(modulePath)]);
  } catch (_) {
    throw new Error("provider-absent");
  }
  if (digest(packageBytes) !== expected.packageSha256 || digest(moduleBytes) !== expected.moduleSha256) {
    throw new Error("wrong-provider-artifact");
  }
  const metadata = JSON.parse(packageBytes.toString("utf8"));
  if (metadata.version !== expected.version) {
    throw new Error("wrong-provider-version");
  }
  const moduleUrl = `data:text/javascript;base64,${moduleBytes.toString("base64")}#${encodeURIComponent(generation)}`;
  const provider = await import(moduleUrl);
  if (typeof provider.CalendarBadge !== "function" || typeof provider.formatCalendarLabel !== "function") {
    throw new Error("required-provider-symbol-missing");
  }
  return Object.freeze({
    bundleDigest,
    formatLabel(count) {
      return provider.formatCalendarLabel(count);
    },
    renderBadge(props) {
      return provider.CalendarBadge(props);
    },
  });
}
