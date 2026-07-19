package wordpresshx.cli.project;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Decode the macro handoff into a concrete validated project type. */
class PluginPlanReader {
	static final SLUG = ~/^[a-z0-9]+(?:-[a-z0-9]+)*$/;
	static final VERSION = ~/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/;
	static final NAMESPACE = ~/^[A-Z_][A-Za-z0-9_]*(?:\\[A-Z_][A-Za-z0-9_]*)*$/;
	static final SOURCE_PATH = ~/^[A-Za-z0-9._@+\/-]+$/;
	static final HAXE_TYPE = ~/^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$/;
	static final HAXE_FIELD = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	public static function decode(source:String, context:ProjectContext):PluginPlan {
		try {
			final fields = switch JsonParser.parse(source) {
				case ObjectValue(values): values;
				case _: return invalid("plugin compiler plan must be an object");
			};
			exact(fields, [
				"author",
				"description",
				"endColumn",
				"endLine",
				"kind",
				"license",
				"name",
				"namespace",
				"privateTitleFilter",
				"profile",
				"schema",
				"slug",
				"sourcePath",
				"startColumn",
				"startLine",
				"version"
			]);
			expect(text(fields, "schema"), "wordpress-hx.plugin-plan.v2", "plugin plan schema");
			expect(text(fields, "kind"), "plugin", "plugin plan kind");
			final slug = text(fields, "slug");
			final projectId = configuredProjectId(context);
			expect(slug, projectId, "plugin plan identity");
			if (!SLUG.match(slug)) {
				return invalid("plugin plan slug is outside the WordPress policy");
			}
			final profile = text(fields, "profile");
			expect(profile, context.profileId(), "plugin plan profile");
			expect(profile, "wp70-release", "plugin producer profile");
			final name = header(text(fields, "name"), "name");
			final description = header(text(fields, "description"), "description");
			final version = header(text(fields, "version"), "version");
			if (!VERSION.match(version)) {
				return invalid("plugin version is not an exact semantic version");
			}
			final author = header(text(fields, "author"), "author");
			final license = header(text(fields, "license"), "license");
			final namespace = text(fields, "namespace");
			if (!NAMESPACE.match(namespace)) {
				return invalid("plugin namespace is not a relative PHP namespace");
			}
			final sourcePath = text(fields, "sourcePath");
			if (!SOURCE_PATH.match(sourcePath) || StringTools.startsWith(sourcePath, "/") || sourcePath.split("/").indexOf("..") >= 0) {
				return invalid("plugin source path is not project-relative");
			}
			final startLine = positive(fields, "startLine");
			final startColumn = positive(fields, "startColumn");
			final endLine = positive(fields, "endLine");
			final endColumn = positive(fields, "endColumn");
			if (endLine < startLine || (endLine == startLine && endColumn < startColumn)) {
				return invalid("plugin source range is reversed");
			}
			final privateTitleFilter = titleFilter(fields, context);
			return new PluginPlan(slug, profile, name, description, version, author, license, namespace, sourcePath, startLine, startColumn, endLine,
				endColumn, privateTitleFilter);
		} catch (error:JsonParseError) {
			return invalid("plugin compiler plan is malformed: " + error.message);
		}
	}

	static function titleFilter(fields:Array<JsonField>, context:ProjectContext):Null<PluginPrivateTitleFilter> {
		return switch field(fields, "privateTitleFilter") {
			case NullValue: null;
			case ObjectValue(values):
				exact(values, [
					"className",
					"endColumn",
					"endLine",
					"methodName",
					"sourcePath",
					"startColumn",
					"startLine"
				]);
				final className = text(values, "className");
				final methodName = text(values, "methodName");
				if (!HAXE_TYPE.match(className) || !HAXE_FIELD.match(methodName)) {
					return invalid("private title filter symbol is not a closed Haxe static method identity");
				}
				final sourcePath = text(values, "sourcePath");
				if (!validSourcePath(sourcePath) || !belongsToSourceRoot(sourcePath, context.bootstrap.sourceRoots)) {
					return invalid("private title filter must belong to a project source root");
				}
				final startLine = positive(values, "startLine");
				final startColumn = positive(values, "startColumn");
				final endLine = positive(values, "endLine");
				final endColumn = positive(values, "endColumn");
				if (endLine < startLine || (endLine == startLine && endColumn < startColumn)) {
					return invalid("private title filter source range is reversed");
				}
				new PluginPrivateTitleFilter(className, methodName, sourcePath, startLine, startColumn, endLine, endColumn);
			case _:
				invalid("plugin compiler plan privateTitleFilter must be an object or null");
		};
	}

	static function validSourcePath(value:String):Bool {
		return SOURCE_PATH.match(value) && !StringTools.startsWith(value, "/") && value.split("/").indexOf("..") < 0;
	}

	static function belongsToSourceRoot(value:String, roots:Array<String>):Bool {
		for (root in roots) {
			if (value == root || StringTools.startsWith(value, root + "/")) {
				return true;
			}
		}
		return false;
	}

	public static function configuredProjectId(context:ProjectContext):String {
		final source = context.bootstrap.configBytes.toString("utf8");
		final value = JsonParser.parse(source);
		final fields = switch value {
			case ObjectValue(values): values;
			case _: return invalid("project bootstrap must be an object");
		};
		return text(fields, "projectId");
	}

	static function exact(fields:Array<JsonField>, expected:Array<String>):Void {
		final actual = [for (field in fields) field.name];
		actual.sort(compareText);
		final wanted = expected.copy();
		wanted.sort(compareText);
		if (actual.join("\n") != wanted.join("\n")) {
			invalid("plugin compiler plan fields differ from the closed schema");
		}
	}

	static function text(fields:Array<JsonField>, name:String):String {
		return switch field(fields, name) {
			case StringValue(value): value;
			case _: invalid("plugin compiler plan " + name + " must be a string");
		};
	}

	static function positive(fields:Array<JsonField>, name:String):Int {
		return switch field(fields, name) {
			case NumberValue(source):
				if (!~/^[1-9][0-9]*$/.match(source)) {
					invalid("plugin compiler plan " + name + " must be positive");
				}
				final value = Std.parseInt(source);
				if (value == null || value < 1) {
					invalid("plugin compiler plan " + name + " is outside the supported range");
				}
				value;
			case _: invalid("plugin compiler plan " + name + " must be an integer");
		};
	}

	static function field(fields:Array<JsonField>, name:String):JsonValue {
		for (field in fields) {
			if (field.name == name) {
				return field.value;
			}
		}
		return invalid("plugin compiler plan is missing " + name);
	}

	static function header(value:String, label:String):String {
		if (value.length == 0 || StringTools.trim(value) != value || value.indexOf("*/") >= 0) {
			return invalid("plugin " + label + " is not a safe header value");
		}
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			if (code < 0x20 || code > 0x7e) {
				return invalid("plugin " + label + " must use printable ASCII in the current profile");
			}
		}
		return value;
	}

	static function expect(actual:String, expected:String, label:String):Void {
		if (actual != expected) {
			invalid(label + " differs from the authenticated project");
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function invalid<T>(message:String):T {
		throw new CliFailure("WPHX3301", message, 6, "haxe-typing-and-plan", null, [
			"Keep one WordPress.plugin declaration with literal typed options, then rebuild."
		]);
	}
}
