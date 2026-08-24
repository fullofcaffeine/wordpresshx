package wordpress.hx.compiler.php.profile;

/**
 * Closed lifecycle plan for one standard or must-use WordPress plugin.
 *
 * The schema option is the only migration checkpoint. Each declared step must
 * be contiguous so a failed step can be retried without skipping work.
 */
class WordPressPluginLifecyclePlan {
	static final OPTION_NAME = ~/^[a-z][a-z0-9_]{0,190}$/;

	public final plugin:PluginBootstrapPlan;
	public final installKind:WordPressPluginInstallKind;
	public final schemaOption:String;
	public final targetSchemaVersion:Int;
	public final uninstallPolicy:WordPressUninstallPolicy;
	public final rootPath:String;
	public final autoloadPath:String;
	public final bootstrapPath:String;
	public final lifecyclePath:String;
	public final uninstallPath:Null<String>;
	public final lifecycleClass:String;
	public final absoluteLifecycleClass:String;

	final upgradeStepValues:Array<WordPressPluginUpgradeStep>;
	final uninstallOptionValues:Array<String>;

	public var upgradeSteps(get, never):Array<WordPressPluginUpgradeStep>;
	public var uninstallOptions(get, never):Array<String>;

	public function new(plugin:PluginBootstrapPlan, installKind:WordPressPluginInstallKind, schemaOption:String, targetSchemaVersion:Int,
			upgradeSteps:Array<WordPressPluginUpgradeStep>, uninstallPolicy:WordPressUninstallPolicy, uninstallOptions:Array<String>) {
		if (plugin == null || installKind == null || schemaOption == null || upgradeSteps == null || uninstallPolicy == null || uninstallOptions == null) {
			throw "WordPress plugin lifecycle plan requires every closed inventory";
		}
		if (!OPTION_NAME.match(schemaOption)) {
			throw "WordPress plugin lifecycle schema option is not a safe option name";
		}
		if (targetSchemaVersion < 1 || upgradeSteps.length != targetSchemaVersion) {
			throw "WordPress plugin lifecycle requires one contiguous step per target schema version";
		}
		for (index in 0...upgradeSteps.length) {
			final step = upgradeSteps[index];
			if (step == null || step.fromVersion != index || step.toVersion != index + 1) {
				throw "WordPress plugin lifecycle upgrade steps must be ordered and contiguous";
			}
		}

		final checkedOptions = checkedUninstallOptions(uninstallOptions);
		switch (uninstallPolicy) {
			case RetainPluginData:
				if (checkedOptions.length != 0) {
					throw "Retained WordPress plugin data cannot declare uninstall deletions";
				}
			case DeleteDeclaredPluginData:
				if (installKind == MustUsePlugin) {
					throw "Must-use plugins have no native uninstall lifecycle";
				}
				if (checkedOptions.indexOf(schemaOption) == -1) {
					throw "WordPress uninstall deletions must include the schema option";
				}
		}

		this.plugin = plugin;
		this.installKind = installKind;
		this.schemaOption = schemaOption;
		this.targetSchemaVersion = targetSchemaVersion;
		this.uninstallPolicy = uninstallPolicy;
		this.upgradeStepValues = upgradeSteps.copy();
		this.uninstallOptionValues = checkedOptions;
		this.lifecycleClass = plugin.namespace.toString() + "\\Lifecycle";
		this.absoluteLifecycleClass = "\\" + lifecycleClass;
		switch (installKind) {
			case StandardPlugin:
				this.rootPath = plugin.rootPath;
				this.autoloadPath = plugin.autoloadPath;
				this.bootstrapPath = plugin.bootstrapPath;
				this.lifecyclePath = "includes/Lifecycle.php";
				this.uninstallPath = "uninstall.php";
			case MustUsePlugin:
				this.rootPath = plugin.rootPath;
				this.autoloadPath = plugin.slug + "/" + plugin.autoloadPath;
				this.bootstrapPath = plugin.slug + "/" + plugin.bootstrapPath;
				this.lifecyclePath = plugin.slug + "/includes/Lifecycle.php";
				this.uninstallPath = null;
		}
	}

	static function checkedUninstallOptions(values:Array<String>):Array<String> {
		final checked = values.copy();
		final seen:Map<String, Bool> = [];
		for (value in checked) {
			if (value == null || !OPTION_NAME.match(value)) {
				throw "WordPress uninstall option is not a safe option name";
			}
			if (seen.exists(value)) {
				throw "Duplicate WordPress uninstall option: " + value;
			}
			seen.set(value, true);
		}
		checked.sort((left, right) -> left < right ? -1 : left > right ? 1 : 0);
		return checked;
	}

	function get_upgradeSteps():Array<WordPressPluginUpgradeStep> {
		return upgradeStepValues.copy();
	}

	function get_uninstallOptions():Array<String> {
		return uninstallOptionValues.copy();
	}
}
