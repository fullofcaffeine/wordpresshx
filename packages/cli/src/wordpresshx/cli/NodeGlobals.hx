package wordpresshx.cli;

import js.Syntax;
import js.node.Process;

/** Typed access to the Node process global without deprecated inline interop. **/
class NodeGlobals {
	public static inline function process():Process {
		return cast Syntax.code("process");
	}
}
