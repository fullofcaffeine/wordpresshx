package wordpress.hx.output.prototype;

import wordpress.hx.output.prototype.Output.CompilerMarkup;
import wordpress.hx.output.prototype.Output.CssDeclarations;
import wordpress.hx.output.prototype.Output.HtmlAttribute;
import wordpress.hx.output.prototype.Output.HtmlScriptData;
import wordpress.hx.output.prototype.Output.HtmlText;
import wordpress.hx.output.prototype.Output.HtmlUrl;
import wordpress.hx.output.prototype.Output.JsonDocument;
import wordpress.hx.output.prototype.Output.KsesHtml;
import wordpress.hx.output.prototype.Output.TextareaText;

/** Exact-context sinks used to prove that terminal values do not interchange. **/
final class OutputSinks {
	public static function text(value:HtmlText):String {
		return "html-text|server=esc_html|browser=react-child-auto-escape";
	}

	public static function attribute(value:HtmlAttribute):String {
		return "html-attribute|server=esc_attr|browser=react-attribute-auto-escape";
	}

	public static function textarea(value:TextareaText):String {
		return "html-textarea|server=esc_textarea|browser=react-textarea-value";
	}

	public static function url(value:HtmlUrl):String {
		return "html-url|server=esc_url|browser=validated-url-plus-react-attribute";
	}

	public static function richHtml<Policy>(value:KsesHtml<Policy>):String {
		return "rich-html|server=" + value.policy.nativeFunction + "|policy=" + value.policy.identity + "|version=" + value.policy.version + "|descriptor="
			+ value.policy.descriptor + "|browser=policy-proof-required";
	}

	public static function restJson<T>(value:JsonDocument<T>):String {
		return "json-document|server=wp_json_encode-with-failure|schema=" + value.schemaId + "|browser=JSON-stringify-codec";
	}

	public static function scriptData<T>(value:HtmlScriptData<T>):String {
		return "html-script-data|server=wp_json_encode-hex-flags|schema=" + value.schemaId + "|browser=non-html-string-sink";
	}

	public static function style(value:CssDeclarations):String {
		return "css-declarations|server=typed-property-printer-plus-esc_attr|browser=typed-style-object";
	}

	public static function markup(value:CompilerMarkup):String {
		return "compiler-markup|fragment=" + value.fragmentId + "|server=static-html-plus-contextual-segments|browser=typed-hxx";
	}
}
