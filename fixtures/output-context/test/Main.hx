import wordpress.hx.output.generated.TodoCardMarkup;
import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.CssDeclaration;
import wordpress.hx.output.prototype.Output.CssKeyword;
import wordpress.hx.output.prototype.Output.CssProperty;
import wordpress.hx.output.prototype.Output.CssRule;
import wordpress.hx.output.prototype.Output.CssSelector;
import wordpress.hx.output.prototype.Output.CssValue;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.KsesAttribute;
import wordpress.hx.output.prototype.Output.KsesProtocol;
import wordpress.hx.output.prototype.Output.KsesTag;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.output.prototype.Output.UrlValidation;
import wordpress.hx.output.prototype.OutputSinks;
import wordpress.hx.output.prototype.OutputSinks.JsonPlan;
import wordpress.hx.output.prototype.OutputSinks.MarkupPlan;
import wordpress.hx.output.prototype.OutputSinks.RichHtmlPlan;
import wordpress.hx.output.prototype.HxxPositionGuard;

using StringTools;

typedef TodoCard = {
	final id:Int;
	final title:String;
}

final class TodoCardCodec implements OutputCodec<TodoCard> {
	public function new() {}

	public function schemaId():String {
		return "todo-card.v1";
	}

	public function encode(value:TodoCard):JsonEncoding {
		if (value.title.indexOf("\x00") >= 0) {
			return EncodingFailure("invalid-control-character");
		}
		return EncodedJson(PlanJson.object([
			new JsonField("id", Std.string(value.id)),
			new JsonField("title", PlanJson.quote(value.title))
		]));
	}
}

final class Main {
	static function main():Void {
		HxxPositionGuard.child("section");
		HxxPositionGuard.attribute("section", "aria-label");
		HxxPositionGuard.attribute("a", "href");
		final acceptedUrl = requireAcceptedUrl("https://example.test/todos/7?mode=edit&from=hxx");
		final todo:TodoCard = {
			id: 7,
			title: '</script><script>alert("json")</script>&\''
		};
		final invalidTodo:TodoCard = {
			id: 8,
			title: "invalid\x00title"
		};
		final todoCodec = new TodoCardCodec();
		final richPayload = '<p><strong>kept</strong><script>alert("rich")</script>' + '<a href="javascript:alert(1)" onmouseover="alert(2)">link</a></p>';
		final customPolicy = Output.customKsesPolicy("todo-rich.v1", [Paragraph, Strong, Link([Href, Title])], [Http, Https]);
		final inlineDeclarations = [
			new CssDeclaration(Color, AccentColor),
			new CssDeclaration(Display, Keyword(Grid)),
			new CssDeclaration(Gap, Pixels(16))
		];
		final markup = OutputSinks.markup(TodoCardMarkup.create());
		final richPlans = PlanJson.array([
			richPlan(OutputSinks.richHtml(Output.postContent(richPayload))),
			richPlan(OutputSinks.richHtml(Output.dataHtml(richPayload))),
			richPlan(OutputSinks.richHtml(Output.customContent(richPayload, customPolicy)))
		]);
		final restJson = jsonPlan(OutputSinks.restJson(Output.jsonDocument(todoCodec, todo)));
		final scriptData = jsonPlan(OutputSinks.scriptData(Output.scriptData(todoCodec, todo)));
		final encodingFailure = jsonPlan(OutputSinks.restJson(Output.jsonDocument(todoCodec, invalidTodo)));
		final inlineStyle = OutputSinks.inlineStyle(Output.inlineStyle(inlineDeclarations));
		final stylesheet = OutputSinks.stylesheet(Output.stylesheet([
			new CssRule(TodoCard, inlineDeclarations),
			new CssRule(TodoTitle, [new CssDeclaration(Display, Keyword(Block))])
		]));

		Sys.println(PlanJson.object([
			new JsonField("schema", PlanJson.quote("wordpresshx.output-context-runtime-plan.v2")),
			new JsonField("text", PlanJson.quote(OutputSinks.text(Output.text('<script>alert("text")</script>&"\'')))),
			new JsonField("attribute", PlanJson.quote(OutputSinks.attribute(Output.attribute('" autofocus onfocus="alert(1)" data-note="<unsafe>"')))),
			new JsonField("textarea", PlanJson.quote(OutputSinks.textarea(Output.textarea("</textarea><script>alert(\"textarea\")</script>&")))),
			new JsonField("url", PlanJson.quote(OutputSinks.url(Output.url(acceptedUrl)))),
			new JsonField("urlMatrix", urlMatrix()),
			new JsonField("richHtml", richPlans),
			new JsonField("restJson", restJson),
			new JsonField("scriptData", scriptData),
			new JsonField("encodingFailure", encodingFailure),
			new JsonField("inlineStyle", PlanJson.quote(inlineStyle)),
			new JsonField("stylesheet", PlanJson.quote(stylesheet)),
			new JsonField("markup", markupPlan(markup))
		]));
	}

	static function requireAcceptedUrl(value:String):wordpress.hx.output.prototype.Output.ValidatedUrl {
		return switch Output.validateUrl(value) {
			case AcceptedUrl(validated): validated;
			case RejectedUrl(reason): throw "expected accepted URL: " + reason;
		};
	}

	static function urlMatrix():String {
		return PlanJson.object([
			urlCase("https", "https://example.test/path"),
			urlCase("schemeCase", "HTTPS://example.test/path"),
			urlCase("relative", "/todos/7?mode=edit&from=hxx"),
			urlCase("fragment", "#todo-7"),
			urlCase("javascript", "javascript:alert(1)"),
			urlCase("schemeWhitespace", "java\tscript:alert(1)"),
			urlCase("protocolRelative", "//evil.example/path"),
			urlCase("data", "data:text/html,<script>alert(1)</script>")
		]);
	}

	static function urlCase(name:String, value:String):JsonField {
		return switch Output.validateUrl(value) {
			case AcceptedUrl(validated):
				new JsonField(name, PlanJson.object([
					new JsonField("input", PlanJson.quote(value)),
					new JsonField("accepted", "true"),
					new JsonField("value", PlanJson.quote(OutputSinks.url(Output.url(validated))))
				]));
			case RejectedUrl(reason):
				new JsonField(name, PlanJson.object([
					new JsonField("input", PlanJson.quote(value)),
					new JsonField("accepted", "false"),
					new JsonField("reason", PlanJson.quote(reason))
				]));
		};
	}

	static function richPlan(value:RichHtmlPlan):String {
		return PlanJson.object([
			new JsonField("value", PlanJson.quote(value.value)),
			new JsonField("policyIdentity", PlanJson.quote(value.policyIdentity)),
			new JsonField("policyVersion", PlanJson.quote(value.policyVersion)),
			new JsonField("nativeFunction", PlanJson.quote(value.nativeFunction)),
			new JsonField("canonicalPolicy", PlanJson.quote(value.canonicalPolicy))
		]);
	}

	static function jsonPlan(value:JsonPlan):String {
		return PlanJson.object([
			new JsonField("schemaId", PlanJson.quote(value.schemaId)),
			new JsonField("encoded", PlanJson.quote(value.encoded)),
			new JsonField("failureReason", PlanJson.quote(value.failureReason))
		]);
	}

	static function markupPlan(value:MarkupPlan):String {
		return PlanJson.object([
			new JsonField("fragmentId", PlanJson.quote(value.fragmentId)),
			new JsonField("sourceFile", PlanJson.quote(value.sourceFile)),
			new JsonField("sourceLine", Std.string(value.sourceLine)),
			new JsonField("sourceColumn", Std.string(value.sourceColumn))
		]);
	}
}

final class JsonField {
	public final name:String;
	public final encodedValue:String;

	public function new(name:String, encodedValue:String) {
		this.name = name;
		this.encodedValue = encodedValue;
	}
}

final class PlanJson {
	public static function object(fields:Array<JsonField>):String {
		return "{" + fields.map(field -> quote(field.name) + ":" + field.encodedValue).join(",") + "}";
	}

	public static function array(values:Array<String>):String {
		return "[" + values.join(",") + "]";
	}

	public static function quote(value:String):String {
		final escaped = value.replace("\\", "\\\\")
			.replace("\"", "\\\"")
			.replace("\x08", "\\b")
			.replace("\x0c", "\\f")
			.replace("\n", "\\n")
			.replace("\r", "\\r")
			.replace("\t", "\\t");
		return '"' + escaped + '"';
	}
}
