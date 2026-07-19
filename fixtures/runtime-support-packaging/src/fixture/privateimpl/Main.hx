package fixture.privateimpl;

/** Private application logic compiled behind a native PHP adapter. **/
class Main {
	public static function main():Void {}

	public static function decorate(value:String):String {
		return value + ":" + marker();
	}

	static function marker():String {
		#if runtime_alpha
		return "alpha-v1";
		#elseif runtime_beta
		return "beta-v2";
		#else
		#error "Select exactly one runtime-support fixture variant"
		#end
	}
}
