<?php

declare(strict_types=1);

require_once '/var/www/html/wp-load.php';

global $wpdb, $wp_version;

$query_result = $wpdb->get_var('SELECT 1');
$database_server_version = $wpdb->get_var('SELECT VERSION()');
$payload = array(
    'databaseQuery' => (int) $query_result,
    'databaseServerVersion' => $database_server_version,
    'installed' => is_blog_installed(),
    'phpVersion' => PHP_VERSION,
    'profileId' => 'wp70-release',
    'seed' => get_option('wordpresshx_harness_seed'),
    'wordpressVersion' => $wp_version,
);

echo wp_json_encode($payload, JSON_UNESCAPED_SLASHES), "\n";
