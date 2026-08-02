package semantics;

class Main {
	public static function main():Void {
		var current = 0;
		do {
			current = current + 1;
		} while (current <= 1);
		if (current == 1) {
			Sys.println("do-while:unexpected");
		} else {
			Sys.println("do-while:fail");
		}
	}
}
