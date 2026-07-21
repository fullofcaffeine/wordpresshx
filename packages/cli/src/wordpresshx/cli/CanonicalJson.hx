package wordpresshx.cli;

import haxe.Json;
import wordpresshx.cli.closedjson.JsonValue;

/** Canonical trace encoder over the shared closed value algebra. */
class CanonicalJson {
	public static function encode(value:JsonValue):String {
		return switch value {
			case NullValue: "null";
			case BoolValue(value): value ? "true" : "false";
			case NumberValue(source): source;
			case StringValue(value): Json.stringify(value);
			case ArrayValue(values): "[" + values.map(encode).join(",") + "]";
			case ObjectValue(fields):
				final sorted = fields.copy();
				sorted.sort((left, right) -> Content.compareText(left.name, right.name));
				"{" + sorted.map(field -> Json.stringify(field.name) + ":" + encode(field.value)).join(",") + "}";
		};
	}
}
