package wordpresshx.cli.project;

import js.Syntax;
import js.node.Buffer;
import wordpresshx.cli.CliFailure;

/**
	A closed ZIP32 writer for reproducible unsigned packages.

	Entries are stored rather than compressed, sorted by their portable ASCII
	paths, stamped at the ZIP epoch, and assigned one normalized regular-file
	mode. The exact representation therefore does not depend on zlib, locale,
	timezone, filesystem enumeration, mtimes, or host permissions.
**/
class DeterministicZip {
	public static inline final FORMAT = "zip32-stored-v1";
	public static inline final FILE_MODE = 420; // 0644
	public static inline final DIRECTORY_MODE = 493; // 0755
	public static inline final MODIFIED_AT = "1980-01-01T00:00:00Z";

	static inline final UTF8_FLAG = 0x0800;
	static inline final DOS_DATE = 0x0021;
	static inline final DOS_TIME = 0;
	static inline final VERSION_NEEDED = 10;
	static inline final VERSION_MADE_BY_UNIX = 0x0314;
	static inline final REGULAR_0644_SIGNED = -2119958528; // 0x81a40000
	static inline final MAX_SIGNED_BUFFER = 0x7fffffff;
	static final CRC_TABLE = makeCrcTable();

	public static function create(rawEntries:Array<DeterministicZipEntry>):Buffer {
		if (rawEntries.length == 0 || rawEntries.length > 0xffff) {
			fail("archive entry count is outside deterministic ZIP32 bounds");
		}
		final entries = rawEntries.copy();
		entries.sort((left, right) -> ProjectJson.compareText(left.path, right.path));
		var previous:Null<String> = null;
		var previousFolded:Null<String> = null;
		final localChunks:Array<Buffer> = [];
		final centralChunks:Array<Buffer> = [];
		var localOffset = 0;

		for (entry in entries) {
			ProjectContract.relativePath(entry.path, "archive entry path");
			final folded = entry.path.toLowerCase();
			if (previous != null && ProjectJson.compareText(previous, entry.path) >= 0) {
				fail("archive entries are not a sorted unique set", entry.path);
			}
			if (previousFolded == folded) {
				fail("archive entries contain a portable case collision", entry.path);
			}
			previous = entry.path;
			previousFolded = folded;
			final name = Buffer.from(entry.path, "utf8");
			if (name.length == 0 || name.length > 0xffff || entry.bytes.length > MAX_SIGNED_BUFFER) {
				fail("archive entry exceeds deterministic ZIP32 bounds", entry.path);
			}
			final checksum = crc32(entry.bytes);
			final local = Buffer.alloc(30);
			writeUInt32(local, 0x04034b50, 0);
			writeUInt16(local, VERSION_NEEDED, 4);
			writeUInt16(local, UTF8_FLAG, 6);
			writeUInt16(local, 0, 8);
			writeUInt16(local, DOS_TIME, 10);
			writeUInt16(local, DOS_DATE, 12);
			writeUInt32(local, checksum, 14);
			writeUInt32(local, entry.bytes.length, 18);
			writeUInt32(local, entry.bytes.length, 22);
			writeUInt16(local, name.length, 26);
			writeUInt16(local, 0, 28);
			localChunks.push(local);
			localChunks.push(name);
			localChunks.push(entry.bytes);

			final central = Buffer.alloc(46);
			writeUInt32(central, 0x02014b50, 0);
			writeUInt16(central, VERSION_MADE_BY_UNIX, 4);
			writeUInt16(central, VERSION_NEEDED, 6);
			writeUInt16(central, UTF8_FLAG, 8);
			writeUInt16(central, 0, 10);
			writeUInt16(central, DOS_TIME, 12);
			writeUInt16(central, DOS_DATE, 14);
			writeUInt32(central, checksum, 16);
			writeUInt32(central, entry.bytes.length, 20);
			writeUInt32(central, entry.bytes.length, 24);
			writeUInt16(central, name.length, 28);
			writeUInt16(central, 0, 30);
			writeUInt16(central, 0, 32);
			writeUInt16(central, 0, 34);
			writeUInt16(central, 0, 36);
			writeUInt32(central, REGULAR_0644_SIGNED, 38);
			writeUInt32(central, localOffset, 42);
			centralChunks.push(central);
			centralChunks.push(name);
			localOffset = checkedAdd(localOffset, 30 + name.length + entry.bytes.length);
		}

		var centralSize = 0;
		for (chunk in centralChunks) {
			centralSize = checkedAdd(centralSize, chunk.length);
		}
		final end = Buffer.alloc(22);
		writeUInt32(end, 0x06054b50, 0);
		writeUInt16(end, 0, 4);
		writeUInt16(end, 0, 6);
		writeUInt16(end, entries.length, 8);
		writeUInt16(end, entries.length, 10);
		writeUInt32(end, centralSize, 12);
		writeUInt32(end, localOffset, 16);
		writeUInt16(end, 0, 20);
		checkedAdd(checkedAdd(localOffset, centralSize), end.length);
		return Buffer.concat(localChunks.concat(centralChunks).concat([end]));
	}

	static function makeCrcTable():Array<Int> {
		final table:Array<Int> = [];
		for (index in 0...256) {
			var value = index;
			for (_ in 0...8) {
				value = (value & 1) == 1 ? (value >>> 1) ^ -306674912 : value >>> 1; // 0xedb88320
			}
			table.push(value);
		}
		return table;
	}

	static function crc32(bytes:Buffer):Float {
		var value = -1;
		for (index in 0...bytes.length) {
			final byte:Int = Syntax.code("{0}[{1}]", bytes, index);
			value = CRC_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8);
		}
		return unsigned(value ^ -1);
	}

	static function checkedAdd(left:Int, right:Int):Int {
		if (right < 0 || left > MAX_SIGNED_BUFFER - right) {
			fail("archive exceeds the deterministic ZIP32 implementation bound");
		}
		return left + right;
	}

	static inline function unsigned(value:Int):Float {
		return value < 0 ? 4294967296.0 + value : value;
	}

	static inline function writeUInt16(buffer:Buffer, value:Int, offset:Int):Void {
		Syntax.code("{0}.writeUInt16LE({1}, {2})", buffer, value, offset);
	}

	static inline function writeUInt32(buffer:Buffer, value:Float, offset:Int):Void {
		final normalized = value < 0 ? 4294967296.0 + value : value;
		Syntax.code("{0}.writeUInt32LE({1}, {2})", buffer, normalized, offset);
	}

	static function fail<T>(message:String, ?path:String):T {
		throw new CliFailure("WPHX3200", message, 5, "artifact-validation", path, [
			"Keep package entries portable and below ZIP32 limits, then rerun a clean deterministic build."
		]);
	}
}
