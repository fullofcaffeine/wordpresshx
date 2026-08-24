<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: lifecycle-command.php <command> <plugin>\n");
    exit(2);
}

$command = $argv[1];
define('WORDPRESSHX_LIFECYCLE_COMMAND', $command);
define('WORDPRESSHX_LIFECYCLE_PLUGIN', $argv[2]);

if ($command === 'fail-load-v3') {
    define('ACME_LIFECYCLE_FAIL_V3', true);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/wp-admin/plugins.php';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$command = WORDPRESSHX_LIFECYCLE_COMMAND;
$plugin = WORDPRESSHX_LIFECYCLE_PLUGIN;

if ($command === 'activate') {
    ob_start();
    $result = activate_plugin($plugin, '', false, false);
    $output = (string) ob_get_clean();
    if (is_wp_error($result)) {
        fwrite(STDERR, $result->get_error_code() . ': ' . $result->get_error_message() . "\n");
        exit(17);
    }
    echo wp_json_encode(
        array(
            'active' => is_plugin_active($plugin),
            'outputBytes' => strlen($output),
        ),
        JSON_UNESCAPED_SLASHES
    ), "\n";
    exit(0);
}

if ($command === 'deactivate') {
    deactivate_plugins($plugin, false, false);
    echo wp_json_encode(array('active' => is_plugin_active($plugin))), "\n";
    exit(0);
}

if ($command === 'uninstall') {
    if (is_plugin_active($plugin)) {
        fwrite(STDERR, "plugin must be inactive before uninstall\n");
        exit(18);
    }
    uninstall_plugin($plugin);
    echo wp_json_encode(array('uninstalled' => true)), "\n";
    exit(0);
}

if ($command !== 'probe' && $command !== 'mu-probe') {
    fwrite(STDERR, "unknown lifecycle command: {$command}\n");
    exit(2);
}

$mu = $command === 'mu-probe';
$prefix = $mu ? 'acme_lifecycle_mu' : 'acme_lifecycle';
$class = $mu ? 'Acme\\LifecycleMu\\Lifecycle' : 'Acme\\Lifecycle\\Lifecycle';
$activation_hook = 'activate_' . $plugin;
$deactivation_hook = 'deactivate_' . $plugin;

function wordpresshx_lifecycle_option(string $name): ?int
{
    $value = get_option($name, null);
    return $value === null ? null : (int) $value;
}

echo wp_json_encode(
    array(
        'active' => $mu ? null : is_plugin_active($plugin),
        'classLoaded' => class_exists($class, false),
        'hooks' => array(
            'activation' => has_action($activation_hook, array($class, 'activate')) !== false,
            'deactivation' => has_action($deactivation_hook, array($class, 'deactivate')) !== false,
            'upgrade' => has_action('plugins_loaded', array($class, 'maybeUpgrade')) !== false,
        ),
        'migrationRuns' => array(
            wordpresshx_lifecycle_option($prefix . '_migration_1_runs'),
            wordpresshx_lifecycle_option($prefix . '_migration_2_runs'),
            wordpresshx_lifecycle_option($prefix . '_migration_3_runs'),
        ),
        'schemaVersion' => wordpresshx_lifecycle_option($prefix . '_schema_version'),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
