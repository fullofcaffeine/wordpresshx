package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.build._internal.JsonValue.JsonField;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockAttribute;

private typedef StaticDeprecation = {
	final version:String;
	final attributes:Array<BlockAttribute>;
	final save:Expr;
	final migrate:Expr;
	final isEligible:Null<Expr>;
	final position:Position;
}

private typedef StaticPlan = {
	final name:String;
	final attributes:Array<BlockAttribute>;
	final deprecations:Array<StaticDeprecation>;
	final sourcePath:String;
	final position:Position;
}

/** Compile-time checker and deterministic plan emitter for static blocks. */
class StaticBlockBuilder {
	static final BLOCK_NAME = ~/^[a-z][a-z0-9-]*\/[a-z][a-z0-9-]*$/;
	static final SEMVER = ~/^[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[0-9A-Za-z.-]+)?$/;
	static final REGISTER_FIELDS = ["name", "edit", "save", "deprecations"];
	static final DEPRECATION_FIELDS = ["version", "save", "migrate", "isEligible"];
	static var callbackInstalled = false;
	static var plans:Array<StaticPlan> = [];

	public static function register(attributeShape:Expr, options:Expr):Expr {
		final currentOwner = shapeOwner(attributeShape);
		final currentAttributes = BlockAttributeDeriver.derive(attributeShape);
		requireExplicitDefaults(currentAttributes, "current", options.pos);
		final fields = objectFields(options, "WPX6110", "StaticBlock.register options");
		requireExactFields(fields, REGISTER_FIELDS, "WPX6110", options.pos);
		final name = literalString(fields.get("name"), "WPX6111", "static block name");
		if (!BLOCK_NAME.match(name)) {
			Context.error("WPX6111: static block name must use namespace/slug lowercase syntax.", fields.get("name").pos);
		}
		final edit = fields.get("edit");
		final save = fields.get("save");
		validateView(edit, "wordpress.hx.gutenberg.block.EditProps", currentOwner, "edit", "WPX6112");
		validateView(save, "wordpress.hx.gutenberg.block.SaveProps", currentOwner, "save", "WPX6113");
		final deprecations = parseDeprecations(fields.get("deprecations"), currentOwner);
		if (deprecations.length == 0) {
			Context.error("WPX6114: a static compatibility proof needs at least one immutable deprecation record.", fields.get("deprecations").pos);
		}
		installCallback();
		for (plan in plans) {
			if (plan.name == name) {
				Context.error('WPX6111: duplicate static block registration ${name}.', options.pos);
			}
		}
		plans.push({
			name: name,
			attributes: currentAttributes,
			deprecations: deprecations,
			sourcePath: sourcePath(options.pos),
			position: options.pos
		});

		final nativeDeprecations:Array<Expr> = [for (deprecation in deprecations) nativeDeprecation(deprecation)];
		final nativeArray:Expr = {expr: EArrayDecl(nativeDeprecations), pos: fields.get("deprecations").pos};
		return macro @:pos(options.pos) wordpress.hx.gutenberg.block._internal.StaticBlockRuntime.register($v{name}, $edit, $save, $nativeArray);
	}

	static function parseDeprecations(expression:Expr, currentOwner:ClassType):Array<StaticDeprecation> {
		final entries = switch expression.expr {
			case EArrayDecl(values): values;
			case _: Context.error("WPX6114: deprecations must be an ordered literal array.", expression.pos);
		};
		final result:Array<StaticDeprecation> = [];
		final versions:Map<String, Bool> = [];
		for (entry in entries) {
			final marker = markerCall(entry);
			final oldOwner = shapeOwner(marker.shape);
			final oldAttributes = BlockAttributeDeriver.derive(marker.shape);
			requireExplicitDefaults(oldAttributes, "deprecated", marker.options.pos);
			final fields = objectFields(marker.options, "WPX6114", "StaticBlock.deprecated options");
			requireAllowedAndRequired(fields, DEPRECATION_FIELDS, ["version", "save", "migrate"], "WPX6114", marker.options.pos);
			final version = literalString(fields.get("version"), "WPX6114", "deprecation version");
			if (!SEMVER.match(version) || versions.exists(version)) {
				Context.error('WPX6114: deprecation version ${version} must be unique semantic version text.', fields.get("version").pos);
			}
			versions.set(version, true);
			final save = fields.get("save");
			final migrate = fields.get("migrate");
			final isEligible = fields.get("isEligible");
			validateView(save, "wordpress.hx.gutenberg.block.SaveProps", oldOwner, "deprecated save", "WPX6115");
			validateMigration(migrate, oldOwner, currentOwner);
			if (isEligible != null) {
				validateEligibility(isEligible, oldOwner);
			}
			result.push({
				version: version,
				attributes: oldAttributes,
				save: save,
				migrate: migrate,
				isEligible: isEligible,
				position: entry.pos
			});
		}
		return result;
	}

	static function markerCall(expression:Expr):{final shape:Expr; final options:Expr;} {
		return switch expression.expr {
			case ECall({expr: EField(ownerExpression, "deprecated")}, [shape, options]):
				final owner = Context.typeExpr(ownerExpression);
				final exact = switch owner.expr {
					case TTypeExpr(TClassDecl(reference)): final declaration = reference.get(); declaration.module == "wordpress.hx.gutenberg.block.StaticBlock" && declaration.name == "StaticBlock";
					case _: false;
				};
				if (!exact) {
					Context.error("WPX6114: deprecation entries must use wordpress.hx.gutenberg.block.StaticBlock.deprecated.", expression.pos);
				}
				{shape: shape, options: options};
			case _:
				Context.error("WPX6114: deprecation entries must be StaticBlock.deprecated(AttributeClass, {...}) calls.", expression.pos);
		};
	}

	static function validateView(expression:Expr, propsPath:String, attributesOwner:ClassType, label:String, code:String):Void {
		final type = Context.follow(Context.typeof(expression));
		final signature = switch type {
			case TFun(arguments, result) if (arguments.length == 1): {argument: arguments[0].t, result: result};
			case _:
				Context.error('${code}: ${label} must be a one-argument function, found ${TypeTools.toString(type)}.', expression.pos);
		};
		if (!propsOwn(signature.argument, propsPath, attributesOwner)) {
			Context.error('${code}: ${label} must accept ${propsPath}<${attributesOwner.module}.${attributesOwner.name}>.', expression.pos);
		}
		final browserNode = Context.getType("wordpress.hx.gutenberg.browser.BrowserNode");
		if (!Context.unify(signature.result, browserNode) || !Context.unify(browserNode, signature.result)) {
			Context.error('${code}: ${label} must return BrowserNode, found ${TypeTools.toString(signature.result)}.', expression.pos);
		}
	}

	static function validateMigration(expression:Expr, oldOwner:ClassType, currentOwner:ClassType):Void {
		final type = Context.follow(Context.typeof(expression));
		switch type {
			case TFun(arguments, result) if (arguments.length == 1):
				if (!sameOwner(arguments[0].t, oldOwner) || !sameOwner(result, currentOwner)) {
					Context.error('WPX6116: migrate must map ${identity(oldOwner)} to ${identity(currentOwner)} exactly.', expression.pos);
				}
			case _:
				Context.error('WPX6116: migrate must be a pure one-argument attribute function, found ${TypeTools.toString(type)}.', expression.pos);
		}
	}

	static function validateEligibility(expression:Expr, oldOwner:ClassType):Void {
		final type = Context.follow(Context.typeof(expression));
		switch type {
			case TFun(arguments, result) if (arguments.length == 1):
				if (!sameOwner(arguments[0].t, oldOwner) || !exactBool(result)) {
					Context.error('WPX6117: isEligible must map ${identity(oldOwner)} to Bool exactly.', expression.pos);
				}
			case _:
				Context.error('WPX6117: isEligible must be a one-argument predicate, found ${TypeTools.toString(type)}.', expression.pos);
		}
	}

	static function nativeDeprecation(deprecation:StaticDeprecation):Expr {
		final fields:Array<ObjectField> = [
			{field: "attributes", expr: BlockSchema.expression(deprecation.attributes, deprecation.position)},
			{field: "save", expr: deprecation.save},
			{field: "migrate", expr: deprecation.migrate}
		];
		if (deprecation.isEligible != null) {
			fields.push({field: "isEligible", expr: deprecation.isEligible});
		}
		return {expr: EObjectDecl(fields), pos: deprecation.position};
	}

	static function installCallback():Void {
		if (callbackInstalled) {
			return;
		}
		callbackInstalled = true;
		Context.onAfterGenerate(emitPlan);
	}

	static function emitPlan():Void {
		final output = Context.definedValue("wordpress_hx_static_block_plan");
		if (output == null || output == "" || output == "1") {
			Context.error("WPX6100: static blocks require -D wordpress_hx_static_block_plan=<path>.", Context.currentPos());
		}
		final candidate = Path.isAbsolute(output) ? output : Path.join([Sys.getCwd(), output]);
		final parent = FileSystem.fullPath(Path.directory(candidate));
		final resolved = Path.join([parent, Path.withoutDirectory(candidate)]);
		if (!FileSystem.exists(parent) || !FileSystem.isDirectory(parent) || FileSystem.exists(resolved)) {
			Context.error("WPX6100: static block plan parent must exist and the output file must be absent.", Context.currentPos());
		}
		plans.sort((left, right) -> compareText(left.name, right.name));
		final document = ObjectValue([
			field("schemaVersion", NumberValue("1")),
			field("profileId", StringValue(Context.definedValue("wordpress_hx_profile"))),
			field("generator", StringValue("wordpresshx-sdk061-static-block-v1")),
			field("blocks", ArrayValue([for (plan in plans) planValue(plan)])),
			field("policy", ObjectValue([
				field("editSaveBoundary", StringValue("distinct-typed-props")),
				field("missingAttributes", StringValue("explicit-default")),
				field("nullAttributes", StringValue("not-admitted")),
				field("deprecations", StringValue("ordered-immutable-source-and-byte-fixtures")),
				field("manualJavaScriptRegistration", BoolValue(false))
			]))
		]);
		File.saveContent(resolved, BlockJson.encode(document) + "\n");
	}

	static function planValue(plan:StaticPlan):JsonValue {
		return ObjectValue([
			field("name", StringValue(plan.name)),
			field("sourcePath", StringValue(plan.sourcePath)),
			field("attributes", BlockSchema.value(plan.attributes)),
			field("deprecations", ArrayValue([
				for (deprecation in plan.deprecations)
					ObjectValue([
						field("version", StringValue(deprecation.version)),
						field("attributes", BlockSchema.value(deprecation.attributes)),
						field("hasEligibility", BoolValue(deprecation.isEligible != null))
					])
			]))
		]);
	}

	static function shapeOwner(expression:Expr):ClassType {
		final typed = Context.typeExpr(expression);
		return switch typed.expr {
			case TTypeExpr(TClassDecl(reference)):
				final owner = reference.get();
				if (owner.params.length > 0) {
					Context.error("WPX6104: static block attribute classes cannot be generic.", expression.pos);
				}
				owner;
			case _:
				Context.error("WPX6104: static blocks require a concrete Haxe attribute class.", expression.pos);
		};
	}

	static function propsOwn(type:Type, propsPath:String, attributesOwner:ClassType):Bool {
		return switch Context.follow(type) {
			case TInst(reference, [attributeType]): final props = reference.get(); props.module == propsPath && props.name == propsPath.substr(propsPath.lastIndexOf(".")
					+ 1) && sameOwner(attributeType, attributesOwner);
			case _: false;
		};
	}

	static function sameOwner(type:Type, expected:ClassType):Bool {
		return switch Context.follow(type) {
			case TInst(reference, parameters): final actual = reference.get(); parameters.length == 0 && actual.module == expected.module && actual.name == expected.name;
			case _: false;
		};
	}

	static function exactBool(type:Type):Bool {
		return switch Context.follow(type) {
			case TAbstract(reference, parameters): final actual = reference.get(); parameters.length == 0 && actual.module == "StdTypes" && actual.name == "Bool";
			case _: false;
		};
	}

	static function requireExplicitDefaults(attributes:Array<BlockAttribute>, label:String, position:Position):Void {
		for (attribute in attributes) {
			if (attribute.defaultValue == null) {
				Context.error('WPX6105: ${label} static attribute ${attribute.name} needs @:wpDefault so missing values have explicit semantics.', position);
			}
		}
	}

	static function objectFields(expression:Expr, code:String, label:String):Map<String, Expr> {
		final result:Map<String, Expr> = [];
		switch expression.expr {
			case EObjectDecl(fields):
				for (entry in fields) {
					if (result.exists(entry.field)) {
						Context.error('${code}: duplicate ${label} field ${entry.field}.', entry.expr.pos);
					}
					result.set(entry.field, entry.expr);
				}
			case _:
				Context.error('${code}: ${label} must be a closed object literal.', expression.pos);
		}
		return result;
	}

	static function requireExactFields(fields:Map<String, Expr>, expected:Array<String>, code:String, position:Position):Void {
		requireAllowedAndRequired(fields, expected, expected, code, position);
	}

	static function requireAllowedAndRequired(fields:Map<String, Expr>, allowed:Array<String>, required:Array<String>, code:String, position:Position):Void {
		for (name in fields.keys()) {
			if (!allowed.contains(name)) {
				Context.error('${code}: unknown field ${name}.', fields.get(name).pos);
			}
		}
		for (name in required) {
			if (!fields.exists(name)) {
				Context.error('${code}: missing required field ${name}.', position);
			}
		}
	}

	static function literalString(expression:Expr, code:String, label:String):String {
		return switch expression.expr {
			case EConst(CString(value, _)) if (value != ""): value;
			case _: Context.error('${code}: ${label} must be a non-empty string literal.', expression.pos);
		};
	}

	static function sourcePath(position:Position):String {
		final file = Context.getPosInfos(position).file.split("\\").join("/");
		final cwd = Sys.getCwd().split("\\").join("/");
		return StringTools.startsWith(file, cwd + "/") ? file.substr(cwd.length + 1) : file;
	}

	static function identity(owner:ClassType):String {
		return owner.module + "." + owner.name;
	}

	static function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
#end
