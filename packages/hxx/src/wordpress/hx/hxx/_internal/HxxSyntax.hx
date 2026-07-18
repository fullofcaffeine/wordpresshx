package wordpress.hx.hxx._internal;

#if macro
import haxe.macro.Expr;

/**
 * Parser-neutral positioned syntax consumed by the native HXX lowerers.
 *
 * The public SDK never exposes these internal types. They deliberately retain
 * Haxe expressions and source positions while keeping every `tink_hxx` type
 * behind `HxxParserAdapter`.
 */
typedef HxxSyntaxName = {
	final value:String;
	final pos:Position;
}

typedef HxxSyntaxChildren = {
	final items:Array<HxxSyntaxChild>;
	final pos:Position;
}

typedef HxxSyntaxChild = {
	final kind:HxxSyntaxChildKind;
	final pos:Position;
}

typedef HxxSyntaxNode = {
	final name:HxxSyntaxName;
	final attributes:Array<HxxSyntaxAttribute>;
	final children:Null<HxxSyntaxChildren>;
	final pos:Position;
}

typedef HxxSyntaxSwitchCase = {
	final values:Array<Expr>;
	final guard:Null<Expr>;
	final children:HxxSyntaxChildren;
}

enum HxxSyntaxAttribute {
	Spread(value:Expr);
	Empty(name:HxxSyntaxName);
	Regular(name:HxxSyntaxName, value:Expr);
}

enum HxxSyntaxChildKind {
	Let(variables:Array<HxxSyntaxAttribute>, children:HxxSyntaxChildren);
	If(condition:Expr, consequent:HxxSyntaxChildren, alternative:Null<HxxSyntaxChildren>);
	For(head:Expr, body:HxxSyntaxChildren);
	Switch(target:Expr, cases:Array<HxxSyntaxSwitchCase>);
	Node(node:HxxSyntaxNode);
	Text(value:HxxSyntaxName);
	Expression(value:Expr);
	ChildSpread(value:Expr);
}
#end
