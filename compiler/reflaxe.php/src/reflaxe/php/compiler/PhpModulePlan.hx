package reflaxe.php.compiler;

import reflaxe.php.ir.PhpStableId;

/** One declaration artifact and its source-derived application dependencies. **/
class PhpModuleNode {
	public final identity:String;
	public final path:String;

	final dependencyValues:Array<String>;

	public var dependencies(get, never):Array<String>;

	public function new(identity:String, path:String, dependencies:Array<String>) {
		this.identity = PhpStableId.validate(identity, "module identity");
		if (path == null || path.length == 0) {
			throw "reflaxe.php module output path cannot be empty";
		}
		this.path = path;
		final values = dependencies.copy();
		values.sort(compareText);
		for (index in 1...values.length) {
			if (values[index - 1] == values[index]) {
				throw "Duplicate reflaxe.php module dependency: " + values[index];
			}
		}
		for (value in values) {
			PhpStableId.validate(value, "module dependency");
		}
		this.dependencyValues = values;
	}

	function get_dependencies():Array<String> {
		return dependencyValues.copy();
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

/** Deterministic dependency-first order independent of compiler callback order. **/
class PhpModulePlan {
	public static function order(nodes:Array<PhpModuleNode>):Array<PhpModuleNode> {
		final byIdentity = new Map<String, PhpModuleNode>();
		final byPath = new Map<String, String>();
		for (node in nodes) {
			if (byIdentity.exists(node.identity)) {
				throw "Duplicate reflaxe.php module identity: " + node.identity;
			}
			if (byPath.exists(node.path)) {
				throw "Colliding reflaxe.php module output path: " + node.path;
			}
			byIdentity.set(node.identity, node);
			byPath.set(node.path, node.identity);
		}
		for (node in nodes) {
			for (dependency in node.dependencies) {
				if (!byIdentity.exists(dependency)) {
					throw "Missing reflaxe.php module dependency " + dependency + " required by " + node.identity;
				}
			}
		}

		final remaining = nodes.copy();
		remaining.sort(compareNodes);
		final emitted = new Map<String, Bool>();
		final result:Array<PhpModuleNode> = [];
		while (remaining.length > 0) {
			var selectedIndex = -1;
			for (index in 0...remaining.length) {
				if (dependenciesEmitted(remaining[index], emitted)) {
					selectedIndex = index;
					break;
				}
			}
			if (selectedIndex < 0) {
				throw "Cyclic reflaxe.php application module dependencies are not yet supported";
			}
			final selected = remaining.splice(selectedIndex, 1)[0];
			result.push(selected);
			emitted.set(selected.identity, true);
		}
		return result;
	}

	static function dependenciesEmitted(node:PhpModuleNode, emitted:Map<String, Bool>):Bool {
		for (dependency in node.dependencies) {
			if (!emitted.exists(dependency)) {
				return false;
			}
		}
		return true;
	}

	static function compareNodes(left:PhpModuleNode, right:PhpModuleNode):Int {
		final byPath = compareText(left.path, right.path);
		return byPath == 0 ? compareText(left.identity, right.identity) : byPath;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
