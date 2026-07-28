package wordpress.hx.contracts;

/**
	Result of projecting the closed wire algebra into JSON bytes.

	A success is safe to hand to a native JSON decoder. A rejection keeps the
	failure explicit instead of publishing bytes with a weaker invariant.
**/
enum WireJsonEncoding {
	JsonEncoded(value:String);
	JsonRejected(reason:String);
}
