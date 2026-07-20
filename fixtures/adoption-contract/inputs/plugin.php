<?php

declare(strict_types=1);

/*
Plugin Name: Acme Calendar
Version: 2.4.1
*/

$sentinel = getenv('WORDPRESSHX_ADOPTION_POISON_SENTINEL');
if (is_string($sentinel) && $sentinel !== '') {
    file_put_contents($sentinel, 'provider code executed');
}
