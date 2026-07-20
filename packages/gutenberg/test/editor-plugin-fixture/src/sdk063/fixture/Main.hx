package sdk063.fixture;

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
import wordpress.hx.gutenberg.react.Hooks.useState;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

class Main {
	private static final pluginName = PluginName.literal("wordpresshx-todo-readiness");
	private static final sidebarName = SidebarName.literal("todo-readiness");
	private static final supportedPostType = PostTypeName.literal("post");
	private static final textDomain = "wordpresshx-sdk063";

	public static function main():Void {
		register();
	}

	@:keep
	public static function register():Void {
		EditorPlugins.register(pluginName, render);
	}

	@:keep
	public static function unregister():Bool {
		return EditorPlugins.unregister(pluginName) != null;
	}

	private static function render():ReactNode {
		return <if {CurrentPost.isType(supportedPostType)}><Main.ReadinessSidebar/><else><></></if>;
	}

	private static function ReadinessSidebar():ReactNode {
		final reviewState = useState(false);
		final priorityState = useState(0);
		final reviewRequired = reviewState.value;
		final priorities = ["CALM", "FOCUSED", "URGENT"];
		final priority = priorities[priorityState.value];

		final menuItem:ReactNode = <PluginSidebarMoreMenuItem target={sidebarName}>
					{__("Todo Studio readiness", textDomain)}
				</PluginSidebarMoreMenuItem>;
		final sidebar:ReactNode = <PluginSidebar name={sidebarName} title={__("Todo Studio readiness", textDomain)} isPinnable={true}>
				<style>{EditorStyles.css}</style>
				<div class="wphx-readiness" data-state={reviewRequired ? "review" : "clear"} data-testid="wphx-readiness-sidebar">
					<header class="wphx-readiness__header">
						<span class="wphx-readiness__eyebrow">TODOSTUDIO / EDITOR CHECK</span>
						<strong>{priority}</strong>
						<p>{__("A typed publishing runway beside the work—not another settings maze.", textDomain)}</p>
					</header>
					<PanelBody>
						<h2 class="wphx-readiness__panel-title">{__("Before this ships", textDomain)}</h2>
						<ToggleControl
							checked={reviewRequired}
							help={reviewRequired ? __("A second set of eyes is now part of the runway.", textDomain) : __("Publish without an editorial handoff.", textDomain)}
							label={__("Require editorial review", textDomain)}
							onChange={next -> reviewState.set(next)}
						/>
						<div class="wphx-readiness__priority">
							<span>{__("Current pace", textDomain)}</span>
							<strong aria-live="polite" aria-atomic>{priority}</strong>
							<Button
								ariaLabel={__("Cycle publishing priority", textDomain)}
								onClick={(event:ReactMouseEvent<HtmlButtonElement>) -> {
									event.preventDefault();
									priorityState.set((priorityState.value + 1) % priorities.length);
								}}
								variant={ButtonVariant.Secondary}
							>
								{__("Change pace", textDomain)}
							</Button>
						</div>
					</PanelBody>
					<footer class="wphx-readiness__footer">
						<span>WP 7.0</span><span>HXX</span><span>NO PRIVATE APIS</span>
					</footer>
				</div>
				</PluginSidebar>;
		return [menuItem, sidebar];
	}
}
