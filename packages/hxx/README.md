# HXX source module

This directory is the compile-time HXX source boundary inside the single `wordpress-hx` Haxelib. SDK-080 contains an evidence prototype, not the supported production renderer: it proves that canonical Haxe 4 inline markup can pass through an internal parser adapter, retain useful source spans, type embedded expressions/props/children/slots/closed spreads, reject target leakage, and disappear from emitted PHP and JavaScript artifacts.

The exact parser closure is [`dependency-lock.json`](dependency-lock.json). It pins `tink_hxx` 0.25.1 and all five selected transitives from the upstream tag's own scoped Lix files. Haxelib artifacts are content-hashed; Git inputs are commit-and-tree pinned. The package-local `.haxerc` and `haxe_libraries/*.hxml` forbid global `haxelib dev`, floating ranges, and sibling paths.

Only `tink.hxx.Parser` and its positioned syntax types are consumed inside `wordpress.hx.hxx._internal.HxxParserAdapter`. No Tink type is public. The prototype component catalog (`Panel`, `Inline`, `ServerFragment`, and `BrowserWidget`) is deliberately neutral evidence data and is not a WordPress SDK API. SDK-081 replaces the serialized evidence plan with the generic `reflaxe.php` typed markup IR plus WordPress adapters; SDK-032 owns the Genes browser lowering.

The server and browser entry points return distinct evidence-only result types. Their committed snapshots must have the same target-neutral semantic digest and relative spans, while target-only components fail closed. The generated-output scan rejects parser, Coconut, VDOM, registry, and template-resolver leakage.

Run the complete gate with:

```bash
bash packages/hxx/scripts/test.sh
```

The gate requires Haxe 4.3.7, Lix 15.12.2, PHP, Node, Git, network access for clean dependency materialization, and formatter 1.18.0. `for`, `switch`, `let`, nested markup inside expressions, native output lowering, full HTML/ARIA typing, and output-context escaping remain intentionally outside this parser-decision prototype and fail explicitly or remain owned by later beads.
