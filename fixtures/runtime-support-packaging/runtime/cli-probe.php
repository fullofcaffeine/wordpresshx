<?php

declare(strict_types=1);

if ($argc !== 5) {
    fwrite(STDERR, "usage: cli-probe.php <alpha-root> <beta-root> <alpha-private-class> <beta-private-class>\n");
    exit(2);
}

define('ABSPATH', __DIR__ . '/wordpress-not-used/');

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

function apply_registered_title_filters(string $title, int $postId): string
{
    global $registeredFilters;
    foreach ($registeredFilters as $registration) {
        if ($registration['hook'] === 'the_title') {
            $title = (string) call_user_func($registration['callback'], $title, $postId);
        }
    }
    return $title;
}

$alphaRoot = $argv[1];
$betaRoot = $argv[2];
$alphaPrivateClass = $argv[3];
$betaPrivateClass = $argv[4];

ob_start();
require $alphaRoot;
require $alphaRoot;
require $betaRoot;
$unexpectedOutput = (string) ob_get_clean();

$alphaMethod = new ReflectionMethod('RuntimeAlpha\\PrivateBridge', 'filterTitle');
$betaMethod = new ReflectionMethod('RuntimeBeta\\PrivateBridge', 'filterTitle');
$filteredTitle = apply_registered_title_filters('seed', 7);

$signature = static function (ReflectionMethod $method): array {
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

$payload = array(
    'alphaBooted' => RuntimeAlpha\Bootstrap::isBooted(),
    'alphaPrivateClass' => $alphaPrivateClass,
    'alphaPrivateLoaded' => class_exists($alphaPrivateClass, false),
    'alphaSignature' => $signature($alphaMethod),
    'betaBooted' => RuntimeBeta\Bootstrap::isBooted(),
    'betaPrivateClass' => $betaPrivateClass,
    'betaPrivateLoaded' => class_exists($betaPrivateClass, false),
    'betaSignature' => $signature($betaMethod),
    'filteredTitle' => $filteredTitle,
    'filterCount' => count($registeredFilters),
    'outputBytes' => strlen($unexpectedOutput),
    'prefixesDistinct' => strstr($alphaPrivateClass, '\\fixture', true) !== strstr($betaPrivateClass, '\\fixture', true),
);

echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
