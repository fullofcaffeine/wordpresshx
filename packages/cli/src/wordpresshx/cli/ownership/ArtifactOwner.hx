package wordpresshx.cli.ownership;

import js.Syntax;
import js.node.Buffer;
import js.node.Crypto;
import js.node.Fs;
import js.node.Path;
import js.node.fs.Stats;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipAction;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipContentState;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipFile;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipJournal;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipManifest;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipMode;
import wordpresshx.cli.ownership.OwnershipContract.OwnershipPhase;

/**
	Exact path+hash ownership and journaled manifest-last publication.

	This class is the only layer allowed to mutate generated destinations. Emitters
	provide a canonical next manifest and a complete validated stage; they never
	receive live-tree write authority.
**/
class ArtifactOwner {
	public static inline final EXACT_NODE_VERSION = "22.17.0";
	static inline final PRIVATE_FILE_MODE = 0x180; // 0600
	static inline final GENERATED_FILE_MODE = 0x1a4; // 0644

	final projectRoot:String;
	final rootDevice:Int;
	final rootInode:Float;
	final manifestPath:String;
	final transactionRoot:String;
	final lockPath:String;
	final journalPath:String;
	final journalTemporaryPath:String;

	#if wordpresshx_ownership_fault_injection
	final fault:Null<(checkpoint:String) -> Void>;
	#end

	public function new(projectRoot:String, ?layout:OwnershipLayout #if wordpresshx_ownership_fault_injection, ?fault:(checkpoint:String) -> Void #end) {
		final nodeProcess = NodeGlobals.process();
		final nodeVersion:String = Syntax.code("{0}.versions.node", nodeProcess);
		if (nodeVersion != EXACT_NODE_VERSION) {
			fail("ownership runtime requires exact Node " + EXACT_NODE_VERSION + ", found " + nodeVersion, "unsupported-runtime");
		}
		if (nodeProcess.platform != "linux" && nodeProcess.platform != "darwin") {
			fail("ownership runtime supports only its admitted POSIX filesystem profile", "unsupported-platform");
		}
		final resolved = Path.resolve(projectRoot);
		final rootStats = lstatAbsolute(resolved, "project root");
		if (rootStats == null || rootStats.isSymbolicLink() || !rootStats.isDirectory()) {
			fail("project root must be a real directory", "unsafe-project-root");
		}
		this.projectRoot = Fs.realpathSync(resolved);
		final canonicalStats = Fs.lstatSync(this.projectRoot);
		if (!canonicalStats.isDirectory() || canonicalStats.isSymbolicLink()) {
			fail("canonical project root must be a real directory", "unsafe-project-root");
		}
		this.rootDevice = canonicalStats.dev;
		this.rootInode = canonicalStats.ino;
		final effective:OwnershipLayout = layout == null ? {
			manifestPath: "build/_GeneratedFiles.json",
			transactionRoot: "build/.wphx-transactions"
		} : layout;
		this.manifestPath = OwnershipContract.relative(effective.manifestPath, "ownership manifest path");
		this.transactionRoot = OwnershipContract.relative(effective.transactionRoot, "ownership transaction root");
		if (OwnershipContract.atOrBelow(this.manifestPath, this.transactionRoot)
			|| OwnershipContract.atOrBelow(this.transactionRoot, this.manifestPath)) {
			fail("ownership manifest and transaction root must be disjoint", "invalid-layout");
		}
		this.lockPath = this.transactionRoot + "/lock";
		this.journalPath = this.transactionRoot + "/journal.json";
		this.journalTemporaryPath = this.transactionRoot + "/.journal.json.tmp";
		#if wordpresshx_ownership_fault_injection
		this.fault = fault;
		#end
		fsyncDirectory(this.projectRoot);
	}

	/** Publish a complete staged generation after running every manifest validator. **/
	public function publish(nextManifestFile:String, callerStageRoot:String, validators:Array<StageValidator>):OwnershipResult {
		preflightRecovery();
		final next = readExternalManifest(nextManifestFile, "next ownership manifest");
		ensureLayout(next);
		final staged = validateCallerStage(callerStageRoot, next, validators);
		return transact(next, staged, Build, []);
	}

	/** Remove only exact currently owned files and publish an empty ownership set. **/
	public function clean():OwnershipResult {
		preflightRecovery();
		final current = readCurrentManifest();
		if (current == null) {
			return NoOp;
		}
		final next = OwnershipContract.deriveManifest(current, []);
		return transact(next, new Map<String, Buffer>(), Clean, []);
	}

	/** Relinquish exact current entries without rewriting or deleting their bytes. **/
	public function adoptGenerated(paths:Array<String>):OwnershipResult {
		preflightRecovery();
		final current = readCurrentManifest();
		if (current == null) {
			fail("adopt-generated requires a current ownership manifest", "missing-manifest");
		}
		if (paths.length == 0) {
			fail("adopt-generated requires at least one exact path", "invalid-adoption");
		}
		final currentFiles = OwnershipContract.fileMap(current);
		final relinquished = new Map<String, Bool>();
		for (rawPath in paths) {
			final path = OwnershipContract.relative(rawPath, "adopt-generated path");
			if (relinquished.exists(path) || !currentFiles.exists(path)) {
				fail("adopt-generated path is not one unique current ownership entry: " + path, "invalid-adoption", path);
			}
			relinquished.set(path, true);
		}
		final retained = [for (path => _ in currentFiles) if (!relinquished.exists(path)) path];
		retained.sort(compareText);
		final sortedRelinquished = [for (path => _ in relinquished) path];
		sortedRelinquished.sort(compareText);
		final next = OwnershipContract.deriveManifest(current, retained);
		return transact(next, new Map<String, Buffer>(), AdoptGenerated, sortedRelinquished);
	}

	/** Resolve a durable journal by exact hashes, or refuse to guess. **/
	public function recover():OwnershipResult {
		revalidateProjectRoot();
		final journalExists = lexists(relativeAbsolute(journalPath));
		final lockExists = lexists(relativeAbsolute(lockPath));
		if (!journalExists) {
			if (lockExists || lexists(relativeAbsolute(journalTemporaryPath))) {
				fail("ownership lock exists without a durable journal; explicit diagnosis is required", "orphan-lock");
			}
			return NothingToRecover;
		}
		if (!lockExists) {
			fail("ownership journal exists without its lock", "journal-without-lock");
		}
		final journal = readJournal();
		validateLock(journal);
		final bound = validateBoundJournal(journal);
		if (liveNextIsComplete(journal, bound.next)) {
			cleanupTransaction(journal);
			return Finalized;
		}
		rollback(journal, bound.prior);
		return RolledBack;
	}

	public function inspectCurrentManifest():Null<JsonValue> {
		preflightRecovery();
		final current = readCurrentManifest();
		return current == null ? null : OwnershipJson.clone(current.json);
	}

	function transact(next:OwnershipManifest, staged:Map<String, Buffer>, mode:OwnershipMode, relinquished:Array<String>):OwnershipResult {
		ensureLayout(next);
		final liveCurrent = readCurrentManifest();
		if (liveCurrent != null) {
			if (OwnershipJson.encode(liveCurrent.locations.json) != OwnershipJson.encode(next.locations.json)) {
				fail("v1 cannot migrate ownership metadata locations implicitly", "layout-migration");
			}
			if (OwnershipJson.encode(ArrayValue([for (root in liveCurrent.outputRoots) root.json])) != OwnershipJson.encode(ArrayValue([for (root in next.outputRoots) root.json]))
				&& !isAdditiveRootMigration(liveCurrent, next)) {
				fail("v1 only permits an additive exact output-root migration", "root-migration");
			}
		}
		final current = liveCurrent == null ? OwnershipContract.deriveManifest(next, []) : liveCurrent;
		checkRootSafety(next);
		verifyOwnedTree(current);
		validateMode(mode, liveCurrent, current, next, staged, relinquished);
		validateDestinations(mode, current, next, staged);

		if (liveCurrent != null && liveCurrent.manifestDigest == next.manifestDigest && relinquished.length == 0) {
			return NoOp;
		}

		final transactionId = Crypto.randomBytes(32).toString("hex");
		var workRoot:Null<String> = null;
		try {
			acquireLock(transactionId);
			verifyOwnedTree(current);
			revalidateProjectRoot();
			final journal = OwnershipContract.makeJournal(liveCurrent, next, transactionId, mode, relinquished);
			OwnershipContract.validateJournalPlan(journal, liveCurrent, next);
			workRoot = journal.locations.workRoot;
			if (lexists(relativeAbsolute(workRoot))) {
				fail("fresh transaction work root already exists", "transaction-collision");
			}
			ensureDirectory(workRoot);
			if (liveCurrent != null) {
				atomicWrite(journal.priorManifest.storagePath, OwnershipJson.encodeDocument(liveCurrent.json), GENERATED_FILE_MODE);
			}
			atomicWrite(journal.nextManifest.storagePath, OwnershipJson.encodeDocument(next.json), GENERATED_FILE_MODE);
			if (mode == Build) {
				final stageRoot = journal.locations.stageRoot;
				for (path => buffer in staged) {
					atomicWrite(stageRoot + "/" + path, buffer, GENERATED_FILE_MODE);
				}
				verifyPrivateStage(stageRoot, next);
			}
			atomicWrite(journalPath, OwnershipJson.encodeDocument(journal.json));
			checkpoint("after-journal-prepared");
			return commit(journal);
		} catch (failure:OwnershipFailure) {
			if (lexists(relativeAbsolute(journalPath))) {
				try {
					final outcome = recover();
					if (outcome == Finalized) {
						return PublishedRecovered;
					}
				} catch (_:haxe.Exception) {
					throw new OwnershipFailure("publication failed and exact automatic recovery requires diagnosis", "recovery-required");
				}
			} else {
				cleanupPreJournal(workRoot);
			}
			throw failure;
		} catch (_:js.lib.Error) {
			if (lexists(relativeAbsolute(journalPath))) {
				try {
					if (recover() == Finalized) {
						return PublishedRecovered;
					}
				} catch (_:haxe.Exception) {
					throw new OwnershipFailure("publication failed and exact automatic recovery requires diagnosis", "recovery-required");
				}
			} else {
				cleanupPreJournal(workRoot);
			}
			throw new OwnershipFailure("ownership publication failed before commit", "publication-failed");
		}
	}

	function isAdditiveRootMigration(current:OwnershipManifest, next:OwnershipManifest):Bool {
		final currentRoots = current.outputRoots;
		final nextRoots = next.outputRoots;
		if (nextRoots.length <= currentRoots.length) {
			return false;
		}
		final nextById = new Map<String, wordpresshx.cli.ownership.OwnershipContract.OwnershipOutputRoot>();
		for (root in nextRoots) {
			nextById.set(root.rootId, root);
		}
		for (root in currentRoots) {
			final id = root.rootId;
			final candidate = nextById.get(id);
			if (candidate == null || OwnershipJson.encode(root.json) != OwnershipJson.encode(candidate.json)) {
				return false;
			}
		}
		return true;
	}

	function validateMode(mode:OwnershipMode, liveCurrent:Null<OwnershipManifest>, current:OwnershipManifest, next:OwnershipManifest,
			staged:Map<String, Buffer>, relinquished:Array<String>):Void {
		final currentFiles = OwnershipContract.fileMap(current);
		final nextFiles = OwnershipContract.fileMap(next);
		if (mode == Build) {
			if (relinquished.length != 0) {
				fail("build cannot relinquish ownership", "invalid-mode");
			}
		} else if (mode == Clean) {
			if (nextFiles.keys().hasNext() || staged.keys().hasNext() || relinquished.length != 0) {
				fail("clean requires an empty next ownership set", "invalid-mode");
			}
		} else if (mode == AdoptGenerated) {
			if (liveCurrent == null || relinquished.length == 0 || staged.keys().hasNext()) {
				fail("adopt-generated requires exact current entries and no staged bytes", "invalid-mode");
			}
			final relinquishSet = new Map<String, Bool>();
			for (path in relinquished) {
				relinquishSet.set(path, true);
			}
			for (path => item in currentFiles) {
				final fresh = nextFiles.get(path);
				if (relinquishSet.exists(path)) {
					if (fresh != null) {
						fail("adopt-generated retained a relinquished entry", "invalid-adoption", path);
					}
				} else if (fresh == null || OwnershipJson.encode(item.json) != OwnershipJson.encode(fresh.json)) {
					fail("adopt-generated changed a retained entry", "invalid-adoption", path);
				}
			}
		} else {
			fail("unknown ownership transaction mode", "invalid-mode");
		}
	}

	function validateDestinations(mode:OwnershipMode, current:OwnershipManifest, next:OwnershipManifest, staged:Map<String, Buffer>):Void {
		final currentFiles = OwnershipContract.fileMap(current);
		final nextFiles = OwnershipContract.fileMap(next);
		for (path => item in nextFiles) {
			assertSafeComponents(path, "next destination");
			if (!currentFiles.exists(path) && lexists(relativeAbsolute(path))) {
				fail("unowned destination already exists: " + path, "unowned-collision", path);
			}
			if (mode == Build) {
				final buffer = staged.get(path);
				if (buffer == null || !stateEquals(OwnershipContract.contentState(buffer), descriptorForManifestFile(item))) {
					fail("staged bytes do not match next manifest: " + path, "staged-mismatch", path);
				}
			}
		}
		if (mode == Build) {
			var count = 0;
			for (path => _ in staged) {
				count++;
				if (!nextFiles.exists(path)) {
					fail("staging tree contains an undeclared file: " + path, "undeclared-stage-file", path);
				}
			}
			var expectedCount = 0;
			for (_ => _ in nextFiles) {
				expectedCount++;
			}
			if (count != expectedCount) {
				fail("staging tree is not the complete next ownership set", "incomplete-stage");
			}
		} else if (staged.keys().hasNext()) {
			fail(mode + " cannot stage generated artifact bytes", "invalid-mode");
		}
	}

	function commit(initialJournal:OwnershipJournal):OwnershipResult {
		var journal = updatePhase(initialJournal, Publishing);
		checkpoint("after-publishing-phase");
		final operations = journal.operations;
		var published = 0;
		for (operation in operations) {
			final action = operation.action;
			if (action == Relinquish) {
				continue;
			}
			revalidateProjectRoot();
			final path = operation.path;
			assertSafeComponents(path, "live destination");
			final oldContent = operation.oldContent;
			final newContent = operation.newContent;
			if (OwnershipContract.isFile(oldContent)) {
				requireState(path, oldContent, "live bytes changed after transaction preflight");
				final backupPath = operation.backupPath;
				if (lexists(relativeAbsolute(backupPath))) {
					fail("transaction backup path already exists", "transaction-collision", path);
				}
				ensureParent(backupPath);
				renameRelative(path, backupPath);
			} else if (lexists(relativeAbsolute(path))) {
				fail("unowned destination appeared during publication", "concurrent-collision", path);
			}
			if (OwnershipContract.isFile(newContent)) {
				final stagedPath = operation.stagedPath;
				requireState(stagedPath, newContent, "private staged bytes changed during publication");
				ensureParent(path);
				renameRelative(stagedPath, path);
			}
			published++;
			checkpoint("after-operation-" + published);
		}
		final nextStorage = journal.nextManifest.storagePath;
		requireState(nextStorage, journal.nextManifest.content, "staged next manifest changed before publication");
		requireState(manifestPath, journal.priorManifest.content, "ownership manifest changed during publication");
		ensureParent(manifestPath);
		renameRelative(nextStorage, manifestPath);
		checkpoint("after-manifest-rename");
		journal = updatePhase(journal, ManifestPublished);
		checkpoint("after-manifest-phase");
		cleanupTransaction(journal);
		return Published;
	}

	function rollback(journal:OwnershipJournal, prior:Null<OwnershipManifest>):Void {
		final operations = journal.operations;
		var index = operations.length;
		while (index > 0) {
			index--;
			final operation = operations[index];
			if (operation.action == Relinquish) {
				continue;
			}
			final path = operation.path;
			final backupPath = operation.backupPath;
			final oldContent = operation.oldContent;
			final newContent = operation.newContent;
			if (lexists(relativeAbsolute(backupPath))) {
				requireState(backupPath, oldContent, "rollback backup bytes are unexpected");
				final live = regularState(path, "rollback live path");
				if (!OwnershipContract.isAbsent(live)) {
					if (!stateEquals(live, newContent)) {
						fail("rollback found unexpected live bytes", "recovery-conflict", path);
					}
					unlinkRelative(path);
				}
				ensureParent(path);
				renameRelative(backupPath, path);
			} else if (OwnershipContract.isAbsent(oldContent)) {
				unlinkMatching(path, newContent);
			} else if (!stateEquals(regularState(path, "rollback live path"), oldContent)) {
				fail("rollback lost both old live bytes and exact backup", "recovery-conflict", path);
			}
		}

		final priorState = journal.priorManifest.content;
		final currentState = regularState(manifestPath, "ownership manifest");
		if (OwnershipContract.isAbsent(priorState)) {
			unlinkMatching(manifestPath, journal.nextManifest.content);
		} else if (!stateEquals(currentState, priorState)) {
			final nextState = journal.nextManifest.content;
			if (!OwnershipContract.isAbsent(currentState) && !stateEquals(currentState, nextState)) {
				fail("rollback found an unexpected ownership manifest", "recovery-conflict", manifestPath);
			}
			final priorStorage = journal.priorManifest.storagePath;
			requireState(priorStorage, priorState, "rollback prior manifest backup is missing");
			ensureParent(manifestPath);
			renameRelative(priorStorage, manifestPath);
		}
		if (prior != null) {
			verifyOwnedTree(prior);
		}
		cleanupTransaction(journal);
	}

	function liveNextIsComplete(journal:OwnershipJournal, next:OwnershipManifest):Bool {
		if (!stateEquals(regularState(manifestPath, "ownership manifest"), journal.nextManifest.content)) {
			return false;
		}
		try {
			verifyOwnedTree(next);
			for (operation in journal.operations) {
				final action = operation.action;
				if (action == Remove && !OwnershipContract.isAbsent(regularState(operation.path, "removed path"))) {
					return false;
				}
				if (action == Relinquish && !stateEquals(regularState(operation.path, "relinquished path"), operation.newContent)) {
					return false;
				}
			}
		} catch (_:OwnershipFailure) {
			return false;
		}
		return true;
	}

	function validateBoundJournal(journal:OwnershipJournal):{prior:Null<OwnershipManifest>, next:OwnershipManifest} {
		final prior = journalManifest(journal, journal.priorManifest, false, "priorManifest");
		final next = journalManifest(journal, journal.nextManifest, true, "nextManifest");
		if (next == null) {
			fail("journal next manifest must be present", "invalid-journal");
		}
		OwnershipContract.validateJournalPlan(journal, prior, next);
		return {prior: prior, next: next};
	}

	function journalManifest(journal:OwnershipJournal, state:wordpresshx.cli.ownership.OwnershipContract.OwnershipManifestState, requirePresent:Bool,
			field:String):Null<OwnershipManifest> {
		final expected = state.content;
		final storagePath = state.storagePath;
		final stored = regularState(storagePath, "journal " + field + " storage");
		if (OwnershipContract.isAbsent(expected)) {
			if (!OwnershipContract.isAbsent(stored)) {
				fail("absent journal manifest unexpectedly has stored bytes", "invalid-journal", storagePath);
			}
			if (requirePresent) {
				fail("journal next manifest is absent", "invalid-journal");
			}
			return null;
		}
		var sourcePath:Null<String> = null;
		if (stateEquals(stored, expected)) {
			sourcePath = storagePath;
		} else if (OwnershipContract.isAbsent(stored) && stateEquals(regularState(manifestPath, "live ownership manifest"), expected)) {
			sourcePath = manifestPath;
		} else {
			fail("journal-bound manifest bytes are missing or unexpected", "invalid-journal", storagePath);
		}
		final value = OwnershipContract.validateManifest(readCanonicalRelative(sourcePath, field));
		ensureLayout(value);
		return value;
	}

	function readCurrentManifest():Null<OwnershipManifest> {
		if (!lexists(relativeAbsolute(manifestPath))) {
			return null;
		}
		final value = OwnershipContract.validateManifest(readCanonicalRelative(manifestPath, "ownership manifest"));
		ensureLayout(value);
		return value;
	}

	function readJournal():OwnershipJournal {
		final value = OwnershipContract.validateJournal(readCanonicalRelative(journalPath, "ownership journal"));
		if (value.locations.manifestPath != manifestPath
			|| value.locations.transactionRoot != transactionRoot
			|| value.locations.lockPath != lockPath
			|| value.locations.journalPath != journalPath) {
			fail("journal does not match the configured ownership layout", "invalid-journal");
		}
		return value;
	}

	function readExternalManifest(path:String, label:String):OwnershipManifest {
		final resolved = Path.resolve(path);
		final stats = lstatAbsolute(resolved, label);
		if (stats == null || stats.isSymbolicLink() || !stats.isFile()) {
			fail(label + " must be a real regular file", "invalid-manifest-input");
		}
		return OwnershipContract.validateManifest(OwnershipJson.parseCanonical(readBufferAbsolute(resolved), label));
	}

	function validateCallerStage(root:String, next:OwnershipManifest, validators:Array<StageValidator>):Map<String, Buffer> {
		final resolved = Path.resolve(root);
		var files = scanStage(resolved, next);
		final expectedIds = [for (validator in next.validators) validator.validatorId];
		final actualIds:Array<String> = [];
		final callbacks = new Map<String, StageValidator>();
		for (validator in validators) {
			if (callbacks.exists(validator.validatorId)) {
				fail("duplicate staged validator callback: " + validator.validatorId, "validator-mismatch");
			}
			callbacks.set(validator.validatorId, validator);
			actualIds.push(validator.validatorId);
		}
		actualIds.sort(compareText);
		if (actualIds.join("\x00") != expectedIds.join("\x00")) {
			fail("staged validator callbacks do not exactly match the next manifest", "validator-mismatch");
		}
		for (validatorId in expectedIds) {
			try {
				callbacks.get(validatorId).run(resolved);
			} catch (_:haxe.Exception) {
				fail("staged validator failed: " + validatorId, "validator-failed");
			}
		}
		files = scanStage(resolved, next);
		return files;
	}

	function scanStage(root:String, next:OwnershipManifest):Map<String, Buffer> {
		final rootStats = lstatAbsolute(root, "caller stage root");
		if (rootStats == null || rootStats.isSymbolicLink() || !rootStats.isDirectory()) {
			fail("caller stage root must be a real directory", "unsafe-stage");
		}
		final files = new Map<String, Buffer>();
		final directories:Array<String> = [];
		scanStageDirectory(root, "", files, directories);
		final expected = OwnershipContract.fileMap(next);
		for (directory in directories) {
			var declaredPrefix = false;
			for (path => _ in expected) {
				if (OwnershipContract.atOrBelow(path, directory) && path != directory) {
					declaredPrefix = true;
					break;
				}
			}
			if (!declaredPrefix) {
				fail("staging tree contains an undeclared directory: " + directory, "undeclared-stage-directory", directory);
			}
		}
		for (path => item in expected) {
			final buffer = files.get(path);
			if (buffer == null || !stateEquals(OwnershipContract.contentState(buffer), descriptorForManifestFile(item))) {
				fail("staged file is missing or does not match its manifest: " + path, "staged-mismatch", path);
			}
		}
		for (path => _ in files) {
			if (!expected.exists(path)) {
				fail("staging tree contains an undeclared file: " + path, "undeclared-stage-file", path);
			}
		}
		return files;
	}

	function scanStageDirectory(root:String, relative:String, files:Map<String, Buffer>, directories:Array<String>):Void {
		final absolute = relative.length == 0 ? root : Path.resolve(root, relative);
		final names = Fs.readdirSync(absolute);
		names.sort(compareText);
		for (name in names) {
			final childRelative = relative.length == 0 ? name : relative + "/" + name;
			OwnershipContract.relative(childRelative, "staged path");
			final stats = Fs.lstatSync(Path.resolve(root, childRelative));
			if (stats.isSymbolicLink()) {
				fail("staging tree contains a symbolic link: " + childRelative, "unsafe-stage", childRelative);
			}
			if (stats.isDirectory()) {
				directories.push(childRelative);
				scanStageDirectory(root, childRelative, files, directories);
			} else if (stats.isFile()) {
				files.set(childRelative, readBufferAbsolute(Path.resolve(root, childRelative)));
			} else {
				fail("staging tree contains a special file: " + childRelative, "unsafe-stage", childRelative);
			}
		}
	}

	function verifyPrivateStage(stageRoot:String, next:OwnershipManifest):Void {
		final expected = OwnershipContract.fileMap(next);
		for (path => item in expected) {
			requireState(stageRoot + "/" + path, descriptorForManifestFile(item), "private stage is incomplete or changed");
		}
	}

	function verifyOwnedTree(manifest:OwnershipManifest):Void {
		for (item in manifest.files) {
			final path = item.path;
			if (!stateEquals(regularState(path, "owned file"), descriptorForManifestFile(item))) {
				fail("owned file is missing or modified: " + path, "modified-owned-file", path);
			}
		}
	}

	function checkRootSafety(manifest:OwnershipManifest):Void {
		for (root in manifest.outputRoots) {
			final path = root.path;
			assertSafeComponents(path, "output root");
			var probe = relativeAbsolute(path);
			var stats = lstatAbsolute(probe, "output root");
			if (stats != null) {
				if (stats.isSymbolicLink() || !stats.isDirectory()) {
					fail("output root is not a real directory: " + path, "unsafe-output-root", path);
				}
			} else {
				probe = Path.dirname(probe);
				stats = lstatAbsolute(probe, "output root ancestor");
				while (stats == null) {
					probe = Path.dirname(probe);
					stats = lstatAbsolute(probe, "output root ancestor");
				}
				if (stats.isSymbolicLink() || !stats.isDirectory()) {
					fail("output root has no safe existing ancestor: " + path, "unsafe-output-root", path);
				}
			}
			if (stats.dev != rootDevice) {
				fail("v1 output roots and transaction state must use one filesystem", "cross-device-root", path);
			}
		}
	}

	function ensureLayout(manifest:OwnershipManifest):Void {
		final locations = manifest.locations;
		if (locations.manifestPath != manifestPath
			|| locations.transactionRoot != transactionRoot
			|| locations.lockPath != lockPath
			|| locations.journalPath != journalPath) {
			fail("manifest does not match the configured ownership layout", "invalid-layout");
		}
	}

	function preflightRecovery():Void {
		final outcome = recover();
		if (outcome == Finalized || outcome == RolledBack) {
			revalidateProjectRoot();
		}
	}

	function acquireLock(transactionId:String):Void {
		if (lexists(relativeAbsolute(lockPath))
			|| lexists(relativeAbsolute(journalPath))
			|| lexists(relativeAbsolute(journalTemporaryPath))) {
			fail("ownership transaction state already exists", "ownership-locked");
		}
		ensureParent(lockPath);
		final lock = OwnershipJson.object([
			"schema" => OwnershipJson.text("wordpress-hx.ownership-lock.v1"),
			"transactionId" => OwnershipJson.text(transactionId),
			"pid" => OwnershipJson.number(NodeGlobals.process().pid),
			"projectDevice" => OwnershipJson.number(rootDevice),
			"projectInode" => OwnershipJson.numberFromFloat(rootInode, "project inode")
		]);
		writeExclusive(lockPath, OwnershipJson.encodeDocument(lock));
	}

	function validateLock(journal:OwnershipJournal):Void {
		final lock = OwnershipContract.decodeLock(readCanonicalRelative(lockPath, "ownership lock"));
		if (lock.transactionId != journal.transactionId
			|| lock.pid <= 0
			|| lock.projectDevice != rootDevice
			|| lock.projectInode != rootInode) {
			fail("ownership lock does not bind the journal and project root", "invalid-lock");
		}
	}

	function updatePhase(journal:OwnershipJournal, phase:OwnershipPhase):OwnershipJournal {
		requireState(journalPath, OwnershipContract.contentState(OwnershipJson.encodeDocument(journal.json)), "ownership journal changed during publication");
		final digested = OwnershipContract.withPhase(journal, phase);
		atomicWrite(journalPath, OwnershipJson.encodeDocument(digested.json));
		return digested;
	}

	function cleanupPreJournal(workRoot:Null<String>):Void {
		if (workRoot != null && OwnershipContract.atOrBelow(workRoot, transactionRoot) && lexists(relativeAbsolute(workRoot))) {
			removePrivateTree(workRoot);
		}
		if (lexists(relativeAbsolute(journalTemporaryPath))) {
			final stats = Fs.lstatSync(relativeAbsolute(journalTemporaryPath));
			if (!stats.isFile() || stats.isSymbolicLink()) {
				fail("journal temporary changed type", "recovery-required");
			}
			unlinkRelative(journalTemporaryPath);
		}
		releaseLock();
		pruneEmptyMetadataParents();
	}

	function cleanupTransaction(journal:OwnershipJournal):Void {
		validateLock(journal);
		requireState(journalPath, OwnershipContract.contentState(OwnershipJson.encodeDocument(journal.json)), "ownership journal changed before cleanup");
		final cleanupManifest = journalManifestForCleanup(journal);
		final workRoot = journal.locations.workRoot;
		if (lexists(relativeAbsolute(workRoot))) {
			removePrivateTree(workRoot);
		}
		if (lexists(relativeAbsolute(journalPath))) {
			requireState(journalPath, OwnershipContract.contentState(OwnershipJson.encodeDocument(journal.json)), "ownership journal changed before cleanup");
			unlinkRelative(journalPath);
		}
		releaseLock();
		pruneEmptyGeneratedParents(journal, cleanupManifest);
		pruneEmptyMetadataParents();
	}

	function removePrivateTree(relative:String):Void {
		if (!OwnershipContract.atOrBelow(relative, transactionRoot) || relative == transactionRoot) {
			fail("refused to remove a path outside the private transaction root", "unsafe-cleanup", relative);
		}
		final absolute = relativeAbsolute(relative);
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink()) {
			fail("private transaction path changed to a symbolic link", "recovery-required", relative);
		}
		if (stats.isDirectory()) {
			final children = Fs.readdirSync(absolute);
			children.sort(compareText);
			for (child in children) {
				removePrivateTree(relative + "/" + child);
			}
			Fs.rmdirSync(absolute);
			fsyncDirectory(Path.dirname(absolute));
		} else if (stats.isFile()) {
			Fs.unlinkSync(absolute);
			fsyncDirectory(Path.dirname(absolute));
		} else {
			fail("private transaction tree contains a special file", "recovery-required", relative);
		}
	}

	function releaseLock():Void {
		if (!lexists(relativeAbsolute(lockPath))) {
			return;
		}
		final stats = Fs.lstatSync(relativeAbsolute(lockPath));
		if (stats.isSymbolicLink() || !stats.isFile()) {
			fail("ownership lock changed type", "recovery-required");
		}
		unlinkRelative(lockPath);
	}

	function pruneEmptyMetadataParents():Void {
		final parts = transactionRoot.split("/");
		while (parts.length > 0) {
			tryRemoveDirectory(parts.join("/"));
			parts.pop();
		}
	}

	function pruneEmptyGeneratedParents(journal:OwnershipJournal, next:Null<OwnershipManifest>):Void {
		final roots:Array<String> = [];
		if (next != null) {
			for (root in next.outputRoots) {
				roots.push(root.path);
			}
		}
		for (operation in journal.operations) {
			final path = operation.path;
			for (root in roots) {
				if (!OwnershipContract.atOrBelow(path, root)) {
					continue;
				}
				var current = path.split("/");
				current.pop();
				while (current.length > root.split("/").length) {
					tryRemoveDirectory(current.join("/"));
					current.pop();
				}
			}
		}
	}

	function journalManifestForCleanup(journal:OwnershipJournal):Null<OwnershipManifest> {
		try {
			final storage = journal.nextManifest.storagePath;
			if (lexists(relativeAbsolute(storage))) {
				return OwnershipContract.validateManifest(readCanonicalRelative(storage, "next manifest"));
			}
			if (lexists(relativeAbsolute(manifestPath))) {
				return OwnershipContract.validateManifest(readCanonicalRelative(manifestPath, "live manifest"));
			}
		} catch (_:haxe.Exception) {}
		return null;
	}

	function tryRemoveDirectory(relative:String):Void {
		if (!lexists(relativeAbsolute(relative))) {
			return;
		}
		final stats = Fs.lstatSync(relativeAbsolute(relative));
		if (stats.isSymbolicLink() || !stats.isDirectory()) {
			return;
		}
		try {
			Fs.rmdirSync(relativeAbsolute(relative));
			fsyncDirectory(Path.dirname(relativeAbsolute(relative)));
		} catch (_:js.lib.Error) {}
	}

	function unlinkMatching(relative:String, expected:OwnershipContentState):Void {
		final actual = regularState(relative, "recovery path");
		if (OwnershipContract.isAbsent(actual)) {
			return;
		}
		if (!stateEquals(actual, expected)) {
			fail("recovery refused to remove unexpected live bytes", "recovery-conflict", relative);
		}
		unlinkRelative(relative);
	}

	function unlinkRelative(relative:String):Void {
		revalidateProjectRoot();
		assertSafeComponents(relative, "unlink path");
		Fs.unlinkSync(relativeAbsolute(relative));
		fsyncDirectory(Path.dirname(relativeAbsolute(relative)));
	}

	function renameRelative(from:String, to:String):Void {
		revalidateProjectRoot();
		assertSafeComponents(from, "rename source");
		assertSafeComponents(to, "rename destination");
		final sourceStats = Fs.lstatSync(relativeAbsolute(from));
		final destinationParent = Fs.lstatSync(Path.dirname(relativeAbsolute(to)));
		if (sourceStats.dev != rootDevice || destinationParent.dev != rootDevice) {
			fail("v1 publication refuses a cross-device rename", "cross-device-rename", to);
		}
		Fs.renameSync(relativeAbsolute(from), relativeAbsolute(to));
		fsyncDirectory(Path.dirname(relativeAbsolute(from)));
		if (Path.dirname(relativeAbsolute(from)) != Path.dirname(relativeAbsolute(to))) {
			fsyncDirectory(Path.dirname(relativeAbsolute(to)));
		}
	}

	function atomicWrite(relative:String, buffer:Buffer, mode:Int = PRIVATE_FILE_MODE):Void {
		final temporary = relative == journalPath ? journalTemporaryPath : Path.dirname(relative) + "/." + Path.basename(relative) + ".tmp";
		if (lexists(relativeAbsolute(temporary))) {
			fail("atomic metadata temporary path already exists", "transaction-collision", relative);
		}
		ensureParent(relative);
		writeExclusive(temporary, buffer, mode);
		renameRelative(temporary, relative);
	}

	function writeExclusive(relative:String, buffer:Buffer, mode:Int = PRIVATE_FILE_MODE):Void {
		revalidateProjectRoot();
		assertSafeComponents(relative, "exclusive write");
		final absolute = relativeAbsolute(relative);
		var descriptor:Null<Int> = null;
		try {
			descriptor = Fs.openSync(absolute, "wx", mode);
			var offset = 0;
			while (offset < buffer.length) {
				final written = Fs.writeSync(descriptor, buffer, offset, buffer.length - offset, offset);
				if (written <= 0) {
					fail("exclusive write made no progress", "filesystem-write", relative);
				}
				offset += written;
			}
			Fs.fsyncSync(descriptor);
		} catch (failure:js.lib.Error) {
			if (descriptor != null) {
				try {
					Fs.closeSync(descriptor);
				} catch (_:js.lib.Error) {}
			}
			throw failure;
		}
		Fs.closeSync(descriptor);
		fsyncDirectory(Path.dirname(absolute));
	}

	function ensureDirectory(relative:String):Void {
		OwnershipContract.relative(relative, "directory path");
		final parts = relative.split("/");
		var current = "";
		for (part in parts) {
			current = current.length == 0 ? part : current + "/" + part;
			final absolute = relativeAbsolute(current);
			final stats = lstatAbsolute(absolute, "directory");
			if (stats == null) {
				Fs.mkdirSync(absolute, 0x1c0);
				fsyncDirectory(Path.dirname(absolute));
			} else if (stats.isSymbolicLink() || !stats.isDirectory() || stats.dev != rootDevice) {
				fail("unsafe directory component appeared: " + current, "unsafe-path", current);
			}
		}
	}

	function ensureParent(relative:String):Void {
		OwnershipContract.relative(relative, "destination path");
		final parent = Path.dirname(relative).split(Path.sep).join("/");
		if (parent != "." && parent.length > 0) {
			ensureDirectory(parent);
		}
		assertSafeComponents(relative, "destination");
	}

	function assertSafeComponents(relative:String, label:String):Void {
		OwnershipContract.relative(relative, label);
		revalidateProjectRoot();
		final parts = relative.split("/");
		var current = projectRoot;
		for (index in 0...parts.length) {
			current = Path.resolve(current, parts[index]);
			final stats = lstatAbsolute(current, label);
			if (stats == null) {
				continue;
			}
			if (stats.isSymbolicLink()) {
				fail(label + " contains a symbolic-link component", "unsafe-path", relative);
			}
			if (index < parts.length - 1 && !stats.isDirectory()) {
				fail(label + " contains a non-directory parent component", "unsafe-path", relative);
			}
		}
	}

	function regularState(relative:String, label:String):OwnershipContentState {
		assertSafeComponents(relative, label);
		final absolute = relativeAbsolute(relative);
		final stats = lstatAbsolute(absolute, label);
		if (stats == null) {
			return OwnershipContract.contentState();
		}
		if (stats.isSymbolicLink() || !stats.isFile()) {
			fail(label + " is not a regular file", "unexpected-file-type", relative);
		}
		return OwnershipContract.contentState(readBufferAbsolute(absolute));
	}

	function requireState(relative:String, expected:OwnershipContentState, message:String):Void {
		if (!stateEquals(regularState(relative, "content path"), expected)) {
			fail(message + ": " + relative, "content-mismatch", relative);
		}
	}

	function readCanonicalRelative(relative:String, label:String):JsonValue {
		final state = regularState(relative, label);
		if (!OwnershipContract.isFile(state)) {
			fail(label + " is absent", "missing-metadata", relative);
		}
		return OwnershipJson.parseCanonical(readBufferAbsolute(relativeAbsolute(relative)), label);
	}

	function descriptorForManifestFile(item:OwnershipFile):OwnershipContentState {
		return FileContent(item.contentSha256, item.sizeBytes);
	}

	function stateEquals(left:OwnershipContentState, right:OwnershipContentState):Bool {
		return OwnershipContract.contentEquals(left, right);
	}

	function relativeAbsolute(relative:String):String {
		return Path.resolve(projectRoot, relative);
	}

	function revalidateProjectRoot():Void {
		final stats = lstatAbsolute(projectRoot, "project root");
		if (stats == null || stats.isSymbolicLink() || !stats.isDirectory() || stats.dev != rootDevice || stats.ino != rootInode) {
			fail("project root identity changed during ownership transaction", "project-root-changed");
		}
	}

	function lstatAbsolute(path:String, label:String):Null<Stats> {
		try {
			return Fs.lstatSync(path);
		} catch (failure:js.lib.Error) {
			// hxnodejs omits Node's fs error `code`; this exact read is immediately narrowed to Null<String>.
			final code:Null<String> = Syntax.code("{0}.code", failure);
			if (code == "ENOENT" || code == "ENOTDIR") {
				return null;
			}
			throw new OwnershipFailure(label + " could not be inspected", "filesystem-inspection");
		}
	}

	function lexists(path:String):Bool {
		return lstatAbsolute(path, "filesystem path") != null;
	}

	function readBufferAbsolute(path:String):Buffer {
		return Fs.readFileSync(path);
	}

	function fsyncDirectory(path:String):Void {
		var descriptor:Null<Int> = null;
		try {
			descriptor = Fs.openSync(path, "r");
			Fs.fsyncSync(descriptor);
			Fs.closeSync(descriptor);
		} catch (_:js.lib.Error) {
			if (descriptor != null) {
				try {
					Fs.closeSync(descriptor);
				} catch (_:js.lib.Error) {}
			}
			throw new OwnershipFailure("supported filesystem profile requires directory fsync", "unsupported-filesystem");
		}
	}

	function checkpoint(name:String):Void {
		#if wordpresshx_ownership_fault_injection
		if (fault != null) {
			fault(name);
		}
		#end
	}

	function fail<T>(message:String, code:String, ?path:String):T {
		throw new OwnershipFailure(message, code, path);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
