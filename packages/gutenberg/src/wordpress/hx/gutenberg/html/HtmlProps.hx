package wordpress.hx.gutenberg.html;

import wordpress.hx.gutenberg.react.DomTypes.HtmlButtonElement;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKeyboardEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKey;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactRefObject;

/** Closed intrinsic-element props admitted by the first browser HXX slice. */
typedef HtmlProps = {
	@:optional final ariaAtomic:Bool;
	@:optional final ariaDescribedBy:String;
	@:optional final ariaHidden:Bool;
	@:optional final ariaLabel:String;
	@:optional final ariaLabelledBy:String;
	@:optional final ariaLive:String;
	@:optional final className:String;
	@:optional final dataContext:String;
	@:optional final dataRefReady:String;
	@:optional final dataState:String;
	@:optional final dataTestId:String;
	@:optional final hidden:Bool;
	@:optional final id:String;
	@:optional final key:ReactKey;
	@:optional final role:String;
	@:optional final tabIndex:Int;
}

/** Closed props for a native button tag. */
typedef HtmlButtonProps = {
	@:optional final ariaControls:String;
	@:optional final ariaExpanded:Bool;
	@:optional final ariaLabel:String;
	@:optional final className:String;
	@:optional final disabled:Bool;
	@:optional final id:String;
	@:optional final onClick:ReactMouseEvent<HtmlButtonElement>->Void;
	@:optional final onKeyDown:ReactKeyboardEvent<HtmlButtonElement>->Void;
	@:optional final ref:ReactRefObject<HtmlButtonElement>;
	@:optional final type:String;
}
