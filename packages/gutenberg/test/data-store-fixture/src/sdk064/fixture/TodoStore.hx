package sdk064.fixture;

import sdk064.fixture.TodoDomain.TodoAction;
import sdk064.fixture.TodoDomain.TodoState;
import sdk064.fixture.TodoDomain.SyncResult;
import wordpress.hx.gutenberg.data.DataStore;
import wordpress.hx.gutenberg.data.DataStores;
import wordpress.hx.gutenberg.data.DataPromise;
import wordpress.hx.gutenberg.data.StoreKey;
import wordpress.hx.gutenberg.data.TypedDataStore;

/** Todo-specific names layered over the reusable native store primitive. */
class TodoStore {
	private static final key = StoreKey.literal("wordpresshx/todo-studio-lab");
	private static final store:TypedDataStore<TodoState, TodoAction> = DataStore.define(key, TodoDomain.initial(), TodoDomain.reduce);
	private static var observedChanges = 0;
	private static var stopSubscription:Null<Void->Void> = null;

	public static function register():Void {
		DataStores.register(store);
		if (snapshot().revision != 0) {
			throw "Todo data store did not register with its declared initial snapshot.";
		}
		stopSubscription = DataStores.subscribe(store, () -> observedChanges += 1);
	}

	public static function stopWatching():Void {
		final stop = stopSubscription;
		if (stop != null) {
			stop();
			stopSubscription = null;
		}
	}

	public static inline function snapshot():TodoState {
		return DataStores.snapshot(store);
	}

	public static inline function useSnapshot():TodoState {
		return DataStores.useSnapshot(store);
	}

	public static inline function useCommands():TodoCommands {
		return new TodoCommands(DataStores.useSender(store));
	}

	public static inline function subscriptionCount():Int {
		return observedChanges;
	}

	public static inline function cyclePriority():Void {
		DataStores.send(store, TodoDomain.cyclePriority());
	}

	public static inline function remaining(state:TodoState):Int {
		return TodoDomain.remaining(state);
	}
}

class TodoCommands {
	private final send:TodoAction->DataPromise<TodoAction>;

	public function new(send:TodoAction->DataPromise<TodoAction>) {
		this.send = send;
	}

	public inline function toggleTask(taskId:String):Void {
		send(TodoDomain.toggleTask(taskId));
	}

	public inline function toggleReview():Void {
		send(TodoDomain.toggleReview());
	}

	public function rehearseSync(shouldSucceed:Bool):Void {
		send(TodoDomain.syncStarted()).then(_ -> {
			js.Browser.window.setTimeout(() -> {
				if (shouldSucceed) {
					send(TodoDomain.syncSucceeded(SyncResult.PreviewSynchronized));
				} else {
					send(TodoDomain.syncFailed(SyncResult.OfflineRehearsal));
				}
			}, 350);
		});
	}
}
