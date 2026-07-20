package sdk064.unit;

import sdk064.fixture.TodoDomain;
import sdk064.fixture.TodoDomain.SyncStatus;
import sdk064.fixture.TodoDomain.SyncResult;
import sdk064.fixture.TodoDomain.TodoPriority;

class Main {
	public static function main():Void {
		final initial = TodoDomain.initial();
		equal(TodoDomain.remaining(initial), 2, "initial remaining count");

		final toggled = TodoDomain.reduce(initial, TodoDomain.toggleTask("invite-review"));
		equal(TodoDomain.remaining(toggled), 1, "toggle selector result");
		equal(initial.tasks[1].complete, false, "reducer preserved prior state");
		equal(toggled.revision, 1, "toggle revision");

		final review = TodoDomain.reduce(toggled, TodoDomain.toggleReview());
		equal(review.reviewRequired, true, "review action");
		final focused = TodoDomain.reduce(review, TodoDomain.cyclePriority());
		equal(focused.priority, TodoPriority.Focused, "priority action");

		final loading = TodoDomain.reduce(focused, TodoDomain.syncStarted());
		equal(loading.syncStatus, SyncStatus.Loading, "loading state");
		final failed = TodoDomain.reduce(loading, TodoDomain.syncFailed(SyncResult.OfflineRehearsal));
		equal(failed.syncStatus, SyncStatus.Error, "error state");
		equal(failed.syncResult, SyncResult.OfflineRehearsal, "typed error payload");
		final recovered = TodoDomain.reduce(failed, TodoDomain.syncSucceeded(SyncResult.PreviewSynchronized));
		equal(recovered.syncStatus, SyncStatus.Ready, "recovery state");
		equal(recovered.syncResult, SyncResult.PreviewSynchronized, "typed success payload");

		trace("SDK-064 pure reducer, action, and selector checks passed");
	}

	private static function equal<T>(actual:T, expected:T, label:String):Void {
		if (actual != expected) {
			throw '${label}: expected ${expected}, received ${actual}';
		}
	}
}
