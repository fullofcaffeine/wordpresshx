package wordpress.hx.output.generated;

import wordpress.hx.output.prototype.Output.CompilerMarkup;
import wordpress.hx.output.prototype.Output.HtmlAttribute;
import wordpress.hx.output.prototype.Output.HtmlText;
import wordpress.hx.output.prototype.Output.HtmlUrl;
import wordpress.hx.output.prototype.Output.ResolvedHxxAst;
import wordpress.hx.output.prototype.Output.ResolvedMarkupAttribute;
import wordpress.hx.output.prototype.Output.ResolvedMarkupNode;
import wordpress.hx.output.prototype.Output.ResolvedMarkupTag;
import wordpress.hx.output.prototype.Output.ResolvedTextAttributeName;
import wordpress.hx.output.prototype.Output.ResolvedUrlAttributeName;

/**
	Fixture stand-in for a compiler-generated HXX fragment.

	Application code can request this exact fragment but cannot manufacture a
	different fragment identity or source location.
**/
final class TodoCardMarkup {
	public static function create(title:HtmlText, label:HtmlAttribute, detailsUrl:HtmlUrl):CompilerMarkup {
		final root = Element(Article, [TextAttribute(ClassName, label)], [
			Element(Heading2, [], [TextNode(title)]),
			Element(Anchor, [UrlAttribute(Href, detailsUrl)], [StaticText("Open todo")])
		]);
		return new CompilerMarkup("TodoCard.render@fixture", "fixtures/output-context/test/Main.hx", 70, 41, new ResolvedHxxAst(root));
	}
}
