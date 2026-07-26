<?php

declare(strict_types=1);

namespace Fixture\Correlation;

class FailureCallbacks {
	public static function failHook(): void {
		throw new \RuntimeException( 'hook failure' );
	}

	public static function allowRest(\WP_REST_Request $request): bool {
		unset( $request );
		return true;
	}

	public static function failRest(\WP_REST_Request $request): object {
		unset( $request );
		throw new \RuntimeException( 'rest failure' );
	}

	/**
	 * Raise the typed block-render fixture failure.
	 *
	 * @param array<string, mixed> $attributes Block attributes keyed by name.
	 */
	public static function failRender(array $attributes, string $content, \WP_Block $block): string {
		unset( $attributes );
		unset( $content );
		unset( $block );
		throw new \RuntimeException( 'render failure' );
	}

	public static function failPrivate(): void {
		self::privateFailure();
	}

	private static function privateFailure(): void {
		throw new \RuntimeException( 'private failure' );
	}

	public static function registerRestRoutes(): void {
		\register_rest_route( 'wordpresshx-fixture/v1', '/fail', array(
			'methods'             => \WP_REST_Server::READABLE,
			'callback'            => array( self::class, 'failRest' ),
			'permission_callback' => array( self::class, 'allowRest' ),
		) );
	}

	public static function registerBlocks(): void {
		\register_block_type( 'wordpresshx-fixture/failure', array(
			'render_callback' => array( self::class, 'failRender' ),
		) );
	}
}
