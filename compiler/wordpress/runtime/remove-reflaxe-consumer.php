<?php

declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: remove-reflaxe-consumer.php <plugin>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/wp-admin/plugins.php';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin = $argv[1];
$plugin_root = WP_PLUGIN_DIR . '/' . dirname($plugin);
deactivate_plugins($plugin, false, false);
$inactive = !is_plugin_active($plugin);
$deleted = delete_plugins(array($plugin));
$error = null;
if (is_wp_error($deleted)) {
    $error = array(
        'code' => $deleted->get_error_code(),
        'message' => $deleted->get_error_message(),
    );
}

echo wp_json_encode(
    array(
        'deleteResult' => $deleted === true,
        'error' => $error,
        'inactive' => $inactive,
        'pluginDirectoryPresent' => is_dir($plugin_root),
        'pluginFilePresent' => is_file(WP_PLUGIN_DIR . '/' . $plugin),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
