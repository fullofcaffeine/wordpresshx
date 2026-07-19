<?php

declare(strict_types=1);

if ($argc !== 9) {
    fwrite(STDERR, "usage: plugin-private-wordpress.php <first-plugin> <second-plugin> <first-bootstrap> <second-bootstrap> <first-bridge> <second-bridge> <first-private> <second-private>\n");
    exit(2);
}

require '/var/www/html/wp-load.php';

$firstPlugin = $argv[1];
$secondPlugin = $argv[2];
$firstBootstrap = $argv[3];
$secondBootstrap = $argv[4];
$firstBridge = $argv[5];
$secondBridge = $argv[6];
$firstPrivate = $argv[7];
$secondPrivate = $argv[8];
$activePlugins = get_option('active_plugins', array());

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

echo wp_json_encode(array(
    'active' => array(
        $firstPlugin => in_array($firstPlugin, $activePlugins, true),
        $secondPlugin => in_array($secondPlugin, $activePlugins, true),
    ),
    'filteredTitle' => apply_filters('the_title', 'seed', 7),
    'firstBooted' => $firstBootstrap::isBooted(),
    'firstPrivateLoaded' => class_exists($firstPrivate, false),
    'firstSignature' => $signature($firstBridge),
    'secondBooted' => $secondBootstrap::isBooted(),
    'secondPrivateLoaded' => class_exists($secondPrivate, false),
    'secondSignature' => $signature($secondBridge),
    'wordpressVersion' => get_bloginfo('version'),
), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), "\n";
