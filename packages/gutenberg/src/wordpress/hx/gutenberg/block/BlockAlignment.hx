package wordpress.hx.gutenberg.block;

/** Alignment controls supported by WordPress 7.0 block metadata. */
enum abstract BlockAlignment(String) {
	var Wide = "wide";
	var Full = "full";
	var Left = "left";
	var Center = "center";
	var Right = "right";
}
