package semantics;

class Main {
	public static function main():Void {
		var current = 0;
		current += 1;
		if (current == 1) {
			Sys.println("compound-assignment:unexpected");
		} else {
			Sys.println("compound-assignment:fail");
		}
	}
}
