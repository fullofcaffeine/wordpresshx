package wordpress.hx.gutenberg.block._internal;

import wordpress.hx.gutenberg.block.EditProps;

/** Erased native partial-object boundary reached only after macro validation. */
@:access(wordpress.hx.gutenberg.block.EditProps)
class EditAttributesRuntime {
	public static inline function apply<Attributes>(props:EditProps<Attributes>, update:{}):Void {
		props.setAttributes(update);
	}
}
