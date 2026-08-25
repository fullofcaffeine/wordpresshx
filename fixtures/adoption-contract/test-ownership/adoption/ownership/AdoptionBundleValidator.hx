package adoption.ownership;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;
import wordpresshx.cli.ownership.OwnershipContract;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Semantic validator for the complete, manifest-independent ADR-015 content bundle. */
final class AdoptionBundleValidator {
	static inline final BUNDLE_PATH = "generated/adoption/acme-calendar/adoption.bundle.json";
	static final EXPECTED_ROLES = ["capability", "contract", "haxe-facade", "provider-artifact", "review"];
	static final TRUST_ANCHORS = [
		"generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs",
		"generated/adoption/acme-calendar/php/acme-calendar-facade.php"
	];

	public static function validate(stageRoot:String):Void {
		final bundleBytes = read(Path.join(stageRoot, BUNDLE_PATH), "adoption bundle");
		final bundle = OwnershipJson.parseCanonical(bundleBytes, "adoption bundle");
		final root = object(bundle, "adoption bundle");
		exact(root, [
			"bundleDigest",
			"bundleId",
			"bundleVersion",
			"members",
			"provider",
			"schema",
			"schemaVersion"
		], "adoption bundle");
		if (text(field(root, "schema"), "bundle.schema") != "wordpress-hx.adoption-bundle.v1"
			|| integer(field(root, "schemaVersion"), "bundle.schemaVersion") != 1) {
			fail("adoption bundle schema identity differs");
		}
		final digest = text(field(root, "bundleDigest"), "bundle.bundleDigest");
		final material = ObjectValue([for (value in root) if (value.name != "bundleDigest") value]);
		if (digest != OwnershipJson.digestValue(material)) {
			fail("adoption bundle self digest is stale");
		}
		for (anchor in TRUST_ANCHORS) {
			final source = read(Path.join(stageRoot, anchor), "runtime trust anchor " + anchor).toString();
			if (source.indexOf(digest) < 0)
				fail("runtime trust anchor does not bind the content root");
		}

		final provider = object(field(root, "provider"), "bundle.provider");
		exact(provider, ["artifactSha256", "id", "version"], "bundle.provider");
		final artifactSha256 = text(field(provider, "artifactSha256"), "bundle.provider.artifactSha256");
		final members = array(field(root, "members"), "bundle.members");
		final roles:Array<String> = [];
		final paths:Array<String> = [];
		final documents:Array<{role:String, value:JsonValue}> = [];
		var providerArtifactSeen = false;
		for (index in 0...members.length) {
			final member = object(members[index], "bundle.members[" + index + "]");
			exact(member, ["path", "role", "sha256", "sizeBytes"], "bundle member");
			final role = text(field(member, "role"), "bundle member role");
			final relative = OwnershipContract.relative(text(field(member, "path"), "bundle member path"), "bundle member path");
			if (!StringTools.startsWith(relative, "generated/adoption/acme-calendar/") || relative == BUNDLE_PATH) {
				fail("bundle member escapes its content root");
			}
			if (roles.indexOf(role) >= 0 || paths.indexOf(relative) >= 0) {
				fail("bundle member roles and paths must be unique");
			}
			final bytes = read(Path.join(stageRoot, relative), "bundle member " + relative);
			if (OwnershipJson.digest(bytes) != text(field(member, "sha256"), "bundle member sha256")
				|| bytes.length != integer(field(member, "sizeBytes"), "bundle member size")) {
				fail("bundle member bytes are stale: " + relative);
			}
			if (role == "provider-artifact") {
				providerArtifactSeen = true;
				if (OwnershipJson.digest(bytes) != artifactSha256) {
					fail("provider artifact differs from the bundle provider identity");
				}
			}
			if (role == "contract" || role == "capability" || role == "review") {
				documents.push({
					role: role,
					value: OwnershipJson.parseCanonical(bytes, "adoption " + role)
				});
			}
			roles.push(role);
			paths.push(relative);
		}
		validateDocuments(documents, provider, roles, paths);
		final sortedRoles = roles.copy();
		sortedRoles.sort(compareText);
		final expectedRoles = EXPECTED_ROLES.copy();
		expectedRoles.sort(compareText);
		if (!providerArtifactSeen || sortedRoles.join("\x00") != expectedRoles.join("\x00")) {
			fail("adoption bundle does not contain one complete semantic role set");
		}
		final declared = paths.concat([BUNDLE_PATH]).concat(TRUST_ANCHORS);
		declared.sort(compareText);
		final staged:Array<String> = [];
		scan(stageRoot, "", staged);
		staged.sort(compareText);
		if (staged.join("\x00") != declared.join("\x00")) {
			fail("adoption stage differs from the content bundle plus its root");
		}
	}

	static function validateDocuments(documents:Array<{role:String, value:JsonValue}>, provider:Array<JsonField>, roles:Array<String>,
			paths:Array<String>):Void {
		final providerId = text(field(provider, "id"), "bundle.provider.id");
		final providerVersion = text(field(provider, "version"), "bundle.provider.version");
		final providerArtifact = text(field(provider, "artifactSha256"), "bundle.provider.artifactSha256");
		final expectedPaths = [
			"capability" => "generated/adoption/acme-calendar/capability.json",
			"contract" => "generated/adoption/acme-calendar/contract.json",
			"haxe-facade" => "generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx",
			"provider-artifact" => "generated/adoption/acme-calendar/provider/acme-calendar." + providerVersion + ".zip",
			"review" => "generated/adoption/acme-calendar/review.json"
		];
		for (index in 0...roles.length) {
			if (expectedPaths.get(roles[index]) != paths[index]) {
				fail("adoption bundle role uses an unexpected path: " + roles[index]);
			}
		}

		final contract = object(document(documents, "contract"), "adoption contract");
		exact(contract, [
			"bindings",
			"capabilitySet",
			"contractDigest",
			"contractId",
			"contractVersion",
			"generation",
			"ownership",
			"profile",
			"provider",
			"schema",
			"schemaVersion"
		], "adoption contract");
		validateDocumentIdentity(contract, "contractDigest", "wordpress-hx.adoption-contract.v1", "adoption contract");
		final contractProvider = object(field(contract, "provider"), "contract.provider");
		validateProvider(contractProvider, providerId, providerVersion, providerArtifact, "contract.provider");
		final contractId = text(field(contract, "contractId"), "contract.contractId");
		final contractVersion = text(field(contract, "contractVersion"), "contract.contractVersion");
		final contractDigest = text(field(contract, "contractDigest"), "contract.contractDigest");

		final capability = object(document(documents, "capability"), "adoption capability");
		exact(capability, [
			"authority",
			"capabilities",
			"capabilitySetDigest",
			"capabilitySetId",
			"capabilitySetVersion",
			"contract",
			"profile",
			"provider",
			"schema",
			"schemaVersion"
		], "adoption capability");
		validateDocumentIdentity(capability, "capabilitySetDigest", "wordpress-hx.adoption-capability.v1", "adoption capability");
		validateContractReference(object(field(capability, "contract"), "capability.contract"), contractId, contractVersion, contractDigest,
			"capability.contract");
		validateProvider(object(field(capability, "provider"), "capability.provider"), providerId, providerVersion, providerArtifact, "capability.provider");
		if (OwnershipJson.encode(field(capability, "profile")) != OwnershipJson.encode(field(contract, "profile"))) {
			fail("capability profile differs from the contract");
		}
		final authority = object(field(capability, "authority"), "capability.authority");
		exact(authority, [
			"absenceBehavior",
			"bundleVerification",
			"callerSuppliedFactsAllowed",
			"lifecycleIdentity",
			"observationOwner",
			"providerTrustAdmission",
			"sameNominalScopeInstanceReusable",
			"scopeTypes",
			"staleTokenAuthority",
			"tokenBoundFacts",
			"tokenCacheable",
			"tokenScope",
			"tokenSerializable"
		], "capability.authority");
		if (text(field(authority, "observationOwner"), "capability.authority.observationOwner") != "target-runtime-adapter"
			|| boolean(field(authority, "callerSuppliedFactsAllowed"), "capability.authority.callerSuppliedFactsAllowed")
			|| boolean(field(authority, "tokenSerializable"), "capability.authority.tokenSerializable")
			|| boolean(field(authority, "tokenCacheable"), "capability.authority.tokenCacheable")
			|| boolean(field(authority, "staleTokenAuthority"), "capability.authority.staleTokenAuthority")) {
			fail("capability authority is forgeable or stale");
		}
		if (text(field(authority, "tokenScope"), "capability.authority.tokenScope") != "declared-per-capability"
			|| text(field(authority, "lifecycleIdentity"), "capability.authority.lifecycleIdentity") != "generative-runtime-nonce"
			|| text(field(authority, "bundleVerification"), "capability.authority.bundleVerification") != "required-before-observation"
			|| text(field(authority, "absenceBehavior"), "capability.authority.absenceBehavior") != "typed-unavailable-with-core-fallback"
			|| text(field(authority, "providerTrustAdmission"), "capability.authority.providerTrustAdmission") != "separate-sdk-117-requirement"
			|| boolean(field(authority, "sameNominalScopeInstanceReusable"), "capability.authority.sameNominalScopeInstanceReusable")) {
			fail("capability authority policy differs");
		}
		if (textArray(field(authority, "scopeTypes"), "capability.authority.scopeTypes").join("|") != "browser-module|php-process|php-request"
			|| textArray(field(authority, "tokenBoundFacts"),
				"capability.authority.tokenBoundFacts")
				.join("|") != "bundle-digest|capability-id|lifecycle-kind|observed-bindings|provider-id|provider-version|runtime-nonce|target-executable-closure-sha256") {
			fail("capability authority facts differ");
		}
		validateCapabilities(array(field(capability, "capabilities"), "capability.capabilities"));

		final review = object(document(documents, "review"), "adoption review");
		exact(review, [
			"claims",
			"conflicts",
			"contract",
			"generator",
			"includedBindings",
			"omissions",
			"provider",
			"reflection",
			"reportDigest",
			"reportId",
			"schema",
			"schemaVersion",
			"summary"
		], "adoption review");
		validateDocumentIdentity(review, "reportDigest", "wordpress-hx.adoption-review.v1", "adoption review");
		validateContractReference(object(field(review, "contract"), "review.contract"), contractId, contractVersion, contractDigest, "review.contract");
		validateProvider(object(field(review, "provider"), "review.provider"), providerId, providerVersion, providerArtifact, "review.provider");
		final generation = object(field(contract, "generation"), "contract.generation");
		if (OwnershipJson.encode(field(review, "generator")) != OwnershipJson.encode(field(generation, "generator"))) {
			fail("review generator differs from the contract");
		}
		final reflection = object(field(review, "reflection"), "review.reflection");
		if (boolean(field(reflection, "requested"), "review.reflection.requested")
			|| boolean(field(reflection, "executed"), "review.reflection.executed")) {
			fail("static adoption review claims reflection execution");
		}
		final claims = object(field(review, "claims"), "review.claims");
		for (name in [
			"providerRuntimeTested",
			"providerTrustAdmitted",
			"productionSupported",
			"implementationOwnershipTransferred"
		]) {
			if (boolean(field(claims, name), "review.claims." + name)) {
				fail("adoption review overclaims " + name);
			}
		}
	}

	static function validateCapabilities(values:Array<JsonValue>):Void {
		if (values.length != 2)
			fail("capability set must contain exactly two capabilities");
		for (value in values) {
			final capability = object(value, "capability entry");
			exact(capability, ["id", "optional", "probe", "scope", "target"], "capability entry");
			final id = text(field(capability, "id"), "capability.id");
			final browser = id == "calendar.badge.browser";
			if (!browser && id != "calendar.read.php")
				fail("unknown capability entry");
			if (boolean(field(capability, "optional"), "capability.optional") != browser
				|| text(field(capability, "target"), "capability.target") != (browser ? "javascript" : "php")
				|| text(field(capability, "scope"), "capability.scope") != (browser ? "browser-module" : "request")) {
				fail("capability target policy differs");
			}
			final probe = object(field(capability, "probe"), "capability.probe");
			exact(probe, [
				"artifactMatch",
				"conditionalFailure",
				"executableClosureSha256",
				"kind",
				"requiredBindings",
				"requiredNativeSymbols",
				"versionMatch"
			], "capability.probe");
			if (text(field(probe, "artifactMatch"), "capability.probe.artifactMatch") != "target-executable-closure-sha256"
				|| text(field(probe, "conditionalFailure"), "capability.probe.conditionalFailure") != "unavailable-not-partially-authorized"
				|| text(field(probe, "versionMatch"), "capability.probe.versionMatch") != "exact"
				|| text(field(probe, "kind"), "capability.probe.kind") != (browser ? "javascript-exports" : "wordpress-plugin-and-symbols")
				|| !~/^[0-9a-f]{64}$/.match(text(field(probe, "executableClosureSha256"), "capability.probe.executableClosureSha256"))) {
				fail("capability probe policy differs");
			}
			final bindings = textArray(field(probe, "requiredBindings"), "capability.probe.requiredBindings");
			final symbols = textArray(field(probe, "requiredNativeSymbols"), "capability.probe.requiredNativeSymbols");
			if (bindings.length == 0 || bindings.length != symbols.length)
				fail("capability probe coverage differs");
		}
	}

	static function document(documents:Array<{role:String, value:JsonValue}>, role:String):JsonValue {
		for (document in documents) {
			if (document.role == role) {
				return document.value;
			}
		}
		return fail("adoption bundle omits semantic document: " + role);
	}

	static function validateDocumentIdentity(fields:Array<JsonField>, digestField:String, schema:String, label:String):Void {
		if (text(field(fields, "schema"), label + ".schema") != schema
			|| integer(field(fields, "schemaVersion"), label + ".schemaVersion") != 1) {
			fail(label + " schema identity differs");
		}
		final digest = text(field(fields, digestField), label + "." + digestField);
		final material = ObjectValue([for (value in fields) if (value.name != digestField) value]);
		if (digest != OwnershipJson.digestValue(material)) {
			fail(label + " self digest is stale");
		}
	}

	static function validateProvider(fields:Array<JsonField>, id:String, version:String, artifactSha256:String, label:String):Void {
		if (text(field(fields, "id"), label + ".id") != id
			|| text(field(fields, "version"), label + ".version") != version
			|| text(field(fields, "artifactSha256"), label + ".artifactSha256") != artifactSha256) {
			fail(label + " differs from the bundle provider");
		}
	}

	static function validateContractReference(fields:Array<JsonField>, id:String, version:String, digest:String, label:String):Void {
		exact(fields, ["id", "sha256", "version"], label);
		if (text(field(fields, "id"), label + ".id") != id
			|| text(field(fields, "version"), label + ".version") != version
			|| text(field(fields, "sha256"), label + ".sha256") != digest) {
			fail(label + " differs from the adoption contract");
		}
	}

	static function scan(root:String, relative:String, files:Array<String>):Void {
		final absolute = relative == "" ? root : Path.join(root, relative);
		final names:Array<String> = Fs.readdirSync(absolute);
		for (name in names) {
			final child = relative == "" ? name : relative + "/" + name;
			final stats = Fs.lstatSync(Path.join(root, child));
			if (stats.isSymbolicLink()) {
				fail("adoption stage contains a symbolic link");
			}
			if (stats.isDirectory()) {
				scan(root, child, files);
			} else if (stats.isFile()) {
				files.push(child);
			} else {
				fail("adoption stage contains a non-file entry");
			}
		}
	}

	static function read(path:String, label:String):Buffer {
		try {
			final stats = Fs.lstatSync(path);
			if (!stats.isFile() || stats.isSymbolicLink()) {
				return fail(label + " must be a regular file");
			}
			return Fs.readFileSync(path);
		} catch (_:haxe.Exception) {
			return fail(label + " is absent or unreadable");
		}
	}

	static function object(value:JsonValue, label:String):Array<JsonField> {
		return switch value {
			case ObjectValue(fields): fields;
			case _: fail(label + " must be an object");
		};
	}

	static function array(value:JsonValue, label:String):Array<JsonValue> {
		return switch value {
			case ArrayValue(values): values;
			case _: fail(label + " must be an array");
		};
	}

	static function textArray(value:JsonValue, label:String):Array<String> {
		return [for (item in array(value, label)) text(item, label)];
	}

	static function field(fields:Array<JsonField>, name:String):JsonValue {
		for (value in fields) {
			if (value.name == name) {
				return value.value;
			}
		}
		return fail("missing adoption bundle field: " + name);
	}

	static function exact(fields:Array<JsonField>, expected:Array<String>, label:String):Void {
		final actual = [for (value in fields) value.name];
		actual.sort(compareText);
		final wanted = expected.copy();
		wanted.sort(compareText);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail(label + " has unexpected fields");
		}
	}

	static function text(value:JsonValue, label:String):String {
		return switch value {
			case StringValue(text) if (text.length > 0): text;
			case _: fail(label + " must be non-empty text");
		};
	}

	static function integer(value:JsonValue, label:String):Int {
		return switch value {
			case NumberValue(source):
				if (!~/^(0|[1-9][0-9]*)$/.match(source)) {
					fail(label + " must be a non-negative integer");
				}
				final parsed = Std.parseInt(source);
				parsed == null ? fail(label + " must be a non-negative integer") : parsed;
			case _: fail(label + " must be an integer");
		};
	}

	static function boolean(value:JsonValue, label:String):Bool {
		return switch value {
			case BoolValue(enabled): enabled;
			case _: fail(label + " must be a boolean");
		};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function fail<T>(message:String):T {
		throw new OwnershipFailure(message, "adoption-bundle");
	}
}
