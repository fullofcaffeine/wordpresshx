package wordpress.hx.gutenberg.react;

import wordpress.hx.gutenberg.react.ReactTypes.HookDependencies;
import wordpress.hx.gutenberg.react.ReactTypes.ReactContext;
import wordpress.hx.gutenberg.react.ReactTypes.ReactRefObject;
import wordpress.hx.gutenberg.react.ReactTypes.State;

@:jsRequire("@wordpress/element", "createContext")
extern function createContext<T>(defaultValue:T):ReactContext<T>;

@:jsRequire("@wordpress/element", "useContext")
extern function useContext<T>(context:ReactContext<T>):T;

@:jsRequire("@wordpress/element", "useEffect")
extern function useEffect(effect:Void->Void, dependencies:HookDependencies):Void;

@:jsRequire("@wordpress/element", "useRef")
extern function useRef<T>(initialValue:Null<T>):ReactRefObject<T>;

@:jsRequire("@wordpress/element", "useState")
extern function useState<T>(initialValue:T):State<T>;
