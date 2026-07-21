package wordpresshx.cli;

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import wordpresshx.cli.closedjson.JsonValue;

typedef ContentPosition = {
	final line:Int;
	final columnUtf8:Int;
}

typedef ContentSpan = {
	final startByte:Int;
	final endByte:Int;
	final start:ContentPosition;
	final end:ContentPosition;
}

/** UTF-8 content identity, logical-path, and redundant-coordinate checks. */
class Content {
	static final SHA256 = ~/^[0-9a-f]{64}$/;
	static final STABLE_ID = ~/^[A-Za-z0-9][A-Za-z0-9._:\/@+\-]{0,255}$/;

	public static function digest(value:String):String {
		return Sha256.make(Bytes.ofString(value)).toHex().toLowerCase();
	}

	public static function byteLength(value:String):Int {
		return Bytes.ofString(value).length;
	}

	public static function lineCount(value:String):Int {
		final bytes = Bytes.ofString(value);
		if (bytes.length == 0) {
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

	public static function positionAt(value:String, byteOffset:Int):ContentPosition {
		final bytes = Bytes.ofString(value);
		Contract.require(byteOffset >= 0 && byteOffset <= bytes.length, "byte offset exceeds authenticated UTF-8 content");
		Contract.require(byteOffset == bytes.length || (bytes.get(byteOffset) & 0xc0) != 0x80, "byte offset splits a UTF-8 sequence");
		var line = 1;
		var lastNewline = -1;
		for (index in 0...byteOffset) {
			if (bytes.get(index) == 0x0a) {
				line++;
				lastNewline = index;
			}
		}
		return {line: line, columnUtf8: byteOffset - lastNewline - 1};
	}

	public static function validateSpan(value:JsonValue, content:Null<String>, byteLength:Int, label:String):ContentSpan {
		Contract.fields(value, ["startByte", "endByte", "start", "end"], label);
		final startByte = Contract.integer(value, "startByte", label);
		final endByte = Contract.integer(value, "endByte", label);
		Contract.require(startByte >= 0 && endByte > startByte && endByte <= byteLength, label + " is not a non-empty in-bounds byte span");
		final start = validatePosition(Contract.fieldValue(value, "start", label), label + ".start");
		final end = validatePosition(Contract.fieldValue(value, "end", label), label + ".end");
		if (content != null) {
			final expectedStart = positionAt(content, startByte);
			final expectedEnd = positionAt(content, endByte);
			Contract.require(start.line == expectedStart.line && start.columnUtf8 == expectedStart.columnUtf8,
				label + " start coordinate contradicts authenticated bytes");
			Contract.require(end.line == expectedEnd.line && end.columnUtf8 == expectedEnd.columnUtf8,
				label + " end coordinate contradicts authenticated bytes");
		}
		return {
			startByte: startByte,
			endByte: endByte,
			start: start,
			end: end
		};
	}

	public static function safeRelativePath(value:String, label:String):String {
		Contract.require(value != null && value.length > 0 && !StringTools.startsWith(value, "/") && value.indexOf("\\") < 0 && value.indexOf(":") < 0,
			label + " must be a safe relative POSIX path");
		for (part in value.split("/")) {
			Contract.require(part.length > 0 && part != "." && part != "..", label + " contains an unsafe path segment");
			for (index in 0...part.length) {
				Contract.require(part.charCodeAt(index) >= 32 && part.charCodeAt(index) != 127, label + " contains a control character");
			}
		}
		return value;
	}

	public static function stableId(value:String, label:String):String {
		Contract.require(value != null && STABLE_ID.match(value), label + " is not a stable ID");
		return value;
	}

	public static function sha256(value:String, label:String):String {
		Contract.require(value != null && SHA256.match(value), label + " is not a lowercase SHA-256");
		return value;
	}

	public static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function validatePosition(value:JsonValue, label:String):ContentPosition {
		Contract.fields(value, ["line", "columnUtf8"], label);
		final line = Contract.integer(value, "line", label);
		final columnUtf8 = Contract.integer(value, "columnUtf8", label);
		Contract.require(line > 0 && columnUtf8 >= 0, label + " is not a valid one-based-line/zero-based-column position");
		return {line: line, columnUtf8: columnUtf8};
	}
}
