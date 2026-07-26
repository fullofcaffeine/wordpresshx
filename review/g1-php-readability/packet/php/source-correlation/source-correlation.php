<?php
/**
 * Plugin Name: Source Correlation
 * Description: SDK-025 exact PHP trace fixture.
 * Version: 0.0.0
 * Requires at least: 7.0
 * Requires PHP: 7.4
 * Author: WordPressHx SDK fixture
 * License: LicenseRef-WordPressHx-Review-Pending
 * Text Domain: source-correlation
 * Domain Path: /languages
 */

if ( ! defined( 'ABSPATH' ) ) {
	return;
}
require_once __DIR__ . '/includes/autoload.php';
\Fixture\Correlation\Bootstrap::boot();
