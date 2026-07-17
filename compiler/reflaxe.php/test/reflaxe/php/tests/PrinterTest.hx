package reflaxe.php.tests;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.print.PhpPrinter;
import sys.FileSystem;
import sys.io.File;

/** Neutral regression fixture for the extracted PHP IR and printer. **/
class PrinterTest {
	static final printer = new PhpPrinter();

	static function main():Void {
		testExpressions();
		testStatements();
		testFailClosedNamesAndOperators();
		writeExecutableFixture();
		Sys.println("reflaxe.php printer tests passed");
	}

	static function testExpressions():Void {
		assertEquals("$value['key']", printer.printExpr(PhpArrayRead(PhpVar("value"), PhpString("key"))), "array read");
		assertEquals("$factory->$className", printer.printExpr(PhpDynamicObjectProperty(PhpVar("factory"), PhpVar("className"))), "dynamic property");
		assertEquals("new Vendor\\Package\\Value( 'item' )", printer.printExpr(PhpNew("Vendor\\Package\\Value", [PhpString("item")])), "qualified constructor");
		assertEquals("static function ($value) {\n\treturn (string) $value;\n}",
			printer.printExpr(PhpStaticClosure(["value"], [PhpReturn(PhpCastString(PhpVar("value")))])), "static closure");
		assertEquals("\"line\\nnext\"", printer.printExpr(PhpString("line\nnext")), "escaped multiline string");
		assertEquals("\"cost \\$value\\n\"", printer.printExpr(PhpString("cost $value\n")), "escaped PHP interpolation");
	}

	static function testStatements():Void {
		assertEquals("if ( $ready ) {\n\treturn true;\n} else {\n\treturn false;\n}",
			printer.printStatement(PhpIfElse(PhpVar("ready"), [PhpReturn(PhpBool(true))], [PhpReturn(PhpBool(false))])), "if/else");
		assertEquals("try {\n\tthrow new RuntimeException( 'nope' );\n} catch (RuntimeException $error) {\n\treturn null;\n}",
			printer.printStatement(PhpTryCatch([PhpThrow(PhpNew("RuntimeException", [PhpString("nope")]))], "RuntimeException", "error", [PhpReturn(PhpNull)])),
			"try/catch");
		assertEquals("list( $left, $right ) = $pair;", printer.printStatement(PhpListAssign(["left", "right"], PhpVar("pair"))), "list assignment");
	}

	static function testFailClosedNamesAndOperators():Void {
		assertThrows(() -> printer.printExpr(PhpVar("value; phpinfo()")), "invalid variable");
		assertThrows(() -> printer.printExpr(PhpFunctionCall("safe(); system", [])), "invalid function name");
		assertThrows(() -> printer.printExpr(PhpBinop("; phpinfo();", PhpInt(1), PhpInt(2))), "invalid operator");
		assertThrows(() -> printer.printExpr(PhpMagicConst("__NOT_MAGIC__")), "invalid magic constant");
	}

	static function writeExecutableFixture():Void {
		final statements:Array<PhpStmt> = [
			PhpLocal("values", PhpLongArray([item(PhpInt(1)), item(PhpInt(2)), item(PhpInt(3))])),
			PhpLocal("total", PhpInt(0)),
			PhpForeach(PhpVar("values"), "value", [PhpAssign(PhpVar("total"), PhpBinop("+", PhpVar("total"), PhpVar("value")))]),
			PhpLocal("payload", PhpLongArray([entry("total", PhpVar("total")), entry("label", PhpString("generic"))])),
			PhpEcho(PhpFunctionCall("json_encode", [PhpVar("payload"), PhpConst("JSON_UNESCAPED_SLASHES")])),
			PhpEcho(PhpString("\n"))
		];
		final source = "<?php\n\n" + printer.printStatements(statements) + "\n";
		final expected = "<?php\n\n"
			+ "$values = array(\n\t1,\n\t2,\n\t3,\n);\n"
			+ "$total = 0;\n"
			+ "foreach ( $values as $value ) {\n\t$total = $total + $value;\n}\n"
			+ "$payload = array(\n\t'total' => $total,\n\t'label' => 'generic',\n);\n"
			+ "echo json_encode( $payload, JSON_UNESCAPED_SLASHES );\n"
			+ "echo \"\\n\";\n";
		assertEquals(expected, source, "executable fixture snapshot");

		if (!FileSystem.exists("build")) {
			FileSystem.createDirectory("build");
		}
		File.saveContent("build/generic-printer-fixture.php", source);
	}

	static function item(value:PhpExpr):PhpArrayEntry {
		return {key: null, value: value};
	}

	static function entry(key:String, value:PhpExpr):PhpArrayEntry {
		return {key: PhpString(key), value: value};
	}

	static function assertEquals(expected:String, actual:String, label:String):Void {
		if (expected != actual) {
			throw label + " mismatch\nexpected:\n" + expected + "\nactual:\n" + actual;
		}
	}

	static function assertThrows(run:() -> Dynamic, label:String):Void {
		var threw = false;
		try {
			run();
		} catch (_:Dynamic) {
			threw = true;
		}
		if (!threw) {
			throw label + " did not fail closed";
		}
	}
}
