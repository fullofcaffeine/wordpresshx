package wordpress.hx.gutenberg.react;

import haxe.extern.EitherType;
import wordpress.hx.gutenberg.browser.BrowserNode;

@:genes.compilerInternal
@:genes.semanticOnly
private typedef ReactNodeScalar = EitherType<BrowserNode, EitherType<String, EitherType<Float, Bool>>>;

@:genes.compilerInternal
@:genes.semanticOnly
private abstract ReactNodeList(Array<ReactNode>) from Array<ReactNode> {}

@:genes.compilerInternal
@:genes.semanticOnly
private typedef ReactNodeValue = EitherType<ReactNodeScalar, ReactNodeList>;

/** Canonical React child boundary retained in generated TypeScript. */
@:ts.type("import('react').ReactNode")
@:genes.jsxNode
abstract ReactNode(ReactNodeValue) from String from Float from Bool from BrowserNode from ReactNodeList {
	@:from
	public static inline function fromChildren(value:Array<ReactNode>):ReactNode {
		final children:ReactNodeList = value;
		return children;
	}
}

/** React reconciliation identity retained as the canonical string/number union. */
@:ts.type("import('react').Key")
abstract ReactKey(EitherType<String, Int>) from String from Int {}

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
typedef ReactContext<T> = genes.react.Context<T>;

/** React hook dependency list; its entries remain `unknown`, never `any`. */
typedef HookDependencies = genes.react.DependencyList<genes.ts.Unknown>;

/** Typed view over the tuple returned by React's `useState`. */
typedef State<T> = genes.react.State<T>;
