package wordpresshx.cli.project;

import js.node.Buffer;

/** Typed proof that the exact emitted plugin passed the pinned PHP gate. */
class PluginPhpQualityResult {
	public final policyId:String;
	public final policySha256:String;
	public final composerLockSha256:String;
	public final wordpressStubsSha256:String;
	public final phpFileCount:Int;
	public final publicPhpFileCount:Int;
	public final privatePhpFileCount:Int;
	public final classmapEntries:Int;
	public final reportBytes:Buffer;
	public final reportSha256:String;

	public function new(policyId:String, policySha256:String, composerLockSha256:String, wordpressStubsSha256:String, phpFileCount:Int,
			publicPhpFileCount:Int, privatePhpFileCount:Int, classmapEntries:Int, reportBytes:Buffer) {
		this.policyId = policyId;
		this.policySha256 = policySha256;
		this.composerLockSha256 = composerLockSha256;
		this.wordpressStubsSha256 = wordpressStubsSha256;
		this.phpFileCount = phpFileCount;
		this.publicPhpFileCount = publicPhpFileCount;
		this.privatePhpFileCount = privatePhpFileCount;
		this.classmapEntries = classmapEntries;
		this.reportBytes = reportBytes;
		this.reportSha256 = wordpresshx.cli.ownership.OwnershipJson.digest(reportBytes);
	}
}
