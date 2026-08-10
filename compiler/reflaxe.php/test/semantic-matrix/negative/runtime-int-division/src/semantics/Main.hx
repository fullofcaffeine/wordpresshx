package semantics;

class Main {
	static function divide(value:Int):Int {
		return Std.int(value / 2);
	}

	static function main():Void {
		Sys.println("runtime-int-division:stock-pass");
	}
}
