package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpIdentifier;

/** One explicit native add_action/add_filter registration. **/
class WordPressHookRegistration {
	static final HOOK_NAME = ~/^[A-Za-z0-9_\.\/:-]+$/;

	public final kind:WordPressHookKind;
	public final hookName:String;
	public final callback:PhpIdentifier;
	public final priority:Int;
	public final acceptedArgs:Int;

	public function new(kind:WordPressHookKind, hookName:String, callback:PhpIdentifier, priority:Int = 10, acceptedArgs:Int = 1) {
		if (kind == null || callback == null) {
			throw "WordPress hook registration requires kind and callback";
		}
		if (hookName == null || !HOOK_NAME.match(hookName)) {
			throw "WordPress hook name contains unsupported characters: " + hookName;
		}
		if (acceptedArgs < 0) {
			throw "WordPress hook accepted_args cannot be negative";
		}
		this.kind = kind;
		this.hookName = hookName;
		this.callback = callback;
		this.priority = priority;
		this.acceptedArgs = acceptedArgs;
	}

	public function stableIdentity():String {
		return (kind == Action ? "action" : "filter") + ":" + hookName + ":" + priority + ":" + callback.value;
	}
}
