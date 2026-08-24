package wordpress.hx.i18n;

#if macro
import haxe.macro.Expr;
import wordpress.hx.i18n._internal.MessageBuilder;
#end

/** Compile-time declarations for closed, extractable message shapes. */
class Messages {
	public static macro function text(options:Expr):ExprOf<TextMessage> {
		return MessageBuilder.buildText(options, false);
	}

	public static macro function context(options:Expr):ExprOf<TextMessage> {
		return MessageBuilder.buildText(options, true);
	}

	public static macro function string(options:Expr):ExprOf<StringMessage> {
		return MessageBuilder.buildString(options, false);
	}

	public static macro function stringContext(options:Expr):ExprOf<StringMessage> {
		return MessageBuilder.buildString(options, true);
	}

	public static macro function plural(options:Expr):ExprOf<PluralMessage> {
		return MessageBuilder.buildPlural(options, false);
	}

	public static macro function pluralContext(options:Expr):ExprOf<PluralMessage> {
		return MessageBuilder.buildPlural(options, true);
	}
}
