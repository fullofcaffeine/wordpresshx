<?php

declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: activate-reflaxe-consumer.php <plugin>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/wp-admin/plugins.php';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin = $argv[1];
$header = get_plugin_data(WP_PLUGIN_DIR . '/' . $plugin, false, false);
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
        'error' => $error,
        'header' => array(
            'Name' => $header['Name'],
            'RequiresPHP' => $header['RequiresPHP'],
            'RequiresWP' => $header['RequiresWP'],
            'Version' => $header['Version'],
        ),
        'option' => get_option('wordpresshx_reflaxe_consumer', null),
        'outputBytes' => strlen($unexpected_output),
        'plugin' => $plugin,
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
