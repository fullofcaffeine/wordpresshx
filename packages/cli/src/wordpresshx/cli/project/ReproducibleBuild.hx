package wordpresshx.cli.project;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Canonical build report plus the exact normalized unsigned archive it binds. **/
class ReproducibleBuild {
	public static inline final SCHEMA = "wordpress-hx.reproducible-build.v1";
	public static inline final REPORT_ARCHIVE_PATH = "_wphx/reproducible-build.json";

	public static function create(context:ProjectContext, payloads:Array<ReproduciblePayload>):ReproducibleProducts {
		if (payloads.length == 0) {
			fail("a reproducible package requires at least one generated payload");
		}
		final sorted = payloads.copy();
		sorted.sort((left, right) -> Reflect.compare(left.path, right.path));
		final reportEntries:Array<Dynamic> = [];
		final archiveEntries:Array<DeterministicZipEntry> = [];
		var previous:Null<String> = null;
		var previousFolded:Null<String> = null;
		for (payload in sorted) {
			ProjectContract.relativePath(payload.path, "reproducible payload path");
			final folded = payload.path.toLowerCase();
			if (payload.path == REPORT_ARCHIVE_PATH
				|| (previous != null && Reflect.compare(previous, payload.path) >= 0)
				|| previousFolded == folded) {
				fail("reproducible payload paths are duplicate, colliding, or reserved", payload.path);
			}
			previous = payload.path;
			previousFolded = folded;
			reportEntries.push(OwnershipJson.object([
				"path" => payload.path,
				"sha256" => OwnershipJson.digest(payload.bytes),
				"sizeBytes" => payload.bytes.length,
				"mode" => DeterministicZip.FILE_MODE
			]));
			archiveEntries.push({path: payload.path, bytes: payload.bytes});
		}
		final profile = ProjectContract.fieldObject(context.lock, "profile", "project lock");
		final report = OwnershipJson.object([
			"schema" => SCHEMA,
			"canonicalization" => "wordpress-hx.canonical-json.v1",
			"fingerprint" => context.fingerprint(),
			"project" => OwnershipJson.object([
				"id" => ProjectContract.string(context.bootstrap.config, "projectId", "project configuration"),
				"profileId" => context.profileId(),
				"profileCatalogSha256" => ProjectContract.string(profile, "catalogSha256", "project lock.profile", "profile-resolution"),
				"toolchainSha256" => ProjectContract.string(context.lock, "lockDigest", "project lock", "profile-resolution")
			]),
			"normalization" => OwnershipJson.object([
				"archiveFormat" => DeterministicZip.FORMAT,
				"entryOrder" => "portable-ascii-path-ascending",
				"fileMode" => DeterministicZip.FILE_MODE,
				"directoryMode" => DeterministicZip.DIRECTORY_MODE,
				"modifiedAt" => DeterministicZip.MODIFIED_AT,
				"compression" => "stored",
				"extraFields" => false,
				"archiveComment" => false
			]),
			"entries" => reportEntries
		]);
		final reportBytes = OwnershipJson.encodeDocument(report);
		archiveEntries.push({path: REPORT_ARCHIVE_PATH, bytes: reportBytes});
		archiveEntries.sort((left, right) -> Reflect.compare(left.path, right.path));
		final archiveBytes = DeterministicZip.create(archiveEntries);
		final allNames = [for (entry in archiveEntries) entry.path];
		return {
			report: report,
			reportBytes: reportBytes,
			archiveBytes: archiveBytes,
			archiveEntries: allNames
		};
	}

	public static function validateStage(root:String, paths:ProjectOwnershipPaths, context:ProjectContext, payloads:Array<ReproduciblePayload>):Void {
		final expected = create(context, payloads);
		final reportBytes = readStage(root, paths.reproducibilityPath);
		final archiveBytes = readStage(root, paths.archivePath);
		final report = OwnershipJson.parseCanonical(reportBytes, "staged reproducibility report");
		if (OwnershipJson.encode(report) != OwnershipJson.encode(expected.report)
			|| reportBytes.length != expected.reportBytes.length
			|| OwnershipJson.digest(reportBytes) != OwnershipJson.digest(expected.reportBytes)) {
			fail("staged reproducibility report differs from the canonical generation", paths.reproducibilityPath);
		}
		if (archiveBytes.length != expected.archiveBytes.length
			|| OwnershipJson.digest(archiveBytes) != OwnershipJson.digest(expected.archiveBytes)) {
			fail("staged unsigned archive differs from its canonical entry set", paths.archivePath);
		}
	}

	static function readStage(root:String, relative:String):Buffer {
		final absolute = Path.resolve(root, relative);
		if (!Fs.existsSync(absolute)) {
			fail("staged reproducibility artifact is missing", relative);
		}
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || !stats.isFile()) {
			fail("staged reproducibility artifact is not a regular file", relative);
		}
		return Fs.readFileSync(absolute);
	}

	static function fail(message:String, ?path:String):Dynamic {
		throw new CliFailure("WPHX3201", message, 5, "artifact-validation", path, [
			"Run a clean build and inspect the first differing report entry before publication."
		]);
	}
}
