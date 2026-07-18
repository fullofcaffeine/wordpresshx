package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;

/** Closed SDK-022 file/symbol plan for one wp70-release plugin bootstrap. **/
class PluginBootstrapPlan {
	static final SLUG = ~/^[a-z0-9]+(?:-[a-z0-9]+)*$/;

	public final profileId:String;
	public final slug:String;
	public final header:PluginHeader;
	public final namespace:PhpQualifiedName;
	public final source:PhpSourceRange;
	public final rootPath:String;
	public final autoloadPath:String;
	public final bootstrapPath:String;
	public final bootstrapClass:String;
	public final absoluteBootstrapClass:String;

	public function new(slug:String, header:PluginHeader, namespace:PhpQualifiedName, source:PhpSourceRange) {
		if (slug == null || !SLUG.match(slug)) {
			throw "Plugin bootstrap requires a lowercase WordPress slug";
		}
		if (header == null || namespace == null || source == null) {
			throw "Plugin bootstrap plan requires header, namespace, and source";
		}
		if (namespace.absolute) {
			throw "Plugin bootstrap namespace must be relative";
		}
		if (header.textDomain != slug) {
			throw "Plugin Text Domain must match the plugin slug";
		}
		if (header.requiresWordPress != "7.0" || header.requiresPhp != "7.4") {
			throw "wp70-release bootstrap requires WordPress 7.0 and PHP 7.4 headers";
		}
		this.profileId = "wp70-release";
		this.slug = slug;
		this.header = header;
		this.namespace = namespace;
		this.source = source;
		this.rootPath = slug + ".php";
		this.autoloadPath = "includes/autoload.php";
		this.bootstrapPath = "includes/Bootstrap.php";
		this.bootstrapClass = namespace.toString() + "\\Bootstrap";
		this.absoluteBootstrapClass = "\\" + bootstrapClass;
	}
}
