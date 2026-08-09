import wordpress.hx.output.generated.TodoCardMarkup;
import haxe.io.Bytes;
import wordpress.hx.contracts.CanonicalWireJson;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.WireJsonEncoding;
import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.CssColor;
import wordpress.hx.output.prototype.Output.CssDisplay;
import wordpress.hx.output.prototype.Output.CssLength;
import wordpress.hx.output.prototype.Output.CssRule;
import wordpress.hx.output.prototype.Output.CssSelector;
import wordpress.hx.output.prototype.Output.InlineDeclaration;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.KsesAttribute;
import wordpress.hx.output.prototype.Output.KsesProtocol;
import wordpress.hx.output.prototype.Output.KsesTag;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.output.prototype.Output.StylesheetDeclaration;
import wordpress.hx.output.prototype.Output.UrlValidation;
import wordpress.hx.output.prototype.OutputSinks;
import wordpress.hx.output.prototype.OutputSinks.JsonPlan;
import wordpress.hx.output.prototype.OutputSinks.MarkupPlanAttribute;
import wordpress.hx.output.prototype.OutputSinks.MarkupPlanNode;
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
		if (value.id <= 0) {
			return EncodingFailure("invalid-domain-id");
		}
		return EncodedValue(ObjectValue([
			{name: "id", value: IntegerValue(value.id)},
			{name: "title", value: StringValue(value.title)}
		]));
	}
}

final class DeepValueCodec implements OutputCodec<Int> {
	public function new() {}

	public function schemaId():String {
		return "deep-value.v1";
	}

	public function encode(depth:Int):JsonEncoding {
		var value:WireValue = NullValue;
		for (_ in 0...depth) {
			value = ArrayValue([value]);
		}
		return EncodedValue(value);
	}
}

final class InvalidUnicodeCodec implements OutputCodec<String> {
	public function new() {}

	public function schemaId():String {
		return "unicode-value.v1";
	}

	public function encode(value:String):JsonEncoding {
		return EncodedValue(StringValue(value));
	}
}

final class EmptyFailureCodec implements OutputCodec<String> {
	public function new() {}

	public function schemaId():String {
		return "empty-failure.v1";
	}

	public function encode(value:String):JsonEncoding {
		return EncodingFailure("");
	}
}

final class Main {
	static function main():Void {
		HxxPositionGuard.child("html", "section");
		HxxPositionGuard.attribute("html", "section", "aria-label");
		HxxPositionGuard.attribute("html", "a", "href");
		final acceptedUrl = requireAcceptedUrl("https://example.test/todos/7?mode=edit&from=hxx");
		final todo:TodoCard = {
			id: 7,
			title: '</script><script>alert("json")</script>&\''
		};
		final invalidTodo:TodoCard = {
			id: 0,
			title: "invalid-domain-value"
		};
		final todoCodec = new TodoCardCodec();
		final richPayload = '<p><strong>kept</strong><script>alert("rich")</script>'
			+ '<a href="http://example.test" title="kept-title" onmouseover="alert(2)">link</a></p>';
		final customPolicy = Output.customKsesPolicy("todo-rich.v1", [Paragraph, Strong, Link([Href, Title, Href]), Paragraph], [Http, Https, Http]);
		final restrictedPolicy = Output.customKsesPolicy("todo-rich.v2", [Paragraph, Strong, Link([Href])], [Https]);
		final inlineDeclarations = [InlineColor(AccentColor), InlineDisplay(Grid), InlineGap(Pixels(16))];
		final markup = OutputSinks.markup(TodoCardMarkup.create(Output.text('<script>alert("markup")</script>'),
			Output.attribute('todo-card" data-forged="true'), Output.url(acceptedUrl)));
		final richPlans = PlanJson.array([
			richPlan(OutputSinks.richHtml(Output.postContent(richPayload))),
			richPlan(OutputSinks.richHtml(Output.dataHtml(richPayload))),
			richPlan(OutputSinks.richHtml(Output.customContent(richPayload, customPolicy))),
			richPlan(OutputSinks.richHtml(Output.customContent(richPayload, restrictedPolicy)))
		]);
		final restJson = jsonPlan(OutputSinks.restJson(Output.jsonDocument(todoCodec, todo)));
		final scriptData = jsonPlan(OutputSinks.scriptData(Output.scriptData(todoCodec, todo)));
		final encodingFailure = jsonPlan(OutputSinks.restJson(Output.jsonDocument(todoCodec, invalidTodo)));
		final emptyFailure = jsonPlan(OutputSinks.restJson(Output.jsonDocument(new EmptyFailureCodec(), "rejected")));
		final inlineStyle = OutputSinks.inlineStyle(Output.inlineStyle(inlineDeclarations));
		final stylesheet = OutputSinks.stylesheet(Output.stylesheet([
			new CssRule(TodoCard, [StylesheetColor(AccentColor), StylesheetDisplay(Grid), StylesheetGap(Pixels(16))]),
			new CssRule(TodoTitle, [StylesheetDisplay(Block)])
		]));

		final plan = PlanJson.object([
			new JsonField("schema", PlanJson.quote("wordpresshx.output-context-runtime-plan.v3")),
			new JsonField("text", PlanJson.quote(OutputSinks.text(Output.text('<script>alert("text")</script>&"\'')))),
			new JsonField("attribute", PlanJson.quote(OutputSinks.attribute(Output.attribute('" autofocus onfocus="alert(1)" data-note="<unsafe>"')))),
			new JsonField("textarea", PlanJson.quote(OutputSinks.textarea(Output.textarea("</textarea><script>alert(\"textarea\")</script>&")))),
			new JsonField("url", PlanJson.quote(OutputSinks.url(Output.url(acceptedUrl)))),
			new JsonField("urlMatrix", urlMatrix()),
			new JsonField("richHtml", richPlans),
			new JsonField("restJson", restJson),
			new JsonField("scriptData", scriptData),
			new JsonField("encodingFailure", encodingFailure),
			new JsonField("emptyFailure", emptyFailure),
			new JsonField("controlJson", controlJson(todoCodec)),
			new JsonField("depthFailure", jsonPlan(OutputSinks.restJson(Output.jsonDocument(new DeepValueCodec(), 66)))),
			new JsonField("invalidUnicodeFailure", jsonPlan(OutputSinks.restJson(Output.jsonDocument(new InvalidUnicodeCodec(), invalidUnicode())))),
			new JsonField("inlineStyle", PlanJson.quote(inlineStyle)),
			new JsonField("stylesheet", PlanJson.quote(stylesheet)),
			new JsonField("markup", markupPlan(markup))
		]);
		#if js
		RuntimeConsole.log(plan);
		#else
		Sys.println(plan);
		#end
	}

	static function invalidUnicode():String {
		#if target.utf16
		return String.fromCharCode(0xd800);
		#else
		return Bytes.ofHex("eda080").toString();
		#end
	}

	static function controlJson(codec:TodoCardCodec):String {
		final plans:Array<String> = [];
		for (code in 0...0x20) {
			final value:TodoCard = {
				id: code + 1,
				title: "before-" + String.fromCharCode(code) + "-after"
			};
			plans.push(jsonPlan(OutputSinks.restJson(Output.jsonDocument(codec, value))));
		}
		return PlanJson.array(plans);
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
			new JsonField("canonicalPolicy", PlanJson.quote(value.canonicalPolicy)),
			new JsonField("rules", value.rulesJson),
			new JsonField("protocols", value.protocolsJson)
		]);
	}

	static function jsonPlan(value:JsonPlan):String {
		return value.fold(encoded -> PlanJson.object([
			new JsonField("schemaId", PlanJson.quote(value.schemaId)),
			new JsonField("status", PlanJson.quote("encoded")),
			new JsonField("encoded", PlanJson.quote(encoded))
		]), reason -> PlanJson.object([
			new JsonField("schemaId", PlanJson.quote(value.schemaId)),
			new JsonField("status", PlanJson.quote("rejected")),
			new JsonField("reason", PlanJson.quote(reason))
		]));
	}

	static function markupPlan(value:MarkupPlan):String {
		return PlanJson.object([
			new JsonField("fragmentId", PlanJson.quote(value.fragmentId)),
			new JsonField("sourceFile", PlanJson.quote(value.sourceFile)),
			new JsonField("sourceLine", Std.string(value.sourceLine)),
			new JsonField("sourceColumn", Std.string(value.sourceColumn)),
			new JsonField("canonicalAst", PlanJson.quote(value.canonicalAst)),
			new JsonField("astSha256", PlanJson.quote(value.astSha256)),
			new JsonField("root", markupNode(value.root))
		]);
	}

	static function markupNode(value:MarkupPlanNode):String {
		return switch value {
			case PlannedElement(tag, attributes, children):
				PlanJson.object([
					new JsonField("kind", PlanJson.quote("element")),
					new JsonField("tag", PlanJson.quote(tag)),
					new JsonField("attributes", PlanJson.array(attributes.map(markupAttribute))),
					new JsonField("children", PlanJson.array(children.map(markupNode)))
				]);
			case PlannedText(text):
				PlanJson.object([
					new JsonField("kind", PlanJson.quote("text")),
					new JsonField("value", PlanJson.quote(text))
				]);
			case PlannedStaticText(text):
				PlanJson.object([
					new JsonField("kind", PlanJson.quote("static-text")),
					new JsonField("value", PlanJson.quote(text))
				]);
		};
	}

	static function markupAttribute(value:MarkupPlanAttribute):String {
		return switch value {
			case PlannedAttribute(name, content):
				PlanJson.object([
					new JsonField("kind", PlanJson.quote("attribute")),
					new JsonField("name", PlanJson.quote(name)),
					new JsonField("value", PlanJson.quote(content))
				]);
			case PlannedUrl(name, content):
				PlanJson.object([
					new JsonField("kind", PlanJson.quote("url")),
					new JsonField("name", PlanJson.quote(name)),
					new JsonField("value", PlanJson.quote(content))
				]);
		};
	}
}

#if js
@:native("console")
private extern class RuntimeConsole {
	static function log(value:String):Void;
}
#end

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
		return switch CanonicalWireJson.encodeChecked(StringValue(value)) {
			case JsonEncoded(encoded): encoded;
			case JsonRejected(reason): throw "runtime-plan string failed JSON encoding: " + reason;
		};
	}
}
