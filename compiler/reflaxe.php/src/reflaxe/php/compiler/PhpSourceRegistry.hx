package reflaxe.php.compiler;

#if macro
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.macro.Context;
import haxe.macro.Expr.Position;
import reflaxe.php.ir.PhpSourceFile;
import reflaxe.php.ir.PhpSourceKind;
import reflaxe.php.ir.PhpSourceRange;
import sys.io.File;
#end

/** Authenticates application source bytes and converts Haxe positions to exact ranges. **/
class PhpSourceRegistry {
	#if macro
	final config:PhpCompilerConfig;
	final sourcesByPath:Map<String, PhpSourceFile> = [];

	public function new(config:PhpCompilerConfig) {
		this.config = config;
	}

	public function owns(position:Position):Bool {
		return config.owns(position);
	}

	public function range(position:Position):PhpSourceRange {
		final info = Context.getPosInfos(position);
		final source = source(position);
		if (info.min < 0 || info.max <= info.min || info.max > source.content.length) {
			Context.fatalError("reflaxe.php received an invalid or empty Haxe source position", position);
			return source.exactRange(0, 1);
		}
		return source.exactRange(source.byteOffsetForCharacterOffset(info.min), source.byteOffsetForCharacterOffset(info.max));
	}

	public function buildInputsSha256():String {
		final sources = [for (source in sourcesByPath) source];
		sources.sort((left, right) -> compareText(left.id, right.id));
		final transcript = sources.map(source -> source.id + "\t" + source.sha256 + "\n").join("");
		return Sha256.make(Bytes.ofString(transcript)).toHex().toLowerCase();
	}

	function source(position:Position):PhpSourceFile {
		final logicalPath = config.logicalPath(position);
		if (sourcesByPath.exists(logicalPath)) {
			final existing = sourcesByPath.get(logicalPath);
			if (existing != null) {
				return existing;
			}
		}
		final content = File.getContent(Context.getPosInfos(position).file);
		if (content.indexOf("\r") != -1) {
			Context.fatalError("reflaxe.php requires LF-normalized Haxe source: " + logicalPath, position);
		}
		final created = new PhpSourceFile("source:" + logicalPath, "reflaxe.php.application", logicalPath, PhpHaxeSource, content);
		sourcesByPath.set(logicalPath, created);
		return created;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
	#end
}
