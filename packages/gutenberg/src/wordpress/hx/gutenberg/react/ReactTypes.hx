package wordpress.hx.gutenberg.react;

import genes.ts.Unknown;
import wordpress.hx.gutenberg.browser.BrowserNode;

/** Canonical React child boundary retained in generated TypeScript. */
@:ts.type("import('react').ReactNode")
abstract ReactNode(Dynamic) from String from Int from Float from Bool from BrowserNode to Dynamic {
	@:from
	public static inline function fromChildren(value:Array<ReactNode>):ReactNode {
		return cast value;
	}
}

/** React reconciliation identity retained as the canonical string/number union. */
@:ts.type("import('react').Key")
abstract ReactKey(Dynamic) from String from Int to Dynamic {}

/** React synthetic mouse event with its concrete DOM target preserved. */
@:ts.type("import('react').MouseEvent<$0>")
extern class ReactMouseEvent<T> {
	public function preventDefault():Void;
	public function stopPropagation():Void;
}

/** React keyboard event with its concrete DOM target preserved. */
@:ts.type("import('react').KeyboardEvent<$0>")
extern class ReactKeyboardEvent<T> {
	public final key:String;
	public function preventDefault():Void;
}

/** Read-only React object ref returned by the admitted `useRef` overload. */
@:ts.type("import('react').RefObject<$0>")
extern class ReactRefObject<T> {
	public final current:Null<T>;
}

/** Profile-admitted React context value supplied by `@wordpress/element`. */
@:ts.type("import('react').Context<$0>")
extern class ReactContext<T> {}

/** React hook dependency list; its entries remain `unknown`, never `any`. */
@:ts.type("import('react').DependencyList")
typedef HookDependencies = Array<Unknown>;

/**
 * Typed view over the tuple returned by React's `useState`.
 *
 * The dynamic storage is erased by the canonical TypeScript tuple projection;
 * callers only see `value` and the typed setter.
 */
@:ts.type("[ $0, import('react').Dispatch<import('react').SetStateAction<$0>> ]")
abstract State<T>(Array<Dynamic>) {
	public var value(get, never):T;

	private inline function get_value():T {
		return cast this[0];
	}

	public inline function set(next:T):Void {
		final setter:T->Void = cast this[1];
		setter(next);
	}
}
