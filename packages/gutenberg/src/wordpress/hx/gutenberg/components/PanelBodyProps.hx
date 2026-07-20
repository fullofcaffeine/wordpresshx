package wordpress.hx.gutenberg.components;

import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

/** Curated stable subset of the exact WordPress PanelBody props. */
@:ts.type("import('react').ComponentProps<typeof import('@wordpress/components').PanelBody>")
typedef PanelBodyProps = {
	@:optional final children:ReactNode;
	@:optional final className:String;
	@:optional final initialOpen:Bool;
	@:optional final onToggle:Bool->Void;
	@:optional final opened:Bool;
	@:optional final scrollAfterOpen:Bool;
	@:optional final title:String;
}
