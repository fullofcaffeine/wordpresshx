package reflaxe.php.print;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpClosureCapture;
import reflaxe.php.ir.PhpDeclaration;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpFunction;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpProperty;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;

using StringTools;

/** Deterministic, fail-closed printer for the admitted generic PHP IR. **/
class PhpPrinter {
	static final IDENTIFIER = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	public function new() {}

	public function printFile(file:PhpFile):PhpRenderedFile {
		if (file == null) {
			throw "PHP printer requires a file";
		}
		final lines = ["<?php"];
		if (file.strictTypes) {
			lines.push("");
			lines.push("declare(strict_types=1);");
		}
		if (file.namespace != null) {
			lines.push("");
			lines.push("namespace " + file.namespace.toString() + ";");
		}

		final declarations = file.declarations.copy();
		declarations.sort((left, right) -> Reflect.compare(stableDeclarationName(file, left), stableDeclarationName(file, right)));
		final renderedDeclarations = [];
		final declaredSymbols:Map<String, String> = [];
		for (declaration in declarations) {
			final stableName = stableDeclarationName(file, declaration);
			final symbolIdentity = declarationSymbolIdentity(file, declaration);
			if (declaredSymbols.exists(symbolIdentity)) {
				throw "Duplicate PHP declaration: " + declaredSymbols.get(symbolIdentity) + " and " + stableName;
			}
			declaredSymbols.set(symbolIdentity, stableName);
			lines.push("");
			final startLine = lines.length + 1;
			final rendered = printDeclaration(declaration);
			for (line in rendered.split("\n")) {
				lines.push(line);
			}
			renderedDeclarations.push(new PhpRenderedDeclaration(stableName, declarationSource(declaration), startLine, lines.length));
		}

		if (file.statements.length > 0) {
			lines.push("");
			for (line in printStatements(file.statements).split("\n")) {
				lines.push(line);
			}
		}
		return new PhpRenderedFile(file.path, lines.join("\n") + "\n", renderedDeclarations);
	}

	public function printDeclaration(declaration:PhpDeclaration):String {
		return switch (declaration) {
			case PhpFunctionDeclaration(value): printFunction(value);
			case PhpClassDeclaration(value): printClass(value);
		}
	}

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
			case PhpWhile(condition, body):
				prefix
				+ "while ( "
				+ printExpr(condition, depth)
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
			case PhpInvoke(callable, args):
				printExpr(callable, depth) + printCallArgs(args, depth);
			case PhpCallableArray(target, method):
				"array( " + printExpr(target, depth) + ", " + quote(method.value) + " )";
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
			case PhpClosure(parameters, captures, body, isStatic, returnType):
				printClosure(parameters, captures, body, isStatic, returnType, depth);
			case PhpReference(inner): "&" + printExpr(inner, depth);
			case PhpNot(inner): "! " + printExpr(inner, depth);
			case PhpCastArray(inner): "(array) " + printExpr(inner, depth);
			case PhpCastBool(inner): "(bool) " + printExpr(inner, depth);
			case PhpCastInt(inner): "(int) " + printExpr(inner, depth);
			case PhpCastString(inner): "(string) " + printExpr(inner, depth);
		}
	}

	function printFunction(declaration:PhpFunction):String {
		return "function "
			+ (declaration.returnsByReference ? "&" : "")
			+ declaration.name.value
			+ "("
			+ declaration.parameters.map(parameter -> printParameter(parameter, 0)).join(", ")
			+ ")"
			+ printReturnType(declaration.returnType)
			+ " {\n"
			+ printStatements(declaration.body, 1)
			+ "\n}";
	}

	function printClass(declaration:PhpClass):String {
		var header = switch (declaration.kind) {
			case PhpClassKindClass: "class ";
			case PhpClassKindInterface: "interface ";
			case PhpClassKindTrait: "trait ";
		}
		header += declaration.name.value;
		switch (declaration.kind) {
			case PhpClassKindClass:
				if (declaration.extendsName != null) {
					header += " extends " + declaration.extendsName.toString();
				}
				if (declaration.implementsNames.length > 0) {
					header += " implements " + declaration.implementsNames.map(name -> name.toString()).join(", ");
				}
			case PhpClassKindInterface:
				final parents = declaration.implementsNames.copy();
				if (declaration.extendsName != null) {
					parents.unshift(declaration.extendsName);
				}
				if (parents.length > 0) {
					header += " extends " + parents.map(name -> name.toString()).join(", ");
				}
			case PhpClassKindTrait:
		}

		final members = [];
		for (property in declaration.properties) {
			members.push(printProperty(property, 1));
		}
		for (method in declaration.methods) {
			members.push(printMethod(method, 1));
		}
		return header + " {\n" + members.join("\n\n") + "\n}";
	}

	function printProperty(property:PhpProperty, depth:Int):String {
		return tabs(depth)
			+ printVisibility(property.visibility)
			+ (property.isStatic ? " static" : "")
			+ " $"
			+ property.name.value
			+ (property.defaultValue == null ? "" : " = " + printExpr(property.defaultValue, depth))
			+ ";";
	}

	function printMethod(method:PhpMethod, depth:Int):String {
		final prefix = tabs(depth);
		final signature = prefix
			+ printVisibility(method.visibility)
			+ (method.isStatic ? " static" : "")
			+ " function "
			+ (method.returnsByReference ? "&" : "")
			+ method.name.value
			+ "("
			+ method.parameters.map(parameter -> printParameter(parameter, depth)).join(", ")
			+ ")"
			+ printReturnType(method.returnType);
		if (method.body == null) {
			return signature + ";";
		}
		return signature + " {\n" + printStatements(method.body, depth + 1) + "\n" + prefix + "}";
	}

	function printParameter(parameter:PhpParameter, depth:Int):String {
		if (parameter == null) {
			throw "PHP parameter cannot be null";
		}
		return (parameter.type == null ? "" : printType(parameter.type) + " ")
			+ (parameter.byReference ? "&" : "")
			+ (parameter.variadic ? "..." : "")
			+ "$"
			+ parameter.name.value
			+ (parameter.defaultValue == null ? "" : " = " + printExpr(parameter.defaultValue, depth));
	}

	function printReturnType(type:Null<PhpType>):String {
		return type == null ? "" : ": " + printType(type);
	}

	function printType(type:PhpType):String {
		return switch (type) {
			case PhpNamedType(name): name.toString();
			case PhpArrayType: "array";
			case PhpBoolType: "bool";
			case PhpCallableType: "callable";
			case PhpFloatType: "float";
			case PhpIntType: "int";
			case PhpIterableType: "iterable";
			case PhpObjectType: "object";
			case PhpStringType: "string";
			case PhpVoidType: "void";
			case PhpNullableType(inner):
				switch (inner) {
					case PhpVoidType | PhpNullableType(_): throw "Invalid nullable PHP type";
					case _: "?" + printType(inner);
				}
		}
	}

	function printVisibility(value:PhpVisibility):String {
		return switch (value) {
			case PhpPublic: "public";
			case PhpProtected: "protected";
			case PhpPrivate: "private";
		}
	}

	function stableDeclarationName(file:PhpFile, declaration:PhpDeclaration):String {
		final prefix = file.namespace == null ? "" : file.namespace.toString() + "\\";
		return switch (declaration) {
			case PhpFunctionDeclaration(value): "function:" + prefix + value.name.value;
			case PhpClassDeclaration(value):
				switch (value.kind) {
					case PhpClassKindClass: "class:" + prefix + value.name.value;
					case PhpClassKindInterface: "interface:" + prefix + value.name.value;
					case PhpClassKindTrait: "trait:" + prefix + value.name.value;
				}
		}
	}

	function declarationSymbolIdentity(file:PhpFile, declaration:PhpDeclaration):String {
		final namespace = file.namespace == null ? "" : file.namespace.toString() + "\\";
		return switch (declaration) {
			case PhpFunctionDeclaration(value): "function:" + (namespace + value.name.value).toLowerCase();
			case PhpClassDeclaration(value): "class-like:" + (namespace + value.name.value).toLowerCase();
		}
	}

	function declarationSource(declaration:PhpDeclaration) {
		return switch (declaration) {
			case PhpFunctionDeclaration(value): value.source;
			case PhpClassDeclaration(value): value.source;
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

	function printClosure(parameters:Array<PhpParameter>, captures:Array<PhpClosureCapture>, body:Array<PhpStmt>, isStatic:Bool, returnType:Null<PhpType>,
			depth:Int):String {
		if (parameters == null || captures == null || body == null) {
			throw "PHP closure fields cannot be null";
		}
		final validatedParameters = PhpParameter.validatedCopy(parameters);
		final captureNames:Map<String, Bool> = [];
		for (capture in captures) {
			if (capture == null) {
				throw "PHP closure captures cannot contain null";
			}
			if (captureNames.exists(capture.name.value)) {
				throw "Duplicate PHP closure capture: " + capture.name.value;
			}
			captureNames.set(capture.name.value, true);
		}
		final useClause = captures.length == 0 ? "" : " use ("
			+ captures.map(capture -> (capture.byReference ? "&" : "") + "$" + capture.name.value).join(", ")
			+ ")";
		return (isStatic ? "static " : "")
			+ "function ("
			+ validatedParameters.map(parameter -> printParameter(parameter, depth)).join(", ")
			+ ")"
			+ useClause
			+ printReturnType(returnType)
			+ " {\n"
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
