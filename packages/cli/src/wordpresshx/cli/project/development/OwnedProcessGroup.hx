package wordpresshx.cli.project.development;

import haxe.Exception;
import js.Syntax;
import wordpresshx.cli.NodeGlobals;

/** Narrow Node process view for the numeric signal-zero existence probe. */
private extern class ProcessGroupProbe {
	public function kill(pid:Int, signal:Int):Void;
}

/**
 * One POSIX process group whose identity is the exact detached child PID.
 *
 * `detached: true` makes that child the group leader before its executable
 * runs. Group-directed signals therefore reach ordinary descendants even when
 * the leader exits first. Windows must use a Job Object and is rejected before
 * this adapter is constructed.
 */
class OwnedProcessGroup {
	public final processGroupId:Int;

	public function new(processGroupId:Int) {
		if (processGroupId <= 1) {
			throw new Exception("owned process group requires a safe positive leader PID");
		}
		this.processGroupId = processGroupId;
	}

	public function signal(signal:String):Bool {
		try {
			NodeGlobals.process().kill(-processGroupId, signal);
			return true;
		} catch (_:Exception) {
			return false;
		}
	}

	public function alive():Bool {
		try {
			processProbe().kill(-processGroupId, 0);
			return true;
		} catch (_:Exception) {
			return false;
		}
	}

	static inline function processProbe():ProcessGroupProbe {
		return Syntax.code("process");
	}
}
