<?php

declare(strict_types=1);

if ($argc !== 5) {
    fwrite(STDERR, "usage: wordpress-probe.php <alpha-plugin> <beta-plugin> <alpha-private-class> <beta-private-class>\n");
    exit(2);
}

require '/var/www/html/wp-load.php';

$alphaPlugin = $argv[1];
$betaPlugin = $argv[2];
$alphaPrivateClass = $argv[3];
$betaPrivateClass = $argv[4];
$activePlugins = get_option('active_plugins', array());

$alphaMethod = new ReflectionMethod('RuntimeAlpha\\PrivateBridge', 'filterTitle');
$betaMethod = new ReflectionMethod('RuntimeBeta\\PrivateBridge', 'filterTitle');
$filteredTitle = apply_filters('the_title', 'seed', 7);

$nativeSignature = static function (ReflectionMethod $method): array {
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

echo json_encode(array(
    'active' => array(
        $alphaPlugin => in_array($alphaPlugin, $activePlugins, true),
        $betaPlugin => in_array($betaPlugin, $activePlugins, true),
    ),
    'alphaBooted' => RuntimeAlpha\Bootstrap::isBooted(),
    'alphaPrivateLoaded' => class_exists($alphaPrivateClass, false),
    'alphaSignature' => $nativeSignature($alphaMethod),
    'betaBooted' => RuntimeBeta\Bootstrap::isBooted(),
    'betaPrivateLoaded' => class_exists($betaPrivateClass, false),
    'betaSignature' => $nativeSignature($betaMethod),
    'filteredTitle' => $filteredTitle,
    'wordpressVersion' => get_bloginfo('version'),
), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
