package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpProperty;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;

/** Closed file/symbol/edge plan for native WordPress callback adapters. **/
class WordPressPublicAdapterPlan {
	public final plugin:PluginBootstrapPlan;
	public final className:PhpIdentifier;
	public final source:PhpSourceRange;
	public final adapterPath:String;
	public final registrationPath:String;
	public final adapterClass:String;
	public final absoluteAdapterClass:String;

	final propertyValues:Array<PhpProperty>;
	final methodValues:Array<PhpMethod>;
	final hookValues:Array<WordPressHookRegistration>;
	final restRouteValues:Array<WordPressRestRouteRegistration>;
	final blockValues:Array<WordPressBlockRegistration>;
	final exportValues:Array<WordPressPublicExport>;

	public var properties(get, never):Array<PhpProperty>;
	public var methods(get, never):Array<PhpMethod>;
	public var hooks(get, never):Array<WordPressHookRegistration>;
	public var restRoutes(get, never):Array<WordPressRestRouteRegistration>;
	public var blocks(get, never):Array<WordPressBlockRegistration>;
	public var exports(get, never):Array<WordPressPublicExport>;

	public function new(plugin:PluginBootstrapPlan, className:PhpIdentifier, source:PhpSourceRange, properties:Array<PhpProperty>, methods:Array<PhpMethod>,
			hooks:Array<WordPressHookRegistration>, restRoutes:Array<WordPressRestRouteRegistration>, blocks:Array<WordPressBlockRegistration>,
			exports:Array<WordPressPublicExport>) {
		if (plugin == null || className == null || source == null || properties == null || methods == null || hooks == null || restRoutes == null
			|| blocks == null || exports == null) {
			throw "WordPress public adapter plan requires every closed inventory";
		}
		final canonicalClassName = className.value.toLowerCase();
		if (canonicalClassName == "bootstrap" || canonicalClassName == "autoload") {
			throw "WordPress public adapter class collides with a reserved plugin file: " + className.value;
		}
		this.plugin = plugin;
		this.className = className;
		this.source = source;
		this.adapterPath = "includes/" + className.value + ".php";
		this.registrationPath = "includes/register-adapters.php";
		this.adapterClass = plugin.namespace.toString() + "\\" + className.value;
		this.absoluteAdapterClass = "\\" + adapterClass;
		this.propertyValues = checkedProperties(properties);
		this.methodValues = checkedMethods(methods);
		this.hookValues = checkedValues(hooks, "hook");
		this.restRouteValues = checkedValues(restRoutes, "REST route");
		this.blockValues = checkedValues(blocks, "block");
		this.exportValues = checkedValues(exports, "public export");
		validateEdges();
	}

	public function method(name:PhpIdentifier):PhpMethod {
		for (method in methodValues) {
			if (method.name.value.toLowerCase() == name.value.toLowerCase()) {
				return method;
			}
		}
		throw "Unknown WordPress public adapter method: " + name.value;
	}

	public static function typeLabel(type:Null<PhpType>):Null<String> {
		return switch (type) {
			case null: null;
			case PhpNamedType(name): name.toString();
			case PhpArrayType: "array";
			case PhpBoolType: "bool";
			case PhpCallableType: "callable";
			case PhpFloatType: "float";
			case PhpIntType: "int";
			case PhpIterableType: "iterable";
			case PhpObjectType: "object";
			case PhpStringType: "string";
			case PhpVoidType: "void";
			case PhpNullableType(inner): "?" + typeLabel(inner);
		}
	}

	function validateEdges():Void {
		final identities:Map<String, Bool> = [];
		for (hook in hookValues) {
			unique(identities, hook.stableIdentity(), "hook registration");
			final callback = publicStatic(hook.callback, "hook callback");
			if (callback.parameters.length != hook.acceptedArgs) {
				throw "Hook accepted_args must equal callback arity until typed truncation exists: " + hook.callback.value;
			}
			switch (hook.kind) {
				case Action:
					requireReturn(callback, "void", "action callback");
				case Filter:
					if (callback.parameters.length == 0
						|| typeLabel(callback.returnType) == null
						|| typeLabel(callback.returnType) == "void") {
						throw "Filter callback must accept and return a native value: " + hook.callback.value;
					}
			}
		}
		for (route in restRouteValues) {
			unique(identities, "rest:" + route.stableIdentity(), "REST route");
			final callback = publicStatic(route.callback, "REST callback");
			requireParameters(callback, ["\\WP_REST_Request"], "REST callback");
			final permission = publicStatic(route.permissionCallback, "REST permission callback");
			requireParameters(permission, ["\\WP_REST_Request"], "REST permission callback");
			requireReturn(permission, "bool", "REST permission callback");
		}
		for (block in blockValues) {
			unique(identities, "block:" + block.blockName, "block registration");
			final callback = publicStatic(block.renderCallback, "block render callback");
			requireParameters(callback, ["array", "string", "\\WP_Block"], "block render callback");
			requireReturn(callback, "string", "block render callback");
		}
		for (export in exportValues) {
			unique(identities, "export:" + export.method.value.toLowerCase(), "public export");
			publicStatic(export.method, "public export");
		}
	}

	function publicStatic(name:PhpIdentifier, label:String):PhpMethod {
		final value = method(name);
		switch (value.visibility) {
			case PhpPublic:
			case _:
				throw label + " must be public: " + name.value;
		}
		if (!value.isStatic) {
			throw label + " must be static: " + name.value;
		}
		return value;
	}

	static function requireParameters(method:PhpMethod, expected:Array<String>, label:String):Void {
		if (method.parameters.length != expected.length) {
			throw label + " has the wrong arity: " + method.name.value;
		}
		for (index in 0...expected.length) {
			if (typeLabel(method.parameters[index].type) != expected[index]) {
				throw label + " parameter " + (index + 1) + " must be " + expected[index] + ": " + method.name.value;
			}
		}
	}

	static function requireReturn(method:PhpMethod, expected:String, label:String):Void {
		if (typeLabel(method.returnType) != expected) {
			throw label + " must return " + expected + ": " + method.name.value;
		}
	}

	static function checkedProperties(values:Array<PhpProperty>):Array<PhpProperty> {
		final copy = values.copy();
		final names:Map<String, Bool> = [];
		for (property in copy) {
			if (property == null) {
				throw "WordPress adapter properties cannot contain null";
			}
			switch (property.visibility) {
				case PhpPrivate:
				case _:
					throw "WordPress adapter implementation properties must remain private";
			}
			if (!property.isStatic) {
				throw "WordPress static adapters require static implementation properties";
			}
			unique(names, property.name.value, "adapter property");
		}
		return copy;
	}

	static function checkedMethods(values:Array<PhpMethod>):Array<PhpMethod> {
		final copy = values.copy();
		final names:Map<String, Bool> = [];
		for (method in copy) {
			if (method == null) {
				throw "WordPress adapter methods cannot contain null";
			}
			final canonical = method.name.value.toLowerCase();
			if (canonical == "registerrestroutes" || canonical == "registerblocks") {
				throw "WordPress adapter method is reserved for synthesized registration: " + method.name.value;
			}
			unique(names, canonical, "adapter method");
		}
		return copy;
	}

	static function checkedValues<T>(values:Array<T>, label:String):Array<T> {
		final copy = values.copy();
		for (value in copy) {
			if (value == null) {
				throw "WordPress adapter " + label + " inventory cannot contain null";
			}
		}
		return copy;
	}

	static function unique(seen:Map<String, Bool>, value:String, label:String):Void {
		final canonical = value.toLowerCase();
		if (seen.exists(canonical)) {
			throw "Duplicate WordPress " + label + ": " + value;
		}
		seen.set(canonical, true);
	}

	function get_properties():Array<PhpProperty> {
		return propertyValues.copy();
	}

	function get_methods():Array<PhpMethod> {
		return methodValues.copy();
	}

	function get_hooks():Array<WordPressHookRegistration> {
		return hookValues.copy();
	}

	function get_restRoutes():Array<WordPressRestRouteRegistration> {
		return restRouteValues.copy();
	}

	function get_blocks():Array<WordPressBlockRegistration> {
		return blockValues.copy();
	}

	function get_exports():Array<WordPressPublicExport> {
		return exportValues.copy();
	}
}
