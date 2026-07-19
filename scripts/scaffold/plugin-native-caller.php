<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: plugin-native-caller.php <plugin-root> <bootstrap-class>\n");
    exit(2);
}

$plugin_root = $argv[1];
$bootstrap_class = $argv[2];
if (!is_file($plugin_root) || !preg_match('/^[A-Z_][A-Za-z0-9_]*(?:\\\\[A-Z_][A-Za-z0-9_]*)*\\\\Bootstrap$/', $bootstrap_class)) {
    fwrite(STDERR, "invalid plugin root or bootstrap class\n");
    exit(2);
}

define('ABSPATH', __DIR__ . '/fixture-wordpress/');
ob_start();
require $plugin_root;
require $plugin_root;
$unexpected_output = (string) ob_get_clean();

$reflection = new ReflectionClass($bootstrap_class);
$methods = array_map(
    static function (ReflectionMethod $method): string {
        return $method->getName();
    },
    $reflection->getMethods(ReflectionMethod::IS_PUBLIC)
);
sort($methods);

echo json_encode(
    array(
        'booted' => $bootstrap_class::isBooted(),
        'class' => $reflection->getName(),
        'methods' => $methods,
        'outputBytes' => strlen($unexpected_output),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
