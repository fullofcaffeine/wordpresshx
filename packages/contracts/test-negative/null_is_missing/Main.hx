import wordpress.hx.contracts.NullableValue;
import wordpress.hx.contracts.Presence;

class Main {
	static function main():Void {
		acceptPresence(ExplicitNull);
	}

	static function acceptPresence(value:Presence<String>):Void {}
}
