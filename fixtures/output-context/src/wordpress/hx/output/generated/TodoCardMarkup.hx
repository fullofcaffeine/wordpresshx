package wordpress.hx.output.generated;

import wordpress.hx.output.prototype.Output.CompilerMarkup;

/**
	Fixture stand-in for a compiler-generated HXX fragment.

	Application code can request this exact fragment but cannot manufacture a
	different fragment identity or source location.
**/
final class TodoCardMarkup {
	public static function create():CompilerMarkup {
		return new CompilerMarkup("TodoCard.render@fixture", "fixtures/output-context/test/Main.hx", 68, 41);
	}
}
