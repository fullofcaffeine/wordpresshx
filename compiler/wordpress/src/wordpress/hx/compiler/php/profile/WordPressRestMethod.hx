package wordpress.hx.compiler.php.profile;

/** Exact public WP_REST_Server method groups admitted by SDK-023. **/
enum WordPressRestMethod {
	Readable;
	Creatable;
	Editable;
	Deletable;
	AllMethods;
}

class WordPressRestMethodTools {
	public static function constantName(method:WordPressRestMethod):String {
		return switch (method) {
			case Readable: "READABLE";
			case Creatable: "CREATABLE";
			case Editable: "EDITABLE";
			case Deletable: "DELETABLE";
			case AllMethods: "ALLMETHODS";
		}
	}

	public static function id(method:WordPressRestMethod):String {
		return constantName(method).toLowerCase();
	}
}
