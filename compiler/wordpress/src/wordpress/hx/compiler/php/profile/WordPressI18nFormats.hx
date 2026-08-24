package wordpress.hx.compiler.php.profile;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import wordpress.hx.i18n.CatalogMessage;
import wordpress.hx.i18n.LocaleCatalog;
import wordpress.hx.i18n.MessageOrigin;
import wordpress.hx.i18n.MessageTranslation;

private typedef JedRecord = {
	final key:String;
	final values:Array<String>;
}

private class MoRecord {
	public final original:Bytes;
	public final translated:Bytes;

	public function new(original:String, translated:String) {
		this.original = Bytes.ofString(original);
		this.translated = Bytes.ofString(translated);
	}
}

/** Deterministic gettext, Jed, MO, and extraction-surrogate serializers. */
class WordPressI18nFormats {
	public static function pot(plan:WordPressI18nPlan):String {
		final lines = [
			"# WordPressHx SDK-055 translation template.",
			"# Generated from typed Haxe declarations. Do not edit.",
			"msgid \"\"",
			"msgstr \"\"",
			"\"Project-Id-Version: " + plan.slug + " 0.0.0\\n\"",
			"\"Content-Type: text/plain; charset=UTF-8\\n\"",
			"\"Content-Transfer-Encoding: 8bit\\n\"",
			"\"MIME-Version: 1.0\\n\"",
			"\"Language: \\n\"",
			"\"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n\"",
			"\"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n\"",
			"\"Language-Team: LANGUAGE <LL@li.org>\\n\"",
			""
		];
		for (catalogMessage in plan.locale.catalog.messages) {
			final source = authoredSource(catalogMessage);
			final data = messageData(catalogMessage);
			lines.push("#. translators: " + data.comment);
			lines.push("#: " + source.file + ":" + Std.string(source.line));
			if (data.placeholder) {
				lines.push("#, php-format");
			}
			if (data.context != null) {
				lines.push("msgctxt " + poQuote(data.context));
			}
			lines.push("msgid " + poQuote(data.singular));
			if (data.plural == null) {
				lines.push("msgstr \"\"");
			} else {
				lines.push("msgid_plural " + poQuote(data.plural));
				lines.push("msgstr[0] \"\"");
				lines.push("msgstr[1] \"\"");
			}
			lines.push("");
		}
		return lines.join("\n") + "\n";
	}

	public static function jed(plan:WordPressI18nPlan):String {
		final records:Array<JedRecord> = [];
		for (translation in plan.locale.translations) {
			final message = LocaleCatalog.message(translation);
			final data = messageData(message);
			final key = data.context == null ? data.singular : data.context + "\x04" + data.singular;
			final values = switch (translation) {
				case TextTranslation(_, value): [value];
				case StringTranslation(_, value): [value];
				case PluralTranslation(_, singular, plural): [singular, plural];
			};
			records.push({key: key, values: values});
		}
		records.sort((left, right) -> compareText(left.key, right.key));
		final domain = plan.locale.catalog.textDomain.toString();
		final lines = [
			"{",
			"  \"domain\": " + json(domain) + ",",
			"  \"generator\": \"WordPressHx SDK-055 deterministic i18n emitter\",",
			"  \"locale_data\": {",
			"    " + json(domain) + ": {",
			"      \"\": {",
			"        \"domain\": " + json(domain) + ",",
			"        \"lang\": " + json(plan.locale.locale.toString()) + ",",
			"        \"plural-forms\": " + json(plan.locale.pluralForms),
			"      },"
		];
		for (index in 0...records.length) {
			final record = records[index];
			final suffix = index == records.length - 1 ? "" : ",";
			lines.push("      " + json(record.key) + ": [" + record.values.map(json).join(", ") + "]" + suffix);
		}
		lines.push("    }");
		lines.push("  },");
		lines.push("  \"source\": " + json(plan.sources[0].path) + ",");
		lines.push("  \"translation-revision-date\": \"\"");
		lines.push("}");
		return lines.join("\n") + "\n";
	}

	public static function mo(plan:WordPressI18nPlan):Bytes {
		final records:Array<MoRecord> = [];
		final metadata = "Project-Id-Version: " + plan.slug + " 0.0.0\n" + "Language: " + plan.locale.locale.toString() + "\n"
			+ "Content-Type: text/plain; charset=UTF-8\n" + "Content-Transfer-Encoding: 8bit\n" + "MIME-Version: 1.0\n" + "Plural-Forms: "
			+ plan.locale.pluralForms + "\n";
		records.push(new MoRecord("", metadata));
		for (translation in plan.locale.translations) {
			final message = LocaleCatalog.message(translation);
			final data = messageData(message);
			var original = data.context == null ? data.singular : data.context + "\x04" + data.singular;
			final translated = switch (translation) {
				case TextTranslation(_, value): value;
				case StringTranslation(_, value): value;
				case PluralTranslation(_, singular, plural):
					original += "\x00" + data.plural;
					singular + "\x00" + plural;
			};
			records.push(new MoRecord(original, translated));
		}
		records.sort((left, right) -> compareText(left.original.toString(), right.original.toString()));
		final count = records.length;
		final originalTableOffset = 28;
		final translationTableOffset = originalTableOffset + count * 8;
		var nextOffset = translationTableOffset + count * 8;
		final originalOffsets:Array<Int> = [];
		for (record in records) {
			originalOffsets.push(nextOffset);
			nextOffset += record.original.length + 1;
		}
		final translationOffsets:Array<Int> = [];
		for (record in records) {
			translationOffsets.push(nextOffset);
			nextOffset += record.translated.length + 1;
		}
		final output = new BytesOutput();
		output.bigEndian = false;
		output.writeInt32(0x950412de);
		output.writeInt32(0);
		output.writeInt32(count);
		output.writeInt32(originalTableOffset);
		output.writeInt32(translationTableOffset);
		output.writeInt32(0);
		output.writeInt32(0);
		for (index in 0...count) {
			output.writeInt32(records[index].original.length);
			output.writeInt32(originalOffsets[index]);
		}
		for (index in 0...count) {
			output.writeInt32(records[index].translated.length);
			output.writeInt32(translationOffsets[index]);
		}
		for (record in records) {
			output.write(record.original);
			output.writeByte(0);
		}
		for (record in records) {
			output.write(record.translated);
			output.writeByte(0);
		}
		return output.getBytes();
	}

	public static function extractionJavaScript(plan:WordPressI18nPlan):String {
		final lines = [
			"// Generated extraction surrogate linked to the typed Haxe catalog.",
			"import { __, _n, _nx, _x } from '@wordpress/i18n';",
			""
		];
		for (catalogMessage in plan.locale.catalog.messages) {
			final source = authoredSource(catalogMessage);
			final data = messageData(catalogMessage);
			lines.push("// Source: " + source.file + ":" + Std.string(source.line) + " [" + catalogMessage.key().toString() + "]");
			lines.push("/* translators: " + data.comment + " */");
			final call = if (data.plural != null) {
				if (data.context == null) {
					"_n( " + json(data.singular) + ", " + json(data.plural) + ", 2, " + json(catalogMessage.domain().toString()) + " );";
				} else {"_nx( "
					+ json(data.singular)
					+ ", "
					+ json(data.plural)
					+ ", 2, "
					+ json(data.context)
					+ ", "
					+ json(catalogMessage.domain().toString())
					+ " );";
				}
			} else if (data.context == null) {
				"__( " + json(data.singular) + ", " + json(catalogMessage.domain().toString()) + " );";
			} else {
				"_x( " + json(data.singular) + ", " + json(data.context) + ", " + json(catalogMessage.domain().toString()) + " );";
			}
			lines.push(call);
			lines.push("");
		}
		return lines.join("\n");
	}

	public static function messageData(message:CatalogMessage):{
		singular:String,
		plural:Null<String>,
		context:Null<String>,
		comment:String,
		placeholder:Bool
	} {
		return switch (message.definition()) {
			case Text(value): {
					singular: value.defaultText,
					plural: null,
					context: value.messageContext,
					comment: value.translatorComment,
					placeholder: false
				};
			case StringPlaceholder(value): {
					singular: value.defaultText,
					plural: null,
					context: value.messageContext,
					comment: value.translatorComment,
					placeholder: true
				};
			case PluralCount(value): {
					singular: value.singular,
					plural: value.plural,
					context: value.messageContext,
					comment: value.translatorComment,
					placeholder: true
				};
		};
	}

	static function authoredSource(message:CatalogMessage):wordpress.hx.i18n.MessageSource {
		return switch (message.origin()) {
			case Authored(source): source;
			case External(boundary): throw "extractable artifact rejects external message: " + boundary;
		};
	}

	static function poQuote(value:String):String {
		return "\"" + value.split("\\")
			.join("\\\\")
			.split("\"")
			.join("\\\"")
			.split("\r")
			.join("\\r")
			.split("\n")
			.join("\\n")
			.split("\t")
			.join("\\t") + "\"";
	}

	static function json(value:String):String {
		final output = new StringBuf();
		output.add("\"");
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			switch (code) {
				case 0x08:
					output.add("\\b");
				case 0x09:
					output.add("\\t");
				case 0x0a:
					output.add("\\n");
				case 0x0c:
					output.add("\\f");
				case 0x0d:
					output.add("\\r");
				case 0x22:
					output.add("\\\"");
				case 0x5c:
					output.add("\\\\");
				case value if (value < 0x20):
					output.add("\\u" + StringTools.hex(value, 4).toLowerCase());
				case _:
					output.addChar(code);
			}
		}
		output.add("\"");
		return output.toString();
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
