package wordpress.hx.gutenberg.editor;

/**
 * Exact public `@wordpress/editor` 14.40.0 SlotFill menu item.
 *
 * `@:genes.jsxComponentProps` binds inline markup to the exact-profile Haxe
 * props while leaving the native menu item as the only runtime implementation.
 */
@:genes.jsxComponentProps("wordpress.hx.gutenberg.editor.PluginSidebarMoreMenuItemProps")
@:jsRequire("@wordpress/editor", "PluginSidebarMoreMenuItem")
extern class PluginSidebarMoreMenuItem {}
