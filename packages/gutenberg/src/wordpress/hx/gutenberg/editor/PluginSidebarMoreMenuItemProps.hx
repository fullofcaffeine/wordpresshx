package wordpress.hx.gutenberg.editor;

import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

/** Curated stable subset with a required accessible menu label. */
@:ts.type("import('react').ComponentProps<typeof import('@wordpress/editor').PluginSidebarMoreMenuItem>")
typedef PluginSidebarMoreMenuItemProps = {
	final target:SidebarName;
	final children:ReactNode;
}
