package reflaxe.php.compiler;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr.Position;
import sys.FileSystem;
#end

/** Closed compiler inputs that select application source and generated paths. **/
class PhpCompilerConfig {
	#if macro
	public final sourceRoot:String;
	public final targetProfile:PhpTargetProfile;

	public function new() {
		PhpSemanticCapabilities.requireAdmitted(ApplicationSourceRoot);
		final configuredProfile = Context.definedValue("reflaxe_php_profile");
		if (configuredProfile == null || StringTools.trim(configuredProfile).length == 0) {
			Context.fatalError("reflaxe.php requires -D reflaxe_php_profile=<exact profile ID>", Context.currentPos());
			this.targetProfile = Php74ModernV1;
		} else {
			try {
				this.targetProfile = PhpTargetProfile.parse(configuredProfile);
			} catch (message:String) {
				Context.fatalError(message, Context.currentPos());
				this.targetProfile = Php74ModernV1;
			}
		}
		final configuredRoot = Context.definedValue("reflaxe_php_source_root");
		if (configuredRoot == null || StringTools.trim(configuredRoot).length == 0) {
			Context.fatalError("reflaxe.php requires -D reflaxe_php_source_root=<application source directory>", Context.currentPos());
			this.sourceRoot = "";
			return;
		}
		final resolved = Path.normalize(FileSystem.fullPath(configuredRoot));
		if (!FileSystem.exists(resolved) || !FileSystem.isDirectory(resolved)) {
			Context.fatalError("reflaxe.php application source root is not a directory: " + configuredRoot, Context.currentPos());
		}
		this.sourceRoot = withoutTrailingSlash(resolved);
	}

	public function owns(position:Position):Bool {
		final info = Context.getPosInfos(position);
		if (!FileSystem.exists(info.file) || FileSystem.isDirectory(info.file)) {
			return false;
		}
		final file = Path.normalize(FileSystem.fullPath(info.file));
		return file == sourceRoot || StringTools.startsWith(file, sourceRoot + "/");
	}

	public function logicalPath(position:Position):String {
		if (!owns(position)) {
			Context.fatalError("reflaxe.php cannot emit a source outside reflaxe_php_source_root", position);
			return "invalid.hx";
		}
		final file = Path.normalize(FileSystem.fullPath(Context.getPosInfos(position).file));
		final relative = file.substr(sourceRoot.length + 1).split("\\").join("/");
		if (relative.length == 0) {
			Context.fatalError("reflaxe.php source root must contain source files rather than naming a file", position);
			return "invalid.hx";
		}
		return relative;
	}

	static function withoutTrailingSlash(value:String):String {
		var result = value.split("\\").join("/");
		while (result.length > 1 && StringTools.endsWith(result, "/")) {
			result = result.substr(0, result.length - 1);
		}
		return result;
	}
	#end
}
