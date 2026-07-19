<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: conflict-probe.php <plugin-root.php> <bootstrap-class>\n");
    exit(64);
}

define('ABSPATH', __DIR__ . '/');
define('WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256', str_repeat('0', 64));

$GLOBALS['wordpresshxAdr018Filters'] = array();

function add_filter(
    string $hookName,
    callable $callback,
    int $priority = 10,
    int $acceptedArguments = 1
): bool {
    $GLOBALS['wordpresshxAdr018Filters'][] = array(
        'callback' => $callback,
        'hookName' => $hookName,
        'priority' => $priority,
        'acceptedArguments' => $acceptedArguments,
    );
    return true;
}

$pluginFile = $argv[1];
$bootstrapClass = $argv[2];
ob_start();
require $pluginFile;
$output = ob_get_clean();
if (!is_string($output)) {
    throw new RuntimeException('failed to capture plugin output');
}

echo json_encode(
    array(
        'bootstrapLoaded' => class_exists($bootstrapClass, false),
        'filterCount' => count($GLOBALS['wordpresshxAdr018Filters']),
        'outputBytes' => strlen($output),
    ),
    JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
);
