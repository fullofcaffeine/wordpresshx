<?php
/** Real WordPress SDK-033 asset/enqueue/translation probe. */

if ( 5 !== $argc ) {
	fwrite( STDERR, "usage: probe-assets.php <plugin-slug> <script-handle> <text-domain> <version>\n" );
	exit( 2 );
}

array_shift( $argv );
list( $plugin_slug, $script_handle, $text_domain, $expected_version ) = $argv;

define( 'WP_USE_THEMES', false );
require '/var/www/html/wp-load.php';

$plugin_root = WP_PLUGIN_DIR . '/' . $plugin_slug;
$plugin_file = $plugin_root . '/' . $plugin_slug . '.php';
$asset_file  = $plugin_root . '/build/editor.asset.php';

if ( ! is_file( $plugin_file ) || ! is_file( $asset_file ) ) {
	throw new RuntimeException( 'Generated SDK-033 plugin is incomplete.' );
}

require_once $plugin_file;
do_action( 'wp_enqueue_scripts' );

$asset   = require $asset_file;
$scripts = wp_scripts();
if ( ! isset( $scripts->registered[ $script_handle ] ) ) {
	throw new RuntimeException( 'Final SDK-033 script handle was not registered.' );
}

$registered = $scripts->registered[ $script_handle ];
if ( $registered->deps !== $asset['dependencies'] ) {
	throw new RuntimeException( 'Registered dependencies differ from final asset metadata.' );
}
if ( $registered->ver !== $asset['version'] || $registered->ver !== $expected_version ) {
	throw new RuntimeException( 'Registered version differs from final bundle hash.' );
}
if ( ! in_array( $script_handle, $scripts->queue, true ) ) {
	throw new RuntimeException( 'Final SDK-033 script was not enqueued.' );
}

$all_dependencies_registered = true;
foreach ( $asset['dependencies'] as $dependency ) {
	if ( ! isset( $scripts->registered[ $dependency ] ) ) {
		$all_dependencies_registered = false;
	}
}
if ( ! $all_dependencies_registered ) {
	throw new RuntimeException( 'A final-bundle dependency handle is absent in WordPress.' );
}

if ( ! $scripts->all_deps( array( $script_handle ) ) ) {
	throw new RuntimeException( 'WordPress could not resolve the final dependency graph.' );
}
$resolved_order = array_values( $scripts->to_do );
$final_position = array_search( $script_handle, $resolved_order, true );
if ( false === $final_position ) {
	throw new RuntimeException( 'Final handle is absent from the resolved dependency order.' );
}
$dependencies_before_final = true;
foreach ( $asset['dependencies'] as $dependency ) {
	$position = array_search( $dependency, $resolved_order, true );
	if ( false === $position || $position >= $final_position ) {
		$dependencies_before_final = false;
	}
}
if ( ! $dependencies_before_final ) {
	throw new RuntimeException( 'A direct dependency was not ordered before the final handle.' );
}

$translations_path = isset( $registered->translations_path )
	? $registered->translations_path
	: null;
$expected_translations_path = $plugin_root . '/languages';
if ( $registered->textdomain !== $text_domain ) {
	throw new RuntimeException( 'Translations were attached to the wrong text domain.' );
}
if ( $translations_path !== $expected_translations_path ) {
	throw new RuntimeException( 'Translations were attached to the wrong path.' );
}
$translation_javascript = $scripts->print_translations( $script_handle, false );
if (
	! is_string( $translation_javascript )
	|| false === strpos( $translation_javascript, $text_domain )
	|| false === strpos( $translation_javascript, 'Bundle metadata, under proof.' )
) {
	throw new RuntimeException( 'WordPress did not load the generated translation JSON.' );
}

ob_start();
$scripts->do_items( array( $script_handle ) );
$printed = ob_get_clean();
if ( ! is_string( $printed ) ) {
	throw new RuntimeException( 'Unable to capture the native WordPress script output.' );
}
$translation_marker = 'id="' . $script_handle . '-js-translations"';
$script_marker      = 'id="' . $script_handle . '-js"';
$translation_pos   = strpos( $printed, $translation_marker );
$script_pos        = strpos( $printed, $script_marker );
if ( false === $translation_pos || false === $script_pos || $translation_pos >= $script_pos ) {
	throw new RuntimeException( 'Translations were not printed before the final script tag.' );
}
if ( false === strpos( $printed, '/build/editor.js?ver=' . $expected_version ) ) {
	throw new RuntimeException( 'Final native script tag did not use the bundle-derived version.' );
}

$direct_order = array_values(
	array_filter(
		$resolved_order,
		static function ( $handle ) use ( $asset, $script_handle ) {
			return $script_handle === $handle || in_array( $handle, $asset['dependencies'], true );
		}
	)
);

global $wp_version;
echo wp_json_encode(
	array(
		'asset' => array(
			'dependencies' => $asset['dependencies'],
			'version'      => $asset['version'],
		),
		'check' => 'wordpresshx-sdk033-wordpress-assets-v1',
		'dependencyOrder' => array(
			'directAndFinal'          => $direct_order,
			'directBeforeFinal'       => $dependencies_before_final,
			'resolvedHandleCount'     => count( $resolved_order ),
		),
		'enqueue' => array(
			'handle'              => $script_handle,
			'queued'              => true,
			'registered'          => true,
			'scriptTagVersioned'  => true,
		),
		'phpVersion' => PHP_VERSION,
		'profileId' => 'wp70-release',
		'translations' => array(
			'domain'             => $registered->textdomain,
			'loaded'             => true,
			'path'               => str_replace( $plugin_root . '/', '', $translations_path ),
			'printedBeforeScript' => true,
		),
		'wordpressVersion' => $wp_version,
	),
	JSON_UNESCAPED_SLASHES
);
