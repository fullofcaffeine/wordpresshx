package wordpress.hx.contracts;

/** Distinguishes an absent wire field from every present value, including null. */
enum Presence<T> {
	Missing;
	Present(value:T);
}
