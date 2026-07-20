import wordpress.hx.gutenberg.data.DataStore;
import wordpress.hx.gutenberg.data.DataStores;
import wordpress.hx.gutenberg.data.StoreKey;
import wordpress.hx.gutenberg.data.TypedDataStore;

private typedef CounterState = {
	final value:Int;
}

private typedef CounterAction = {
	final type:String;
	final increment:Int;
}

class Main {
	static final initial:CounterState = {value: 0};
	static final store:TypedDataStore<CounterState, CounterAction> = DataStore.define(StoreKey.literal("wordpresshx/counter"), initial, reduce);

	static function main():Void {
		DataStores.send(store, "not-a-counter-action");
	}

	static function reduce(state:CounterState, action:CounterAction):CounterState {
		return {value: state.value + action.increment};
	}
}
