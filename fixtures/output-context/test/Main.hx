import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.CssDeclaration;
import wordpress.hx.output.prototype.Output.CssKeyword;
import wordpress.hx.output.prototype.Output.CssProperty;
import wordpress.hx.output.prototype.Output.CssValue;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.output.prototype.Output.UrlValidation;
import wordpress.hx.output.prototype.OutputSinks;

typedef TodoCard = {
	final id:Int;
	final title:String;
}

final class TodoCardCodec implements OutputCodec<TodoCard> {
	public function new() {}

	public function schemaId():String {
		return "todo-card.v1";
	}
}

final class Main {
	static function main():Void {
		final acceptedUrl = switch Output.validateUrl("https://example.test/todos/7?mode=edit&from=hxx") {
			case AcceptedUrl(value): value;
			case RejectedUrl(reason): throw "expected accepted URL: " + reason;
		};
		final rejectedUrl = switch Output.validateUrl("javascript:alert(1)") {
			case AcceptedUrl(_): "unexpected-accept";
			case RejectedUrl(reason): reason;
		};
		final todo:TodoCard = {
			id: 7,
			title: "Ship <typed> & safe"
		};
		final todoCodec = new TodoCardCodec();

		final lines = [
			OutputSinks.text(Output.text("<script>alert('text')</script>")),
			OutputSinks.attribute(Output.attribute("\" autofocus onfocus=alert(1)")),
			OutputSinks.textarea(Output.textarea("</textarea><script>alert(1)</script>")),
			OutputSinks.url(Output.url(acceptedUrl)),
			"url-rejection|" + rejectedUrl,
			OutputSinks.richHtml(Output.postContent("<strong>allowed</strong><script>alert(1)</script>")),
			OutputSinks.richHtml(Output.dataHtml("<a href=\"https://example.test\">allowed by data policy only</a>")),
			OutputSinks.restJson(Output.jsonDocument(todoCodec, todo)),
			OutputSinks.scriptData(Output.scriptData(todoCodec, todo)),
			OutputSinks.style(Output.css([
				new CssDeclaration(Color, Token("todo-accent")),
				new CssDeclaration(Display, Keyword(Grid)),
				new CssDeclaration(Gap, Pixels(16))
			])),
			OutputSinks.markup(Output.resolvedHxxFragment("TodoCard.render@fixture"))
		];
		for (line in lines) {
			Sys.println(line);
		}
	}
}
