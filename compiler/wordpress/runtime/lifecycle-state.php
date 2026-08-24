<?php

declare(strict_types=1);

if ($argc !== 2) {
    fwrite(STDERR, "usage: lifecycle-state.php <option-prefix>\n");
    exit(2);
}

$prefix = $argv[1];
if (!preg_match('/^[a-z][a-z0-9_]+$/', $prefix)) {
    fwrite(STDERR, "invalid lifecycle option prefix\n");
    exit(2);
}

define('WP_INSTALLING', true);
$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';

function wordpresshx_lifecycle_state_option(string $name): ?int
{
    $value = get_option($name, null);
    return $value === null ? null : (int) $value;
}

echo wp_json_encode(
    array(
        'migrationRuns' => array(
            wordpresshx_lifecycle_state_option($prefix . '_migration_1_runs'),
            wordpresshx_lifecycle_state_option($prefix . '_migration_2_runs'),
            wordpresshx_lifecycle_state_option($prefix . '_migration_3_runs'),
        ),
        'schemaVersion' => wordpresshx_lifecycle_state_option($prefix . '_schema_version'),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
