<?php
/** Prepare a real WordPress 7.0 site for SDK-055 locale proof. */

if ( 3 !== $argc ) {
	fwrite( STDERR, "usage: setup.php <plugin-slug> <site-url>\n" );
	exit( 2 );
}

$plugin_slug = $argv[1];
$site_url    = $argv[2];
if ( ! preg_match( '/^[a-z0-9]+(?:-[a-z0-9]+)*$/', $plugin_slug ) ) {
	throw new InvalidArgumentException( 'Unsafe SDK-055 plugin slug.' );
}
if ( false === filter_var( $site_url, FILTER_VALIDATE_URL ) || 'http' !== parse_url( $site_url, PHP_URL_SCHEME ) ) {
	throw new InvalidArgumentException( 'Unsafe SDK-055 site URL.' );
}

define( 'WP_USE_THEMES', false );
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin_file = $plugin_slug . '/' . $plugin_slug . '.php';
$plugin_mo = WP_PLUGIN_DIR . '/' . $plugin_slug . '/languages/' . $plugin_slug . '-es_MX.mo';
if ( ! is_file( $plugin_mo ) ) {
	throw new RuntimeException( 'The generated SDK-055 Spanish MO file is absent.' );
}
wp_mkdir_p( WP_LANG_DIR );
if ( ! copy( $plugin_mo, WP_LANG_DIR . '/es_MX.mo' ) ) {
	throw new RuntimeException( 'Unable to admit the deterministic SDK-055 locale fixture.' );
}
wp_cache_delete( md5( WP_LANG_DIR . '/' ), 'translation_files' );
update_option( 'WPLANG', 'es_MX' );
update_option( 'home', $site_url );
update_option( 'siteurl', $site_url );
$activation = activate_plugin( $plugin_file );
if ( is_wp_error( $activation ) ) {
	throw new RuntimeException( $activation->get_error_message() );
}

$post_id = wp_insert_post(
	array(
		'post_title'   => 'SDK-055 translation probe',
		'post_content' => '<p>SDK-055</p>',
		'post_status'  => 'publish',
		'post_type'    => 'post',
	),
	true
);
if ( is_wp_error( $post_id ) ) {
	throw new RuntimeException( $post_id->get_error_message() );
}

global $wp_version;
echo wp_json_encode(
	array(
		'check'            => 'wordpresshx-sdk055-setup-v1',
		'homeUrl'          => home_url(),
		'locale'           => get_option( 'WPLANG' ),
		'pluginActive'     => is_plugin_active( $plugin_file ),
		'postId'           => $post_id,
		'wordpressVersion' => $wp_version,
	),
	JSON_UNESCAPED_SLASHES
);
