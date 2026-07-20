package wordpress.hx.output.prototype;

using StringTools;

/**
	Bounded ADR-012 type prototype.

	These values represent terminal output plans. They deliberately expose no raw
	string conversion and cannot be constructed outside this module. Production
	SDK types and emitters remain owned by SDK-052.
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
		if (value.startsWith("https://")
			|| value.startsWith("http://")
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
		return new KsesHtml(value, new KsesPolicy("wordpress-post-content", "wp70-release", "profile-native-filterable", "wp_kses_post"));
	}

	public static function dataHtml(value:String):KsesHtml<DataHtmlPolicy> {
		return new KsesHtml(value, new KsesPolicy("wordpress-data", "wp70-release", "profile-native-filterable", "wp_kses_data"));
	}

	public static function jsonDocument<T>(codec:OutputCodec<T>, value:T):JsonDocument<T> {
		return new JsonDocument(codec.schemaId(), value);
	}

	public static function scriptData<T>(codec:OutputCodec<T>, value:T):HtmlScriptData<T> {
		return new HtmlScriptData(codec.schemaId(), value);
	}

	public static function css(declarations:Array<CssDeclaration>):CssDeclarations {
		return new CssDeclarations(declarations.copy());
	}

	/** Compiler-only evidence hook: it accepts an identity, never raw markup. **/
	public static function resolvedHxxFragment(fragmentId:String):CompilerMarkup {
		return new CompilerMarkup(fragmentId);
	}

	static function containsWhitespaceOrControl(value:String):Bool {
		return ~/[\x00-\x20\x7f]/.match(value);
	}
}

/** Fixture-local stand-in for the ADR-009 `ContractCodec<T>` authority. **/
interface OutputCodec<T> {
	public function schemaId():String;
}

enum UrlValidation {
	AcceptedUrl(value:ValidatedUrl);
	RejectedUrl(reason:String);
}

@:allow(wordpress.hx.output.prototype.Output)
final class ValidatedUrl {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

final class PostContentPolicy {}
final class DataHtmlPolicy {}

@:allow(wordpress.hx.output.prototype.Output)
final class KsesPolicy<Policy> {
	public final identity:String;
	public final version:String;
	public final descriptor:String;
	public final nativeFunction:String;

	private function new(identity:String, version:String, descriptor:String, nativeFunction:String) {
		this.identity = identity;
		this.version = version;
		this.descriptor = descriptor;
		this.nativeFunction = nativeFunction;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class HtmlText {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class HtmlAttribute {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class TextareaText {
	final value:String;

	private function new(value:String) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class HtmlUrl {
	final value:ValidatedUrl;

	private function new(value:ValidatedUrl) {
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class KsesHtml<Policy> {
	final value:String;

	public final policy:KsesPolicy<Policy>;

	private function new(value:String, policy:KsesPolicy<Policy>) {
		this.value = value;
		this.policy = policy;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class JsonDocument<T> {
	public final schemaId:String;

	final value:T;

	private function new(schemaId:String, value:T) {
		this.schemaId = schemaId;
		this.value = value;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class HtmlScriptData<T> {
	public final schemaId:String;

	final value:T;

	private function new(schemaId:String, value:T) {
		this.schemaId = schemaId;
		this.value = value;
	}
}

enum CssProperty {
	Color;
	BackgroundColor;
	Display;
	Gap;
}

enum CssValue {
	Token(name:String);
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

@:allow(wordpress.hx.output.prototype.Output)
final class CssDeclarations {
	final declarations:Array<CssDeclaration>;

	private function new(declarations:Array<CssDeclaration>) {
		this.declarations = declarations;
	}
}

@:allow(wordpress.hx.output.prototype.Output)
final class CompilerMarkup {
	public final fragmentId:String;

	private function new(fragmentId:String) {
		this.fragmentId = fragmentId;
	}
}
