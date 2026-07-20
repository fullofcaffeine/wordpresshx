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

$post_id = wp_insert_post(
    array(
        'post_title' => 'Todo Studio data-store rehearsal',
        'post_content' => '<!-- wp:paragraph --><p>Native typed store proof.</p><!-- /wp:paragraph -->',
        'post_status' => 'draft',
        'post_type' => 'post',
        'post_author' => 1,
    ),
    true
);
$page_id = wp_insert_post(
    array(
        'post_title' => 'Unsupported data-store page',
        'post_content' => '<!-- wp:paragraph --><p>Post-type visibility negative.</p><!-- /wp:paragraph -->',
        'post_status' => 'draft',
        'post_type' => 'page',
        'post_author' => 1,
    ),
    true
);
if (is_wp_error($post_id) || is_wp_error($page_id)) {
    fwrite(STDERR, "unable to seed data-store fixtures\n");
    exit(1);
}

echo wp_json_encode(
    array(
        'check' => 'wordpresshx-sdk064-data-store-setup-v1',
        'pageId' => $page_id,
        'pluginActive' => is_plugin_active($plugin_file),
        'postId' => $post_id,
        'wordpressVersion' => get_bloginfo('version'),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
