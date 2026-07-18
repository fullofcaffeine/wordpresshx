package reflaxe.php.ir;

/** A structural PHP class, interface, or trait declaration. **/
class PhpClass {
	public final kind:PhpClassKind;
	public final name:PhpIdentifier;
	public final extendsName:Null<PhpQualifiedName>;
	public final source:PhpSourceRange;
	public final semanticNodeId:Null<String>;

	final implementedNameValues:Array<PhpQualifiedName>;
	final propertyValues:Array<PhpProperty>;
	final methodValues:Array<PhpMethod>;

	public var implementsNames(get, never):Array<PhpQualifiedName>;
	public var properties(get, never):Array<PhpProperty>;
	public var methods(get, never):Array<PhpMethod>;

	public function new(kind:PhpClassKind, name:PhpIdentifier, source:PhpSourceRange, ?extendsName:PhpQualifiedName, ?implementsNames:Array<PhpQualifiedName>,
			?properties:Array<PhpProperty>, ?methods:Array<PhpMethod>, ?semanticNodeId:String) {
		if (kind == null || name == null || source == null) {
			throw "PHP class declaration requires kind, name, and source";
		}
		final interfaces = implementsNames == null ? [] : implementsNames.copy();
		final declaredProperties = properties == null ? [] : properties.copy();
		final declaredMethods = methods == null ? [] : methods.copy();
		for (implementedName in interfaces) {
			if (implementedName == null) {
				throw "PHP implemented names cannot contain null";
			}
		}
		final implementedNames:Map<String, Bool> = [];
		for (implementedName in interfaces) {
			final canonicalName = implementedName.toString().toLowerCase();
			if (implementedNames.exists(canonicalName)) {
				throw "Duplicate PHP implemented name: " + implementedName.toString();
			}
			implementedNames.set(canonicalName, true);
		}
		for (property in declaredProperties) {
			if (property == null) {
				throw "PHP properties cannot contain null";
			}
		}
		for (method in declaredMethods) {
			if (method == null) {
				throw "PHP methods cannot contain null";
			}
		}
		final propertyNames:Map<String, Bool> = [];
		for (property in declaredProperties) {
			if (propertyNames.exists(property.name.value)) {
				throw "Duplicate PHP property: " + property.name.value;
			}
			propertyNames.set(property.name.value, true);
		}
		final methodNames:Map<String, Bool> = [];
		for (method in declaredMethods) {
			final canonicalName = method.name.value.toLowerCase();
			if (methodNames.exists(canonicalName)) {
				throw "Duplicate PHP method: " + method.name.value;
			}
			methodNames.set(canonicalName, true);
		}
		switch (kind) {
			case PhpClassKindInterface:
				if (declaredProperties.length > 0) {
					throw "PHP interface properties are not admitted by this IR";
				}
				for (method in declaredMethods) {
					if (method.body != null) {
						throw "PHP interface methods cannot have bodies";
					}
				}
			case PhpClassKindTrait:
				if (extendsName != null || interfaces.length > 0) {
					throw "PHP traits cannot extend or implement declarations";
				}
				for (method in declaredMethods) {
					if (method.body == null) {
						throw "PHP trait methods require bodies";
					}
				}
			case PhpClassKindClass:
				for (method in declaredMethods) {
					if (method.body == null) {
						throw "Non-abstract PHP class methods require bodies";
					}
				}
		}
		this.kind = kind;
		this.name = name;
		this.extendsName = extendsName;
		this.implementedNameValues = interfaces;
		this.propertyValues = declaredProperties;
		this.methodValues = declaredMethods;
		this.source = source;
		this.semanticNodeId = semanticNodeId == null ? null : PhpStableId.validate(semanticNodeId, "class semantic node ID");
	}

	function get_implementsNames():Array<PhpQualifiedName> {
		return implementedNameValues.copy();
	}

	function get_properties():Array<PhpProperty> {
		return propertyValues.copy();
	}

	function get_methods():Array<PhpMethod> {
		return methodValues.copy();
	}
}
