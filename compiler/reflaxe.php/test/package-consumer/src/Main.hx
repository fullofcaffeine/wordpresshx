package;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.print.PhpPrinter;
import sys.FileSystem;
import sys.io.File;

/** Neutral application proving that the installed package can emit runnable PHP. **/
class Main {
	static function main():Void {
		final entries:Array<PhpArrayEntry> = [
			{key: PhpString("package"), value: PhpString("standalone")},
			{key: PhpString("answer"), value: PhpInt(42)}
		];
		final statements:Array<PhpStmt> = [
			PhpLocal("payload", PhpLongArray(entries)),
			PhpEcho(PhpFunctionCall("json_encode", [PhpVar("payload"), PhpConst("JSON_UNESCAPED_SLASHES")])),
			PhpEcho(PhpString("\n"))
		];
		final file = new PhpFile("build/external-consumer.php", PhpQualifiedName.relative("Fixture\\PackageConsumer"), true, [], statements);
		final rendered = new PhpPrinter().printFile(file);
		if (!FileSystem.exists("build")) {
			FileSystem.createDirectory("build");
		}
		File.saveContent(file.path, rendered.source);
		Sys.println("REFLAXE_PHP_EXTERNAL_CONSUMER:PASS");
	}
}
