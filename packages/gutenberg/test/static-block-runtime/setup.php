<?php

declare(strict_types=1);

if ($argc !== 2 || !preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/', $argv[1])) {
    fwrite(STDERR, "usage: setup.php <plugin-slug>\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = 'wordpress-mysql';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpress-mysql';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$plugin_slug = $argv[1];
$plugin_file = $plugin_slug . '/' . $plugin_slug . '.php';
$activation = activate_plugin($plugin_file, '', false, true);
if (is_wp_error($activation)) {
    fwrite(STDERR, $activation->get_error_message() . "\n");
    exit(1);
}

update_option('home', 'http://wordpress-mysql', false);
update_option('siteurl', 'http://wordpress-mysql', false);
update_user_option(1, 'show_welcome_panel', 0, true);

$legacy_bytes = <<<'HTML'
<!-- wp:wordpresshx/callout -->
<div class="wp-block-wordpresshx-callout wphx-callout-legacy"><p class="wphx-callout__message">Legacy bytes.</p></div>
<!-- /wp:wordpresshx/callout -->
HTML;
$current_post_id = wp_insert_post(
    array(
        'post_title' => 'Typed static callout',
        'post_content' => '',
        'post_status' => 'publish',
        'post_type' => 'post',
        'post_author' => 1,
    ),
    true
);
$legacy_post_id = wp_insert_post(
    array(
        'post_title' => 'Migrated static callout',
        'post_content' => $legacy_bytes,
        'post_status' => 'publish',
        'post_type' => 'post',
        'post_author' => 1,
    ),
    true
);
if (is_wp_error($current_post_id) || is_wp_error($legacy_post_id)) {
    fwrite(STDERR, "unable to seed static block fixtures\n");
    exit(1);
}

echo wp_json_encode(
    array(
        'check' => 'wordpresshx-sdk061-static-block-setup-v1',
        'currentPostId' => $current_post_id,
        'legacyPostId' => $legacy_post_id,
        'pluginActive' => is_plugin_active($plugin_file),
        'wordpressVersion' => get_bloginfo('version'),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
