package wordpress.hx.i18n;

#if macro
import haxe.macro.Expr;
import wordpress.hx.i18n._internal.TranslationBuilder;
#end

/** Compile-time translation factories that preserve source placeholder contracts. */
class Translations {
	public static macro function text(message:ExprOf<TextMessage>, value:ExprOf<String>):ExprOf<MessageTranslation> {
		return TranslationBuilder.buildText(message, value);
	}

	public static macro function string(message:ExprOf<StringMessage>, value:ExprOf<String>):ExprOf<MessageTranslation> {
		return TranslationBuilder.buildString(message, value);
	}

	public static macro function plural(message:ExprOf<PluralMessage>, singular:ExprOf<String>, plural:ExprOf<String>):ExprOf<MessageTranslation> {
		return TranslationBuilder.buildPlural(message, singular, plural);
	}
}
