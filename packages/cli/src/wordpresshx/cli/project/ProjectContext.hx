package wordpresshx.cli.project;

import wordpresshx.cli.closedjson.JsonValue;

class ProjectContext {
	public final bootstrap:ProjectBootstrap;
	public final lock:JsonValue;
	public final lockBytes:js.node.Buffer;
	public final effectiveInputs:JsonValue;

	public function new(bootstrap:ProjectBootstrap, lock:JsonValue, lockBytes:js.node.Buffer, effectiveInputs:JsonValue) {
		this.bootstrap = bootstrap;
		this.lock = lock;
		this.lockBytes = lockBytes;
		this.effectiveInputs = effectiveInputs;
	}

	public inline function fingerprint():String {
		return ProjectContract.string(effectiveInputs, "fingerprint", "effective inputs");
	}

	public inline function profileId():String {
		return ProjectContract.string(ProjectContract.fieldObject(lock, "profile", "project lock", "profile-resolution"), "id", "project lock.profile",
			"profile-resolution");
	}
}
