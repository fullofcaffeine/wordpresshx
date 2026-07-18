package wordpress.hx.compiler.php.profile;

import reflaxe.php.map.PhpRangeMapConfig;
import reflaxe.php.map.PhpRangeMapWriter;
import reflaxe.php.print.PhpRenderedFile;

/** SDK projection of the neutral compiler map model onto the public PHP map format. **/
class WordPressPhpRangeMapWriter {
	final writer:PhpRangeMapWriter;

	public function new(generatorVersion:String, generatorSourceSha256:String, buildInputsSha256:String) {
		writer = new PhpRangeMapWriter(new PhpRangeMapConfig("wordpresshx.php-haxe-range-map.v1", "wordpresshx.reflaxe.php", generatorVersion,
			generatorSourceSha256, buildInputsSha256));
	}

	public function write(rendered:PhpRenderedFile):String {
		return writer.write(rendered);
	}
}
