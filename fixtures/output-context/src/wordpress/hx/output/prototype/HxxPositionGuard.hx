package wordpress.hx.output.prototype;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

using StringTools;

/**
	Bounded compile-time HXX position classifier.

	Unknown ordinary attributes remain text attributes. Nested grammars and
	executable positions fail closed until a dedicated typed terminal exists.
**/
final class HxxPositionGuard {
	public static macro function attribute(tagExpression:ExprOf<String>, attributeExpression:ExprOf<String>):Expr {
		final tag = literal(tagExpression, "HXX tag");
		final attribute = literal(attributeExpression, "HXX attribute");
		final normalizedTag = tag.toLowerCase();
		final normalizedAttribute = attribute.toLowerCase();

		if (normalizedTag == "svg" || normalizedTag == "math") {
			Context.error("HXX nested namespace attributes require a dedicated typed profile", attributeExpression.pos);
		}
		if (normalizedAttribute.startsWith("on")) {
			Context.error("HXX event attributes cannot contain server/browser string handlers", attributeExpression.pos);
		}
		switch normalizedAttribute {
			case "srcdoc":
				Context.error("HXX srcdoc is a nested HTML document and is not admitted", attributeExpression.pos);
			case "srcset":
				Context.error("HXX srcset is a URL-list grammar and is not admitted", attributeExpression.pos);
			case "style":
				Context.error("HXX style requires the typed InlineStyle terminal", attributeExpression.pos);
			case "href":
				if (normalizedTag != "a") {
					Context.error("HXX href is admitted only for the exact typed anchor URL position", attributeExpression.pos);
				}
			case "src":
				if (normalizedTag != "img") {
					Context.error("HXX src is admitted only for the exact typed image URL position", attributeExpression.pos);
				}
			case "action":
				if (normalizedTag != "form") {
					Context.error("HXX action is admitted only for the exact typed form URL position", attributeExpression.pos);
				}
			case "formaction":
				if (normalizedTag != "button" && normalizedTag != "input") {
					Context.error("HXX formaction is admitted only for exact typed submit controls", attributeExpression.pos);
				}
			default:
		}
		return macro null;
	}

	public static macro function child(tagExpression:ExprOf<String>):Expr {
		final tag = literal(tagExpression, "HXX child tag").toLowerCase();
		switch tag {
			case "script":
				Context.error("HXX script children require the typed HtmlScriptData terminal", tagExpression.pos);
			case "style":
				Context.error("HXX style children are withheld until a typed stylesheet-element contract exists", tagExpression.pos);
			case "iframe":
				Context.error("HXX iframe children are a nested document and are not admitted", tagExpression.pos);
			case "textarea":
				Context.error("HXX textarea children require the typed TextareaText terminal", tagExpression.pos);
			default:
		}
		return macro null;
	}

	#if macro
	static function literal(expression:ExprOf<String>, label:String):String {
		return switch expression.expr {
			case EConst(CString(value, _)): value;
			default:
				Context.error(label + " must be a compile-time string literal", expression.pos);
				"";
		};
	}
	#end
}
