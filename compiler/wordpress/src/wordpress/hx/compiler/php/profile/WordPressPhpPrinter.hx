package wordpress.hx.compiler.php.profile;

import haxe.io.Bytes;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.print.PhpPrinter;
import reflaxe.php.print.PhpRenderedFile;

/** WordPress metadata wrapper over the generic structured PHP printer. **/
class WordPressPhpPrinter {
	static inline final PHP_OPEN = "<?php\n";
	static inline final WORDPRESS_HEADER_SCAN_BYTES = 8192;

	final php:PhpPrinter;

	public function new() {
		php = new PhpPrinter();
	}

	public function print(file:PhpFile):PhpRenderedFile {
		return php.printFile(file);
	}

	public function printPluginRoot(header:PluginHeader, file:PhpFile):PhpRenderedFile {
		if (header == null || file == null) {
			throw "WordPress plugin root requires a header and PHP file";
		}
		if (file.strictTypes || file.namespace != null || file.declarations.length != 0) {
			throw "WordPress plugin root must be a non-namespaced statement-only file";
		}
		final rendered = php.printFile(file);
		if (!StringTools.startsWith(rendered.source, PHP_OPEN)) {
			throw "Generic PHP printer returned an unexpected file opening";
		}
		final headerLines = ["/**"];
		for (entry in header.orderedEntries()) {
			headerLines.push(" * " + entry.label + ": " + entry.value);
		}
		headerLines.push(" */");
		final headerSource = headerLines.join("\n") + "\n";
		if (Bytes.ofString(PHP_OPEN + headerSource).length > WORDPRESS_HEADER_SCAN_BYTES) {
			throw "WordPress plugin header exceeds the native 8 KiB scan window";
		}
		final source = PHP_OPEN + headerSource + rendered.source.substr(PHP_OPEN.length);
		return new PhpRenderedFile(rendered.path, source, []);
	}
}
