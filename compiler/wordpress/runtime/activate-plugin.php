<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: activate-plugin.php <plugin> <bootstrap-class>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/wp-admin/plugins.php';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

define('WORDPRESSHX_FIXTURE_PLUGIN', $argv[1]);
define('WORDPRESSHX_FIXTURE_BOOTSTRAP_CLASS', $argv[2]);

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin = WORDPRESSHX_FIXTURE_PLUGIN;
$bootstrap_class = WORDPRESSHX_FIXTURE_BOOTSTRAP_CLASS;
$plugin_file = WP_PLUGIN_DIR . '/' . $plugin;
$header = get_plugin_data($plugin_file, false, false);

ob_start();
$result = activate_plugin($plugin, '', false, false);
$unexpected_output = (string) ob_get_clean();

$error = null;
if (is_wp_error($result)) {
    $error = array(
        'code' => $result->get_error_code(),
        'message' => $result->get_error_message(),
    );
}

echo wp_json_encode(
    array(
        'active' => is_plugin_active($plugin),
        'booted' => class_exists($bootstrap_class, false) && $bootstrap_class::isBooted(),
        'error' => $error,
        'header' => array(
            'Name' => $header['Name'],
            'Version' => $header['Version'],
            'RequiresWP' => $header['RequiresWP'],
            'RequiresPHP' => $header['RequiresPHP'],
            'TextDomain' => $header['TextDomain'],
            'DomainPath' => $header['DomainPath'],
        ),
        'outputBytes' => strlen($unexpected_output),
        'plugin' => $plugin,
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
