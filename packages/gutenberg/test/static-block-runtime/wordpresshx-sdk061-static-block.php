<?php

declare(strict_types=1);

/**
 * Plugin Name: WordPressHx SDK-061 Static Block Oracle
 * Description: Test-only native consumer for the generated static block artifact.
 * Version: 1.0.0
 * Requires at least: 7.0
 * Requires PHP: 7.4
 */

add_action(
    'init',
    static function (): void {
        $registered = register_block_type(__DIR__ . '/blocks/callout');
        if ($registered === false) {
            throw new RuntimeException('Unable to register the SDK-061 static block artifact.');
        }
    }
);
