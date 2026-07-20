package wordpress.hx.contracts;

/** Represents an explicit wire null without relying on target null semantics. */
enum NullableValue<T> {
	ExplicitNull;
	NonNull(value:T);
}
