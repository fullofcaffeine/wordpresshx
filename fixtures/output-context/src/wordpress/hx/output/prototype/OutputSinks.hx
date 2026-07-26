package wordpress.hx.output.prototype;

import haxe.crypto.Sha256;
import wordpress.hx.output.prototype.Output.CompilerMarkup;
import wordpress.hx.output.prototype.Output.CssColor;
import wordpress.hx.output.prototype.Output.CssDisplay;
import wordpress.hx.output.prototype.Output.CssLength;
import wordpress.hx.output.prototype.Output.CssRule;
import wordpress.hx.output.prototype.Output.CssSelector;
import wordpress.hx.output.prototype.Output.HtmlAttribute;
import wordpress.hx.output.prototype.Output.HtmlScriptData;
import wordpress.hx.output.prototype.Output.HtmlText;
import wordpress.hx.output.prototype.Output.HtmlUrl;
import wordpress.hx.output.prototype.Output.InlineDeclaration;
import wordpress.hx.output.prototype.Output.InlineStyle;
import wordpress.hx.output.prototype.Output.JsonDocument;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.KsesHtml;
import wordpress.hx.output.prototype.Output.KsesPolicy;
import wordpress.hx.output.prototype.Output.ResolvedMarkupAttribute;
import wordpress.hx.output.prototype.Output.ResolvedMarkupNode;
import wordpress.hx.output.prototype.Output.ResolvedMarkupTag;
import wordpress.hx.output.prototype.Output.ResolvedTextAttributeName;
import wordpress.hx.output.prototype.Output.ResolvedUrlAttributeName;
import wordpress.hx.output.prototype.Output.Stylesheet;
import wordpress.hx.output.prototype.Output.StylesheetDeclaration;
import wordpress.hx.output.prototype.Output.TextareaText;

/**
	Final fixture boundary from nominal terminals to a portable native-runtime
	plan. PHP and React consume this exact plan.
**/
final class OutputSinks {
	public static function text(value:HtmlText):String {
		return value.value;
	}

	public static function attribute(value:HtmlAttribute):String {
		return value.value;
	}

	public static function textarea(value:TextareaText):String {
		return value.value;
	}

	public static function url(value:HtmlUrl):String {
		return value.value.value;
	}

	public static function richHtml<Policy>(value:KsesHtml<Policy>):RichHtmlPlan {
		return new RichHtmlPlan(value.value, value.policy.identity, value.policy.version, value.policy.nativeFunction, value.policy.canonicalDocument,
			ksesRulesJson(value.policy), ksesProtocolsJson(value.policy));
	}

	public static function restJson(value:JsonDocument):JsonPlan {
		return jsonPlan(value.schemaId, value.encoding);
	}

	public static function scriptData(value:HtmlScriptData):JsonPlan {
		return jsonPlan(value.schemaId, value.encoding);
	}

	public static function inlineStyle(value:InlineStyle):String {
		return value.declarations.map(printInlineDeclaration).join("");
	}

	public static function stylesheet(value:Stylesheet):String {
		return value.rules.map(printRule).join("");
	}

	public static function markup(value:CompilerMarkup):MarkupPlan {
		final root = lowerNode(value.ast.root);
		final canonicalAst = canonicalNode(root);
		return new MarkupPlan(value.fragmentId, value.sourceFile, value.sourceLine, value.sourceColumn, canonicalAst, Sha256.encode(canonicalAst), root);
	}

	static function jsonPlan(schemaId:String, encoding:JsonEncoding):JsonPlan {
		return switch encoding {
			case EncodedJson(value): JsonPlan.success(schemaId, value);
			case EncodingFailure(reason): JsonPlan.failure(schemaId, reason);
		};
	}

	static function ksesRulesJson<Policy>(policy:KsesPolicy<Policy>):String {
		final rules:Array<String> = [];
		if (policy.linkHref || policy.linkTitle) {
			final attributes:Array<String> = [];
			if (policy.linkHref) {
				attributes.push('"href"');
			}
			if (policy.linkTitle) {
				attributes.push('"title"');
			}
			rules.push('{"name":"a","attributes":[' + attributes.join(",") + "]}");
		}
		if (policy.paragraph) {
			rules.push('{"name":"p","attributes":[]}');
		}
		if (policy.strong) {
			rules.push('{"name":"strong","attributes":[]}');
		}
		return "[" + rules.join(",") + "]";
	}

	static function ksesProtocolsJson<Policy>(policy:KsesPolicy<Policy>):String {
		final protocols:Array<String> = [];
		if (policy.http) {
			protocols.push('"http"');
		}
		if (policy.https) {
			protocols.push('"https"');
		}
		return "[" + protocols.join(",") + "]";
	}

	static function printRule(rule:CssRule):String {
		return selectorName(rule.selector) + "{" + rule.declarations.map(printStylesheetDeclaration).join("") + "}";
	}

	static function printInlineDeclaration(declaration:InlineDeclaration):String {
		return switch declaration {
			case InlineColor(value): "color:" + colorName(value) + ";";
			case InlineBackgroundColor(value): "background-color:" + colorName(value) + ";";
			case InlineDisplay(value): "display:" + displayName(value) + ";";
			case InlineGap(value): "gap:" + lengthName(value) + ";";
		};
	}

	static function printStylesheetDeclaration(declaration:StylesheetDeclaration):String {
		return switch declaration {
			case StylesheetColor(value): "color:" + colorName(value) + ";";
			case StylesheetBackgroundColor(value): "background-color:" + colorName(value) + ";";
			case StylesheetDisplay(value): "display:" + displayName(value) + ";";
			case StylesheetGap(value): "gap:" + lengthName(value) + ";";
		};
	}

	static function colorName(value:CssColor):String {
		return switch value {
			case AccentColor: "#c43b27";
		};
	}

	static function displayName(value:CssDisplay):String {
		return switch value {
			case Block: "block";
			case Grid: "grid";
			case Flex: "flex";
			case None: "none";
		};
	}

	static function lengthName(value:CssLength):String {
		return switch value {
			case Pixels(value): value + "px";
		};
	}

	static function selectorName(selector:CssSelector):String {
		return switch selector {
			case TodoCard: ".todo-card";
			case TodoTitle: ".todo-card__title";
		};
	}

	static function lowerNode(node:ResolvedMarkupNode):MarkupPlanNode {
		return switch node {
			case Element(tag, attributes, children):
				PlannedElement(tagName(tag), attributes.map(lowerAttribute), children.map(lowerNode));
			case TextNode(value):
				PlannedText(text(value));
			case StaticText(value):
				PlannedStaticText(value);
		};
	}

	static function lowerAttribute(attribute:ResolvedMarkupAttribute):MarkupPlanAttribute {
		return switch attribute {
			case TextAttribute(name, value):
				PlannedAttribute(textAttributeName(name), OutputSinks.attribute(value));
			case UrlAttribute(name, value):
				PlannedUrl(urlAttributeName(name), url(value));
		};
	}

	static function canonicalNode(node:MarkupPlanNode):String {
		return switch node {
			case PlannedElement(tag, attributes, children):
				tag
				+ "["
				+ attributes.map(canonicalAttribute).join(",")
				+ "]("
				+ children.map(canonicalNode).join(",")
				+ ")";
			case PlannedText(_):
				"text";
			case PlannedStaticText(_):
				"static-text";
		};
	}

	static function canonicalAttribute(attribute:MarkupPlanAttribute):String {
		return switch attribute {
			case PlannedAttribute(name, _): name + ":attribute";
			case PlannedUrl(name, _): name + ":url";
		};
	}

	static function tagName(tag:ResolvedMarkupTag):String {
		return switch tag {
			case Article: "article";
			case Heading2: "h2";
			case Anchor: "a";
		};
	}

	static function textAttributeName(name:ResolvedTextAttributeName):String {
		return switch name {
			case ClassName: "class";
			case AriaLabel: "aria-label";
		};
	}

	static function urlAttributeName(name:ResolvedUrlAttributeName):String {
		return switch name {
			case Href: "href";
		};
	}
}

final class RichHtmlPlan {
	public final value:String;
	public final policyIdentity:String;
	public final policyVersion:String;
	public final nativeFunction:String;
	public final canonicalPolicy:String;
	public final rulesJson:String;
	public final protocolsJson:String;

	public function new(value:String, policyIdentity:String, policyVersion:String, nativeFunction:String, canonicalPolicy:String, rulesJson:String,
			protocolsJson:String) {
		this.value = value;
		this.policyIdentity = policyIdentity;
		this.policyVersion = policyVersion;
		this.nativeFunction = nativeFunction;
		this.canonicalPolicy = canonicalPolicy;
		this.rulesJson = rulesJson;
		this.protocolsJson = protocolsJson;
	}
}

final class JsonPlan {
	public final schemaId:String;
	public final encoded:String;
	public final failureReason:String;

	private function new(schemaId:String, encoded:String, failureReason:String) {
		this.schemaId = schemaId;
		this.encoded = encoded;
		this.failureReason = failureReason;
	}

	public static function success(schemaId:String, encoded:String):JsonPlan {
		return new JsonPlan(schemaId, encoded, "");
	}

	public static function failure(schemaId:String, reason:String):JsonPlan {
		return new JsonPlan(schemaId, "", reason);
	}
}

enum MarkupPlanAttribute {
	PlannedAttribute(name:String, value:String);
	PlannedUrl(name:String, value:String);
}

enum MarkupPlanNode {
	PlannedElement(tag:String, attributes:Array<MarkupPlanAttribute>, children:Array<MarkupPlanNode>);
	PlannedText(value:String);
	PlannedStaticText(value:String);
}

final class MarkupPlan {
	public final fragmentId:String;
	public final sourceFile:String;
	public final sourceLine:Int;
	public final sourceColumn:Int;
	public final canonicalAst:String;
	public final astSha256:String;
	public final root:MarkupPlanNode;

	public function new(fragmentId:String, sourceFile:String, sourceLine:Int, sourceColumn:Int, canonicalAst:String, astSha256:String, root:MarkupPlanNode) {
		this.fragmentId = fragmentId;
		this.sourceFile = sourceFile;
		this.sourceLine = sourceLine;
		this.sourceColumn = sourceColumn;
		this.canonicalAst = canonicalAst;
		this.astSha256 = astSha256;
		this.root = root;
	}
}
