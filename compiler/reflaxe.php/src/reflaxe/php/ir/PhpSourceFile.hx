package reflaxe.php.ir;

import haxe.crypto.Sha256;
import haxe.io.Bytes;

/** Authenticated UTF-8 source bytes under a logical, reproducible path. **/
class PhpSourceFile {
	public final id:String;
	public final rootId:String;
	public final path:String;
	public final kind:PhpSourceKind;
	public final content:String;
	public final sha256:String;
	public final byteLength:Int;
	public final lineCount:Int;

	final contentBytes:Bytes;

	public function new(id:String, rootId:String, path:String, kind:PhpSourceKind, content:String) {
		this.id = PhpStableId.validate(id, "source ID");
		this.rootId = PhpStableId.validate(rootId, "source root ID");
		this.path = validatePath(path);
		if (kind == null || content == null || content.length == 0) {
			throw "Exact PHP source requires a kind and non-empty UTF-8 content";
		}
		if (content.indexOf("\r") != -1) {
			throw "Exact PHP source must use normalized LF line endings: " + path;
		}
		this.kind = kind;
		this.content = content;
		this.contentBytes = Bytes.ofString(content);
		this.byteLength = contentBytes.length;
		this.sha256 = Sha256.make(contentBytes).toHex().toLowerCase();
		this.lineCount = countLines(contentBytes);
	}

	public function positionAt(byteOffset:Int):PhpSourcePosition {
		return positionIn(contentBytes, byteOffset);
	}

	public function exactRange(startByte:Int, endByte:Int):PhpSourceRange {
		return PhpSourceRange.exact(this, startByte, endByte);
	}

	public static function positionIn(bytes:Bytes, byteOffset:Int):PhpSourcePosition {
		if (bytes == null || byteOffset < 0 || byteOffset > bytes.length) {
			throw "PHP source byte offset is out of bounds: " + byteOffset;
		}
		if (byteOffset < bytes.length && (bytes.get(byteOffset) & 0xc0) == 0x80) {
			throw "PHP source byte offset splits a UTF-8 sequence: " + byteOffset;
		}
		var line = 1;
		var lastNewline = -1;
		for (index in 0...byteOffset) {
			if (bytes.get(index) == 0x0a) {
				line++;
				lastNewline = index;
			}
		}
		return new PhpSourcePosition(line, byteOffset - lastNewline - 1);
	}

	public static function countLines(bytes:Bytes):Int {
		if (bytes == null || bytes.length == 0) {
			return 0;
		}
		var lines = 0;
		for (index in 0...bytes.length) {
			if (bytes.get(index) == 0x0a) {
				lines++;
			}
		}
		return lines + (bytes.get(bytes.length - 1) == 0x0a ? 0 : 1);
	}

	static function validatePath(value:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") != -1) {
			throw "Exact PHP source requires a relative path";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") != -1 || ~/^[A-Za-z]:\//.match(normalized)) {
			throw "Exact PHP source path must be relative: " + value;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "Exact PHP source path contains an unsafe segment: " + value;
			}
		}
		return normalized;
	}
}
