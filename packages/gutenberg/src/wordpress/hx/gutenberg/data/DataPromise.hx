package wordpress.hx.gutenberg.data;

/** Native browser promise returned by WordPress data dispatchers. */
@:ts.type("Promise<$0>")
extern class DataPromise<T> {
	public function then<Result>(fulfilled:T->Result):DataPromise<Result>;
}
