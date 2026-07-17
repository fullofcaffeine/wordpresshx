<?php

declare(strict_types=1);

$_SERVER['HTTP_HOST'] = 'wordpresshx.test';
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'wordpresshx.test';
$_SERVER['SERVER_PORT'] = '80';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

define('WP_INSTALLING', true);
require_once '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';

add_filter(
    'pre_wp_mail',
    static function () {
        return true;
    }
);

$fresh_install = !is_blog_installed();
if ($fresh_install) {
    wp_install(
        'WordPressHx SDK Harness',
        'wordpresshx_admin',
        'wordpresshx@example.invalid',
        false,
        '',
        'wordpresshx-test-only'
    );
}

update_option('home', 'http://wordpresshx.test', false);
update_option('siteurl', 'http://wordpresshx.test', false);
update_option('wordpresshx_harness_seed', 'sdk-090', false);

echo wp_json_encode(
    array(
        'freshInstall' => $fresh_install,
        'installed' => is_blog_installed(),
        'seed' => get_option('wordpresshx_harness_seed'),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
