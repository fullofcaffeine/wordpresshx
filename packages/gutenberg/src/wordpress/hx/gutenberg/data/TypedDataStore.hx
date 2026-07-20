package wordpress.hx.gutenberg.data;

/**
 * Opaque descriptor created and owned by `@wordpress/data`.
 *
 * `State` is the immutable application snapshot and `Action` is the closed
 * command union accepted by its reducer.
 */
@:ts.type("import('@wordpress/data').StoreDescriptor<import('@wordpress/data').ReduxStoreConfig<$0, { dispatchAction: (action: $1) => $1 }, { getState: (state: $0) => $0 }>>")
extern class TypedDataStore<State, Action> {}
