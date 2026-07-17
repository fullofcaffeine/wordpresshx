package reflaxe.php.print;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpStmt;

using StringTools;

/** Deterministic, fail-closed printer for the admitted generic PHP IR. **/
class PhpPrinter {
	static final IDENTIFIER = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	public function new() {}

	public function printStatements(statements:Array<PhpStmt>, depth:Int = 0):String {
		return statements.map(statement -> printStatement(statement, depth)).join("\n");
	}

	public function printStatement(statement:PhpStmt, depth:Int = 0):String {
		final prefix = tabs(depth);
		return switch (statement) {
			case PhpIf(condition, body):
				prefix
				+ "if ( "
				+ printExpr(condition, depth)
				+ " ) {\n"
				+ printStatements(body, depth + 1)
				+ "\n"
				+ prefix
				+ "}";
			case PhpIfElse(condition, body, elseBody):
				prefix
				+ "if ( "
				+ printExpr(condition, depth)
				+ " ) {\n"
				+ printStatements(body, depth + 1)
				+ "\n"
				+ prefix
				+ "} else {\n"
				+ printStatements(elseBody, depth + 1)
				+ "\n"
				+ prefix
				+ "}";
			case PhpFor(init, condition, update, body):
				prefix
				+ "for ( "
				+ printExpr(init, depth)
				+ "; "
				+ printExpr(condition, depth)
				+ "; "
				+ printExpr(update, depth)
				+ " ) {\n"
				+ printStatements(body, depth + 1)
				+ "\n"
				+ prefix
				+ "}";
			case PhpForeach(iterable, valueVar, body):
				prefix
				+ "foreach ( "
				+ printExpr(iterable, depth)
				+ " as $"
				+ identifier(valueVar)
				+ " ) {\n"
				+ printStatements(body, depth + 1)
				+ "\n"
				+ prefix
				+ "}";
			case PhpForeachKeyValue(iterable, keyVar, valueVar, body):
				prefix
				+ "foreach ( "
				+ printExpr(iterable, depth)
				+ " as $"
				+ identifier(keyVar)
				+ " => $"
				+ identifier(valueVar)
				+ " ) {\n"
				+ printStatements(body, depth + 1)
				+ "\n"
				+ prefix
				+ "}";
			case PhpTryCatch(tryBody, catchType, catchVar, catchBody):
				prefix
				+ "try {\n"
				+ printStatements(tryBody, depth + 1)
				+ "\n"
				+ prefix
				+ "} catch ("
				+ qualifiedName(catchType, "catch type")
				+ " $"
				+ identifier(catchVar)
				+ ") {\n"
				+ printStatements(catchBody, depth + 1)
				+ "\n"
				+ prefix
				+ "}";
			case PhpAssign(target, value):
				prefix + printExpr(target, depth) + " = " + printExpr(value, depth) + ";";
			case PhpListAssign(names, value):
				prefix
				+ "list( "
				+ names.map(name -> "$" + identifier(name)).join(", ")
				+ " ) = "
				+ printExpr(value, depth)
				+ ";";
			case PhpGlobal(names):
				prefix + "global " + names.map(name -> "$" + identifier(name)).join(", ") + ";";
			case PhpLocal(name, value):
				prefix + "$" + identifier(name) + " = " + printExpr(value, depth) + ";";
			case PhpStaticLocal(name, value):
				prefix + "static $" + identifier(name) + " = " + printExpr(value, depth) + ";";
			case PhpExprStmt(expr):
				prefix + printExpr(expr, depth) + ";";
			case PhpEcho(expr):
				prefix + "echo " + printExpr(expr, depth) + ";";
			case PhpRequireOnce(path):
				prefix + "require_once " + printExpr(path, depth) + ";";
			case PhpReturn(value):
				prefix + "return " + printExpr(value, depth) + ";";
			case PhpReturnVoid:
				prefix + "return;";
			case PhpThrow(value):
				prefix + "throw " + printExpr(value, depth) + ";";
			case PhpUnset(target):
				prefix + "unset( " + printExpr(target, depth) + " );";
			case PhpBreak:
				prefix + "break;";
			case PhpContinue:
				prefix + "continue;";
		}
	}

	public function printExpr(expr:PhpExpr, depth:Int = 0):String {
		return switch (expr) {
			case PhpVar(name): "$" + identifier(name);
			case PhpNull: "null";
			case PhpBool(value): value ? "true" : "false";
			case PhpInt(value): Std.string(value);
			case PhpString(value): quote(value);
			case PhpConst(name): qualifiedName(name, "constant");
			case PhpMagicConst(name): magicConstant(name);
			case PhpArrayRead(base, key): printExpr(base, depth) + "[" + printArrayKey(key, depth) + "]";
			case PhpArrayAppend(base): printExpr(base, depth) + "[]";
			case PhpLongArray(entries): printLongArray(entries, depth, false);
			case PhpNew(className, args): printNew(className, args, depth);
			case PhpNewDynamic(classExpr, args): printDynamicNew(classExpr, args, depth);
			case PhpStaticCall(className, method, args):
				qualifiedName(className, "class")
				+ "::"
				+ identifier(method)
				+ printCallArgs(args, depth);
			case PhpClassConst(className, constName):
				qualifiedName(className, "class") + "::" + identifier(constName);
			case PhpStaticProperty(className, property):
				qualifiedName(className, "class") + "::$" + identifier(property);
			case PhpMethodCall(target, method, args):
				printExpr(target, depth) + "->" + identifier(method) + printCallArgs(args, depth);
			case PhpObjectProperty(target, property):
				printExpr(target, depth) + "->" + identifier(property);
			case PhpDynamicObjectProperty(target, property):
				printDynamicObjectProperty(target, property, depth);
			case PhpFunctionCall(name, args):
				qualifiedName(name, "function") + printCallArgs(args, depth);
			case PhpBinop(op, left, right):
				printExpr(left, depth) + " " + binaryOperator(op) + " " + printExpr(right, depth);
			case PhpInstanceOf(value, className):
				printExpr(value, depth) + " instanceof " + qualifiedName(className, "class");
			case PhpNullCoalesce(left, right):
				printExpr(left, depth) + " ?? " + printExpr(right, depth);
			case PhpTernary(condition, ifTrue, ifFalse):
				printExpr(condition, depth)
				+ " ? "
				+ printExpr(ifTrue, depth)
				+ " : "
				+ printExpr(ifFalse, depth);
			case PhpAssignExpr(target, value):
				printExpr(target, depth) + " = " + printExpr(value, depth);
			case PhpPostDecrement(target): printExpr(target, depth) + "--";
			case PhpStaticClosure(parameters, body): printStaticClosure(parameters, body, depth);
			case PhpReference(inner): "&" + printExpr(inner, depth);
			case PhpNot(inner): "! " + printExpr(inner, depth);
			case PhpCastArray(inner): "(array) " + printExpr(inner, depth);
			case PhpCastBool(inner): "(bool) " + printExpr(inner, depth);
			case PhpCastInt(inner): "(int) " + printExpr(inner, depth);
			case PhpCastString(inner): "(string) " + printExpr(inner, depth);
		}
	}

	function printStaticClosure(parameters:Array<String>, body:Array<PhpStmt>, depth:Int):String {
		return "static function ("
			+ parameters.map(parameter -> "$" + identifier(parameter)).join(", ")
			+ ") {\n"
			+ printStatements(body, depth + 1)
			+ "\n"
			+ tabs(depth)
			+ "}";
	}

	function printDynamicObjectProperty(target:PhpExpr, property:PhpExpr, depth:Int):String {
		final renderedTarget = printExpr(target, depth);
		return switch (property) {
			case PhpVar(name): renderedTarget + "->$" + identifier(name);
			case _: renderedTarget + "->{" + printExpr(property, depth) + "}";
		}
	}

	function printArrayKey(key:PhpExpr, depth:Int):String {
		return switch (key) {
			case PhpString(_): printExpr(key, depth);
			case _: " " + printExpr(key, depth) + " ";
		}
	}

	function printLongArray(entries:Array<PhpArrayEntry>, depth:Int, indentFirstLine:Bool):String {
		if (entries.length == 0) {
			return "array()";
		}

		final renderedKeys = entries.map(entry -> entry.key == null ? null : printExpr(entry.key, depth + 1));
		var keyWidth = 0;
		for (key in renderedKeys) {
			if (key != null && key.length > keyWidth) {
				keyWidth = key.length;
			}
		}

		final lines = [(indentFirstLine ? tabs(depth) : "") + "array("];
		for (index in 0...entries.length) {
			final entry = entries[index];
			final key = renderedKeys[index];
			final value = printExpr(entry.value, depth + 1);
			if (key == null) {
				lines.push(tabs(depth + 1) + value + ",");
			} else {
				lines.push(tabs(depth + 1) + key + StringTools.rpad("", " ", keyWidth - key.length + 1) + "=> " + value + ",");
			}
		}
		lines.push(tabs(depth) + ")");
		return lines.join("\n");
	}

	function printNew(className:String, args:Array<PhpExpr>, depth:Int):String {
		final renderedClass = qualifiedName(className, "class");
		if (args.length == 0) {
			return "new " + renderedClass + "()";
		}
		if (args.length == 1 && exprIsMultiline(args[0])) {
			return "new " + renderedClass + "(\n" + printMultilineArg(args[0], depth + 1) + "\n" + tabs(depth) + ")";
		}
		return "new " + renderedClass + "( " + args.map(arg -> printExpr(arg, depth)).join(", ") + " )";
	}

	function printDynamicNew(classExpr:PhpExpr, args:Array<PhpExpr>, depth:Int):String {
		final className = printExpr(classExpr, depth);
		return args.length == 0 ? "new " + className + "()" : "new "
			+ className
			+ "( "
			+ args.map(arg -> printExpr(arg, depth)).join(", ")
			+ " )";
	}

	function printMultilineArg(expr:PhpExpr, depth:Int):String {
		return switch (expr) {
			case PhpLongArray(entries): printLongArray(entries, depth, true);
			case _: printExpr(expr, depth);
		}
	}

	function printCallArgs(args:Array<PhpExpr>, depth:Int):String {
		return args.length == 0 ? "()" : "( " + args.map(arg -> printExpr(arg, depth)).join(", ") + " )";
	}

	function exprIsMultiline(expr:PhpExpr):Bool {
		return switch (expr) {
			case PhpLongArray(_): true;
			case _: false;
		}
	}

	function binaryOperator(value:String):String {
		return switch (value) {
			case "+", "-", "*", "/", "%", ".", "==", "===", "!=", "!==", ">", ">=", "<", "<=", "&&", "||", "&", "|", "^", "<<", ">>":
				value;
			case _:
				throw "Unsupported PHP binary operator: " + value;
		}
	}

	function magicConstant(value:String):String {
		return switch (value) {
			case "__CLASS__", "__DIR__", "__FILE__", "__FUNCTION__", "__LINE__", "__METHOD__", "__NAMESPACE__", "__TRAIT__":
				value;
			case _:
				throw "Unsupported PHP magic constant: " + value;
		}
	}

	function qualifiedName(value:String, label:String):String {
		var body = value;
		if (body.startsWith("\\")) {
			body = body.substr(1);
		}
		if (body.length == 0) {
			throw "Empty PHP " + label;
		}
		for (part in body.split("\\")) {
			identifier(part);
		}
		return value;
	}

	function identifier(value:String):String {
		final normalized = value == "new" ? "__construct" : value;
		if (!IDENTIFIER.match(normalized)) {
			throw "Invalid PHP identifier: " + value;
		}
		return normalized;
	}

	function quote(value:String):String {
		if (value.indexOf("\r") != -1 || value.indexOf("\n") != -1 || value.indexOf("\t") != -1) {
			return "\""
				+ value.split("\\")
					.join("\\\\")
					.split("$")
					.join("\\$")
					.split("\"")
					.join("\\\"")
					.split("\r")
					.join("\\r")
					.split("\n")
					.join("\\n")
					.split("\t")
					.join("\\t") + "\"";
		}
		return "'" + value.split("\\").join("\\\\").split("'").join("\\'") + "'";
	}

	function tabs(count:Int):String {
		final out = new StringBuf();
		for (_ in 0...count) {
			out.add("\t");
		}
		return out.toString();
	}
}
