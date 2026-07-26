package wordpress.hx.output.prototype;

import wordpress.hx.output.prototype.Output.CompilerMarkup;
import wordpress.hx.output.prototype.Output.CssDeclaration;
import wordpress.hx.output.prototype.Output.CssKeyword;
import wordpress.hx.output.prototype.Output.CssProperty;
import wordpress.hx.output.prototype.Output.CssRule;
import wordpress.hx.output.prototype.Output.CssSelector;
import wordpress.hx.output.prototype.Output.CssValue;
import wordpress.hx.output.prototype.Output.HtmlAttribute;
import wordpress.hx.output.prototype.Output.HtmlScriptData;
import wordpress.hx.output.prototype.Output.HtmlText;
import wordpress.hx.output.prototype.Output.HtmlUrl;
import wordpress.hx.output.prototype.Output.InlineStyle;
import wordpress.hx.output.prototype.Output.JsonDocument;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.KsesHtml;
import wordpress.hx.output.prototype.Output.Stylesheet;
import wordpress.hx.output.prototype.Output.TextareaText;

/**
	Final fixture boundary from nominal terminals to a portable native-runtime
	plan. PHP and React consume this exact plan; they no longer use independent
	handwritten payloads.
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
		return new RichHtmlPlan(value.value, value.policy.identity, value.policy.version, value.policy.nativeFunction, value.policy.canonicalDocument);
	}

	public static function restJson(value:JsonDocument):JsonPlan {
		return jsonPlan(value.schemaId, value.encoding);
	}

	public static function scriptData(value:HtmlScriptData):JsonPlan {
		return jsonPlan(value.schemaId, value.encoding);
	}

	public static function inlineStyle(value:InlineStyle):String {
		return printDeclarations(value.declarations);
	}

	public static function stylesheet(value:Stylesheet):String {
		return value.rules.map(printRule).join("");
	}

	public static function markup(value:CompilerMarkup):MarkupPlan {
		return new MarkupPlan(value.fragmentId, value.sourceFile, value.sourceLine, value.sourceColumn);
	}

	static function jsonPlan(schemaId:String, encoding:JsonEncoding):JsonPlan {
		return switch encoding {
			case EncodedJson(value): JsonPlan.success(schemaId, value);
			case EncodingFailure(reason): JsonPlan.failure(schemaId, reason);
		};
	}

	static function printRule(rule:CssRule):String {
		return selectorName(rule.selector) + "{" + printDeclarations(rule.declarations) + "}";
	}

	static function printDeclarations(declarations:Array<CssDeclaration>):String {
		return declarations.map(printDeclaration).join("");
	}

	static function printDeclaration(declaration:CssDeclaration):String {
		return propertyName(declaration.property) + ":" + valueName(declaration.value) + ";";
	}

	static function propertyName(property:CssProperty):String {
		return switch property {
			case Color: "color";
			case BackgroundColor: "background-color";
			case Display: "display";
			case Gap: "gap";
		};
	}

	static function valueName(value:CssValue):String {
		return switch value {
			case AccentColor: "#c43b27";
			case Pixels(value): value + "px";
			case Keyword(value):
				switch value {
					case Block: "block";
					case Grid: "grid";
					case Flex: "flex";
					case None: "none";
				};
		};
	}

	static function selectorName(selector:CssSelector):String {
		return switch selector {
			case TodoCard: ".todo-card";
			case TodoTitle: ".todo-card__title";
		};
	}
}

final class RichHtmlPlan {
	public final value:String;
	public final policyIdentity:String;
	public final policyVersion:String;
	public final nativeFunction:String;
	public final canonicalPolicy:String;

	public function new(value:String, policyIdentity:String, policyVersion:String, nativeFunction:String, canonicalPolicy:String) {
		this.value = value;
		this.policyIdentity = policyIdentity;
		this.policyVersion = policyVersion;
		this.nativeFunction = nativeFunction;
		this.canonicalPolicy = canonicalPolicy;
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

final class MarkupPlan {
	public final fragmentId:String;
	public final sourceFile:String;
	public final sourceLine:Int;
	public final sourceColumn:Int;

	public function new(fragmentId:String, sourceFile:String, sourceLine:Int, sourceColumn:Int) {
		this.fragmentId = fragmentId;
		this.sourceFile = sourceFile;
		this.sourceLine = sourceLine;
		this.sourceColumn = sourceColumn;
	}
}
