package wordpresshx.cli.ownership;

import js.node.Buffer;

/** Closed v1 manifest and journal validation plus deterministic plan derivation. **/
class OwnershipContract {
	public static inline final MANIFEST_SCHEMA = "wordpress-hx.generated-files.v1";
	public static inline final JOURNAL_SCHEMA = "wordpress-hx.ownership-journal.v1";
	public static inline final TRANSACTION_PROTOCOL = "wordpress-hx.ownership-transaction.v1";
	public static inline final CANONICALIZATION = "wordpress-hx.canonical-json.v1";
	public static inline final MANIFEST_DIGEST_ALGORITHM = "sha256-canonical-json-without-manifestDigest-v1";
	public static inline final JOURNAL_DIGEST_ALGORITHM = "sha256-canonical-json-without-journalDigest-v1";

	static final SHA256 = new EReg("^[0-9a-f]{64}$", "");
	static final STABLE_ID = new EReg("^[a-z][a-z0-9]*(?:[._:/-][a-z0-9]+)*$", "");
	static final PORTABLE_SEGMENT = new EReg("^[A-Za-z0-9._@+-]+$", "");

	static final WINDOWS_RESERVED = [
		"con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6",
		"lpt7", "lpt8", "lpt9"
	];

	public static function validateManifest(value:Dynamic):Void {
		exactFields(value, [
			"schema",
			"canonicalization",
			"transactionProtocol",
			"manifestDigestAlgorithm",
			"manifestDigest",
			"locations",
			"generator",
			"inputs",
			"outputRoots",
			"validators",
			"files"
		], "manifest");
		expectString(value, "schema", "manifest", MANIFEST_SCHEMA);
		expectString(value, "canonicalization", "manifest", CANONICALIZATION);
		expectString(value, "transactionProtocol", "manifest", TRANSACTION_PROTOCOL);
		expectString(value, "manifestDigestAlgorithm", "manifest", MANIFEST_DIGEST_ALGORITHM);
		sha256(string(value, "manifestDigest", "manifest"), "manifest.manifestDigest");
		if (string(value, "manifestDigest", "manifest") != digestWithout(value, "manifestDigest")) {
			fail("manifestDigest does not bind the canonical manifest", "manifest-digest");
		}

		final locations = fieldObject(value, "locations", "manifest");
		exactFields(locations, ["manifestPath", "transactionRoot", "lockPath", "journalPath"], "manifest.locations");
		for (field in ["manifestPath", "transactionRoot", "lockPath", "journalPath"]) {
			relative(string(locations, field, "manifest.locations"), "manifest.locations." + field);
		}
		final transactionRoot = string(locations, "transactionRoot", "manifest.locations");
		if (string(locations, "lockPath", "manifest.locations") != transactionRoot + "/lock"
			|| string(locations, "journalPath", "manifest.locations") != transactionRoot + "/journal.json") {
			fail("manifest ownership lock and journal are not derived from transactionRoot", "manifest-locations");
		}
		final manifestPath = string(locations, "manifestPath", "manifest.locations");
		if (atOrBelow(manifestPath, transactionRoot) || atOrBelow(transactionRoot, manifestPath)) {
			fail("manifestPath and transactionRoot must be disjoint", "manifest-locations");
		}

		validateGenerator(fieldObject(value, "generator", "manifest"));
		validateInputs(fieldObject(value, "inputs", "manifest"));

		final roots = array(value, "outputRoots", "manifest");
		if (roots.length == 0) {
			fail("manifest.outputRoots must not be empty", "manifest-roots");
		}
		final rootIds = new Map<String, Bool>();
		final rootKeys = new Map<String, Bool>();
		var previousRootKey:Null<String> = null;
		for (index in 0...roots.length) {
			final root = object(roots[index], "manifest.outputRoots[" + index + "]");
			exactFields(root, ["rootId", "path", "ownershipMode"], "manifest.outputRoots[" + index + "]");
			final rootId = stableId(string(root, "rootId", "output root"), "manifest.outputRoots[" + index + "].rootId");
			final path = relative(string(root, "path", "output root"), "manifest.outputRoots[" + index + "].path");
			expectString(root, "ownershipMode", "output root", "exact-file-manifest-coexists-with-unowned");
			final orderKey = path + "\x00" + rootId;
			if (previousRootKey != null && Reflect.compare(previousRootKey, orderKey) >= 0) {
				fail("manifest output roots are not a sorted unique set", "manifest-roots");
			}
			previousRootKey = orderKey;
			if (rootIds.exists(rootId) || rootKeys.exists(collisionKey(path))) {
				fail("manifest contains a duplicate output root identity or path", "manifest-roots");
			}
			for (otherIndex in 0...index) {
				final otherPath = string(object(roots[otherIndex], "output root"), "path", "output root");
				if (atOrBelow(path, otherPath) || atOrBelow(otherPath, path)) {
					fail("nested output roots are forbidden in v1", "manifest-roots");
				}
			}
			rootIds.set(rootId, true);
			rootKeys.set(collisionKey(path), true);
		}
		for (reserved in [manifestPath, transactionRoot]) {
			var contained = false;
			for (candidate in roots) {
				final path = string(object(candidate, "output root"), "path", "output root");
				if (reserved != path && atOrBelow(reserved, path)) {
					contained = true;
				}
			}
			if (!contained) {
				fail("reserved ownership path is outside declared output roots", "manifest-roots");
			}
		}

		final validators = array(value, "validators", "manifest");
		if (validators.length == 0) {
			fail("manifest.validators must not be empty", "manifest-validators");
		}
		final validatorIds = new Map<String, Bool>();
		var previousValidator:Null<String> = null;
		for (index in 0...validators.length) {
			final validator = object(validators[index], "manifest.validators[" + index + "]");
			validateValidator(validator, index);
			final id = string(validator, "validatorId", "validator");
			if (previousValidator != null && Reflect.compare(previousValidator, id) >= 0) {
				fail("manifest validators are not a sorted unique set", "manifest-validators");
			}
			previousValidator = id;
			validatorIds.set(id, true);
		}

		final files = array(value, "files", "manifest");
		var previousPath:Null<String> = null;
		final pathKeys = new Map<String, Bool>();
		for (index in 0...files.length) {
			final item = object(files[index], "manifest.files[" + index + "]");
			validateFile(item, index, roots, validatorIds, locations);
			final path = string(item, "path", "manifest file");
			if (previousPath != null && Reflect.compare(previousPath, path) >= 0) {
				fail("manifest files are not sorted by exact path", "manifest-files");
			}
			previousPath = path;
			final key = collisionKey(path);
			if (pathKeys.exists(key)) {
				fail("manifest files contain a case-folding collision", "manifest-files");
			}
			pathKeys.set(key, true);
		}
		if (string(fieldObject(value, "inputs", "manifest"), "generationSha256", "manifest.inputs") != generationDigest(files)) {
			fail("manifest generationSha256 does not bind the file set", "generation-digest");
		}
	}

	public static function validateJournal(value:Dynamic):Void {
		exactFields(value, [
			"schema",
			"canonicalization",
			"journalDigestAlgorithm",
			"journalDigest",
			"transactionId",
			"mode",
			"phase",
			"locations",
			"priorManifest",
			"nextManifest",
			"operations"
		], "journal");
		expectString(value, "schema", "journal", JOURNAL_SCHEMA);
		expectString(value, "canonicalization", "journal", CANONICALIZATION);
		expectString(value, "journalDigestAlgorithm", "journal", JOURNAL_DIGEST_ALGORITHM);
		sha256(string(value, "journalDigest", "journal"), "journal.journalDigest");
		if (string(value, "journalDigest", "journal") != digestWithout(value, "journalDigest")) {
			fail("journalDigest does not bind the canonical journal", "journal-digest");
		}
		final transactionId = sha256(string(value, "transactionId", "journal"), "journal.transactionId");
		final mode = enumString(value, "mode", "journal", ["build", "clean", "adopt-generated"]);
		enumString(value, "phase", "journal", ["prepared", "publishing", "manifest-published"]);
		final locations = fieldObject(value, "locations", "journal");
		exactFields(locations, [
			"manifestPath",
			"transactionRoot",
			"lockPath",
			"journalPath",
			"workRoot",
			"stageRoot",
			"backupRoot"
		], "journal.locations");
		for (field in Reflect.fields(locations)) {
			relative(string(locations, field, "journal.locations"), "journal.locations." + field);
		}
		final transactionRoot = string(locations, "transactionRoot", "journal.locations");
		final workRoot = transactionRoot + "/" + transactionId;
		if (string(locations, "lockPath", "journal.locations") != transactionRoot + "/lock"
			|| string(locations, "journalPath", "journal.locations") != transactionRoot + "/journal.json"
			|| string(locations, "workRoot", "journal.locations") != workRoot
			|| string(locations, "stageRoot", "journal.locations") != workRoot + "/stage"
			|| string(locations, "backupRoot", "journal.locations") != workRoot + "/backup") {
			fail("journal reserved locations do not match transactionId", "journal-locations");
		}
		validateManifestState(fieldObject(value, "priorManifest", "journal"), "journal.priorManifest", false, workRoot);
		validateManifestState(fieldObject(value, "nextManifest", "journal"), "journal.nextManifest", true, workRoot);

		final operations = array(value, "operations", "journal");
		var previousPath:Null<String> = null;
		final operationIds = new Map<String, Bool>();
		final pathKeys = new Map<String, Bool>();
		for (index in 0...operations.length) {
			final operation = object(operations[index], "journal.operations[" + index + "]");
			exactFields(operation, [
				"operationId",
				"action",
				"path",
				"rootId",
				"oldContent",
				"newContent",
				"backupPath",
				"stagedPath"
			], "journal.operations[" + index + "]");
			final operationId = stableId(string(operation, "operationId", "journal operation"), "journal operation ID");
			if (operationIds.exists(operationId)) {
				fail("journal operation IDs are not unique", "journal-operations");
			}
			operationIds.set(operationId, true);
			final action = enumString(operation, "action", "journal operation", ["create", "replace", "remove", "relinquish"]);
			final path = relative(string(operation, "path", "journal operation"), "journal operation path");
			stableId(string(operation, "rootId", "journal operation"), "journal operation rootId");
			if (previousPath != null && Reflect.compare(previousPath, path) >= 0) {
				fail("journal operation paths are not sorted", "journal-operations");
			}
			previousPath = path;
			if (pathKeys.exists(collisionKey(path))) {
				fail("journal operation paths collide", "journal-operations");
			}
			pathKeys.set(collisionKey(path), true);
			final oldContent = fieldObject(operation, "oldContent", "journal operation");
			final newContent = fieldObject(operation, "newContent", "journal operation");
			validateContentState(oldContent, "journal operation oldContent", false);
			validateContentState(newContent, "journal operation newContent", false);
			final expectedStates = switch (action) {
				case "create": ["absent", "file"];
				case "replace": ["file", "file"];
				case "remove": ["file", "absent"];
				case "relinquish": ["file", "file"];
				case _: [];
			}
			if (string(oldContent, "state", "oldContent") != expectedStates[0]
				|| string(newContent, "state", "newContent") != expectedStates[1]) {
				fail("journal action does not match old/new content states", "journal-operations");
			}
			if (action == "replace" && string(oldContent, "sha256", "oldContent") == string(newContent, "sha256", "newContent")) {
				fail("journal replace operation does not change bytes", "journal-operations");
			}
			if (action == "relinquish" && OwnershipJson.encode(oldContent) != OwnershipJson.encode(newContent)) {
				fail("journal relinquish operation changes live bytes", "journal-operations");
			}
			if (string(operation, "backupPath", "journal operation") != string(locations, "backupRoot", "journal locations") + "/" + path
				|| string(operation, "stagedPath", "journal operation") != string(locations, "stageRoot", "journal locations") + "/" + path) {
				fail("journal staged or backup path is not content-path-derived", "journal-operations");
			}
			if (mode == "build" && action == "relinquish") {
				fail("build journal contains relinquish", "journal-mode");
			}
			if (mode == "clean" && action != "remove") {
				fail("clean journal contains a non-remove operation", "journal-mode");
			}
			if (mode == "adopt-generated" && action != "relinquish") {
				fail("adopt-generated journal contains a non-relinquish operation", "journal-mode");
			}
		}
		if (mode == "adopt-generated" && operations.length == 0) {
			fail("adopt-generated journal has no relinquish operations", "journal-mode");
		}
	}

	public static function validateJournalPlan(journal:Dynamic, prior:Null<Dynamic>, next:Dynamic):Void {
		final mode = string(journal, "mode", "journal");
		final priorFiles = prior == null ? new Map<String, Dynamic>() : fileMap(prior);
		final nextFiles = fileMap(next);
		final relinquished:Array<String> = [];
		if (mode == "adopt-generated") {
			if (prior == null) {
				fail("adopt-generated journal has no prior manifest", "journal-plan");
			}
			for (path => _ in priorFiles) {
				if (!nextFiles.exists(path)) {
					relinquished.push(path);
				}
			}
			relinquished.sort(Reflect.compare);
			if (relinquished.length == 0) {
				fail("adopt-generated journal does not relinquish an entry", "journal-plan");
			}
			for (path => item in nextFiles) {
				final old = priorFiles.get(path);
				if (old == null || OwnershipJson.encode(old) != OwnershipJson.encode(item)) {
					fail("adopt-generated journal changes a retained entry", "journal-plan", path);
				}
			}
		} else if (mode == "clean" && nextFiles.keys().hasNext()) {
			fail("clean journal has a non-empty next ownership set", "journal-plan");
		}
		final expected = makeJournal(prior, next, string(journal, "transactionId", "journal"), mode, relinquished);
		for (field in [
			"transactionId",
			"mode",
			"locations",
			"priorManifest",
			"nextManifest",
			"operations"
		]) {
			if (OwnershipJson.encode(Reflect.field(journal, field)) != OwnershipJson.encode(Reflect.field(expected, field))) {
				fail("journal " + field + " is not derived from its bound manifests", "journal-plan");
			}
		}
	}

	public static function makeJournal(prior:Null<Dynamic>, next:Dynamic, transactionId:String, mode:String, relinquished:Array<String>):Dynamic {
		final locations = fieldObject(next, "locations", "next manifest");
		final transactionRoot = string(locations, "transactionRoot", "manifest locations");
		final workRoot = transactionRoot + "/" + transactionId;
		final stageRoot = workRoot + "/stage";
		final backupRoot = workRoot + "/backup";
		final priorFiles = prior == null ? new Map<String, Dynamic>() : fileMap(prior);
		final nextFiles = fileMap(next);
		final relinquishSet = new Map<String, Bool>();
		for (path in relinquished) {
			relinquishSet.set(path, true);
		}
		final allPaths = [for (path => _ in priorFiles) path];
		for (path => _ in nextFiles) {
			if (allPaths.indexOf(path) < 0) {
				allPaths.push(path);
			}
		}
		allPaths.sort(Reflect.compare);
		final operations:Array<Dynamic> = [];
		for (pathIndex in 0...allPaths.length) {
			final path = allPaths[pathIndex];
			final old = priorFiles.get(path);
			final fresh = nextFiles.get(path);
			var action:Null<String> = null;
			var newContent:Dynamic = null;
			if (relinquishSet.exists(path)) {
				if (old == null || fresh != null) {
					fail("relinquish is not an exact current-owned removal", "journal-plan");
				}
				action = "relinquish";
				newContent = descriptorForFile(old);
			} else if (old == null) {
				action = "create";
				newContent = descriptorForFile(fresh);
			} else if (fresh == null) {
				action = "remove";
				newContent = OwnershipJson.contentState();
			} else if (string(old, "contentSha256", "old file") != string(fresh, "contentSha256", "new file")) {
				action = "replace";
				newContent = descriptorForFile(fresh);
			}
			if (action == null) {
				continue;
			}
			final source = fresh == null ? old : fresh;
			operations.push(OwnershipJson.object([
				"operationId" => "op/" + StringTools.lpad(Std.string(pathIndex + 1), "0", 4),
				"action" => action,
				"path" => path,
				"rootId" => string(source, "rootId", "manifest file"),
				"oldContent" => old == null ? OwnershipJson.contentState() : descriptorForFile(old),
				"newContent" => newContent,
				"backupPath" => backupRoot + "/" + path,
				"stagedPath" => stageRoot + "/" + path
			]));
		}
		final priorBuffer = prior == null ? null : OwnershipJson.encodeDocument(prior);
		final nextBuffer = OwnershipJson.encodeDocument(next);
		final journal = OwnershipJson.object([
			"schema" => JOURNAL_SCHEMA,
			"canonicalization" => CANONICALIZATION,
			"journalDigestAlgorithm" => JOURNAL_DIGEST_ALGORITHM,
			"transactionId" => transactionId,
			"mode" => mode,
			"phase" => "prepared",
			"locations" => OwnershipJson.object([
				"manifestPath" => string(locations, "manifestPath", "manifest locations"),
				"transactionRoot" => transactionRoot,
				"lockPath" => string(locations, "lockPath", "manifest locations"),
				"journalPath" => string(locations, "journalPath", "manifest locations"),
				"workRoot" => workRoot,
				"stageRoot" => stageRoot,
				"backupRoot" => backupRoot
			]),
			"priorManifest" => OwnershipJson.object([
				"content" => OwnershipJson.contentState(priorBuffer),
				"storagePath" => workRoot + "/prior-manifest.json"
			]),
			"nextManifest" => OwnershipJson.object([
				"content" => OwnershipJson.contentState(nextBuffer),
				"storagePath" => workRoot + "/next-manifest.json"
			]),
			"operations" => operations
		]);
		return withDigest(journal, "journalDigest");
	}

	public static function deriveManifest(current:Dynamic, retainedPaths:Array<String>):Dynamic {
		final retained = new Map<String, Bool>();
		for (path in retainedPaths) {
			retained.set(path, true);
		}
		final result = OwnershipJson.clone(current);
		final files = [
			for (item in array(result, "files", "manifest"))
				if (retained.exists(string(item, "path", "manifest file"))) item
		];
		Reflect.setField(result, "files", files);
		Reflect.setField(fieldObject(result, "inputs", "manifest"), "generationSha256", generationDigest(files));
		return withDigest(result, "manifestDigest");
	}

	public static function withDigest(value:Dynamic, field:String):Dynamic {
		final result = OwnershipJson.clone(value);
		Reflect.deleteField(result, field);
		Reflect.setField(result, field, OwnershipJson.digestValue(result));
		return result;
	}

	public static function fileMap(manifest:Dynamic):Map<String, Dynamic> {
		final result = new Map<String, Dynamic>();
		for (item in array(manifest, "files", "manifest")) {
			result.set(string(item, "path", "manifest file"), item);
		}
		return result;
	}

	public static function generationDigest(files:Array<Dynamic>):String {
		final material:Array<Dynamic> = [];
		for (item in files) {
			material.push(OwnershipJson.object([
				"contentSha256" => string(item, "contentSha256", "manifest file"),
				"path" => string(item, "path", "manifest file"),
				"sizeBytes" => integer(item, "sizeBytes", "manifest file")
			]));
		}
		return OwnershipJson.digestValue(material);
	}

	public static function relative(value:String, label:String):String {
		if (value == null || value.length == 0 || OwnershipJson.nfc(value) != value || value.indexOf("\\") >= 0 || StringTools.startsWith(value, "/")) {
			fail(label + " is not an NFC project-relative POSIX path", "unsafe-path", value);
		}
		final segments = value.split("/");
		for (segment in segments) {
			final stem = segment.split(".")[0].toLowerCase();
			if (segment.length == 0 || segment == "." || segment == ".." || !PORTABLE_SEGMENT.match(segment) || StringTools.endsWith(segment, ".")
				|| StringTools.endsWith(segment, " ") || WINDOWS_RESERVED.indexOf(stem) >= 0) {
				fail(label + " is outside the portable path policy", "unsafe-path", value);
			}
		}
		return value;
	}

	public static function atOrBelow(path:String, root:String):Bool {
		final pathParts = path.split("/");
		final rootParts = root.split("/");
		if (pathParts.length < rootParts.length) {
			return false;
		}
		for (index in 0...rootParts.length) {
			if (pathParts[index] != rootParts[index]) {
				return false;
			}
		}
		return true;
	}

	public static function string(value:Dynamic, field:String, label:String):String {
		final child = Reflect.field(object(value, label), field);
		if (!Std.isOfType(child, String) || child.length == 0) {
			fail(label + "." + field + " must be a non-empty string", "contract-shape");
		}
		return cast child;
	}

	public static function integer(value:Dynamic, field:String, label:String):Dynamic {
		final child = Reflect.field(object(value, label), field);
		if (!OwnershipJson.isSafeInteger(child)) {
			fail(label + "." + field + " must be a safe integer", "contract-shape");
		}
		return child;
	}

	public static function array(value:Dynamic, field:String, label:String):Array<Dynamic> {
		final child = Reflect.field(object(value, label), field);
		if (!Std.isOfType(child, Array)) {
			fail(label + "." + field + " must be an array", "contract-shape");
		}
		return cast child;
	}

	public static function object(value:Dynamic, label:String):Dynamic {
		if (value == null || !Reflect.isObject(value) || Std.isOfType(value, Array) || Std.isOfType(value, String)) {
			fail(label + " must be an object", "contract-shape");
		}
		return value;
	}

	public static function fieldObject(value:Dynamic, field:String, label:String):Dynamic {
		return object(Reflect.field(object(value, label), field), label + "." + field);
	}

	public static function exactFields(value:Dynamic, expected:Array<String>, label:String):Void {
		object(value, label);
		final actual = Reflect.fields(value);
		actual.sort(Reflect.compare);
		final wanted = expected.copy();
		wanted.sort(Reflect.compare);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail(label + " fields differ; expected " + wanted.join(", ") + ", found " + actual.join(", "), "contract-shape");
		}
	}

	public static function fail(message:String, code:String = "ownership-contract", ?path:String):Dynamic {
		throw new OwnershipFailure(message, code, path);
	}

	static function validateGenerator(value:Dynamic):Void {
		exactFields(value, [
			"sdkVersion",
			"cliVersion",
			"generatorId",
			"generatorSourceSha256",
			"toolchainSha256"
		], "manifest.generator");
		string(value, "sdkVersion", "manifest.generator");
		string(value, "cliVersion", "manifest.generator");
		stableId(string(value, "generatorId", "manifest.generator"), "manifest.generator.generatorId");
		sha256(string(value, "generatorSourceSha256", "manifest.generator"), "manifest.generator.generatorSourceSha256");
		sha256(string(value, "toolchainSha256", "manifest.generator"), "manifest.generator.toolchainSha256");
	}

	static function validateInputs(value:Dynamic):Void {
		exactFields(value, [
			"sourceTreeSha256",
			"semanticPlanSha256",
			"emissionResultSha256s",
			"generationSha256",
			"profile"
		], "manifest.inputs");
		sha256(string(value, "sourceTreeSha256", "manifest.inputs"), "manifest.inputs.sourceTreeSha256");
		sha256(string(value, "semanticPlanSha256", "manifest.inputs"), "manifest.inputs.semanticPlanSha256");
		sha256(string(value, "generationSha256", "manifest.inputs"), "manifest.inputs.generationSha256");
		validateSortedStrings(array(value, "emissionResultSha256s", "manifest.inputs"), "manifest.inputs.emissionResultSha256s", true, sha256);
		final profile = fieldObject(value, "profile", "manifest.inputs");
		exactFields(profile, ["profileId", "catalogRevision", "catalogSha256"], "manifest.inputs.profile");
		stableId(string(profile, "profileId", "manifest.inputs.profile"), "manifest.inputs.profile.profileId");
		string(profile, "catalogRevision", "manifest.inputs.profile");
		sha256(string(profile, "catalogSha256", "manifest.inputs.profile"), "manifest.inputs.profile.catalogSha256");
	}

	static function validateValidator(value:Dynamic, index:Int):Void {
		final label = "manifest.validators[" + index + "]";
		exactFields(value, [
			"validatorId",
			"tool",
			"version",
			"toolSha256",
			"configSha256",
			"scope",
			"outcome"
		], label);
		stableId(string(value, "validatorId", label), label + ".validatorId");
		string(value, "tool", label);
		string(value, "version", label);
		sha256(string(value, "toolSha256", label), label + ".toolSha256");
		sha256(string(value, "configSha256", label), label + ".configSha256");
		enumString(value, "scope", label, ["complete-staged-tree", "selected-artifacts"]);
		expectString(value, "outcome", label, "passed");
	}

	static function validateFile(item:Dynamic, index:Int, roots:Array<Dynamic>, validatorIds:Map<String, Bool>, locations:Dynamic):Void {
		final label = "manifest.files[" + index + "]";
		exactFields(item, [
			"path",
			"rootId",
			"contentSha256",
			"sizeBytes",
			"kind",
			"ownerNodeId",
			"projectionIds",
			"sourceNodeIds",
			"sourceSpans",
			"validatorIds"
		], label);
		final path = relative(string(item, "path", label), label + ".path");
		stableId(string(item, "rootId", label), label + ".rootId");
		sha256(string(item, "contentSha256", label), label + ".contentSha256");
		if (integer(item, "sizeBytes", label) < 0) {
			fail(label + ".sizeBytes must be non-negative", "contract-shape");
		}
		stableId(string(item, "kind", label), label + ".kind");
		stableId(string(item, "ownerNodeId", label), label + ".ownerNodeId");
		validateSortedStrings(array(item, "projectionIds", label), label + ".projectionIds", true, stableId);
		validateSortedStrings(array(item, "sourceNodeIds", label), label + ".sourceNodeIds", true, stableId);
		final namedValidators = validateSortedStrings(array(item, "validatorIds", label), label + ".validatorIds", true, stableId);
		for (validatorId in namedValidators) {
			if (!validatorIds.exists(validatorId)) {
				fail(label + " names an unknown validator " + validatorId, "manifest-validators");
			}
		}
		if (path == string(locations, "manifestPath", "locations") || atOrBelow(path, string(locations, "transactionRoot", "locations"))) {
			fail(label + " uses a reserved ownership path", "manifest-files", path);
		}
		var ownerCount = 0;
		var ownerId:Null<String> = null;
		for (root in roots) {
			if (atOrBelow(path, string(root, "path", "output root"))) {
				ownerCount++;
				ownerId = string(root, "rootId", "output root");
			}
		}
		if (ownerCount != 1 || ownerId != string(item, "rootId", label)) {
			fail(label + " is not confined to its declared output root", "manifest-files", path);
		}
		final spans = array(item, "sourceSpans", label);
		if (spans.length == 0) {
			fail(label + ".sourceSpans must not be empty", "contract-shape");
		}
		var previous:Null<String> = null;
		for (spanIndex in 0...spans.length) {
			final span = object(spans[spanIndex], label + ".sourceSpans[" + spanIndex + "]");
			exactFields(span, ["path", "sourceSha256", "start", "end", "symbol"], label + ".sourceSpans[" + spanIndex + "]");
			final spanPath = relative(string(span, "path", "source span"), "source span path");
			sha256(string(span, "sourceSha256", "source span"), "source span sourceSha256");
			string(span, "symbol", "source span");
			final start = validatePoint(fieldObject(span, "start", "source span"), "source span start");
			final end = validatePoint(fieldObject(span, "end", "source span"), "source span end");
			if (start >= end) {
				fail("source span is empty or reversed", "manifest-source-span", spanPath);
			}
			final key = spanPath + "\x00" + start + "\x00" + end + "\x00" + string(span, "symbol", "source span");
			if (previous != null && Reflect.compare(previous, key) >= 0) {
				fail("source spans are not a sorted unique set", "manifest-source-span", spanPath);
			}
			previous = key;
		}
	}

	static function validatePoint(value:Dynamic, label:String):Dynamic {
		exactFields(value, ["offset", "line", "column"], label);
		final offset = integer(value, "offset", label);
		if (offset < 0 || integer(value, "line", label) < 1 || integer(value, "column", label) < 0) {
			fail(label + " has invalid coordinates", "manifest-source-span");
		}
		return offset;
	}

	static function validateManifestState(value:Dynamic, label:String, requirePresent:Bool, workRoot:String):Void {
		exactFields(value, ["content", "storagePath"], label);
		validateContentState(fieldObject(value, "content", label), label + ".content", requirePresent);
		final storagePath = relative(string(value, "storagePath", label), label + ".storagePath");
		if (!atOrBelow(storagePath, workRoot)) {
			fail(label + " storagePath escapes workRoot", "journal-locations", storagePath);
		}
	}

	public static function validateContentState(value:Dynamic, label:String, requirePresent:Bool):Void {
		final state = string(value, "state", label);
		if (state == "absent") {
			if (requirePresent) {
				fail(label + " must be present", "journal-content");
			}
			exactFields(value, ["state"], label);
			return;
		}
		if (state != "file") {
			fail(label + " has an unknown content state", "journal-content");
		}
		exactFields(value, ["state", "sha256", "sizeBytes"], label);
		sha256(string(value, "sha256", label), label + ".sha256");
		if (integer(value, "sizeBytes", label) < 0) {
			fail(label + ".sizeBytes must be non-negative", "journal-content");
		}
	}

	static function descriptorForFile(item:Dynamic):Dynamic {
		return OwnershipJson.object([
			"state" => "file",
			"sha256" => string(item, "contentSha256", "manifest file"),
			"sizeBytes" => integer(item, "sizeBytes", "manifest file")
		]);
	}

	static function validateSortedStrings(values:Array<Dynamic>, label:String, requireNonEmpty:Bool, validator:(String, String) -> String):Array<String> {
		if (requireNonEmpty && values.length == 0) {
			fail(label + " must not be empty", "contract-shape");
		}
		final result:Array<String> = [];
		var previous:Null<String> = null;
		for (index in 0...values.length) {
			if (!Std.isOfType(values[index], String)) {
				fail(label + "[" + index + "] must be a string", "contract-shape");
			}
			final value:String = cast values[index];
			validator(value, label + "[" + index + "]");
			if (previous != null && Reflect.compare(previous, value) >= 0) {
				fail(label + " is not a sorted unique set", "contract-shape");
			}
			previous = value;
			result.push(value);
		}
		return result;
	}

	static function digestWithout(value:Dynamic, field:String):String {
		final material = OwnershipJson.clone(value);
		Reflect.deleteField(material, field);
		return OwnershipJson.digestValue(material);
	}

	static function sha256(value:String, label:String):String {
		if (value == null || !SHA256.match(value)) {
			fail(label + " is not a lowercase SHA-256", "contract-shape");
		}
		return value;
	}

	static function stableId(value:String, label:String):String {
		if (value == null || !STABLE_ID.match(value)) {
			fail(label + " is not a stable ID", "contract-shape");
		}
		return value;
	}

	static function collisionKey(value:String):String {
		return value.toLowerCase();
	}

	static function expectString(value:Dynamic, field:String, label:String, expected:String):Void {
		if (string(value, field, label) != expected) {
			fail(label + "." + field + " must equal " + expected, "contract-version");
		}
	}

	static function enumString(value:Dynamic, field:String, label:String, allowed:Array<String>):String {
		final result = string(value, field, label);
		if (allowed.indexOf(result) < 0) {
			fail(label + "." + field + " is outside the closed enum", "contract-shape");
		}
		return result;
	}
}
