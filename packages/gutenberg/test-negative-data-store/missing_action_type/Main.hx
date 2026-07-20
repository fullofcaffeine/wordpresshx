import wordpress.hx.gutenberg.data.DataStore;
import wordpress.hx.gutenberg.data.StoreKey;

private typedef CounterState = {
	final value:Int;
}

private typedef BrokenAction = {
	final increment:Int;
}

class Main {
	static final initial:CounterState = {value: 0};

	static function main():Void {
		DataStore.define(StoreKey.literal("wordpresshx/counter"), initial, reduce);
	}

	static function reduce(state:CounterState, action:BrokenAction):CounterState {
		return {value: state.value + action.increment};
	}
}
