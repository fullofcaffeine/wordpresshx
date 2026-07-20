package wordpress.hx.gutenberg.block._internal;

import wordpress.hx.gutenberg.block.EditProps;
import wordpress.hx.gutenberg.block.SaveProps;
import wordpress.hx.gutenberg.browser.BrowserNode;

private typedef NativeStaticBlockSettings<Attributes> = {
	final edit:EditProps<Attributes>->BrowserNode;
	final save:SaveProps<Attributes>->BrowserNode;
	final deprecated:Array<{}>;
}

private extern class NativeRegisteredBlock {}

@:jsRequire("@wordpress/blocks", "registerBlockType")
private extern function registerBlockType<Attributes>(name:String, settings:NativeStaticBlockSettings<Attributes>):Null<NativeRegisteredBlock>;

/** Narrow native registration boundary fed only by `StaticBlockBuilder`. */
class StaticBlockRuntime {
	public static inline function register<Attributes>(name:String, edit:EditProps<Attributes>->BrowserNode, save:SaveProps<Attributes>->BrowserNode,
			deprecations:Array<{}>):Void {
		registerBlockType(name, {edit: edit, save: save, deprecated: deprecations});
	}
}
