<?php

declare(strict_types=1);

class ReflaxePhpInt32Runtime {
	public static function add(int $left, int $right): int {
		if ( PHP_INT_SIZE !== 8 ) {
			throw new \RuntimeException( 'reflaxe.php Int32 runtime requires 64-bit PHP' );
		}
		return ( ( $left + $right ) << 32 ) >> 32;
	}

	public static function subtract(int $left, int $right): int {
		if ( PHP_INT_SIZE !== 8 ) {
			throw new \RuntimeException( 'reflaxe.php Int32 runtime requires 64-bit PHP' );
		}
		return ( ( $left - $right ) << 32 ) >> 32;
	}
}
