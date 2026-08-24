<?php
/** Fresh-request server and script-translation observer for SDK-055. */

if ( 4 !== $argc ) {
	fwrite( STDERR, "usage: probe.php <mode> <script-handle> <text-domain>\n" );
	exit( 2 );
}

list( , $mode, $script_handle, $text_domain ) = $argv;
if ( ! in_array( $mode, array( 'editor', 'frontend' ), true ) ) {
	throw new InvalidArgumentException( 'Unknown SDK-055 probe mode.' );
}

define( 'WP_USE_THEMES', false );
require '/var/www/html/wp-load.php';

if ( 'es_MX' !== get_locale() ) {
	throw new RuntimeException( 'The SDK-055 Spanish locale was not selected on a fresh request.' );
}
if ( ! function_exists( 'wordpresshx_sdk055_render_messages' ) ) {
	throw new RuntimeException( 'The generated SDK-055 server adapter is absent.' );
}

$one = wordpresshx_sdk055_render_messages( 1, 'Atlas' );
$many = wordpresshx_sdk055_render_messages( 3, 'Atlas' );
if ( ! is_textdomain_loaded( $text_domain ) ) {
	throw new RuntimeException( 'The SDK-055 Spanish text domain was not loaded by native gettext.' );
}
$expected_one = array(
	'books.count'       => '1 libro',
	'books.open-action' => 'Abrir',
	'books.open-title'  => 'Abrir Atlas',
	'books.ready'       => 'Biblioteca lista.',
	'books.shelf-count' => '1 elemento de estante',
);
$expected_many = array(
	'books.count'       => '3 libros',
	'books.open-action' => 'Abrir',
	'books.open-title'  => 'Abrir Atlas',
	'books.ready'       => 'Biblioteca lista.',
	'books.shelf-count' => '3 elementos de estante',
);
if ( $one !== $expected_one || $many !== $expected_many ) {
	throw new RuntimeException( 'Native PHP gettext output differs from the typed catalog.' );
}

$hook = 'editor' === $mode ? 'enqueue_block_editor_assets' : 'wp_enqueue_scripts';
do_action( $hook );
$scripts = wp_scripts();
if ( ! isset( $scripts->registered[ $script_handle ] ) ) {
	throw new RuntimeException( 'The SDK-055 final browser handle was not registered.' );
}
$registered = $scripts->registered[ $script_handle ];
if (
	array( 'wp-i18n' ) !== $registered->deps
	|| $registered->textdomain !== $text_domain
	|| $registered->translations_path !== WP_PLUGIN_DIR . '/wordpresshx-sdk055/languages'
	|| ! in_array( $script_handle, $scripts->queue, true )
) {
	throw new RuntimeException( 'The SDK-055 script translation attachment drifted.' );
}
$translation_javascript = $scripts->print_translations( $script_handle, false );
if ( ! is_string( $translation_javascript ) ) {
	throw new RuntimeException( 'WordPress did not emit SDK-055 browser locale data.' );
}
foreach ( array( 'Biblioteca lista.', 'Abrir %1$s', '%1$d libros', '%1$d elementos de estante' ) as $translation ) {
	if ( false === strpos( $translation_javascript, $translation ) ) {
		throw new RuntimeException( 'WordPress browser locale data omitted an SDK-055 translation.' );
	}
}

global $wp_version;
echo wp_json_encode(
	array(
		'check'                   => 'wordpresshx-sdk055-wordpress-i18n-v1',
		'handle'                  => $script_handle,
		'hook'                    => $hook,
		'locale'                  => get_locale(),
		'mode'                    => $mode,
		'serverMany'              => $many,
		'serverOne'               => $one,
		'textDomain'              => $registered->textdomain,
		'translationScriptBytes'  => strlen( $translation_javascript ),
		'wordpressVersion'        => $wp_version,
	),
	JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
);
