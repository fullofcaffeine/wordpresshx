package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpIdentifier;
import wordpress.hx.compiler.php.profile.WordPressRestMethod.WordPressRestMethodTools;

/** One native register_rest_route callback/permission boundary. **/
class WordPressRestRouteRegistration {
	static final NAMESPACE = ~/^[a-z0-9]+(?:-[a-z0-9]+)*(?:\/[a-z][a-z0-9.-]*)+$/;

	public final namespace:String;
	public final route:String;
	public final method:WordPressRestMethod;
	public final callback:PhpIdentifier;
	public final permissionCallback:PhpIdentifier;

	public function new(namespace:String, route:String, method:WordPressRestMethod, callback:PhpIdentifier, permissionCallback:PhpIdentifier) {
		if (namespace == null || !NAMESPACE.match(namespace)) {
			throw "REST namespace must be a lowercase plugin/version path without edge slashes";
		}
		if (!safeRoute(route)) {
			throw "REST route must be a bounded slash-prefixed pattern without whitespace or controls";
		}
		if (method == null || callback == null || permissionCallback == null) {
			throw "REST route requires method, callback, and permission callback";
		}
		this.namespace = namespace;
		this.route = route;
		this.method = method;
		this.callback = callback;
		this.permissionCallback = permissionCallback;
	}

	public function stableIdentity():String {
		return namespace + ":" + route + ":" + WordPressRestMethodTools.id(method);
	}

	static function safeRoute(value:String):Bool {
		if (value == null || value.length < 2 || value.length > 240 || !StringTools.startsWith(value, "/")) {
			return false;
		}
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			if (code <= 32 || code == 127) {
				return false;
			}
		}
		return true;
	}
}
