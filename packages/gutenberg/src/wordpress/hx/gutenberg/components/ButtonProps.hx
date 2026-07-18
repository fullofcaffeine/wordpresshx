package wordpress.hx.gutenberg.components;

import wordpress.hx.gutenberg.react.DomTypes.HtmlButtonElement;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKeyboardEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;
import wordpress.hx.gutenberg.react.ReactTypes.ReactRefObject;

@:ts.type("'primary' | 'secondary' | 'tertiary' | 'link'")
enum abstract ButtonVariant(String) to String {
	var Primary = "primary";
	var Secondary = "secondary";
	var Tertiary = "tertiary";
	var Link = "link";
}

/** Curated Haxe view of the exact WordPress Button props used by the SDK. */
@:ts.type("import('react').ComponentProps<typeof import('@wordpress/components').Button>")
typedef ButtonProps = {
	@:optional final accessibleWhenDisabled:Bool;
	@:optional final ariaControls:String;
	@:optional final ariaExpanded:Bool;
	@:optional final ariaLabel:String;
	@:optional final children:ReactNode;
	@:optional final className:String;
	@:optional final description:String;
	@:optional final disabled:Bool;
	@:optional final isBusy:Bool;
	@:optional final isDestructive:Bool;
	@:optional final label:String;
	@:optional final onClick:ReactMouseEvent<HtmlButtonElement>->Void;
	@:optional final onKeyDown:ReactKeyboardEvent<HtmlButtonElement>->Void;
	@:optional final ref:ReactRefObject<HtmlButtonElement>;
	@:optional final text:String;
	@:optional final variant:ButtonVariant;
}
