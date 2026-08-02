package semantics;

class Main {
	public static function main():Void {
		try {
			throw "raw-string-exception";
		} catch (error:String) {
			Sys.println(error);
		}
	}
}
