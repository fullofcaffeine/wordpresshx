<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: probe-adapters.php <plugin> <adapter-class>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/wp-json/acme-books/v1/books/7';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

define('WORDPRESSHX_FIXTURE_PLUGIN', $argv[1]);
define('WORDPRESSHX_FIXTURE_ADAPTER_CLASS', $argv[2]);

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin = WORDPRESSHX_FIXTURE_PLUGIN;
$adapter_class = WORDPRESSHX_FIXTURE_ADAPTER_CLASS;
wp_set_current_user(1);

$rest_server = rest_get_server();
$positive_response = $rest_server->dispatch(new WP_REST_Request('GET', '/acme-books/v1/books/7'));
$negative_response = $rest_server->dispatch(new WP_REST_Request('GET', '/acme-books/v1/books/0'));
$routes = $rest_server->get_routes();
$route_key = '/acme-books/v1/books/(?P<id>[\\d]+)';

$block_registry = WP_Block_Type_Registry::get_instance();
$block_registered = $block_registry->is_registered('acme-books/summary');
$block_markup = render_block(
    array(
        'blockName' => 'acme-books/summary',
        'attrs' => array('title' => 'Typed & Safe'),
        'innerBlocks' => array(),
        'innerHTML' => '',
        'innerContent' => array(),
    )
);

$labels = array('runtime');
$adapter_class::appendLabel($labels, 'verified');
$reflection = new ReflectionClass($adapter_class);
$methods = array_map(
    static function (ReflectionMethod $method): string {
        return $method->getName();
    },
    $reflection->getMethods(ReflectionMethod::IS_PUBLIC)
);
sort($methods);

echo wp_json_encode(
    array(
        'active' => is_plugin_active($plugin),
        'block' => array(
            'markup' => $block_markup,
            'registered' => $block_registered,
        ),
        'class' => $reflection->getName(),
        'exports' => array(
            'labels' => $labels,
            'normalizeTitle' => $adapter_class::normalizeTitle('  runtime title  '),
        ),
        'hooks' => array(
            'filterPriority' => has_filter('the_title', array($adapter_class, 'filterTitle')),
            'filteredTitle' => apply_filters('the_title', '  typed title  ', 123),
            'initPriority' => has_action('init', array($adapter_class, 'onInit')),
            'initialized' => $adapter_class::isInitialized(),
        ),
        'methods' => $methods,
        'plugin' => $plugin,
        'rest' => array(
            'negative' => array(
                'code' => $negative_response->get_data()['code'] ?? null,
                'status' => $negative_response->get_status(),
            ),
            'permission' => $adapter_class::restPermission(new WP_REST_Request('GET', '/')),
            'positive' => array(
                'data' => $positive_response->get_data(),
                'status' => $positive_response->get_status(),
            ),
            'routeRegistered' => array_key_exists($route_key, $routes),
        ),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
