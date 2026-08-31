import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";

const expected = Object.freeze({
  version: "2.4.1",
  moduleSha256: "9228805f03547e088b0a96a581dfcab823fccd8a4c2a4dd810764972a76d1710",
  packageSha256: "eb0e484d9bb26022868a4f13d8bb53d887d8f5a2c3861308e339c1fdf9f09d1f",
  providerArtifactSha256: "923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd",
  bundleDigest: "c2a0a55dd274ead37af78c2ea2d53a43cdc7868c9fb80949e9cc246e2c57088a",
  executableClosureSha256: "f072306f4ce994dd45ab045a122bcf77cd76a15d78a5941cc7d2815d24e9e46e",
});
const expectedStaticMembers = Object.freeze([{"path":"generated/adoption/acme-calendar/capability.json","role":"capability","sha256":"58156adc8a2bbc467084c676f26c1b180589dc573dc8837eb5e752ea4138fff4","sizeBytes":2477},{"path":"generated/adoption/acme-calendar/contract.json","role":"contract","sha256":"066f6f821bf2e7ce329fdebcff469a4775af9d6e2cf92b5c305035097c005db2","sizeBytes":8278},{"path":"generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx","role":"haxe-facade","sha256":"59c4729d6606960a318c6517e912fb000892ffe5e26ea23d5a40fc2e38274b35","sizeBytes":2898},{"path":"generated/adoption/acme-calendar/provider/acme-calendar.2.4.1.zip","role":"provider-artifact","sha256":"923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd","sizeBytes":1549},{"path":"generated/adoption/acme-calendar/review.json","role":"review","sha256":"2cbf1e95de6b6ada60851261ac0b56754cff5f6491c13ed7872a1aef3ba31bfe","sizeBytes":4785}]);

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
  if (digest(Buffer.from(material, "utf8")) !== match[1] || match[1] !== expected.bundleDigest) {
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
  if (!Array.isArray(bundle.members) || bundle.members.length !== 5) {
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
  const bundleSuffix = "generated/adoption/acme-calendar/adoption.bundle.json";
  const normalizedBundleFile = path.resolve(bundleFile).split(path.sep).join("/");
  if (!normalizedBundleFile.endsWith(bundleSuffix)) {
    throw new Error("wrong-content-bundle");
  }
  const outputRoot = normalizedBundleFile.slice(0, -bundleSuffix.length);
  for (const member of expectedStaticMembers) {
    let memberBytes;
    try {
      memberBytes = await readFile(path.resolve(outputRoot, member.path));
    } catch (_) {
      throw new Error("wrong-content-bundle");
    }
    if (memberBytes.length !== member.sizeBytes || digest(memberBytes) !== member.sha256) {
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
    executableClosureSha256: expected.executableClosureSha256,
    formatLabel(count) {
      const value = provider.formatCalendarLabel(count);
      if (typeof value !== "string") {
        throw new Error("wrong-provider-result-shape");
      }
      return value;
    },
    renderBadge(props) {
      const value = provider.CalendarBadge(props);
      if (value === null || typeof value !== "object" || typeof value.then === "function") {
        throw new Error("wrong-provider-result-shape");
      }
      return value;
    },
  });
}
