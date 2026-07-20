package wordpress.hx.gutenberg.block;

/** Curated stable props used by the SDK-061 plain-text editor surface. */
@:ts.type("{ readonly value: string; readonly onChange: (next: string) => void; readonly className?: string; readonly placeholder?: string; readonly 'aria-label'?: string }")
typedef PlainTextProps = {
	@:optional final ariaLabel:String;
	@:optional final className:String;
	final onChange:String->Void;
	@:optional final placeholder:String;
	final value:String;
}
