<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: cold-boot.php <plugin-root> <public-bridge-class>\n");
    exit(2);
}

define('ABSPATH', __DIR__ . '/wordpress-not-used/');

function add_filter(string $hookName, array $callback, int $priority = 10, int $acceptedArgs = 1): bool
{
    return $hookName !== '' && count($callback) === 2 && $priority >= 0 && $acceptedArgs >= 0;
}

$started = hrtime(true);
require $argv[1];
$bridgeClass = $argv[2];
$result = (string) call_user_func(array($bridgeClass, 'filterTitle'), 'seed', 7);
$elapsed = hrtime(true) - $started;

echo json_encode(array(
    'elapsedNanoseconds' => $elapsed,
    'result' => $result,
), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
