import wordpress.hx.gutenberg.data.DataStore;
import wordpress.hx.gutenberg.data.StoreKey;

private typedef CounterState = {
	final value:Int;
}

private typedef CounterAction = {
	final type:String;
	final increment:Int;
}

class Main {
	static function main():Void {
		DataStore.define(StoreKey.literal("wordpresshx/counter"), {value: 0}, (state:CounterState, action:CounterAction) -> state.value + action.increment);
	}
}
