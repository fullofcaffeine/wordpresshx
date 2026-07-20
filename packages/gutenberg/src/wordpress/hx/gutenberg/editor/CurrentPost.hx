package wordpress.hx.gutenberg.editor;

import wordpress.hx.gutenberg.react.ReactTypes.HookDependencies;

private typedef EditorSelectors = {
	function getCurrentPostType():Null<String>;
}

private typedef EditorSelect = String->EditorSelectors;

@:jsRequire("@wordpress/data", "useSelect")
private extern function useSelect<T>(mapSelect:EditorSelect->T, dependencies:HookDependencies):T;

/** Exact `core/editor` selector boundary used for post-type visibility. */
class CurrentPost {
	private static final STORE = "core/editor";

	public static inline function typeName():Null<String> {
		return useSelect(select -> select(STORE).getCurrentPostType(), []);
	}

	public static inline function isType(expected:PostTypeName):Bool {
		return typeName() == expected.toString();
	}
}
