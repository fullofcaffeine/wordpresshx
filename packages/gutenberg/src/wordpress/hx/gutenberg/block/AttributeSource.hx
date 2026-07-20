package wordpress.hx.gutenberg.block;

/** Stable attribute extraction sources admitted by WordPress 7.0. */
enum abstract AttributeSource(String) {
	var Attribute = "attribute";
	var Text = "text";
	var RichText = "rich-text";
	var Html = "html";
	var Raw = "raw";
}
