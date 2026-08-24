package wordpress.hx.compiler.php.profile;

import haxe.io.Bytes;
import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpDeclaration;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpFunction;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import wordpress.hx.i18n.CatalogMessage;
import wordpress.hx.i18n.MessageOrigin;

/** Native PHP and deterministic translation emitter for exact wp70-release. */
class Wp70I18nProfile {
	final printer:WordPressPhpPrinter;

	public function new() {
		printer = new WordPressPhpPrinter();
	}

	public function emit(plan:WordPressI18nPlan):WordPressI18nArtifact {
		if (plan == null || plan.profileId != "wp70-release") {
			throw "Wp70I18nProfile requires an exact wp70-release plan";
		}
		final root = printer.printPluginRoot(plan.header, pluginRoot(plan));
		final messages = printer.print(messagesFile(plan));
		return new WordPressI18nArtifact(plan, [
			new WordPressI18nFile(plan.rootPath, "plugin-root", Bytes.ofString(root.source)),
			new WordPressI18nFile(plan.messagesPath, "server-messages", Bytes.ofString(messages.source)),
			new WordPressI18nFile(plan.bundlePath, "browser-bundle", plan.browser.bundle),
			new WordPressI18nFile(plan.metadataPath, "asset-metadata", plan.browser.metadata),
			new WordPressI18nFile(plan.potPath, "pot", Bytes.ofString(WordPressI18nFormats.pot(plan))),
			new WordPressI18nFile(plan.moPath, "mo", WordPressI18nFormats.mo(plan)),
			new WordPressI18nFile(plan.jedPath, "jed", Bytes.ofString(WordPressI18nFormats.jed(plan))),
			new WordPressI18nFile(plan.extractionPath, "extraction-surrogate", Bytes.ofString(WordPressI18nFormats.extractionJavaScript(plan)))
		]);
	}

	function pluginRoot(plan:WordPressI18nPlan):PhpFile {
		final loadTranslations = PhpClosure([], [], [
			PhpExprStmt(PhpFunctionCall("\\load_plugin_textdomain", [
				PhpString(plan.header.textDomain),
				PhpBool(false),
				PhpBinop(".", PhpFunctionCall("\\dirname", [PhpFunctionCall("\\plugin_basename", [PhpMagicConst("__FILE__")])]), PhpString("/languages"))
			]))
		], true, PhpVoidType);
		final assetPath = PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/" + plan.metadataPath));
		final register = PhpClosure([], [], [
			PhpLocal("asset", PhpRequire(assetPath, false)),
			PhpExprStmt(PhpFunctionCall("\\wp_register_script", [
				PhpString(plan.scriptHandle),
				PhpFunctionCall("\\plugins_url", [PhpString(plan.bundlePath), PhpMagicConst("__FILE__")]),
				PhpArrayRead(PhpVar("asset"), PhpString("dependencies")),
				PhpArrayRead(PhpVar("asset"), PhpString("version")),
				PhpLongArray([entry("in_footer", PhpBool(true))])
			])),
			PhpIf(PhpNot(PhpFunctionCall("\\wp_set_script_translations", [
				PhpString(plan.scriptHandle),
				PhpString(plan.header.textDomain),
				PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/languages"))
			])), [
				PhpThrow(PhpNew("\\RuntimeException", [PhpString("Unable to attach generated WordPressHx translations")]))
			]),
			PhpExprStmt(PhpFunctionCall("\\wp_enqueue_script", [PhpString(plan.scriptHandle)]))
		], true, PhpVoidType);
		return new PhpFile(plan.rootPath, null, false, [], [
			PhpIf(PhpNot(PhpFunctionCall("defined", [PhpString("ABSPATH")])), [PhpReturnVoid]),
			PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/" + plan.messagesPath))),
			PhpLocal("loadTranslations", loadTranslations),
			PhpExprStmt(PhpFunctionCall("\\add_action", [PhpString("plugins_loaded"), PhpVar("loadTranslations")])),
			PhpLocal("registerTranslations", register),
			PhpExprStmt(PhpFunctionCall("\\add_action", [PhpString("enqueue_block_editor_assets"), PhpVar("registerTranslations")])),
			PhpExprStmt(PhpFunctionCall("\\add_action", [PhpString("wp_enqueue_scripts"), PhpVar("registerTranslations")]))
		]);
	}

	function messagesFile(plan:WordPressI18nPlan):PhpFile {
		final statements:Array<PhpStmt> = [];
		final values:Array<PhpArrayEntry> = [];
		var index = 0;
		for (message in plan.locale.catalog.messages) {
			final local = "message" + Std.string(index);
			statements.push(PhpComment("translators: " + WordPressI18nFormats.messageData(message).comment));
			statements.push(PhpLocal(local, translatedExpression(message, plan)));
			values.push(entry(message.key().toString(), PhpVar(local)));
			index++;
		}
		statements.push(PhpReturn(PhpLongArray(values)));
		final source = firstSource(plan);
		final declaration = new PhpFunction(false, id(plan.renderFunction), [
			PhpParameter.named(id("count"), PhpIntType),
			PhpParameter.named(id("title"), PhpStringType)
		], statements,
			PhpSourceRange.at(source.file, source.line, 1, source.line, 2), PhpArrayType);
		return new PhpFile(plan.messagesPath, null, true, [PhpFunctionDeclaration(declaration)]);
	}

	function translatedExpression(message:CatalogMessage, plan:WordPressI18nPlan):PhpExpr {
		return switch (message.definition()) {
			case Text(value):
				textExpression(value.defaultText, value.messageContext, plan.header.textDomain);
			case StringPlaceholder(value):
				PhpFunctionCall("\\sprintf", [
					textExpression(value.defaultText, value.messageContext, plan.header.textDomain),
					PhpVar("title")
				]);
			case PluralCount(value):
				final translated = value.messageContext == null ? PhpFunctionCall("\\_n", [
					PhpString(value.singular),
					PhpString(value.plural),
					PhpVar("count"),
					PhpString(plan.header.textDomain)
				]) : PhpFunctionCall("\\_nx", [
					PhpString(value.singular),
					PhpString(value.plural),
					PhpVar("count"),
					PhpString(value.messageContext),
					PhpString(plan.header.textDomain)
					]);
				PhpFunctionCall("\\sprintf", [translated, PhpVar("count")]);
		};
	}

	function textExpression(text:String, context:Null<String>, domain:String):PhpExpr {
		return context == null ? PhpFunctionCall("\\__",
			[PhpString(text), PhpString(domain)]) : PhpFunctionCall("\\_x", [PhpString(text), PhpString(context), PhpString(domain)]);
	}

	function firstSource(plan:WordPressI18nPlan):wordpress.hx.i18n.MessageSource {
		final origin = plan.locale.catalog.messages[0].origin();
		return switch (origin) {
			case Authored(source): source;
			case External(boundary): throw "SDK-055 emitter rejects external message boundary: " + boundary;
		};
	}

	static function entry(key:String, value:PhpExpr):PhpArrayEntry {
		return {key: PhpString(key), value: value};
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}
}
