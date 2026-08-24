package wordpress.hx.i18n._internal;

import wordpress.hx.i18n.MessageTranslation;
import wordpress.hx.i18n.PluralMessage;
import wordpress.hx.i18n.StringMessage;
import wordpress.hx.i18n.TextMessage;
#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Validated runtime constructors and literal translation macro implementation. */
class TranslationBuilder {
	public static function createText(message:TextMessage, value:String):MessageTranslation {
		return TextTranslation(message, MessageRuntime.noPlaceholders(value, "translated text"));
	}

	public static function createString(message:StringMessage, value:String):MessageTranslation {
		return StringTranslation(message, MessageRuntime.stringPlaceholder(value, "translated text"));
	}

	public static function createPlural(message:PluralMessage, singular:String, plural:String):MessageTranslation {
		return PluralTranslation(message, MessageRuntime.countPlaceholder(singular, "translated singular text"),
			MessageRuntime.countPlaceholder(plural, "translated plural text"));
	}

	#if macro
	public static function buildText(message:ExprOf<TextMessage>, value:ExprOf<String>):ExprOf<MessageTranslation> {
		final literal = literal(value);
		validate(value, () -> MessageRuntime.noPlaceholders(literal, "translated text"));
		return macro @:pos(value.pos) wordpress.hx.i18n._internal.TranslationBuilder.createText($message, $v{literal});
	}

	public static function buildString(message:ExprOf<StringMessage>, value:ExprOf<String>):ExprOf<MessageTranslation> {
		final literal = literal(value);
		validate(value, () -> MessageRuntime.stringPlaceholder(literal, "translated text"));
		return macro @:pos(value.pos) wordpress.hx.i18n._internal.TranslationBuilder.createString($message, $v{literal});
	}

	public static function buildPlural(message:ExprOf<PluralMessage>, singular:ExprOf<String>, plural:ExprOf<String>):ExprOf<MessageTranslation> {
		final singularLiteral = literal(singular);
		final pluralLiteral = literal(plural);
		validate(singular, () -> MessageRuntime.countPlaceholder(singularLiteral, "translated singular text"));
		validate(plural, () -> MessageRuntime.countPlaceholder(pluralLiteral, "translated plural text"));
		return macro @:pos(singular.pos) wordpress.hx.i18n._internal.TranslationBuilder.createPlural($message, $v{singularLiteral}, $v{pluralLiteral});
	}

	static function literal(expression:ExprOf<String>):String {
		return switch (expression.expr) {
			case EConst(CString(value, _)): value;
			case _: Context.error("WPX5507: translation text must be a string literal.", expression.pos);
		};
	}

	static function validate(expression:Expr, run:() -> String):Void {
		try {
			run();
		} catch (failure:haxe.Exception) {
			Context.error("WPX5508: " + failure.message + ".", expression.pos);
		}
	}
	#end
}
