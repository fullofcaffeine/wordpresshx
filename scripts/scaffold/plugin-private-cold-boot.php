<?php

declare(strict_types=1);

if ($argc !== 4 || !is_file($argv[1])) {
    fwrite(STDERR, "usage: plugin-private-cold-boot.php <plugin-root> <bridge-class> <expected>\n");
    exit(2);
}

$bridgeClass = $argv[2];
$expected = $argv[3];
if (!preg_match('/^[A-Za-z_][A-Za-z0-9_]*(?:\\\\[A-Za-z_][A-Za-z0-9_]*)+$/', $bridgeClass)) {
    fwrite(STDERR, "invalid bridge class\n");
    exit(2);
}

define('ABSPATH', __DIR__ . '/fixture-wordpress/');
$registeredFilters = array();

function add_filter(string $hookName, array $callback, int $priority = 10, int $acceptedArgs = 1): bool
{
    global $registeredFilters;
    $registeredFilters[] = array($hookName, $callback, $priority, $acceptedArgs);
    return true;
}

$start = hrtime(true);
require $argv[1];
$result = (string) call_user_func(array($bridgeClass, 'filterTitle'), 'seed', 7);
$elapsed = hrtime(true) - $start;

echo json_encode(array(
    'elapsedNanoseconds' => $elapsed,
    'expectedMatched' => $result === $expected,
    'filterCount' => count($registeredFilters),
    'result' => $result,
), JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR), "\n";
