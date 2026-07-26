package wordpress.hx.gutenberg.html;

import wordpress.hx.gutenberg.react.DomTypes.HtmlButtonElement;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKeyboardEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKey;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactRefObject;

/** Closed intrinsic-element props admitted by the first browser HXX slice. */
typedef HtmlProps = {
	@:native("aria-atomic")
	@:optional final ariaAtomic:Bool;
	@:native("aria-describedby")
	@:optional final ariaDescribedBy:String;
	@:native("aria-hidden")
	@:optional final ariaHidden:Bool;
	@:native("aria-label")
	@:optional final ariaLabel:String;
	@:native("aria-labelledby")
	@:optional final ariaLabelledBy:String;
	@:native("aria-live")
	@:optional final ariaLive:String;
	@:optional final className:String;
	@:native("data-context")
	@:optional final dataContext:String;
	@:native("data-ref-ready")
	@:optional final dataRefReady:String;
	@:native("data-state")
	@:optional final dataState:String;
	@:native("data-testid")
	@:optional final dataTestId:String;
	@:optional final hidden:Bool;
	@:optional final id:String;
	@:optional final key:ReactKey;
	@:optional final role:String;
	@:optional final tabIndex:Int;
}

/** Closed props for a native button tag. */
typedef HtmlButtonProps = {
	@:native("aria-controls")
	@:optional final ariaControls:String;
	@:native("aria-expanded")
	@:optional final ariaExpanded:Bool;
	@:native("aria-label")
	@:optional final ariaLabel:String;
	@:optional final className:String;
	@:optional final disabled:Bool;
	@:optional final id:String;
	@:optional final onClick:ReactMouseEvent<HtmlButtonElement>->Void;
	@:optional final onKeyDown:ReactKeyboardEvent<HtmlButtonElement>->Void;
	@:optional final ref:ReactRefObject<HtmlButtonElement>;
	@:optional final type:HtmlButtonType;
}
