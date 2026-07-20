package wordpress.hx.contracts;

import haxe.iterators.StringIteratorUnicode;

/** Target-independent lexicographic ordering over Unicode scalar values. */
class UnicodeScalarOrder {
	public static function compare(left:String, right:String):Int {
		final leftScalars = new StringIteratorUnicode(left);
		final rightScalars = new StringIteratorUnicode(right);
		while (leftScalars.hasNext() && rightScalars.hasNext()) {
			final leftScalar = leftScalars.next();
			final rightScalar = rightScalars.next();
			if (leftScalar < rightScalar) {
				return -1;
			}
			if (leftScalar > rightScalar) {
				return 1;
			}
		}
		return leftScalars.hasNext() ? 1 : rightScalars.hasNext() ? -1 : 0;
	}
}
