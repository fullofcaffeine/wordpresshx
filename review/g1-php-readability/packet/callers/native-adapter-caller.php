<?php

declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: native-adapter-caller.php <adapter-class-file>\n");
    exit(2);
}

$adapter_file = $argv[1];
if (!is_file($adapter_file)) {
    fwrite(STDERR, "adapter class file does not exist\n");
    exit(2);
}

ob_start();
require_once $adapter_file;
$unexpected_output = (string) ob_get_clean();

$class = 'Acme\\BooksAdapters\\PublicAdapters';
$reflection = new ReflectionClass($class);
$public_methods = array_map(
    static function (ReflectionMethod $method): string {
        return $method->getName();
    },
    $reflection->getMethods(ReflectionMethod::IS_PUBLIC)
);
$private_methods = array_map(
    static function (ReflectionMethod $method): string {
        return $method->getName();
    },
    $reflection->getMethods(ReflectionMethod::IS_PRIVATE)
);
sort($public_methods);
sort($private_methods);

$labels = array('seed');
$class::appendLabel($labels, 'added');
$class::onInit();
$append_parameters = $reflection->getMethod('appendLabel')->getParameters();

echo json_encode(
    array(
        'class' => $reflection->getName(),
        'initialized' => $class::isInitialized(),
        'labels' => $labels,
        'methods' => $public_methods,
        'normalize' => $class::normalizeTitle('  native caller  '),
        'outputBytes' => strlen($unexpected_output),
        'parameters' => array(
            'labelType' => (string) $append_parameters[1]->getType(),
            'labelsByReference' => $append_parameters[0]->isPassedByReference(),
        ),
        'privateMethods' => $private_methods,
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
