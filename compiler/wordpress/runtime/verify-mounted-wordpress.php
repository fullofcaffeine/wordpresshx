<?php

declare(strict_types=1);

if ($argc !== 5) {
    fwrite(STDERR, "usage: verify-mounted-wordpress.php <version> <php-version> <file-count> <tree-sha256>\n");
    exit(2);
}

$expected_version = $argv[1];
$expected_php = $argv[2];
$expected_count = (int) $argv[3];
$expected_tree = $argv[4];
$root = '/var/www/html';

require $root . '/wp-includes/version.php';
if ($wp_version !== $expected_version || PHP_VERSION !== $expected_php) {
    fwrite(STDERR, "mounted WordPress/PHP version differs\n");
    exit(17);
}

$entries = array();
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS)
);
foreach ($iterator as $file) {
    if (!$file->isFile()) {
        continue;
    }
    $relative = substr($file->getPathname(), strlen($root) + 1);
    if ($relative === 'wp-config.php') {
        continue;
    }
    $entries[$relative] = hash_file('sha256', $file->getPathname());
}
ksort($entries, SORT_STRING);
$digest_input = '';
foreach ($entries as $relative => $sha256) {
    $digest_input .= $sha256 . '  ./' . $relative . "\n";
}
$tree = hash('sha256', $digest_input);
if (count($entries) !== $expected_count || $tree !== $expected_tree) {
    fwrite(STDERR, "mounted WordPress source tree differs\n");
    exit(18);
}

echo json_encode(
    array(
        'contentFileCount' => count($entries),
        'contentTreeSha256' => $tree,
        'phpVersion' => PHP_VERSION,
        'wordpressVersion' => $wp_version,
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
