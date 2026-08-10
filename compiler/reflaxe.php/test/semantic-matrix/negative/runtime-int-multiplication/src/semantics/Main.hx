package semantics;

class Main {
	static function double(value:Int):Int {
		return value * 2;
	}

	public static function main():Void {
		if (double(5) == 10) {
			Sys.println("runtime-int-multiplication:stock-pass");
		} else {
			Sys.println("runtime-int-multiplication:stock-fail");
		}
	}
}
