package reflaxe.php.tests;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpClosureCapture;
import reflaxe.php.ir.PhpDeclaration;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpFunction;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpProperty;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;
import reflaxe.php.print.PhpPrinter;
import sys.FileSystem;
import sys.io.File;

/** Neutral regression fixture for the extracted PHP IR and printer. **/
class PrinterTest {
	static final printer = new PhpPrinter();

	static function main():Void {
		testExpressions();
		testStatements();
		testClassShapes();
		testFileDeclarationsAndSourceRanges();
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
		assertEquals("function (int $value) use (&$prefix): string {\n\treturn $prefix . (string) $value;\n}",
			printer.printExpr(PhpClosure([PhpParameter.named(id("value"), PhpIntType)], [new PhpClosureCapture(id("prefix"), true)],
				[PhpReturn(PhpBinop(".", PhpVar("prefix"), PhpCastString(PhpVar("value"))))], false, PhpStringType)),
			"typed closure");
		assertEquals("array( Scaler::class, 'double' )", printer.printExpr(PhpCallableArray(PhpClassConst("Scaler", "class"), id("double"))), "callable array");
	}

	static function testStatements():Void {
		assertEquals("if ( $ready ) {\n\treturn true;\n} else {\n\treturn false;\n}",
			printer.printStatement(PhpIfElse(PhpVar("ready"), [PhpReturn(PhpBool(true))], [PhpReturn(PhpBool(false))])), "if/else");
		assertEquals("try {\n\tthrow new RuntimeException( 'nope' );\n} catch (RuntimeException $error) {\n\treturn null;\n}",
			printer.printStatement(PhpTryCatch([PhpThrow(PhpNew("RuntimeException", [PhpString("nope")]))], "RuntimeException", "error", [PhpReturn(PhpNull)])),
			"try/catch");
		assertEquals("list( $left, $right ) = $pair;", printer.printStatement(PhpListAssign(["left", "right"], PhpVar("pair"))), "list assignment");
		assertEquals("while ( $ready ) {\n\tbreak;\n}", printer.printStatement(PhpWhile(PhpVar("ready"), [PhpBreak])), "while loop");
	}

	static function testFileDeclarationsAndSourceRanges():Void {
		final declarations = fixtureDeclarations();
		final callerOwnedDeclarations = [declarations.functionDeclaration, declarations.classDeclaration];
		final file = new PhpFile("generated/native-boundary.php", PhpQualifiedName.relative("Fixture\\NativeBoundary"), true, callerOwnedDeclarations);
		callerOwnedDeclarations.resize(0);
		file.declarations.resize(0);
		final reversed = new PhpFile("generated/native-boundary.php", PhpQualifiedName.relative("Fixture\\NativeBoundary"), true,
			[declarations.classDeclaration, declarations.functionDeclaration]);
		final rendered = printer.printFile(file);
		final renderedAgain = printer.printFile(reversed);
		assertEquals(rendered.source, renderedAgain.source, "declaration order determinism");
		assertEquals("class:Fixture\\NativeBoundary\\Scaler", rendered.declarationAt(0).stableName, "stable class name");
		assertEquals("function:Fixture\\NativeBoundary\\mutate", rendered.declarationAt(1).stableName, "stable function name");
		assertEquals("src/fixtures/NativeBoundary.hx", rendered.declarationAt(0).source.file, "class source file");
		assertEquals("20", Std.string(rendered.declarationAt(0).source.startLine), "class source line");
		assertEquals("5", Std.string(rendered.declarationAt(1).source.startLine), "function source line");
		final renderedLines = rendered.source.split("\n");
		assertEquals("class Scaler {", renderedLines[rendered.declarationAt(0).generatedStartLine - 1], "class generated range");
		assertEquals("function mutate(array &$values, callable $callback): array {", renderedLines[rendered.declarationAt(1).generatedStartLine - 1],
			"function generated range");
	}

	static function testClassShapes():Void {
		final source = PhpSourceRange.at("src/fixtures/ClassShapes.hx", 1, 1, 12, 2);
		final interfaceMethod = new PhpMethod(PhpPublic, false, false, id("run"), [PhpParameter.named(id("value"), PhpStringType)], source, PhpStringType);
		final interfaceDeclaration = new PhpClass(PhpClassKindInterface, id("Contract"), source, null, [], [], [interfaceMethod]);
		assertEquals("interface Contract {\n\tpublic function run(string $value): string;\n}",
			printer.printDeclaration(PhpClassDeclaration(interfaceDeclaration)), "interface declaration");

		final traitMethod = new PhpMethod(PhpProtected, false, false, id("label"), [], source, PhpStringType, [PhpReturn(PhpVar("label"))]);
		final traitDeclaration = new PhpClass(PhpClassKindTrait, id("Helper"), source, null, [],
			[new PhpProperty(PhpProtected, false, id("label"), PhpString("generic"))], [traitMethod]);
		assertEquals("trait Helper {\n\tprotected $label = 'generic';\n\n\tprotected function label(): string {\n\t\treturn $label;\n\t}\n}",
			printer.printDeclaration(PhpClassDeclaration(traitDeclaration)), "trait declaration");
	}

	static function testFailClosedNamesAndOperators():Void {
		assertThrows(() -> printer.printExpr(PhpVar("value; phpinfo()")), "invalid variable");
		assertThrows(() -> printer.printExpr(PhpFunctionCall("safe(); system", [])), "invalid function name");
		assertThrows(() -> printer.printExpr(PhpBinop("; phpinfo();", PhpInt(1), PhpInt(2))), "invalid operator");
		assertThrows(() -> printer.printExpr(PhpMagicConst("__NOT_MAGIC__")), "invalid magic constant");
		assertThrows(() -> PhpIdentifier.named("bad-name"), "invalid structural identifier");
		assertThrows(() -> PhpQualifiedName.parse("Vendor\\\\Value"), "invalid qualified name");
		assertThrows(() -> PhpSourceRange.at("/private/Fixture.hx", 1, 1, 1, 2), "absolute source path");
		assertThrows(() -> PhpSourceRange.at("src/../Fixture.hx", 1, 1, 1, 2), "traversing source path");
		assertThrows(() -> PhpSourceRange.at("file:C:/Fixture.hx", 1, 1, 1, 2), "source URI path");
		assertThrows(() -> PhpSourceRange.at("src/Fixture.hx", 2, 1, 1, 1), "backward source range");
		assertThrows(() -> new PhpFile("../fixture.php"), "unsafe PHP file path");
		assertThrows(() -> PhpParameter.validatedCopy([PhpParameter.named(id("value")), PhpParameter.named(id("value"))]), "duplicate parameters");
		assertThrows(() -> PhpParameter.validatedCopy([
			PhpParameter.named(id("values"), null, false, true),
			PhpParameter.named(id("tail"))
		]), "non-final variadic parameter");
		final source = PhpSourceRange.at("src/fixtures/Duplicates.hx", 1, 1, 1, 2);
		assertThrows(() -> new PhpClass(PhpClassKindClass, id("DuplicateMethods"), source, null, [], [], [
			new PhpMethod(PhpPublic, false, false, id("render"), [], source, null, []),
			new PhpMethod(PhpPublic, false, false, id("RENDER"), [], source, null, [])
		]), "case-insensitive duplicate methods");
		assertThrows(() -> printer.printFile(new PhpFile("generated/duplicates.php", null, true, [
			PhpClassDeclaration(new PhpClass(PhpClassKindClass, id("Boundary"), source)),
			PhpClassDeclaration(new PhpClass(PhpClassKindInterface, id("BOUNDARY"), source))
		])), "case-insensitive duplicate class-like declarations");
	}

	static function writeExecutableFixture():Void {
		final declarations = fixtureDeclarations();
		final statements:Array<PhpStmt> = [
			PhpLocal("values", PhpLongArray([item(PhpInt(1)), item(PhpInt(2)), item(PhpInt(3))])),
			PhpLocal("callback", PhpCallableArray(PhpClassConst("Scaler", "class"), id("double"))),
			PhpLocal("result", PhpFunctionCall("mutate", [PhpVar("values"), PhpVar("callback")])),
			PhpLocal("errorLabel", PhpString("none")),
			PhpTryCatch([PhpThrow(PhpNew("\\RuntimeException", [PhpString("expected")]))], "\\RuntimeException", "error",
				[PhpAssign(PhpVar("errorLabel"), PhpFunctionCall("get_class", [PhpVar("error")]))]),
			PhpLocal("payload", PhpLongArray([
				entry("total", PhpFunctionCall("array_sum", [PhpVar("result")])),
				entry("count", PhpFunctionCall("count", [PhpVar("values")])),
				entry("error", PhpVar("errorLabel")),
				entry("label", PhpString("generic"))
			])),
			PhpEcho(PhpFunctionCall("json_encode", [PhpVar("payload"), PhpConst("JSON_UNESCAPED_SLASHES")])),
			PhpEcho(PhpString("\n"))
		];
		final rendered = printer.printFile(new PhpFile("build/generic-printer-fixture.php", PhpQualifiedName.relative("Fixture\\NativeBoundary"), true,
			[declarations.functionDeclaration, declarations.classDeclaration], statements));
		final source = rendered.source;
		final expected = "<?php\n\ndeclare(strict_types=1);\n\nnamespace Fixture\\NativeBoundary;\n\n"
			+ "class Scaler {\n\tpublic static function double(int $value): int {\n\t\treturn $value * 2;\n\t}\n}\n\n"
			+ "function mutate(array &$values, callable $callback): array {\n\t$alias = &$values;\n\t$alias[] = $callback( 4 );\n\treturn $values;\n}\n\n"
			+ "$values = array(\n\t1,\n\t2,\n\t3,\n);\n"
			+ "$callback = array( Scaler::class, 'double' );\n"
			+ "$result = mutate( $values, $callback );\n"
			+ "$errorLabel = 'none';\n"
			+ "try {\n\tthrow new \\RuntimeException( 'expected' );\n} catch (\\RuntimeException $error) {\n\t$errorLabel = get_class( $error );\n}\n"
			+ "$payload = array(\n\t'total' => array_sum( $result ),\n\t'count' => count( $values ),\n\t'error' => $errorLabel,\n\t'label' => 'generic',\n);\n"
			+ "echo json_encode( $payload, JSON_UNESCAPED_SLASHES );\n"
			+ "echo \"\\n\";\n";
		assertEquals(expected, source, "executable fixture snapshot");

		if (!FileSystem.exists("build")) {
			FileSystem.createDirectory("build");
		}
		File.saveContent("build/generic-printer-fixture.php", source);
	}

	static function fixtureDeclarations():{functionDeclaration:PhpDeclaration, classDeclaration:PhpDeclaration} {
		final functionSource = PhpSourceRange.at("src/fixtures/NativeBoundary.hx", 5, 1, 12, 2);
		final classSource = PhpSourceRange.at("src/fixtures/NativeBoundary.hx", 20, 1, 28, 2);
		final methodSource = PhpSourceRange.at("src/fixtures/NativeBoundary.hx", 21, 2, 23, 3);
		final functionDeclaration = PhpFunctionDeclaration(new PhpFunction(false, id("mutate"), [
			PhpParameter.named(id("values"), PhpArrayType, true),
			PhpParameter.named(id("callback"), PhpCallableType)
		], [
			PhpAssign(PhpVar("alias"), PhpReference(PhpVar("values"))),
			PhpAssign(PhpArrayAppend(PhpVar("alias")), PhpInvoke(PhpVar("callback"), [PhpInt(4)])),
			PhpReturn(PhpVar("values"))
		], functionSource, PhpArrayType));
		final classDeclaration = PhpClassDeclaration(new PhpClass(PhpClassKindClass, id("Scaler"), classSource, null, [], [], [
			new PhpMethod(PhpPublic, true, false, id("double"), [PhpParameter.named(id("value"), PhpIntType)], methodSource, PhpIntType,
				[PhpReturn(PhpBinop("*", PhpVar("value"), PhpInt(2)))])
		]));
		return {functionDeclaration: functionDeclaration, classDeclaration: classDeclaration};
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
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
