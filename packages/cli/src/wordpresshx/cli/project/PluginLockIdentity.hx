package wordpresshx.cli.project;

/** Exact lock values needed by the plugin producer and ownership receipt. */
class PluginLockIdentity {
	public final lockDigest:String;
	public final sdkLockEntrySha256:String;
	public final sdkVersion:String;
	public final cliVersion:String;
	public final catalogRevision:String;
	public final catalogSha256:String;

	public function new(lockDigest:String, sdkLockEntrySha256:String, sdkVersion:String, cliVersion:String, catalogRevision:String, catalogSha256:String) {
		this.lockDigest = lockDigest;
		this.sdkLockEntrySha256 = sdkLockEntrySha256;
		this.sdkVersion = sdkVersion;
		this.cliVersion = cliVersion;
		this.catalogRevision = catalogRevision;
		this.catalogSha256 = catalogSha256;
	}
}
