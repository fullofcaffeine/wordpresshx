package wordpress.hx.hxx._internal;

#if macro
import haxe.Json;
import haxe.crypto.Sha256;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import tink.hxx.Attribute;
import tink.hxx.Node.Child;
import tink.hxx.Node.Children;
import tink.hxx.Node.Node;
import tink.hxx.Parser;

using StringTools;

private enum abstract HxxTarget(String) to String {
	var Server = "server";
	var Browser = "browser";
}

private typedef PropContract = {
	final name:String;
	final typeName:String;
	final required:Bool;
}

private typedef SlotContract = {
	final name:String;
	final required:Bool;
}

private typedef ComponentContract = {
	final name:String;
	final targets:Array<HxxTarget>;
	final props:Array<PropContract>;
	final slots:Array<SlotContract>;
	final acceptsChildren:Bool;
}

private typedef SnapshotSpan = {
	final start:Int;
	final end:Int;
}

private typedef SnapshotEntry = {
	final kind:String;
	final name:String;
	final context:String;
	final valueType:String;
	final span:SnapshotSpan;
}

/**
 * Parser-only boundary for the SDK-080 evidence prototype.
 *
 * No tink_hxx type crosses this file. The production semantic contract and
 * native lowerers are intentionally owned by SDK-081 and SDK-032.
 */
class HxxParserAdapter {
	public static function lowerServer(markup:Expr):Expr {
		return lower(markup, Server);
	}

	public static function lowerBrowser(markup:Expr):Expr {
		return lower(markup, Browser);
	}

	private static function lower(markup:Expr, target:HxxTarget):Expr {
		final children = Parser.parseRoot(markup, {
			defaultExtension: "hxx",
			fragment: "__fragment__",
			noControlStructures: false,
			defaultSwitchTarget: macro __data__,
			isVoid: name -> isVoidElement(name.value),
			treatNested: nested -> {
				Context.error("WPXHXX1015 nested inline markup inside an expression is outside the SDK-080 prototype", nested.pos);
				macro null;
			}
		});
		final snapshot = new SnapshotBuilder(target).build(children);

		return switch target {
			case Server:
				macro @:pos(markup.pos) (cast $v{snapshot} : wordpress.hx.hxx.prototype.ServerSnapshot);
			case Browser:
				macro @:pos(markup.pos) (cast $v{snapshot} : wordpress.hx.hxx.prototype.BrowserSnapshot);
		}
	}

	private static function isVoidElement(name:String):Bool {
		return switch name {
			case "area" | "base" | "br" | "col" | "embed" | "hr" | "img" | "input" | "link" | "meta" | "param" | "source" | "track" | "wbr":
				true;
			default:
				false;
		}
	}
}

private class SnapshotBuilder {
	private final target:HxxTarget;
	private final entries:Array<SnapshotEntry> = [];
	private final structure:Array<String> = [];
	private var sourceBase:Int = 0;

	public function new(target:HxxTarget) {
		this.target = target;
	}

	public function build(children:Children):String {
		final rootInfo = Context.getPosInfos(children.pos);
		sourceBase = rootInfo.min;
		visitChildren(children, "root");

		final digest = Sha256.encode(structure.join("\n"));
		final rootSpan = position(children.pos);
		final serializedEntries = entries.map(serializeEntry).join(",");

		return '{"schemaVersion":1,"target":${quote(target)},' + '"semanticDigest":${quote(digest)},' + '"rootSpan":${serializeSpan(rootSpan)},'
			+ '"entryCount":${entries.length},' + '"entries":[${serializedEntries}]}';
	}

	private function visitChildren(children:Null<Children>, context:String):Void {
		if (children == null) {
			return;
		}

		for (child in children.value) {
			visitChild(child, context);
		}
	}

	private function visitChild(child:Child, context:String):Void {
		switch child.value {
			case CNode(node):
				visitNode(node, child.pos, context);
			case CText(text):
				if (text.value.length > 0) {
					add("text", digestIdentity(text.value), context, "String", text.pos);
				}
			case CExpr(expression):
				final actualType = requireScalarChild(expression, context);
				add("expression", expressionIdentity(expression), context, actualType, expression.pos);
			case CSplat(expression):
				final actualType = requireClosedChildSpread(expression, context);
				add("child-spread", expressionIdentity(expression), context, actualType, expression.pos);
			case CIf(condition, consequent, alternative):
				final conditionType = requireType(condition, "Bool", "conditional");
				add("if", expressionIdentity(condition), context, conditionType, child.pos);
				visitChildren(consequent, '$context/if:then');
				visitChildren(alternative, '$context/if:else');
			case CFor(_, _):
				Context.error("WPXHXX1012 for-control lowering is outside the SDK-080 parser prototype", child.pos);
			case CSwitch(_, _):
				Context.error("WPXHXX1013 switch-control lowering is outside the SDK-080 parser prototype", child.pos);
			case CLet(_, _):
				Context.error("WPXHXX1014 let-control lowering is outside the SDK-080 parser prototype", child.pos);
		}
	}

	private function visitNode(node:Node, nodePosition:Position, context:String):Void {
		final name = node.name.value;
		if (name == "__fragment__") {
			if (node.attributes.length > 0) {
				Context.error("WPXHXX1009 fragments cannot have attributes", node.name.pos);
			}
			add("fragment", "fragment", context, "", nodePosition);
			visitChildren(node.children, '$context/fragment');
			return;
		}

		final component = componentContract(name);
		if (component != null) {
			visitComponent(component, node, nodePosition, context);
			return;
		}

		if (startsWithUppercase(name)) {
			Context.error('WPXHXX1001 unknown component <$name>', node.name.pos);
		}
		if (!isKnownElement(name)) {
			Context.error('WPXHXX1000 unknown element <$name>', node.name.pos);
		}

		add("element", name, context, "", nodePosition);
		validateAttributes(node.attributes, elementProps(name), name, nodePosition);
		visitChildren(node.children, '$context/element:$name');
	}

	private function visitComponent(component:ComponentContract, node:Node, nodePosition:Position, context:String):Void {
		if (!component.targets.contains(target)) {
			Context.error('WPXHXX1002 component <${component.name}> is not available for $target markup', node.name.pos);
		}

		add("component", component.name, context, "", nodePosition);
		validateAttributes(node.attributes, component.props, component.name, nodePosition);

		if (component.slots.length > 0) {
			visitSlots(component, node.children, nodePosition, context);
			return;
		}
		if (!component.acceptsChildren && hasMeaningfulChildren(node.children)) {
			Context.error('WPXHXX1007 component <${component.name}> does not accept children', nodePosition);
		}
		if (component.acceptsChildren) {
			visitChildren(node.children, '$context/component:${component.name}');
		}
	}

	private function visitSlots(component:ComponentContract, children:Null<Children>, nodePosition:Position, context:String):Void {
		final seen = new Map<String, Bool>();
		if (children != null) {
			for (child in children.value) {
				switch child.value {
					case CText(text) if (text.value.trim().length == 0):
					case CNode(slotNode):
						final slot = findSlot(component.slots, slotNode.name.value);
						if (slot == null) {
							Context.error('WPXHXX1005 component <${component.name}> has no named slot <${slotNode.name.value}>', slotNode.name.pos);
						}
						if (seen.exists(slot.name)) {
							Context.error('WPXHXX1006 duplicate named slot <${slot.name}> in <${component.name}>', slotNode.name.pos);
						}
						if (slotNode.attributes.length > 0) {
							Context.error('WPXHXX1010 named slot <${slot.name}> cannot have attributes', slotNode.name.pos);
						}
						seen[slot.name] = true;
						add("slot", slot.name, component.name, "", child.pos);
						visitChildren(slotNode.children, '$context/component:${component.name}/slot:${slot.name}');
					default:
						Context.error('WPXHXX1008 component <${component.name}> requires direct named-slot children', child.pos);
				}
			}
		}

		for (slot in component.slots) {
			if (slot.required && !seen.exists(slot.name)) {
				Context.error('WPXHXX1004 component <${component.name}> is missing required slot <${slot.name}>', nodePosition);
			}
		}
	}

	private function validateAttributes(attributes:Array<Attribute>, props:Array<PropContract>, owner:String, nodePosition:Position):Void {
		final explicit = new Map<String, Bool>();
		final spread = new Map<String, Bool>();
		final guaranteed = new Map<String, Bool>();

		for (attribute in attributes) {
			switch attribute {
				case Empty(name):
					final contract = requireProp(props, name.value, owner, name.pos);
					if (contract.typeName != "Bool") {
						Context.error('WPXHXX1102 empty attribute ${name.value} on <$owner> requires Bool, not ${contract.typeName}', name.pos);
					}
					requireNoExplicitDuplicate(explicit, name.value, owner, name.pos);
					diagnoseSpreadOverride(spread, name.value, owner, name.pos);
					explicit[name.value] = true;
					guaranteed[name.value] = true;
					add("attribute", name.value, owner, "Bool", name.pos);
				case Regular(name, value):
					final contract = requireProp(props, name.value, owner, name.pos);
					requireNoExplicitDuplicate(explicit, name.value, owner, name.pos);
					diagnoseSpreadOverride(spread, name.value, owner, name.pos);
					final actualType = requireType(value, contract.typeName, 'attribute ${name.value} on <$owner>');
					explicit[name.value] = true;
					guaranteed[name.value] = true;
					add("attribute", name.value, owner, actualType, value.pos);
				case Splat(value):
					final fields = requireClosedAttributeSpread(value, owner);
					add("attribute-spread", expressionIdentity(value), owner, typeName(Context.typeof(value)), value.pos);
					for (field in fields) {
						final contract = requireProp(props, field.name, owner, field.pos);
						if (!Context.unify(field.type, Context.getType(contract.typeName))) {
							Context.error('WPXHXX1101 spread field ${field.name} on <$owner> expected ${contract.typeName}, found ${typeName(field.type)}',
								field.pos);
						}
						if (explicit.exists(field.name) || spread.exists(field.name)) {
							Context.warning('WPXHXX1108 duplicate spread field ${field.name} on <$owner>; explicit attributes win', field.pos);
						}
						spread[field.name] = true;
						if (!field.meta.has(":optional")) {
							guaranteed[field.name] = true;
						}
					}
			}
		}

		for (prop in props) {
			if (prop.required && !guaranteed.exists(prop.name)) {
				Context.error('WPXHXX1003 <$owner> is missing required prop ${prop.name}:${prop.typeName}', nodePosition);
			}
		}
	}

	private function requireClosedAttributeSpread(expression:Expr, owner:String):Array<ClassField> {
		final actualType = Context.follow(Context.typeof(expression));
		return switch actualType {
			case TAnonymous(reference):
				final anonymous = reference.get();
				switch anonymous.status {
					case AClosed | AConst:
					default:
						Context.error('WPXHXX1104 attribute spread on <$owner> must be a closed structural type', expression.pos);
				}
				final fields = anonymous.fields.copy();
				fields.sort((left, right) -> Reflect.compare(left.name, right.name));
				fields;
			default:
				Context.error('WPXHXX1103 attribute spread on <$owner> must be a closed structural type, found ${typeName(actualType)}', expression.pos);
		}
	}

	private function requireClosedChildSpread(expression:Expr, context:String):String {
		final actualType = Context.follow(Context.typeof(expression));
		switch actualType {
			case TInst(reference, [elementType]) if (reference.get().pack.length == 0 && reference.get().name == "Array"):
				requireScalarType(elementType, 'child spread in $context', expression.pos);
			default:
				Context.error('WPXHXX1201 child spread in $context must be Array<String|Int|Float>, found ${typeName(actualType)}', expression.pos);
		}
		return typeName(actualType);
	}

	private function requireScalarChild(expression:Expr, context:String):String {
		final actualType = Context.typeof(expression);
		requireScalarType(actualType, 'child expression in $context', expression.pos);
		return typeName(actualType);
	}

	private function requireScalarType(type:Type, context:String, position:Position):Void {
		final normalized = typeName(type);
		if (normalized != "String" && normalized != "Int" && normalized != "Float") {
			Context.error('WPXHXX1200 $context must be String, Int, or Float, found $normalized', position);
		}
	}

	private function requireType(expression:Expr, expectedName:String, context:String):String {
		final actualType = Context.typeof(expression);
		final expectedType = Context.getType(expectedName);
		if (!Context.unify(actualType, expectedType)) {
			Context.error('WPXHXX1100 $context expected $expectedName, found ${typeName(actualType)}', expression.pos);
		}
		return typeName(actualType);
	}

	private function add(kind:String, name:String, context:String, valueType:String, sourcePosition:Position):Void {
		final entry:SnapshotEntry = {
			kind: kind,
			name: name,
			context: context,
			valueType: valueType,
			span: position(sourcePosition)
		};
		entries.push(entry);
		structure.push('$kind|$name|$context|$valueType');
	}

	private function position(sourcePosition:Position):SnapshotSpan {
		final info = Context.getPosInfos(sourcePosition);
		return {
			start: info.min - sourceBase,
			end: info.max - sourceBase
		};
	}

	private static function requireProp(props:Array<PropContract>, name:String, owner:String, position:Position):PropContract {
		for (prop in props) {
			if (prop.name == name) {
				return prop;
			}
		}
		Context.error('WPXHXX1105 unknown prop $name on <$owner>', position);
		return cast null;
	}

	private static function requireNoExplicitDuplicate(explicit:Map<String, Bool>, name:String, owner:String, position:Position):Void {
		if (explicit.exists(name)) {
			Context.error('WPXHXX1106 duplicate explicit prop $name on <$owner>', position);
		}
	}

	private static function diagnoseSpreadOverride(spread:Map<String, Bool>, name:String, owner:String, position:Position):Void {
		if (spread.exists(name)) {
			Context.warning('WPXHXX1107 explicit prop $name overrides a spread value on <$owner>', position);
		}
	}

	private static function componentContract(name:String):Null<ComponentContract> {
		return switch name {
			case "Panel":
				{
					name: "Panel",
					targets: [Server, Browser],
					props: [
						prop("title", "String", true),
						prop("count", "Int", false),
						prop("highlighted", "Bool", false)
					],
					slots: [slot("header", true), slot("body", true), slot("footer", false)],
					acceptsChildren: false
				};
			case "Inline":
				{
					name: "Inline",
					targets: [Server, Browser],
					props: [prop("label", "String", true)],
					slots: [],
					acceptsChildren: true
				};
			case "ServerFragment":
				{
					name: "ServerFragment",
					targets: [Server],
					props: [prop("token", "String", true)],
					slots: [],
					acceptsChildren: true
				};
			case "BrowserWidget":
				{
					name: "BrowserWidget",
					targets: [Browser],
					props: [prop("token", "String", true)],
					slots: [],
					acceptsChildren: true
				};
			default:
				null;
		}
	}

	private static function elementProps(name:String):Array<PropContract> {
		final props = [
			prop("id", "String", false),
			prop("class", "String", false),
			prop("hidden", "Bool", false),
			prop("aria-label", "String", false),
			prop("data-testid", "String", false)
		];
		switch name {
			case "a":
				props.push(prop("href", "String", false));
			case "img":
				props.push(prop("src", "String", true));
				props.push(prop("alt", "String", true));
			case "button":
				props.push(prop("disabled", "Bool", false));
				props.push(prop("type", "String", false));
			default:
		}
		return props;
	}

	private static function isKnownElement(name:String):Bool {
		return switch name {
			case "a" | "article" | "aside" | "body" | "br" | "button" | "div" | "footer" | "h1" | "h2" | "h3" | "header" | "img" | "li" | "main" | "nav" |
				"p" | "section" | "span" | "ul":
				true;
			default:
				false;
		}
	}

	private static function startsWithUppercase(value:String):Bool {
		return value.length > 0 && value.charAt(0) == value.charAt(0).toUpperCase();
	}

	private static function hasMeaningfulChildren(children:Null<Children>):Bool {
		if (children == null) {
			return false;
		}
		for (child in children.value) {
			switch child.value {
				case CText(text) if (text.value.trim().length == 0):
				default:
					return true;
			}
		}
		return false;
	}

	private static function findSlot(slots:Array<SlotContract>, name:String):Null<SlotContract> {
		for (slot in slots) {
			if (slot.name == name) {
				return slot;
			}
		}
		return null;
	}

	private static function prop(name:String, typeName:String, required:Bool):PropContract {
		return {name: name, typeName: typeName, required: required};
	}

	private static function slot(name:String, required:Bool):SlotContract {
		return {name: name, required: required};
	}

	private static function typeName(type:Type):String {
		return TypeTools.toString(Context.follow(type));
	}

	private static function expressionIdentity(expression:Expr):String {
		return digestIdentity(ExprTools.toString(expression));
	}

	private static function digestIdentity(value:String):String {
		return Sha256.encode(value).substr(0, 16);
	}

	private static function quote(value:String):String {
		return Json.stringify(value);
	}

	private static function serializeSpan(span:SnapshotSpan):String {
		return '{"start":${span.start},"end":${span.end}}';
	}

	private static function serializeEntry(entry:SnapshotEntry):String {
		return '{"kind":${quote(entry.kind)},' + '"name":${quote(entry.name)},' + '"context":${quote(entry.context)},' + '"type":${quote(entry.valueType)},'
			+ '"span":${serializeSpan(entry.span)}}';
	}
}
#end
