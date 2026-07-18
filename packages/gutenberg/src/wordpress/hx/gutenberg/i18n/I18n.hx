package wordpress.hx.gutenberg.i18n;

/** Exact @wordpress/i18n gettext boundary. Typed message keys follow in SDK-055. */
@:jsRequire("@wordpress/i18n", "__")
extern function __(message:String, textDomain:String):String;
