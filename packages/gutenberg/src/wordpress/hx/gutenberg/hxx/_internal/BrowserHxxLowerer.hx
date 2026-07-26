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

/**
 * One validated property before it becomes Genes' typed linked carrier.
 *
 * Why: the former `Array<Expr>` representation mirrored Genes 1.36's
 * heterogeneous runtime marker array and forced generated `any[]` locals.
 * Keeping names and spreads distinct here lets every value retain its own Haxe
 * type when the carrier is constructed.
 *
 * What/How: `NamedProperty` stores the target JSX name, checked value, and
 * authored position; `SpreadProperty` stores one already-validated closed
 * object. `propertyCarrier` later folds these values right-to-left into the
 * generic Genes 1.37 protocol without reflection, casts, or weak containers.
 */
private enum BrowserHxxProperty {
	NamedProperty(name:String, value:Expr, position:Position);
	SpreadProperty(value:Expr);
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
		final lowered:Array<Expr> = [];
		for (child in children.items) {
			final expression = lowerChild(child, children.items.length != 1);
			if (expression != null) {
				lowered.push(expression);
			}
		}
		if (lowered.length == 0) {
			Context.error("WPX3203: browser HXX must produce at least one child.", children.pos);
		}
		return lowered.length == 1 ? lowered[0] : fragment(lowered, children.pos, false);
	}

	private function lowerChildren(children:Null<HxxSyntaxChildren>):Array<Expr> {
		if (children == null) {
			return [];
		}
		final output:Array<Expr> = [];
		for (child in children.items) {
			final lowered = lowerChild(child, true);
			if (lowered != null) {
				output.push(lowered);
			}
		}
		return output;
	}

	private function lowerChild(child:HxxSyntaxChild, hxxNestedChild:Bool):Null<Expr> {
		return switch child.kind {
			case Node(node):
				lowerNode(node, hxxNestedChild);
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

	private function lowerNode(node:HxxSyntaxNode, hxxNestedChild:Bool):Expr {
		if (node.name.value == "__fragment__") {
			if (node.attributes.length > 0) {
				Context.error("WPX3204: browser HXX fragments cannot have attributes.", node.name.pos);
			}
			return fragment(lowerChildren(node.children), node.pos, hxxNestedChild);
		}

		if (isIntrinsic(node.name.value)) {
			return lowerElement(node, hxxNestedChild);
		}
		if (!startsUppercase(node.name.value)) {
			Context.error('WPX3205: unknown browser HXX intrinsic <${node.name.value}>.', node.name.pos);
		}
		return lowerComponent(node, hxxNestedChild);
	}

	private function lowerElement(node:HxxSyntaxNode, hxxNestedChild:Bool):Expr {
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
		return jsx(tag, lowerAttributes(node.attributes, contract, children, node.pos), children, node.pos, hxxNestedChild);
	}

	private function lowerComponent(node:HxxSyntaxNode, hxxNestedChild:Bool):Expr {
		final tag = try {
			Context.parse(node.name.value, node.name.pos);
		} catch (_:haxe.Exception) {
			Context.error('WPX3207: unknown browser HXX component <${node.name.value}>.', node.name.pos);
		}
		final tagType = try {
			Context.typeof(tag);
		} catch (_:haxe.Exception) {
			Context.error('WPX3207: unknown browser HXX component <${node.name.value}>.', node.name.pos);
		}
		final component = BrowserHxxProfile.component(profile, node.name.value);
		final contract = component == null ? customComponent(node.name.value, tagType, node.name.pos) : profileComponent(component, tagType, node.name.pos);
		final children = lowerChildren(node.children);
		return jsx(tag, lowerAttributes(node.attributes, contract, children, node.pos), children, node.pos, hxxNestedChild);
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
				final browserNode = Context.getType("genes.react.Element");
				final reactNode = Context.getType("wordpress.hx.gutenberg.react.ReactTypes.ReactNode");
				if (!Context.unify(result, browserNode) && !Context.unify(result, reactNode)) {
					Context.error('WPX3209: custom browser HXX component <$name> must return BrowserNode or ReactNode.', position);
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
			nodePosition:Position):Array<BrowserHxxProperty> {
		final spreads:Array<BrowserHxxProperty> = [];
		final explicit:Array<BrowserHxxProperty> = [];
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
					spreads.push(SpreadProperty(value));
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
					explicit.push(NamedProperty(resolved.targetName, checked(at(macro true, name.pos), prop.type, !prop.required), name.pos));
				case Regular(name, value):
					final resolved = propName(name.value);
					final prop = requireProp(contract, resolved.haxeName, name.pos);
					requireUnique(present, resolved.haxeName, contract.displayName, name.pos);
					warnExplicitOverride(spreadNames, resolved.haxeName, contract.displayName, name.pos);
					present[resolved.haxeName] = true;
					explicit.push(NamedProperty(resolved.targetName, checked(value, prop.type, !prop.required), name.pos));
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
				checked(childValue, childrenProp.type, !childrenProp.required);
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
		} catch (_:haxe.Exception) {
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
		output.sort((left, right) -> compareText(left.name, right.name));
		return output;
	}

	/**
	 * Applies the supplied-property type rather than the omission wrapper.
	 *
	 * Haxe represents an optional structural field as `Null<T>` while retaining
	 * `@:optional` separately. That outer `Null` means the field may be absent;
	 * it does not permit an authored `null` value. Genes 1.37 correctly checks
	 * those states separately, so the expression must be contextualized as `T`.
	 * A required field, including one explicitly declared `Null<T>`, keeps its
	 * complete original type.
	 */
	private function checked(value:Expr, expected:Type, optionalField:Bool = false):Expr {
		final suppliedType = optionalField ? withoutOptionalNull(expected) : expected;
		final complex = suppliedType.toComplexType();
		if (complex == null) {
			Context.error('WPX3225: browser HXX cannot express expected type ${TypeTools.toString(suppliedType)}.', value.pos);
		}
		final normalized = normalizeKnownLiteral(value, suppliedType);
		return {expr: ECheckType(normalized, complex), pos: value.pos};
	}

	/**
	 * Keeps standard HTML string syntax while producing a precise Haxe value.
	 *
	 * A raw String cannot inhabit the closed `HtmlButtonType` union. Rewriting
	 * only its three admitted literals gives authors ordinary `type="button"`
	 * markup while invalid literals and broad String variables still fail in
	 * Haxe before TypeScript exists.
	 */
	private static function normalizeKnownLiteral(value:Expr, expected:Type):Expr {
		return switch [abstractTypeIdentity(expected), value.expr] {
			case ["wordpress.hx.gutenberg.html.HtmlButtonType", EConst(CString("button", _))]:
				at(macro {
					final htmlButtonType:wordpress.hx.gutenberg.html.HtmlButtonType = wordpress.hx.gutenberg.html.HtmlButtonType.Button;
					htmlButtonType;
				}, value.pos);
			case ["wordpress.hx.gutenberg.html.HtmlButtonType", EConst(CString("submit", _))]:
				at(macro {
					final htmlButtonType:wordpress.hx.gutenberg.html.HtmlButtonType = wordpress.hx.gutenberg.html.HtmlButtonType.Submit;
					htmlButtonType;
				}, value.pos);
			case ["wordpress.hx.gutenberg.html.HtmlButtonType", EConst(CString("reset", _))]:
				at(macro {
					final htmlButtonType:wordpress.hx.gutenberg.html.HtmlButtonType = wordpress.hx.gutenberg.html.HtmlButtonType.Reset;
					htmlButtonType;
				}, value.pos);
			case ["wordpress.hx.gutenberg.html.HtmlButtonType", EConst(CString(invalid, _))]:
				Context.error('WPX3229: native button type "$invalid" must be button, submit, or reset.', value.pos);
			default:
				value;
		};
	}

	private static function abstractTypeIdentity(type:Type):Null<String> {
		return switch type {
			case TAbstract(reference, _):
				final value = reference.get();
				value.pack.concat([value.name]).join(".");
			case TLazy(resolve):
				abstractTypeIdentity(resolve());
			case TType(_, _):
				abstractTypeIdentity(Context.follow(type));
			default:
				null;
		};
	}

	private static function withoutOptionalNull(type:Type):Type {
		return switch type {
			case TAbstract(reference, [inner]) if (reference.get().pack.length == 0 && reference.get().name == "Null"):
				inner;
			case TLazy(resolve):
				withoutOptionalNull(resolve());
			default:
				type;
		};
	}

	/**
	 * Emits one checked element through Genes' generic linked carrier protocol.
	 *
	 * Why: nested parser-owned markup may be safely inlined by Genes only when
	 * the marker records that ownership. The root marker remains ordinary
	 * authored JSX intent, while nested markers use the dedicated HXX identity.
	 *
	 * What/How: property and child carriers preserve each expression's concrete
	 * Haxe type. Genes validates the complete marker plan before choosing TSX,
	 * JSX, typed `createElement`, or classic JavaScript output.
	 */
	private function jsx(tag:Expr, props:Array<BrowserHxxProperty>, children:Array<Expr>, position:Position, hxxNestedChild:Bool):Expr {
		final properties = propertyCarrier(props, position);
		final childValues = childrenCarrier(children, position);
		final marker = hxxNestedChild ? macro genes.react.internal.Jsx.__hxxChildJsx($tag, $properties,
			$childValues) : macro genes.react.internal.Jsx.__jsx($tag, $properties, $childValues);
		return at(marker, position);
	}

	private function fragment(children:Array<Expr>, position:Position, hxxNestedChild:Bool = true):Expr {
		final childValues = childrenCarrier(children, position);
		final marker = hxxNestedChild ? macro genes.react.internal.Jsx.__hxxChildFrag($childValues) : macro genes.react.internal.Jsx.__frag($childValues);
		return at(marker, position);
	}

	private function group(children:Array<Expr>, position:Position):Expr {
		if (children.length == 0) {
			return at(macro null, position);
		}
		return children.length == 1 ? children[0] : fragment(children, position);
	}

	/**
	 * Folds validated properties into the immutable Genes marker shape.
	 *
	 * Building from the end preserves authored order in the forward linked
	 * chain. Every record is structurally distinct, so a String property and a
	 * callback property never need a shared weak array element type.
	 */
	private function propertyCarrier(properties:Array<BrowserHxxProperty>, position:Position):Expr {
		var carrier = at(macro {__genesJsxPropsEnd: true}, position);
		var index = properties.length;
		while (index > 0) {
			index--;
			switch properties[index] {
				case NamedProperty(name, value, propertyPosition):
					carrier = at(macro {
						__genesJsxPropName: $v{name},
						__genesJsxPropValue: $value,
						__genesJsxPropNext: $carrier
					}, propertyPosition);
				case SpreadProperty(value):
					carrier = at(macro {
						__genesJsxSpreadValue: $value,
						__genesJsxPropNext: $carrier
					}, value.pos);
			}
		}
		return carrier;
	}

	/**
	 * Folds children into typed links while retaining their source positions.
	 *
	 * Genes may keep or safely inline a child link, but either choice reads the
	 * same checked value exactly once and in source order.
	 */
	private function childrenCarrier(children:Array<Expr>, position:Position):Expr {
		var carrier = at(macro {__genesJsxChildrenEnd: true}, position);
		var index = children.length;
		while (index > 0) {
			index--;
			final child = children[index];
			carrier = at(macro {
				__genesJsxChildValue: $child,
				__genesJsxChildNext: $carrier
			}, child.pos);
		}
		return carrier;
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

	private static function compareText(left:String, right:String):Int {
		return left == right ? 0 : left < right ? -1 : 1;
	}
}
#end
