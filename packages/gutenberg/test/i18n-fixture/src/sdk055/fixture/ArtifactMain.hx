package sdk055.fixture;

import sys.FileSystem;
import sys.io.File;
import wordpress.hx.compiler.php.profile.WordPressI18nArtifact;
import wordpress.hx.compiler.php.profile.Wp70I18nProfile;

/** Writes one complete deterministic SDK-055 artifact from final browser bytes. */
class ArtifactMain {
	public static function main():Void {
		final arguments = Sys.args();
		if (arguments.length != 3) {
			throw "usage: ArtifactMain <messages.js> <messages.asset.php> <output-root>";
		}
		final bundlePath = arguments[0];
		final metadataPath = arguments[1];
		final outputRoot = arguments[2];
		if (!FileSystem.exists(bundlePath) || !FileSystem.exists(metadataPath) || FileSystem.exists(outputRoot)) {
			throw "SDK-055 artifact inputs must exist and output root must be absent";
		}
		final plan = I18nFixture.plan(File.getBytes(bundlePath), File.getBytes(metadataPath), File.getBytes(I18nFixture.SOURCE_PATH));
		final artifact = new Wp70I18nProfile().emit(plan);
		writeArtifact(outputRoot, artifact);
	}

	static function writeArtifact(outputRoot:String, artifact:WordPressI18nArtifact):Void {
		ensureDirectory(outputRoot);
		for (file in artifact.files) {
			final destination = outputRoot + "/" + file.path;
			ensureParent(destination);
			File.saveBytes(destination, file.content);
		}
		File.saveContent(outputRoot + "/" + artifact.plan.manifestPath, artifact.manifestSource());
	}

	static function ensureParent(path:String):Void {
		final separator = path.lastIndexOf("/");
		if (separator > 0) {
			ensureDirectory(path.substr(0, separator));
		}
	}

	static function ensureDirectory(path:String):Void {
		if (FileSystem.exists(path)) {
			return;
		}
		final separator = path.lastIndexOf("/");
		if (separator > 0) {
			ensureDirectory(path.substr(0, separator));
		}
		FileSystem.createDirectory(path);
	}
}
