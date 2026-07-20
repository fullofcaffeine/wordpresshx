package wordpress.hx.gutenberg.editor;

import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

private typedef NativePluginSettings = {
	final render:Void->ReactNode;
}

/** Opaque registration returned by WordPress' native plugin registry. */
extern class RegisteredEditorPlugin {}

@:jsRequire("@wordpress/plugins", "registerPlugin")
private extern function registerPlugin(name:String, settings:NativePluginSettings):RegisteredEditorPlugin;

@:jsRequire("@wordpress/plugins", "unregisterPlugin")
private extern function unregisterPlugin(name:String):Null<RegisteredEditorPlugin>;

/** Dense typed facade over `@wordpress/plugins`; WordPress remains runtime owner. */
class EditorPlugins {
	public static inline function register(name:PluginName, render:Void->ReactNode):RegisteredEditorPlugin {
		return registerPlugin(name.toString(), {render: render});
	}

	public static inline function unregister(name:PluginName):Null<RegisteredEditorPlugin> {
		return unregisterPlugin(name.toString());
	}
}
