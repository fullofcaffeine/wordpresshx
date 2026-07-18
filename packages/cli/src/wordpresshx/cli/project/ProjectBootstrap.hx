package wordpresshx.cli.project;

class ProjectBootstrap {
	public final root:String;
	public final config:Dynamic;
	public final configBytes:js.node.Buffer;
	public final outputRoots:Array<ProjectOutputRoot>;
	public final sourceRoots:Array<String>;
	public final testRoots:Array<String>;
	public final assetRoots:Array<String>;
	public final stateRoot:String;
	public final distributionRoot:String;
	public final lockPath:String;
	public final packageManifestPath:String;
	public final packageLockPath:String;

	public function new(root:String, config:Dynamic, configBytes:js.node.Buffer, outputRoots:Array<ProjectOutputRoot>, sourceRoots:Array<String>,
			testRoots:Array<String>, assetRoots:Array<String>, stateRoot:String, distributionRoot:String, lockPath:String, packageManifestPath:String,
			packageLockPath:String) {
		this.root = root;
		this.config = config;
		this.configBytes = configBytes;
		this.outputRoots = outputRoots;
		this.sourceRoots = sourceRoots;
		this.testRoots = testRoots;
		this.assetRoots = assetRoots;
		this.stateRoot = stateRoot;
		this.distributionRoot = distributionRoot;
		this.lockPath = lockPath;
		this.packageManifestPath = packageManifestPath;
		this.packageLockPath = packageLockPath;
	}
}
