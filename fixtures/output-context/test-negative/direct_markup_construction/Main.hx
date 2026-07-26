import wordpress.hx.output.prototype.Output.CompilerMarkup;
import wordpress.hx.output.prototype.Output.ResolvedHxxAst;

final class Main {
	static function main():Void {}

	static function forge(ast:ResolvedHxxAst):CompilerMarkup {
		return new CompilerMarkup("forged", "Main.hx", 8, 3, ast);
	}
}
