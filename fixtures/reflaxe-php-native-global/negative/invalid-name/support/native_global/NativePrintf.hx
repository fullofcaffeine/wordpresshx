package native_global;

extern class NativePrintf {
	@:phpGlobalFunction("printf;system")
	public static function write(format:String, value:String):Void;
}
