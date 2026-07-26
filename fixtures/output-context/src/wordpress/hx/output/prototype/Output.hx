package wordpress.hx.output.prototype;

import haxe.crypto.Sha256;

using StringTools;

/**
	Bounded ADR-012 executable type prototype.

	Terminal values retain their typed authority until OutputSinks creates a
	native-runtime plan. They expose no raw string conversion to application code.
**/
final class Output {
	public static function text(value:String):HtmlText {
		return new HtmlText(value);
	}

	public static function attribute(value:String):HtmlAttribute {
		return new HtmlAttribute(value);
	}

	public static function textarea(value:String):TextareaText {
		return new TextareaText(value);
	}

	public static function validateUrl(value:String):UrlValidation {
		if (value != value.trim() || containsWhitespaceOrControl(value)) {
			return RejectedUrl("whitespace-or-control");
		}
		final normalized = value.toLowerCase();
		if (normalized.startsWith("https://")
			|| normalized.startsWith("http://")
			|| (value.startsWith("/") && !value.startsWith("//"))
			|| value.startsWith("#")) {
			return AcceptedUrl(new ValidatedUrl(value));
		}
		return RejectedUrl("unsupported-scheme-or-shape");
	}

	public static function url(value:ValidatedUrl):HtmlUrl {
		return new HtmlUrl(value);
	}

	public static function postContent(value:String):KsesHtml<PostContentPolicy> {
		return new KsesHtml(value, new KsesPolicy("wordpress-post-content", "wp70-release", "wp_kses_post", "profile-native-filterable"));
	}

	public static function dataHtml(value:String):KsesHtml<DataHtmlPolicy> {
		return new KsesHtml(value, new KsesPolicy("wordpress-data", "wp70-release", "wp_kses_data", "profile-native-filterable"));
	}

	public static function customContent(value:String, policy:CustomKsesPolicy):KsesHtml<CustomContentPolicy> {
		return new KsesHtml(value, new KsesPolicy("custom:" + policy.digest, policy.version, "wp_kses", policy.canonicalDocument));
	}

	public static function customKsesPolicy(version:String, tags:Array<KsesTag>, protocols:Array<KsesProtocol>):CustomKsesPolicy {
		return CustomKsesPolicy.create(version, tags, protocols);
	}

	public static function jsonDocument<T>(codec:OutputCodec<T>, value:T):JsonDocument {
		return new JsonDocument(codec.schemaId(), codec.encode(value));
	}

	public static function scriptData<T>(codec:OutputCodec<T>, value:T):HtmlScriptData {
		return new HtmlScriptData(codec.schemaId(), codec.encode(value));
	}

	public static function inlineStyle(declarations:Array<CssDeclaration>):InlineStyle {
		return new InlineStyle(declarations.copy());
	}

	public static function stylesheet(rules:Array<CssRule>):Stylesheet {
		return new Stylesheet(rules.copy());
	}

	static function containsWhitespaceOrControl(value:String):Bool {
		return ~/[\x00-\x20\x7f]/.match(value);
	}
}

/** Fixture-local stand-in for ADR-009's executable `ContractCodec<T>`. **/
interface OutputCodec<T> {
	public function schemaId():String;
	public function encode(value:T):JsonEncoding;
}

enum JsonEncoding {
	EncodedJson(value:String);
	EncodingFailure(reason:String);
}

enum UrlValidation {
	AcceptedUrl(value:ValidatedUrl);
	RejectedUrl(reason:String);
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class ValidatedUrl {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

final class PostContentPolicy {}
final class DataHtmlPolicy {}
final class CustomContentPolicy {}

enum KsesAttribute {
	Href;
	Title;
}

enum KsesTag {
	Paragraph;
	Strong;
	Link(attributes:Array<KsesAttribute>);
}

enum KsesProtocol {
	Http;
	Https;
}

final class CustomKsesPolicy {
	public final version:String;
	public final canonicalDocument:String;
	public final digest:String;

	private function new(version:String, canonicalDocument:String) {
		this.version = version;
		this.canonicalDocument = canonicalDocument;
		this.digest = Sha256.encode(canonicalDocument);
	}

	public static function create(version:String, tags:Array<KsesTag>, protocols:Array<KsesProtocol>):CustomKsesPolicy {
		final tagNames = tags.map(tagName);
		final protocolNames = protocols.map(protocolName);
		tagNames.sort(compare);
		protocolNames.sort(compare);
		final canonicalDocument = "version=" + version + ";tags=" + tagNames.join(",") + ";protocols=" + protocolNames.join(",");
		return new CustomKsesPolicy(version, canonicalDocument);
	}

	static function tagName(tag:KsesTag):String {
		return switch tag {
			case Paragraph: "p";
			case Strong: "strong";
			case Link(attributes):
				final names = attributes.map(attributeName);
				names.sort(compare);
				"a[" + names.join(",") + "]";
		};
	}

	static function attributeName(attribute:KsesAttribute):String {
		return switch attribute {
			case Href: "href";
			case Title: "title";
		};
	}

	static function protocolName(protocol:KsesProtocol):String {
		return switch protocol {
			case Http: "http";
			case Https: "https";
		};
	}

	static function compare(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class KsesPolicy<Policy> {
	public final identity:String;
	public final version:String;
	public final nativeFunction:String;
	public final canonicalDocument:String;

	private function new(identity:String, version:String, nativeFunction:String, canonicalDocument:String) {
		this.identity = identity;
		this.version = version;
		this.nativeFunction = nativeFunction;
		this.canonicalDocument = canonicalDocument;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class HtmlText {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class HtmlAttribute {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class TextareaText {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class HtmlUrl {
	final value:ValidatedUrl;

	private function new(value:ValidatedUrl) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class KsesHtml<Policy> {
	final value:String;

	public final policy:KsesPolicy<Policy>;

	private function new(value:String, policy:KsesPolicy<Policy>) {
		this.value = value;
		this.policy = policy;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class JsonDocument {
	final schemaId:String;
	final encoding:JsonEncoding;

	private function new(schemaId:String, encoding:JsonEncoding) {
		this.schemaId = schemaId;
		this.encoding = encoding;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class HtmlScriptData {
	final schemaId:String;
	final encoding:JsonEncoding;

	private function new(schemaId:String, encoding:JsonEncoding) {
		this.schemaId = schemaId;
		this.encoding = encoding;
	}
}

enum CssProperty {
	Color;
	BackgroundColor;
	Display;
	Gap;
}

enum CssValue {
	AccentColor;
	Pixels(value:Int);
	Keyword(value:CssKeyword);
}

enum CssKeyword {
	Block;
	Grid;
	Flex;
	None;
}

final class CssDeclaration {
	public final property:CssProperty;
	public final value:CssValue;

	public function new(property:CssProperty, value:CssValue) {
		this.property = property;
		this.value = value;
	}
}

final class CssRule {
	public final selector:CssSelector;
	public final declarations:Array<CssDeclaration>;

	public function new(selector:CssSelector, declarations:Array<CssDeclaration>) {
		this.selector = selector;
		this.declarations = declarations.copy();
	}
}

enum CssSelector {
	TodoCard;
	TodoTitle;
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class InlineStyle {
	final declarations:Array<CssDeclaration>;

	private function new(declarations:Array<CssDeclaration>) {
		this.declarations = declarations;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
@:allow(wordpress.hx.output.prototype.OutputSinks)
final class Stylesheet {
	final rules:Array<CssRule>;

	private function new(rules:Array<CssRule>) {
		this.rules = rules;
	}
}

/**
	Compiler-owned provenance retained by a generated HXX fragment.

	Only the exact generated TodoCardMarkup class is allowed to construct it.
**/
@:allow(wordpress.hx.output.generated.TodoCardMarkup)
final class CompilerMarkup {
	public final fragmentId:String;
	public final sourceFile:String;
	public final sourceLine:Int;
	public final sourceColumn:Int;

	private function new(fragmentId:String, sourceFile:String, sourceLine:Int, sourceColumn:Int) {
		this.fragmentId = fragmentId;
		this.sourceFile = sourceFile;
		this.sourceLine = sourceLine;
		this.sourceColumn = sourceColumn;
	}
}
