package wordpresshx.cli.ownership;

import js.node.Buffer;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Closed v1 ownership codecs plus deterministic manifest and journal derivation. **/
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

	public static function validateManifest(value:JsonValue):OwnershipManifest {
		final root = OwnershipReader.from(value, "manifest");
		root.exact([
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
		]);
		expect(root.string("schema"), MANIFEST_SCHEMA, "manifest.schema");
		expect(root.string("canonicalization"), CANONICALIZATION, "manifest.canonicalization");
		expect(root.string("transactionProtocol"), TRANSACTION_PROTOCOL, "manifest.transactionProtocol");
		expect(root.string("manifestDigestAlgorithm"), MANIFEST_DIGEST_ALGORITHM, "manifest.manifestDigestAlgorithm");
		final manifestDigest = sha256(root.string("manifestDigest"), "manifest.manifestDigest");
		if (manifestDigest != digestWithout(value, "manifestDigest")) {
			fail("manifestDigest does not bind the canonical manifest", "manifest-digest");
		}

		final locations = decodeManifestLocations(root.object("locations"));
		validateGenerator(root.object("generator"));
		final inputs = validateInputs(root.object("inputs"));
		final roots = decodeRoots(root.array("outputRoots"), locations);
		final validators = decodeValidators(root.array("validators"));
		final validatorIds = new Map<String, Bool>();
		for (validator in validators) {
			validatorIds.set(validator.validatorId, true);
		}
		final files = decodeFiles(root.array("files"), roots, validatorIds, locations);
		if (inputs.generationSha256 != generationDigest(files)) {
			fail("manifest generationSha256 does not bind the file set", "generation-digest");
		}
		return new OwnershipManifest(value, manifestDigest, locations, inputs, roots, validators, files);
	}

	public static function validateJournal(value:JsonValue):OwnershipJournal {
		final root = OwnershipReader.from(value, "journal");
		root.exact([
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
		]);
		expect(root.string("schema"), JOURNAL_SCHEMA, "journal.schema");
		expect(root.string("canonicalization"), CANONICALIZATION, "journal.canonicalization");
		expect(root.string("journalDigestAlgorithm"), JOURNAL_DIGEST_ALGORITHM, "journal.journalDigestAlgorithm");
		final journalDigest = sha256(root.string("journalDigest"), "journal.journalDigest");
		if (journalDigest != digestWithout(value, "journalDigest")) {
			fail("journalDigest does not bind the canonical journal", "journal-digest");
		}
		final transactionId = sha256(root.string("transactionId"), "journal.transactionId");
		final mode = decodeMode(root.string("mode"), "journal.mode");
		final phase = decodePhase(root.string("phase"), "journal.phase");
		final locations = decodeJournalLocations(root.object("locations"), transactionId);
		final priorManifest = decodeManifestState(root.object("priorManifest"), "journal.priorManifest", false, locations.workRoot);
		final nextManifest = decodeManifestState(root.object("nextManifest"), "journal.nextManifest", true, locations.workRoot);
		final operations = decodeOperations(root.array("operations"), mode, locations);
		if (mode == AdoptGenerated && operations.length == 0) {
			fail("adopt-generated journal has no relinquish operations", "journal-mode");
		}
		return new OwnershipJournal(value, journalDigest, transactionId, mode, phase, locations, priorManifest, nextManifest, operations);
	}

	public static function validateJournalPlan(journal:OwnershipJournal, prior:Null<OwnershipManifest>, next:OwnershipManifest):Void {
		final priorFiles = prior == null ? new Map<String, OwnershipFile>() : fileMap(prior);
		final nextFiles = fileMap(next);
		final relinquished:Array<String> = [];
		if (journal.mode == AdoptGenerated) {
			if (prior == null) {
				fail("adopt-generated journal has no prior manifest", "journal-plan");
			}
			for (path => _ in priorFiles) {
				if (!nextFiles.exists(path)) {
					relinquished.push(path);
				}
			}
			relinquished.sort(compareText);
			if (relinquished.length == 0) {
				fail("adopt-generated journal does not relinquish an entry", "journal-plan");
			}
			for (path => item in nextFiles) {
				final old = priorFiles.get(path);
				if (old == null || OwnershipJson.encode(old.json) != OwnershipJson.encode(item.json)) {
					fail("adopt-generated journal changes a retained entry", "journal-plan", path);
				}
			}
		} else if (journal.mode == Clean && nextFiles.keys().hasNext()) {
			fail("clean journal has a non-empty next ownership set", "journal-plan");
		}
		final expected = makeJournal(prior, next, journal.transactionId, journal.mode, relinquished);
		if (journal.transactionId != expected.transactionId
			|| journal.mode != expected.mode
			|| OwnershipJson.encode(journal.locations.json) != OwnershipJson.encode(expected.locations.json)
			|| OwnershipJson.encode(journal.priorManifest.json) != OwnershipJson.encode(expected.priorManifest.json)
			|| OwnershipJson.encode(journal.nextManifest.json) != OwnershipJson.encode(expected.nextManifest.json)
			|| OwnershipJson.encode(ArrayValue([for (operation in journal.operations) operation.json])) != OwnershipJson.encode(ArrayValue([for (operation in expected.operations) operation.json]))) {
			fail("journal plan is not derived from its bound manifests", "journal-plan");
		}
	}

	public static function makeJournal(prior:Null<OwnershipManifest>, next:OwnershipManifest, transactionId:String, mode:OwnershipMode,
			relinquished:Array<String>):OwnershipJournal {
		sha256(transactionId, "journal.transactionId");
		final workRoot = next.locations.transactionRoot + "/" + transactionId;
		final stageRoot = workRoot + "/stage";
		final backupRoot = workRoot + "/backup";
		final priorFiles = prior == null ? new Map<String, OwnershipFile>() : fileMap(prior);
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
		allPaths.sort(compareText);
		final operations:Array<OwnershipOperation> = [];
		for (pathIndex in 0...allPaths.length) {
			final path = allPaths[pathIndex];
			final old = priorFiles.get(path);
			final fresh = nextFiles.get(path);
			var action:Null<OwnershipAction> = null;
			var newContent:Null<OwnershipContentState> = null;
			if (relinquishSet.exists(path)) {
				if (old == null || fresh != null) {
					fail("relinquish is not an exact current-owned removal", "journal-plan");
				}
				action = Relinquish;
				newContent = descriptorForFile(old);
			} else if (old == null && fresh != null) {
				action = Create;
				newContent = descriptorForFile(fresh);
			} else if (old != null && fresh == null) {
				action = Remove;
				newContent = AbsentContent;
			} else if (old != null && fresh != null && old.contentSha256 != fresh.contentSha256) {
				action = Replace;
				newContent = descriptorForFile(fresh);
			}
			if (action == null || newContent == null) {
				continue;
			}
			final source = fresh == null ? old : fresh;
			if (source == null) {
				fail("journal operation has no manifest source", "journal-plan", path);
			}
			final operationId = "op/" + StringTools.lpad(Std.string(pathIndex + 1), "0", 4);
			final oldContent = old == null ? AbsentContent : descriptorForFile(old);
			final operationValue = operationJson(operationId, action, path, source.rootId, oldContent, newContent, backupRoot + "/" + path,
				stageRoot + "/" + path);
			operations.push(new OwnershipOperation(operationValue, operationId, action, path, source.rootId, oldContent, newContent, backupRoot
				+ "/"
				+ path,
				stageRoot
				+ "/"
				+ path));
		}
		final priorBuffer = prior == null ? null : OwnershipJson.encodeDocument(prior.json);
		final nextBuffer = OwnershipJson.encodeDocument(next.json);
		final locationsValue = OwnershipJson.object([
			"manifestPath" => OwnershipJson.text(next.locations.manifestPath),
			"transactionRoot" => OwnershipJson.text(next.locations.transactionRoot),
			"lockPath" => OwnershipJson.text(next.locations.lockPath),
			"journalPath" => OwnershipJson.text(next.locations.journalPath),
			"workRoot" => OwnershipJson.text(workRoot),
			"stageRoot" => OwnershipJson.text(stageRoot),
			"backupRoot" => OwnershipJson.text(backupRoot)
		]);
		final priorState = manifestState(contentState(priorBuffer), workRoot + "/prior-manifest.json");
		final nextState = manifestState(contentState(nextBuffer), workRoot + "/next-manifest.json");
		final base = OwnershipJson.object([
			"schema" => OwnershipJson.text(JOURNAL_SCHEMA),
			"canonicalization" => OwnershipJson.text(CANONICALIZATION),
			"journalDigestAlgorithm" => OwnershipJson.text(JOURNAL_DIGEST_ALGORITHM),
			"transactionId" => OwnershipJson.text(transactionId),
			"mode" => OwnershipJson.text(mode),
			"phase" => OwnershipJson.text(Prepared),
			"locations" => locationsValue,
			"priorManifest" => priorState.json,
			"nextManifest" => nextState.json,
			"operations" => ArrayValue([for (operation in operations) operation.json])
		]);
		return validateJournal(withDigest(base, "journalDigest"));
	}

	public static function deriveManifest(current:OwnershipManifest, retainedPaths:Array<String>):OwnershipManifest {
		final retained = new Map<String, Bool>();
		for (path in retainedPaths) {
			retained.set(path, true);
		}
		final files = [for (item in current.files) if (retained.exists(item.path)) item];
		final filesValue = ArrayValue([for (item in files) item.json]);
		final inputsValue = replaceField(current.inputs.json, "generationSha256", OwnershipJson.text(generationDigest(files)));
		var result = replaceField(current.json, "files", filesValue);
		result = replaceField(result, "inputs", inputsValue);
		result = withDigest(result, "manifestDigest");
		return validateManifest(result);
	}

	public static function withPhase(journal:OwnershipJournal, phase:OwnershipPhase):OwnershipJournal {
		var value = replaceField(journal.json, "phase", OwnershipJson.text(phase));
		value = withDigest(value, "journalDigest");
		return validateJournal(value);
	}

	public static function fileMap(manifest:OwnershipManifest):Map<String, OwnershipFile> {
		final result = new Map<String, OwnershipFile>();
		for (item in manifest.files) {
			result.set(item.path, item);
		}
		return result;
	}

	public static function generationDigest(files:Array<OwnershipFile>):String {
		final material = ArrayValue([
			for (item in files)
				OwnershipJson.object([
					"contentSha256" => OwnershipJson.text(item.contentSha256),
					"path" => OwnershipJson.text(item.path),
					"sizeBytes" => OwnershipJson.number(item.sizeBytes)
				])
		]);
		return OwnershipJson.digestValue(material);
	}

	public static function contentState(?buffer:Buffer):OwnershipContentState {
		return buffer == null ? AbsentContent : FileContent(OwnershipJson.digest(buffer), buffer.length);
	}

	public static function contentJson(state:OwnershipContentState):JsonValue {
		return switch state {
			case AbsentContent: OwnershipJson.object(["state" => OwnershipJson.text("absent")]);
			case FileContent(sha256, sizeBytes): OwnershipJson.object([
					"state" => OwnershipJson.text("file"),
					"sha256" => OwnershipJson.text(sha256),
					"sizeBytes" => OwnershipJson.number(sizeBytes)
				]);
		};
	}

	public static function contentEquals(left:OwnershipContentState, right:OwnershipContentState):Bool {
		return switch [left, right] {
			case [AbsentContent, AbsentContent]: true;
			case [FileContent(leftSha, leftSize), FileContent(rightSha, rightSize)]: leftSha == rightSha && leftSize == rightSize;
			case _: false;
		};
	}

	public static inline function isAbsent(state:OwnershipContentState):Bool {
		return switch state {
			case AbsentContent: true;
			case FileContent(_, _): false;
		};
	}

	public static inline function isFile(state:OwnershipContentState):Bool {
		return !isAbsent(state);
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

	public static function decodeLock(value:JsonValue):OwnershipLock {
		final reader = OwnershipReader.from(value, "ownership lock");
		reader.exact(["schema", "transactionId", "pid", "projectDevice", "projectInode"]);
		expect(reader.string("schema"), "wordpress-hx.ownership-lock.v1", "ownership lock.schema");
		final transactionId = sha256(reader.string("transactionId"), "ownership lock.transactionId");
		final pid = reader.integer("pid");
		final projectDevice = reader.safeNumber("projectDevice");
		final projectInode = reader.safeNumber("projectInode");
		if (pid <= 0 || projectDevice < 0 || projectInode < 0) {
			fail("ownership lock contains invalid process or project identity", "invalid-lock");
		}
		return new OwnershipLock(transactionId, pid, projectDevice, projectInode);
	}

	public static function fail<T>(message:String, code:String = "ownership-contract", ?path:String):T {
		throw new OwnershipFailure(message, code, path);
	}

	static function decodeManifestLocations(reader:OwnershipReader):OwnershipManifestLocations {
		reader.exact(["manifestPath", "transactionRoot", "lockPath", "journalPath"]);
		final manifestPath = relative(reader.string("manifestPath"), "manifest.locations.manifestPath");
		final transactionRoot = relative(reader.string("transactionRoot"), "manifest.locations.transactionRoot");
		final lockPath = relative(reader.string("lockPath"), "manifest.locations.lockPath");
		final journalPath = relative(reader.string("journalPath"), "manifest.locations.journalPath");
		if (lockPath != transactionRoot + "/lock" || journalPath != transactionRoot + "/journal.json") {
			fail("manifest ownership lock and journal are not derived from transactionRoot", "manifest-locations");
		}
		if (atOrBelow(manifestPath, transactionRoot) || atOrBelow(transactionRoot, manifestPath)) {
			fail("manifestPath and transactionRoot must be disjoint", "manifest-locations");
		}
		return new OwnershipManifestLocations(reader.value, manifestPath, transactionRoot, lockPath, journalPath);
	}

	static function validateGenerator(reader:OwnershipReader):Void {
		reader.exact([
			"sdkVersion",
			"cliVersion",
			"generatorId",
			"generatorSourceSha256",
			"toolchainSha256"
		]);
		reader.string("sdkVersion");
		reader.string("cliVersion");
		stableId(reader.string("generatorId"), "manifest.generator.generatorId");
		sha256(reader.string("generatorSourceSha256"), "manifest.generator.generatorSourceSha256");
		sha256(reader.string("toolchainSha256"), "manifest.generator.toolchainSha256");
	}

	static function validateInputs(reader:OwnershipReader):OwnershipInputs {
		reader.exact([
			"sourceTreeSha256",
			"semanticPlanSha256",
			"emissionResultSha256s",
			"generationSha256",
			"profile"
		]);
		sha256(reader.string("sourceTreeSha256"), "manifest.inputs.sourceTreeSha256");
		sha256(reader.string("semanticPlanSha256"), "manifest.inputs.semanticPlanSha256");
		final generationSha256 = sha256(reader.string("generationSha256"), "manifest.inputs.generationSha256");
		validateSortedStrings(reader.array("emissionResultSha256s"), "manifest.inputs.emissionResultSha256s", true, sha256);
		final profile = reader.object("profile");
		profile.exact(["profileId", "catalogRevision", "catalogSha256"]);
		stableId(profile.string("profileId"), "manifest.inputs.profile.profileId");
		profile.string("catalogRevision");
		sha256(profile.string("catalogSha256"), "manifest.inputs.profile.catalogSha256");
		return new OwnershipInputs(reader.value, generationSha256);
	}

	static function decodeRoots(values:Array<JsonValue>, locations:OwnershipManifestLocations):Array<OwnershipOutputRoot> {
		if (values.length == 0) {
			fail("manifest.outputRoots must not be empty", "manifest-roots");
		}
		final roots:Array<OwnershipOutputRoot> = [];
		final rootIds = new Map<String, Bool>();
		final rootKeys = new Map<String, Bool>();
		var previousRootKey:Null<String> = null;
		for (index in 0...values.length) {
			final reader = OwnershipReader.from(values[index], "manifest.outputRoots[" + index + "]");
			reader.exact(["rootId", "path", "ownershipMode"]);
			final rootId = stableId(reader.string("rootId"), "manifest.outputRoots[" + index + "].rootId");
			final path = relative(reader.string("path"), "manifest.outputRoots[" + index + "].path");
			expect(reader.string("ownershipMode"), "exact-file-manifest-coexists-with-unowned", "manifest.outputRoots[" + index + "].ownershipMode");
			final orderKey = path + "\x00" + rootId;
			if (previousRootKey != null && compareText(previousRootKey, orderKey) >= 0) {
				fail("manifest output roots are not a sorted unique set", "manifest-roots");
			}
			previousRootKey = orderKey;
			if (rootIds.exists(rootId) || rootKeys.exists(collisionKey(path))) {
				fail("manifest contains a duplicate output root identity or path", "manifest-roots");
			}
			for (other in roots) {
				if (atOrBelow(path, other.path) || atOrBelow(other.path, path)) {
					fail("nested output roots are forbidden in v1", "manifest-roots");
				}
			}
			rootIds.set(rootId, true);
			rootKeys.set(collisionKey(path), true);
			roots.push(new OwnershipOutputRoot(reader.value, rootId, path));
		}
		for (reserved in [locations.manifestPath, locations.transactionRoot]) {
			var contained = false;
			for (candidate in roots) {
				if (reserved != candidate.path && atOrBelow(reserved, candidate.path)) {
					contained = true;
				}
			}
			if (!contained) {
				fail("reserved ownership path is outside declared output roots", "manifest-roots");
			}
		}
		return roots;
	}

	static function decodeValidators(values:Array<JsonValue>):Array<OwnershipValidator> {
		if (values.length == 0) {
			fail("manifest.validators must not be empty", "manifest-validators");
		}
		final validators:Array<OwnershipValidator> = [];
		var previous:Null<String> = null;
		for (index in 0...values.length) {
			final label = "manifest.validators[" + index + "]";
			final reader = OwnershipReader.from(values[index], label);
			reader.exact([
				"validatorId",
				"tool",
				"version",
				"toolSha256",
				"configSha256",
				"scope",
				"outcome"
			]);
			final id = stableId(reader.string("validatorId"), label + ".validatorId");
			reader.string("tool");
			reader.string("version");
			sha256(reader.string("toolSha256"), label + ".toolSha256");
			sha256(reader.string("configSha256"), label + ".configSha256");
			expectOne(reader.string("scope"), ["complete-staged-tree", "selected-artifacts"], label + ".scope");
			expect(reader.string("outcome"), "passed", label + ".outcome");
			if (previous != null && compareText(previous, id) >= 0) {
				fail("manifest validators are not a sorted unique set", "manifest-validators");
			}
			previous = id;
			validators.push(new OwnershipValidator(reader.value, id));
		}
		return validators;
	}

	static function decodeFiles(values:Array<JsonValue>, roots:Array<OwnershipOutputRoot>, validatorIds:Map<String, Bool>,
			locations:OwnershipManifestLocations):Array<OwnershipFile> {
		final files:Array<OwnershipFile> = [];
		var previousPath:Null<String> = null;
		final pathKeys = new Map<String, Bool>();
		for (index in 0...values.length) {
			final label = "manifest.files[" + index + "]";
			final reader = OwnershipReader.from(values[index], label);
			reader.exact([
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
			]);
			final path = relative(reader.string("path"), label + ".path");
			final rootId = stableId(reader.string("rootId"), label + ".rootId");
			final contentSha256 = sha256(reader.string("contentSha256"), label + ".contentSha256");
			final sizeBytes = reader.integer("sizeBytes");
			if (sizeBytes < 0) {
				fail(label + ".sizeBytes must be non-negative", "contract-shape");
			}
			stableId(reader.string("kind"), label + ".kind");
			stableId(reader.string("ownerNodeId"), label + ".ownerNodeId");
			validateSortedStrings(reader.array("projectionIds"), label + ".projectionIds", true, stableId);
			validateSortedStrings(reader.array("sourceNodeIds"), label + ".sourceNodeIds", true, stableId);
			final namedValidators = validateSortedStrings(reader.array("validatorIds"), label + ".validatorIds", true, stableId);
			for (validatorId in namedValidators) {
				if (!validatorIds.exists(validatorId)) {
					fail(label + " names an unknown validator " + validatorId, "manifest-validators");
				}
			}
			if (path == locations.manifestPath || atOrBelow(path, locations.transactionRoot)) {
				fail(label + " uses a reserved ownership path", "manifest-files", path);
			}
			var ownerCount = 0;
			var ownerId:Null<String> = null;
			for (root in roots) {
				if (atOrBelow(path, root.path)) {
					ownerCount++;
					ownerId = root.rootId;
				}
			}
			if (ownerCount != 1 || ownerId != rootId) {
				fail(label + " is not confined to its declared output root", "manifest-files", path);
			}
			validateSourceSpans(reader.array("sourceSpans"), label);
			if (previousPath != null && compareText(previousPath, path) >= 0) {
				fail("manifest files are not sorted by exact path", "manifest-files");
			}
			previousPath = path;
			final key = collisionKey(path);
			if (pathKeys.exists(key)) {
				fail("manifest files contain a case-folding collision", "manifest-files");
			}
			pathKeys.set(key, true);
			files.push(new OwnershipFile(reader.value, path, rootId, contentSha256, sizeBytes));
		}
		return files;
	}

	static function validateSourceSpans(values:Array<JsonValue>, fileLabel:String):Void {
		if (values.length == 0) {
			fail(fileLabel + ".sourceSpans must not be empty", "contract-shape");
		}
		var previous:Null<String> = null;
		for (index in 0...values.length) {
			final label = fileLabel + ".sourceSpans[" + index + "]";
			final reader = OwnershipReader.from(values[index], label);
			reader.exact(["path", "sourceSha256", "start", "end", "symbol"]);
			final path = relative(reader.string("path"), "source span path");
			sha256(reader.string("sourceSha256"), "source span sourceSha256");
			final symbol = reader.string("symbol");
			final start = validatePoint(reader.object("start"), "source span start");
			final end = validatePoint(reader.object("end"), "source span end");
			if (start >= end) {
				fail("source span is empty or reversed", "manifest-source-span", path);
			}
			final key = path + "\x00" + start + "\x00" + end + "\x00" + symbol;
			if (previous != null && compareText(previous, key) >= 0) {
				fail("source spans are not a sorted unique set", "manifest-source-span", path);
			}
			previous = key;
		}
	}

	static function validatePoint(reader:OwnershipReader, label:String):Int {
		reader.exact(["offset", "line", "column"]);
		final offset = reader.integer("offset");
		if (offset < 0 || reader.integer("line") < 1 || reader.integer("column") < 0) {
			fail(label + " has invalid coordinates", "manifest-source-span");
		}
		return offset;
	}

	static function decodeJournalLocations(reader:OwnershipReader, transactionId:String):OwnershipJournalLocations {
		reader.exact([
			"manifestPath",
			"transactionRoot",
			"lockPath",
			"journalPath",
			"workRoot",
			"stageRoot",
			"backupRoot"
		]);
		final manifestPath = relative(reader.string("manifestPath"), "journal.locations.manifestPath");
		final transactionRoot = relative(reader.string("transactionRoot"), "journal.locations.transactionRoot");
		final lockPath = relative(reader.string("lockPath"), "journal.locations.lockPath");
		final journalPath = relative(reader.string("journalPath"), "journal.locations.journalPath");
		final workRoot = relative(reader.string("workRoot"), "journal.locations.workRoot");
		final stageRoot = relative(reader.string("stageRoot"), "journal.locations.stageRoot");
		final backupRoot = relative(reader.string("backupRoot"), "journal.locations.backupRoot");
		final expectedWorkRoot = transactionRoot + "/" + transactionId;
		if (lockPath != transactionRoot + "/lock"
			|| journalPath != transactionRoot + "/journal.json"
			|| workRoot != expectedWorkRoot
			|| stageRoot != expectedWorkRoot + "/stage"
			|| backupRoot != expectedWorkRoot + "/backup") {
			fail("journal reserved locations do not match transactionId", "journal-locations");
		}
		return new OwnershipJournalLocations(reader.value, manifestPath, transactionRoot, lockPath, journalPath, workRoot, stageRoot, backupRoot);
	}

	static function decodeManifestState(reader:OwnershipReader, label:String, requirePresent:Bool, workRoot:String):OwnershipManifestState {
		reader.exact(["content", "storagePath"]);
		final content = decodeContentState(reader.object("content"), label + ".content", requirePresent);
		final storagePath = relative(reader.string("storagePath"), label + ".storagePath");
		if (!atOrBelow(storagePath, workRoot)) {
			fail(label + " storagePath escapes workRoot", "journal-locations", storagePath);
		}
		return new OwnershipManifestState(reader.value, content, storagePath);
	}

	static function decodeContentState(reader:OwnershipReader, label:String, requirePresent:Bool):OwnershipContentState {
		final state = reader.string("state");
		if (state == "absent") {
			if (requirePresent) {
				fail(label + " must be present", "journal-content");
			}
			reader.exact(["state"]);
			return AbsentContent;
		}
		if (state != "file") {
			fail(label + " has an unknown content state", "journal-content");
		}
		reader.exact(["state", "sha256", "sizeBytes"]);
		final digest = sha256(reader.string("sha256"), label + ".sha256");
		final size = reader.integer("sizeBytes");
		if (size < 0) {
			fail(label + ".sizeBytes must be non-negative", "journal-content");
		}
		return FileContent(digest, size);
	}

	static function decodeOperations(values:Array<JsonValue>, mode:OwnershipMode, locations:OwnershipJournalLocations):Array<OwnershipOperation> {
		final operations:Array<OwnershipOperation> = [];
		var previousPath:Null<String> = null;
		final operationIds = new Map<String, Bool>();
		final pathKeys = new Map<String, Bool>();
		for (index in 0...values.length) {
			final label = "journal.operations[" + index + "]";
			final reader = OwnershipReader.from(values[index], label);
			reader.exact([
				"operationId",
				"action",
				"path",
				"rootId",
				"oldContent",
				"newContent",
				"backupPath",
				"stagedPath"
			]);
			final operationId = stableId(reader.string("operationId"), "journal operation ID");
			if (operationIds.exists(operationId)) {
				fail("journal operation IDs are not unique", "journal-operations");
			}
			operationIds.set(operationId, true);
			final action = decodeAction(reader.string("action"), label + ".action");
			final path = relative(reader.string("path"), "journal operation path");
			final rootId = stableId(reader.string("rootId"), "journal operation rootId");
			if (previousPath != null && compareText(previousPath, path) >= 0) {
				fail("journal operation paths are not sorted", "journal-operations");
			}
			previousPath = path;
			if (pathKeys.exists(collisionKey(path))) {
				fail("journal operation paths collide", "journal-operations");
			}
			pathKeys.set(collisionKey(path), true);
			final oldContent = decodeContentState(reader.object("oldContent"), "journal operation oldContent", false);
			final newContent = decodeContentState(reader.object("newContent"), "journal operation newContent", false);
			if (!validTransition(action, oldContent, newContent)) {
				fail("journal action does not match old/new content states", "journal-operations");
			}
			if (action == Replace && contentDigest(oldContent) == contentDigest(newContent)) {
				fail("journal replace operation does not change bytes", "journal-operations");
			}
			if (action == Relinquish && !contentEquals(oldContent, newContent)) {
				fail("journal relinquish operation changes live bytes", "journal-operations");
			}
			final backupPath = reader.string("backupPath");
			final stagedPath = reader.string("stagedPath");
			if (backupPath != locations.backupRoot + "/" + path || stagedPath != locations.stageRoot + "/" + path) {
				fail("journal staged or backup path is not content-path-derived", "journal-operations");
			}
			if ((mode == Build && action == Relinquish)
				|| (mode == Clean && action != Remove)
				|| (mode == AdoptGenerated && action != Relinquish)) {
				fail("journal operation is outside its transaction mode", "journal-mode");
			}
			operations.push(new OwnershipOperation(reader.value, operationId, action, path, rootId, oldContent, newContent, backupPath, stagedPath));
		}
		return operations;
	}

	static function validTransition(action:OwnershipAction, oldContent:OwnershipContentState, newContent:OwnershipContentState):Bool {
		return switch action {
			case Create: isAbsent(oldContent) && isFile(newContent);
			case Replace: isFile(oldContent) && isFile(newContent);
			case Remove: isFile(oldContent) && isAbsent(newContent);
			case Relinquish: isFile(oldContent) && isFile(newContent);
		};
	}

	static function contentDigest(state:OwnershipContentState):String {
		return switch state {
			case FileContent(sha256, _): sha256;
			case AbsentContent: "";
		};
	}

	static function descriptorForFile(item:OwnershipFile):OwnershipContentState {
		return FileContent(item.contentSha256, item.sizeBytes);
	}

	static function operationJson(operationId:String, action:OwnershipAction, path:String, rootId:String, oldContent:OwnershipContentState,
			newContent:OwnershipContentState, backupPath:String, stagedPath:String):JsonValue {
		return OwnershipJson.object([
			"operationId" => OwnershipJson.text(operationId),
			"action" => OwnershipJson.text(action),
			"path" => OwnershipJson.text(path),
			"rootId" => OwnershipJson.text(rootId),
			"oldContent" => contentJson(oldContent),
			"newContent" => contentJson(newContent),
			"backupPath" => OwnershipJson.text(backupPath),
			"stagedPath" => OwnershipJson.text(stagedPath)
		]);
	}

	static function manifestState(content:OwnershipContentState, storagePath:String):OwnershipManifestState {
		final value = OwnershipJson.object([
			"content" => contentJson(content),
			"storagePath" => OwnershipJson.text(storagePath)
		]);
		return new OwnershipManifestState(value, content, storagePath);
	}

	static function validateSortedStrings(values:Array<JsonValue>, label:String, requireNonEmpty:Bool, validator:(String, String) -> String):Array<String> {
		if (requireNonEmpty && values.length == 0) {
			fail(label + " must not be empty", "contract-shape");
		}
		final result:Array<String> = [];
		var previous:Null<String> = null;
		for (index in 0...values.length) {
			final value = switch values[index] {
				case StringValue(text) if (text.length > 0): text;
				case _: fail(label + "[" + index + "] must be a non-empty string", "contract-shape");
			}
			validator(value, label + "[" + index + "]");
			if (previous != null && compareText(previous, value) >= 0) {
				fail(label + " is not a sorted unique set", "contract-shape");
			}
			previous = value;
			result.push(value);
		}
		return result;
	}

	static function digestWithout(value:JsonValue, field:String):String {
		return OwnershipJson.digestValue(removeField(value, field));
	}

	static function withDigest(value:JsonValue, field:String):JsonValue {
		final material = removeField(value, field, false);
		return addField(material, field, OwnershipJson.text(OwnershipJson.digestValue(material)));
	}

	static function replaceField(value:JsonValue, name:String, replacement:JsonValue):JsonValue {
		return switch value {
			case ObjectValue(fields):
				var found = false;
				final updated:Array<JsonField> = [
					for (field in fields)
						if (field.name == name) {
							found = true;
							{name: name, value: replacement};
						} else field
				];
				if (!found) {
					fail("missing field " + name + " while deriving ownership data", "contract-shape");
				}
				ObjectValue(updated);
			case _: fail("ownership document root must be an object", "contract-shape");
		};
	}

	static function removeField(value:JsonValue, name:String, requirePresent:Bool = true):JsonValue {
		return switch value {
			case ObjectValue(fields):
				final filtered = [for (field in fields) if (field.name != name) field];
				if (requirePresent && filtered.length != fields.length - 1) {
					fail("expected exactly one field named " + name, "contract-shape");
				}
				ObjectValue(filtered);
			case _: fail("ownership document root must be an object", "contract-shape");
		};
	}

	static function addField(value:JsonValue, name:String, child:JsonValue):JsonValue {
		return switch value {
			case ObjectValue(fields): ObjectValue(fields.concat([{name: name, value: child}]));
			case _: fail("ownership document root must be an object", "contract-shape");
		};
	}

	static function sha256(value:String, label:String):String {
		if (!SHA256.match(value)) {
			fail(label + " is not a lowercase SHA-256", "contract-shape");
		}
		return value;
	}

	static function stableId(value:String, label:String):String {
		if (!STABLE_ID.match(value)) {
			fail(label + " is not a stable ID", "contract-shape");
		}
		return value;
	}

	static function collisionKey(value:String):String {
		return value.toLowerCase();
	}

	static function expect(actual:String, expected:String, label:String):Void {
		if (actual != expected) {
			fail(label + " must equal " + expected, "contract-version");
		}
	}

	static function expectOne(actual:String, allowed:Array<String>, label:String):String {
		if (allowed.indexOf(actual) < 0) {
			fail(label + " is outside the closed enum", "contract-shape");
		}
		return actual;
	}

	static function decodeMode(value:String, label:String):OwnershipMode {
		return switch value {
			case "build": Build;
			case "clean": Clean;
			case "adopt-generated": AdoptGenerated;
			case _: fail(label + " is outside the closed enum", "contract-shape");
		};
	}

	static function decodePhase(value:String, label:String):OwnershipPhase {
		return switch value {
			case "prepared": Prepared;
			case "publishing": Publishing;
			case "manifest-published": ManifestPublished;
			case _: fail(label + " is outside the closed enum", "contract-shape");
		};
	}

	static function decodeAction(value:String, label:String):OwnershipAction {
		return switch value {
			case "create": Create;
			case "replace": Replace;
			case "remove": Remove;
			case "relinquish": Relinquish;
			case _: fail(label + " is outside the closed enum", "contract-shape");
		};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

enum abstract OwnershipMode(String) to String {
	var Build = "build";
	var Clean = "clean";
	var AdoptGenerated = "adopt-generated";
}

enum abstract OwnershipPhase(String) to String {
	var Prepared = "prepared";
	var Publishing = "publishing";
	var ManifestPublished = "manifest-published";
}

enum abstract OwnershipAction(String) to String {
	var Create = "create";
	var Replace = "replace";
	var Remove = "remove";
	var Relinquish = "relinquish";
}

enum OwnershipContentState {
	AbsentContent;
	FileContent(sha256:String, sizeBytes:Int);
}

class OwnershipManifest {
	public final json:JsonValue;
	public final manifestDigest:String;
	public final locations:OwnershipManifestLocations;
	public final inputs:OwnershipInputs;
	public final outputRoots:Array<OwnershipOutputRoot>;
	public final validators:Array<OwnershipValidator>;
	public final files:Array<OwnershipFile>;

	public function new(json:JsonValue, manifestDigest:String, locations:OwnershipManifestLocations, inputs:OwnershipInputs,
			outputRoots:Array<OwnershipOutputRoot>, validators:Array<OwnershipValidator>, files:Array<OwnershipFile>) {
		this.json = json;
		this.manifestDigest = manifestDigest;
		this.locations = locations;
		this.inputs = inputs;
		this.outputRoots = outputRoots;
		this.validators = validators;
		this.files = files;
	}
}

class OwnershipInputs {
	public final json:JsonValue;
	public final generationSha256:String;

	public function new(json:JsonValue, generationSha256:String) {
		this.json = json;
		this.generationSha256 = generationSha256;
	}
}

class OwnershipManifestLocations {
	public final json:JsonValue;
	public final manifestPath:String;
	public final transactionRoot:String;
	public final lockPath:String;
	public final journalPath:String;

	public function new(json:JsonValue, manifestPath:String, transactionRoot:String, lockPath:String, journalPath:String) {
		this.json = json;
		this.manifestPath = manifestPath;
		this.transactionRoot = transactionRoot;
		this.lockPath = lockPath;
		this.journalPath = journalPath;
	}
}

class OwnershipOutputRoot {
	public final json:JsonValue;
	public final rootId:String;
	public final path:String;

	public function new(json:JsonValue, rootId:String, path:String) {
		this.json = json;
		this.rootId = rootId;
		this.path = path;
	}
}

class OwnershipValidator {
	public final json:JsonValue;
	public final validatorId:String;

	public function new(json:JsonValue, validatorId:String) {
		this.json = json;
		this.validatorId = validatorId;
	}
}

class OwnershipFile {
	public final json:JsonValue;
	public final path:String;
	public final rootId:String;
	public final contentSha256:String;
	public final sizeBytes:Int;

	public function new(json:JsonValue, path:String, rootId:String, contentSha256:String, sizeBytes:Int) {
		this.json = json;
		this.path = path;
		this.rootId = rootId;
		this.contentSha256 = contentSha256;
		this.sizeBytes = sizeBytes;
	}
}

class OwnershipJournal {
	public final json:JsonValue;
	public final journalDigest:String;
	public final transactionId:String;
	public final mode:OwnershipMode;
	public final phase:OwnershipPhase;
	public final locations:OwnershipJournalLocations;
	public final priorManifest:OwnershipManifestState;
	public final nextManifest:OwnershipManifestState;
	public final operations:Array<OwnershipOperation>;

	public function new(json:JsonValue, journalDigest:String, transactionId:String, mode:OwnershipMode, phase:OwnershipPhase,
			locations:OwnershipJournalLocations, priorManifest:OwnershipManifestState, nextManifest:OwnershipManifestState,
			operations:Array<OwnershipOperation>) {
		this.json = json;
		this.journalDigest = journalDigest;
		this.transactionId = transactionId;
		this.mode = mode;
		this.phase = phase;
		this.locations = locations;
		this.priorManifest = priorManifest;
		this.nextManifest = nextManifest;
		this.operations = operations;
	}
}

class OwnershipJournalLocations {
	public final json:JsonValue;
	public final manifestPath:String;
	public final transactionRoot:String;
	public final lockPath:String;
	public final journalPath:String;
	public final workRoot:String;
	public final stageRoot:String;
	public final backupRoot:String;

	public function new(json:JsonValue, manifestPath:String, transactionRoot:String, lockPath:String, journalPath:String, workRoot:String, stageRoot:String,
			backupRoot:String) {
		this.json = json;
		this.manifestPath = manifestPath;
		this.transactionRoot = transactionRoot;
		this.lockPath = lockPath;
		this.journalPath = journalPath;
		this.workRoot = workRoot;
		this.stageRoot = stageRoot;
		this.backupRoot = backupRoot;
	}
}

class OwnershipManifestState {
	public final json:JsonValue;
	public final content:OwnershipContentState;
	public final storagePath:String;

	public function new(json:JsonValue, content:OwnershipContentState, storagePath:String) {
		this.json = json;
		this.content = content;
		this.storagePath = storagePath;
	}
}

class OwnershipOperation {
	public final json:JsonValue;
	public final operationId:String;
	public final action:OwnershipAction;
	public final path:String;
	public final rootId:String;
	public final oldContent:OwnershipContentState;
	public final newContent:OwnershipContentState;
	public final backupPath:String;
	public final stagedPath:String;

	public function new(json:JsonValue, operationId:String, action:OwnershipAction, path:String, rootId:String, oldContent:OwnershipContentState,
			newContent:OwnershipContentState, backupPath:String, stagedPath:String) {
		this.json = json;
		this.operationId = operationId;
		this.action = action;
		this.path = path;
		this.rootId = rootId;
		this.oldContent = oldContent;
		this.newContent = newContent;
		this.backupPath = backupPath;
		this.stagedPath = stagedPath;
	}
}

class OwnershipLock {
	public final transactionId:String;
	public final pid:Int;
	public final projectDevice:Float;
	public final projectInode:Float;

	public function new(transactionId:String, pid:Int, projectDevice:Float, projectInode:Float) {
		this.transactionId = transactionId;
		this.pid = pid;
		this.projectDevice = projectDevice;
		this.projectInode = projectInode;
	}
}

private class OwnershipReader {
	public final value:JsonValue;

	final fields:Array<JsonField>;
	final label:String;

	public static function from(value:JsonValue, label:String):OwnershipReader {
		return switch value {
			case ObjectValue(fields): new OwnershipReader(value, fields, label);
			case _: OwnershipContract.fail(label + " must be an object", "contract-shape");
		};
	}

	function new(value:JsonValue, fields:Array<JsonField>, label:String) {
		this.value = value;
		this.fields = fields;
		this.label = label;
	}

	public function exact(expected:Array<String>):Void {
		final actual = [for (field in fields) field.name];
		actual.sort(compareText);
		final wanted = expected.copy();
		wanted.sort(compareText);
		if (actual.join("\x00") != wanted.join("\x00")) {
			OwnershipContract.fail(label + " fields differ; expected " + wanted.join(", ") + ", found " + actual.join(", "), "contract-shape");
		}
	}

	public function string(name:String):String {
		return switch requiredValue(name) {
			case StringValue(value) if (value.length > 0): value;
			case _: OwnershipContract.fail(label + "." + name + " must be a non-empty string", "contract-shape");
		};
	}

	public function integer(name:String):Int {
		return switch requiredValue(name) {
			case NumberValue(source):
				final value = Std.parseInt(source);
				if (value == null || Std.string(value) != source || !OwnershipJson.isSafeInteger(value)) {
					OwnershipContract.fail(label + "." + name + " must be a safe integer", "contract-shape");
				}
				value;
			case _: OwnershipContract.fail(label + "." + name + " must be a safe integer", "contract-shape");
		};
	}

	public function safeNumber(name:String):Float {
		return switch requiredValue(name) {
			case NumberValue(source):
				final value = Std.parseFloat(source);
				if (!OwnershipJson.isSafeInteger(value)) {
					OwnershipContract.fail(label + "." + name + " must be a safe integer", "contract-shape");
				}
				value;
			case _: OwnershipContract.fail(label + "." + name + " must be a safe integer", "contract-shape");
		};
	}

	public function array(name:String):Array<JsonValue> {
		return switch requiredValue(name) {
			case ArrayValue(values): values;
			case _: OwnershipContract.fail(label + "." + name + " must be an array", "contract-shape");
		};
	}

	public function object(name:String):OwnershipReader {
		return from(requiredValue(name), label + "." + name);
	}

	function requiredValue(name:String):JsonValue {
		for (field in fields) {
			if (field.name == name) {
				return field.value;
			}
		}
		return OwnershipContract.fail(label + " is missing field " + name, "contract-shape");
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
