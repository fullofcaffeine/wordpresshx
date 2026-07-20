<?php

declare(strict_types=1);

if ($argc !== 2 || !preg_match('/^http:\/\/127\.0\.0\.1:[1-9][0-9]{0,4}$/', $argv[1])) {
    fwrite(STDERR, "usage: set-url.php http://127.0.0.1:<port>\n");
    exit(2);
}

$origin = $argv[1];
$port = (int) parse_url($origin, PHP_URL_PORT);
if ($port < 1 || $port > 65535) {
    fwrite(STDERR, "invalid demo port\n");
    exit(2);
}

$_SERVER['HTTP_HOST'] = '127.0.0.1:' . $port;
$_SERVER['HTTPS'] = 'off';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = '127.0.0.1';
$_SERVER['SERVER_PORT'] = (string) $port;
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';

require_once '/var/www/html/wp-load.php';

update_option('home', $origin, false);
update_option('siteurl', $origin, false);

echo wp_json_encode(
    array(
        'check' => 'wordpresshx-example-public-url-v1',
        'home' => get_option('home'),
        'siteurl' => get_option('siteurl'),
    ),
    JSON_UNESCAPED_SLASHES
), "\n";
