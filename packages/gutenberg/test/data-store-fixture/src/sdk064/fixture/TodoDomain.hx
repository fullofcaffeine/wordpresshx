package sdk064.fixture;

@:ts.type("'calm' | 'focused' | 'urgent'")
enum abstract TodoPriority(String) to String {
	var Calm = "calm";
	var Focused = "focused";
	var Urgent = "urgent";

	public inline function toString():String {
		return this;
	}
}

@:ts.type("'idle' | 'loading' | 'ready' | 'error'")
enum abstract SyncStatus(String) to String {
	var Idle = "idle";
	var Loading = "loading";
	var Ready = "ready";
	var Error = "error";

	public inline function toString():String {
		return this;
	}
}

@:ts.type("'offline-rehearsal' | 'preview-synchronized'")
enum abstract SyncResult(String) to String {
	var OfflineRehearsal = "offline-rehearsal";
	var PreviewSynchronized = "preview-synchronized";
}

@:ts.type("'toggle-task' | 'toggle-review' | 'cycle-priority' | 'sync-started' | 'sync-failed' | 'sync-succeeded'")
enum abstract TodoActionType(String) to String {
	var ToggleTask = "toggle-task";
	var ToggleReview = "toggle-review";
	var CyclePriority = "cycle-priority";
	var SyncStarted = "sync-started";
	var SyncFailed = "sync-failed";
	var SyncSucceeded = "sync-succeeded";
}

typedef TodoTask = {
	final id:String;
	final title:String;
	final complete:Bool;
}

typedef TodoState = {
	final tasks:Array<TodoTask>;
	final priority:TodoPriority;
	final reviewRequired:Bool;
	final syncStatus:SyncStatus;
	final syncResult:Null<SyncResult>;
	final revision:Int;
}

typedef TodoAction = {
	final type:TodoActionType;
	final taskId:Null<String>;
	final syncResult:Null<SyncResult>;
}

/** Pure task state, commands, and selectors shared by every future runtime. */
class TodoDomain {
	public static function initial():TodoState {
		return {
			tasks: [
				{id: "shape-brief", title: "Shape the project brief", complete: true},
				{id: "invite-review", title: "Invite an editorial review", complete: false},
				{id: "publish-plan", title: "Publish the launch plan", complete: false}
			],
			priority: Calm,
			reviewRequired: false,
			syncStatus: Idle,
			syncResult: null,
			revision: 0
		};
	}

	public static inline function toggleTask(taskId:String):TodoAction {
		return {type: ToggleTask, taskId: taskId, syncResult: null};
	}

	public static inline function toggleReview():TodoAction {
		return {type: ToggleReview, taskId: null, syncResult: null};
	}

	public static inline function cyclePriority():TodoAction {
		return {type: CyclePriority, taskId: null, syncResult: null};
	}

	public static inline function syncStarted():TodoAction {
		return {type: SyncStarted, taskId: null, syncResult: null};
	}

	public static inline function syncFailed(result:SyncResult):TodoAction {
		return {type: SyncFailed, taskId: null, syncResult: result};
	}

	public static inline function syncSucceeded(result:SyncResult):TodoAction {
		return {type: SyncSucceeded, taskId: null, syncResult: result};
	}

	public static function remaining(state:TodoState):Int {
		var count = 0;
		for (task in state.tasks) {
			if (!task.complete) {
				count += 1;
			}
		}
		return count;
	}

	public static function reduce(state:TodoState, action:TodoAction):TodoState {
		return switch action.type {
			case ToggleTask:
				final selected = action.taskId;
				final tasks:Array<TodoTask> = [];
				for (task in state.tasks) {
					if (selected == task.id) {
						final toggled:TodoTask = {
							id: task.id,
							title: task.title,
							complete: !task.complete
						};
						tasks.push(toggled);
					} else {
						tasks.push(task);
					}
				}
				next(state, tasks, state.priority, state.reviewRequired, state.syncStatus, state.syncResult);
			case ToggleReview:
				next(state, state.tasks, state.priority, !state.reviewRequired, state.syncStatus, state.syncResult);
			case CyclePriority:
				final priority = switch state.priority {
					case Calm: Focused;
					case Focused: Urgent;
					case Urgent: Calm;
				};
				next(state, state.tasks, priority, state.reviewRequired, state.syncStatus, state.syncResult);
			case SyncStarted:
				next(state, state.tasks, state.priority, state.reviewRequired, Loading, null);
			case SyncFailed:
				next(state, state.tasks, state.priority, state.reviewRequired, Error, action.syncResult);
			case SyncSucceeded:
				next(state, state.tasks, state.priority, state.reviewRequired, Ready, action.syncResult);
			case _:
				// Redux owns initialization and probe action identities; they may read but must not change application state.
				state;
		};
	}

	private static inline function next(previous:TodoState, tasks:Array<TodoTask>, priority:TodoPriority, reviewRequired:Bool, syncStatus:SyncStatus,
			syncResult:Null<SyncResult>):TodoState {
		return {
			tasks: tasks,
			priority: priority,
			reviewRequired: reviewRequired,
			syncStatus: syncStatus,
			syncResult: syncResult,
			revision: previous.revision + 1
		};
	}
}
