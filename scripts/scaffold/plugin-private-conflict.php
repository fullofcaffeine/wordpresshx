<?php

declare(strict_types=1);

if ($argc !== 3 || !is_file($argv[1])) {
    fwrite(STDERR, "usage: plugin-private-conflict.php <plugin-root> <bridge-class>\n");
    exit(2);
}

$bridgeClass = $argv[2];
if (!preg_match('/^[A-Za-z_][A-Za-z0-9_]*(?:\\\\[A-Za-z_][A-Za-z0-9_]*)+$/', $bridgeClass)) {
    fwrite(STDERR, "invalid bridge class\n");
    exit(2);
}

define('ABSPATH', __DIR__ . '/fixture-wordpress/');
define('WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256', str_repeat('0', 64));
$registeredFilters = array();

function add_filter(string $hookName, array $callback, int $priority = 10, int $acceptedArgs = 1): bool
{
    global $registeredFilters;
    $registeredFilters[] = array($hookName, $callback, $priority, $acceptedArgs);
    return true;
}

ob_start();
require $argv[1];
$unexpectedOutput = (string) ob_get_clean();

echo json_encode(array(
    'bridgeLoaded' => class_exists($bridgeClass, false),
    'filterCount' => count($registeredFilters),
    'outputBytes' => strlen($unexpectedOutput),
), JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR), "\n";
