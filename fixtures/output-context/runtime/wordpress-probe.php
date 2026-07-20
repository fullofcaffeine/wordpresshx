<?php

declare(strict_types=1);

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';

$payload = '<script>alert("xss")</script><strong data-note="&quot;">kept</strong>&"\'';
$attribute_payload = '" autofocus onfocus="alert(1)" data-note="<unsafe>"';
$textarea_payload = '</textarea><script>alert("textarea")</script>&';
$rich_payload = '<p><strong>kept</strong><script>alert("rich")</script>'
    . '<a href="javascript:alert(1)" onmouseover="alert(2)">link</a></p>';

register_block_type(
    'wordpresshx/output-context-proof',
    array(
        'attributes' => array(
            'title' => array(
                'type' => 'string',
                'default' => '',
            ),
        ),
        'render_callback' => static function (array $attributes): string {
            return '<section class="output-context-proof">'
                . esc_html((string) $attributes['title'])
                . '</section>';
        },
    )
);

$block_markup = render_block(
    array(
        'blockName' => 'wordpresshx/output-context-proof',
        'attrs' => array('title' => $payload),
        'innerBlocks' => array(),
        'innerHTML' => '',
        'innerContent' => array(),
    )
);

add_action(
    'rest_api_init',
    static function (): void {
        register_rest_route(
            'wordpresshx/v1',
            '/output-context',
            array(
                'methods' => 'GET',
                'permission_callback' => '__return_true',
                'callback' => static function (WP_REST_Request $request): WP_REST_Response {
                    return new WP_REST_Response(
                        array(
                            'title' => (string) $request->get_param('title'),
                            'kind' => 'data-not-markup',
                        ),
                        200
                    );
                },
            )
        );
    }
);
do_action('rest_api_init');

$request = new WP_REST_Request('GET', '/wordpresshx/v1/output-context');
$request->set_param('title', $payload);
$rest_response = rest_do_request($request);
$rest_data = $rest_response->get_data();

ob_start();
wp_admin_notice(
    '<strong>Notice</strong> ' . $payload,
    array(
        'type' => 'error',
        'dismissible' => true,
        'id' => 'wordpresshx-output-context-proof',
    )
);
$admin_notice = (string) ob_get_clean();

$script_json = wp_json_encode(
    array(
        'title' => '</script><script>alert("json")</script>&\'',
        'id' => 7,
    ),
    JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT
);

$result = array(
    'check' => 'wordpresshx-adr012-wordpress-output-context-v1',
    'wordpressVersion' => get_bloginfo('version'),
    'text' => esc_html($payload),
    'attribute' => esc_attr($attribute_payload),
    'textarea' => esc_textarea($textarea_payload),
    'url' => array(
        'https' => esc_url('https://example.test/todos/7?a=1&b=2'),
        'javascript' => esc_url('javascript:alert(1)'),
        'relative' => esc_url('/todos/7?mode=edit&from=hxx'),
    ),
    'richHtml' => array(
        'post' => wp_kses_post($rich_payload),
        'data' => wp_kses_data($rich_payload),
        'custom' => wp_kses(
            $rich_payload,
            array(
                'p' => array(),
                'strong' => array(),
                'a' => array('href' => true),
            ),
            array('http', 'https')
        ),
    ),
    'scriptJson' => $script_json,
    'blockMarkup' => $block_markup,
    'rest' => array(
        'status' => $rest_response->get_status(),
        'data' => $rest_data,
        'encoded' => wp_json_encode(
            $rest_data,
            JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT
        ),
    ),
    'adminNotice' => $admin_notice,
);

echo json_encode($result, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), "\n";
