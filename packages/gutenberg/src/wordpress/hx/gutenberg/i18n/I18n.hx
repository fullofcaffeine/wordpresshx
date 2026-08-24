package wordpress.hx.gutenberg.i18n;

/** Exact @wordpress/i18n gettext and formatting boundary. */
@:jsRequire("@wordpress/i18n", "__")
extern function __(message:String, textDomain:String):String;

@:jsRequire("@wordpress/i18n", "_x")
extern function _x(message:String, context:String, textDomain:String):String;

@:jsRequire("@wordpress/i18n", "_n")
extern function _n(singular:String, plural:String, count:Int, textDomain:String):String;

@:jsRequire("@wordpress/i18n", "_nx")
extern function _nx(singular:String, plural:String, count:Int, context:String, textDomain:String):String;

@:jsRequire("@wordpress/i18n", "sprintf")
@:overload(function(format:String, value:Int):String {})
extern function sprintf(format:String, value:String):String;
