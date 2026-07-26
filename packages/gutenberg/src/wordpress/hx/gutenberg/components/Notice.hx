package wordpress.hx.gutenberg.components;

/**
 * Exact `@wordpress/components` 32.2.0 named export admitted by wp70-release.
 *
 * `@:genes.jsxComponentProps` gives Genes the closed Haxe contract for Notice
 * markup. It changes compile-time JSX validation only; generated code keeps the
 * native `@wordpress/components` value and adds no runtime wrapper.
 */
@:genes.jsxComponentProps("wordpress.hx.gutenberg.components.NoticeProps")
@:jsRequire("@wordpress/components", "Notice")
extern class Notice {}
