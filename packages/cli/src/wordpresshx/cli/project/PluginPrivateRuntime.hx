package wordpresshx.cli.project;

/** Complete dependency-closed private package ready for public adapter wiring. */
class PluginPrivateRuntime {
	public final identity:PluginPrivateRuntimeIdentity;
	public final privateClass:String;
	public final polyfillSha256:String;
	public final stockFrontSha256:String;
	public final classmapEntries:Int;
	public final privatePhpFileCount:Int;
	public final privatePhpBytes:Int;
	public final files:Array<PluginEmittedFile>;

	public function new(identity:PluginPrivateRuntimeIdentity, privateClass:String, polyfillSha256:String, stockFrontSha256:String, classmapEntries:Int,
			privatePhpFileCount:Int, privatePhpBytes:Int, files:Array<PluginEmittedFile>) {
		this.identity = identity;
		this.privateClass = privateClass;
		this.polyfillSha256 = polyfillSha256;
		this.stockFrontSha256 = stockFrontSha256;
		this.classmapEntries = classmapEntries;
		this.privatePhpFileCount = privatePhpFileCount;
		this.privatePhpBytes = privatePhpBytes;
		this.files = files.copy();
		this.files.sort((left, right) -> compareText(left.relativePath, right.relativePath));
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
