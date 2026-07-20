package wordpress.hx.gutenberg.block;

import wordpress.hx.gutenberg.block._internal.NativeUseBlockProps;

/** Typed access to WordPress' edit and save block-wrapper props. */
class BlockProps {
	public static inline function edit(props:BlockElementProps):BlockElementProps {
		return NativeUseBlockProps.edit(props);
	}

	public static inline function save(props:BlockElementProps):BlockElementProps {
		return NativeUseBlockProps.save(props);
	}
}
