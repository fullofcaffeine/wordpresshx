package fixtures.sourcecorrelation;

/** Haxe-only application surface used to prove PHP failure correlation. **/
class SourceCorrelationCallbacks {
	public static function failHook():Void {
		throw new haxe.Exception("hook failure");
	}

	public static function allowRest(request:Dynamic):Bool {
		return true;
	}

	public static function failRest(request:Dynamic):Dynamic {
		throw new haxe.Exception("rest failure");
	}

	public static function failRender(attributes:Array<Dynamic>, content:String, block:Dynamic):String {
		throw new haxe.Exception("render failure");
	}

	public static function failPrivate():Void {
		privateFailure();
	}

	static function privateFailure():Void {
		throw new haxe.Exception("private failure");
	}
}
