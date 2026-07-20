package sdk064.fixture;

import sdk064.fixture.TodoDomain.SyncStatus;
import sdk064.fixture.TodoDomain.SyncResult;
import wordpress.hx.gutenberg.components.Button;
import wordpress.hx.gutenberg.components.ButtonProps.ButtonVariant;
import wordpress.hx.gutenberg.components.PanelBody;
import wordpress.hx.gutenberg.components.ToggleControl;
import wordpress.hx.gutenberg.editor.CurrentPost;
import wordpress.hx.gutenberg.editor.EditorPlugins;
import wordpress.hx.gutenberg.editor.PluginName;
import wordpress.hx.gutenberg.editor.PluginSidebar;
import wordpress.hx.gutenberg.editor.PluginSidebarMoreMenuItem;
import wordpress.hx.gutenberg.editor.PostTypeName;
import wordpress.hx.gutenberg.editor.SidebarName;
import wordpress.hx.gutenberg.i18n.I18n.__;
import wordpress.hx.gutenberg.react.DomTypes.HtmlButtonElement;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

class Main {
	private static final pluginName = PluginName.literal("wordpresshx-todo-data-lab");
	private static final sidebarName = SidebarName.literal("todo-data-lab");
	private static final supportedPostType = PostTypeName.literal("post");
	private static final textDomain = "wordpresshx-sdk064";

	public static function main():Void {
		TodoStore.register();
		EditorPlugins.register(pluginName, render);
	}

	@:keep
	public static function unregister():Bool {
		TodoStore.stopWatching();
		return EditorPlugins.unregister(pluginName) != null;
	}

	private static function render():ReactNode {
		return <if {CurrentPost.isType(supportedPostType)}><Main.TodoDataSidebar/><else><></></if>;
	}

	private static function TodoDataSidebar():ReactNode {
		final menuItem:ReactNode = <PluginSidebarMoreMenuItem target={sidebarName}>
					{__("Todo data-store lab", textDomain)}
				</PluginSidebarMoreMenuItem>;
		final sidebar:ReactNode = <PluginSidebar name={sidebarName} title={__("Todo data-store lab", textDomain)} isPinnable={true}>
				<style>{DataStoreStyles.css}</style>
				<Main.TodoPanel/>
			</PluginSidebar>;
		return [menuItem, sidebar];
	}

	private static function TodoPanel():ReactNode {
		final state = TodoStore.useSnapshot();
		final commands = TodoStore.useCommands();
		final remaining = TodoStore.remaining(state);
		final shouldSucceed = state.syncStatus == SyncStatus.Error;
		final syncCopy = switch state.syncStatus {
			case Idle: __("Rehearse an asynchronous save without leaving the editor.", textDomain);
			case Loading: __("Sending the typed command…", textDomain);
			case Error: state.syncResult == SyncResult.OfflineRehearsal ? __("Offline rehearsal: no task data was lost.", textDomain) : "";
			case Ready: state.syncResult == SyncResult.PreviewSynchronized ? __("Preview synchronized through the native registry.", textDomain) : "";
		};

		return <section class="wphx-todo-lab" data-testid="wphx-todo-data-sidebar">
			<header class="wphx-todo-lab__header">
				<span class="wphx-todo-lab__eyebrow">TODOSTUDIO / NATIVE DATA</span>
				<h2>{__("A tiny board with a real spine.", textDomain)}</h2>
				<p>{__("Every click crosses a closed Haxe action, a pure reducer, and WordPress’ own reactive registry.", textDomain)}</p>
			</header>
			<div class="wphx-todo-lab__meter">
				<strong aria-live="polite" aria-atomic>{remaining}</strong>
				<span>{__("tasks remain", textDomain)}</span>
			</div>
			<ul class="wphx-todo-lab__tasks">
				<for {task in state.tasks}>
					<li class="wphx-todo-lab__task" data-state={task.complete ? "complete" : "open"}>
						<Button
							ariaLabel={(task.complete ? __("Reopen ", textDomain) : __("Complete ", textDomain)) + task.title}
							onClick={(event:ReactMouseEvent<HtmlButtonElement>) -> {
								event.preventDefault();
								commands.toggleTask(task.id);
							}}
							variant={ButtonVariant.Tertiary}
						>{task.complete ? "✓" : ""}</Button>
						<span>{task.title}</span>
					</li>
				</for>
			</ul>
			<PanelBody>
				<ToggleControl
					checked={state.reviewRequired}
					help={state.reviewRequired ? __("A second set of eyes is part of this run.", textDomain) : __("No handoff is required yet.", textDomain)}
					label={__("Require editorial review", textDomain)}
					onChange={_ -> commands.toggleReview()}
				/>
				<div class="wphx-todo-lab__priority">
					<span>{__("Run priority", textDomain)}</span>
					<strong>{state.priority.toString()}</strong>
					<Button ariaLabel={__("Cycle run priority", textDomain)} onClick={_ -> TodoStore.cyclePriority()} variant={ButtonVariant.Secondary}>
						{__("Change priority", textDomain)}
					</Button>
				</div>
				<div class="wphx-todo-lab__sync" data-state={state.syncStatus.toString()} aria-live="polite">
					<p>{syncCopy}</p>
					<Button
						ariaLabel={shouldSucceed ? __("Retry preview synchronization", textDomain) : __("Rehearse preview synchronization", textDomain)}
						disabled={state.syncStatus == SyncStatus.Loading}
						isBusy={state.syncStatus == SyncStatus.Loading}
						onClick={_ -> commands.rehearseSync(shouldSucceed)}
						variant={ButtonVariant.Primary}
					>{shouldSucceed ? __("Retry sync", textDomain) : __("Rehearse sync", textDomain)}</Button>
				</div>
			</PanelBody>
			<footer class="wphx-todo-lab__footer">
				<span>{"REV " + state.revision}</span>
				<span>{"SUB " + TodoStore.subscriptionCount()}</span>
				<span>WP/DATA</span>
			</footer>
		</section>;
	}
}
