package wordpress.hx.i18n._internal;

import wordpress.hx.i18n.MessageKey;
import wordpress.hx.i18n.MessageOrigin;
import wordpress.hx.i18n.MessageSource;
import wordpress.hx.i18n.PluralMessage;
import wordpress.hx.i18n.StringMessage;
import wordpress.hx.i18n.TextDomain;
import wordpress.hx.i18n.TextMessage;
#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
#end

/** Validated constructor and compile-time declaration implementation. */
class MessageBuilder {
	public static function createText(key:String, defaultText:String, comment:String, domain:String, context:Null<String>, file:String, line:Int):TextMessage {
		return new TextMessage(MessageKey.parse(key), defaultText, comment, TextDomain.parse(domain), context, Authored(new MessageSource(file, line)));
	}

	public static function createString(key:String, defaultText:String, comment:String, domain:String, context:Null<String>, file:String,
			line:Int):StringMessage {
		return new StringMessage(MessageKey.parse(key), defaultText, comment, TextDomain.parse(domain), context, Authored(new MessageSource(file, line)));
	}

	public static function createPlural(key:String, singular:String, plural:String, comment:String, domain:String, context:Null<String>, file:String,
			line:Int):PluralMessage {
		return new PluralMessage(MessageKey.parse(key), singular, plural, comment, TextDomain.parse(domain), context, Authored(new MessageSource(file, line)));
	}

	public static function createExternalText(key:String, defaultText:String, comment:String, domain:String, context:Null<String>,
			boundary:String):TextMessage {
		return new TextMessage(MessageKey.parse(key), defaultText, comment, TextDomain.parse(domain), context, External(MessageRuntime.boundary(boundary)));
	}

	#if macro
	public static function buildText(options:Expr, withContext:Bool):ExprOf<TextMessage> {
		final fields = objectFields(options,
			withContext ? ["comment", "context", "defaultText", "domain", "key"] : ["comment", "defaultText", "domain", "key"]);
		final key = literal(fields.get("key"), "WPX5500", "message key");
		final defaultText = literal(fields.get("defaultText"), "WPX5501", "message default text");
		final comment = literal(fields.get("comment"), "WPX5502", "translator comment");
		final domain = literal(fields.get("domain"), "WPX5503", "text domain");
		final context = withContext ? literal(fields.get("context"), "WPX5503", "message context") : null;
		validate(options, () -> {
			MessageKey.parse(key);
			TextDomain.parse(domain);
			MessageRuntime.noPlaceholders(defaultText, "message default text");
			MessageRuntime.comment(comment);
			if (context != null) {
				MessageRuntime.context(context);
			}
		});
		final source = source(options);
		return macro @:pos(options.pos) wordpress.hx.i18n._internal.MessageBuilder.createText($v{key}, $v{defaultText}, $v{comment}, $v{domain}, $v{context},
			$v{source.file}, $v{source.line});
	}

	public static function buildString(options:Expr, withContext:Bool):ExprOf<StringMessage> {
		final fields = objectFields(options,
			withContext ? ["comment", "context", "defaultText", "domain", "key"] : ["comment", "defaultText", "domain", "key"]);
		final key = literal(fields.get("key"), "WPX5500", "message key");
		final defaultText = literal(fields.get("defaultText"), "WPX5501", "message default text");
		final comment = literal(fields.get("comment"), "WPX5502", "translator comment");
		final domain = literal(fields.get("domain"), "WPX5503", "text domain");
		final context = withContext ? literal(fields.get("context"), "WPX5503", "message context") : null;
		validate(options, () -> {
			MessageKey.parse(key);
			TextDomain.parse(domain);
			MessageRuntime.stringPlaceholder(defaultText, "message default text");
			MessageRuntime.comment(comment);
			if (context != null) {
				MessageRuntime.context(context);
			}
		});
		final source = source(options);
		return macro @:pos(options.pos) wordpress.hx.i18n._internal.MessageBuilder.createString($v{key}, $v{defaultText}, $v{comment}, $v{domain},
			$v{context}, $v{source.file}, $v{source.line});
	}

	public static function buildPlural(options:Expr, withContext:Bool):ExprOf<PluralMessage> {
		final fields = objectFields(options,
			withContext ? ["comment", "context", "domain", "key", "plural", "singular"] : ["comment", "domain", "key", "plural", "singular"]);
		final key = literal(fields.get("key"), "WPX5500", "message key");
		final singular = literal(fields.get("singular"), "WPX5501", "message singular text");
		final plural = literal(fields.get("plural"), "WPX5501", "message plural text");
		final comment = literal(fields.get("comment"), "WPX5502", "translator comment");
		final domain = literal(fields.get("domain"), "WPX5503", "text domain");
		final context = withContext ? literal(fields.get("context"), "WPX5503", "message context") : null;
		validate(options, () -> {
			MessageKey.parse(key);
			TextDomain.parse(domain);
			MessageRuntime.countPlaceholder(singular, "message singular text");
			MessageRuntime.countPlaceholder(plural, "message plural text");
			MessageRuntime.comment(comment);
			if (context != null) {
				MessageRuntime.context(context);
			}
		});
		final source = source(options);
		return macro @:pos(options.pos) wordpress.hx.i18n._internal.MessageBuilder.createPlural($v{key}, $v{singular}, $v{plural}, $v{comment}, $v{domain},
			$v{context}, $v{source.file}, $v{source.line});
	}

	static function objectFields(options:Expr, expected:Array<String>):Map<String, Expr> {
		final result:Map<String, Expr> = [];
		switch (options.expr) {
			case EObjectDecl(fields):
				for (field in fields) {
					if (result.exists(field.field)) {
						Context.error("WPX5506: duplicate message declaration field " + field.field + ".", field.expr.pos);
					}
					result.set(field.field, field.expr);
				}
			case _:
				Context.error("WPX5506: message declaration must be a closed object literal.", options.pos);
		}
		expected.sort(compareText);
		final actual = [for (name in result.keys()) name];
		actual.sort(compareText);
		if (actual.join("|") != expected.join("|")) {
			Context.error("WPX5506: message declaration fields must be exactly " + expected.join(", ") + ".", options.pos);
		}
		return result;
	}

	static function literal(expression:Expr, code:String, label:String):String {
		return switch (expression.expr) {
			case EConst(CString(value, _)): value;
			case _: Context.error(code + ": " + label + " must be a string literal.", expression.pos);
		};
	}

	static function validate(options:Expr, run:() -> Void):Void {
		try {
			run();
		} catch (failure:haxe.Exception) {
			Context.error("WPX5504: " + failure.message + ".", options.pos);
		}
	}

	static function source(options:Expr):{file:String, line:Int} {
		final info = Context.getPosInfos(options.pos);
		final physical = info.file;
		if (!FileSystem.exists(physical)) {
			Context.error("WPX5505: message source file cannot be read for provenance.", options.pos);
		}
		final normalizedCwd = Sys.getCwd().split("\\").join("/");
		var logical = physical.split("\\").join("/");
		if (StringTools.startsWith(logical, normalizedCwd + "/")) {
			logical = logical.substr(normalizedCwd.length + 1);
		}
		while (StringTools.startsWith(logical, "./")) {
			logical = logical.substr(2);
		}
		if (StringTools.startsWith(logical, "/") || logical.split("/").indexOf("..") != -1) {
			Context.error("WPX5505: message source must resolve inside the compilation root.", options.pos);
		}
		final content = File.getContent(physical);
		final prefix = content.substr(0, info.min);
		return {file: logical, line: prefix.split("\n").length};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
	#end
}
