package native_global;

/** Typed declaration of the exact native PHP function used by this fixture. */
extern class NativePrintf {
	@:phpGlobalFunction("printf")
	public static function write(format:String, value:String):Void;
}
