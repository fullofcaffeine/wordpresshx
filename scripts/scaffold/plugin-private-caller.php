<?php

declare(strict_types=1);

if ($argc !== 8) {
    fwrite(STDERR, "usage: plugin-private-caller.php <first-root> <second-root> <first-bridge> <second-bridge> <first-private> <second-private> <expected>\n");
    exit(2);
}

$firstRoot = $argv[1];
$secondRoot = $argv[2];
$firstBridge = $argv[3];
$secondBridge = $argv[4];
$firstPrivate = $argv[5];
$secondPrivate = $argv[6];
$expected = $argv[7];
$classPattern = '/^[A-Za-z_][A-Za-z0-9_]*(?:\\\\[A-Za-z_][A-Za-z0-9_]*)+$/';
if (!is_file($firstRoot) || !is_file($secondRoot)) {
    fwrite(STDERR, "private plugin roots must be files\n");
    exit(2);
}
foreach (array($firstBridge, $secondBridge, $firstPrivate, $secondPrivate) as $className) {
    if (!preg_match($classPattern, $className)) {
        fwrite(STDERR, "private plugin class identity is invalid\n");
        exit(2);
    }
}

define('ABSPATH', __DIR__ . '/fixture-wordpress/');
$registeredFilters = array();

function add_filter(string $hookName, array $callback, int $priority = 10, int $acceptedArgs = 1): bool
{
    global $registeredFilters;
    $registeredFilters[] = array(
        'hook' => $hookName,
        'callback' => $callback,
        'priority' => $priority,
        'acceptedArgs' => $acceptedArgs,
    );
    return true;
}

function apply_private_title_filters(string $title, int $postId): string
{
    global $registeredFilters;
    foreach ($registeredFilters as $registration) {
        if ($registration['hook'] === 'the_title') {
            $title = (string) call_user_func($registration['callback'], $title, $postId);
        }
    }
    return $title;
}

$signature = static function (string $className): array {
    $method = new ReflectionMethod($className, 'filterTitle');
    $parameters = array();
    foreach ($method->getParameters() as $parameter) {
        $type = $parameter->getType();
        $parameters[] = $type === null ? null : (string) $type;
    }
    $returnType = $method->getReturnType();
    return array(
        'parameters' => $parameters,
        'return' => $returnType === null ? null : (string) $returnType,
    );
};

ob_start();
require $firstRoot;
require $firstRoot;
require $secondRoot;
$unexpectedOutput = (string) ob_get_clean();
$filteredTitle = apply_private_title_filters('seed', 7);

echo json_encode(array(
    'expectedMatched' => $filteredTitle === $expected,
    'filterCount' => count($registeredFilters),
    'filteredTitle' => $filteredTitle,
    'firstPrivateLoaded' => class_exists($firstPrivate, false),
    'firstSignature' => $signature($firstBridge),
    'outputBytes' => strlen($unexpectedOutput),
    'prefixesDistinct' => strstr($firstPrivate, '\\typed\\', true) !== strstr($secondPrivate, '\\typed\\', true),
    'secondPrivateLoaded' => class_exists($secondPrivate, false),
    'secondSignature' => $signature($secondBridge),
), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR), "\n";
