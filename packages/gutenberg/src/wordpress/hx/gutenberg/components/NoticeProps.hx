package wordpress.hx.gutenberg.components;

import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

@:ts.type("'polite' | 'assertive'")
enum abstract NoticePoliteness(String) to String {
	var Polite = "polite";
	var Assertive = "assertive";
}

@:ts.type("'warning' | 'success' | 'error' | 'info'")
enum abstract NoticeStatus(String) to String {
	var Warning = "warning";
	var Success = "success";
	var Error = "error";
	var Info = "info";
}

/** Curated Haxe view of the exact WordPress Notice props used by the SDK. */
@:ts.type("import('react').ComponentProps<typeof import('@wordpress/components').Notice>")
typedef NoticeProps = {
	final children:ReactNode;
	@:optional final className:String;
	@:optional final isDismissible:Bool;
	@:optional final onRemove:Void->Void;
	@:optional final politeness:NoticePoliteness;
	@:optional final spokenMessage:ReactNode;
	@:optional final status:NoticeStatus;
}
