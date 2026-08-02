<?php

declare(strict_types=1);

class ReflaxePhpStringRuntime {
	public static function length(string $value): int {
		$characters = \preg_split( '//u', $value, -1, PREG_SPLIT_NO_EMPTY );
		if ( $characters === false ) {
			throw new \RuntimeException( 'reflaxe.php String runtime received invalid UTF-8' );
		}
		return \count( $characters );
	}
}
