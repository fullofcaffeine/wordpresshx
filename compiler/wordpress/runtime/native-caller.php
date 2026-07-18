<?php

declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: native-caller.php <plugin-root>\n");
    exit(2);
}

$plugin_root = $argv[1];
if (!is_file($plugin_root)) {
    fwrite(STDERR, "plugin root does not exist\n");
    exit(2);
}

define('ABSPATH', __DIR__ . '/fixture-wordpress/');
ob_start();
require $plugin_root;
require $plugin_root;
$unexpected_output = (string) ob_get_clean();

$class = 'Acme\\Books\\Bootstrap';
$reflection = new ReflectionClass($class);
$methods = array_map(
    static function (ReflectionMethod $method): string {
        return $method->getName();
    },
    $reflection->getMethods(ReflectionMethod::IS_PUBLIC)
);
sort($methods);

echo json_encode(
    array(
        'booted' => $class::isBooted(),
        'class' => $reflection->getName(),
        'methods' => $methods,
        'outputBytes' => strlen($unexpected_output),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
