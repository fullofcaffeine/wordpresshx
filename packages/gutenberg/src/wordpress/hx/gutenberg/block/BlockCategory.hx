package wordpress.hx.gutenberg.block;

/** Core block-inserter categories admitted by the `wp70-release` profile. */
enum abstract BlockCategory(String) {
	var Text = "text";
	var Media = "media";
	var Design = "design";
	var Widgets = "widgets";
	var Theme = "theme";
	var Embed = "embed";
}
