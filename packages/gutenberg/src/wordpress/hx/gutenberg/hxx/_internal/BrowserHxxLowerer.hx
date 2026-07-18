package wordpress.hx.gutenberg.hxx._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import wordpress.hx.gutenberg.hxx._internal.BrowserHxxProfile.BrowserHxxComponentProfile;
import wordpress.hx.gutenberg.hxx._internal.BrowserHxxProfile.BrowserHxxProfileData;
import wordpress.hx.hxx._internal.HxxParserAdapter;
import wordpress.hx.hxx._internal.HxxSyntax.HxxSyntaxAttribute;
import wordpress.hx.hxx._internal.HxxSyntax.HxxSyntaxChild;
import wordpress.hx.hxx._internal.HxxSyntax.HxxSyntaxChildKind;
import wordpress.hx.hxx._internal.HxxSyntax.HxxSyntaxChildren;
import wordpress.hx.hxx._internal.HxxSyntax.HxxSyntaxNode;

using haxe.macro.TypeTools;
using StringTools;

private typedef PropName = {
	final haxeName:String;
	final targetName:String;
}

private typedef PropContract = {
	final name:String;
	final type:Type;
	final required:Bool;
	final pos:Position;
}

private typedef ComponentContract = {
	final displayName:String;
	final props:Array<PropContract>;
	final children:String;
}

/** Turns the neutral positioned HXX tree into Genes' runtime-free JSX intent. */
class BrowserHxxLowerer {
	public static function lower(markup:Expr):Expr {
		final profile = BrowserHxxProfile.current();
		final syntax = HxxParserAdapter.parseSyntax(markup);
		return new BrowserHxxLowerer(profile).lowerRoot(syntax);
	}

	private final profile:BrowserHxxProfileData;

	private function new(profile:BrowserHxxProfileData) {
		this.profile = profile;
	}

	private function lowerRoot(children:HxxSyntaxChildren):Expr {
		final lowered = lowerChildren(children);
		if (lowered.length == 0) {
			Context.error("WPX3203: browser HXX must produce at least one child.", children.pos);
		}
		return lowered.length == 1 ? lowered[0] : fragment(lowered, children.pos);
	}

	private function lowerChildren(children:Null<HxxSyntaxChildren>):Array<Expr> {
		if (children == null) {
			return [];
		}
		final output:Array<Expr> = [];
		for (child in children.items) {
			final lowered = lowerChild(child);
			if (lowered != null) {
				output.push(lowered);
			}
		}
		return output;
	}

	private function lowerChild(child:HxxSyntaxChild):Null<Expr> {
		return switch child.kind {
			case Node(node):
				lowerNode(node);
			case Text(value):
				value.value.length == 0 ? null : at(macro $v{value.value}, value.pos);
			case Expression(value):
				checked(value, Context.getType("wordpress.hx.gutenberg.react.ReactTypes.ReactNode"));
			case ChildSpread(value):
				validateChildSpread(value);
				value;
			case If(condition, consequent, alternative):
				lowerIf(condition, consequent, alternative, child.pos);
			case For(head, body):
				lowerFor(head, body, child.pos);
			case Switch(_, _):
				Context.error("WPX3213: switch-control browser HXX is not admitted by SDK-032.", child.pos);
			case Let(_, _):
				Context.error("WPX3214: let-control browser HXX is not admitted by SDK-032.", child.pos);
		};
	}

	private function lowerNode(node:HxxSyntaxNode):Expr {
		if (node.name.value == "__fragment__") {
			if (node.attributes.length > 0) {
				Context.error("WPX3204: browser HXX fragments cannot have attributes.", node.name.pos);
			}
			return fragment(lowerChildren(node.children), node.pos);
		}

		if (isIntrinsic(node.name.value)) {
			return lowerElement(node);
		}
		if (!startsUppercase(node.name.value)) {
			Context.error('WPX3205: unknown browser HXX intrinsic <${node.name.value}>.', node.name.pos);
		}
		return lowerComponent(node);
	}

	private function lowerElement(node:HxxSyntaxNode):Expr {
		if (isVoid(node.name.value) && hasChildren(node.children)) {
			Context.error('WPX3206: void browser HXX element <${node.name.value}> cannot have children.', node.pos);
		}
		final propsType = node.name.value == "button" ? "wordpress.hx.gutenberg.html.HtmlProps.HtmlButtonProps" : "wordpress.hx.gutenberg.html.HtmlProps";
		final contract:ComponentContract = {
			displayName: node.name.value,
			props: propsFromType(propsType, node.name.pos),
			children: isVoid(node.name.value) ? "forbidden" : "optional"
		};
		final children = lowerChildren(node.children);
		final tag = at(macro $v{node.name.value}, node.name.pos);
		return jsx(tag, lowerAttributes(node.attributes, contract, children, node.pos), children, node.pos);
	}

	private function lowerComponent(node:HxxSyntaxNode):Expr {
		final tag = try {
			Context.parse(node.name.value, node.name.pos);
		} catch (_:Dynamic) {
			Context.error('WPX3207: unknown browser HXX component <${node.name.value}>.', node.name.pos);
		}
		final tagType = try {
			Context.typeof(tag);
		} catch (_:Dynamic) {
			Context.error('WPX3207: unknown browser HXX component <${node.name.value}>.', node.name.pos);
		}
		final component = BrowserHxxProfile.component(profile, node.name.value);
		final contract = component == null ? customComponent(node.name.value, tagType, node.name.pos) : profileComponent(component, tagType, node.name.pos);
		final children = lowerChildren(node.children);
		return jsx(tag, lowerAttributes(node.attributes, contract, children, node.pos), children, node.pos);
	}

	private function profileComponent(component:BrowserHxxComponentProfile, tagType:Type, position:Position):ComponentContract {
		final identity = classIdentity(tagType);
		final renderedType = TypeTools.toString(tagType);
		if (identity != component.haxeType && renderedType != 'Class<${component.haxeType}>') {
			Context.error('WPX3208: <${component.tag}> resolved to ${identity == null ? renderedType : identity}, expected ${component.haxeType} from ${profile.profileId}.',
				position);
		}
		return {
			displayName: component.tag,
			props: propsFromType(component.propsType, position),
			children: component.children
		};
	}

	private function customComponent(name:String, tagType:Type, position:Position):ComponentContract {
		return switch Context.follow(tagType) {
			case TFun(arguments, result):
				if (!Context.unify(result, Context.getType("genes.react.Element"))) {
					Context.error('WPX3209: custom browser HXX component <$name> must return BrowserNode.', position);
				}
				switch arguments {
					case []:
						{displayName: name, props: [], children: "forbidden"};
					case [props]:
						final fields = propsFromTypeValue(props.t, name, position);
						final childField = findProp(fields, "children");
						{displayName: name, props: fields, children: childField == null ? "forbidden" : childField.required ? "required" : "optional"};
					default:
						Context.error('WPX3210: custom browser HXX component <$name> must take zero arguments or one closed props object.', position);
				}
			default:
				Context.error('WPX3207: <$name> is neither an exact-profile component nor a typed Haxe function component.', position);
		};
	}

	private function lowerAttributes(attributes:Array<HxxSyntaxAttribute>, contract:ComponentContract, children:Array<Expr>,
			nodePosition:Position):Array<Expr> {
		final spreads:Array<Expr> = [];
		final explicit:Array<Expr> = [];
		final present = new Map<String, Bool>();
		final spreadNames = new Map<String, Bool>();

		for (attribute in attributes) {
			switch attribute {
				case Spread(value):
					final fields = closedSpread(value, contract);
					for (field in fields) {
						if (!field.required) {
							continue;
						}
						present[field.name] = true;
						spreadNames[field.name] = true;
					}
					spreads.push(spreadProperty(value));
				case Empty(name):
					final resolved = propName(name.value);
					final prop = requireProp(contract, resolved.haxeName, name.pos);
					requireUnique(present, resolved.haxeName, contract.displayName, name.pos);
					if (!Context.unify(Context.getType("Bool"), prop.type)) {
						Context.error('WPX3211: empty prop ${name.value} on <${contract.displayName}> requires Bool, found ${TypeTools.toString(prop.type)}.',
							name.pos);
					}
					warnExplicitOverride(spreadNames, resolved.haxeName, contract.displayName, name.pos);
					present[resolved.haxeName] = true;
					explicit.push(property(resolved.targetName, checked(at(macro true, name.pos), prop.type), name.pos));
				case Regular(name, value):
					final resolved = propName(name.value);
					final prop = requireProp(contract, resolved.haxeName, name.pos);
					requireUnique(present, resolved.haxeName, contract.displayName, name.pos);
					warnExplicitOverride(spreadNames, resolved.haxeName, contract.displayName, name.pos);
					present[resolved.haxeName] = true;
					explicit.push(property(resolved.targetName, checked(value, prop.type), name.pos));
			}
		}

		final childrenProp = findProp(contract.props, "children");
		if (children.length > 0) {
			if (contract.children == "forbidden") {
				Context.error('WPX3212: <${contract.displayName}> does not accept children.', nodePosition);
			}
			present["children"] = true;
			if (childrenProp != null) {
				final childValue = children.length == 1 ? children[0] : fragment(children, nodePosition);
				checked(childValue, childrenProp.type);
			}
		} else if (contract.children == "required") {
			Context.error('WPX3215: <${contract.displayName}> requires children.', nodePosition);
		}

		for (prop in contract.props) {
			if (prop.name != "children" && prop.required && !present.exists(prop.name)) {
				Context.error('WPX3216: <${contract.displayName}> is missing required prop ${prop.name}:${TypeTools.toString(prop.type)}.', nodePosition);
			}
		}
		return spreads.concat(explicit);
	}

	private function closedSpread(expression:Expr, contract:ComponentContract):Array<PropContract> {
		final actual = Context.follow(Context.typeof(expression));
		final fields = switch actual {
			case TAnonymous(reference):
				final anonymous = reference.get();
				switch anonymous.status {
					case AClosed | AConst:
					default:
						Context.error('WPX3218: prop spread on <${contract.displayName}> must be a closed structural type.', expression.pos);
				}
				anonymous.fields;
			default:
				Context.error('WPX3218: prop spread on <${contract.displayName}> must be a closed structural type, found ${TypeTools.toString(actual)}.',
					expression.pos);
		};

		final output:Array<PropContract> = [];
		for (field in fields) {
			final resolved = propName(field.name);
			if (resolved.targetName != resolved.haxeName) {
				Context.error('WPX3219: aliased prop ${field.name} cannot be spread on <${contract.displayName}>; write it explicitly.', field.pos);
			}
			final expected = requireProp(contract, resolved.haxeName, field.pos);
			if (!Context.unify(field.type, expected.type)) {
				Context.error('WPX3220: spread prop ${field.name} on <${contract.displayName}> expected ${TypeTools.toString(expected.type)}, found ${TypeTools.toString(field.type)}.',
					field.pos);
			}
			output.push({
				name: field.name,
				type: field.type,
				required: !field.meta.has(":optional"),
				pos: field.pos
			});
		}
		return output;
	}

	private function lowerIf(condition:Expr, consequent:HxxSyntaxChildren, alternative:Null<HxxSyntaxChildren>, position:Position):Expr {
		final checkedCondition = checked(condition, Context.getType("Bool"));
		final yes = group(lowerChildren(consequent), consequent.pos);
		final no = alternative == null ? at(macro null, position) : group(lowerChildren(alternative), alternative.pos);
		return at(macro $checkedCondition ? $yes : $no, position);
	}

	private function lowerFor(head:Expr, body:HxxSyntaxChildren, position:Position):Expr {
		return switch head.expr {
			case EBinop(OpIn, {expr: EConst(CIdent(name))}, iterable):
				final bodyExpression = group(lowerChildren(body), body.pos);
				final mapper:Expr = {
					expr: EFunction(FArrow, {
						args: [{name: name}],
						ret: null,
						expr: {expr: EReturn(bodyExpression), pos: bodyExpression.pos}
					}),
					pos: position
				};
				final mapField:Expr = {expr: EField(iterable, "map"), pos: iterable.pos};
				{expr: ECall(mapField, [mapper]), pos: position};
			default:
				Context.error("WPX3221: browser HXX for-control requires `for (item in Array)`.", head.pos);
		};
	}

	private function validateChildSpread(expression:Expr):Void {
		final actual = Context.follow(Context.typeof(expression));
		switch actual {
			case TInst(reference, [_]) if (reference.get().pack.length == 0 && reference.get().name == "Array"):
			default:
				Context.error('WPX3222: browser HXX child spread requires Array<ReactNode>, found ${TypeTools.toString(actual)}.', expression.pos);
		}
	}

	private function propsFromType(path:String, position:Position):Array<PropContract> {
		final type = try {
			Context.getType(path);
		} catch (_:Dynamic) {
			Context.error('WPX3223: browser HXX props type ${path} is unavailable.', position);
		}
		return propsFromTypeValue(type, path, position);
	}

	private function propsFromTypeValue(type:Type, owner:String, position:Position):Array<PropContract> {
		final fields = switch Context.follow(type) {
			case TAnonymous(reference):
				reference.get().fields;
			default:
				Context.error('WPX3224: browser HXX props for ${owner} must be a closed structural type, found ${TypeTools.toString(type)}.', position);
		};
		final output = [
			for (field in fields)
				{
					name: field.name,
					type: field.type,
					required: !field.meta.has(":optional"),
					pos: field.pos
				}
		];
		output.sort((left, right) -> Reflect.compare(left.name, right.name));
		return output;
	}

	private function checked(value:Expr, expected:Type):Expr {
		final complex = expected.toComplexType();
		if (complex == null) {
			Context.error('WPX3225: browser HXX cannot express expected type ${TypeTools.toString(expected)}.', value.pos);
		}
		return {expr: ECheckType(value, complex), pos: value.pos};
	}

	private function jsx(tag:Expr, props:Array<Expr>, children:Array<Expr>, position:Position):Expr {
		final propArray = dynamicArray(props, position);
		final childArray = dynamicArray(children, position);
		return at(macro genes.react.internal.Jsx.__jsx($tag, $propArray, $childArray), position);
	}

	private function fragment(children:Array<Expr>, position:Position):Expr {
		final childArray = dynamicArray(children, position);
		return at(macro genes.react.internal.Jsx.__frag($childArray), position);
	}

	private function group(children:Array<Expr>, position:Position):Expr {
		if (children.length == 0) {
			return at(macro null, position);
		}
		return children.length == 1 ? children[0] : fragment(children, position);
	}

	private function property(name:String, value:Expr, position:Position):Expr {
		return at(macro {name: $v{name}, value: $value}, position);
	}

	private function spreadProperty(value:Expr):Expr {
		return at(macro {spread: $value}, value.pos);
	}

	private static function propName(source:String):PropName {
		return switch source {
			case "class": {haxeName: "className", targetName: "className"};
			case "for": {haxeName: "htmlFor", targetName: "htmlFor"};
			case "aria-label" | "ariaLabel": {haxeName: "ariaLabel", targetName: "aria-label"};
			case "aria-labelledby" | "ariaLabelledBy": {haxeName: "ariaLabelledBy", targetName: "aria-labelledby"};
			case "aria-describedby" | "ariaDescribedBy": {haxeName: "ariaDescribedBy", targetName: "aria-describedby"};
			case "aria-hidden" | "ariaHidden": {haxeName: "ariaHidden", targetName: "aria-hidden"};
			case "aria-live" | "ariaLive": {haxeName: "ariaLive", targetName: "aria-live"};
			case "aria-atomic" | "ariaAtomic": {haxeName: "ariaAtomic", targetName: "aria-atomic"};
			case "aria-controls" | "ariaControls": {haxeName: "ariaControls", targetName: "aria-controls"};
			case "aria-expanded" | "ariaExpanded": {haxeName: "ariaExpanded", targetName: "aria-expanded"};
			case "data-context" | "dataContext": {haxeName: "dataContext", targetName: "data-context"};
			case "data-ref-ready" | "dataRefReady": {haxeName: "dataRefReady", targetName: "data-ref-ready"};
			case "data-state" | "dataState": {haxeName: "dataState", targetName: "data-state"};
			case "data-testid" | "dataTestId": {haxeName: "dataTestId", targetName: "data-testid"};
			case value: {haxeName: value, targetName: value};
		};
	}

	private static function requireProp(contract:ComponentContract, name:String, position:Position):PropContract {
		final prop = findProp(contract.props, name);
		if (prop == null) {
			Context.error('WPX3226: unknown prop ${name} on <${contract.displayName}>.', position);
		}
		return prop;
	}

	private static function findProp(props:Array<PropContract>, name:String):Null<PropContract> {
		for (prop in props) {
			if (prop.name == name) {
				return prop;
			}
		}
		return null;
	}

	private static function requireUnique(present:Map<String, Bool>, name:String, owner:String, position:Position):Void {
		if (present.exists(name)) {
			Context.error('WPX3227: duplicate explicit prop ${name} on <${owner}>.', position);
		}
	}

	private static function warnExplicitOverride(spreads:Map<String, Bool>, name:String, owner:String, position:Position):Void {
		if (spreads.exists(name)) {
			Context.warning('WPX3228: explicit prop ${name} overrides a spread value on <${owner}>.', position);
		}
	}

	private static function classIdentity(type:Type):Null<String> {
		return switch type {
			case TAbstract(reference, parameters) if (reference.get().pack.length == 0 && reference.get().name == "Class" && parameters.length == 1):
				instanceIdentity(parameters[0]);
			case TInst(reference, parameters) if (reference.get().pack.length == 0 && reference.get().name == "Class" && parameters.length == 1):
				instanceIdentity(parameters[0]);
			case TType(_, _):
				classIdentity(Context.follow(type));
			default:
				null;
		};
	}

	private static function instanceIdentity(type:Type):Null<String> {
		return switch Context.follow(type) {
			case TInst(reference, _):
				final value = reference.get();
				value.pack.concat([value.name]).join(".");
			default:
				null;
		};
	}

	private static function isIntrinsic(name:String):Bool {
		return switch name {
			case "article" | "aside" | "br" | "button" | "div" | "footer" | "h1" | "h2" | "h3" | "header" | "li" | "main" | "nav" | "p" | "section" | "span" |
				"strong" | "style" | "ul":
				true;
			default:
				false;
		};
	}

	private static function isVoid(name:String):Bool {
		return switch name {
			case "area" | "base" | "br" | "col" | "embed" | "hr" | "img" | "input" | "link" | "meta" | "param" | "source" | "track" | "wbr":
				true;
			default:
				false;
		};
	}

	private static function startsUppercase(value:String):Bool {
		return value.length > 0 && value.charAt(0) == value.charAt(0).toUpperCase();
	}

	private static function hasChildren(children:Null<HxxSyntaxChildren>):Bool {
		return children != null && children.items.length > 0;
	}

	private static function at(expression:Expr, position:Position):Expr {
		expression.pos = position;
		return expression;
	}

	private static function dynamicArray(items:Array<Expr>, position:Position):Expr {
		final values:Expr = {expr: EArrayDecl(items), pos: position};
		return {expr: ECheckType(values, macro :Array<Dynamic>), pos: position};
	}
}
#end
