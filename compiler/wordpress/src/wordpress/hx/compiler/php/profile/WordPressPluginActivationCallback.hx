package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpQualifiedName;

/**
 * Identifies the native PHP callable registered against a plugin root file.
 *
 * WordPress binds activation callbacks to the root plugin `__FILE__`, so this
 * value keeps the class and method typed while the profile owns where the
 * registration is emitted.
 */
class WordPressPluginActivationCallback {
	public final callbackClass:PhpQualifiedName;
	public final callbackMethod:PhpIdentifier;
	public final absoluteClassName:String;

	public function new(callbackClass:PhpQualifiedName, callbackMethod:PhpIdentifier) {
		if (callbackClass == null || callbackMethod == null) {
			throw "WordPress activation callback requires a class and method";
		}
		if (callbackClass.absolute) {
			throw "WordPress activation callback class must be relative";
		}
		this.callbackClass = callbackClass;
		this.callbackMethod = callbackMethod;
		this.absoluteClassName = "\\" + callbackClass.toString();
	}
}
