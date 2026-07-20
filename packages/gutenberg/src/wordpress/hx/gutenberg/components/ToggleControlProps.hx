package wordpress.hx.gutenberg.components;

import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

/** Curated stable subset of the exact WordPress ToggleControl props. */
@:ts.type("import('react').ComponentProps<typeof import('@wordpress/components').ToggleControl>")
typedef ToggleControlProps = {
	@:optional final checked:Bool;
	@:optional final className:String;
	@:optional final disabled:Bool;
	@:optional final help:ReactNode;
	final label:ReactNode;
	final onChange:Bool->Void;
}
