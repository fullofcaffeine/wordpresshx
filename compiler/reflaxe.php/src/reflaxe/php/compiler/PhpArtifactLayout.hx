package reflaxe.php.compiler;

import reflaxe.php.ir.PhpStableId;

/** Collision-safe identities and relative paths for Haxe-owned PHP types. **/
class PhpArtifactLayout {
	static final SEGMENT = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	public static function typeIdentity(moduleName:String, typeName:String):String {
		validateModule(moduleName);
		validateSegment(typeName, "type");
		return PhpStableId.validate(moduleName + "@" + typeName, "module/type identity");
	}

	public static function typePath(moduleName:String, typeName:String):String {
		validateModule(moduleName);
		validateSegment(typeName, "type");
		final moduleSegments = moduleName.split(".").map(encodeSegment);
		return "modules/" + moduleSegments.join("/") + "/" + encodeSegment(typeName) + ".php";
	}

	static function validateModule(value:String):Void {
		if (value == null || value.length == 0) {
			throw "reflaxe.php module identity cannot be empty";
		}
		for (segment in value.split(".")) {
			validateSegment(segment, "module");
		}
	}

	static function validateSegment(value:String, label:String):Void {
		if (value == null || !SEGMENT.match(value)) {
			throw "Invalid reflaxe.php " + label + " path segment: " + value;
		}
	}

	static function encodeSegment(value:String):String {
		return value.length + "_" + value;
	}
}
