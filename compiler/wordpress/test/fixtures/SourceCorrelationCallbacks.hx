package fixtures.sourcecorrelation;

private typedef SourceCorrelationAttribute = {
	final name:String;
	final value:String;
}

private class SourceCorrelationRestRequest {}
private class SourceCorrelationRestResponse {}
private class SourceCorrelationBlock {}

/** Haxe-only application surface used to prove PHP failure correlation. **/
class SourceCorrelationCallbacks {
	public static function failHook():Void {
		throw new haxe.Exception("hook failure");
	}

	public static function allowRest(request:SourceCorrelationRestRequest):Bool {
		return true;
	}

	public static function failRest(request:SourceCorrelationRestRequest):SourceCorrelationRestResponse {
		throw new haxe.Exception("rest failure");
	}

	public static function failRender(attributes:Array<SourceCorrelationAttribute>, content:String, block:SourceCorrelationBlock):String {
		throw new haxe.Exception("render failure");
	}

	public static function failPrivate():Void {
		privateFailure();
	}

	static function privateFailure():Void {
		throw new haxe.Exception("private failure");
	}
}
