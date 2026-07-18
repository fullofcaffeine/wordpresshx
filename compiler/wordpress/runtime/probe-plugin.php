<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: probe-plugin.php <plugin> <bootstrap-class>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

define('WORDPRESSHX_FIXTURE_PLUGIN', $argv[1]);
define('WORDPRESSHX_FIXTURE_BOOTSTRAP_CLASS', $argv[2]);

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin = WORDPRESSHX_FIXTURE_PLUGIN;
$bootstrap_class = WORDPRESSHX_FIXTURE_BOOTSTRAP_CLASS;
$reflection = new ReflectionClass($bootstrap_class);
$methods = array_map(
    static function (ReflectionMethod $method): string {
        return $method->getName();
    },
    $reflection->getMethods(ReflectionMethod::IS_PUBLIC)
);
sort($methods);
$bootstrap_file = str_replace(
    '\\',
    '/',
    substr((string) $reflection->getFileName(), strlen(WP_PLUGIN_DIR) + 1)
);

echo wp_json_encode(
    array(
        'active' => is_plugin_active($plugin),
        'booted' => $bootstrap_class::isBooted(),
        'bootstrapFile' => $bootstrap_file,
        'class' => $reflection->getName(),
        'methods' => $methods,
        'plugin' => $plugin,
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
