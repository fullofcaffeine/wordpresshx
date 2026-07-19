package wordpresshx.cli.project;

import wordpresshx.cli.Content;

/** Stable package-specific namespace derived from authenticated Haxe identity. */
class PluginPrivateRuntimeIdentity {
	public static inline final SCHEMA = "wordpress-hx.private-runtime.v1";
	public static inline final MODULE_ID = "plugin";
	static final PREFIX = ~/^wphx_internal\.p[0-9a-f]{24}$/;

	public final projectId:String;
	public final moduleId:String;
	public final derivationSha256:String;
	public final prefix:String;
	public final prefixPath:String;

	public static function derive(plan:PluginPlan):PluginPrivateRuntimeIdentity {
		final derivationSha256 = Content.digest(SCHEMA + "\x00" + plan.slug + "\x00" + MODULE_ID);
		final prefix = "wphx_internal.p" + derivationSha256.substr(0, 24);
		if (!PREFIX.match(prefix)) {
			throw new wordpresshx.cli.CliFailure("WPHX5200", "derived private PHP namespace is outside the accepted identity contract", 6,
				"private-php-emission");
		}
		return new PluginPrivateRuntimeIdentity(plan.slug, MODULE_ID, derivationSha256, prefix);
	}

	function new(projectId:String, moduleId:String, derivationSha256:String, prefix:String) {
		this.projectId = projectId;
		this.moduleId = moduleId;
		this.derivationSha256 = derivationSha256;
		this.prefix = prefix;
		this.prefixPath = prefix.split(".").join("/");
	}

	public function phpClass(className:String):String {
		return prefix.split(".").join("\\") + "\\" + className.split(".").join("\\");
	}
}
