package wordpresshx.cli.project;

class ProjectContext {
	public final bootstrap:ProjectBootstrap;
	public final lock:Dynamic;
	public final lockBytes:js.node.Buffer;
	public final effectiveInputs:Dynamic;

	public function new(bootstrap:ProjectBootstrap, lock:Dynamic, lockBytes:js.node.Buffer, effectiveInputs:Dynamic) {
		this.bootstrap = bootstrap;
		this.lock = lock;
		this.lockBytes = lockBytes;
		this.effectiveInputs = effectiveInputs;
	}

	public inline function fingerprint():String {
		return cast Reflect.field(effectiveInputs, "fingerprint");
	}

	public inline function profileId():String {
		return cast Reflect.field(Reflect.field(lock, "profile"), "id");
	}
}
