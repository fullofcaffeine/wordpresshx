package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.WireValue.WireField;
import wordpress.hx.contracts.schema.FrozenWireValue;

class FrozenWireValueTools {
	public static function snapshot(value:WireValue):FrozenWireValue {
		return snapshotAt(value, "$", [], []);
	}

	static function snapshotAt(value:WireValue, path:String, activeArrays:Array<Array<WireValue>>, activeObjects:Array<Array<WireField>>):FrozenWireValue {
		return switch value {
			case NullValue: FrozenNull;
			case BoolValue(value): FrozenBool(value);
			case IntegerValue(value): FrozenInteger(value);
			case StringValue(value): FrozenString(value);
			case ArrayValue(values):
				if (containsArray(activeArrays, values)) {
					throw new ContractError(path + ": cyclic wire array cannot become a schema default");
				}
				activeArrays.push(values);
				final snapshot = FrozenArray([
					for (index in 0...values.length)
						snapshotAt(values[index], path + "[" + index + "]", activeArrays, activeObjects)
				]);
				activeArrays.pop();
				snapshot;
			case ObjectValue(fields):
				if (containsObject(activeObjects, fields)) {
					throw new ContractError(path + ": cyclic wire object cannot become a schema default");
				}
				activeObjects.push(fields);
				final snapshot = FrozenObject([for (field in fields) snapshotField(field, path, activeArrays, activeObjects)]);
				activeObjects.pop();
				snapshot;
		};
	}

	public static function thaw(value:FrozenWireValue):WireValue {
		return switch value {
			case FrozenNull: NullValue;
			case FrozenBool(value): BoolValue(value);
			case FrozenInteger(value): IntegerValue(value);
			case FrozenString(value): StringValue(value);
			case FrozenArray(values): ArrayValue([for (item in values) thaw(item)]);
			case FrozenObject(fields): ObjectValue([for (field in fields) thawField(field)]);
		};
	}

	static function snapshotField(field:WireField, path:String, activeArrays:Array<Array<WireValue>>, activeObjects:Array<Array<WireField>>):FrozenWireField {
		return new FrozenWireField(field.name, snapshotAt(field.value, path + "/" + pointerComponent(field.name), activeArrays, activeObjects));
	}

	static function thawField(field:FrozenWireField):WireField {
		return {name: field.name, value: thaw(field.value)};
	}

	static function containsArray(active:Array<Array<WireValue>>, expected:Array<WireValue>):Bool {
		for (candidate in active) {
			if (candidate == expected) {
				return true;
			}
		}
		return false;
	}

	static function containsObject(active:Array<Array<WireField>>, expected:Array<WireField>):Bool {
		for (candidate in active) {
			if (candidate == expected) {
				return true;
			}
		}
		return false;
	}

	static function pointerComponent(value:String):String {
		return StringTools.replace(StringTools.replace(value, "~", "~0"), "/", "~1");
	}
}
