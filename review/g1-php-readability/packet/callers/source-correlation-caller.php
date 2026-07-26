<?php

declare(strict_types=1);

if ($argc !== 3) {
    fwrite(STDERR, "usage: source-correlation-caller.php <adapter-file> <hook|rest|render|private>\n");
    exit(2);
}

class WP_REST_Request
{
}

class WP_Block
{
}

$adapter_file = $argv[1];
$mode = $argv[2];
if (!is_file($adapter_file)) {
    fwrite(STDERR, "adapter file does not exist\n");
    exit(2);
}

require_once $adapter_file;

$adapter_class = '\\Fixture\\Correlation\\FailureCallbacks';
try {
    switch ($mode) {
        case 'hook':
            $adapter_class::failHook();
            break;
        case 'rest':
            $adapter_class::failRest(new WP_REST_Request());
            break;
        case 'render':
            $adapter_class::failRender(array(), '', new WP_Block());
            break;
        case 'private':
            $adapter_class::failPrivate();
            break;
        default:
            fwrite(STDERR, "unknown source-correlation failure mode\n");
            exit(2);
    }
} catch (Throwable $error) {
    fwrite(STDOUT, (string) $error . "\n");
    exit(17);
}

fwrite(STDERR, "source-correlation callback did not fail\n");
exit(1);
