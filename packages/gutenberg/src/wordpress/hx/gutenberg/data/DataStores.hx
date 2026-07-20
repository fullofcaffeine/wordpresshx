package wordpress.hx.gutenberg.data;

private typedef NativeActionCreators<Action> = {
	function dispatchAction(action:Action):Action;
}

private typedef NativeSelectors<State> = {
	function getState(state:State):State;
}

private typedef NativeStoreOptions<State, Action> = {
	final initialState:State;
	final reducer:(state:State, action:Action) -> State;
	final actions:NativeActionCreators<Action>;
	final selectors:NativeSelectors<State>;
}

private typedef BoundActionCreators<Action> = {
	function dispatchAction(action:Action):DataPromise<Action>;
}

private typedef BoundSelectors<State> = {
	function getState():State;
}

@:jsRequire("@wordpress/data", "createReduxStore")
private extern function createReduxStore<State, Action>(key:String, options:NativeStoreOptions<State, Action>):TypedDataStore<State, Action>;

@:jsRequire("@wordpress/data", "register")
private extern function registerStore<State, Action>(store:TypedDataStore<State, Action>):Void;

@:jsRequire("@wordpress/data", "select")
private extern function selectStore<State, Action>(store:TypedDataStore<State, Action>):BoundSelectors<State>;

@:jsRequire("@wordpress/data", "dispatch")
private extern function dispatchStore<State, Action>(store:TypedDataStore<State, Action>):BoundActionCreators<Action>;

@:jsRequire("@wordpress/data", "subscribe")
private extern function subscribeStore<State, Action>(listener:Void->Void, store:TypedDataStore<State, Action>):Void->Void;

@:jsRequire("@wordpress/data", "useSelect")
private extern function useStoreSelect<State, Action>(mapSelect:(TypedDataStore<State, Action>->BoundSelectors<State>)->State,
	dependencies:Array<String>):State;

@:jsRequire("@wordpress/data", "useDispatch")
private extern function useStoreDispatch<State, Action>(store:TypedDataStore<State, Action>):BoundActionCreators<Action>;

/**
 * Typed Haxe facade over WordPress' native reactive data registry.
 *
 * The deliberately small first contract transports one closed action type and
 * exposes one immutable snapshot selector. Domain-specific command and selector
 * names stay ordinary Haxe methods, while WordPress keeps registration,
 * dispatch, subscription, and React update ownership.
 */
class DataStores {
	@:noCompletion
	public static inline function createValidated<State, Action:{final type:String;}>(key:StoreKey, initialState:State,
			reducer:(state:State, action:Action) -> State):TypedDataStore<State, Action> {
		return createReduxStore(key.toString(), {
			initialState: initialState,
			reducer: reducer,
			actions: {dispatchAction: action -> action},
			selectors: {getState: state -> state}
		});
	}

	public static inline function register<State, Action>(store:TypedDataStore<State, Action>):Void {
		registerStore(store);
	}

	public static inline function snapshot<State, Action>(store:TypedDataStore<State, Action>):State {
		return selectStore(store).getState();
	}

	public static inline function send<State, Action>(store:TypedDataStore<State, Action>, action:Action):DataPromise<Action> {
		return dispatchStore(store).dispatchAction(action);
	}

	public static inline function subscribe<State, Action>(store:TypedDataStore<State, Action>, listener:Void->Void):Void->Void {
		return subscribeStore(listener, store);
	}

	public static inline function useSnapshot<State, Action>(store:TypedDataStore<State, Action>):State {
		return useStoreSelect(select -> select(store).getState(), []);
	}

	public static inline function useSender<State, Action>(store:TypedDataStore<State, Action>):Action->DataPromise<Action> {
		return useStoreDispatch(store).dispatchAction;
	}
}
