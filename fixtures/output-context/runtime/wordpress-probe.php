<?php

declare(strict_types=1);

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';

function wordpresshx_kses_allowlist(array $rules): array
{
    $allowlist = array();
    foreach ($rules as $rule) {
        $attributes = array();
        foreach ($rule['attributes'] as $attribute) {
            $attributes[(string) $attribute] = true;
        }
        $allowlist[(string) $rule['name']] = $attributes;
    }
    return $allowlist;
}

function wordpresshx_render_markup_node(array $node): string
{
    if ('text' === $node['kind'] || 'static-text' === $node['kind']) {
        return esc_html((string) $node['value']);
    }
    if ('element' !== $node['kind'] || ! in_array($node['tag'], array('article', 'h2', 'a'), true)) {
        throw new RuntimeException('Generated HXX plan contains an unadmitted element');
    }
    $attributes = '';
    foreach ($node['attributes'] as $attribute) {
        $name = (string) $attribute['name'];
        if ('attribute' === $attribute['kind'] && in_array($name, array('class', 'aria-label'), true)) {
            $attributes .= ' ' . $name . '="' . esc_attr((string) $attribute['value']) . '"';
        } elseif ('url' === $attribute['kind'] && 'href' === $name) {
            $attributes .= ' href="' . esc_url((string) $attribute['value']) . '"';
        } else {
            throw new RuntimeException('Generated HXX plan contains an unadmitted attribute');
        }
    }
    $children = '';
    foreach ($node['children'] as $child) {
        $children .= wordpresshx_render_markup_node($child);
    }
    $tag = (string) $node['tag'];
    return '<' . $tag . $attributes . '>' . $children . '</' . $tag . '>';
}

$plan_path = '/opt/wordpresshx/output-context-plan.json';
$plan_bytes = file_get_contents($plan_path);
if (false === $plan_bytes) {
    throw new RuntimeException('Haxe-generated output-context plan is missing');
}
$plan = json_decode($plan_bytes, true, 512, JSON_THROW_ON_ERROR);
if (
    ! is_array($plan)
    || 'wordpresshx.output-context-runtime-plan.v3' !== ($plan['schema'] ?? null)
) {
    throw new RuntimeException('Haxe-generated output-context plan identity differs');
}

$payload = (string) $plan['text'];
$attribute_payload = (string) $plan['attribute'];
$textarea_payload = (string) $plan['textarea'];
$rich_plans = $plan['richHtml'];
if (! is_array($rich_plans) || 4 !== count($rich_plans)) {
    throw new RuntimeException('Haxe-generated rich HTML plan differs');
}
$rich_payload = (string) $rich_plans[0]['value'];
if (
    $rich_payload !== $rich_plans[1]['value']
    || $rich_payload !== $rich_plans[2]['value']
    || $rich_payload !== $rich_plans[3]['value']
) {
    throw new RuntimeException('KSES policies did not receive one generated payload');
}

$custom_policy = (string) $rich_plans[2]['canonicalPolicy'];
$expected_custom_policy = 'profile=wp70-release;version=todo-rich.v1;tags=a[href,title],p,strong;protocols=http,https';
if ($expected_custom_policy !== $custom_policy) {
    throw new RuntimeException('Custom KSES policy canonical document differs');
}
$custom_digest = hash('sha256', $custom_policy);
if ('custom:' . $custom_digest !== $rich_plans[2]['policyIdentity']) {
    throw new RuntimeException('Custom KSES policy digest differs');
}
if ($rich_plans[2]['policyIdentity'] === $rich_plans[3]['policyIdentity']) {
    throw new RuntimeException('Custom KSES policy mutations retained one identity');
}
$custom_allowlist = wordpresshx_kses_allowlist($rich_plans[2]['rules']);
$restricted_allowlist = wordpresshx_kses_allowlist($rich_plans[3]['rules']);
$compiler_markup = wordpresshx_render_markup_node($plan['markup']['root']);
if (hash('sha256', (string) $plan['markup']['canonicalAst']) !== $plan['markup']['astSha256']) {
    throw new RuntimeException('Generated HXX AST digest differs');
}

$rest_value = json_decode((string) $plan['restJson']['encoded'], true, 512, JSON_THROW_ON_ERROR);
$script_value = json_decode((string) $plan['scriptData']['encoded'], true, 512, JSON_THROW_ON_ERROR);
if (! is_array($plan['controlJson']) || 0x20 !== count($plan['controlJson'])) {
    throw new RuntimeException('C0 JSON corpus differs');
}
foreach ($plan['controlJson'] as $code => $result) {
    if ('encoded' !== ($result['status'] ?? null) || array_key_exists('reason', $result)) {
        throw new RuntimeException('C0 JSON corpus unexpectedly failed');
    }
    $decoded_control = json_decode((string) $result['encoded'], true, 512, JSON_THROW_ON_ERROR);
    if ('before-' . chr($code) . '-after' !== $decoded_control['title']) {
        throw new RuntimeException('C0 JSON corpus changed at byte ' . $code);
    }
}
if (
    'rejected' !== ($plan['depthFailure']['status'] ?? null)
    || ! str_ends_with((string) ($plan['depthFailure']['reason'] ?? ''), 'json-depth-limit-exceeded')
    || array_key_exists('encoded', $plan['depthFailure'])
    || 'rejected' !== ($plan['invalidUnicodeFailure']['status'] ?? null)
    || ! str_ends_with((string) ($plan['invalidUnicodeFailure']['reason'] ?? ''), 'invalid-unicode')
    || array_key_exists('encoded', $plan['invalidUnicodeFailure'])
) {
    throw new RuntimeException('JSON depth or Unicode failure changed');
}
if (
    'encoded' !== ($plan['restJson']['status'] ?? null)
    || array_key_exists('reason', $plan['restJson'])
    || 'encoded' !== ($plan['scriptData']['status'] ?? null)
    || array_key_exists('reason', $plan['scriptData'])
    || 'rejected' !== ($plan['encodingFailure']['status'] ?? null)
    || 'invalid-domain-id' !== ($plan['encodingFailure']['reason'] ?? null)
    || array_key_exists('encoded', $plan['encodingFailure'])
    || 'rejected' !== ($plan['emptyFailure']['status'] ?? null)
    || 'codec-rejected-without-reason' !== ($plan['emptyFailure']['reason'] ?? null)
    || array_key_exists('encoded', $plan['emptyFailure'])
) {
    throw new RuntimeException('Typed JSON codec result differs');
}

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
    static function () use ($rest_value): void {
        register_rest_route(
            'wordpresshx/v1',
            '/output-context',
            array(
                'methods' => 'GET',
                'permission_callback' => '__return_true',
                'callback' => static function (WP_REST_Request $request) use ($rest_value): WP_REST_Response {
                    return new WP_REST_Response(
                        array(
                            'id' => (int) $rest_value['id'],
                            'title' => (string) $rest_value['title'],
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
    $script_value,
    JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT
);
if (false === $script_json) {
    throw new RuntimeException('wp_json_encode failed for admitted script data');
}

$result = array(
    'check' => 'wordpresshx-adr012-wordpress-output-context-v1',
    'planSha256' => hash('sha256', $plan_bytes),
    'wordpressVersion' => get_bloginfo('version'),
    'text' => esc_html($payload),
    'attribute' => esc_attr($attribute_payload),
    'textarea' => esc_textarea($textarea_payload),
    'url' => array(
        'https' => $plan['urlMatrix']['https']['accepted']
            ? esc_url((string) $plan['urlMatrix']['https']['input'])
            : '',
        'schemeCase' => $plan['urlMatrix']['schemeCase']['accepted']
            ? esc_url((string) $plan['urlMatrix']['schemeCase']['input'])
            : '',
        'javascript' => $plan['urlMatrix']['javascript']['accepted']
            ? esc_url((string) $plan['urlMatrix']['javascript']['input'])
            : '',
        'protocolRelative' => $plan['urlMatrix']['protocolRelative']['accepted']
            ? esc_url((string) $plan['urlMatrix']['protocolRelative']['input'])
            : '',
        'data' => $plan['urlMatrix']['data']['accepted']
            ? esc_url((string) $plan['urlMatrix']['data']['input'])
            : '',
        'relative' => $plan['urlMatrix']['relative']['accepted']
            ? esc_url((string) $plan['urlMatrix']['relative']['input'])
            : '',
    ),
    'richHtml' => array(
        'post' => wp_kses_post($rich_payload),
        'data' => wp_kses_data($rich_payload),
        'custom' => wp_kses(
            $rich_payload,
            $custom_allowlist,
            $rich_plans[2]['protocols']
        ),
        'customRestricted' => wp_kses(
            $rich_payload,
            $restricted_allowlist,
            $rich_plans[3]['protocols']
        ),
    ),
    'scriptJson' => $script_json,
    'inlineStyle' => esc_attr((string) $plan['inlineStyle']),
    'stylesheet' => (string) $plan['stylesheet'],
    'markupProvenance' => $plan['markup'],
    'compilerMarkup' => $compiler_markup,
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
