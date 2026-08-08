package wordpress.hx.contracts;

/**
	Result of projecting the closed wire algebra into JSON bytes.

		A `JsonEncoded` value returned directly by `CanonicalWireJson.encodeChecked`
		is safe to give to a native JSON decoder. The public enum constructor is a
		transport shape. It does not give authority to caller-authored bytes.
**/
enum WireJsonEncoding {
	JsonEncoded(value:String);
	JsonRejected(reason:String);
}
