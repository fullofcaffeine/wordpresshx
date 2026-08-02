package reflaxe.php.compiler;

import reflaxe.php.ir.PhpStableId;

/** Exact native PHP syntax and type policy selected for one compilation. **/
enum abstract PhpTargetProfile(String) to String {
	var Php74ModernV1 = "php74-modern-v1";

	public static function parse(value:String):PhpTargetProfile {
		return switch (PhpStableId.validate(value, "target profile")) {
			case "php74-modern-v1": Php74ModernV1;
			case other: throw "Unsupported reflaxe.php target profile: " + other;
		}
	}

	public inline function value():String {
		return this;
	}

	public inline function minimumPhpVersionId():Int {
		return this == Php74ModernV1 ? 70400 : throw "Unknown reflaxe.php target profile";
	}

	public inline function usesStrictTypes():Bool {
		return this == Php74ModernV1 ? true : throw "Unknown reflaxe.php target profile";
	}

	public inline function usesNativeIntTypes():Bool {
		return this == Php74ModernV1 ? true : throw "Unknown reflaxe.php target profile";
	}
}
