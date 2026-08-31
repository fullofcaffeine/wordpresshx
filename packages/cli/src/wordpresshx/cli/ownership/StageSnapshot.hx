package wordpresshx.cli.ownership;

import js.node.Buffer;

/**
	One owner-captured manifest and complete stage view.

	Every read returns a copy. A validator cannot change the buffers that the
	owner later installs, and the owner never reopens caller paths after capture.
**/
final class StageSnapshot {
	final manifest:Buffer;
	final staged:Map<String, Buffer>;

	public function new(manifest:Buffer, staged:Map<String, Buffer>) {
		this.manifest = copy(manifest);
		this.staged = new Map<String, Buffer>();
		for (path => buffer in staged) {
			this.staged.set(path, copy(buffer));
		}
	}

	public function manifestBytes():Buffer {
		return copy(manifest);
	}

	public function paths():Array<String> {
		final result = [for (path => _ in staged) path];
		result.sort(compareText);
		return result;
	}

	public function read(relativePath:String):Null<Buffer> {
		final path = OwnershipContract.relative(relativePath, "stage snapshot path");
		final buffer = staged.get(path);
		return buffer == null ? null : copy(buffer);
	}

	static function copy(source:Buffer):Buffer {
		final result = Buffer.alloc(source.length);
		source.copy(result);
		return result;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
