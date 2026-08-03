<?php

declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: probe-reflaxe-consumer.php <plugin>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin = $argv[1];
echo wp_json_encode(
    array(
        'active' => is_plugin_active($plugin),
        'nativeFunctionPresent' => function_exists('update_option'),
        'option' => get_option('wordpresshx_reflaxe_consumer', null),
        'plugin' => $plugin,
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
