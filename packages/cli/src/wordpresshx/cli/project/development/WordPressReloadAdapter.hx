package wordpresshx.cli.project.development;

/** Private development-only WordPress bridge derived by the Haxe provider. */
class WordPressReloadAdapter {
	public final clientUrl:String;
	public final eventsUrl:String;

	public function new(clientUrl:String, eventsUrl:String) {
		this.clientUrl = clientUrl;
		this.eventsUrl = eventsUrl;
	}

	public static function pluginSource():String {
		return [
			"<?php",
			"declare(strict_types=1);",
			"",
			"(static function (): void {",
			"if (!defined('ABSPATH')) {",
			"\texit;",
			"}",
			"",
			"$wordpresshx_client = getenv('WPHX_DEV_RELOAD_CLIENT');",
			"$wordpresshx_events = getenv('WPHX_DEV_RELOAD_EVENTS');",
			"$wordpresshx_plugin = getenv('WPHX_DEV_PLUGIN_ENTRY');",
			"if (!is_string($wordpresshx_client) || $wordpresshx_client === '' || !is_string($wordpresshx_events) || $wordpresshx_events === '') {",
			"\treturn;",
			"}",
			"",
			"if (PHP_SAPI !== 'cli' && is_string($wordpresshx_plugin) && $wordpresshx_plugin !== '') {",
			"\tadd_action('plugins_loaded', static function () use ($wordpresshx_plugin): void {",
			"\t\t$wordpresshx_active = get_option('active_plugins', array());",
			"\t\tif (!is_array($wordpresshx_active) || !in_array($wordpresshx_plugin, $wordpresshx_active, true)) {",
			"\t\t\tstatus_header(503);",
			"\t\t\theader('Cache-Control: no-store');",
			"\t\t\theader('Content-Type: text/plain; charset=utf-8');",
			"\t\t\techo 'generated plugin is not active';",
			"\t\t\texit;",
			"\t\t}",
			"\t\theader('X-WordPressHx-Plugin: ' . $wordpresshx_plugin);",
			"\t}, PHP_INT_MIN);",
			"}",
			"",
			"$wordpresshx_render_reload = static function () use ($wordpresshx_client, $wordpresshx_events): void {",
			"\tprintf(",
			"\t\t'<script src=\"%s\" data-wordpresshx-reload-events=\"%s\" async></script>',",
			"\t\tesc_url($wordpresshx_client),",
			"\t\tesc_url($wordpresshx_events)",
			"\t);",
			"};",
			"",
			"add_action('wp_footer', $wordpresshx_render_reload, PHP_INT_MAX);",
			"add_action('admin_footer', $wordpresshx_render_reload, PHP_INT_MAX);",
			"add_action('login_footer', $wordpresshx_render_reload, PHP_INT_MAX);",
			"})();",
			""
		].join("\n");
	}
}
