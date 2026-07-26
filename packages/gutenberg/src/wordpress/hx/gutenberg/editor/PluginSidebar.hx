package wordpress.hx.gutenberg.editor;

/**
 * Exact public `@wordpress/editor` 14.40.0 SlotFill component.
 *
 * `@:genes.jsxComponentProps` binds inline markup to the exact-profile Haxe
 * props while leaving the native SlotFill as the only runtime implementation.
 */
@:genes.jsxComponentProps("wordpress.hx.gutenberg.editor.PluginSidebarProps")
@:jsRequire("@wordpress/editor", "PluginSidebar")
extern class PluginSidebar {}
