package wordpress.hx.compiler.php.profile;

/** Explicit data policy applied when a standard plugin is uninstalled. */
enum WordPressUninstallPolicy {
	RetainPluginData;
	DeleteDeclaredPluginData;
}
