package wordpress.hx.gutenberg.editor;

import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

/** Curated stable subset of the exact PluginSidebar props. */
@:ts.type("import('react').ComponentProps<typeof import('@wordpress/editor').PluginSidebar>")
typedef PluginSidebarProps = {
	final name:SidebarName;
	final title:String;
	final children:ReactNode;
	@:optional final className:String;
	@:optional final isPinnable:Bool;
}
