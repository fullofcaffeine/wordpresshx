<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: probe-source-correlation.php <plugin> <adapter-class>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/wp-json/wordpresshx-fixture/v1/fail';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

define('WORDPRESSHX_CORRELATION_PLUGIN', $argv[1]);
define('WORDPRESSHX_CORRELATION_ADAPTER_CLASS', $argv[2]);

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

/**
 * Exercise one native WordPress entry point while preserving the complete
 * Throwable string long enough to verify that its native frame survived.
 *
 * @return array<string, int|string|bool>
 */
function wordpresshx_capture_failure(string $mode, callable $trigger): array
{
    try {
        $trigger();
    } catch (Throwable $error) {
        $native_stack = (string) $error;
        $plugin_marker = '/wp-content/plugins/source-correlation/';
        $throw_file = str_replace('\\', '/', $error->getFile());
        $marker_offset = strpos($throw_file, $plugin_marker);
        $logical_file = $marker_offset === false
            ? 'unresolved'
            : 'source-correlation/' . substr(
                $throw_file,
                $marker_offset + strlen($plugin_marker)
            );

        return array(
            'class' => get_class($error),
            'logicalFile' => $logical_file,
            'message' => $error->getMessage(),
            'mode' => $mode,
            'nativeStackPreserved' => strpos($native_stack, 'Stack trace:') !== false
                && strpos($native_stack, 'FailureCallbacks.php') !== false,
            'throwLine' => $error->getLine(),
            'traceFrameCount' => count($error->getTrace()),
        );
    }

    throw new RuntimeException($mode . ' failure did not throw');
}

$plugin = WORDPRESSHX_CORRELATION_PLUGIN;
$adapter_class = WORDPRESSHX_CORRELATION_ADAPTER_CLASS;
$rest_server = rest_get_server();
$routes = $rest_server->get_routes();
$block_registry = WP_Block_Type_Registry::get_instance();

$failures = array(
    'hook' => wordpresshx_capture_failure(
        'hook',
        static function (): void {
            do_action('wordpresshx_fixture_fail');
        }
    ),
    'rest' => wordpresshx_capture_failure(
        'rest',
        static function () use ($rest_server): void {
            $rest_server->dispatch(
                new WP_REST_Request('GET', '/wordpresshx-fixture/v1/fail')
            );
        }
    ),
    'render' => wordpresshx_capture_failure(
        'render',
        static function (): void {
            render_block(
                array(
                    'blockName' => 'wordpresshx-fixture/failure',
                    'attrs' => array(),
                    'innerBlocks' => array(),
                    'innerHTML' => '',
                    'innerContent' => array(),
                )
            );
        }
    ),
    'private' => wordpresshx_capture_failure(
        'private',
        static function () use ($adapter_class): void {
            $adapter_class::failPrivate();
        }
    ),
);

echo wp_json_encode(
    array(
        'active' => is_plugin_active($plugin),
        'blockRegistered' => $block_registry->is_registered(
            'wordpresshx-fixture/failure'
        ),
        'class' => $adapter_class,
        'failures' => $failures,
        'plugin' => $plugin,
        'restRouteRegistered' => array_key_exists(
            '/wordpresshx-fixture/v1/fail',
            $routes
        ),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
