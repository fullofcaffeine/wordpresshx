package wordpress.hx.gutenberg.block._internal;

import wordpress.hx.gutenberg.block.BlockElementProps;

/** Internal exact native projection for callable `useBlockProps` plus `.save`. */
@:jsRequire("@wordpress/block-editor", "useBlockProps")
extern class NativeUseBlockProps {
	@:selfCall public static function edit(props:BlockElementProps):BlockElementProps;
	public static function save(props:BlockElementProps):BlockElementProps;
}
