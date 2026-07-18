# Gutenberg and browser source module

This directory owns the WordPressHx browser profile inside the assembled
wordpress-hx Haxelib. It is not a separately published package.

SDK-031 establishes the first bounded compiler/profile fixture:

- exact Genes v1.36.3 source at its immutable release commit, admitted through
  the generalized Array-index fix in upstream PR #3;
- Haxe 4.3.7 and a scoped Lix dependency graph;
- exact Node 22.17.0, npm 10.9.2, TypeScript 5.9.3, and esbuild 0.27.2
  verification tooling;
- strict split-ESM TypeScript as the primary source lane;
- classic split-ESM JavaScript plus declarations as a bounded differential;
- an SDK-owned Haxe export directive projected to the generic
  @:genes.library retention contract;
- full-DCE public facade retention and private-member removal;
- binding-free side-effect and live ESM import behavior; and
- an ordinary JavaScript caller of both bundled outputs.

The SDK-030 Genes v1.33.0 receipt remains the historical compiler-selection
baseline. This package's dependency lock records the later baseline -> fix ->
merge -> release chain; it does not rewrite that earlier receipt or read from a
mutable sibling checkout.

The exact upstream and package proof is recorded in
[`SDK-031-STRICT-BROWSER-PROFILE`](../../manifests/evidence/sdk-031-strict-browser-profile.json).

The fixture is intentionally independent of WordPress package symbols.
WordPress package externs and React/Gutenberg HXX belong to SDK-032; official
dependency extraction, handles, asset PHP, and translations belong to SDK-033.
This boundary ensures a failure can be reduced to Genes without adding
WordPress names to the generic compiler.

The Haxe source remains the application authoring surface. TypeScript and
JavaScript under test/consumer and test/runtime are external-consumer/native
module fixtures, not required application source.

Run the complete gate from the repository root:

~~~sh
bash packages/gutenberg/scripts/test.sh
~~~

The gate downloads only checksum/commit-locked inputs, writes generated output
under temporary directories, and executes the Node portion inside the exact
content-addressed image selected by ADR-013. Its committed artifact inventory
also detects byte drift in the replayed generated tree and both browser
bundles, in addition to semantic, runtime, DCE, and size checks.
